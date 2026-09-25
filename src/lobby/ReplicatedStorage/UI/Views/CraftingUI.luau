local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local Net = require(ReplicatedStorage.Shared.Net.client)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)
local CutscenePlayer = require(ReplicatedStorage.Shared.Modules.Cutscene.CutscenePlayer)

local changed = Vide.changed
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local CraftingUI = {}
local InventoryClient
local DataClient
local UIController

local VIEW_ID = "Crafting"
local CUTSCENE_VIEW_ID = "DragonSlayerCutscene"
local recipeKeys = {}
for recipeKey, recipe in CraftRecipes do
	local isValid = if recipe.ResultType == "Tower"
		then TowerData.ByName[recipe.ResultName] ~= nil
		else ItemData.ByName[recipe.ResultName] ~= nil
	for _, ingredient in recipe.Ingredients do
		isValid = isValid and ItemData.ByName[ingredient.Name] ~= nil
	end
	if isValid then
		table.insert(recipeKeys, recipeKey)
	else
		warn(`[CraftingUI] Hiding invalid recipe "{recipeKey}" because its item data is incomplete`)
	end
end
table.sort(recipeKeys, function(a, b)
	local leftRecipe = CraftRecipes[a]
	local rightRecipe = CraftRecipes[b]
	local left = if leftRecipe.ResultType == "Tower" then TowerData.ByName[leftRecipe.ResultName] else ItemData.ByName[leftRecipe.ResultName]
	local right = if rightRecipe.ResultType == "Tower" then TowerData.ByName[rightRecipe.ResultName] else ItemData.ByName[rightRecipe.ResultName]
	if left.Index == right.Index then
		return a < b
	end
	return left.Index < right.Index
end)

local selectedRecipe = source(if CraftRecipes["Dragon Slayer"] and table.find(recipeKeys, "Dragon Slayer") then "Dragon Slayer" else recipeKeys[1])
local craftAmount = source(1)
local searchQuery = source("")
local isCrafting = source(false)
local isCutscenePlaying = source(false)
local statusText = source("")

local CARD_CORNER_RADIUS = UDim.new(0.06, 0)
local CARD_INSET = 3
local RECIPE_COLUMNS = 3
local RECIPE_GRID_PADDING = 6
local RECIPE_GRID_GAP = 7
local ACTION_AVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
})
local ACTION_UNAVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 76, 76)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 18, 18)),
})

local function itemInfo(itemName: string)
	return ItemData.ByName[itemName]
end

local function itemGradient(itemName: string): ColorSequence
	local info = itemInfo(itemName)
	return RarityData.Get(if info then info.Rarity else "Common").Presentation.Gradient
end

local function resultGradient(recipe: CraftRecipes.Recipe): ColorSequence
	local info = if recipe.ResultType == "Tower" then TowerData.ByName[recipe.ResultName] else itemInfo(recipe.ResultName)
	return RarityData.Get(if info then info.Rarity else "Common").Presentation.Gradient
end

local function ownedCurrency(currency: string): number
	if not DataClient then return 0 end
	if currency == "Coins" then return DataClient.Coins() end
	if currency == "Gems" then return DataClient.Gems() end
	return 0
end

local function formatAmount(amount: number): string
	return if DataClient then DataClient.FormatNumber(amount) else tostring(amount)
end

local function ownedAmount(itemName: string): number
	return InventoryClient.Items()[itemName] or 0
end

local function matchesSearch(recipeKey: string): boolean
	local query = string.lower(searchQuery()):gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then
		return true
	end
	local recipe = CraftRecipes[recipeKey]
	return string.find(string.lower(`{recipeKey} {recipe.ResultName}`), query, 1, true) ~= nil
end

