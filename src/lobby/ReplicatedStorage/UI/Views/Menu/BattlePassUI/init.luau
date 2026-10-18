local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PassTier = require(script.PassTier)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useButtonHoverEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonHoverEffect)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local UIController

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local effect = Vide.effect

local VIEW_ID = "BattlePass"
local END_AT = os.time() + 500000

local isVisible = source(false)
local currentTier = source(2)
local currentExp = source(8500)
local tierExp = source(10000)
local endLeft = source(END_AT - os.time())

local BattlePassUI = {}

function BattlePassUI.RenderUI()
	local animatedExp, setExpSpring = spring(currentExp, 0.75, 1)

	effect(function()
		if isVisible() then
			setExpSpring({ position = 0, velocity = 0 })
		end
	end)

	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,

		Position = spring(function()
			return if isVisible() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.55)
		end, 0.5, 0.6),

		Size = UDim2.fromScale(1, 1),
		Visible = isVisible,

		create("Frame")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(19, 19, 25),
			Position = UDim2.fromScale(0.49955, 0.510746),
			Size = UDim2.fromScale(0.553555, 0.475348),

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.05, 0),
				BottomRightRadius = UDim.new(0.05, 0),
				TopLeftRadius = UDim.new(0.05, 0),
				TopRightRadius = UDim.new(0.05, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.new(1, 1, 1),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.0075,
				ZIndex = 2,

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
					}),
					Rotation = 45,
				}),
			}),

			create("UIShadow")({
				Name = "UIShadow",
				BlurRadius = spring(function()
					return if isVisible() then UDim.new(0.06, 0) else UDim.new(0, 0)
				end, 0.5, 0.8),
				Color = Color3.fromRGB(255, 162, 0),
				Transparency = 0.5,
			}),

			create("UIStroke")({
				Name = "BlackStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.0185,
			}),

			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				Position = UDim2.fromScale(0.5, 0.857567),
				Size = spring(function()
					return if isVisible() then UDim2.fromScale(1, 0.00593472) else UDim2.fromScale(1, 0)
				end, 0.5, 0.5),
			}),

			create("Frame")({
				Name = "Bottom",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.00171821, 0.84273),
				Size = UDim2.fromScale(0.996564, 0.15727),
				ZIndex = 2,

				create("TextLabel")({
					Name = "Level",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.0265543, 0.366168),
					Size = UDim2.fromScale(0.161722, 0.369681),
					Text = function()
						return `Lv.{currentTier()}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 2,

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),
				}),

				create("CanvasGroup")({
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.105627, 0.419009),
					Size = UDim2.fromScale(0.485002, 0.283019),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(1, 0),
						BottomRightRadius = UDim.new(1, 0),
						TopLeftRadius = UDim.new(1, 0),
						TopRightRadius = UDim.new(1, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("Frame")({
						Name = "Expbar",
						BackgroundColor3 = Color3.fromRGB(81, 81, 81),
						ClipsDescendants = true,
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
							}),
							Rotation = 90,
						}),

						create("TextLabel")({
							Name = "EXP",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.16982, 0.00209554),
							Size = UDim2.fromScale(0.66055, 0.886793),
							Text = function()
								return `( {NumberUtils.FormatComma(math.round(animatedExp()))}/{NumberUtils.FormatComma(
									tierExp()
								)} EXP )`
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							ZIndex = 3,

							create("UIStroke")({
								Name = "UIStroke",
								StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
								Thickness = 0.12,
							}),
						}),

						create("Frame")({
							Name = "Bar",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							Position = UDim2.fromScale(0, 0.5),
							Size = function()
								return UDim2.fromScale(animatedExp() / tierExp(), 1)
							end,

							create("UICorner")({
								Name = "UICorner",
								BottomLeftRadius = UDim.new(1, 0),
								BottomRightRadius = UDim.new(1, 0),
								TopLeftRadius = UDim.new(1, 0),
								TopRightRadius = UDim.new(1, 0),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
								}),
								Rotation = 90,
							}),
						}),
					}),
				}),

				create("TextButton")({
					Name = "SkipTier",
					BackgroundColor3 = Color3.new(1, 1, 1),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.700904, 0.553508)
							else UDim2.fromScale(0.700904, 0.766163)
					end, 0.45, 0.4),

					Size = UDim2.fromScale(0.176982, 0.432326),
					Text = "",
					ZIndex = 3,

					useButtonEffect(),
					useButtonHoverEffect(),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.15, 0),
						BottomRightRadius = UDim.new(0.15, 0),
						TopLeftRadius = UDim.new(0.15, 0),
						TopRightRadius = UDim.new(0.15, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(0, 65, 98),
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 238, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 119, 255)),
						}),
						Rotation = 90,
					}),

					create("TextLabel")({
						Name = "Price",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.627587, 0.709994),
						Text = "Skip Tier",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 2,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),

				create("TextButton")({
					Name = "ClaimAll",
					BackgroundColor3 = Color3.new(1, 1, 1),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.896698, 0.553508)
							else UDim2.fromScale(0.896698, 0.816163)
					end, 0.6, 0.5),

					Size = UDim2.fromScale(0.176982, 0.432326),
					Text = "",
					ZIndex = 3,

					useButtonEffect(),
					useButtonHoverEffect(),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.15, 0),
						BottomRightRadius = UDim.new(0.15, 0),
						TopLeftRadius = UDim.new(0.15, 0),
						TopRightRadius = UDim.new(0.15, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(2, 99, 0),
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 255, 0)),
						}),
						Rotation = 90,
					}),

					create("TextLabel")({
						Name = "Price",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.4948485, 0.522694),
						Size = UDim2.fromScale(0.627587, 0.709994),
						Text = "Claim All",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 2,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),
			}),

			create("Frame")({
				Name = "Rewards",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.519288),
				Size = UDim2.fromScale(0.950452, 0.590504),

				create("ScrollingFrame")({
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.278414, -0.155779),
					ScrollBarImageColor3 = Color3.new(1, 1, 1),
					ScrollBarThickness = 6,
					Size = UDim2.fromScale(0.72083, 1.18844),

					create("UIListLayout")({
						Padding = UDim.new(0.005, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Wraps = true,
					}),

					PassTier({ IsVisible = isVisible, OwnPremium = true, IsClaimed = false, PassLevel = 1 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 2 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 3 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 4 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 5 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 6 }),
					PassTier({ IsVisible = isVisible, OwnPremium = false, IsClaimed = false, PassLevel = 7 }),
				}),

				create("ImageLabel")({
					Name = "ImageLabel",
					BackgroundTransparency = 1,
					Image = "rbxassetid://118060728616692",
					ImageTransparency = spring(function()
						return if isVisible() then 0 else 1
					end, 0.85, 0.8),

					Rotation = spring(function()
						return if isVisible() then 0 else 8
					end, 0.8, 0.65),

					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(-0.227527, -0.16321)
							else UDim2.fromScale(-0.125, -0.2)
					end, 0.75, 0.65),

					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.498757, 1.17751),
					ZIndex = 2,
				}),

				create("Frame")({
					Name = "PurchaseBorder",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.002, -0.095),
					Size = UDim2.fromScale(0.257122, 1.09087),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.04, 0),
						BottomRightRadius = UDim.new(0.04, 0),
						TopLeftRadius = UDim.new(0.04, 0),
						TopRightRadius = UDim.new(0.04, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(102, 102, 102),
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = spring(function()
							return if isVisible() then 0.02 else 0
						end, 0.4, 0.5),

						Transparency = spring(function()
							return if isVisible() then 0 else 1
						end, 0.75, 1),
					}),
				}),

				create("TextButton")({
					Name = "Purchase",
					BackgroundColor3 = Color3.new(1, 1, 1),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.1273708, 0.902081)
							else UDim2.fromScale(0.1273708, 0.95)
					end, 0.5, 0.5),
					Size = UDim2.fromScale(0.230791, 0.110694),
					Text = "",
					TextColor3 = Color3.new(),
					TextSize = 14,
					ZIndex = 3,

					useButtonEffect(),
					useButtonHoverEffect(),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.15, 0),
						BottomRightRadius = UDim.new(0.15, 0),
						TopLeftRadius = UDim.new(0.15, 0),
						TopRightRadius = UDim.new(0.15, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(2, 99, 0),
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 255, 0)),
						}),
						Rotation = 90,
					}),

					create("TextLabel")({
						Name = "Price",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.4948485, 0.483579),
						Size = UDim2.fromScale(0.627587, 0.709994),
						Text = "R$ 799",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 2,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),

				create("TextButton")({
					Name = "Gift",
					BackgroundColor3 = Color3.new(1, 1, 1),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.1273708, 0.748948)
							else UDim2.fromScale(0.1273708, 0.8)
					end, 0.6, 0.5),
					Size = UDim2.fromScale(0.230791, 0.110694),
					Text = "",
					TextColor3 = Color3.new(),
					TextSize = 14,
					ZIndex = 3,

					useButtonEffect(),
					useButtonHoverEffect(),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.15, 0),
						BottomRightRadius = UDim.new(0.15, 0),
						TopLeftRadius = UDim.new(0.15, 0),
						TopRightRadius = UDim.new(0.15, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(113, 75, 0),
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("TextLabel")({
						Name = "Price",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.4948485, 0.483579),
						Size = UDim2.fromScale(0.627587, 0.709994),
						Text = "Gift",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 2,

						create("LocalScript")({
							Name = "LocalScript",
						}),

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
						}),
						Rotation = 90,
					}),
				}),
			}),

			create("Frame")({
				Name = "SeasonEnds",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.499187, 0.0372341),
				Size = UDim2.fromScale(0.434891, 0.0797872),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.2, 0),
					BottomRightRadius = UDim.new(0.2, 0),
					TopLeftRadius = UDim.new(0.2, 0),
					TopRightRadius = UDim.new(0.2, 0),
				}),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(86, 86, 86),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),

				create("TextLabel")({
					Name = "Level",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.03, 0.128582),
					Size = UDim2.fromScale(0.943776, 0.709994),
					Text = function()
						return `Season Ends in {NumberUtils.FormatTime(endLeft())}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),
				}),
			}),
		}),

		create("ImageLabel")({
			Name = "Header",
			BackgroundTransparency = 1,
			Image = "rbxassetid://128042683086366",
			Position = spring(function()
				return if isVisible() then UDim2.fromScale(0.208821, 0.249052) else UDim2.fromScale(0.19, 0.249052)
			end, 0.5, 0.8),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.274527, 0.079646),

			create("ImageLabel")({
				Name = "Cloud",
				BackgroundTransparency = 1,
				Image = "rbxassetid://103759571542755",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.5, 1),
				Position = spring(function()
					return if isVisible()
						then UDim2.fromScale(0.445734, 0.0645161)
						else UDim2.fromScale(0.35, 0.0645161)
				end, 1, 0.8),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.61249, 0.935484),
				ZIndex = 2,
			}),

			create("ImageLabel")({
				Name = "Star",
				BackgroundTransparency = 1,
				Image = "rbxassetid://74847087718700",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.3, 1),

				Rotation = spring(function()
					return if isVisible() then 0 else 150
				end, 1, 0.6),

				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.97599875, 0.6644585) else UDim2.fromScale(0.85, 0.8)
				end, 1, 0.7),
				ScaleType = Enum.ScaleType.Fit,
				Size = spring(function()
					return if isVisible() then UDim2.fromScale(0.0480035, 0.264399) else UDim2.fromScale(0.094, 0.454)
				end, 1, 0.9),
				ZIndex = 2,
			}),

			create("ImageLabel")({
				Name = "Star",
				BackgroundTransparency = 1,
				Image = "rbxassetid://91343381683538",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.3, 1),

				AnchorPoint = Vector2.new(0.5, 0.5),

				Rotation = spring(function()
					return if isVisible() then 0 else 170
				end, 1, 0.65),

				Position = UDim2.fromScale(0.6501825, 0.1774191),
				ScaleType = Enum.ScaleType.Fit,
				Size = spring(function()
					return if isVisible() then UDim2.fromScale(0.054945, 0.258064) else UDim2.fromScale(0.105, 0.506)
				end, 1, 0.9),
				ZIndex = 2,
			}),

			create("ImageLabel")({
				Name = "Star",
				BackgroundTransparency = 1,
				Image = "rbxassetid://79407702118852",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.3, 1),

				AnchorPoint = Vector2.new(0.5, 0.5),

				Rotation = spring(function()
					return if isVisible() then 0 else -150
				end, 0.8, 0.6),

				Position = UDim2.fromScale(0.04029302, 0.701229),
				ScaleType = Enum.ScaleType.Fit,
				Size = spring(function()
					return if isVisible() then UDim2.fromScale(0.065934, 0.337942) else UDim2.fromScale(0.081, 0.392)
				end, 1, 0.9),
				ZIndex = 2,
			}),

			create("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.0732601, 0.306451) else UDim2.fromScale(0.04, 0.306451)
				end, 0.5, 0.5),

				Size = UDim2.fromScale(0.732601, 0.354839),
				Text = "Battlepass",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.4, 1),

				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
					Transparency = spring(function()
						return if isVisible() then 0 else 1
					end, 0.6, 1),
				}),
			}),

			create("TextLabel")({
				Name = "Shadow",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.0732601, 0.306451),
				Size = UDim2.fromScale(0.732601, 0.354839),
				Text = "Battlepass",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.5, 1),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(255, 151, 23),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.16,
					Transparency = spring(function()
						return if isVisible() then 0.5 else 1
					end, 0.5, 1),
				}),
			}),
		}),

		create("ImageButton")({
			Name = "Exit",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://128068175856648",
			Position = UDim2.fromScale(0.77, 0.29),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.0450045, 0.0632111),

			MouseButton1Click = function()
				UIController:Close(VIEW_ID)
			end,

			useButtonEffect(nil, 1.1),

			create("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.233263, 0.246451),
				Size = UDim2.fromScale(0.516739, 0.506392),
				Text = "X",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1.40455,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function BattlePassUI.Init()
	UIController = ServiceRegistry:GetService("UIController")

	isVisible = function()
		return UIController:IsVisible(VIEW_ID)()
	end
end

function BattlePassUI.Start() end

return BattlePassUI
