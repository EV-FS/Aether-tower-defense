local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local SummonResultUI = require(script.Parent.SummonResultUI)
local UIController

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local isHovered = source(false)
local currentPity = source(0)

local DEFAULT_UNITS_POOL = {
	Common = { Name = "", RateText = "" },
	Uncommon = { Name = "", RateText = "" },
	Rare = { Name = "", RateText = "" },
	Epic = { Name = "", RateText = "" },
	Legendary = { Name = "", RateText = "" },
	Mythic = { Name = "", RateText = "" },
	Absolute = { Name = "", RateText = "" },
}

local currentUnitsPool = source(DEFAULT_UNITS_POOL)

local function copyDefaultUnitsPool()
	local pool = {}
	for rarity, info in DEFAULT_UNITS_POOL do
		pool[rarity] = {
			Name = info.Name,
			RateText = info.RateText,
		}
	end
	return pool
end

local SummonUI = {}

function SummonUI.UpdateBanner(bannerData)
	if not bannerData or type(bannerData.Units) ~= "table" then
		warn(`bannerData의 타입에 오류가 존재함.`)
		return
	end

	local unitsByRarity = copyDefaultUnitsPool()
	local units = bannerData.Units

	if units[1] then
		for _, unit in ipairs(units) do
			if unit.Rarity and unitsByRarity[unit.Rarity] then
				unitsByRarity[unit.Rarity] = {
					Name = unit.Name or "",
					RateText = unit.RateText or "",
				}
			end
		end
	else
		for rarity, info in units do
			if unitsByRarity[rarity] and type(info) == "table" then
				unitsByRarity[rarity] = {
					Name = info.Name or "",
					RateText = info.RateText or "",
				}
			end
		end
	end

	currentUnitsPool(unitsByRarity)
end

function SummonUI.Summon(number: number)
	task.spawn(function()
		local ok, success, result = pcall(function()
			return Net.SummonService.DoSummon.Invoke(number):await()
		end)

		if not ok then
			warn(`Summon request failed: {success}`)
			return
		end

		if not success or not result or not result.Success then
			return
		end

		local pulledUnits = result.PulledUnits
		if type(pulledUnits) == "table" and #pulledUnits > 0 then
			SummonResultUI.ShowResults(pulledUnits)
		end
	end)
end