local function canCraft(recipeKey: string, amount: number): boolean
	local recipe = CraftRecipes[recipeKey]
	if not recipe then
		return false
	end
	for _, ingredient in recipe.Ingredients do
		if ownedAmount(ingredient.Name) < ingredient.Amount * amount then
			return false
		end
	end
	for currency, cost in recipe.Currencies or {} do
		if ownedCurrency(currency) < cost * amount then
			return false
		end
	end
	return true
end

local function towerImage(towerName: string, position: UDim2, size: UDim2, active: () -> boolean)
	local profile = UnitViewportProfiles.GetCard(towerName)
	return TowerViewport({
		Name = "TowerImage",
		TowerName = towerName,
		Position = position,
		Size = size,
		Active = active,
		UseViewportModel = true,
		UseCharacterBounds = profile.BoundsMode == "Character",
		UsePortraitBounds = profile.BoundsMode == "Portrait",
		CenterOnRoot = not profile.CenterOnBounds,
		RenderEffects = false,
		FitPadding = profile.FitPadding,
		FocusYOffset = profile.FocusYOffset,
		FieldOfView = 35,
		ModelRotation = 15,
		AnimationName = "Idle",
		AnimationLevel = 0,
		AnimationLooped = true,
		ZIndex = 5,
	})
end

local function itemImage(itemName: string, position: UDim2, size: UDim2)
	local info = itemInfo(itemName)
	return create("ImageLabel")({
		Name = "ItemImage",
		BackgroundTransparency = 1,
		Image = if info then info.ItemImage else "",
		Position = position,
		ScaleType = Enum.ScaleType.Fit,
		Size = size,
		ZIndex = 5,
	})
end

local function itemNameLabel(itemName: string)
	return create("TextLabel")({
		Name = "ItemName",
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
		Position = UDim2.fromScale(0.076095, 0.730419),
		Size = UDim2.fromScale(0.84887, 0.172688),
		Text = itemName,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		create("UIStroke")({ Thickness = 2 }),
	})
end

local function cardBorder(name: string, color: Color3 | (() -> Color3), thickness: number | (() -> number), transparency: number | (() -> number))
	return create("Frame")({
		Name = name,
		Active = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(CARD_INSET, CARD_INSET),
		Size = UDim2.new(1, -CARD_INSET * 2, 1, -CARD_INSET * 2),
		-- Keep the border above the card art, but below quantity/name overlays.
		ZIndex = 8,
		create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = color,
			Thickness = thickness,
			Transparency = transparency,
		}),
	})
end

local function recipeCard(recipeKey: string, layoutOrder: number)
	local recipe = CraftRecipes[recipeKey]
	return create("ImageButton")({
		Name = recipeKey,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = layoutOrder,
		Visible = function() return matchesSearch(recipeKey) end,
		Activated = function()
			selectedRecipe(recipeKey)
			craftAmount(1)
			statusText("")
		end,
		useButtonEffect(0.95, 1.025),
		create("UIGradient")({ Color = resultGradient(recipe), Rotation = 45 }),
		create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
		cardBorder(
			"SelectionBorder",
			Color3.fromRGB(255, 248, 222),
			function() return if selectedRecipe() == recipeKey then 2 else 1 end,
			function() return if selectedRecipe() == recipeKey then 0.05 else 1 end
		),
		if recipe.ResultType == "Tower"
			then towerImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69), function()
				return matchesSearch(recipeKey)
			end)
			else itemImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69)),
		itemNameLabel(recipe.ResultName),
	})
end

