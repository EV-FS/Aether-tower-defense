local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeData = require(script.Codes)

local DataService

local REMOTES_FOLDER_NAME = "RuntimeRemotes"
local REDEEM_REMOTE_NAME = "RedeemCode"
local REQUEST_COOLDOWN = 0.75
local MAX_CODE_LENGTH = 40
local lastRequestAt: { [Player]: number } = {}
local processing: { [Player]: boolean } = {}
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

local function describeRewards(rewards): string
	local descriptions = {}
	for _, currencyName in { "Coins", "Gems", "Blossom" } do
		local amount = rewards[currencyName]
		if amount then
			table.insert(descriptions, `{amount} {currencyName}`)
		end
	end
	for _, emoteName in rewards.Emotes or {} do
		table.insert(descriptions, `{emoteName} emote`)
	end
	return table.concat(descriptions, " + ")
end

local function redeemLoaded(player: Player, code: string, definition, unixTime: number)
	local playerData = DataService:GetData(player)
	if not playerData then
		return { Success = false, Message = "Your data is still loading. Try again." }
	end

	local redeemedCodes = playerData.RedeemedCodes
	if type(redeemedCodes) ~= "table" then
		assert(DataService:UpdateData(player, "RedeemedCodes", {}) ~= nil, "Failed to initialize redeemed codes")
		redeemedCodes = playerData.RedeemedCodes
	end
	if redeemedCodes[code] then
		return { Success = false, Message = "You already redeemed this code." }
	end

	local rewards = definition.Rewards
	-- Reserve the code before granting rewards so an interrupted grant cannot be
	-- repeated for extra currency. The per-player lock stays active through this write.
	assert(DataService:UpdateData(player, "RedeemedCodes", unixTime, code) == unixTime,
		"Failed to reserve redeemed code")
	for _, currencyName in { "Coins", "Gems", "Blossom" } do
		local amount = rewards[currencyName]
		if amount then
			assert(DataService:AddData(player, currencyName, amount) ~= nil, `Failed to grant {currencyName}`)
		end
	end
	for _, emoteName in rewards.Emotes or {} do
		assert(DataService:AddData(player, "Inventory", 1, "Emotes", emoteName) ~= nil,
			`Failed to grant emote {emoteName}`)
	end

	return {
		Success = true,
		Message = `Code redeemed! You received {describeRewards(rewards)}.`,
	}
end

function CodeService:Redeem(player: Player, rawCode: any)
	if processing[player] then
		return { Success = false, Message = "Please wait before trying again." }
	end

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
		not definition
		or definition.Enabled == false
		or (definition.StartsAt and unixTime < definition.StartsAt)
		or (definition.ExpiresAt and unixTime >= definition.ExpiresAt)
	then
		return { Success = false, Message = "This code is invalid or expired." }
	end

	processing[player] = true
	local ok, result = pcall(redeemLoaded, player, code, definition, unixTime)
	processing[player] = nil
	if not ok then
		warn(`[CodeService] Failed to redeem {code} for {player.UserId}: {tostring(result)}`)
		return { Success = false, Message = "This code is temporarily unavailable. Please contact support if the issue persists." }
	end
	return result
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
		processing[player] = nil
	end)
end

return CodeService
