local prompt = game:GetService("Workspace"):WaitForChild("Untitled"):WaitForChild("Torso"):WaitForChild("Plane.008"):WaitForChild("ProximityPrompt")
local DialogueService = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DialogueService"))

local function onTriggered(player)
    DialogueService.StartDialogue(player, "NpcA")
end

prompt.Triggered:Connect(onTriggered)