local function ingredientCard(ingredient: CraftRecipes.Ingredient, layoutOrder: number, cardSize: () -> number, isCurrency: boolean?)
	local function owned()
		return if isCurrency then ownedCurrency(ingredient.Name) else ownedAmount(ingredient.Name)
	end
	local image = if ingredient.Name == "Coins" then "rbxassetid://117112996963807"
		elseif ingredient.Name == "Gems" then "rbxassetid://104268323693949"
		else itemInfo(ingredient.Name).ItemImage
	local gradient = if ingredient.Name == "Coins" then RarityData.Get("Legendary").Presentation.Gradient
		elseif ingredient.Name == "Gems" then RarityData.Get("Rare").Presentation.Gradient
		else itemGradient(ingredient.Name)
	return create("ImageLabel")({
		Name = ingredient.Name,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = layoutOrder,
		-- Pixel width derived from the viewport height avoids a circular dependency
		-- between X-scaled children and AutomaticCanvasSize.X.
		Size = function() return UDim2.fromOffset(cardSize(), cardSize()) end,
		create("UIGradient")({ Color = gradient, Rotation = 45 }),
		create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
		cardBorder(
			"RequirementBorder",
			function()
				return if owned() >= ingredient.Amount * craftAmount()
					then Color3.fromRGB(104, 255, 126)
					else Color3.fromRGB(255, 73, 73)
			end,
			1.5,
			0
		),
		create("ImageLabel")({
			Name = "IngredientImage",
			BackgroundTransparency = 1,
			Image = image,
			Position = UDim2.fromScale(0.11, 0.08),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.784, 0.69),
			ZIndex = 5,
		}),
		create("ImageLabel")({
			Name = "Quantity",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.013, -0.05),
			Size = UDim2.fromScale(0.94, 0.238322),
			ZIndex = 15,
			create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
			create("TextLabel")({
				Name = "Amount",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.88, 0.889),
				Text = function() return `{formatAmount(owned())}/{formatAmount(ingredient.Amount * craftAmount())}` end,
				TextColor3 = function()
					return if owned() >= ingredient.Amount * craftAmount()
						then Color3.new(1, 1, 1)
						else Color3.fromRGB(255, 105, 105)
				end,
				TextScaled = true,
				ZIndex = 16,
				create("UIStroke")({ Thickness = 2 }),
			}),
		}),
		itemNameLabel(ingredient.Name),
	})
end

local function craftSelected()
	local recipeKey = selectedRecipe()
	local amount = craftAmount()
	if isCrafting() or isCutscenePlaying() or not recipeKey then
		return
	end
	if not canCraft(recipeKey, amount) then
		statusText("NOT ENOUGH RESOURCES")
		NotificationFeed.Pull("Not enough materials or currency to craft.", "Error")
		return
	end

	isCrafting(true)
	statusText("CRAFTING...")
	task.spawn(function()
		local crafted = 0
		for _ = 1, amount do
			local callOk, promiseOk, result = pcall(function()
				return Net.CraftService.Craft.Invoke({ craftKey = recipeKey, consumedTowers = {} }):await()
			end)
			if not callOk or not promiseOk or result ~= true then
				break
			end
			crafted += 1
		end

		local playDragonCutscene = crafted > 0 and recipeKey == "Dragon Slayer"
		local cutsceneViewOpen = false
		if not playDragonCutscene then isCrafting(false) end
		if crafted == amount then
			statusText(`CRAFTED {crafted}x`)
		elseif crafted > 0 then
			statusText(`CRAFTED {crafted}/{amount}`)
		else
			statusText("CRAFT FAILED")
			NotificationFeed.Pull("Crafting failed. Please try again.", "Error")
		end
		local function refreshInventory()
			local refreshOk = pcall(function()
				return InventoryClient.RefreshInventory():await()
			end)
			if not refreshOk then
				warn("[CraftingUI] Failed to refresh inventory after crafting")
			end
			if crafted > 0 and CraftRecipes[recipeKey].ResultType == "Tower" then
				local towersOk = pcall(function()
					return InventoryClient.RefreshTowers():await()
				end)
				if not towersOk then
					warn("[CraftingUI] Failed to refresh crafted units")
				end
			end
		end
		if playDragonCutscene then
			task.spawn(refreshInventory)
			local function restoreCutsceneUI()
				if cutsceneViewOpen then
					UIController:Close(CUTSCENE_VIEW_ID)
					cutsceneViewOpen = false
				end
				isCrafting(false)
				isCutscenePlaying(false)
			end
			local didPlay = CutscenePlayer.Play("DragonSlayer", {
				OnCovered = function()
					-- Keep the crafting page in the opening shot until it is fully black.
					isCutscenePlaying(true)
					cutsceneViewOpen = UIController:OpenExclusive(CUTSCENE_VIEW_ID)
					if not cutsceneViewOpen then UIController:Close(VIEW_ID) end
					isCrafting(false)
				end,
				OnReturning = restoreCutsceneUI,
			})
			restoreCutsceneUI()
			if not didPlay then
				NotificationFeed.Pull("Dragon Slayer cutscene could not be played. Check Output for the cause.", "Error")
			end
		else
			refreshInventory()
		end
		if crafted > 0 and CraftRecipes[recipeKey].ResultType == "Tower" then
			NotificationFeed.Pull(`Crafted {crafted}x {CraftRecipes[recipeKey].ResultName}!`)
		end
	end)
