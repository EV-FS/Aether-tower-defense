local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local spring = Vide.spring

local ButtonArrangementUI = {}
local UIController
local DialogueClient

type MenuButtonConfig = {
	Name: string,
	Label: string,
	Image: string,
	Icon: string,
	IconPosition: UDim2,
	IconSize: UDim2,
	IconAspectRatio: number,
	ShadowColor: Color3,
	LayoutOrder: number,
	Activated: (() -> ())?,
}

local MENU_BUTTONS: { MenuButtonConfig } = {
	{
		Name = "InventoryButton",
		Label = "인벤토리",
		Image = "rbxassetid://93619515456928",
		Icon = "rbxassetid://117877885546585",
		IconPosition = UDim2.fromScale(0.486774, 0.5),
		IconSize = UDim2.fromScale(0.927412, 0.84234),
		IconAspectRatio = 1.06,
		ShadowColor = Color3.fromRGB(191, 82, 49),
		LayoutOrder = 1,
	},
	{
		Name = "TradeButton",
		Label = "거래",
		Image = "rbxassetid://89053099166022",
		Icon = "rbxassetid://113361253033520",
		IconPosition = UDim2.fromScale(0.5, 0.5),
		IconSize = UDim2.fromScale(0.927412, 0.84234),
		IconAspectRatio = 0.99,
		ShadowColor = Color3.fromRGB(49, 191, 41),
		LayoutOrder = 2,
	},
	{
		Name = "ShopButton",
		Label = "상점",
		Image = "rbxassetid://120719208845179",
		Icon = "rbxassetid://111956663454997",
		IconPosition = UDim2.fromScale(0.45, 0.53),
		IconSize = UDim2.fromScale(0.810117, 0.726431),
		IconAspectRatio = 1.1,
		ShadowColor = Color3.fromRGB(191, 37, 37),
		LayoutOrder = 3,
	},
	{
		Name = "IndexButton",
		Label = "인덱스",
		Image = "rbxassetid://86848984512006",
		Icon = "rbxassetid://138577084954436",
		IconPosition = UDim2.fromScale(0.5, 0.5),
		IconSize = UDim2.fromScale(0.927412, 0.84234),
		IconAspectRatio = 1.28,
		ShadowColor = Color3.fromRGB(49, 63, 191),
		LayoutOrder = 4,
	},
	{
		Name = "QuestButton",
		Label = "퀘스트",
		Image = "rbxassetid://81544195469564",
		Icon = "rbxassetid://75286969875681",
		IconPosition = UDim2.fromScale(0.489078, 0.516645),
		IconSize = UDim2.fromScale(0.810117, 0.726431),
		IconAspectRatio = 1,
		ShadowColor = Color3.fromRGB(191, 163, 50),
		LayoutOrder = 5,
		Activated = function()
			if UIController then
				UIController:Toggle("Quest")
			end
		end,
	},
	{
		Name = "UnitButton",
		Label = "유닛",
		Image = "rbxassetid://100432247888014",
		Icon = "rbxassetid://122013500873045",
		IconPosition = UDim2.fromScale(0.488069, 0.515225),
		IconSize = UDim2.fromScale(0.759346, 0.821046),
		IconAspectRatio = 0.91,
		ShadowColor = Color3.fromRGB(174, 43, 191),
		LayoutOrder = 6,
		Activated = function()
			if UIController then
				UIController:Toggle("Units")
			end
		end,
	},
}

local function createMenuButton(config: MenuButtonConfig)
	local isInteractive = config.Activated ~= nil

	return create("ImageButton")({
		Name = config.Name,
		Active = isInteractive,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = config.Image,
		LayoutOrder = config.LayoutOrder,
		Selectable = isInteractive,
		Size = UDim2.fromScale(0.509, 0.173),

		Activated = config.Activated,

		useButtonEffect(0.93, 1.055),

		create("UIShadow")({
			Name = "UIShadow",
			BlurRadius = UDim.new(0, 20),
			Color = config.ShadowColor,
			Transparency = 0.5,
		}),

		create("ImageLabel")({
			Name = "ICON",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = config.Icon,
			Position = config.IconPosition,
			Size = config.IconSize,
			ZIndex = 9,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = config.IconAspectRatio,
			}),
		}),

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.0978223, 0.757618),
			Size = UDim2.fromScale(0.8, 0.242),
			Text = config.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 10,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),
	})
end

function ButtonArrangementUI.RenderUI()
	local function isMenuVisible(): boolean
		if UIController and UIController:IsExclusive() then
			return false
		end
		if DialogueClient and DialogueClient.IsOpen() then
			return false
		end
		if UIController and UIController:IsOpen("Dialogue") then
			return false
		end
		return true
	end

	local menuScale = spring(function()
		return if isMenuVisible() then 1 else 0.92
	end, 0.22, 0.82)

	local buttons = table.create(#MENU_BUTTONS)
	for _, config in MENU_BUTTONS do
		table.insert(buttons, createMenuButton(config))
	end

	return create("Frame")({
		Name = "ButtonArrangement",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.1, 0.5),
		Size = UDim2.fromScale(0.189397, 1),
		Visible = isMenuVisible,
		ZIndex = 2,

		create("UIScale")({
			Name = "MenuScale",
			Scale = menuScale,
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 0.34,
		}),

		create("UIGridLayout")({
			Name = "UIGridLayout",
			CellPadding = UDim2.fromScale(0.03, 0.006),
			CellSize = UDim2.fromScale(0.392, 0.13),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		unpack(buttons),
	})
end

function ButtonArrangementUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
end

return ButtonArrangementUI