function SummonUI.RenderUI()
	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = spring(function()
			return if UIController:IsVisible("Summon")() then 0 else -3
		end, 0.5, 0.65),
		Position = spring(function()
			return if UIController:IsVisible("Summon")() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.6)
		end, 0.5, 0.65),
		Size = UDim2.fromScale(1, 1),

		Visible = UIController:IsVisible("Summon"),

		create("UIAspectRatioConstraint")({
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://76595093118022",
			Position = UDim2.new(0.49878, 0, 0.484331, 4),
			Size = UDim2.fromScale(0.67, 0.60215),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://97669663501555",
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.987, 0.04)
						else UDim2.fromScale(0.987, 0.08)
				end, 0.5, 0.65),
				Size = UDim2.fromScale(0.0455964, 0.0784857),
				ZIndex = 3,

				MouseButton1Click = function()
					UIController:Close("Summon")
				end,

				useButtonEffect(),

				create("UIAspectRatioConstraint")({}),
			}),

			create("ImageLabel")({
				Name = "Icon",
				BackgroundTransparency = 1,
				Image = "rbxassetid://137286113984807",
				ImageTransparency = spring(function()
					return if UIController:IsVisible("Summon")() then 0 else 1
				end, 0.5, 1),

				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.0184762, 0.0549331)
						else UDim2.fromScale(0, 0.0549331)
				end, 0.5, 1),
				Size = UDim2.fromScale(0.0739609, 0.110878),

				create("UIAspectRatioConstraint")({}),
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Rotation = spring(function()
					return if UIController:IsVisible("Summon")() then 0 else -8
				end, 0.5, 0.45),
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.09, 0.0607155)
						else UDim2.fromScale(0, 0.0607155)
				end, 0.5, 1),
				Size = UDim2.fromScale(0.138753, 0.0954101),
				Text = "Summon",
				TextTransparency = spring(function()
					return if UIController:IsVisible("Summon")() then 0 else 1
				end, 0.7, 1),

				TextColor3 = Color3.fromRGB(214, 207, 150),
				TextScaled = true,
			}),

			create("Frame")({
				Name = "LeftFrame",
				Position = UDim2.fromScale(0.011, 0.197),
				Size = UDim2.fromScale(0.236, 0.575),

				BackgroundTransparency = 1,

				create("ImageLabel")({
					Image = "rbxassetid://127755102717021",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}),

				create("ScrollingFrame")({
					Name = "Category",
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = spring(function()
						return if UIController:IsVisible("Summon")()
							then UDim2.fromScale(0.5, 0.5)
							else UDim2.fromScale(0.4, 0.5)
					end, 0.5, 1),
					ScrollBarThickness = 0,
					Size = UDim2.fromScale(1, 1),

					create("ImageButton")({
						Name = "BestCategory",
						BackgroundTransparency = 1,
						Image = "rbxassetid://133178243441481",
						ImageTransparency = spring(function()
							return if UIController:IsVisible("Summon")() then 0 else 1
						end, 0.5, 1),

						Size = UDim2.fromScale(1, 0.09),

						create("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							Image = "rbxassetid://76397723941177",
							Position = UDim2.fromScale(0.0737704, 0.183541),
							Size = UDim2.fromScale(0.197095, 0.704737),

							create("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(223, 218, 168)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(223, 218, 168)),
								}),
							}),

							create("UIAspectRatioConstraint")({}),
						}),

						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 229, 164)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 229, 164)),
							}),
						}),

						create("TextLabel")({
							Name = "Tag",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.344374, 0.148429),
							Size = UDim2.fromScale(0.575, 0.672084),
							Text = "개쌉레전드 배너",
							TextColor3 = Color3.fromRGB(213, 204, 150),
							TextScaled = true,
						}),
					}),

					create("UIListLayout")({
						Padding = UDim.new(0.01, 0),
					}),

					create("ImageButton")({
						Name = "WarriorCategory",
						BackgroundTransparency = 1,
						Image = "rbxassetid://83054705354423",
						Size = UDim2.fromScale(1, 0.09),

						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 229, 164)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 229, 164)),
							}),
						}),

						create("TextLabel")({
							Name = "Tag",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.344374, 0.148429),
							Size = UDim2.fromScale(0.575, 0.672084),
							Text = "현우 슈퍼 배너",
							TextColor3 = Color3.fromRGB(213, 204, 150),
							TextScaled = true,
						}),
					}),
				}),
			}),

			create("Frame")({
				Name = "Floor",
				BackgroundTransparency = 1,
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.0302338, 0.818397)
						else UDim2.fromScale(0, 0.818397)
				end, 0.5, 0.9),
				Size = UDim2.fromScale(0.317576, 0.101516),

				create("UIAspectRatioConstraint")({
					AspectRatio = 5.36,
				}),

				create("ImageLabel")({
					Name = "Fill",
					BackgroundTransparency = 1,
					Image = "rbxassetid://102454806975257",
					Position = UDim2.fromScale(0.0184759, 0.596062),
					Size = spring(function()
						return if UIController:IsVisible("Summon")()
							then UDim2.fromScale(currentPity() / 1000 * 0.735357, 0.248)
							else UDim2.fromScale(0, 0.248)
					end, 0.5, 0.85),
					ZIndex = 3,

					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 34, 34)),
						}),
						Rotation = 90,
					}),
				}),

				create("TextLabel")({
					Name = "FloorGrade",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.248702, 0.0891927),
					Size = UDim2.fromScale(0.13344, 0.421426),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 51, 51)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 26, 26)),
						}),
						Rotation = 90,
					}),
				}),

				create("TextLabel")({
					Name = "Tag",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.317778, 0.0891927),
					Size = UDim2.fromScale(0.255651, 0.421426),
					Text = "까지..",
					TextColor3 = Color3.fromRGB(131, 126, 92),
					TextScaled = true,
				}),

				create("TextLabel")({
					Name = "Tag",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.753487, 0.51062),
					Size = UDim2.fromScale(0.255651, 0.313284),
					Text = function()
						return `{currentPity()}/1000`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),

				create("TextLabel")({
					Name = "Tag",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.014907, 0.0891927),
					Size = UDim2.fromScale(0.255651, 0.421426),
					Text = "다음 확정",
					TextColor3 = Color3.fromRGB(131, 126, 92),
					TextScaled = true,
				}),

				create("ImageLabel")({
					Name = "BG",
					BackgroundTransparency = 1,
					Image = "rbxassetid://76248240080018",
					Position = UDim2.fromScale(0.0184759, 0.596062),
					Size = UDim2.fromScale(0.735357, 0.248),
				}),
			}),

			create("Frame")({
				Name = "ProbabilityTableFrame",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.273784, 0.092519),
				Size = UDim2.fromScale(0.338632, 0.629318),
				ZIndex = 10,
				Visible = isHovered,

				create("ImageLabel")({
					Name = "Main",
					BackgroundTransparency = 1,
					Image = "rbxassetid://71833528076714",
					Size = UDim2.fromScale(1, 1),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(0.3, 1),
							Text = "Absolute",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 255, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
								})),
							}),
						}),

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Absolute.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),
					}),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(0.3, 1),
							Text = "Mythic",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 14, 18)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 0, 3)),
								})),
							}),
						}),

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Mythic.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),
					}),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Size = UDim2.fromScale(0.3, 1),
							Text = "Legendary",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 52)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 126, 61)),
								})),
							}),
						}),

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Legendary.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),
					}),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							SelectionOrder = 1,
							Size = UDim2.fromScale(0.3, 0.55),
							Text = "Epic",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 85, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 32, 170)),
								})),
							}),
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							SelectionOrder = 2,
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Epic.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					}),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.286966, 0),
							Size = UDim2.fromScale(0.3, 0.55),
							Text = "Rare",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 106, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 34, 255)),
								})),
							}),
						}),

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Rare.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),
					}),

					create("Frame")({
						Name = "Group",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.199586),

						create("TextLabel")({
							Name = "Grade",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.286966, 0),
							Size = UDim2.fromScale(0.3, 1),
							Text = "Common",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(199, 199, 199)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(199, 199, 199)),
								}),
							}),
						}),

						create("TextLabel")({
							Name = "Probability",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.168518, 0.0607149),
							Size = UDim2.fromScale(0.215465, 0.6),
							Text = function()
								return currentUnitsPool().Common.RateText
							end,
							TextColor3 = Color3.fromRGB(255, 231, 170),
							TextScaled = true,
						}),

						create("UIListLayout")({
							Name = "UIListLayout",
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0.05, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					}),

					create("UIListLayout")({
						Name = "UIListLayout",
						Padding = UDim.new(-0.04, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}),
			}),

			create("ImageButton")({
				Name = "OnePickButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://76477257599577",
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.54, 0.869)
						else UDim2.fromScale(0.54, 0.9)
				end, 0.5, 0.8),
				Size = UDim2.fromScale(0.275587, 0.104507),

				MouseButton1Click = function()
					SummonUI.Summon(1)
				end,

				useButtonEffect(0.97),

				create("TextLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.025, 0.5),
					Size = UDim2.fromScale(0.4, 0.5),
					Text = "100 C",
					TextColor3 = Color3.fromRGB(58, 56, 41),
					TextScaled = true,
				}),

				create("TextLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.4, 0.5),
					Text = "1x Summon",
					TextColor3 = Color3.fromRGB(58, 56, 41),
					TextScaled = true,
				}),
			}),

			create("ImageButton")({
				Name = "TenPickButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://128938309235864",
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.83, 0.869)
						else UDim2.fromScale(0.83, 0.9)
				end, 0.5, 0.8),
				Size = UDim2.fromScale(0.273784, 0.104507),

				MouseButton1Click = function()
					SummonUI.Summon(10)
				end,

				useButtonEffect(0.97),

				create("TextLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.02, 0.5),
					Size = UDim2.fromScale(0.4, 0.5),
					Text = "900 C",
					TextColor3 = Color3.fromRGB(58, 56, 41),
					TextScaled = true,
				}),

				create("TextLabel")({
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.4, 0.5),
					Text = "10x Summon",
					TextColor3 = Color3.fromRGB(58, 56, 41),
					TextScaled = true,
				}),
			}),

			create("ImageButton")({
				Name = "ProbabilityTableButton",
				BackgroundTransparency = 1,
				Image = "rbxassetid://120545788069786",
				ImageTransparency = spring(function()
					return if UIController:IsVisible("Summon")() then 0 else 1
				end, 0.75, 0.7),

				LayoutOrder = 3,
				Rotation = spring(function()
					return if UIController:IsVisible("Summon")() then 0 else 720
				end, 0.75, 0.7),
				Position = spring(function()
					return if UIController:IsVisible("Summon")()
						then UDim2.fromScale(0.248589, 0.0628885)
						else UDim2.fromScale(0.4, 0.0628885)
				end, 0.5, 0.8),
				Size = UDim2.fromScale(0.025, 0.05),
				ZIndex = 2,

				MouseEnter = function()
					isHovered(true)
				end,

				MouseLeave = function()
					isHovered(false)
				end,

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("Frame")({
				Name = "TowerBanner",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.248589, 0.0784857),
				Size = UDim2.fromScale(0.728293, 0.693514),

				create("Frame")({
					Name = "Tower",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(-0.15, 0),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					create("ImageLabel")({
						Name = "Legendary",
						BackgroundTransparency = 1,
						Image = "rbxassetid://87157288731947",
						ImageTransparency = spring(function()
							return if UIController:IsVisible("Summon")() then 0 else 0.5
						end, 0.3, 1),

						Size = UDim2.fromScale(0.475343, 0.855337),

						TowerViewport({
							TowerName = function()
								return currentUnitsPool().Legendary.Name
							end,
							AnimationName = "Idle",
							AnchorPoint = Vector2.new(0.5, 1),
							ImageTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							BackgroundColor3 = Color3.new(),
							BackgroundTransparency = 1,
							Position = spring(function()
								return if UIController:IsVisible("Summon")()
									then UDim2.fromScale(0.5, 1)
									else UDim2.fromScale(0.4, 1)
							end, 0.5, 0.7),
							Size = UDim2.fromScale(0.7, 1),
							ModelRotation = spring(function()
								return if UIController:IsVisible("Summon")() then 20 else -90
							end, 0.75, 0.6),
						}),
					}),

					create("ImageLabel")({
						Name = "Absolute",
						BackgroundTransparency = 1,
						Image = "rbxassetid://87157288731947",
						ImageTransparency = spring(function()
							return if UIController:IsVisible("Summon")() then 0 else 0.5
						end, 0.3, 1),

						Size = UDim2.fromScale(0.475343, 0.855337),

						TowerViewport({
							TowerName = function()
								return currentUnitsPool().Absolute.Name
							end,
							AnimationName = "Idle",
							AnchorPoint = Vector2.new(0.5, 1),
							ImageTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							BackgroundColor3 = Color3.new(),
							BackgroundTransparency = 1,
							Position = spring(function()
								return if UIController:IsVisible("Summon")()
									then UDim2.fromScale(0.5, 1)
									else UDim2.fromScale(0.5, 1.1)
							end, 0.5, 0.7),
							Size = UDim2.fromScale(0.7, 1.2),
							ModelRotation = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else -30
							end, 0.75, 0.6),
						}),
					}),

					create("ImageLabel")({
						Name = "Mythic",
						BackgroundTransparency = 1,
						Image = "rbxassetid://87157288731947",
						ImageTransparency = spring(function()
							return if UIController:IsVisible("Summon")() then 0 else 0.5
						end, 0.3, 1),

						Size = UDim2.fromScale(0.475343, 0.855337),

						TowerViewport({
							TowerName = function()
								return currentUnitsPool().Mythic.Name
							end,
							AnimationName = "Idle",
							AnchorPoint = Vector2.new(0.5, 1),
							ImageTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							BackgroundColor3 = Color3.new(),
							BackgroundTransparency = 1,
							Position = spring(function()
								return if UIController:IsVisible("Summon")()
									then UDim2.fromScale(0.5, 1)
									else UDim2.fromScale(0.6, 1)
							end, 0.5, 0.7),
							Size = UDim2.fromScale(0.7, 1),
							ModelRotation = spring(function()
								return if UIController:IsVisible("Summon")() then -20 else 50
							end, 0.75, 0.6),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "Shadow",
					BackgroundTransparency = 1,
					Image = "rbxassetid://73218199585812",
					ImageTransparency = spring(function()
						return if UIController:IsVisible("Summon")() then 0 else 1
					end, 0.75, 1),

					Position = UDim2.fromScale(1.40765e-07, 0.672081),
					Size = UDim2.fromScale(0.999999, 0.32792),
				}),

				create("ImageLabel")({
					Name = "Shadow",
					BackgroundTransparency = 1,
					Image = "rbxassetid://81640855031906",
					ImageTransparency = spring(function()
						return if UIController:IsVisible("Summon")() then 0 else 1
					end, 0.75, 1),

					Position = UDim2.fromScale(-0.00691873, -0.0283006),
					Size = UDim2.fromScale(0.999999, 0.32792),
				}),

				create("Frame")({
					Name = "UnitNames",
					BackgroundTransparency = 1,
					Position = spring(function()
						return if UIController:IsVisible("Summon")()
							then UDim2.fromScale(2.8153e-07, 0.696212)
							else UDim2.fromScale(2.8153e-07, 0.775)
					end, 0.5, 0.7),

					Size = UDim2.fromScale(1.01384, 0.3),

					create("Frame")({
						Name = "LegendaryDesc",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(0.347516, 0.910111),

						create("TextLabel")({
							Name = "TowerName",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.265108),
							Size = UDim2.fromScale(0.8, 0.3),
							Text = function()
								return currentUnitsPool().Legendary.Name
							end,
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),

						create("TextLabel")({
							Name = "Grade",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.572479),
							Size = UDim2.fromScale(0.4, 0.352901),
							Text = "Legendary",
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Transparency = spring(function()
									return if UIController:IsVisible("Summon")() then 0 else 1
								end, 0.5, 1),
							}),

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 52)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 126, 61)),
								})),
							}),
						}),
					}),

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(-0.02, 0),
					}),

					create("Frame")({
						Name = "AbsoluteDesc",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(0.347516, 0.910111),

						create("TextLabel")({
							Name = "TowerName",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.265108),
							Size = UDim2.fromScale(0.8, 0.3),
							Text = function()
								return currentUnitsPool().Absolute.Name
							end,
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),

						create("TextLabel")({
							Name = "Grade",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.572479),
							Size = UDim2.fromScale(0.404952, 0.352901),
							Text = "Absolute",
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Transparency = spring(function()
									return if UIController:IsVisible("Summon")() then 0 else 1
								end, 0.5, 1),
							}),

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 255, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
								})),
							}),
						}),
					}),

					create("Frame")({
						Name = "MythicDesc",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(0.347516, 0.910111),

						create("TextLabel")({
							Name = "TowerName",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.265108),
							Size = UDim2.fromScale(0.8, 0.3),
							Text = function()
								return currentUnitsPool().Mythic.Name
							end,
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),

						create("TextLabel")({
							Name = "Grade",
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/SourceSansPro.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.5, 0.572479),
							Size = UDim2.fromScale(0.312316, 0.352901),
							Text = "Mythic",
							TextTransparency = spring(function()
								return if UIController:IsVisible("Summon")() then 0 else 1
							end, 0.5, 1),

							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Transparency = spring(function()
									return if UIController:IsVisible("Summon")() then 0 else 1
								end, 0.5, 1),
							}),

							create("UIGradient")({
								useColorSequenceCycle(ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 14, 18)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 0, 3)),
								})),
							}),
						}),
					}),
				}),
			}),
		}),
	})
end

function SummonUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
end

function SummonUI.Start()
	Net.SummonService.BannerUpdated.On(SummonUI.UpdateBanner)

	task.spawn(function()
		local ok, success, bannerData = pcall(function()
			return Net.SummonService.GetBanner.Invoke():await()
		end)

		if ok and success and bannerData then
			SummonUI.UpdateBanner(bannerData)
		elseif not ok then
			warn(`GetBanner failed: {success}`)
		end
	end)

	local summonTouch = workspace:WaitForChild("TouchZone"):WaitForChild("SummonTouch")
	local zone = TouchZone.new(summonTouch)
	zone:Start()

	zone.Touched:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		UIController:Open("Summon")
	end)

	zone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		UIController:Close("Summon")
	end)
end

return SummonUI
