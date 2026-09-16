-- Server-only bridge to Eternal Tower Defense's existing match services.
-- Permission checks belong to the admin server before calling Perform.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = {}
local MAX_ACTIVE_ENEMIES = 300
local MAX_ACTIVE_UNITS = 150
local MAX_OWNED_ADMIN_UNITS = 50

local function find(root, ...)
	local current = root
	for _, name in { ... } do
		current = current and current:FindFirstChild(name)
	end
	return current
end

function Match.Available()
	return find(ServerScriptService, "Server", "Services", "Entities", "EnemyService") ~= nil
		and find(ServerScriptService, "Server", "Services", "Entities", "UnitService") ~= nil
		and find(ReplicatedStorage, "Shared", "Services", "System", "EconomyService") ~= nil
end

local function sortedNames(data)
	local names = {}
	for name in pairs(data.ByName or {}) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Match.Catalog()
	if not Match.Available() then
		return { units = {}, enemies = {} }
	end
	local data = assert(find(ReplicatedStorage, "Settings", "Data"), "Match catalogs are unavailable.")
	return {
		units = sortedNames(require(data.UnitData)),
		enemies = sortedNames(require(data.EnemyData)),
	}
end

local function number(value, name, minimum, maximum, integer)
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
		name .. " must be a finite number.")
	assert(value >= minimum and value <= maximum,
		string.format("%s must be between %s and %s.", name, minimum, maximum))
	assert(not integer or value % 1 == 0, name .. " must be a whole number.")
	return value
end

local function service(name)
	local module = assert(find(ReplicatedStorage, "Shared", "Modules", "Core", "ServiceRegistry"),
		"Game services are unavailable in this place.")
	local registry = require(module)
	local value = registry._services[name]
	assert(registry._isStarted and value, "Game services are still starting. Try again shortly.")
	return value
end

local function readyPath()
	local gameService = service("GameService")
	local map = workspace:FindFirstChild("Map")
	assert(gameService.IsMapLoaded and map and map:GetAttribute("GameplayReady") == true,
		"Wait for the match map to finish loading.")
	local paths = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
	assert(paths.CachedPath and paths.Paths[1], "The match route is not ready.")
	return paths
end

local function livePlayer(player)
	assert(typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players,
		"Select a player who is in this server.")
end

local function countEntries(entries)
	local count = 0
	for _ in pairs(entries) do count += 1 end
	return count
end

local function validEntity(kind, name)
	assert(type(name) == "string" and #name > 0 and #name <= 80, "Select a valid " .. kind .. ".")
	local moduleName = kind == "enemy" and "EnemyData" or "UnitData"
	local data = require(ReplicatedStorage.Settings.Data[moduleName])
	assert(data.ByName[name], "Unknown " .. kind .. ": " .. name)
	local assetFolder = kind == "enemy" and "Enemies" or "Units"
	local model = find(ReplicatedStorage, "Assets", assetFolder, name)
	assert(model and model:IsA("Model") and model.PrimaryPart,
		"This " .. kind .. " has no usable model: " .. name)
	return name
end

local function virtualSummoner(owner)
	local Signal = require(ReplicatedStorage.Packages.Signal)
	local events = {}
	local summoner = {
		Id = 0, -- Real tower registry IDs start at 1; clients accept an absent summoner.
		Owner = owner,
		Stats = {},
		IsAdminSummoner = true,
	}
	function summoner:GetEvent(name)
		if not events[name] then events[name] = Signal.new() end
		return events[name]
	end
	function summoner:Destroy()
		self.IsDestroyed = true
		for _, event in pairs(events) do event:Destroy() end
		table.clear(events)
	end
	return summoner
end

function Match.Perform(action, actor, target, args)
	assert(Match.Available(), "In-game controls are available in the In Game place.")
	assert(type(args) == "table", "Missing command arguments.")
	livePlayer(actor)

	if action == "Money" then
		livePlayer(target)
		local amount = number(args.amount, "Money", 0, 1_000_000_000, true)
		local economy = service("EconomyService")
		assert(economy.GetCash(target) ~= nil, "This player's match cash is still loading.")
		economy.SetCash(target, amount)
		return string.format("Set %s's match money to %s.", target.Name, amount)
	elseif action == "GameSpeed" then
		readyPath()
		local speed = number(args.speed, "Game speed", 0.25, 5, false)
		-- Existing network packets encode speed * 10 as an integer. Keep both sides in sync.
		speed = math.round(speed * 10) / 10
		service("TimeService"):SetGameSpeed(speed)
		return string.format("Set server game speed to %.1fx.", speed)
	elseif action == "SpawnEnemy" then
		readyPath()
		local name = validEntity("enemy", args.enemyId)
		local amount = number(args.count or 1, "Spawn count", 1, 25, true)
		local enemies = service("EnemyService")
		assert(countEntries(enemies.GetAll()) + amount <= MAX_ACTIVE_ENEMIES,
			"The server already has too many active enemies. Wait for some to despawn.")
		-- An explicit route guarantees count means total enemies, even on multi-route maps.
		for _ = 1, amount do
			enemies.SetupNewEnemy(name, false, 0, 1)
		end
		return string.format("Spawned %d %s on route 1.", amount, name)
	elseif action == "SpawnUnit" then
		livePlayer(target)
		readyPath()
		local name = validEntity("unit", args.unitId or args.towerId)
		local amount = number(args.count or 1, "Spawn count", 1, 25, true)
		local units = service("UnitService")
		local active = units.GetAll()
		assert(countEntries(active) + amount <= MAX_ACTIVE_UNITS,
			"The server already has too many active allied units. Wait for some to despawn.")
		local owned = 0
		for _, unit in pairs(active) do
			local summoner = unit.Summoner
			if summoner and summoner.IsAdminSummoner and summoner.Owner == target then owned += 1 end
		end
		assert(owned + amount <= MAX_OWNED_ADMIN_UNITS, "This player already has too many admin-spawned allied units.")
		for _ = 1, amount do
			local summoner = virtualSummoner(target)
			local ok, unit = pcall(units.Spawn, summoner, name, 1, false)
			if not ok then
				summoner:Destroy()
				error(unit, 0)
			end
			unit.Destroyed:Connect(function()
				task.defer(function() summoner:Destroy() end)
			end)
		end
		return string.format("Spawned %d %s for %s.", amount, name, target.Name)
	end
	error("Unknown in-game action: " .. tostring(action))
end

return Match
