local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local TowerButton = require(ReplicatedStorage.UI.Components.TowerButton)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local InventoryClient
local UIController

local create = Vide.create
local action = Vide.action
local changed = Vide.changed
local cleanup = Vide.cleanup
local derive = Vide.derive
local effect = Vide.effect
local show = Vide.show
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local towerInventory = source({})
local currentSort = source("Rarity")
local searchQuery = source("")

local VIEW_ID = "Units"

local SORT_CRITERIA = { "Rarity", "ABC", "Level" }
local RARITY_ORDER = {
	Absolute = 1,
	Exclusive = 2,
	Mythic = 3,
	Legendary = 4,
	Epic = 5,
	Rare = 6,
	Common = 7,
}

local selectedName = source(nil)
local selectedKey = source()
local selectedDamage = source(0)
local selectedCooldown = source(0)
local selectedRange = source(0)
local selectedMaxTower = source(0)

local function normalizeSearch(value: string): string
	return string.lower(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getOwnedTower(towerName: string?, towerKey: string | number?): any?
	if not towerName or towerKey == nil then
		return nil
	end

	local towers = towerInventory()[towerName]
	if not towers then
		return nil
	end

	local keyText = tostring(towerKey)
	local keyId = keyText:match("^t_(%d+)$") or keyText:match("^(%d+)$")
	return towers[towerKey] or towers[keyText] or (keyId and towers[`t_{keyId}`]) or nil
end

local function matchesSearch(towerName: string, towerKey: string | number, towerData): boolean
	local query = normalizeSearch(searchQuery())
	if query == "" then
		return true
	end

	local rarity = UnitCatalog.GetRarity(towerName)
	local level = if towerData and typeof(towerData.Lv) == "number" then towerData.Lv else 0
	local searchableText = string.lower(`{towerName} {rarity} {towerKey} level {level} lv {level}`)
	return string.find(searchableText, query, 1, true) ~= nil
end

local function matchingUnitCount(): number
	local count = 0
	for towerName, towers in towerInventory() do
		for towerKey, towerData in towers do
			if matchesSearch(towerName, towerKey, towerData) then
				count += 1
			end
		end
	end
	return count
end

local function storageCount(): number
	local count = 0

	for _, towers in towerInventory() do
		for _ in towers do
			count += 1
		end
	end

	return count
end

local function getTowerKeyId(towerKey: string | number): number
	return tonumber(tostring(towerKey):match("%d+$")) or 0
end

local function getUnitId(towerName: string, towerKey: string | number): string
	return `{towerName}\0{tostring(towerKey)}`
end

local function compareByCriterion(a, b, criterion: string): boolean?
	if criterion == "Rarity" then
		local aOrder = RARITY_ORDER[UnitCatalog.GetRarity(a.Name)] or 999
		local bOrder = RARITY_ORDER[UnitCatalog.GetRarity(b.Name)] or 999

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
	local aEquipped = a.EquippedSlot ~= nil
	local bEquipped = b.EquippedSlot ~= nil
	if aEquipped ~= bEquipped then
		return aEquipped
	end
	if aEquipped and a.EquippedSlot ~= b.EquippedSlot then
		return a.EquippedSlot < b.EquippedSlot
	end

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

local function formatAnimatedStat(animatedValue: number, statValue: number): string
	local decimalPart = string.format("%.10f", math.abs(statValue)):match("%.(%d*[1-9])0*$")
	local decimalPlaces = if decimalPart then #decimalPart else 0
	local scale = 10 ^ decimalPlaces
	local roundedValue = math.round(animatedValue * scale) / scale

	return NumberUtils.FormatComma(roundedValue)
end

local UnitUI = {}

function UnitUI.OnSelected(towerName: string, towerKey: string, _towerProfile)
	selectedName(towerName)
	selectedKey(towerKey)
end

function UnitUI.EquipActivated()
	local towerName = selectedName()
	local towerKey = selectedKey()
	if type(towerName) ~= "string" or (type(towerKey) ~= "string" and type(towerKey) ~= "number") then
		return
	end

	InventoryClient.ToggleTower(towerName, towerKey):catch(function(err)
		warn(`[UnitUI] Failed to update loadout: {err}`)
	end)
end

function UnitUI.SortActivated()
	local currentIndex = table.find(SORT_CRITERIA, currentSort()) or 1
	local nextIndex = currentIndex % #SORT_CRITERIA + 1

	currentSort(SORT_CRITERIA[nextIndex])
end

function UnitUI.RenderUI()
	local isInventoryVisible = UIController:IsVisible(VIEW_ID)
	local searchTextBox: TextBox? = nil
	local selectedTowerData = derive(function()
		return getOwnedTower(selectedName(), selectedKey())
	end)
	local selectedLevel = derive(function()
		local towerData = selectedTowerData()
		return if towerData and typeof(towerData.Lv) == "number" then towerData.Lv else 0
	end)
	local selectedExp = derive(function()
		local towerData = selectedTowerData()
		return if towerData and typeof(towerData.Exp) == "number" then towerData.Exp else 0
	end)
	local selectedRequiredExp = derive(function()
		if selectedLevel() >= DataConstants.MAX_TOWER_LEVEL then
			return 0
		end
		return 100 * (selectedLevel() + 1)
	end)
	local sortedUnitRanks = derive(function()
		local primaryCriterion = currentSort()
		local priorities = { primaryCriterion }
		local units = {}

		for _, criterion in SORT_CRITERIA do
			if criterion ~= primaryCriterion then
				table.insert(priorities, criterion)
			end
		end

		for towerName, towers in towerInventory() do
			for towerKey, towerData in towers do
				table.insert(units, {
					Name = towerName,
					Key = towerKey,
					Data = towerData,
					EquippedSlot = InventoryClient.FindEquippedSlot(towerName, towerKey),
				})
			end
		end

		table.sort(units, function(a, b)
			return comesBefore(a, b, priorities)
		end)

		local ranks = {}
		for rank, unit in units do
			ranks[getUnitId(unit.Name, unit.Key)] = rank
		end
		return ranks
	end)

	effect(function()
		local towerName = selectedName()
		local towerInfo = if towerName then TowerData.ByName[towerName] else nil
		local towerStats = towerInfo and towerInfo.Stats
		local currentStats = towerStats and towerStats[0]

		selectedMaxTower(if towerInfo then towerInfo.MaxTowers or 0 else 0)
		selectedDamage(if currentStats then currentStats.Damage or 0 else 0)
		selectedCooldown(if currentStats then currentStats.Cooldown or 0 else 0)
		selectedRange(if currentStats then currentStats.Range or 0 else 0)
	end)

	local animatedCount = spring(storageCount, 0.5, 1)
	local animatedDamage = spring(selectedDamage, 0.5, 1)
	local animatedCooldown = spring(selectedCooldown, 0.5, 1)
	local animatedRange = spring(selectedRange, 0.5, 1)
	local animatedMaxTower = spring(selectedMaxTower, 0.5, 1)

	return create("Frame")({
		Name = "Units",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://86505261925755",
			Rotation = spring(function()
				return if UIController:IsVisible(VIEW_ID)() then 0 else -4
			end, 0.5, 1),

			Position = UDim2.fromScale(0.5, 0.20195),
			Size = spring(function()
				return if UIController:IsVisible(VIEW_ID)()
					then UDim2.fromScale(0.721698, 0.668872)
					else UDim2.fromScale(0.675, 0.668872)
			end, 0.5, 0.5),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://79038669500555",
				Position = spring(function()
					return if UIController:IsVisible(VIEW_ID)()
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
						return if UIController:IsVisible(VIEW_ID)() then 0 else -90
					end, 0.5, 0.7),
					Position = UDim2.fromScale(0.133, 0.478),
					Size = spring(function()
						return if UIController:IsVisible(VIEW_ID)()
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
						return if UIController:IsVisible(VIEW_ID)() then 0 else 1
					end, 0.5, 1),

					Position = spring(function()
						return if UIController:IsVisible(VIEW_ID)()
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
					Text = "UNITS",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextTransparency = spring(function()
						return if UIController:IsVisible(VIEW_ID)() then 0 else 1
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
					Active = true,
					BackgroundTransparency = 1,
					Image = "rbxassetid://101405228511471",
					Position = UDim2.fromScale(-0.00261403, 0.882837),
					Size = UDim2.fromScale(1, 0.117596),
					ZIndex = 20,

					create("ImageButton")({
						Name = "SellButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://76383008324602",
						Position = spring(function()
							return if UIController:IsVisible(VIEW_ID)()
								then UDim2.fromScale(0.24, 0.5)
								else UDim2.fromScale(0.24, 1.2)
						end, 0.35, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),
						ZIndex = 21,

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
							return if UIController:IsVisible(VIEW_ID)()
								then UDim2.fromScale(0.5, 0.5)
								else UDim2.fromScale(0.5, 1.4)
						end, 0.5, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),
						ZIndex = 21,

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
						Active = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Image = "rbxassetid://128977854458302",
						Position = spring(function()
							return if UIController:IsVisible(VIEW_ID)()
								then UDim2.fromScale(0.76, 0.5)
								else UDim2.fromScale(0.76, 1.6)
						end, 0.65, 0.5),
						Size = UDim2.fromScale(0.251482, 0.782844),
						Selectable = true,
						ZIndex = 21,

						Activated = UnitUI.SortActivated,

						useButtonEffect(),

						create("TextLabel")({
							Name = "Title",
							Active = false,
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
					ClipsDescendants = true,
					Position = spring(function()
						return if UIController:IsVisible(VIEW_ID)()
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
						ClipsDescendants = true,
						Position = UDim2.fromScale(0, 0),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(1, 1),

						create("UIGridLayout")({
							Name = "UIGridLayout",
							CellPadding = spring(function()
								return if UIController:IsVisible(VIEW_ID)()
									then UDim2.fromScale(0.0015, 0.012)
									else UDim2.fromScale(-0.015, 0.012)
							end, 0.5, 1),
							CellSize = UDim2.fromScale(0.192543, 0.329466),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						values(towerInventory, function(towers, towerName)
							local buttons = {}

							for towerKey, towerData in towers do
								local layoutOrder = function()
									return sortedUnitRanks()[getUnitId(towerName(), towerKey)] or 999999
								end
								local shouldMount = derive(function()
									return isInventoryVisible()
										and matchesSearch(towerName(), towerKey, towerData)
								end)

								table.insert(buttons, show(shouldMount, function()
									return TowerButton({
										TowerName = towerName(),
										TowerKey = towerKey,
										TowerData = towerData,
										IsSelected = function()
											return if selectedName() == towerName()
													and selectedKey() == towerKey
												then true
												else false
										end,
										IsEquipped = function()
											return InventoryClient.IsEquipped(towerName(), towerKey)
										end,
										EquippedSlot = function()
											return InventoryClient.FindEquippedSlot(towerName(), towerKey)
										end,
										LayoutOrder = layoutOrder,
										OnActivated = function()
											UnitUI.OnSelected(towerName(), towerKey, towerData)
										end,
									})
								end))
							end

							return buttons
						end),
					}),

					create("TextLabel")({
						Name = "EmptySearchResult",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.48),
						Size = UDim2.fromScale(0.72, 0.1),
						Text = "NO UNITS FOUND",
						TextColor3 = Color3.fromRGB(218, 218, 226),
						TextScaled = true,
						Visible = function()
							return normalizeSearch(searchQuery()) ~= "" and matchingUnitCount() == 0
						end,
						ZIndex = 4,

						create("UIStroke")({
							Color = Color3.fromRGB(32, 28, 60),
							Thickness = 2,
						}),
					}),
				}),

				create("ImageButton")({
					Name = "SearchButton",
					BackgroundTransparency = 1,
					Image = "rbxassetid://97005389138079",
					LayoutOrder = 6,
					Position = UDim2.fromScale(0.033053, 0.0172543),
					Size = UDim2.fromScale(0.0794115, 0.0921883),

					Activated = function()
						if normalizeSearch(searchQuery()) ~= "" then
							searchQuery("")
						elseif searchTextBox then
							searchTextBox:CaptureFocus()
						end
					end,

					useButtonEffect(0.94, 1.06),

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
						return if UIController:IsVisible(VIEW_ID)()
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
						ClearTextOnFocus = false,
						PlaceholderText = "UNIT NAME, RARITY, LEVEL",
						Text = searchQuery,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Left,

						changed("Text", function(value: string)
							searchQuery(value)
						end),

						action(function(textBox: TextBox)
							searchTextBox = textBox
							cleanup(function()
								if searchTextBox == textBox then
									searchTextBox = nil
								end
							end)
						end),

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
					Name = "UnitLimit",
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
							local total = math.round(animatedCount())
							if normalizeSearch(searchQuery()) ~= "" then
								return `{matchingUnitCount()}/{total}`
							end
							return `{total}/100`
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
					return if UIController:IsVisible(VIEW_ID)()
						then UDim2.fromScale(0.596001, 0.170108)
						else UDim2.fromScale(0.625, 0.170108)
				end, 0.4, 0.5),
				Size = spring(function()
					return if UIController:IsVisible(VIEW_ID)()
						then UDim2.fromScale(0.382446, 0.697631)
						else UDim2.fromScale(0.425, 0.697631)
				end, 0.4, 0.5),
				ZIndex = 10,

				create("UIGradient")({
					Name = "UIGradient",
					Color = function()
						local selectedInfo = TowerData.ByName[selectedName()]
						local secondColor = if selectedInfo
							then RarityGradient.Glow[selectedInfo.Rarity]
							else Color3.new(1, 1, 1)

						return ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),
							ColorSequenceKeypoint.new(1, secondColor),
						})
					end,
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
					Size = function()
						local requiredExp = selectedRequiredExp()
						local ratio = if requiredExp == 0 then 1 else math.clamp(selectedExp() / requiredExp, 0, 1)
						return UDim2.fromScale(0.813106 * ratio, 0.0421658)
					end,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(147, 120, 12)),
							ColorSequenceKeypoint.new(0.494898, Color3.fromRGB(251, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(254, 255, 203)),
						}),
					}),
				}),

				create("TextLabel")({
					Name = "LevelTag",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.484, 0.836),
					Size = UDim2.fromScale(0.686, 0.042),
					Text = function()
						local level = selectedLevel()
						local requiredExp = selectedRequiredExp()
						if level >= DataConstants.MAX_TOWER_LEVEL then
							return string.format("LV.%d MAX", level)
						end
						return string.format("LV.%d (%d/%d XP)", level, selectedExp(), requiredExp)
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create("UIStroke")({
						Name = "UIStroke",
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
					Text = function()
						local towerName = selectedName()
						return if towerName then UnitCatalog.GetRarity(towerName) else ""
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,

					create("UIStroke")({
						Name = "UIStroke",
					}),

					create("UIGradient")({
						Name = "UIGradient",
						useColorSequenceCycle(function()
							local towerName = selectedName()
							return if towerName
								then RarityGradient.Gradients[UnitCatalog.GetRarity(towerName)]
									or RarityGradient.Gradients.Common
								else ColorSequence.new(Color3.new(1, 1, 1))
						end, function()
							local towerName = selectedName()
							return if towerName
								then RarityGradient.ShimmerSpeed[UnitCatalog.GetRarity(towerName)] or 1
								else 1
						end),
					}),
				}),

				TowerViewport({
					TowerName = selectedName,
					AnimationName = "Idle",
					AnimationLevel = selectedLevel,
					AnimationFadeTime = 0,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.59),
					Size = UDim2.fromScale(0.86, 0.74),
					UseViewportModel = true,
					UseCharacterBounds = true,
					FitPadding = 1.1,
					CameraDirection = Vector3.new(0, 0, -1),
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
					return if UIController:IsVisible(VIEW_ID)()
						then UDim2.fromScale(0.787698, 0.920119)
						else UDim2.fromScale(0.787698, 1.05)
				end, 0.75, 0.65),
				Size = UDim2.fromScale(0.337246, 0.0842378),
				ZIndex = 11,

				MouseButton1Click = UnitUI.EquipActivated,

				useButtonEffect(0.985),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.237766),
					Size = UDim2.fromScale(0.467855, 0.487941),
					Text = function()
						local towerName = selectedName()
						local towerKey = selectedKey()

						if
							type(towerName) ~= "string"
							or (type(towerKey) ~= "string" and type(towerKey) ~= "number")
						then
							return "EQUIP"
						end

						return if InventoryClient.IsEquipped(towerName, towerKey) then "UNEQUIP" else "EQUIP"
					end,
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
					return if UIController:IsVisible(VIEW_ID)() then 0 else -1800
				end, 1, 0.8),
				Position = spring(function()
					return if UIController:IsVisible(VIEW_ID)()
						then UDim2.fromScale(0.980096, 0.0289194)
						else UDim2.fromScale(0.2, 0.0289194)
				end, 1, 0.85),
				Size = UDim2.fromScale(0.102144, 0.15458),

				MouseButton1Click = function()
					UIController:Close(VIEW_ID)
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

function UnitUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
	towerInventory = InventoryClient.Towers
end

function UnitUI.Start() end

return UnitUI
