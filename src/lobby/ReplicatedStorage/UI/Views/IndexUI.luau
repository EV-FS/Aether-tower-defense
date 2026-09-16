local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local changed = Vide.changed
local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local show = Vide.show
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local VIEW_ID = "Index"
local CATEGORIES = { "Unit", "Item" }
local RARITY_ORDER = { Absolute = 1, Exclusive = 2, Mythic = 3, Legendary = 4, Epic = 5, Rare = 6, Common = 7 }

local UIController
local IndexClient
local selectedCategory = source("Unit")
local searchQuery = source("")

local isLast = false

local IndexUI = {}

local function normalizeSearch(text: string): string
	return string.lower(text):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getRarity(category: string, name: string): string
	if category == "Unit" then
		local info = TowerData.ByName[name]
		return if info then info.Rarity else "Common"
	end
	local info = ItemData.ByName[name]
	return if info then info.Rarity else "Common"
end

local function matchesSearch(category: string, name: string): boolean
	local query = normalizeSearch(searchQuery())
	if query == "" then
		return true
	end
	return string.find(string.lower(`{name} {getRarity(category, name)}`), query, 1, true) ~= nil
end

local function layoutOrder(category: string, name: string): number
	local rarity = getRarity(category, name)
	local rarityRank = RARITY_ORDER[rarity] or 99
	local dataIndex = if category == "Unit" and TowerData.ByName[name] then TowerData.ByName[name].Index else 999
	return rarityRank * 10_000 + dataIndex
end

local function categoryButton(category: string, order: number, isVisible: () -> boolean)
	local isSelected = function()
		return selectedCategory() == category
	end
	return create("ImageButton")({
		Name = category,
		Active = true,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://131630835944461",
		LayoutOrder = order,
		Size = spring(function()
			if not isVisible() then
				return UDim2.fromScale(0.72, 0.11)
			end
			return if isSelected() then UDim2.fromScale(0.9, 0.134) else UDim2.fromScale(0.873612, 0.128)
		end, 0.42 + order * 0.08, 0.78),
		Activated = function()
			selectedCategory(category)
		end,
		useButtonEffect(0.97, 1.02),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.122851, 0.237766),
			Size = UDim2.fromScale(0.733093, 0.487941),
			Text = string.upper(category),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			create("UIStroke")({}),
		}),
		create("UIGradient")({
			Color = function()
				return ColorSequence.new(
					if isSelected() then Color3.fromRGB(36, 16, 255) else Color3.fromRGB(97, 97, 97)
				)
			end,
		}),
		create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		create("UIStroke")({
			Color = function()
				return if isSelected() then Color3.fromRGB(112, 69, 255) else Color3.fromRGB(109, 109, 109)
			end,
			Thickness = function()
				return if isSelected() then 2 else 1
			end,
		}),
	})
end

local function collectionCard(category: string, entryName: string)
	local rarity = getRarity(category, entryName)
	local itemInfo = ItemData.ByName[entryName]
	return create("ImageButton")({
		Name = entryName,
		Active = false,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = layoutOrder(category, entryName),
		Size = UDim2.fromScale(0.161155, 0.292),
		create("UIGradient")({
			Color = RarityGradient.Gradients[rarity] or RarityGradient.Gradients.Common,
			Rotation = 45,
		}),
		if category == "Unit"
			then TowerViewport({
				Name = "ViewportFrame",
				TowerName = entryName,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.11, 0.07),
				Size = UDim2.fromScale(0.784, 0.72),
				FieldOfView = 35,
				FitPadding = 1.05,
				UseViewportModel = true,
				UseCharacterBounds = true,
				AnimationName = "Idle",
				AnimationLooped = true,
				ZIndex = 5,
			})
			else create("ImageLabel")({
				Name = "Item",
				BackgroundTransparency = 1,
				Image = if itemInfo then itemInfo.ItemImage else "",
				Position = UDim2.fromScale(0.11, 0.07),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.784, 0.72),
				ZIndex = 5,
			}),
		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.076095, 0.730419),
			Size = UDim2.fromScale(0.84887, 0.172688),
			Text = entryName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			create("UIStroke")({ Thickness = 2 }),
		}),
	})
end

function IndexUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local resultCount = derive(function()
		local entries = if selectedCategory() == "Unit" then IndexClient.Units() else IndexClient.Items()
		local count = 0
		for name, discovered in entries do
			if discovered == true and matchesSearch(selectedCategory(), name) then
				count += 1
			end
		end
		return count
	end)

	local openSFX = useAudio({
		Id = UISFX.IndexOpen.Id,
		Volume = UISFX.IndexOpen.Volume,
	})
	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})

	effect(function()
		if isVisible() then
			IndexClient.Refresh():catch(function(err)
				warn(`[IndexUI] Failed to refresh collection: {err}`)
			end)
		end
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

	return create("Frame")({
		Name = VIEW_ID,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = isVisible,
		create("ImageLabel")({
			Name = "Main",
			BackgroundTransparency = 1,
			Image = "rbxassetid://114669990960052",
			Position = spring(function()
				return if isVisible() then UDim2.fromScale(0.13799, 0.20195) else UDim2.fromScale(0.13799, 0.24)
			end, 0.5, 0.82),
			Size = spring(function()
				return if isVisible() then UDim2.fromScale(0.721698, 0.593865) else UDim2.fromScale(0.68, 0.56)
			end, 0.5, 0.72),
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://109769135793340",
				Position = spring(function()
					return if isVisible()
						then UDim2.fromScale(-0.0573612, -0.111321)
						else UDim2.fromScale(-0.12, -0.111321)
				end, 0.55, 0.8),
				Size = UDim2.fromScale(0.683091, 0.28349),
				ZIndex = 10,
				create("ImageLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Image = "rbxassetid://78448968235913",
					Position = UDim2.fromScale(0.0271911, 0.0964203),
					Size = UDim2.fromScale(0.230096, 0.734038),
					create("UIAspectRatioConstraint")({ AspectRatio = 1.42 }),
				}),
				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://74102163197737",
					Position = UDim2.fromScale(0.529887, 0.0551715),
					Size = UDim2.fromScale(0.507418, 1.06417),
					create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }),
				}),
				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.354292, 0.290134),
					Text = "INDEX",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
			}),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = UDim2.fromScale(0.980096, 0.0289194),
				Rotation = spring(function()
					return if isVisible() then 0 else -1080
				end, 0.7, 0.7),
				Size = UDim2.fromScale(0.0822234, 0.15458),
				Activated = function()
					UIController:Close(VIEW_ID)
				end,
				useButtonEffect(nil, 1.1),
				create("UIAspectRatioConstraint")({}),
			}),
			create("ImageLabel")({
				Name = "Searchbox",
				BackgroundTransparency = 1,
				Image = "rbxassetid://98711334217794",
				Position = UDim2.fromScale(0.625, 0.073),
				Size = UDim2.fromScale(0.345239, 0.0911058),
				create("TextBox")({
					Name = "TextBox",
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					PlaceholderText = "SEARCH...",
					Position = UDim2.fromScale(0.0270247, 0.0962657),
					Size = UDim2.fromScale(0.942547, 0.775506),
					Text = searchQuery,
					TextColor3 = Color3.fromRGB(125, 125, 125),
					TextSize = 14,
					changed("Text", function(value: string)
						searchQuery(value)
					end),
				}),
			}),
			create("ScrollingFrame")({
				Name = "Category",
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.023325, 0.168533),
				ScrollBarThickness = 0,
				Size = UDim2.fromScale(0.226938, 0.779961),
				create("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				categoryButton(CATEGORIES[1], 1, isVisible),
				categoryButton(CATEGORIES[2], 2, isVisible),
			}),
			create("CanvasGroup")({
				Name = "ItemsClip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.608833, 0.555042),
				Size = UDim2.fromScale(0.717141, 0.765746),
				create("ScrollingFrame")({
					Name = "Items",
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					ScrollBarThickness = 0,
					Size = UDim2.fromScale(1, 1),
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0.005, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						Wraps = true,
					}),
					values(IndexClient.Units, function(discovered, name)
						local shouldMount = derive(function()
							return isVisible()
								and selectedCategory() == "Unit"
								and discovered == true
								and matchesSearch("Unit", name())
						end)
						return show(shouldMount, function()
							return collectionCard("Unit", name())
						end)
					end),
					values(IndexClient.Items, function(discovered, name)
						local shouldMount = derive(function()
							return isVisible()
								and selectedCategory() == "Item"
								and discovered == true
								and matchesSearch("Item", name())
						end)
						return show(shouldMount, function()
							return collectionCard("Item", name())
						end)
					end),
				}),
				create("TextLabel")({
					Name = "EmptyResult",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.48),
					Size = UDim2.fromScale(0.82, 0.1),
					Text = function()
						return if normalizeSearch(searchQuery()) == "" then "NOT DISCOVERED YET" else "NO RESULTS"
					end,
					TextColor3 = Color3.fromRGB(190, 190, 205),
					TextScaled = true,
					Visible = function()
						return resultCount() == 0
					end,
					create("UIStroke")({ Color = Color3.fromRGB(25, 20, 55), Thickness = 2 }),
				}),
			}),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function IndexUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	IndexClient = ServiceRegistry:GetService("IndexClient")
end

function IndexUI.Start() end

return IndexUI
