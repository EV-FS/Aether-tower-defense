local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)

local REMOTES_FOLDER_NAME = "RuntimeRemotes"
local REMOTE_NAME = "TraitRoll"
local REQUEST_COOLDOWN = 0.5
local MAX_TOWER_NAME_LENGTH = 80
local MAX_TOWER_KEY_ID = 4_294_967_295
local RANDOM = Random.new()

local DataService
local lastRequestAt: { [Player]: number } = {}
local TraitService = {}

local function response(success: boolean, message: string, extra: { [string]: any }?)
	local result = extra or {}
	result.Success = success
	result.Message = message
	return result
end

local function normalizeTowerKey(value: any): string?
	if typeof(value) ~= "string" and typeof(value) ~= "number" then return nil end
	local text = tostring(value)
	local idText = string.match(text, "^t_(%d+)$") or string.match(text, "^(%d+)$")
	local id = if idText then tonumber(idText) else nil
	if not id or id % 1 ~= 0 or id < 0 or id > MAX_TOWER_KEY_ID then return nil end
	return `t_{id}`
end

local function getRandomTrait(): string
	local totalWeight = 0
	for _, trait in TraitData.ByIndex do totalWeight += trait.Chance end
	local roll = RANDOM:NextNumber(0, totalWeight)
	local cursor = 0
	for _, trait in TraitData.ByIndex do
		cursor += trait.Chance
		if roll <= cursor then return trait.Name end
	end
	return TraitData.ByIndex[#TraitData.ByIndex].Name
end

function TraitService:RollTrait(player: Player, data: any)
	local now = os.clock()
	if lastRequestAt[player] and now - lastRequestAt[player] < REQUEST_COOLDOWN then
		return response(false, "Please wait before rolling again.")
	end
	lastRequestAt[player] = now

	if typeof(data) ~= "table" then return response(false, "Invalid trait request.") end
	local towerName = data.TowerName
	local towerKey = normalizeTowerKey(data.TowerKey)
	if typeof(towerName) ~= "string" or towerName == "" or #towerName > MAX_TOWER_NAME_LENGTH or not towerKey then
		return response(false, "Invalid unit selection.")
	end

	local playerData = DataService:GetData(player)
	if not playerData then return response(false, "Your data is still loading.") end
	local ownedTower = playerData.OwnedTowers[towerName] and playerData.OwnedTowers[towerName][towerKey]
	if typeof(ownedTower) ~= "table" then return response(false, "You do not own this unit.") end
	if (playerData.Gems or 0) < TraitData.RollCost then
		return response(false, `You need {TraitData.RollCost} Gems.`)
	end

	local gems = DataService:AddData(player, "Gems", -TraitData.RollCost)
	if gems == nil then return response(false, "Could not spend Gems.") end
	local newTrait = getRandomTrait()
	DataService:AdjustTower(player, towerName, towerKey, "Trait", newTrait)
	return response(true, `Rolled {newTrait}!`, {
		Trait = newTrait, Gems = gems, TowerName = towerName, TowerKey = towerKey,
	})
end

function TraitService.Init(services)
	DataService = services:GetService("DataService")
end

TraitService.Dependencies = { "DataService" }

function TraitService.Start()
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end
	local remote = remotesFolder:FindFirstChild(REMOTE_NAME)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = REMOTE_NAME
		remote.Parent = remotesFolder
	end
	assert(remote:IsA("RemoteFunction"), "TraitRoll runtime remote must be a RemoteFunction")
	remote.OnServerInvoke = function(player, data)
		return TraitService:RollTrait(player, data)
	end
	Players.PlayerRemoving:Connect(function(player) lastRequestAt[player] = nil end)
end

return TraitService
