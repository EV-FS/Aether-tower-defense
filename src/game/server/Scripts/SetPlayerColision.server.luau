local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local function PlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		CharacterUtils.SetCollisionGroup(character, "Player")
	end)
end

for _, player in Players:GetPlayers() do
	PlayerAdded(player)
end

Players.PlayerAdded:Connect(PlayerAdded)
