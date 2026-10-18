local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CurrencyData = require(ReplicatedStorage.Settings.Data.CurrencyData)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local UnitUI = require(ReplicatedStorage.UI.Views.UnitUI)

local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source

local VIEW_ID = "Traits"
local TOUCH_FOLDER = "TouchZone"
local TOUCH_PART = "TraitTouch"

local InventoryClient
local TraitClient
local DataClient
local UIController
local ConfirmationService

type UnitSelection = {
	Name: string,
	Key: string | number,
}

-- Keep the name and inventory key atomic. Updating them as separate sources lets
-- the validation effect observe a temporary "new name + old key" selection.
local selectedUnit = source(nil :: UnitSelection?)
local isRolling = source(false)
local statusText = source("SELECT A UNIT")
local pendingConfirmation = source(nil)
local closeConfirmation: (() -> ())? = nil
local rollGeneration = 0
local traitZone

local ACTION_AVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(234, 255, 0)),
})
local ACTION_UNAVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 108, 108)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 48)),
})

local TraitUI = {}

--[[ Releases a trait replacement prompt owned by this view. ]]
local function cancelConfirmation()
	pendingConfirmation(nil)
	if closeConfirmation then
		closeConfirmation()
		closeConfirmation = nil
	end
end

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
	statusText("READY TO ROLL")
end

local function hasTraitCurrency(): boolean
	return DataClient ~= nil and DataClient.Gems() >= TraitData.RollCost
end

local function canRollTrait(): boolean
	return selectedUnit() ~= nil and not isRolling() and pendingConfirmation() == nil
		and ConfirmationService:GetCurrent() == nil and hasTraitCurrency()
end

--[[ Revalidates the reviewed unit before submitting its replacement. ]]
local function performRoll(selection: UnitSelection, expectedTrait: string?, confirmedTrait: string?)
	if isRolling() then return end
	local current = selectedUnit()
	if not UIController:IsOpen(VIEW_ID) or not current
		or current.Name ~= selection.Name or current.Key ~= selection.Key then
		return
	end
	local towerName, towerKey = selection.Name, selection.Key
	local tower = InventoryClient.GetTower(towerName, towerKey)
	if not tower or tower.Trait ~= expectedTrait or tower.Trading == true then
		statusText("UNIT CHANGED")
		NotificationFeed.Pull("The unit changed. Review it before rolling again.", "Error")
		return
	end
	if not hasTraitCurrency() then
		statusText(`NEED {TraitData.RollCost} GEMS`)
		NotificationFeed.Pull(`You need {TraitData.RollCost} Gems to reroll.`, "Error")
		return
	end

	isRolling(true)
	statusText("ROLLING...")
	local token = rollGeneration
	TraitClient.Roll(towerName, towerKey, expectedTrait, confirmedTrait):andThen(function(result)
		if token ~= rollGeneration then return end
		isRolling(false)
		local selected = selectedUnit()
		if not selected or selected.Name ~= towerName or selected.Key ~= towerKey then return end
		if result.Success == true then
			statusText(`ROLLED: {string.upper(result.Trait)}`)
		else
			statusText(string.upper(result.Message or "ROLL FAILED"))
			NotificationFeed.Pull(result.Message or "Trait reroll failed.", "Error")
		end
	end):catch(function(err)
		if token ~= rollGeneration then return end
		isRolling(false)
		statusText("ROLL FAILED")
		warn(`[TraitUI] Roll failed: {err}`)
		NotificationFeed.Pull("Trait reroll failed. Please try again.", "Error")
	end)
end

--[[ Protects valuable traits until their replacement is explicitly accepted. ]]
local function rollSelected()
	if not UIController:IsOpen(VIEW_ID) then return end
	if isRolling() or pendingConfirmation() or ConfirmationService:GetCurrent() then return end
	local selection = selectedUnit()
	if not selection then
		NotificationFeed.Pull("Select a unit first.", "Error")
		return
	end
	local tower = InventoryClient.GetTower(selection.Name, selection.Key)
	if not tower then return end
	local traitName = tower.Trait
	if not hasTraitCurrency() or not TraitData.RequiresConfirmation(traitName) then
		performRoll(selection, traitName)
		return
	end
	local trait = TraitData.ByName[traitName]
	local pending = { Name = selection.Name, Key = selection.Key, Trait = traitName }
	closeConfirmation = ConfirmationService:Prompt({
		Title = "Replace Rare Trait?",
		Text = `Reroll {trait.Name} on {selection.Name}?`,
		SubText = `{trait.Rarity}\nYour current trait will be lost.`,
		AcceptText = "Reroll",
		AcceptColor = Color3.fromRGB(255, 80, 80),
		DeclineText = "Keep",
		DeclineColor = Color3.fromRGB(80, 190, 100),
		OnAccept = function()
			pendingConfirmation(nil)
			performRoll(selection, traitName, traitName)
		end,
		OnDecline = function()
			pendingConfirmation(nil)
			statusText(`KEPT: {string.upper(traitName)}`)
		end,
	})
	pending.Request = ConfirmationService:GetCurrent()
	pendingConfirmation(pending)
