local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive
local spring = Vide.spring

return function(props: { Name: any, Health: any, MaxHealth: any })
	local function getMaxHealth()
		return typeof(props.MaxHealth) == "function" and props.MaxHealth() or props.MaxHealth
	end

	local function getHealth()
		return typeof(props.Health) == "function" and props.Health() or props.Health
	end

	local function getName()
		return typeof(props.Name) == "function" and props.Name() or props.Name
	end

	local healthRatio = derive(function()
		local currentHealth = getHealth()
		if not currentHealth then
			return 0
		end
		return math.clamp(currentHealth / getMaxHealth(), 0, 1)
	end)
	
	local animatedRatio = spring(healthRatio, 0.2, 0.8)

	local healthText = derive(function()
		local currentHealth = getHealth()
		return `{NumberUtils.FormatComma(math.floor(currentHealth))}/{NumberUtils.FormatComma(getMaxHealth())}`
	end)

	return create("Frame")({
		Name = "Template",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.257583, 0),
		Size = UDim2.new(0.5, 25, 0.4, 5),

		create("CanvasGroup")({
			Name = "Background",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(21, 21, 21),
			Position = UDim2.fromScale(0.53, 0.663),
			Size = UDim2.fromScale(0.75, 0.425),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.2,
			}),

			create("Frame")({
				Name = "BarFrame",
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(animatedRatio(), 1)
				end,

				create("Frame")({
					Name = "LowerBar",
					BackgroundColor3 = Color3.fromRGB(154, 0, 0),
					BorderColor3 = Color3.new(),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.493645),
					Size = UDim2.fromScale(1, 0.506355),
				}),
			}),

			create("TextLabel")({
				Name = "Health",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.521046, 0.5),
				RichText = true,
				Size = UDim2.fromScale(0.239026, 0.8),
				Text = healthText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 3,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.12,
				}),
			}),

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(1, 0),
			}),

			create("Frame")({
				Name = "Grids",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(6.06262e-08, 4.70776e-07),
				Size = UDim2.fromScale(1, 1),

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.1, 0),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Wraps = true,
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),

				create("Frame")({
					Name = "Grid",
					BackgroundColor3 = Color3.new(),
					Size = UDim2.fromScale(0.004, 1),
				}),
			}),
		}),

		create("TextLabel")({
			Name = "Name",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.425, 0.175),
			RichText = true,
			Size = UDim2.fromScale(0.515, 0.028),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Text = getName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.12,
			}),
		}),

		create("Frame")({
			Name = "Frame",
			BackgroundColor3 = Color3.fromRGB(162, 162, 162),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.09, -0.158),
			Size = UDim2.fromScale(0.066, 0.066),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 3,

			create("ImageLabel")({
				Name = "ImageLabel",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://84234420733416",
				Position = UDim2.fromScale(0.5, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1.2, 1.2),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.07,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 114, 116)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(98, 29, 32)),
				}),
				Rotation = 90,
			}),
		}),
	})
end
