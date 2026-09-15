local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local requestEvent = ReplicatedStorage:WaitForChild("RequestAFKTeleport")
local requested = false

player.Idled:Connect(function()
	if RunService:IsStudio() or requested then
		return
	end

	requested = true
	(requestEvent :: RemoteEvent):FireServer()

	-- Allow another request if every server-side retry failed. Successful
	-- teleports destroy this LocalScript before the cooldown expires.
	task.delay(15, function()
		requested = false
	end)
end)
