local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local aether = Workspace:WaitForChild("Aether", 5)

local Part = aether:WaitForChild("Part", 5)


local prompt = Part:WaitForChild("ProximityPrompt", 5)

local DialogueService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DialogueService"))

local function onTriggered(player)
    DialogueService.StartDialogue(player, "Aether")
end

prompt.Triggered:Connect(onTriggered)