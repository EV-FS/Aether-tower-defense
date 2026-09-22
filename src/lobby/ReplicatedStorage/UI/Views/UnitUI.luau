local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
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
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local towerInventory = source({})
local currentSort = source("Rarity")
local searchQuery = source("")

local VIEW_ID = "Units"

local SORT_CRITERIA = { "Rarity", "ABC", "Level" }
local VIRTUAL_OVERSCAN_ROWS = 1
local VIRTUAL_COLUMNS = 5
local VIRTUAL_OUTER_PADDING_X = 0.018
local VIRTUAL_OUTER_PADDING_Y_PIXELS = 10
local VIRTUAL_CELL_WIDTH = 0.1832
local VIRTUAL_PADDING_X = 0.012
local VIRTUAL_CARD_ASPECT_RATIO = 1.05
local VIRTUAL_PADDING_Y_PIXELS = 14
local VIRTUAL_FALLBACK_HEIGHT_PIXELS = 128
local selectedName = source(nil)
local selectedKey = source()
local selectedDamage = source(0)
local selectedCooldown = source(0)
local selectedRange = source(0)
local selectedMaxTower = source(0)
local unitActionPending = source(false)
local unitActionFeedback = source("")
local unitActionSucceeded = source(true)

local isLast = false

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
		return if a.RarityOrder ~= b.RarityOrder then a.RarityOrder < b.RarityOrder else nil
	elseif criterion == "ABC" then
		return if a.LowerName ~= b.LowerName then a.LowerName < b.LowerName else nil
	elseif criterion == "Level" then
		return if a.Level ~= b.Level then a.Level > b.Level else nil
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
	local menuMotion = useMenuMotion(isInventoryVisible, function()
		return UIController:GetActiveView()
	end)
	local searchTextBox: TextBox? = nil
	local scrollingFrame = source(nil :: ScrollingFrame?)
	local virtualCellHeight = source(VIRTUAL_FALLBACK_HEIGHT_PIXELS)
	local visibleStartRank = source(1)
	local visibleEndRank = source(0)
	local sellConfirmation = source(false)
	local unitEntryCache = {}
	local selectedTowerData = derive(function()
		return getOwnedTower(selectedName(), selectedKey())
	end)
	local selectedLevel = derive(function()
		local towerData = selectedTowerData()
		return if towerData and typeof(towerData.Lv) == "number" then towerData.Lv else 0
	end)
	local selectedTraitInfo = derive(function()
		local towerData = selectedTowerData()
		return if towerData and towerData.Trait then TraitData.ByName[towerData.Trait] else nil
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
	local hasSelectedUnit = derive(function()
		return selectedTowerData() ~= nil and not unitActionPending()
	end)
	local selectedLocked = derive(function()
		local towerData = selectedTowerData()
		return towerData ~= nil and towerData.Locked == true
	end)
	local sortedUnits = derive(function()
		local primaryCriterion = currentSort()
		local priorities = { primaryCriterion }
		local units = {}
		local seenUnitIds = {}

		for _, criterion in SORT_CRITERIA do
			if criterion ~= primaryCriterion then
				table.insert(priorities, criterion)
			end
		end

		for towerName, towers in towerInventory() do
			for towerKey, towerData in towers do
				local unitId = getUnitId(towerName, towerKey)
				local equippedSlot = InventoryClient.FindEquippedSlot(towerName, towerKey)
				local unit = unitEntryCache[unitId]
				if not unit or unit.Data ~= towerData or unit.EquippedSlot ~= equippedSlot then
					local rarity = UnitCatalog.GetRarity(towerName)
					local level = if typeof(towerData.Lv) == "number" then towerData.Lv else 0
					unit = {
						Name = towerName,
						Key = towerKey,
						Data = towerData,
						EquippedSlot = equippedSlot,
						RarityOrder = RarityRegistry.GetOrder(rarity),
						LowerName = string.lower(towerName),
						Level = level,
						SearchText = string.lower(`{towerName} {rarity} {towerKey} level {level} lv {level}`),
					}
					unitEntryCache[unitId] = unit
				end
				seenUnitIds[unitId] = true
				table.insert(units, unit)
			end
		end
		for unitId in unitEntryCache do
			if not seenUnitIds[unitId] then
				unitEntryCache[unitId] = nil
			end
		end

		table.sort(units, function(a, b)
			return comesBefore(a, b, priorities)
		end)

		return units
	end)
	local unitListing = derive(function()
		local query = normalizeSearch(searchQuery())
		local filtered = {}
		for _, unit in sortedUnits() do
			if query == "" or string.find(unit.SearchText, query, 1, true) ~= nil then
				table.insert(filtered, unit)
			end
		end
		return {
			Count = #filtered,
			Units = filtered,
		}
	end)
	local visibleUnits = derive(function()
		local listing = unitListing()
		local visible = {}
		local lastRank = math.min(visibleEndRank(), listing.Count)
		for rank = visibleStartRank(), lastRank do
			local unit = listing.Units[rank]
			if unit then
				visible[rank] = unit
			end
		end
		return visible
	end)

	local function updateVirtualWindow()
		if not isInventoryVisible() then
			-- Keep the small rendered pool alive while closed so reopening is free.
			return
		end

		local frame = scrollingFrame()
		if not frame then
			visibleStartRank(1)
			visibleEndRank(25)
			return
		end

		local viewportSize = frame.AbsoluteWindowSize
		if viewportSize.X <= 0 or viewportSize.Y <= 0 then
			visibleStartRank(1)
			visibleEndRank(25)
			return
		end

		local nextCellHeight = math.max(math.floor(viewportSize.X * VIRTUAL_CELL_WIDTH / VIRTUAL_CARD_ASPECT_RATIO + 0.5), 1)
		virtualCellHeight(nextCellHeight)
		local rowStride = nextCellHeight + VIRTUAL_PADDING_Y_PIXELS
		local contentY = math.max(frame.CanvasPosition.Y - VIRTUAL_OUTER_PADDING_Y_PIXELS, 0)
		local firstRow = math.max(math.floor(contentY / rowStride) - VIRTUAL_OVERSCAN_ROWS, 0)
		local visibleRows = math.ceil(viewportSize.Y / rowStride) + VIRTUAL_OVERSCAN_ROWS * 2 + 1

		visibleStartRank(firstRow * VIRTUAL_COLUMNS + 1)
		visibleEndRank((firstRow + visibleRows) * VIRTUAL_COLUMNS)
	end

	effect(function()
		local frame = scrollingFrame()
		local _listing = unitListing()
		local _isVisible = isInventoryVisible()
		updateVirtualWindow()
		if not frame then
			return
		end

		local connections = {
			frame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVirtualWindow),
			frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateVirtualWindow),
		}
		cleanup(function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end)
	end)

	local previousListMode = `{currentSort()}\0{normalizeSearch(searchQuery())}`
	effect(function()
		local listMode = `{currentSort()}\0{normalizeSearch(searchQuery())}`
		local frame = scrollingFrame()
		if frame and listMode ~= previousListMode then
			frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, 0)
		end
		previousListMode = listMode
	end)

	local openSFX = useAudio({
		Id = UISFX.UnitsOpen.Id,
		Volume = UISFX.UnitsOpen.Volume,
	})
	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})
	local equipSFX = useAudio({
		Id = UISFX.Equip.Id,
		Volume = UISFX.Equip.Volume,
	})
	local unequipSFX = useAudio({
		Id = UISFX.Uneqiup.Id,
		Volume = UISFX.Uneqiup.Volume,
	})
	local sellSFX = useAudio({
		Id = UISFX.Sell.Id,
		Volume = UISFX.Sell.Volume,
	})
	local lockSFX = useAudio({
		Id = UISFX.Lock.Id,
		Volume = UISFX.Lock.Volume,
	})
	local sortSFX = useAudio({
		Id = UISFX.Sort.Id,
		Volume = UISFX.Sort.Volume,
	})
	local feedbackToken = 0
	local sellConfirmationToken = 0
	local function runUnitAction(actionName: "ToggleUnitLock" | "SellUnit", successSFX)
		if unitActionPending() then
			return
		end

		local towerName = selectedName()
		local towerKey = selectedKey()
		if type(towerName) ~= "string" or (type(towerKey) ~= "string" and type(towerKey) ~= "number") then
			return
		end

		sellConfirmationToken += 1
		sellConfirmation(false)
		feedbackToken += 1
		unitActionPending(true)
		unitActionSucceeded(true)
		unitActionFeedback(if actionName == "SellUnit" then "SELLING..." else "UPDATING...")

		InventoryClient.PerformUnitAction(actionName, towerName, towerKey)
			:andThen(function(result)
				local succeeded = result.Success == true
				unitActionSucceeded(succeeded)
				unitActionFeedback(result.Message or (if succeeded then "DONE" else "ACTION FAILED"))
				if succeeded then
					successSFX:Play()
					if actionName == "SellUnit" then
						selectedName(nil)
						selectedKey(nil)
					end
				end
			end)
			:catch(function(err)
				unitActionSucceeded(false)
				unitActionFeedback(tostring(err))
			end)
			:finally(function()
				unitActionPending(false)
				feedbackToken += 1
				local token = feedbackToken
				task.delay(2.5, function()
					if feedbackToken == token then
						unitActionFeedback("")
					end
				end)
			end)
	end
	local function requestSell()
		if unitActionPending() then
			return
		end
		if sellConfirmation() then
			sellConfirmation(false)
			runUnitAction("SellUnit", sellSFX)
			return
		end

		sellConfirmation(true)
		sellConfirmationToken += 1
		local token = sellConfirmationToken
		feedbackToken += 1
		unitActionSucceeded(false)
		unitActionFeedback("PRESS SELL AGAIN TO CONFIRM")
		task.delay(2.5, function()
			if sellConfirmationToken == token and sellConfirmation() then
				sellConfirmation(false)
				unitActionFeedback("")
			end
		end)
	end

	effect(function()
		local _towerName = selectedName()
		local _towerKey = selectedKey()
		sellConfirmationToken += 1
		sellConfirmation(false)
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

	effect(function()
		if UIController:IsVisible(VIEW_ID)() then
			isLast = true
			openSFX:Play()
		elseif isLast then
			isLast = false
			closeSFX:Play()
		end
	end)

	local animatedCount = spring(storageCount, 0.5, 1)
	local animatedDamage = spring(selectedDamage, 0.5, 1)
	local animatedCooldown = spring(selectedCooldown, 0.5, 1)
	local animatedRange = spring(selectedRange, 0.5, 1)
	local animatedMaxTower = spring(selectedMaxTower, 0.5, 1)

	return create("CanvasGroup")({
		Name = "Units", GroupTransparency = menuMotion.Transparency, Interactable = isInventoryVisible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = menuMotion.IsMounted,

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://86505261925755",
			Rotation = menuMotion:WindowRotation(),

			Position = UDim2.fromScale(0.5, 0.20195),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.668872)),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://79038669500555",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Star",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://111343804919469",
					Rotation = menuMotion:IconRotation(),
					Position = UDim2.fromScale(0.133, 0.478),
					Size = menuMotion:IconSize(UDim2.fromScale(0.184974, 0.837933)),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://122017999272407",
					ImageTransparency = menuMotion:Fade(),

					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)),
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
					TextTransparency = menuMotion:Fade(),
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
					Active = hasSelectedUnit,
					BackgroundTransparency = 1,
					Image = "rbxassetid://101405228511471",
					ImageTransparency = function()
						return if hasSelectedUnit() then 0 else 0.45
					end,
					Position = UDim2.fromScale(-0.00261403, 0.882837),
					Size = UDim2.fromScale(1, 0.117596),
					ZIndex = 20,

					create("ImageButton")({
						Name = "SellButton",
						Active = hasSelectedUnit,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://76383008324602",
						ImageTransparency = function()
							return if hasSelectedUnit() then 0 else 0.45
						end,
						Position = menuMotion:Spring(UDim2.fromScale(0.24, 0.5), UDim2.fromScale(0.24, 1.2), "Content"),
						Size = UDim2.fromScale(0.251482, 0.782844),
						ZIndex = 21,
						Activated = function()
							requestSell()
						end,

						useButtonEffect(nil, nil, true),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.265238, 0.237766),
							Size = UDim2.fromScale(0.467855, 0.487941),
							Text = function()
								return if sellConfirmation() then "CONFIRM" else "SELL"
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						}),
					}),

					create("ImageButton")({
						Name = "LockButton",
						Active = hasSelectedUnit,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://70564113534462",
						ImageTransparency = function()
							return if hasSelectedUnit() then 0 else 0.45
						end,
						Position = menuMotion:Spring(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 1.4), "Content"),
						Size = UDim2.fromScale(0.251482, 0.782844),
						ZIndex = 21,
						Activated = function()
							runUnitAction("ToggleUnitLock", lockSFX)
						end,

						useButtonEffect(nil, nil, true),

						create("TextLabel")({
							Name = "Title",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.265238, 0.237766),
							Size = UDim2.fromScale(0.467855, 0.487941),
							Text = function()
								return if selectedLocked() then "UNLOCK" else "LOCK"
							end,
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
						Position = menuMotion:Spring(UDim2.fromScale(0.76, 0.5), UDim2.fromScale(0.76, 1.6), "Content"),
						Size = UDim2.fromScale(0.251482, 0.782844),
						Selectable = true,
						ZIndex = 21,

						Activated = function()
							UnitUI.SortActivated()
							sortSFX:Play()
						end,

						useButtonEffect(nil, nil, true),

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

					create("TextLabel")({
						Name = "ActionFeedback",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, -0.08),
						Size = UDim2.fromScale(0.85, 0.3),
						Text = unitActionFeedback,
						TextColor3 = function()
							return if unitActionSucceeded()
								then Color3.fromRGB(163, 255, 126)
								else Color3.fromRGB(255, 113, 113)
						end,
						TextScaled = true,
						Visible = function()
							return unitActionFeedback() ~= ""
						end,
						ZIndex = 25,

						create("UIStroke")({ Thickness = 1.5 }),
					}),
				}),

				create("CanvasGroup")({
					Name = "ScrollBackground",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = menuMotion:Spring(UDim2.fromScale(0.0339824, 0.124035), UDim2.fromScale(-0.03, 0.124035), "Content"),
					Size = UDim2.fromScale(0.966018, 0.758802),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.None,
						BackgroundTransparency = 1,
						CanvasSize = function()
							local rows = math.ceil(unitListing().Count / VIRTUAL_COLUMNS)
							local height = if rows > 0
								then VIRTUAL_OUTER_PADDING_Y_PIXELS * 2
									+ rows * virtualCellHeight()
									+ (rows - 1) * VIRTUAL_PADDING_Y_PIXELS
								else 0
							return UDim2.fromOffset(0, height)
						end,
						ClipsDescendants = true,
						Position = UDim2.fromScale(0, 0),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Size = UDim2.fromScale(1, 1),

						action(function(instance: ScrollingFrame)
							scrollingFrame(instance)
							cleanup(function()
								if scrollingFrame() == instance then
									scrollingFrame(nil)
								end
							end)
						end),

						values(visibleUnits, function(unit, rank)
							local towerName = unit.Name
							local towerKey = unit.Key
							local towerData = unit.Data
							return TowerButton({
								Name = `Unit_{towerName}_{tostring(towerKey)}`,
								TowerName = towerName,
								TowerKey = towerKey,
								TowerData = towerData,
								PerformanceMode = true,
								Position = function()
									local zeroBasedRank = math.max((rank() or 1) - 1, 0)
									local column = zeroBasedRank % VIRTUAL_COLUMNS
									local row = math.floor(zeroBasedRank / VIRTUAL_COLUMNS)
									return UDim2.new(
										VIRTUAL_OUTER_PADDING_X
											+ column * (VIRTUAL_CELL_WIDTH + VIRTUAL_PADDING_X),
										0,
										0,
										VIRTUAL_OUTER_PADDING_Y_PIXELS
											+ row * (virtualCellHeight() + VIRTUAL_PADDING_Y_PIXELS)
									)
								end,
								Size = function()
									return UDim2.new(VIRTUAL_CELL_WIDTH, 0, 0, virtualCellHeight())
								end,
								IsSelected = function()
									return selectedName() == towerName and selectedKey() == towerKey
								end,
								IsEquipped = function()
									return InventoryClient.IsEquipped(towerName, towerKey)
								end,
								EquippedSlot = function()
									return InventoryClient.FindEquippedSlot(towerName, towerKey)
								end,
								IsLocked = function()
									return towerData.Locked == true
								end,
								OnActivated = function()
									UnitUI.OnSelected(towerName, towerKey, towerData)
								end,
							})
						end),
					}),

					create("TextLabel")({
						Name = "EmptySearchResult",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.48),
						Size = UDim2.fromScale(0.72, 0.1),
						Text = function()
							return if normalizeSearch(searchQuery()) == "" then "NO UNITS OWNED" else "NO UNITS FOUND"
						end,
						TextColor3 = Color3.fromRGB(218, 218, 226),
						TextScaled = true,
						Visible = function()
							return unitListing().Count == 0
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
					Size = menuMotion:SearchSize(UDim2.fromScale(0.702835, 0.0921883)),

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
								return `{unitListing().Count}/{total}`
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
				Position = menuMotion:Spring(UDim2.fromScale(0.596001, 0.170108), UDim2.fromScale(0.625, 0.170108), "Detail"),
				Size = menuMotion:Spring(UDim2.fromScale(0.382446, 0.697631), UDim2.fromScale(0.425, 0.697631), "Detail"),
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
						end, nil, isInventoryVisible),
					}),
				}),

				TowerViewport({
					TowerName = selectedName,
					Active = isInventoryVisible,
					AnimationName = "Idle",
					AnimationLevel = selectedLevel,
					AnimationFadeTime = 0,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.59),
					Size = UDim2.fromScale(0.86, 0.74),
					UseViewportModel = true,
					UseCharacterBounds = false,
					UsePortraitBounds = false,
					CenterOnRoot = true,
					RenderEffects = false,
					FitPadding = function()
						return UnitViewportProfiles.GetDetail(selectedName() or "").FitPadding
					end,
					FieldOfView = 35,
					FocusYOffset = function()
						return UnitViewportProfiles.GetDetail(selectedName() or "").FocusYOffset
					end,
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
						Color = function()
							local info = selectedTraitInfo()
							return ColorSequence.new(if info then info.Color else Color3.fromRGB(255, 246, 144))
						end,
					}),

					create("ImageLabel")({
						Name = "Trait",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = function()
							local info = selectedTraitInfo()
							return if info then info.Image else ""
						end,
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
				Position = menuMotion:Spring(UDim2.fromScale(0.787698, 0.920119), UDim2.fromScale(0.787698, 1.05), "Action"),
				Size = UDim2.fromScale(0.337246, 0.0842378),
				ZIndex = 11,

				MouseButton1Click = function()
					UnitUI.EquipActivated()

					local towerName = selectedName()
					local towerKey = selectedKey()

					if type(towerName) ~= "string" or (type(towerKey) ~= "string" and type(towerKey) ~= "number") then
						return
					end

					if InventoryClient.IsEquipped(towerName, towerKey) then
						unequipSFX:Play()
					else
						equipSFX:Play()
					end
				end,

				useButtonEffect(0.985, nil, true),

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
				Rotation = menuMotion:CloseRotation(),
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Size = UDim2.fromScale(0.102144, 0.15458),

				MouseButton1Click = function()
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(nil, 1.1, true),

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
