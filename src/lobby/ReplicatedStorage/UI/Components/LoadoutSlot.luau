local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useRarityShine = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useRarityShine)

local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local RARITY_IMAGE_COLORS = {
	Common = Color3.fromRGB(236, 230, 230),
	Rare = Color3.fromRGB(47, 145, 231),
	Epic = Color3.fromRGB(228, 76, 255),
	Legendary = Color3.fromRGB(218, 56, 58),
	Mythic = Color3.fromRGB(255, 161, 67),
	Exclusive = Color3.fromRGB(154, 0, 5),
	Absolute = Color3.fromRGB(164, 246, 255),
}

export type Props = {
	slotNumber: number,
	loadout: () -> { [string | number]: { Name: string?, Key: string?, towerName: string? }? },
	Activated: (() -> ())?,
}

return function(props: Props)
	local tower = derive(function()
		local currentLoadout = props.loadout()
		return currentLoadout[tostring(props.slotNumber)] or currentLoadout[props.slotNumber]
	end)

	local towerName = derive(function()
		local equipped = tower()
		if not equipped then
			return ""
		end

		return equipped.Name or equipped.towerName or ""
	end)

	local hasTower = derive(function()
		return towerName() ~= ""
	end)

	local towerCost = derive(function()
		local towerInfo = TowerData.ByName[towerName()]
		local cost = towerInfo and towerInfo.Stats and towerInfo.Stats[0] and towerInfo.Stats[0].Cost or 0
		return `₩{NumberUtils.FormatComma(cost)}`
	end)

	local imageColor = derive(function()
		local towerInfo = TowerData.ByName[towerName()]
		return if towerInfo then RARITY_IMAGE_COLORS[towerInfo.Rarity] or Color3.new(1, 1, 1) else Color3.new(1, 1, 1)
	end)

	local rarity = derive(function()
		local towerInfo = TowerData.ByName[towerName()]
		return towerInfo and towerInfo.Rarity or "Common"
	end)

	local isHovered = source(false)
	local hoverTransparency = spring(function()
		return if isHovered() then 0.72 else 1
	end, 0.16, 0.82)
	local hoverStrokeTransparency = spring(function()
		return if isHovered() then 0.05 else 1
	end, 0.14, 0.8)
	local hoverRotation = spring(function()
		return if isHovered() then -1.5 else 0
	end, 0.18, 0.78)

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Image = "rbxassetid://87496848270095",
		ImageColor3 = imageColor,
		ImageTransparency = function()
			return if hasTower() then 0 else 0.2
		end,
		LayoutOrder = props.slotNumber,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = hoverRotation,
		Size = UDim2.fromScale(0.227, 0.935),
		ZIndex = 1,

		Activated = props.Activated,
		MouseEnter = function()
			isHovered(true)
		end,
		MouseLeave = function()
			isHovered(false)
		end,

		useButtonEffect(0.93, 1.07),

		create("UICorner")({
			Name = "HoverCorner",
			CornerRadius = UDim.new(0, 8),
		}),

		create("ImageLabel")({
			Name = "HoverHighlight",
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://87496848270095",
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = hoverTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.95),
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 8),
			}),
		}),

		create("UIStroke")({
			Name = "HoverStroke",
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
			Transparency = hoverStrokeTransparency,
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
		}),

		create("ImageLabel")({
			Name = "Level",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.013, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
			Visible = hasTower,
			ZIndex = 10,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 3.2,
			}),

			create("TextLabel")({
				Name = "TextLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.3, 0.489),
				Size = UDim2.fromScale(0.477775, 0.75514),
				Text = "레벨 1",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
					}),
					Rotation = 90,
				}),
			}),
		}),

		create("ImageLabel")({
			Name = "Trait",
			BackgroundTransparency = 1,
			Image = "rbxassetid://100463457721493",
			Position = UDim2.fromScale(0.64, 0.03),
			Size = UDim2.fromScale(0.359565, 0.31687),
			Visible = false,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
			}),
		}),

		create("TextLabel")({
			Name = "Price",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.108, 0.782623),
			Size = UDim2.fromScale(0.641, 0.2),
			Text = towerCost,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			Visible = hasTower,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
				}),
				Rotation = 90,
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
			Position = UDim2.fromScale(0.108, 0.618754),
			Size = UDim2.fromScale(0.848871, 0.172688),
			Text = towerName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			Visible = hasTower,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),

		TowerViewport({
			Name = "ViewportFrame",
			TowerName = towerName,
			AnimationName = "Idle",
			BackgroundTransparency = 1,
			CameraDirection = Vector3.new(0, 0.82, -0.88),
			FieldOfView = 26,
			FitPadding = 0.62,
			Position = UDim2.fromScale(0.11, 0.102),
			Size = UDim2.fromScale(0.784, 0.781),
			ZIndex = 5,
			Visible = hasTower,
		}),

		create("CanvasGroup")({
			Name = "CanvasGroup",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			GroupTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,

			create("UICorner")({
				Name = "ShineCorner",
				CornerRadius = UDim.new(0, 8),
			}),

			useRarityShine(rarity),
		}),

		create("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 228, 228)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 76, 76)),
			}),
			Rotation = 45,
		}),
	})
end

