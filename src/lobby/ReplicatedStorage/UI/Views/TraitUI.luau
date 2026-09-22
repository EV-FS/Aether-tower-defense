local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local VIEW_ID = "Traits"
local TOUCH_FOLDER = "TouchZone"
local TOUCH_PART = "TraitTouch"

local InventoryClient
local TraitClient
local DataClient
local UIController

type UnitSelection = {
	Name: string,
	Key: string | number,
}

-- Keep the name and inventory key atomic. Updating them as separate sources lets
-- the validation effect observe a temporary "new name + old key" selection.
local selectedUnit = source(nil :: UnitSelection?)
local isRolling = source(false)
local statusText = source("SELECT A UNIT")
local isUnitPickerOpen = source(false)
local traitZone

local TraitUI = {}

local function getUnits()
	local units = {}
	for towerName, towerCollection in InventoryClient.Towers() do
		for towerKey, tower in towerCollection do
			table.insert(units, { Name = towerName, Key = towerKey, Data = tower })
		end
	end
	table.sort(units, function(a, b)
		if a.Name == b.Name then return a.Key < b.Key end
		return a.Name < b.Name
	end)
	return units
end

local function ensureSelection()
	local selection = selectedUnit()
	if selection and InventoryClient.GetTower(selection.Name, selection.Key) then return end
	local first = getUnits()[1]
	selectedUnit(if first then { Name = first.Name, Key = first.Key } else nil)
	statusText(if first then "READY TO ROLL" else "NO UNITS OWNED")
end

local function selectUnit(towerName: string, towerKey: string | number)
	selectedUnit({ Name = towerName, Key = towerKey })
	isUnitPickerOpen(false)
	statusText("READY TO ROLL")
end

local function rollSelected()
	if isRolling() then return end
	local selection = selectedUnit()
	if not selection then
		statusText("SELECT A UNIT")
		return
	end
	local towerName, towerKey = selection.Name, selection.Key
	if DataClient.Gems() < TraitData.RollCost then
		statusText(`NEED {TraitData.RollCost} GEMS`)
		return
	end

	isRolling(true)
	statusText("ROLLING...")
	TraitClient.Roll(towerName, towerKey):andThen(function(result)
		isRolling(false)
		if result.Success == true then
			statusText(`ROLLED: {string.upper(result.Trait)}`)
		else
			statusText(string.upper(result.Message or "ROLL FAILED"))
		end
	end):catch(function(err)
		isRolling(false)
		statusText("ROLL FAILED")
		warn(`[TraitUI] Roll failed: {err}`)
	end)
end

local function traitRow(trait)
	return create("ImageLabel")({
		Name = trait.Name,
		BackgroundTransparency = 1,
		Image = "rbxassetid://92748570815326",
		LayoutOrder = trait.Index,
		Size = UDim2.fromScale(1, 0.11206),
		create("UIAspectRatioConstraint")({ AspectRatio = 3.5 }),
		create("ImageLabel")({
			Name = "Icon", BackgroundTransparency = 1, Image = trait.Image,
			Position = UDim2.fromScale(0.0316361, 0.184112), Size = UDim2.fromScale(0.179429, 0.628001), ScaleType = Enum.ScaleType.Fit,
			create("UIAspectRatioConstraint")({}),
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(121, 224, 255), Color3.fromRGB(255, 134, 243)) }),
		}),
		create("TextLabel")({
			Name = "Title", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.225422, 0.134451), Size = UDim2.fromScale(0.44, 0.290134),
			Text = string.upper(trait.Name), TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(146, 255, 248), Color3.fromRGB(249, 160, 255)) }),
		}),
		create("TextLabel")({
			Name = "Description", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.236, 0.433), Size = UDim2.fromScale(0.62, 0.547303),
			Text = trait.Description, TextColor3 = Color3.fromRGB(231, 231, 240), TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(146, 255, 248), Color3.fromRGB(249, 160, 255)) }),
		}),
		create("TextLabel")({
			Name = "Percent", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.849117, 0.107244), Size = UDim2.fromScale(0.11577, 0.22921),
			Text = `{trait.Chance}%`, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(146, 255, 248), Color3.fromRGB(249, 160, 255)) }),
		}),
	})
end

