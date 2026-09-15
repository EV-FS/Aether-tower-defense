-- src/Settings/Data/NpcDialogueData.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCS = ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Data"):WaitForChild("NPCS")

return {
	["WanderingMerchant"] = require(NPCS:WaitForChild("WanderingMerchant")),
}

