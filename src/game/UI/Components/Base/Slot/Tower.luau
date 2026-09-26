local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local RigViewport = require(ReplicatedStorage.UI.Components.RigViewport)
type Reactive<T> = T | (() -> T)

type Props = {
	TowerName: Reactive<string>,
	TowerLevel: Reactive<number>?,
	TraitName: Reactive<string>?,
}

local create = Vide.create
local read = Vide.read
local derive = Vide.derive

return function(props: Props)
	local towerModel = derive(function()
		return ReplicatedStorage.Assets.Towers:FindFirstChild(read(props.TowerName))
	end)

	local idleAnimation = derive(function()
		local animations = ReplicatedStorage.Assets.Animations:FindFirstChild(read(props.TowerName))
		print(animations and animations:FindFirstChild("Idle"))

		return animations and animations:FindFirstChild("Idle")
	end)

	local towerPrice = derive(function()
		local towerInfo = TowerData.ByName[read(props.TowerName)]
		return towerInfo and towerInfo.Stats[0].Cost
	end)

	local traitInfo = derive(function()
		return TraitData.ByName[read(props.TraitName)]
	end)

	local traitGradientData = derive(function()
		return traitInfo() and RarityRegistry.Get(traitInfo().Rarity).Presentation
	end)

	return create("Frame")({
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.97),

		RigViewport({
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.99, 0.98),

			CenterOffset = Vector3.new(0, 0.6, 0),
			Rig = towerModel,
			UseWorldModel = true,
			Zoom = 1,

			Animation = idleAnimation,
			AutoPlay = true,
			AnimationLooped = true,
			AnimationFadeTime = 0,

			Child = {
				create("UICorner")({
					CornerRadius = UDim.new(0.1, 0),
				}),
				create("UIGradient")({
					Name = "UIGradient",
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.85, 0),
						NumberSequenceKeypoint.new(0.9, 0.45),
						NumberSequenceKeypoint.new(0.95, 0.75),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			},
		}),

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.107999, 0.618754),
			Size = UDim2.fromScale(0.84887, 0.172688),
			Text = props.TowerName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),

		create("ImageLabel")({
			Name = "Level",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.0129994, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
			ZIndex = 10,
			Visible = function()
				return read(props.TowerLevel) ~= nil
			end,

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
				Text = function()
					return `Lv. {read(props.TowerLevel)}`
				end,
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
			Image = function()
				return if traitInfo() then traitInfo().Image else ""
			end,
			Position = UDim2.fromScale(0.64, 0.03),
			Size = UDim2.fromScale(0.359565, 0.31687),
			Visible = function()
				return read(props.TraitName) ~= nil
			end,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
			}),

			create("UIGradient")({
				Name = "UIGradient",
				useColorSequenceCycle(function()
					return if traitGradientData() then traitGradientData().Gradient else ColorSequence.new(Color3.new())
				end, function()
					return if traitGradientData() then traitGradientData().ShimmerSpeed else 1
				end),

				Rotation = 45,
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
			Position = UDim2.fromScale(0.108, 0.75),
			Size = UDim2.fromScale(0.641, 0.2),
			Text = function()
				return `₩{NumberUtils.FormatComma(towerPrice() or 0)}`
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			Visible = function()
				return towerPrice() ~= nil
			end,

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
	})
end