end

local function recipeInformation(recipeKey: string)
	local recipe = CraftRecipes[recipeKey]
	local resultInfo = itemInfo(recipe.ResultName)
	local cardSize = source(80)
	local ingredients = {}
	for index, ingredient in recipe.Ingredients do
		table.insert(ingredients, ingredientCard(ingredient, index, cardSize))
	end
	for _, currency in { "Coins", "Gems" } do
		local cost = if recipe.Currencies then recipe.Currencies[currency] else nil
		if cost then
			table.insert(ingredients, ingredientCard({ Name = currency, Amount = cost }, #ingredients + 1, cardSize, true))
		end
	end

	return create("Frame")({
		Name = `{recipeKey}Information`,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = function() return selectedRecipe() == recipeKey end,
		create("ImageLabel")({
			Name = "Result",
			BackgroundTransparency = 1,
			Image = "rbxassetid://87496848270095",
			Position = UDim2.fromScale(0.0214648, 0.0591611),
			Size = UDim2.fromScale(0.321756, 0.360393),
			create("UIGradient")({ Color = resultGradient(recipe), Rotation = 45 }),
			create("UIAspectRatioConstraint")({}),
			create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
			if recipe.ResultType == "Tower"
				then towerImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69), function()
					return selectedRecipe() == recipeKey
				end)
				else itemImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69)),
			itemNameLabel(recipe.ResultName),
		}),
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.318299, 0.094162),
			Size = UDim2.fromScale(0.643448, 0.283369),
			Text = if resultInfo then resultInfo.Description or "" else "Craft this exclusive unit with dragon relics, shards, Coins, and Gems.",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		create("ImageLabel")({
			Name = "IngredientsHeader",
			BackgroundTransparency = 1,
			Image = "rbxassetid://131328421366367",
			Position = UDim2.fromScale(0.0274305, 0.473116),
			Size = UDim2.fromScale(0.937, 0.079),
			create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.0431852, 0.193485), Size = UDim2.fromScale(0.570817, 0.564427), Text = "INGREDIENTS", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }),
		}),
		create("CanvasGroup")({
			Name = "IngredientsClip",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.024, 0.567801),
			Size = UDim2.fromScale(0.949939, 0.222846),
			changed("AbsoluteSize", function(size: Vector2)
				if size.Y > 0 then
					cardSize(math.max(24, math.floor(size.Y) - 10))
				end
			end),
			create("ScrollingFrame")({
				Name = "Ingredients",
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0, 0),
				ScrollBarImageColor3 = Color3.fromRGB(190, 171, 255),
				ScrollBarThickness = if #ingredients > 4 then 4 else 0,
				ScrollingEnabled = true,
				ScrollingDirection = Enum.ScrollingDirection.X,
				Size = UDim2.fromScale(1, 1),
				create("UIPadding")({ PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5) }),
				create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
				unpack(ingredients),
			}),
		}),
		create("ImageLabel")({
			Name = "Amount",
			BackgroundTransparency = 1,
			Image = "rbxassetid://137163439630654",
			Position = UDim2.fromScale(0.0310159, 0.829528),
			Size = UDim2.fromScale(0.229708, 0.142301),
			ZIndex = 6,
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.205253, 0.216213),
				Size = UDim2.fromScale(0.570817, 0.564427),
				Text = function() return tostring(craftAmount()) end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 7,
			}),
		}),
		create("ImageButton")({
			Name = "CraftButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			Active = function() return not isCrafting() end,
			Interactable = function() return not isCrafting() end,
			BackgroundTransparency = 1,
			Image = "rbxassetid://83967774994235",
			Position = UDim2.fromScale(0.728829, 0.898627),
			Size = UDim2.fromScale(0.440385, 0.138199),
			Activated = craftSelected,
			useButtonEffect(0.94, 1.05),
			create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.265238, 0.237766), Size = UDim2.fromScale(0.467855, 0.487941), Text = function() return if isCrafting() then "WAIT" else "CRAFT" end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
			create("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = function()
					return if canCraft(recipeKey, craftAmount()) and not isCrafting()
						then Color3.new(1, 1, 1)
						else Color3.fromRGB(255, 106, 106)
				end,
				Thickness = 1.5,
			}),
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			create("UIGradient")({
				Color = function()
					return if canCraft(recipeKey, craftAmount()) and not isCrafting()
						then ACTION_AVAILABLE_GRADIENT
						else ACTION_UNAVAILABLE_GRADIENT
				end,
			}),
		}),
	})
