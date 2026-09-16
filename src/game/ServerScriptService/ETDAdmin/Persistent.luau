-- Server-only bridge to the existing profile services in both places.
-- Authorization and per-target request serialization belong to the admin server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Constants = require(ReplicatedStorage.Settings.Data.DataConstants)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)

local Persistent = {}
local MAX_ITEM_GRANT = 1000000
local MAX_ITEM_TOTAL = 1000000000
local CURRENCIES = {Coins=true, Gems=true, Blossom=true}
local MAX_CURRENCY_GRANT = 1000000
local MAX_CURRENCY_TOTAL = 1000000000
local MAX_TOWER_GRANT = 50
local MAX_OWNED_TOWERS = 2000
local MAX_TOWER_ID = 4294967294

local function integer(value, low, high, label)
	assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge,
		label .. " must be a finite number.")
	assert(value % 1 == 0 and value >= low and value <= high,
		label .. " must be an integer from " .. low .. " to " .. high .. ".")
	return value
end

local function identifier(value, catalog, label)
	assert(type(value) == "string" and #value > 0 and #value <= 160 and catalog[value] ~= nil,
		"Select a valid " .. label .. " from the catalog.")
	return value
end

local function sortedKeys(dictionary)
	local result = {}
	for name in pairs(dictionary) do
		if type(name) == "string" then
			table.insert(result, name)
		end
	end
	table.sort(result)
	return result
end

local function context(target, writing)
	assert(typeof(target) == "Instance" and target:IsA("Player") and target.Parent == Players,
		"The target player is no longer in this server.")
	local dataService = Registry:GetService("DataService")
	if writing and RunService:IsStudio() then
		assert(dataService.AdminStudioSandbox == true,
			"Studio profile sandbox is not enabled. Persistent actions are blocked until the mock profile store is configured.")
	end
	local profile = dataService:GetProfile(target)
	assert(profile and profile:IsActive() and type(profile.Data) == "table", "The target profile has not loaded yet.")
	assert(target.Parent == Players, "The target player left the server.")
	local data = profile.Data
	assert(type(data.OwnedTowers) == "table" and type(data.Inventory) == "table" and type(data.Inventory.Items) == "table",
		"The target profile has an unsupported inventory schema.")
	return dataService, data
end

local function findOwned(data, unitId)
	assert(type(unitId) == "string" and #unitId <= 32 and unitId:match("^t_%d+$"),
		"Select a tower instance from the target inventory.")
	local foundName, foundTower
	for name, copies in pairs(data.OwnedTowers) do
		if type(copies) == "table" and copies[unitId] then
			assert(foundTower == nil, "The profile contains a duplicate tower identifier.")
			foundName, foundTower = name, copies[unitId]
		end
	end
	assert(foundName and type(foundTower) == "table" and TowerData.ByName[foundName],
		"The selected tower is not owned by this player or is no longer in the catalog.")
	return foundName, foundTower
end

local function ownedCount(data)
	local count = 0
	for _, copies in pairs(data.OwnedTowers) do
		if type(copies) == "table" then
			for _ in pairs(copies) do count += 1 end
		end
	end
	return count
end

function Persistent.Catalog()
	return {
		towers = sortedKeys(TowerData.ByName),
		items = sortedKeys(ItemData.ByName),
		traits = sortedKeys(TraitData.ByName),
		currencies = sortedKeys(CURRENCIES),
		maxCurrencyGrant = MAX_CURRENCY_GRANT,
		maxTowerLevel = Constants.MAX_TOWER_LEVEL or 30,
		maxOwnedTowers = MAX_OWNED_TOWERS,
	}
end

function Persistent.Inventory(player)
	local _, data = context(player, false)
	local result = {}
	for name, copies in pairs(data.OwnedTowers) do
		if type(copies) == "table" and TowerData.ByName[name] then
			for key, tower in pairs(copies) do
				if type(key) == "string" and type(tower) == "table" then
					table.insert(result, {
						id = key,
						name = name,
						level = tower.Lv or 0,
						trait = tower.Trait or "None",
					})
				end
			end
		end
	end
	table.sort(result, function(a, b)
		if a.name == b.name then return a.id < b.id end
		return a.name < b.name
	end)
	return result
end

