local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local LoadoutSlot = require(ReplicatedStorage.UI.Components.LoadoutSlot)

local create = Vide.create

local MAX_LOADOUT_SIZE = 5
local INVENTORY_VIEW_ID = "InventoryFrame"

local InventoryClient
local UIController

local LoadoutUI = {}

function LoadoutUI.RenderUI()
	local slots = table.create(MAX_LOADOUT_SIZE)

	for index = 1, MAX_LOADOUT_SIZE do
		slots[index] = LoadoutSlot({
			slotNumber = index,
			loadout = InventoryClient.Loadout,
			Activated = function()
				UIController:Open(INVENTORY_VIEW_ID)
			end,
		})
	end

	return create("Frame")({
		Name = "LoadoutUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,

		create("Frame")({
			Name = "Slots",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			create("Frame")({
				Name = "Loadout",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = false,
				Position = UDim2.fromScale(0.5, 0.928),
				Size = UDim2.fromScale(1, 0.140329),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Wraps = true,
				}),

				unpack(slots),
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.42478,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),
		}),
	})
end

function LoadoutUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function LoadoutUI.Start()
	InventoryClient.FetchLoadout()
end

return LoadoutUI