local function unitPickerCard(towerName: string, towerKey: string | number, tower)
	local isSelected = function()
		local selection = selectedUnit()
		return selection ~= nil and selection.Name == towerName and selection.Key == towerKey
	end
	return create("ImageButton")({
		Name = `{towerName}_{towerKey}`, Active = true, AutoButtonColor = false, BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095", Size = UDim2.fromScale(0.225, 0.34),
		Activated = function() selectUnit(towerName, towerKey) end,
		useButtonEffect(0.94, 1.04),
		create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(72, 68, 101), Color3.fromRGB(143, 119, 207)), Rotation = 45 }),
		create("UIStroke")({ Color = Color3.new(1, 1, 1), Thickness = function() return if isSelected() then 3 else 0 end }),
		create("ImageLabel")({
			Name = "Unit", BackgroundTransparency = 1, Image = UnitCatalog.GetImage(towerName),
			Position = UDim2.fromScale(0.08, 0.08), Size = UDim2.fromScale(0.84, 0.63), ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
		}),
		create("TextLabel")({
			Name = "Name", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.07, 0.68), Size = UDim2.fromScale(0.86, 0.13), Text = towerName,
			TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
			create("UIStroke")({ Thickness = 1.5 }),
		}),
		create("TextLabel")({
			Name = "Level", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.15, 0.82), Size = UDim2.fromScale(0.7, 0.1), Text = `LV. {tower.Lv or 1}`,
			TextColor3 = Color3.fromRGB(226, 216, 255), TextScaled = true, ZIndex = 4,
		}),
	})
end

function TraitUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local selectedTower = derive(function()
		local selection = selectedUnit()
		return if selection then InventoryClient.GetTower(selection.Name, selection.Key) else nil
	end)
	local currentTrait = derive(function()
		local tower = selectedTower()
		return tower and tower.Trait or nil
	end)
	local traitInfo = derive(function()
		local trait = currentTrait()
		return if trait then TraitData.ByName[trait] else nil
	end)

	effect(function()
		local _towers = InventoryClient.Towers()
		if isVisible() then ensureSelection() end
	end)

	local rows = table.create(#TraitData.ByIndex)
	for _, trait in TraitData.ByIndex do table.insert(rows, traitRow(trait)) end

	return create("CanvasGroup")({
		Name = "Container", GroupTransparency = menuMotion.Transparency, Interactable = isVisible, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.753032, 1), Visible = menuMotion.IsMounted,
		create("ImageLabel")({
			Name = "Main", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Image = "rbxassetid://96882538048826",
			Position = UDim2.fromScale(0.498839, 0.20195),
			Rotation = menuMotion:WindowRotation(),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.593865)),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageLabel")({
				Name = "Header", BackgroundTransparency = 1, Image = "rbxassetid://130457374557135",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.057, -0.111)),
				Size = UDim2.fromScale(0.683091, 0.28349), ZIndex = 10,
				create("ImageLabel")({ Name = "Icon", Rotation = menuMotion:IconRotation(), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://126800652570353", Position = UDim2.fromScale(0.134912, 0.527015), Size = menuMotion:IconSize(UDim2.fromScale(0.189824, 1.16203)), create("UIAspectRatioConstraint")({ AspectRatio = 0.74 }) }),
				create("ImageLabel")({ Name = "Cloud", BackgroundTransparency = 1, Image = "rbxassetid://108560268349568", ImageTransparency = menuMotion:Fade(), Position = menuMotion:CloudPosition(UDim2.fromScale(0.604824, 0.043466)), Size = UDim2.fromScale(0.507418, 1.06417), create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }) }),
				create("TextLabel")({ Name = "Title", TextTransparency = menuMotion:Fade(), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.265238, 0.435573), Size = UDim2.fromScale(0.283423, 0.290134), Text = "TRAITS", TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
			}),
			create("ImageButton")({ Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)), Rotation = menuMotion:CloseRotation(), Size = UDim2.fromScale(0.0822234, 0.15458), ZIndex = 10, Activated = function() UIController:Close(VIEW_ID) end, useButtonEffect(nil, 1.1), create("UIAspectRatioConstraint")({}) }),
			create("ImageLabel")({ Name = "BGdecoLeft", BackgroundTransparency = 1, Image = "rbxassetid://83809640524117", Position = UDim2.fromScale(0.0297514, 0.0680275), Size = UDim2.fromScale(0.270332, 0.388118) }),
			create("ImageLabel")({ Name = "BGdecoRight", BackgroundTransparency = 1, Image = "rbxassetid://136182191255134", Position = UDim2.fromScale(0.556767, 0.418054), Size = UDim2.fromScale(0.431686, 0.545469) }),
			create("ImageLabel")({
				Name = "ButtonHolder", BackgroundTransparency = 1, Image = "rbxassetid://114923401047801",
				Position = UDim2.fromScale(0.365834, 0.0423376), Size = UDim2.fromScale(0.589304, 0.921186), ZIndex = 3,
				create("ImageButton")({
					Name = "ImageButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
					Active = true, AutoButtonColor = false, Image = "rbxassetid://87496848270095", LayoutOrder = 6,
					Position = UDim2.fromScale(0.525, 0.5), Size = UDim2.fromScale(0.214411, 0.257868),
					Activated = function() isUnitPickerOpen(true) end, useButtonEffect(0.96, 1.03),
					create("UIAspectRatioConstraint")({}),
					create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(164, 246, 255)), Rotation = 45 }),
					create("ImageLabel")({
						Name = "Level", BackgroundTransparency = 1, Image = "rbxassetid://104083646922843",
						Position = UDim2.fromScale(-0.0129994, -0.05), Size = UDim2.fromScale(0.653434, 0.238322), ZIndex = 10,
						create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
						create("TextLabel")({ Name = "TextLabel", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(0.3, 0.489), Size = UDim2.fromScale(0.477775, 0.75514), Text = function() local tower = selectedTower(); return `LV. {tower and tower.Lv or 1}` end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, create("UIStroke")({ Thickness = 2 }), create("UIGradient")({ Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(104, 106, 211)), Rotation = 90 }) }),
					}),
					create("ImageLabel")({ Name = "Trait", BackgroundTransparency = 1, Image = function() local info = traitInfo(); return if info then info.Image else "" end, Position = UDim2.fromScale(0.64, 0.03), Size = UDim2.fromScale(0.359565, 0.31687), Visible = function() return traitInfo() ~= nil end, ZIndex = 10, create("UIAspectRatioConstraint")({}) }),
					create("TextLabel")({ Name = "Price", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(0.108, 0.782623), Size = UDim2.fromScale(0.641, 0.2), Text = function() return string.upper(currentTrait() or "NONE") end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10, create("UIStroke")({ Thickness = 2 }), create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 152, 62), Color3.fromRGB(255, 160, 26)), Rotation = 90 }) }),
					create("TextLabel")({ Name = "Name", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(0.107999, 0.618754), Size = UDim2.fromScale(0.84887, 0.172688), Text = function() local selection = selectedUnit(); return if selection then selection.Name else "SELECT UNIT" end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10, create("UIStroke")({ Thickness = 2 }) }),
					TowerViewport({
						TowerName = function()
							local selection = selectedUnit()
							return if selection then selection.Name else nil
						end,
						Active = function()
							return isVisible() and selectedUnit() ~= nil
						end,
						AnimationName = "Idle",
						AnimationLevel = function()
							local tower = selectedTower()
							return tower and tower.Lv or 0
						end,
						AnimationFadeTime = 0,
						AnimationLooped = true,
						AnimationSpeed = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.51),
						Size = UDim2.fromScale(0.9, 0.9),
						UseViewportModel = true,
						UseCharacterBounds = false,
						UsePortraitBounds = true,
						CenterOnRoot = true,
						RenderEffects = false,
						FitPadding = function()
							local selection = selectedUnit()
							return UnitViewportProfiles.GetCard(if selection then selection.Name else "").FitPadding
						end,
						FocusYOffset = function()
							local selection = selectedUnit()
							return UnitViewportProfiles.GetCard(if selection then selection.Name else "").FocusYOffset
						end,
						FieldOfView = 35,
						CameraDirection = Vector3.new(0, 0, -1),
						ModelRotation = 15,
						Ambient = Color3.fromRGB(205, 205, 205),
						ZIndex = 5,
					}),
				}),
				create("ImageButton")({
					Name = "PurchaseButton", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
					Active = function() return selectedUnit() ~= nil and not isRolling() end, AutoButtonColor = false,
					Image = "rbxassetid://139274506988816", ImageTransparency = function() return if selectedUnit() and not isRolling() then 0 else 0.35 end,
					Position = UDim2.fromScale(0.440864, 0.923101), Size = UDim2.fromScale(0.39314, 0.120926),
					Activated = rollSelected, useButtonEffect(0.94, 1.05),
					create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.149276, 0.214464), Size = UDim2.fromScale(0.68577, 0.527425), Text = function() if isRolling() then return "ROLLING..." end local message = statusText(); return if message == "READY TO ROLL" or string.sub(message, 1, 7) == "ROLLED:" then "ROLL" else message end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, create("UIStroke")({}) }),
					create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(13, 255, 0), Color3.fromRGB(234, 255, 0)) }),
					create("UIAspectRatioConstraint")({ AspectRatio = 3.91 }), create("UIStroke")({ Color = Color3.new(1, 1, 1) }), create("UICorner")({}),
				}),
				create("CanvasGroup")({
					Name = "UnitPicker", BackgroundColor3 = Color3.fromRGB(25, 21, 42), BackgroundTransparency = 0.04,
					Position = spring(function() return if isUnitPickerOpen() then UDim2.fromScale(0.04, 0.075) else UDim2.fromScale(0.5, 0.5) end, 0.35, 0.8),
					Size = spring(function() return if isUnitPickerOpen() then UDim2.fromScale(0.92, 0.82) else UDim2.fromScale(0.04, 0.04) end, 0.35, 0.72),
					GroupTransparency = spring(function() return if isUnitPickerOpen() then 0 else 1 end, 0.35, 0.85), Visible = isUnitPickerOpen, ZIndex = 40, ClipsDescendants = true,
					create("UICorner")({ CornerRadius = UDim.new(0.04, 0) }), create("UIStroke")({ Color = Color3.fromRGB(178, 151, 255), Thickness = 2.5 }),
					create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.7, 0.1), Text = "SELECT A UNIT", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, create("UIStroke")({ Thickness = 2 }) }),
					create("TextButton")({ Name = "Back", AnchorPoint = Vector2.new(1, 0), AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(106, 82, 156), Position = UDim2.fromScale(0.95, 0.04), Size = UDim2.fromScale(0.16, 0.1), FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Text = "BACK", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, ZIndex = 42, Activated = function() isUnitPickerOpen(false) end, useButtonEffect(0.92, 1.06), create("UICorner")({ CornerRadius = UDim.new(0.2, 0) }), create("UIStroke")({ Color = Color3.fromRGB(211, 195, 255), Thickness = 1.5 }) }),
					create("CanvasGroup")({
						Name = "OwnedUnitsClip",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						AnchorPoint = Vector2.new(0, 0),
						Position = UDim2.fromScale(0.04, 0.17),
						Size = UDim2.fromScale(0.92, 0.78),
						ZIndex = 41,
						create("ScrollingFrame")({
							Name = "OwnedUnits", AnchorPoint = Vector2.new(0, 0), Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, CanvasSize = UDim2.new(), ClipsDescendants = true,
							Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(205, 183, 255), ZIndex = 41,
							create("UIGridLayout")({ CellPadding = UDim2.fromScale(0.02, 0.025), CellSize = UDim2.fromScale(0.225, 0.34), SortOrder = Enum.SortOrder.Name }),
							values(InventoryClient.Towers, function(towers, towerName) local cards = {} for towerKey, tower in towers do table.insert(cards, unitPickerCard(towerName(), towerKey, tower)) end return cards end),
						}),
					}),
					create("TextLabel")({ Name = "Empty", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.75, 0.1), Text = "NO UNITS OWNED", TextColor3 = Color3.fromRGB(218, 210, 233), TextScaled = true, Visible = function() return #getUnits() == 0 end, ZIndex = 43 }),
				}),
			}),
			create("CanvasGroup")({
				Name = "ScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromScale(0.0317382, 0.106916),
				Size = UDim2.fromScale(0.404726, 0.848434),
				ZIndex = 2,
				create("ScrollingFrame")({
					Name = "ScrollingFrame", AnchorPoint = Vector2.new(0, 0), Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
					CanvasSize = UDim2.new(), ClipsDescendants = true, Position = UDim2.fromScale(0, 0),
					ScrollBarImageColor3 = Color3.new(), ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.fromScale(1, 1), ZIndex = 2,
					create("UIListLayout")({ Padding = UDim.new(0.01, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
					create("UIPadding")({ PaddingTop = UDim.new(0.03, 0) }), unpack(rows),
				}),
			}),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function TraitUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	TraitClient = ServiceRegistry:GetService("TraitClient")
	DataClient = ServiceRegistry:GetService("DataClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function TraitUI.Start()
	local touchPart = workspace:WaitForChild(TOUCH_FOLDER):WaitForChild(TOUCH_PART)
	if not touchPart:IsA("BasePart") then
		warn(`[TraitUI] workspace.{TOUCH_FOLDER}.{TOUCH_PART} must be a BasePart.`)
		return
	end

	traitZone = TouchZone.new(touchPart)
	traitZone:Start()
	traitZone.Touched:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then return end
		ensureSelection()
		isUnitPickerOpen(false)
		UIController:OpenExclusive(VIEW_ID)
	end)
	traitZone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then return end
		isUnitPickerOpen(false)
		UIController:Close(VIEW_ID)
	end)
end

function TraitUI.Destroy()
	if traitZone then traitZone:Destroy() traitZone = nil end
end

return TraitUI