end

function CraftingUI.RenderUI()
	local controllerVisible = UIController:IsVisible(VIEW_ID)
	local isVisible = function()
		return controllerVisible() and not isCutscenePlaying()
	end
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local recipeCellSize = source(100)
	local cards = {}
	local informationPanels = {}
	for index, recipeKey in recipeKeys do
		table.insert(cards, recipeCard(recipeKey, index))
		table.insert(informationPanels, recipeInformation(recipeKey))
	end

	return create("CanvasGroup")({
		Name = "CraftingContainer", GroupTransparency = menuMotion.Transparency, Interactable = isVisible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = function() return menuMotion.IsMounted() and not isCutscenePlaying() end,
		create("ImageLabel")({
			Name = "Main", Rotation = menuMotion:WindowRotation(), AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140081374666771",
			Position = UDim2.fromScale(0.498839, 0.20195),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.668872)),
			create("ImageLabel")({
				Name = "Header", BackgroundTransparency = 1, Image = "rbxassetid://86877608635653",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.692821, 0.28349), ZIndex = 10,
				create("ImageLabel")({ Name = "Icon", Rotation = menuMotion:IconRotation(), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://137141565690695", Position = UDim2.fromScale(0.1380175, 0.513408), Size = menuMotion:IconSize(UDim2.fromScale(0.230035, 0.720816)), create("UIAspectRatioConstraint")({ AspectRatio = 1.42 }) }),
				create("ImageLabel")({ Name = "Cloud", ImageTransparency = menuMotion:Fade(), BackgroundTransparency = 1, Image = "rbxassetid://128371081570035", Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)), Size = UDim2.fromScale(0.537766, 1.06417), create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }) }),
				create("TextLabel")({ Name = "Title", TextTransparency = menuMotion:Fade(), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.265238, 0.435573), Size = UDim2.fromScale(0.354292, 0.290134), Text = "CRAFTING", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
			}),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageButton")({ Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)), Rotation = menuMotion:CloseRotation(), Size = UDim2.fromScale(0.102144, 0.15458), Activated = function() UIController:Close(VIEW_ID) end, useButtonEffect(nil, 1.1), create("UIAspectRatioConstraint")({}) }),
			create("ImageLabel")({
				Name = "Searchbox", BackgroundTransparency = 1, Image = "rbxassetid://110042619462357", Position = UDim2.fromScale(0.0311001, 0.157864), Size = menuMotion:SearchSize(UDim2.fromScale(0.345239, 0.0911058)),
				create("TextBox")({ Name = "TextBox", BackgroundTransparency = 1, ClearTextOnFocus = false, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), PlaceholderText = "SEARCH...", Position = UDim2.fromScale(0.0270247, 0.0962657), Size = UDim2.fromScale(0.942547, 0.775506), Text = searchQuery, TextColor3 = Color3.fromRGB(125, 125, 125), TextSize = 14, changed("Text", function(value: string) searchQuery(value) end) }),
			}),
			create("CanvasGroup")({
				Name = "ItemsClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.2, 0.604),
				Size = UDim2.fromScale(0.352309, 0.690162),
				ZIndex = 1,
				create("ScrollingFrame")({
					Name = "Items", Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0, 0), BackgroundTransparency = 1, CanvasSize = UDim2.new(), Position = UDim2.fromScale(0, 0), ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, Size = UDim2.fromScale(1, 1),
					changed("AbsoluteSize", function(size: Vector2)
						local availableWidth = size.X - 2 * RECIPE_GRID_PADDING - (RECIPE_COLUMNS - 1) * RECIPE_GRID_GAP
						recipeCellSize(math.max(1, math.floor(availableWidth / RECIPE_COLUMNS)))
					end),
					create("UIPadding")({ PaddingBottom = UDim.new(0, RECIPE_GRID_PADDING), PaddingLeft = UDim.new(0, RECIPE_GRID_PADDING), PaddingRight = UDim.new(0, RECIPE_GRID_PADDING), PaddingTop = UDim.new(0, RECIPE_GRID_PADDING) }),
					create("UIGridLayout")({
						CellPadding = UDim2.fromOffset(RECIPE_GRID_GAP, RECIPE_GRID_GAP),
						CellSize = function() return UDim2.fromOffset(recipeCellSize(), recipeCellSize()) end,
						FillDirection = Enum.FillDirection.Horizontal,
						FillDirectionMaxCells = RECIPE_COLUMNS,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					unpack(cards),
				}),
			}),
			create("ImageLabel")({ Name = "Information", BackgroundTransparency = 1, Image = "rbxassetid://100386829313680", Position = menuMotion:Spring(UDim2.fromScale(0.387762, 0.157864), UDim2.fromScale(0.387762, 0.157864) + UDim2.fromScale(0.028999, 0), "Detail"), Size = UDim2.fromScale(0.579556, 0.79063), unpack(informationPanels) }),
			create("ImageButton")({ Name = "PlusButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://81723758791115", Position = UDim2.fromScale(0.574838, 0.868508), Size = UDim2.fromScale(0.0582918, 0.118359), ZIndex = 6, Activated = function() craftAmount(math.min(craftAmount() + 1, 99)); statusText("") end, useButtonEffect(0.92, 1.08), create("UIAspectRatioConstraint")({}) }),
			create("ImageButton")({ Name = "MinusButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://117612042912132", Position = UDim2.fromScale(0.638593, 0.868508), Size = UDim2.fromScale(0.0582918, 0.118359), ZIndex = 6, Activated = function() craftAmount(math.max(craftAmount() - 1, 1)); statusText("") end, useButtonEffect(0.92, 1.08), create("UIAspectRatioConstraint")({}) }),
			create("TextLabel")({ Name = "Status", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.39, 0.944), Size = UDim2.fromScale(0.56, 0.04), Text = statusText, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, create("UIStroke")({ Thickness = 2 }) }),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function CraftingUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	DataClient = ServiceRegistry:GetService("DataClient")
	UIController = ServiceRegistry:GetService("UIController")
	task.spawn(function()
		CutscenePlayer.Preload("DragonSlayer")
	end)
end

return CraftingUI
