local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local Fn = require(ReplicatedStorage.Shared.Modules.Utils.Fn)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local TowerButton = require(ReplicatedStorage.UI.Components.TowerButton)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local InventoryClient
local UIController

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local towerInventory = source({})
local currentSort = source("Rarity")

local SORT_CRITERIA = { "Rarity", "ABC", "Level" }
local RARITY_ORDER = {
	Absolute = 1,
	Exclusive = 2,
	Mythic = 3,
	Legendary = 4,
	Epic = 5,
	Rare = 6,
	Uncommon = 7,
	Common = 8,
}

local storageCount = source(0)
local selectedName = source(nil)
local selectedKey = source()
local selectedDamage = source(0)
local selectedCooldown = source(0)
local selectedRange = source(0)
local selectedMaxTower = source(0)

local function getTowerKeyId(towerKey: string | number): number
	return tonumber(tostring(towerKey):match("%d+$")) or 0
end

local function cloneTowerInventory(inventory)
	local clone = {}

	for towerName, towers in inventory do
		clone[towerName] = table.clone(towers)
	end

	return clone
end

local function compareByCriterion(a, b, criterion: string): boolean?
	if criterion == "Rarity" then
		local aInfo = TowerData.ByName[a.Name]
		local bInfo = TowerData.ByName[b.Name]
		local aOrder = if aInfo then RARITY_ORDER[aInfo.Rarity] or 999 else 999
		local bOrder = if bInfo then RARITY_ORDER[bInfo.Rarity] or 999 else 999

		return if aOrder ~= bOrder then aOrder < bOrder else nil
	elseif criterion == "ABC" then
		local aName = string.lower(a.Name)
		local bName = string.lower(b.Name)

		return if aName ~= bName then aName < bName else nil
	elseif criterion == "Level" then
		local aLevel = a.Data.Lv or 0
		local bLevel = b.Data.Lv or 0

		return if aLevel ~= bLevel then aLevel > bLevel else nil
	end

	return nil
end

local function comesBefore(a, b, priorities): boolean
	for _, criterion in priorities do
		local result = compareByCriterion(a, b, criterion)
		if result ~= nil then
			return result
		end
	end

	local aKeyId = getTowerKeyId(a.Key)
	local bKeyId = getTowerKeyId(b.Key)
	if aKeyId ~= bKeyId then
		return aKeyId < bKeyId
	end

	return tostring(a.Key) < tostring(b.Key)
end

local function getTowerLayoutOrder(towerName: string, towerKey: string | number, towerData): number
	local primaryCriterion = currentSort()
	local priorities = { primaryCriterion }
	local target = {
		Name = towerName,
		Key = towerKey,
		Data = towerData,
	}
	local layoutOrder = 1

	for _, criterion in SORT_CRITERIA do
		if criterion ~= primaryCriterion then
			table.insert(priorities, criterion)
		end
	end

	for otherName, towers in towerInventory() do
		for otherKey, otherData in towers do
			if otherName == towerName and otherKey == towerKey then
				continue
			end

			if
				comesBefore({
					Name = otherName,
					Key = otherKey,
					Data = otherData,
				}, target, priorities)
			then
				layoutOrder += 1
			end
		end
	end

	return layoutOrder
end

local function formatAnimatedStat(animatedValue: number, statValue: number): string
	local decimalPart = string.format("%.10f", math.abs(statValue)):match("%.(%d*[1-9])0*$")
	local decimalPlaces = if decimalPart then #decimalPart else 0
	local scale = 10 ^ decimalPlaces
	local roundedValue = math.round(animatedValue * scale) / scale

	return NumberUtils.FormatComma(roundedValue)
end

local InventoryUI = {}

function InventoryUI.OnSelected(towerName: string, towerKey: string, _towerProfile)
	selectedName(towerName)
	selectedKey(towerKey)

	local towerInfo = TowerData.ByName[towerName]
	if not towerInfo then
		return
	end
	local towerStats = towerInfo.Stats

	selectedMaxTower(towerInfo.MaxTowers)
	selectedDamage(towerStats[0].Damage)
	selectedCooldown(towerStats[0].Cooldown)
	selectedRange(towerStats[0].Range)
end

function InventoryUI.EquipActivated()
	local towerName = selectedName()
	local towerKey = selectedKey()
	if type(towerName) ~= "string" or typeof(towerKey) ~= "string" then
		return
	end

	InventoryClient.EquipTower(towerName, towerKey)
end

