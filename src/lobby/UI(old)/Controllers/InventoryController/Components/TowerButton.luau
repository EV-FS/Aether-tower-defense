local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)

local State = require(script.Parent.Parent.State)
local HoverTracker = require(script.Parent.Parent.HoverTracker)
local Shared = require(script.Parent.Shared)

return function(entry, index)
	local isEquipped = Vide.derive(function()
		local e = entry()
		local equippedSlots = State.EquippedSlots()
		for _, tower in ipairs(e.Stack.Towers) do
			local id = State.generateTowerId(e.Name, tower.Key)
			if id and equippedSlots[id] then
				return true
			end
		end
		return false
	end)

	local towerInfo = Vide.derive(function()
		return TowerData.ByName[entry().Name]
	end)

	local rarityColor = Vide.derive(function()
		local info = towerInfo()
		return info and RarityColor[info.Rarity] or State.COLORS.DEFAULT
	end)

	local outlineColor = Vide.derive(function()
		return rarityColor()
	end)

	local isVisible = Vide.derive(function()
		local e = entry()
		local search = string.lower(State.SearchText())
		return search == "" or string.find(string.lower(e.Name), search, 1, true) ~= nil
	end)

	local isSelected = Vide.derive(function()
		local selected = State.SelectedTower()
		local e = entry()
		return selected and selected.Stack == e.Stack
	end)

	return Vide.create("ImageButton")({
		Name = Vide.derive(function()
			return tostring(entry().Key)
		end),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Modal = true,
		Size = UDim2.fromScale(0.24, 0.24),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = isVisible,
		ZIndex = function()
			return isSelected() and 3 or 1
		end,

		Vide.create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.9),

			Shared.Corner(UDim.new(0.12, 0)),
			Vide.create("UIStroke")({
				Name = "InnerOutline",
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = function()
					if isEquipped() then
						return State.COLORS.EQUIP
					end
					return isSelected() and Color3.new(1, 1, 1) or Color3.fromRGB(123, 123, 123)
				end,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.03,
			}),
			Vide.create("UIStroke")({
				Name = "Outline",
				Color = outlineColor,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.03,
				Vide.create("UIGradient")({
					Color = function()
						local baseColor = outlineColor()
						local darkColor = Color3.new(baseColor.R * 0.3, baseColor.G * 0.3, baseColor.B * 0.3)
						return ColorSequence.new({
							ColorSequenceKeypoint.new(0, baseColor),
							ColorSequenceKeypoint.new(1, darkColor),
						})
					end,
					Rotation = 90,
				}),
			}),
			Vide.create("ImageLabel")({
				Name = "TowerImage",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = function()
					local info = towerInfo()
					return info and info.TowerImage or ""
				end,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1.15385, 1.16923),
				Vide.create("UIAspectRatioConstraint")({}),
			}),
			Vide.create("TextLabel")({
				Name = "Cost",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.18769, 0.710769),
				Size = UDim2.fromScale(0.766154, 0.184615),
				Text = function()
					local info = towerInfo()
					return info and info.Stats[0] and `\${info.Stats[0].Cost}` or "$0"
				end,
				TextColor3 = Color3.fromRGB(174, 255, 0),
				TextScaled = true,
				ZIndex = 2,
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 3.32 }),
				Vide.create("UIStroke")({ Thickness = 2 }),
			}),
			Vide.create("TextLabel")({
				Name = "Level",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.0731206, 0.301373),
				Size = UDim2.fromScale(0.612923, 0.138462),
				Text = function()
					return `Lv.{entry().Data and entry().Data.Lv or 0}`
				end,
				TextColor3 = Color3.fromRGB(255, 170, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
				Vide.create("UIAspectRatioConstraint")({ AspectRatio = 3.32 }),
				Vide.create("UIStroke")({ Thickness = 2 }),
			}),
			Vide.create("TextLabel")({
				Name = "NameText",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.08, 0.078),
				Size = UDim2.fromScale(0.782, 0.2),
				Text = function()
					return entry().Name
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 99,
				Shared.Stroke(0.1, Color3.new(0, 0, 0), Enum.StrokeSizingMode.ScaledSize),
			}),
			Vide.create("ImageLabel")({
				Name = "CountFrame",
				BackgroundTransparency = 1,
				Image = "rbxassetid://130386539956710",
				ImageColor3 = rarityColor,
				Position = UDim2.fromScale(0.75, -0.1),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.35, 0.35),
				Visible = function()
					return entry().Count() > 1
				end,
				Vide.create("UIAspectRatioConstraint")({}),
				Vide.create("TextLabel")({
					Name = "CountText",
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1.01,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.475, 0.5),
					RichText = true,
					Size = UDim2.fromScale(0.75, 0.45),
					Text = function()
						return `x{entry().Count()}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Shared.Stroke(0.1, Color3.new(0, 0, 0), Enum.StrokeSizingMode.ScaledSize),
				}),
			}),
		}),
		Activated = function()
			local e = entry()
			local rep = State.getRepresentativeTower(e.Name, e.Stack, State.EquippedSlots())
			if rep then
				State.SelectedTower({
					Name = e.Name,
					Key = rep.Key,
					Data = rep.Data,
					Stack = e.Stack,
				})
			end
		end,
		MouseEnter = function()
			local e = entry()
			local rep = State.getRepresentativeTower(e.Name, e.Stack, State.EquippedSlots())
			if rep then
				if not State.ExistCounts[e.Name] then
					State.ExistCounts[e.Name] = Vide.source(-1)
					Net.GlobalExistService.GetCount
						.Invoke({ category = "Towers", itemName = e.Name })
						:andThen(function(count)
							State.ExistCounts[e.Name](count)
						end)
						:catch(function()
							State.ExistCounts[e.Name](-2)
						end)
				end

				HoverTracker.Start({ Name = e.Name, Data = rep.Data })
			end
		end,
		MouseLeave = function()
			HoverTracker.Stop()
		end,
	})
end
