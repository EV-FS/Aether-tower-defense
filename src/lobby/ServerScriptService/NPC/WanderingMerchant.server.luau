local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCs = Workspace:WaitForChild("NPCs")

local WanderingMerchant = NPCs:WaitForChild("WanderingMerchant", 5)

local Part = WanderingMerchant:WaitForChild("Part", 5)

local prompt = Part:WaitForChild("ProximityPrompt", 5)

local DialogueService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DialogueService"))

local function onTriggered(player)
	DialogueService.StartDialogue(player, "WanderingMerchant")
end

prompt.Triggered:Connect(onTriggered)