function Persistent.Perform(action, _actor, target, args)
	assert(type(args) == "table", "Action arguments are required.")
	assert(action == "GiveCurrency" or action == "GiveItem" or action == "GiveTower" or action == "TowerLevel" or action == "Trait" or action == "ResetData",
		"Unknown persistent action.")
	local service, data = context(target, true)
	local message
	if action == "GiveCurrency" then
		local currencyId = identifier(args.currencyId, CURRENCIES, "currency")
		local amount = integer(args.amount, 1, MAX_CURRENCY_GRANT, "Currency amount")
		local current = integer(data[currencyId], 0, MAX_CURRENCY_TOTAL, "Current currency balance")
		assert(current + amount <= MAX_CURRENCY_TOTAL, "The currency balance would exceed the limit.")
		local balance = service:AddData(target, currencyId, amount)
		assert(balance == current + amount, "The currency grant could not be applied.")
		message = ("Granted %d %s to %s. Balance: %d."):format(amount, currencyId, target.Name, balance)
	elseif action == "GiveItem" then
		local itemId = identifier(args.itemId, ItemData.ByName, "item")
		local amount = integer(args.amount, 1, MAX_ITEM_GRANT, "Amount")
		local current = integer(data.Inventory.Items[itemId] or 0, 0, MAX_ITEM_TOTAL, "Current item count")
		assert(current + amount <= MAX_ITEM_TOTAL, "The item total would exceed the inventory limit.")
		service:AddData(target, "Inventory", amount, "Items", itemId)
		message = ("Granted %d × %s to %s."):format(amount, itemId, target.Name)
	elseif action == "GiveTower" then
		local towerId = identifier(args.towerId, TowerData.ByName, "tower")
		local count = integer(args.count, 1, MAX_TOWER_GRANT, "Tower count")
		assert(ownedCount(data) + count <= MAX_OWNED_TOWERS, "The target inventory is full (2,000 towers).")
		local nextId = integer(data._NextId, 1, MAX_TOWER_ID - count, "Next tower ID")
		for _, copies in pairs(data.OwnedTowers) do
			if type(copies) == "table" then
				for id = nextId, nextId + count - 1 do
					assert(copies["t_" .. id] == nil, "The profile tower ID counter needs repair.")
				end
			end
		end
		for _ = 1, count do service:AddTower(target, towerId) end
		message = ("Granted %d × %s to %s."):format(count, towerId, target.Name)
	elseif action == "TowerLevel" then
		local level = integer(args.level, 0, Constants.MAX_TOWER_LEVEL or 30, "Tower level")
		local name, tower = findOwned(data, args.unitId)
		local previousLevel = tower.Lv or 0
		service:UpdateData(target, "OwnedTowers", level, name, args.unitId, "Lv")
		service:UpdateData(target, "OwnedTowers", 0, name, args.unitId, "Exp")
		service:FireChanged(target, "TowerExpChanged", {
			TowerName = name, TowerKey = args.unitId, Exp = 0,
			Level = level, HasLevelUp = level > previousLevel,
		})
		message = ("Set %s (%s) to level %d."):format(name, args.unitId, level)
	elseif action == "Trait" then
		local traitId = identifier(args.traitId, TraitData.ByName, "trait")
		local name = findOwned(data, args.unitId)
		service:AdjustTower(target, name, args.unitId, "Trait", traitId)
		message = ("Set %s (%s) trait to %s."):format(name, args.unitId, traitId)
	else
		-- The admin server must require confirmation before dispatch.
		-- ClearData replaces only profile.Data; the active session lock is preserved.
		-- Mirror removals before re-adding the normal starter inventory.
		local oldTowers = data.OwnedTowers
		service:ClearData(target)
		for name, copies in pairs(oldTowers) do
			if TowerData.ByName[name] and type(copies) == "table" then
				for key in pairs(copies) do
					local numericId = type(key) == "string" and tonumber(key:match("^t_(%d+)$"))
					if numericId then
						service:FireChanged(target, "OwnedTowersRemoved", { towerName = name, towerKeyId = numericId })
					end
				end
			end
		end
		local resetData = service:GetData(target)
		assert(resetData and resetData ~= data, "The profile reset failed.")
		-- Use UpdateData so leaderstats and currency observers refresh too.
		for _, key in ipairs({ "Coins", "Gems", "Blossom", "Level", "Exp", "Quests", "Inventory", "Loadout" }) do
			if resetData[key] ~= nil then service:UpdateData(target, key, resetData[key]) end
		end
		if TowerData.ByName[Constants.STARTER_TOWER] then
			local starterKey = "t_" .. resetData._NextId
			service:AddTower(target, Constants.STARTER_TOWER)
			service:UpdateData(target, "_StarterTowerReceived", true)
			service:UpdateData(target, "Loadout", { Name = Constants.STARTER_TOWER, Key = starterKey }, "1")
		end
		message = ("Reset %s's profile and restored the starter tower. Deployed match towers are unchanged; rejoin for a fresh match."):format(target.Name)
	end
	service:SaveData(target)
	return message
end

return Persistent
