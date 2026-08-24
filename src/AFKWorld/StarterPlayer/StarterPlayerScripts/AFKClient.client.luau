local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AFK_PLACE_ID = 85894813807831
local player = Players.LocalPlayer
local teleporting = false

player.Idled:Connect(function()
	if RunService:IsStudio() or teleporting then
		return
	end

	teleporting = true
	local success, err = pcall(function()
		TeleportService:Teleport(AFK_PLACE_ID, player)
	end)
	if not success then
		warn(`[AFKWorld] Failed to refresh idle session: {err}`)
		teleporting = false
	end
end)