end

local function traitRow(trait, rowHeight)
	local gradient = RarityRegistry.Get(trait.Rarity).Presentation.Gradient
	return create("Frame")({
		Name = trait.Name,
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		LayoutOrder = trait.Index,
		Size = function() return UDim2.new(0.92, 0, 0, rowHeight()) end,
		create("UICorner")({ CornerRadius = UDim.new(0, 10) }),
		create("UIStroke")({
			Color = Color3.new(1, 1, 1), Thickness = 2.5,
			create("UIGradient")({ Color = gradient, Rotation = 30 }),
		}),
		create("ImageLabel")({
			Name = "Icon", BackgroundTransparency = 1, Image = trait.Image,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.12, 0.5), Size = UDim2.fromScale(0.18, 0.63),
			ScaleType = Enum.ScaleType.Fit,
			create("UIGradient")({ Color = gradient }),
		}),
		create("TextLabel")({
			Name = "Title", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.23, 0.13), Size = UDim2.fromScale(0.52, 0.29),
			Text = string.upper(trait.Name), TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIGradient")({ Color = gradient }),
		}),
		create("TextLabel")({
			Name = "Description", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.23, 0.44), Size = UDim2.fromScale(0.73, 0.49),
			Text = trait.Description, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			create("UIGradient")({ Color = gradient }),
		}),
		create("TextLabel")({
			Name = "Percent", BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.77, 0.12), Size = UDim2.fromScale(0.19, 0.25),
			Text = `{trait.Chance}%`, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			create("UIGradient")({ Color = gradient }),
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
	local selectedTraitGradient = derive(function()
		local info = traitInfo()
		return RarityRegistry.Get(if info then info.Rarity else "Common").Presentation.Gradient
	end)

	effect(function()
		local _towers = InventoryClient.Towers()
		if isVisible() then ensureSelection() end
	end)
	effect(function()
		local pending = pendingConfirmation()
		if not pending then return end
		local selection = selectedUnit()
		local tower = if selection then InventoryClient.GetTower(selection.Name, selection.Key) else nil
		if not isVisible() or not selection or selection.Name ~= pending.Name or selection.Key ~= pending.Key
			or not tower or tower.Trait ~= pending.Trait or tower.Trading == true
			or ConfirmationService:GetCurrent() ~= pending.Request then
			cancelConfirmation()
		end
	end)
	cleanup(cancelConfirmation)

	local rowHeight = source(90)
	local rows = table.create(#TraitData.ByIndex)
	for _, trait in TraitData.ByIndex do table.insert(rows, traitRow(trait, rowHeight)) end

	return create("CanvasGroup")({
		Name = "Container", GroupTransparency = menuMotion.Transparency, Interactable = isVisible, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.753032, 1), Visible = menuMotion.IsMounted,
		create("ImageLabel")({
			Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://96882538048826",
			Position = UDim2.fromScale(0.498379, 0.497778),
			-- A rotated ancestor can bypass clipping on the nested scroll view.
			-- The window still animates through menuMotion:WindowSize().
			Rotation = 0,
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
					Activated = function()
						if not isRolling() then
							local selection = selectedUnit()
							UnitUI.OpenSelectionMode({
								Title = "TRAIT REROLL",
								ReturnView = VIEW_ID,
								SelectedName = selection and selection.Name,
								SelectedKey = selection and selection.Key,
								OnConfirm = function(towerName, towerKey)
									selectUnit(towerName, towerKey)
								end,
							})
						end
					end,
					useButtonEffect(0.96, 1.03),
					create("UIAspectRatioConstraint")({}),
					create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(164, 246, 255)), Rotation = 45 }),
					create("ImageLabel")({
						Name = "Level", BackgroundTransparency = 1, Image = "rbxassetid://104083646922843",
						Position = UDim2.fromScale(-0.0129994, -0.05), Size = UDim2.fromScale(0.653434, 0.238322), ZIndex = 10,
						create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
						create("TextLabel")({ Name = "TextLabel", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(0.3, 0.489), Size = UDim2.fromScale(0.477775, 0.75514), Text = function() local tower = selectedTower(); return `LV. {tower and tower.Lv or 1}` end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, create("UIStroke")({ Thickness = 2 }), create("UIGradient")({ Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(104, 106, 211)), Rotation = 90 }) }),
					}),
					create("ImageLabel")({ Name = "Trait", BackgroundTransparency = 1, Image = function() local info = traitInfo(); return if info then info.Image else "" end, Position = UDim2.fromScale(0.64, 0.03), Size = UDim2.fromScale(0.359565, 0.31687), Visible = function() return traitInfo() ~= nil end, ZIndex = 10, create("UIAspectRatioConstraint")({}), create("UIGradient")({ Name = "RarityGradient", Color = selectedTraitGradient, Rotation = 30 }) }),
					create("TextLabel")({
						Name = "Price", BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0.108, 0.782623), Size = UDim2.fromScale(0.75, 0.2),
						Text = function()
							local selection = selectedUnit()
							local info = selection and UnitCatalog.GetInfo(selection.Name)
							local stats = info and info.Stats and info.Stats[0]
							return if stats then `₩{stats.Cost or 0}` else ""
						end,
						TextColor3 = Color3.fromRGB(255, 170, 40), TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10,
						create("UIStroke")({ Thickness = 2 }),
					}),
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
					Active = function() return isVisible() and canRollTrait() end,
					Interactable = function() return isVisible() and canRollTrait() end,
					AutoButtonColor = false,
					Image = "rbxassetid://139274506988816",
					Position = UDim2.fromScale(0.440864, 0.923101), Size = UDim2.fromScale(0.39314, 0.120926),
					Activated = rollSelected, useButtonEffect(0.94, 1.05),
					create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.083, 0.142), Size = UDim2.fromScale(0.403, 0.65), Text = function() return if isRolling() then "..." else "Roll" end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, create("UIStroke")({}) }),
					create("TextLabel")({ Name = "Cost", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.65, 0.2), Size = UDim2.fromScale(0.164, 0.5), Text = tostring(TraitData.RollCost), TextColor3 = function() return if hasTraitCurrency() then Color3.new(1, 1, 1) else Color3.fromRGB(255, 72, 72) end, TextScaled = true, create("UIStroke")({}) }),
					create("ImageLabel")({ Name = "Gems", BackgroundTransparency = 1, Image = CurrencyData.ByName.Gems.CurrencyImage, Position = UDim2.fromScale(0.784, 0.084), Size = UDim2.fromScale(0.198, 0.781), ScaleType = Enum.ScaleType.Fit }),
					create("UIGradient")({
						Color = function()
							return if canRollTrait() then ACTION_AVAILABLE_GRADIENT else ACTION_UNAVAILABLE_GRADIENT
						end,
					}),
					create("UIAspectRatioConstraint")({ AspectRatio = 3.91 }),
					create("UIStroke")({
						Color = function()
							return if canRollTrait() then Color3.new(1, 1, 1) else Color3.fromRGB(121, 121, 121)
						end,
					}),
					create("UICorner")({}),
				}),
				create("TextLabel")({
					Name = "RollStatus", BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.14, 0.8), Size = UDim2.fromScale(0.62, 0.06),
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Text = function()
						local info = traitInfo()
						return if statusText() == "READY TO ROLL" and info then string.upper(info.Name) else statusText()
					end, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 10,
					create("UIStroke")({ Thickness = 1.5 }),
				}),
			}),
			create("CanvasGroup")({
				Name = "ScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromScale(0.030932, 0.153165),
				Size = UDim2.fromScale(0.404726, 0.801601),
				ZIndex = 2,
				create("ScrollingFrame")({
					Name = "TraitRates", Active = true, AutomaticCanvasSize = Enum.AutomaticSize.None,
					BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
					CanvasSize = function()
						return UDim2.fromOffset(0, #rows * (rowHeight() + 10) + 6)
					end,
					ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(175, 155, 205),
					ElasticBehavior = Enum.ElasticBehavior.Never,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.fromScale(1, 1), ZIndex = 2,
					action(function(frame: ScrollingFrame)
						local function resize()
							-- Width drives the 3.5:1 card, never canvas height.
							rowHeight(math.max(1, (frame.AbsoluteSize.X - 12) * 0.92 / 3.5))
						end
						local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
						resize()
						cleanup(function() connection:Disconnect() end)
					end),
					create("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
					create("UIPadding")({ PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
					unpack(rows),
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
	ConfirmationService = ServiceRegistry:GetService("ConfirmationService")
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
		UIController:OpenExclusive(VIEW_ID)
	end)
	traitZone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then return end
		UIController:Close(VIEW_ID)
	end)
end

function TraitUI.Destroy()
	rollGeneration += 1
	cancelConfirmation()
	isRolling(false)
	if traitZone then traitZone:Destroy() traitZone = nil end
end

return TraitUI
