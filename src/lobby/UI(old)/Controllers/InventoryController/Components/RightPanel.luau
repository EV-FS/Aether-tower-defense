local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local State = require(script.Parent.Parent.State)
local Shared = require(script.Parent.Shared)

return function(Controller)
	local selectedInfo = function()
		local selected = State.SelectedTower()
		return selected and TowerData.ByName[selected.Name] or nil
	end

	return Vide.create("Frame")({
		Name = "Right",
		BackgroundColor3 = Color3.fromRGB(13, 13, 13),
		Position = UDim2.fromScale(0.66, 0.0830491),
		Size = UDim2.fromScale(0.268297, 0.844783),

		Shared.Corner(UDim.new(0.05, 0)),
		Shared.Stroke(0.015, Color3.fromRGB(36, 36, 36), Enum.StrokeSizingMode.ScaledSize),

		Vide.create("TextLabel")({
			Name = "TowerName",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.ExtraBold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.0729737, 0.0519448),
			Size = UDim2.fromScale(0.891, 0.08),
			Text = function()
				return (State.SelectedTower() or {}).Name or "Select a Tower"
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Shared.Stroke(0.088, Color3.new(0, 0, 0), Enum.StrokeSizingMode.ScaledSize),
		}),
		Vide.create("TextLabel")({
			Name = "Rarity",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.ExtraBold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.0729737, 0.13),
			Size = UDim2.fromScale(0.798, 0.065),
			Text = function()
				return (selectedInfo() or {}).Rarity or ""
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Vide.create("UIGradient")({
				Color = function()
					local rarity = (selectedInfo() or {}).Rarity
					return State.RARITY_CONFIG[rarity] and State.RARITY_CONFIG[rarity].Colors
						or ColorSequence.new(State.COLORS.DEFAULT)
				end,
				Rotation = 90,
			}),
			Shared.Stroke(0.088, Color3.new(0, 0, 0), Enum.StrokeSizingMode.ScaledSize),
		}),
		Vide.create("ImageLabel")({
			Name = "TowerImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = function()
				return (selectedInfo() or {}).TowerImage or ""
			end,
			Position = UDim2.fromScale(0.485141, 0.439054),
			Size = UDim2.fromScale(0.670564, 0.461686),
			Visible = function()
				return State.SelectedTower() ~= nil
			end,
		}),
		Vide.create("TextButton")({
			Name = "ToggleEquip",
			BackgroundColor3 = Color3.fromRGB(0, 162, 255),
			Position = UDim2.fromScale(0.505, 0.88),
			Size = UDim2.fromScale(0.418296, 0.0898565),
			Visible = function()
				return State.SelectedTower() ~= nil
			end,
			Activated = function()
				Controller:ToggleEquip()
			end,
			Shared.Corner(UDim.new(0.12, 0)),
			Vide.create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				Size = UDim2.fromScale(1, 1),
				Text = function()
					local selected = State.SelectedTower()
					if not selected then
						return "Equip"
					end
					local id = State.generateTowerId(selected.Name, selected.Key)
					return id and State.EquippedSlots()[id] and "Unequip" or "Equip"
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Shared.Stroke(0.1, Color3.fromRGB(15, 60, 128), Enum.StrokeSizingMode.ScaledSize),
			}),
		}),
		Vide.create("TextButton")({
			Name = "Sell",
			BackgroundColor3 = Color3.fromRGB(255, 60, 0),
			Position = UDim2.fromScale(0.069, 0.88),
			Size = UDim2.fromScale(0.198305, 0.0898565),
			Visible = function()
				return State.SelectedTower() ~= nil
			end,
			Activated = function()
				local selected = State.SelectedTower()
				if selected then
					--Net.DataService.SellTower:Fire(selected.Key)
				end
			end,
			Shared.Corner(UDim.new(0.12, 0)),
			Vide.create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				Size = UDim2.fromScale(1, 1),
				Text = "Sell",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Shared.Stroke(0.1, Color3.fromRGB(128, 26, 15), Enum.StrokeSizingMode.ScaledSize),
			}),
		}),
		Vide.create("TextButton")({
			Name = "Lock",
			BackgroundColor3 = Color3.fromRGB(255, 170, 0),
			Position = UDim2.fromScale(0.288, 0.88),
			Size = UDim2.fromScale(0.198305, 0.0898565),
			Visible = function()
				return State.SelectedTower() ~= nil
			end,
			Activated = function()
				local selected = State.SelectedTower()
				if selected then
					--Net.DataService.LockTower:Fire(selected.Key)
				end
			end,
			Shared.Corner(UDim.new(0.12, 0)),
			Vide.create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				Size = UDim2.fromScale(1, 1),
				Text = "Lock",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Shared.Stroke(0.1, Color3.fromRGB(128, 92, 15), Enum.StrokeSizingMode.ScaledSize),
			}),
		}),
	})
end
