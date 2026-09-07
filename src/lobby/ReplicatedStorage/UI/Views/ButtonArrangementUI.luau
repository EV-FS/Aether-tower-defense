local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local ButtonArrangementUI = {}
local UIController
local DialogueClient

type MenuButtonConfig = {
	Name: string,
	Label: string,
	Image: string,
	LayoutOrder: number,
	Activated: (() -> ())?,
	Icon: string?,
}

local MENU_BUTTONS: { MenuButtonConfig } = {
	{
		Name = "InventoryButton",
		Label = "인벤토리",
		Image = "rbxassetid://78824365403347",
		LayoutOrder = 1,
	},
	{
		Name = "TradeButton",
		Label = "거래",
		Image = "rbxassetid://101920175927849",
		LayoutOrder = 2,
	},
	{
		Name = "ShopButton",
		Label = "상점",
		Image = "rbxassetid://81803440554186",
		LayoutOrder = 3,
	},
	{
		Name = "IndexButton",
		Label = "인덱스",
		Image = "rbxassetid://135162687505077",
		LayoutOrder = 4,
	},
	{
		Name = "QuestButton",
		Label = "퀘스트",
		Image = "rbxassetid://83257230376880",
		LayoutOrder = 5,
	},
	{
		Name = "UnitButton",
		Label = "유닛",
		Image = "rbxassetid://76150462384511",
		Icon = "rbxassetid://96662802265325",
		LayoutOrder = 6,
		Activated = function()
			if UIController then
				UIController:Toggle("Inventory")
			end
		end,
	},
}

local function createMenuButton(config: MenuButtonConfig)
	local isInteractive = config.Activated ~= nil
	local isHovered = source(false)
	local hoverGlow = spring(function()
		return if isHovered() then 0.8 else 1
	end, 0.16, 0.82)

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
		MouseEnter = function()
			if isInteractive then
				isHovered(true)
			end
		end,
		MouseLeave = function()
			isHovered(false)
		end,

		useButtonEffect(0.93, 1.055),

		create("ImageLabel")({
			Name = "HoverGlow",
			BackgroundTransparency = 1,
			Image = config.Image,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = hoverGlow,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		}),

		if config.Icon then create("ImageLabel")({
			Name = "ICON",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = config.Icon,
			Position = UDim2.fromScale(0.498196, 0.5),
			Size = UDim2.fromScale(0.825, 0.580307),
			ZIndex = 9,
		}) else nil,

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.189005, 0.757618),
			Size = UDim2.fromScale(0.61743, 0.172688),
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
			CellPadding = UDim2.fromScale(-0.04, -0.015),
			CellSize = UDim2.fromScale(0.392, 0.133),
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
