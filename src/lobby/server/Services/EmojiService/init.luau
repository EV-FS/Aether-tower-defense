local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local Net = require(ReplicatedStorage.Shared.Net.server)

local EMOJI_COOLDOWN = 1

local lastEmojiTime: { [Player]: number } = {}

local EmojiService = {}

function EmojiService.ShowEmoji(player: Player, emojiId: string): boolean
	local emojiConfig = EmojiData.ByName[emojiId]
	if not emojiConfig or emojiConfig.Image == "" then
		warn(`[EmojiService] Invalid emoji requested by {player.Name}: {emojiId}`)
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local now = os.clock()
	local lastUsed = lastEmojiTime[player] or 0
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

function EmojiService.Init() end

function EmojiService.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastEmojiTime[player] = nil
	end)

	Net.EmojiService.RequestShowEmoji.On(function(player: Player, data: { EmojiId: string }): boolean
		return EmojiService.ShowEmoji(player, data.EmojiId)
	end)
end

return EmojiService
