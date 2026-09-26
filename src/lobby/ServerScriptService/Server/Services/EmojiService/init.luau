local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local Net = require(ReplicatedStorage.Shared.Net.server)

local EMOJI_COOLDOWN = 0.5
local LOADOUT_COOLDOWN = 0.15
local MAX_SLOTS = 4
local LOADOUT_REMOTE_NAME = "EmojiLoadoutAction"

local lastEmojiTime: { [Player]: number } = {}
local lastLoadoutTime: { [Player]: number } = {}
local DataService

local EmojiService = {}

function EmojiService.ShowEmoji(player: Player, emojiId: string): boolean
	local emojiConfig = EmojiData.ByName[emojiId]
	if not emojiConfig then
		return false
	end
	local playerData = DataService:GetData(player)
	if not playerData or not playerData.Inventory or not playerData.Inventory.Emojis
		or (tonumber(playerData.Inventory.Emojis[emojiId]) or 0) <= 0 then
		return false
	end
	local equipped = false
	for _, equippedId in playerData.EmojiLoadout or {} do
		if equippedId == emojiId then equipped = true; break end
	end
	if not equipped then return false end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local now = os.clock()
	local lastUsed = lastEmojiTime[player] or -math.huge
	if now - lastUsed < EMOJI_COOLDOWN then
		return false
	end
	lastEmojiTime[player] = now

	Net.EmojiService.EmojiShown.FireAll({
		Player = player,
		EmojiId = emojiId,
	})
	return true
end

function EmojiService.UpdateLoadout(player: Player, request: any)
	if type(request) ~= "table" then return { Success = false, Message = "Invalid emoji request." } end
	local slot = request.Slot
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > MAX_SLOTS then
		return { Success = false, Message = "Invalid emoji slot." }
	end
	local now = os.clock()
	if now - (lastLoadoutTime[player] or -math.huge) < LOADOUT_COOLDOWN then
		return { Success = false, Message = "Please wait before changing another slot." }
	end
	lastLoadoutTime[player] = now
	local data = DataService:GetData(player)
	if not data then return { Success = false, Message = "Your data is still loading." } end
	local loadout = table.clone(data.EmojiLoadout or {})
	if request.Action == "Unequip" then
		loadout[tostring(slot)] = nil
		loadout[slot] = nil
	elseif request.Action == "Equip" then
		local emojiId = request.EmojiId
		if type(emojiId) ~= "string" or not EmojiData.ByName[emojiId]
			or not data.Inventory or not data.Inventory.Emojis
			or (tonumber(data.Inventory.Emojis[emojiId]) or 0) <= 0 then
			return { Success = false, Message = "You do not own this emoji." }
		end
		for existingSlot, equippedId in loadout do
			if equippedId == emojiId then loadout[existingSlot] = nil end
		end
		loadout[tostring(slot)] = emojiId
		loadout[slot] = nil
	else
		return { Success = false, Message = "Invalid emoji action." }
	end
	local saved = DataService:UpdateData(player, "EmojiLoadout", loadout)
	if type(saved) ~= "table" then
		return { Success = false, Message = "Your emoji slots could not be saved." }
	end
	return { Success = true, Message = if request.Action == "Equip" then `Equipped to slot {slot}.` else `Slot {slot} cleared.`, Loadout = saved }
end

function EmojiService.Init(services)
	DataService = services:GetService("DataService")
end

EmojiService.Dependencies = { "DataService" }

function EmojiService.Start()
	local folder = ReplicatedStorage:FindFirstChild("RuntimeRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RuntimeRemotes"
		folder.Parent = ReplicatedStorage
	end
	local remote = folder:FindFirstChild(LOADOUT_REMOTE_NAME)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = LOADOUT_REMOTE_NAME
		remote.Parent = folder
	end
	assert(remote:IsA("RemoteFunction"), "Emoji loadout remote must be a RemoteFunction")
	remote.OnServerInvoke = function(player: Player, request: any)
		return EmojiService.UpdateLoadout(player, request)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastEmojiTime[player] = nil
		lastLoadoutTime[player] = nil
	end)

	Net.EmojiService.RequestShowEmoji.On(function(player: Player, data: any): boolean
		if type(data) ~= "table" or type(data.EmojiId) ~= "string" then return false end
		return EmojiService.ShowEmoji(player, data.EmojiId)
	end)
end

return EmojiService
