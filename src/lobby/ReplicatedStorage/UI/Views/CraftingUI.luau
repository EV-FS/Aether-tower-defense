local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local Net = require(ReplicatedStorage.Shared.Net.client)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local changed = Vide.changed
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local CraftingUI = {}
local InventoryClient
local UIController

local VIEW_ID = "Crafting"
local recipeKeys = {}
for recipeKey in CraftRecipes do
	table.insert(recipeKeys, recipeKey)
end
table.sort(recipeKeys, function(a, b)
	return ItemData.ByName[CraftRecipes[a].ResultName].Index < ItemData.ByName[CraftRecipes[b].ResultName].Index
end)

local selectedRecipe = source(recipeKeys[1])
local craftAmount = source(1)
local searchQuery = source("")
local isCrafting = source(false)
local statusText = source("")

local CARD_CORNER_RADIUS = UDim.new(0.06, 0)
local CARD_INSET = 3

local function itemInfo(itemName: string)
	return ItemData.ByName[itemName]
end

local function itemGradient(itemName: string): ColorSequence
	local info = itemInfo(itemName)
	return RarityGradient.Gradients[if info then info.Rarity else "Common"] or RarityGradient.Gradients.Common
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
	return true
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
		Size = UDim2.fromScale(0.321756, 0.360393),
		Visible = function() return matchesSearch(recipeKey) end,
		Activated = function()
			selectedRecipe(recipeKey)
			craftAmount(1)
			statusText("")
		end,
		useButtonEffect(0.95, 1.025),
		create("UIGradient")({ Color = itemGradient(recipe.ResultName), Rotation = 45 }),
		create("UIAspectRatioConstraint")({}),
		create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
		cardBorder(
			"SelectionBorder",
			Color3.fromRGB(255, 248, 222),
			function() return if selectedRecipe() == recipeKey then 2 else 1 end,
			function() return if selectedRecipe() == recipeKey then 0.05 else 1 end
		),
		itemImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69)),
		itemNameLabel(recipe.ResultName),
	})
end

local function ingredientCard(ingredient: CraftRecipes.Ingredient, layoutOrder: number)
	return create("ImageLabel")({
		Name = ingredient.Name,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.22, 0.941195),
		create("UIGradient")({ Color = itemGradient(ingredient.Name), Rotation = 45 }),
		create("UIAspectRatioConstraint")({}),
		create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
		cardBorder(
			"RequirementBorder",
			function()
				return if ownedAmount(ingredient.Name) >= ingredient.Amount * craftAmount()
					then Color3.fromRGB(104, 255, 126)
					else Color3.fromRGB(255, 73, 73)
			end,
			1.5,
			0
		),
		itemImage(ingredient.Name, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69)),
		create("ImageLabel")({
			Name = "Quantity",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.013, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
			ZIndex = 15,
			create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
			create("TextLabel")({
				Name = "Amount",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.365, 0.4),
				Size = UDim2.fromScale(0.608, 0.889),
				Text = function() return `{ownedAmount(ingredient.Name)}/{ingredient.Amount * craftAmount()}` end,
				TextColor3 = Color3.new(1, 1, 1),
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
	if isCrafting() or not recipeKey then
		return
	end
	if not canCraft(recipeKey, amount) then
		statusText("NOT ENOUGH ITEMS")
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

		local refreshOk = pcall(function()
			return InventoryClient.RefreshInventory():await()
		end)
		isCrafting(false)
		if crafted == amount then
			statusText(`CRAFTED {crafted}x`)
		elseif crafted > 0 then
			statusText(`CRAFTED {crafted}/{amount}`)
		else
			statusText("CRAFT FAILED")
		end
		if not refreshOk then
			warn("[CraftingUI] Failed to refresh inventory after crafting")
		end
	end)
end

local function recipeInformation(recipeKey: string)
	local recipe = CraftRecipes[recipeKey]
	local resultInfo = itemInfo(recipe.ResultName)
	local ingredients = {}
	for index, ingredient in recipe.Ingredients do
		table.insert(ingredients, ingredientCard(ingredient, index))
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
			create("UIGradient")({ Color = itemGradient(recipe.ResultName), Rotation = 45 }),
			create("UIAspectRatioConstraint")({}),
			create("UICorner")({ CornerRadius = CARD_CORNER_RADIUS }),
			itemImage(recipe.ResultName, UDim2.fromScale(0.11, 0.08), UDim2.fromScale(0.784, 0.69)),
			itemNameLabel(recipe.ResultName),
		}),
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.318299, 0.094162),
			Size = UDim2.fromScale(0.643448, 0.283369),
			Text = if resultInfo then resultInfo.Description or "" else "",
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
		create("ScrollingFrame")({
			Name = "Ingredients",
			Active = true,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.fromScale(math.max(1, #recipe.Ingredients * 0.24), 0),
			Position = UDim2.fromScale(0.024, 0.567801),
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Size = UDim2.fromScale(0.949939, 0.222846),
			create("UIPadding")({ PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5) }),
			create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
			unpack(ingredients),
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
			Active = function() return canCraft(recipeKey, craftAmount()) and not isCrafting() end,
			BackgroundTransparency = 1,
			Image = "rbxassetid://83967774994235",
			ImageTransparency = function() return if canCraft(recipeKey, craftAmount()) and not isCrafting() then 0 else 0.45 end,
			Position = UDim2.fromScale(0.728829, 0.898627),
			Size = UDim2.fromScale(0.440385, 0.138199),
			Activated = craftSelected,
			useButtonEffect(0.94, 1.05),
			create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.265238, 0.237766), Size = UDim2.fromScale(0.467855, 0.487941), Text = function() return if isCrafting() then "WAIT" else "CRAFT" end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }),
			create("UIStroke")({ ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.new(1, 1, 1), Thickness = 1.5 }),
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(55, 255, 0), Color3.fromRGB(255, 238, 1)) }),
		}),
	})