function InventoryUI.RenderUI()
	local animatedCount = spring(storageCount, 0.5, 1)
	local animatedDamage = spring(selectedDamage, 0.5, 1)
	local animatedCooldown = spring(selectedCooldown, 0.5, 1)
	local animatedRange = spring(selectedRange, 0.5, 1)
	local animatedMaxTower = spring(selectedMaxTower, 0.5, 1)

	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible("Inventory"),

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://86505261925755",
			Rotation = spring(function()
				return if UIController:IsVisible("Inventory")() then 0 else -4
			end, 0.5, 1),
			Position = UDim2.fromScale(0.5, 0.20195),
			Size = spring(function()
				return if UIController:IsVisible("Inventory")()
					then UDim2.fromScale(0.721698, 0.668872)
					else UDim2.fromScale(0.675, 0.668872)
			end, 0.5, 0.5),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://79038669500555",
				Position = spring(function()
					return if UIController:IsVisible("Inventory")()
						then UDim2.fromScale(-0.0573612, -0.111321)
						else UDim2.fromScale(-0.1, -0.111321)
				end, 0.5, 1),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Star",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://111343804919469",
					Rotation = spring(function()
						return if UIController:IsVisible("Inventory")() then 0 else -90
					end, 0.5, 0.7),
					Position = UDim2.fromScale(0.133, 0.478),
					Size = spring(function()
						return if UIController:IsVisible("Inventory")()
							then UDim2.fromScale(0.184974, 0.837933)
							else UDim2.fromScale(0.346017, 1.56746)
					end, 0.5, 0.8),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://122017999272407",
					ImageTransparency = spring(function()
						return if UIController:IsVisible("Inventory")() then 0 else 1
					end, 0.5, 1),

					Position = spring(function()
						return if UIController:IsVisible("Inventory")()
							then UDim2.fromScale(0.529887, 0.0551715)
							else UDim2.fromScale(0.375, 0.0551715)
					end, 0.7, 0.8),
					Size = UDim2.fromScale(0.537766, 1.06417),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 2.16,
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.283423, 0.290134),
					Text = "INVENTORY",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextTransparency = spring(function()
						return if UIController:IsVisible("Inventory")() then 0 else 1
					end, 0.5, 1),
				}),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
					AspectRatio = 4.53,
				}),
			}),

			create("Frame")({
				Name = "LeftFrame",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.018712, 0.158304),
				Size = UDim2.fromScale(0.596526, 0.803586),

				create("ImageLabel")({
					Name = "Bottom",
					BackgroundTransparency = 1,
					Image = "rbxassetid://101405228511471",
					Position = UDim2.fromScale(-0.00261403, 0.882837),
					Size = UDim2.fromScale(1, 0.117596),

					create("ImageButton")({
						Name = "SellButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://76383008324602",
						Position = spring(function()
							return if UIController:IsVisible("Inventory")()
								then UDim2.fromScale(0.24, 0.5)
								else UDim2.fromScale(0.24, 1.2)
						end, 0.35, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),

						useButtonEffect(),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.265238, 0.237766),
							Size = UDim2.fromScale(0.467855, 0.487941),
							Text = "SELL",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),
					}),

					create("ImageButton")({
						Name = "LockButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://70564113534462",
						Position = spring(function()
							return if UIController:IsVisible("Inventory")()
								then UDim2.fromScale(0.5, 0.5)
								else UDim2.fromScale(0.5, 1.4)
						end, 0.5, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),

						useButtonEffect(),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.265238, 0.237766),
							Size = UDim2.fromScale(0.467855, 0.487941),
							Text = "LOCK",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),
					}),

					create("ImageButton")({
						Name = "SortButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://128977854458302",
						Position = spring(function()
							return if UIController:IsVisible("Inventory")()
								then UDim2.fromScale(0.76, 0.5)
								else UDim2.fromScale(0.76, 1.6)
						end, 0.65, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),

						MouseButton1Click = function()
							print("a")
							local currentIndex = table.find(SORT_CRITERIA, currentSort()) or 1
							local nextIndex = currentIndex % #SORT_CRITERIA + 1

							currentSort(SORT_CRITERIA[nextIndex])
						end,

						useButtonEffect(),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.234055, 0.237766),
							Size = UDim2.fromScale(0.734762, 0.487942),
							Text = function()
								return `SORT : {string.upper(currentSort())}`
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),
					}),
				}),

				create("CanvasGroup")({
					Name = "ScrollBackground",
					BackgroundTransparency = 1,
					Position = spring(function()
						return if UIController:IsVisible("Inventory")()
							then UDim2.fromScale(0.0339824, 0.124035)
							else UDim2.fromScale(-0.03, 0.124035)
					end, 0.5, 0.8),
					Size = UDim2.fromScale(0.966018, 0.758802),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.new(),
						Position = UDim2.fromScale(0, 0),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(1, 1),

						create("UIGridLayout")({
							Name = "UIGridLayout",
							CellPadding = spring(function()
								return if UIController:IsVisible("Inventory")()
									then UDim2.fromScale(0.0015, 0.012)
									else UDim2.fromScale(-0.015, 0.012)
							end, 0.5, 1),
							CellSize = UDim2.fromScale(0.192543, 0.329466),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						values(towerInventory, function(towers, towerName)
							local buttons = {}

							for towerKey, towerData in towers do
								table.insert(
									buttons,
									TowerButton({
										Visible = UIController:IsVisible("Inventory"),
										TowerName = towerName(),
										TowerKey = towerKey,
										TowerData = towerData,
										IsSelected = function()
											return if selectedName() == towerName()
													and selectedKey() == towerKey
												then true
												else false
										end,
										LayoutOrder = function()
											return getTowerLayoutOrder(towerName(), towerKey, towerData)
										end,
										OnActivated = function()
											InventoryUI.OnSelected(towerName(), towerKey, towerData)
										end,
									})
								)
							end

							return buttons
						end),
					}),
				}),

				create("ImageButton")({
					Name = "SearchButton",
					BackgroundTransparency = 1,
					Image = "rbxassetid://97005389138079",
					LayoutOrder = 6,
					Position = UDim2.fromScale(0.033053, 0.0172543),
					Size = UDim2.fromScale(0.0794115, 0.0921883),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "SearchBox",
					BackgroundTransparency = 1,
					Image = "rbxassetid://102610083488834",
					Position = UDim2.fromScale(0.123512, 0.0172543),
					Size = spring(function()
						return if UIController:IsVisible("Inventory")()
							then UDim2.fromScale(0.702835, 0.0921883)
							else UDim2.fromScale(0, 0.0921883)
					end, 0.5, 0.9),

					create("TextBox")({
						Name = "TextBox",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/FredokaOne.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.0363427, 0),
						Size = UDim2.fromScale(0.963657, 1),
						PlaceholderText = "TOWER NAME",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UITextSizeConstraint")({
							Name = "UITextSizeConstraint",
							MaxTextSize = 30,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 18, 98)),
							}),
							Rotation = 90,
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "InventoryLimit",
					BackgroundTransparency = 1,
					Image = "rbxassetid://92189379920788",
					Position = UDim2.fromScale(0.844985, 0.0172543),
					Size = UDim2.fromScale(0.133909, 0.0921883),

					create("TextLabel")({
						Name = "Title",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.843832, 0.543318),
						Text = function()
							return `{math.round(animatedCount())}/100`
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 37, 85)),
							}),
							Rotation = 90,
						}),

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "Shadow",
					BackgroundTransparency = 1,
					Image = "rbxassetid://78891351891737",
					Position = UDim2.fromScale(0.0130701, 0.671846),
					Size = UDim2.fromScale(0.965823, 0.211848),
				}),
			}),

			create("ImageLabel")({
				Name = "Avatar",
				BackgroundTransparency = 1,
				Image = "rbxassetid://121523581447419",
				Position = spring(function()
					return if UIController:IsVisible("Inventory")()
						then UDim2.fromScale(0.596001, 0.170108)
						else UDim2.fromScale(0.625, 0.170108)
				end, 0.4, 0.5),
				Size = spring(function()
					return if UIController:IsVisible("Inventory")()
						then UDim2.fromScale(0.382446, 0.697631)
						else UDim2.fromScale(0.425, 0.697631)
				end, 0.4, 0.5),
				ZIndex = 10,

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 3, 4)),
					}),
					Rotation = 90,
				}),

				create("ImageLabel")({
					Name = "Damage",
					BackgroundTransparency = 1,
					Image = "rbxassetid://91726020798265",
					Position = UDim2.fromScale(0.0743812, 0.865685),
					Size = UDim2.fromScale(0.287129, 0.130411),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.75, 0.5),
						Size = UDim2.fromScale(0.843832, 0.543318),
						Text = function()
							return formatAnimatedStat(animatedDamage(), selectedDamage())
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "Rng",
					BackgroundTransparency = 1,
					Image = "rbxassetid://77164215386840",
					Position = UDim2.fromScale(0.355713, 0.865685),
					Size = UDim2.fromScale(0.287129, 0.130411),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.75, 0.5),
						Size = UDim2.fromScale(0.843832, 0.543318),
						Text = function()
							return formatAnimatedStat(animatedRange(), selectedRange())
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "Cooldown",
					BackgroundTransparency = 1,
					Image = "rbxassetid://117790979554827",
					Position = UDim2.fromScale(0.641121, 0.865685),
					Size = UDim2.fromScale(0.287129, 0.130411),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.75, 0.5),
						Size = UDim2.fromScale(0.843832, 0.543318),
						Text = function()
							return formatAnimatedStat(animatedCooldown(), selectedCooldown())
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "LevelBG",
					BackgroundTransparency = 1,
					Image = "rbxassetid://111497714681866",
					Position = UDim2.fromScale(0.0927249, 0.819462),
					Size = UDim2.fromScale(0.813106, 0.0421658),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 36, 28)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 36, 28)),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "LevelFill",
					BackgroundTransparency = 1,
					Image = "rbxassetid://111497714681866",
					Position = UDim2.fromScale(0.0927249, 0.819462),
					Size = UDim2.fromScale(0.813106, 0.0421658),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.48102, 0.39498),
						Size = UDim2.fromScale(0.843832, 1),
						Text = "LV.10(1/100xp)",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(147, 120, 12)),
							ColorSequenceKeypoint.new(0.494898, Color3.fromRGB(251, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(254, 255, 203)),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "MaximumPlacement",
					BackgroundTransparency = 1,
					Image = "rbxassetid://99625316186918",
					Position = UDim2.fromScale(0.0866135, 0.719145),
					Size = UDim2.fromScale(0.207609, 0.0877106),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.8, 0.52),
						Size = UDim2.fromScale(0.843832, 0.672881),
						Text = function()
							return formatAnimatedStat(animatedMaxTower(), selectedMaxTower())
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("ImageButton")({
					Name = "SkinButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://114347652939958",
					Position = UDim2.fromScale(0.85117, 0.732566),
					Size = UDim2.fromScale(0.186781, 0.168732),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),

					create("TextLabel")({
						Name = "Tag",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.498106, 0.825253),
						Size = UDim2.fromScale(0.721342, 0.344584),
						Text = "skin",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),
				}),

				create("TextLabel")({
					Name = "Name",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.49695, 0.147478),
					Size = UDim2.fromScale(0.83363, 0.0605149),
					Text = function()
						return selectedName() or ""
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,

					create("UIStroke")({
						Name = "UIStroke",
					}),
				}),

				create("TextLabel")({
					Name = "Grade",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.49695, 0.200005),
					Size = UDim2.fromScale(0.83363, 0.0479085),
					Text = "EXCLUSIVE",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,

					create("UIStroke")({
						Name = "UIStroke",
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 23, 2)),
							ColorSequenceKeypoint.new(0.501701, Color3.fromRGB(18, 9, 9)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 23, 2)),
						}),
					}),
				}),

				TowerViewport({
					TowerName = selectedName,

					AnimationName = "Idle",
					AnimationFadeTime = 0,
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.107252, 0.111511),
					Size = UDim2.fromScale(0.789563, 0.888489),
					ModelRotation = 20,

					ZIndex = -1,
				}),

				create("ImageLabel")({
					Name = "Trait",
					BackgroundTransparency = 1,
					Image = "rbxassetid://127028785606527",
					Position = UDim2.fromScale(0.0825364, 0.019763),
					Size = UDim2.fromScale(0.113389, 0.097458),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 144)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 246, 144)),
						}),
					}),

					create("ImageLabel")({
						Name = "Trait",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://100463457721493",
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.887562, 0.847315),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),
				}),
			}),

			create("ImageButton")({
				Name = "EquipButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://83967774994235",
				Position = spring(function()
					return if UIController:IsVisible("Inventory")()
						then UDim2.fromScale(0.787698, 0.920119)
						else UDim2.fromScale(0.787698, 1.05)
				end, 0.75, 0.65),
				Size = UDim2.fromScale(0.337246, 0.0842378),
				ZIndex = 11,

				useButtonEffect(0.985),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.237766),
					Size = UDim2.fromScale(0.467855, 0.487941),
					Text = "EQUIP",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 255, 88)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 255, 1)),
					}),
					Rotation = 90,
				}),
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Rotation = spring(function()
					return if UIController:IsVisible("Inventory")() then 0 else -1800
				end, 1, 0.8),
				Position = spring(function()
					return if UIController:IsVisible("Inventory")()
						then UDim2.fromScale(0.980096, 0.0289194)
						else UDim2.fromScale(0.2, 0.0289194)
				end, 1, 0.85),
				Size = UDim2.fromScale(0.102144, 0.15458),

				MouseButton1Click = function()
					UIController:Close("Inventory")
				end,

				useButtonEffect(nil, 1.1),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.88,
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function InventoryUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function InventoryUI.Start()
	task.spawn(function()
		towerInventory(cloneTowerInventory(InventoryClient.GetOwnedTowers()))
	end)

	InventoryClient.TowerAdded:Connect(function()
		towerInventory(cloneTowerInventory(InventoryClient.OwnedTowers))
	end)

	InventoryClient.TowerRemoved:Connect(function()
		towerInventory(cloneTowerInventory(InventoryClient.OwnedTowers))
	end)

	UIController:Open("Inventory")
end

return InventoryUI
