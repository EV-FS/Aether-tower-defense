--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ButtonEffects = require(ReplicatedStorage.Shared.Modules.UI.ButtonEffects)
local UIController = require(script.Parent.UIController)

--/Fusion setup
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local scope = Fusion:scoped()

--/Variables
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HoverState = {
	Inventory = scope:Value(false),
	Store = scope:Value(false),
	Quest = scope:Value(false),
	Settings = scope:Value(false),
	Index = scope:Value(false),
	Trade = scope:Value(false),
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function setupButtonHover(button: GuiButton, hoverState, toggleName: string)
	local description = button:WaitForChild("Description")

	local pos = scope:Spring(
		scope:Computed(function(use)
			return if use(hoverState) then UDim2.fromScale(1.02, 0.5) else UDim2.fromScale(0.9, 0.5)
		end),
		15,
		0.9
	)

	local trans = scope:Spring(
		scope:Computed(function(use)
			return if use(hoverState) then 0 else 1
		end),
		30,
		1
	)

	scope:Hydrate(description)({
		Position = pos,
		BackgroundTransparency = trans,
	})

	local textLabel = description:FindFirstChild("TextLabel")
	if textLabel then
		scope:Hydrate(textLabel)({
			[Children] = scope:New("UIStroke")({
				Transparency = trans,
				Thickness = 0.1,
			}),
			TextTransparency = trans,
		})
	end

	scope:Hydrate(button)({
		[OnEvent("MouseEnter")] = function()
			hoverState:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hoverState:set(false)
		end,
		[OnEvent("MouseButton1Click")] = function()
			UIController:Toggle(toggleName)
		end,
	})
end

-------------------------------------------------
--// ButtonController
-------------------------------------------------
local ButtonController = {}

function ButtonController.Init()
	local mainGui = playerGui:WaitForChild("MainGui")
	local hud = mainGui:WaitForChild("Button")

	ButtonController.InventoryButton = hud:WaitForChild("Inventory")
	ButtonController.StoreButton = hud:WaitForChild("Store")
	ButtonController.QuestButton = hud:WaitForChild("Quest")
	ButtonController.SettingsButton = hud:WaitForChild("Settings")
	ButtonController.IndexButton = hud:WaitForChild("Index")
	ButtonController.TradeButton = hud:WaitForChild("Trade")

	for _, button in ButtonController do
		if typeof(button) == "Instance" and button:IsA("GuiButton") then
			ButtonEffects.ApplyPressEffect(button)
		end
	end

	ButtonController:Hydrate()
end

function ButtonController:Hydrate()
	setupButtonHover(self.InventoryButton, HoverState.Inventory, "Inventory")
	setupButtonHover(self.StoreButton, HoverState.Store, "Store")
	setupButtonHover(self.QuestButton, HoverState.Quest, "Quest")
	setupButtonHover(self.SettingsButton, HoverState.Settings, "Settings")
	setupButtonHover(self.IndexButton, HoverState.Index, "Index")
	setupButtonHover(self.TradeButton, HoverState.Trade, "Trade")
end

return ButtonController