end

function CraftingUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local cards = {}
	local informationPanels = {}
	for index, recipeKey in recipeKeys do
		table.insert(cards, recipeCard(recipeKey, index))
		table.insert(informationPanels, recipeInformation(recipeKey))
	end

	return create("Frame")({
		Name = "CraftingContainer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = isVisible,
		create("ImageLabel")({
			Name = "Main",
			BackgroundTransparency = 1,
			Image = "rbxassetid://140081374666771",
			Position = spring(function() return if isVisible() then UDim2.fromScale(0.13799, 0.20195) else UDim2.fromScale(0.13799, 0.24) end, 0.5, 0.82),
			Size = spring(function() return if isVisible() then UDim2.fromScale(0.721698, 0.668872) else UDim2.fromScale(0.68, 0.63) end, 0.5, 0.72),
			create("ImageLabel")({
				Name = "Header", BackgroundTransparency = 1, Image = "rbxassetid://86877608635653",
				Position = spring(function() return if isVisible() then UDim2.fromScale(-0.0573612, -0.111321) else UDim2.fromScale(-0.12, -0.111321) end, 0.55, 0.8),
				Size = UDim2.fromScale(0.692821, 0.28349), ZIndex = 10,
				create("ImageLabel")({ Name = "Icon", BackgroundTransparency = 1, Image = "rbxassetid://137141565690695", Position = UDim2.fromScale(0.023, 0.153), Size = UDim2.fromScale(0.230035, 0.720816), create("UIAspectRatioConstraint")({ AspectRatio = 1.42 }) }),
				create("ImageLabel")({ Name = "Cloud", BackgroundTransparency = 1, Image = "rbxassetid://128371081570035", Position = UDim2.fromScale(0.529887, 0.0551715), Size = UDim2.fromScale(0.537766, 1.06417), create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }) }),
				create("TextLabel")({ Name = "Title", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.265238, 0.435573), Size = UDim2.fromScale(0.354292, 0.290134), Text = "CRAFTING", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
			}),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageButton")({ Name = "CancelButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://92651860309635", Position = UDim2.fromScale(0.980096, 0.0289194), Rotation = spring(function() return if isVisible() then 0 else -1080 end, 0.7, 0.7), Size = UDim2.fromScale(0.102144, 0.15458), Activated = function() UIController:Close(VIEW_ID) end, useButtonEffect(nil, 1.1), create("UIAspectRatioConstraint")({}) }),
			create("ImageLabel")({
				Name = "Searchbox", BackgroundTransparency = 1, Image = "rbxassetid://110042619462357", Position = UDim2.fromScale(0.0311001, 0.157864), Size = UDim2.fromScale(0.345239, 0.0911058),
				create("TextBox")({ Name = "TextBox", BackgroundTransparency = 1, ClearTextOnFocus = false, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), PlaceholderText = "SEARCH...", Position = UDim2.fromScale(0.0270247, 0.0962657), Size = UDim2.fromScale(0.942547, 0.775506), Text = searchQuery, TextColor3 = Color3.fromRGB(125, 125, 125), TextSize = 14, changed("Text", function(value: string) searchQuery(value) end) }),
			}),
			create("ScrollingFrame")({
				Name = "Items", Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, CanvasSize = UDim2.new(), Position = UDim2.fromScale(0.2, 0.604), ScrollBarThickness = 0, Size = UDim2.fromScale(0.352309, 0.690162),
				create("UIPadding")({ PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6) }),
				create("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Wraps = true }),
				unpack(cards),
			}),
			create("ImageLabel")({ Name = "Information", BackgroundTransparency = 1, Image = "rbxassetid://100386829313680", Position = UDim2.fromScale(0.387762, 0.157864), Size = UDim2.fromScale(0.579556, 0.79063), unpack(informationPanels) }),
			create("ImageButton")({ Name = "PlusButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://81723758791115", Position = UDim2.fromScale(0.574838, 0.868508), Size = UDim2.fromScale(0.0582918, 0.118359), ZIndex = 6, Activated = function() craftAmount(math.min(craftAmount() + 1, 99)); statusText("") end, useButtonEffect(0.92, 1.08), create("UIAspectRatioConstraint")({}) }),
			create("ImageButton")({ Name = "MinusButton", AnchorPoint = Vector2.new(0.5, 0.5), AutoButtonColor = false, BackgroundTransparency = 1, Image = "rbxassetid://117612042912132", Position = UDim2.fromScale(0.638593, 0.868508), Size = UDim2.fromScale(0.0582918, 0.118359), ZIndex = 6, Activated = function() craftAmount(math.max(craftAmount() - 1, 1)); statusText("") end, useButtonEffect(0.92, 1.08), create("UIAspectRatioConstraint")({}) }),
			create("TextLabel")({ Name = "Status", BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"), Position = UDim2.fromScale(0.39, 0.944), Size = UDim2.fromScale(0.56, 0.04), Text = statusText, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, create("UIStroke")({ Thickness = 2 }) }),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function CraftingUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
end

return CraftingUI
