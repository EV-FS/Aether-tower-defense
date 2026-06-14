--/Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local Slot = require(script.Components.Slot)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)
local InputService

local create = Vide.create
local source = Vide.source
local read = Vide.read

--/UI States
local Loadout = source({})
local OwnedTowers = source({})

-------------------------------------------------
--// TowerLoadout
-------------------------------------------------
local TowerLoadout = {}

function TowerLoadout.RenderUI()
	local slots = {}

	for i = 1, 5 do
		table.insert(
			slots,
			Slot({
				slotNumber = i,
				loadout = Loadout,
				ownedTowers = OwnedTowers,
				Activated = function()
					TowerLoadout.RequestSpawn(i)
				end,
			})
		)
	end

	return create("Frame")({
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0.07, 50),
		ZIndex = 5,

		create("Frame")({
			Name = "TowerSlots",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.74, 1),
			ZIndex = 2,

			create("UIListLayout")({
				Name = "UIListLayout",
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(-0.005, 0),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Wraps = true,
			}),

			unpack(slots),
		}),

		create("Frame")({
			Name = "Background",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.2,
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(4.8, 0.4),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			create("UIGradient")({
				Name = "UIGradient",
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}),
	})
end

function TowerLoadout.RequestSpawn(slotIndex: number)
	local currentLoadout = read(Loadout)
	local tower = currentLoadout[tostring(slotIndex)] or currentLoadout[slotIndex]
	if tower then
		local towerName = tower.Name or tower.towerName
		local towerKey = tower.Key or tower.towerKey

		ClientSignals.SpawnRequested:Fire(towerName, towerKey)
	end
end

function TowerLoadout.Init()
	InputService = ServiceRegistry:GetService("InputService")
end

function TowerLoadout.Start()
	local playerLoadout = Net.DataService.GetDataValue.Invoke("Loadout"):expect()
	if playerLoadout then
		Loadout(playerLoadout)
	end

	local playerOwnedTowers = Net.DataService.GetDataValue.Invoke("OwnedTowers"):expect()
	if playerOwnedTowers then
		OwnedTowers(playerOwnedTowers)
	end

	local iScope = InputService.NewScope
	local iAction = InputService.NewAction
	local iInfo = InputService.NewInfo

	local PlacementScope = iScope("LoadoutInput", {
		iAction("Placement_1", iInfo({ Enum.KeyCode.One })),
		iAction("Placement_2", iInfo({ Enum.KeyCode.Two })),
		iAction("Placement_3", iInfo({ Enum.KeyCode.Three })),
		iAction("Placement_4", iInfo({ Enum.KeyCode.Four })),
		iAction("Placement_5", iInfo({ Enum.KeyCode.Five })),
	}):Enable()

	for i = 1, 5 do
		PlacementScope.Actions[`Placement_{i}`].Began:Connect(function()
			TowerLoadout.RequestSpawn(i)
		end)
	end
end

return TowerLoadout
