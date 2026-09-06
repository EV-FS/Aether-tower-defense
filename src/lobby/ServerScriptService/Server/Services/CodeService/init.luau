local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeData = require(ReplicatedStorage.Settings.Data.CodeData)

local DataService

local REMOTES_FOLDER_NAME = "RuntimeRemotes"
local REDEEM_REMOTE_NAME = "RedeemCode"
local REQUEST_COOLDOWN = 0.75
local MAX_CODE_LENGTH = 40
local VALID_REWARDS = {
	Coins = true,
	Gems = true,
	Blossom = true,
}

local lastRequestAt: { [Player]: number } = {}
local CodeService = {}

local function normalizeCode(value: any): string?
	if type(value) ~= "string" then
		return nil
	end

	local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
	if trimmed == "" or #trimmed > MAX_CODE_LENGTH then
		return nil
	end

	return string.upper(trimmed)
end

local function describeRewards(rewards: { [string]: number }): string
	local descriptions = {}
	for _, currencyName in { "Coins", "Gems", "Blossom" } do
		local amount = rewards[currencyName]
		if type(amount) == "number" and amount > 0 then
			table.insert(descriptions, `{amount} {currencyName}`)
		end
	end
	return table.concat(descriptions, " + ")
end

function CodeService:Redeem(player: Player, rawCode: any)
	local now = os.clock()
	local previousRequestAt = lastRequestAt[player]
	if previousRequestAt and now - previousRequestAt < REQUEST_COOLDOWN then
		return { Success = false, Message = "Please wait before trying again." }
	end
	lastRequestAt[player] = now

	local code = normalizeCode(rawCode)
	if not code then
		return { Success = false, Message = "Enter a valid code." }
	end

	local definition = CodeData[code]
	local unixTime = os.time()
	if
		type(definition) ~= "table"
		or definition.Enabled == false
		or (definition.StartsAt and unixTime < definition.StartsAt)
		or (definition.ExpiresAt and unixTime >= definition.ExpiresAt)
	then
		return { Success = false, Message = "This code is invalid or expired." }
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return { Success = false, Message = "Your data is still loading. Try again." }
	end

	local redeemedCodes = playerData.RedeemedCodes
	if type(redeemedCodes) ~= "table" then
		DataService:UpdateData(player, "RedeemedCodes", {})
		redeemedCodes = playerData.RedeemedCodes
	end
	if redeemedCodes[code] then
		return { Success = false, Message = "You already redeemed this code." }
	end

	local rewards = definition.Rewards
	if type(rewards) ~= "table" then
		return { Success = false, Message = "This code has no available rewards." }
	end

	local hasReward = false
	for currencyName, amount in rewards do
		if
			VALID_REWARDS[currencyName]
			and type(amount) == "number"
			and amount > 0
			and amount <= 1_000_000_000
			and amount % 1 == 0
		then
			hasReward = true
		else
			warn(`[CodeService] Invalid reward in code {code}: {currencyName} = {tostring(amount)}`)
			return { Success = false, Message = "This code is temporarily unavailable." }
		end
	end
	if not hasReward then
		return { Success = false, Message = "This code has no available rewards." }
	end

	-- ProfileStore owns one active profile session, and this write occurs before any yield.
	-- This prevents two simultaneous requests from claiming the same code twice.
	DataService:UpdateData(player, "RedeemedCodes", unixTime, code)
	for currencyName, amount in rewards do
		DataService:AddData(player, currencyName, amount)
	end

	return {
		Success = true,
		Message = `Code redeemed! You received {describeRewards(rewards)}.`,
	}
end

function CodeService.Init(services)
	DataService = services:GetService("DataService")
end

CodeService.Dependencies = { "DataService" }

function CodeService.Start()
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local redeemRemote = remotesFolder:FindFirstChild(REDEEM_REMOTE_NAME)
	if not redeemRemote then
		redeemRemote = Instance.new("RemoteFunction")
		redeemRemote.Name = REDEEM_REMOTE_NAME
		redeemRemote.Parent = remotesFolder
	end
	assert(redeemRemote:IsA("RemoteFunction"), "RedeemCode runtime remote must be a RemoteFunction")

	redeemRemote.OnServerInvoke = function(player: Player, code: any)
		return CodeService:Redeem(player, code)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return CodeService
