--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/UI Components
local TowerConsumeBtn = require(script.Components.TowerConsumeBtn)
local TowerResultBtn = require(script.Components.TowerResultBtn)
local TowerIngredient = require(script.Components.TowerIngredient)
local ItemIngredient = require(script.Components.ItemIngredient)

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)
local UIState = require(script.Parent.Parent.Utils.UIState)
local UIController
local NotificationService
local InventoryClient

--/Constants
local CRAFT_TOUCH: BasePart = workspace:WaitForChild("TouchZone"):WaitForChild("CraftTouch")
local RARITY_ORDER: { [string]: number } = {
	Exclusive = 1,
	Absolute = 2,
	Mythic = 3,
	Legendary = 4,
	Epic = 5,
	Rare = 6,
	Uncommon = 7,
	Common = 8,
}

--/UI Variables
local create = Vide.create
local derive = Vide.derive
local indexes = Vide.indexes
local source = Vide.source
local untrack = Vide.untrack

--/React States
local SelectedRecipe = source(nil)
local ConsumedTowers = source({})
local ConsumeTarget = source(nil)
local ClientInventory = source({ Items = {}, Crates = {} })

local function updateInventory()
	Net.DataService.GetDataValue.Invoke("Inventory"):andThen(function(inv)
		ClientInventory(inv or { Items = {}, Crates = {} })
	end):catch(function(err)
		warn(`Failed to update craft inventory: {err}`)
	end)
end

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getConsumedCount(towers, towerName)
	local count = 0
	for _, name in pairs(towers) do
		if name == towerName then
			count += 1
		end
	end
	return count
end

local function getNeededAmount(recipeName, towerName)
	local recipe = CraftRecipes[recipeName]
	if not recipe then
		return 0
	end
	for _, ingredient in recipe.Ingredients do
		if ingredient.Type == "Tower" and ingredient.Name == towerName then
			return ingredient.Amount
		end
	end
	return 0
end

local function toggleConsumeTower(towerName, towerKey)
	local current = table.clone(ConsumedTowers())

	if current[towerKey] then
		current[towerKey] = nil
	else
		local neededAmount = getNeededAmount(SelectedRecipe(), towerName)
		local currentCount = getConsumedCount(current, towerName)

		if currentCount < neededAmount then
			current[towerKey] = towerName
		elseif neededAmount > 0 then
			for k, name in pairs(current) do
				if name == towerName then
					current[k] = nil
					break
				end
			end
			current[towerKey] = towerName
		end
	end

	ConsumedTowers(current)
end

local function RequestCraft(): boolean
	local recipe = SelectedRecipe()
	if not recipe then
		return false
	end

	local consumedMap = {}
	for towerKey, towerName in pairs(ConsumedTowers()) do
		if not consumedMap[towerName] then
			consumedMap[towerName] = {}
		end
		table.insert(consumedMap[towerName], towerKey)
	end

	local success = Net.CraftService.Craft
		.Invoke({
			craftKey = recipe,
			consumedTowers = consumedMap,
		})
		:expect()

	if success then
		ConsumedTowers({})
		updateInventory()
		if NotificationService then
			NotificationService:Popup(`+{recipe}!`)
		end
	end

	return success
end

local function getSortedRecipes(): { any }
	local sortedRecipes = {}
	for _, recipe in pairs(CraftRecipes) do
		table.insert(sortedRecipes, recipe)
	end

	table.sort(sortedRecipes, function(a: any, b: any): boolean
		local dataA = TowerData.ByName[a.ResultName] or ItemData.ByName[a.ResultName]
		local dataB = TowerData.ByName[b.ResultName] or ItemData.ByName[b.ResultName]

		local rarityA = dataA and dataA.Rarity or "Common"
		local rarityB = dataB and dataB.Rarity or "Common"

		local orderA = RARITY_ORDER[rarityA] or 9
		local orderB = RARITY_ORDER[rarityB] or 9

		if orderA ~= orderB then
			return orderA < orderB
		end

		return a.ResultName < b.ResultName
	end)

	return sortedRecipes
end

local function RecipeList()
	return create("Frame")({
		Name = "RecipeList",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.425, 0.45),

		Visible = function()
			return SelectedRecipe() == nil
		end,

		create("Frame")({
			Name = "Bar",
			BackgroundColor3 = Color3.fromRGB(170, 170, 255),
			BackgroundTransparency = 0.95,
			Size = UDim2.fromScale(1, 0.15),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.04, 0.175),
				Size = UDim2.fromScale(0.8, 0.625),
				Text = "Craft",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		create("TextButton")({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.99, 0.025),
			Size = UDim2.fromScale(0.1, 0.1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 73, 76),
			TextScaled = true,
			ZIndex = 2,

			MouseButton1Click = function()
				if UIController then
					UIController:Close("Craft")
				end
			end,
		}),

		create("ScrollingFrame")({
			Name = "ElementList",
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.55),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(0.95, 0.75),

			untrack(function()
				local buttons = {}
				for _, recipe in getSortedRecipes() do
					local newBtn = TowerResultBtn({
						TowerName = recipe.ResultName,
						Size = UDim2.fromScale(0.195, 0.195),

						OnActivated = function()
							ConsumedTowers({})
							SelectedRecipe(recipe.ResultName)
						end,
					})

					table.insert(buttons, newBtn)
				end

				return buttons
			end),

			create("UIListLayout")({
				Name = "UIListLayout",
				FillDirection = Enum.FillDirection.Horizontal,
				ItemLineAlignment = Enum.ItemLineAlignment.End,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
			}),

			create("UIPadding")({
				Name = "UIPadding",
				PaddingTop = UDim.new(0, 5),
			}),
		}),

		create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0.03, 0),
		}),

		create("UIStroke")({
			Color = Color3.fromRGB(65, 65, 65),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.007,
			ZIndex = 2,
		}),
		create("UIStroke")({
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.012,
		}),
	})
end

local function Crafting()
	local towerInfo = derive(function()
		local recipeName = SelectedRecipe()
		return recipeName and (TowerData.ByName[recipeName] or ItemData.ByName[recipeName]) or nil
	end)

	local CurrentIngredients = derive(function()
		local recipeName = SelectedRecipe()
		if not recipeName then
			return {}
		end

		local recipe = CraftRecipes[recipeName]
		if not recipe then
			return {}
		end

		local towers = {}
		for _, ingredient in recipe.Ingredients do
			if ingredient.Type == "Tower" then
				table.insert(towers, ingredient)
			end
		end
		return towers
	end)

	local CurrentItemIngredients = derive(function()
		local recipeName = SelectedRecipe()
		if not recipeName then
			return {}
		end

		local recipe = CraftRecipes[recipeName]
		if not recipe then
			return {}
		end

		local items = {}
		for _, ingredient in recipe.Ingredients do
			if ingredient.Type == "Item" then
				table.insert(items, ingredient)
			end
		end
		return items
	end)

	return create("Frame")({
		Name = "Crafting",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.425, 0.45),

		Visible = function()
			return SelectedRecipe() ~= nil
		end,

		--/Bar
		create("Frame")({
			Name = "Bar",
			BackgroundColor3 = Color3.fromRGB(170, 170, 255),
			BackgroundTransparency = 0.95,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.1),

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 17)),
					ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
				}),
				Rotation = 90,
			}),

			create("TextButton")({
				Name = "Close",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.95, 0.15),
				Size = UDim2.fromScale(0.85, 0.85),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = "X",
				TextColor3 = Color3.fromRGB(255, 73, 76),
				TextScaled = true,

				MouseButton1Click = function()
					SelectedRecipe(nil)
				end,
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.03, 0.175),
				Size = UDim2.fromScale(0.345, 0.625),
				Text = "Craft",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		--/Preview
		create("Frame")({
			Name = "Preview",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.025, 0.135),
			Size = UDim2.fromScale(0.575, 0.65),

			create("TextLabel")({
				Name = "TowerName",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.03, 0.775),
				Size = UDim2.fromScale(0.625, 0.075),
				ZIndex = 2,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return SelectedRecipe() or ""
				end,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),

			create("TextLabel")({
				Name = "Rarity",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.03, 0.85),
				Size = UDim2.fromScale(0.625, 0.055),
				ZIndex = 2,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					local info = towerInfo()
					return info and info.Rarity or ""
				end,
				TextColor3 = function()
					local info = towerInfo()
					return info and RarityColor[info.Rarity] or Color3.new(1, 1, 1)
				end,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),

			create("ImageLabel")({
				Name = "TowerImage",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(0.58, 0.9),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 1,
				Image = function()
					local info = towerInfo()
					return info and (info.TowerImage or info.ItemImage) or ""
				end,
			}),

			create("Frame")({
				Name = "Bar",
				BackgroundColor3 = Color3.fromRGB(170, 170, 255),
				BackgroundTransparency = 0.95,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 0.1),

				create("UIGradient")({
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 17)),
						ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
					}),
					Rotation = 90,
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothamSSm.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.03, 0.175),
					Size = UDim2.fromScale(0.345, 0.625),
					Text = "Preview",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0.02, 0),
			}),

			create("UIStroke")({
				Color = Color3.fromRGB(42, 42, 42),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.01,
				ZIndex = 2,
			}),
		}),

		--/Recipes
		create("Frame")({
			Name = "Recipes",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.625, 0.135),
			Size = UDim2.fromScale(0.35, 0.65),

			create("Frame")({
				Name = "Bar",
				BackgroundColor3 = Color3.fromRGB(170, 170, 255),
				BackgroundTransparency = 0.95,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 0.1),

				create("UIGradient")({
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 17)),
						ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
					}),
					Rotation = 90,
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothamSSm.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.04, 0.175),
					Size = UDim2.fromScale(0.345, 0.625),
					Text = "Recipe",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			create("ScrollingFrame")({
				Name = "Towers",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.04, 0.215),
				Size = UDim2.fromScale(0.96, 0.2),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				CanvasSize = UDim2.fromScale(0, 0),

				indexes(CurrentIngredients, function(ingredientSource)
					local ingredient = ingredientSource()

					local needAmount = function()
						return ingredient.Amount
					end

					local currentAmount = function()
						return getConsumedCount(ConsumedTowers(), ingredient.Name)
					end

					return TowerIngredient({
						TowerImage = TowerData.ByName[ingredient.Name] and TowerData.ByName[ingredient.Name].TowerImage
							or "",
						CurrentAmount = currentAmount,
						NeedAmount = needAmount,
						OnActivated = function()
							ConsumeTarget(ingredient.Name)
						end,
					})
				end),

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				create("UIPadding")({
					PaddingLeft = UDim.new(0.02, 0),
					PaddingRight = UDim.new(0.02, 0),
				}),
			}),

			create("Frame")({
				Name = "RingBar",
				BackgroundColor3 = Color3.fromRGB(103, 103, 103),
				Position = UDim2.fromScale(0.055, 0.475),
				Size = UDim2.fromScale(0.9, 0.0075),
			}),

			create("Frame")({
				Name = "RingBar",
				BackgroundColor3 = Color3.fromRGB(103, 103, 103),
				Position = UDim2.fromScale(0.055, 0.83),
				Size = UDim2.fromScale(0.9, 0.0075),
			}),

			create("TextLabel")({
				Name = "ItemsTitle",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.04, 0.5),
				Size = UDim2.fromScale(0.625, 0.045),
				Text = "Required Items",
				TextColor3 = Color3.new(0, 0.5, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				Name = "ItemsAmount",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.525, 0.5),
				Size = UDim2.fromScale(0.45, 0.045),
				TextColor3 = Color3.new(0, 0.5, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					local satisfiedCount = 0
					local ingredients = CurrentItemIngredients()
					for _, ingredient in ingredients do
						local current = ClientInventory().Items[ingredient.Name] or 0
						if current >= ingredient.Amount then
							satisfiedCount += 1
						end
					end
					return `({satisfiedCount}/{#ingredients})`
				end,
			}),

			create("ScrollingFrame")({
				Name = "Items",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.04, 0.58),
				Size = UDim2.fromScale(0.96, 0.2),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				CanvasSize = UDim2.fromScale(0, 0),

				indexes(CurrentItemIngredients, function(ingredientSource)
					local ingredient = ingredientSource()

					local needAmount = function()
						return ingredient.Amount
					end

					local currentAmount = function()
						return ClientInventory().Items[ingredient.Name] or 0
					end

					return ItemIngredient({
						ItemName = ingredient.Name,
						CurrentAmount = currentAmount,
						NeedAmount = needAmount,
					})
				end),

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				create("UIPadding")({
					PaddingLeft = UDim.new(0.02, 0),
					PaddingRight = UDim.new(0.02, 0),
				}),
			}),

			create("TextLabel")({
				Name = "TowersTitle",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.04, 0.135),
				Size = UDim2.fromScale(0.625, 0.045),
				Text = "Required Towers",
				TextColor3 = Color3.new(0, 1, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				Name = "TowersAmount",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.525, 0.135),
				Size = UDim2.fromScale(0.45, 0.045),
				TextColor3 = Color3.new(0, 1, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					local satisfiedCount = 0
					local ingredients = CurrentIngredients()
					for _, ingredient in ingredients do
						local current = getConsumedCount(ConsumedTowers(), ingredient.Name)
						if current >= ingredient.Amount then
							satisfiedCount += 1
						end
					end
					return `({satisfiedCount}/{#ingredients})`
				end,
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.05, 0.88),
				Size = UDim2.fromScale(0.415, 0.06),
				Text = "Cost:",
				TextColor3 = Color3.fromRGB(255, 170, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			create("TextLabel")({
				Name = "CostValue",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.526472, 0.882634),
				Size = UDim2.fromScale(0.442037, 0.0603121),
				Text = "2,000",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0.02, 0),
			}),

			create("UIStroke")({
				Color = Color3.fromRGB(42, 42, 42),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.01,
				ZIndex = 2,
			}),
		}),

		create("TextButton")({
			Name = "Craft",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(85, 255, 0),
			Position = UDim2.fromScale(0.36, 0.9),
			Size = UDim2.fromScale(0.25, 0.115),

			-- 제작 핸들러 바인딩
			MouseButton1Click = RequestCraft,
			useButtonEffect(),

			create("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.55),
				Text = "Craft",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.49, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 190)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
				}),
				Rotation = 90,
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0.1, 0),
			}),
		}),

		create("TextButton")({
			Name = "Back",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 0, 0),
			Position = UDim2.fromScale(0.64, 0.9),
			Size = UDim2.fromScale(0.25, 0.115),

			MouseButton1Click = function()
				SelectedRecipe(nil)
			end,

			useButtonEffect(),

			create("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.55),
				Text = "Back",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.49, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 190)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
				}),
				Rotation = 90,
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0.1, 0),
			}),
		}),
	})
end

local function ConsumeList()
	local targetTowers = derive(function()
		local target = ConsumeTarget()
		if not target or not InventoryClient then
			return {}
		end

		InventoryClient.TowersChanged()

		local owned = InventoryClient.OwnedTowers and InventoryClient.OwnedTowers[target]
		if not owned then
			return {}
		end

		local arr = {}
		for keyId, data in pairs(owned) do
			table.insert(arr, { Key = keyId, Data = data })
		end
		return arr
	end)

	return create("Frame")({
		Name = "ConsumeList",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.25, 0.25),

		Visible = function()
			return ConsumeTarget() ~= nil
		end,

		create("UIShadow")({
			BlurRadius = UDim.new(0.1, 0),
			Color = Color3.fromRGB(60, 55, 100),
			Transparency = 0.25,
		}),

		create("UICorner")({
			CornerRadius = UDim.new(0.03, 0),
		}),

		create("UIStroke")({
			Color = Color3.fromRGB(65, 65, 65),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.012,
			ZIndex = 2,
		}),

		--/Bar
		create("Frame")({
			Name = "Bar",
			BackgroundColor3 = Color3.fromRGB(170, 170, 255),
			BackgroundTransparency = 0.95,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.16),

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 17)),
					ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
				}),
				Rotation = 90,
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.03, 0.175),
				Size = UDim2.fromScale(0.345, 0.625),
				Text = "Select Tower",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		create("ScrollingFrame")({
			Name = "ElementList",
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.5, 0.6),
			ScrollBarThickness = 6,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(0.95, 0.75),

			indexes(targetTowers, function(towerSource)
				local tower = towerSource()
				local towerName = ConsumeTarget()
				if not towerName then
					return nil
				end

				return TowerConsumeBtn({
					TowerName = towerName,
					TowerLevel = tower.Data.Lv or 0,
					IsSelected = function()
						return ConsumedTowers()[tower.Key] ~= nil
					end,
					OnActivated = function()
						toggleConsumeTower(towerName, tower.Key)
					end,
				})
			end),

			create("UIListLayout")({
				Name = "UIListLayout",
				FillDirection = Enum.FillDirection.Horizontal,
				ItemLineAlignment = Enum.ItemLineAlignment.End,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
			}),

			create("UIPadding")({
				Name = "UIPadding",
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5),
			}),
		}),

		create("TextButton")({
			Name = "Close",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.925, 0.025),
			Size = UDim2.fromScale(0.12, 0.12),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 73, 76),
			TextScaled = true,

			MouseButton1Click = function()
				ConsumeTarget(nil)
			end,
		}),
	})
end

-------------------------------------------------
--// CraftUI
-------------------------------------------------
local CraftUI = {}

function CraftUI.RenderUI(): GuiObject
	local craftFrame = create("Frame")({
		Name = "CraftFrame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = false, -- Managed by UIController

		RecipeList(),
		Crafting(),
		ConsumeList(),

		create("UIAspectRatioConstraint")({
			AspectRatio = 1.779,
		}),
	})

	if UIController then
		UIController:RegisterFrame("Craft", craftFrame)
	end

	return craftFrame
end

function CraftUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = require(script.Parent.Parent.Controllers.UIController)
	NotificationService = ServiceRegistry:GetService("NotificationService")
	task.spawn(updateInventory)
end

function CraftUI.Start(): ()
	local function handleTouch(_: Player, targetState: boolean): ()
		local isCurrentlyOpen = UIController:IsOpen("Craft")
		if isCurrentlyOpen == targetState then
			return
		end

		if targetState then
			updateInventory()
			UIController:Open("Craft")
		else
			UIController:Close("Craft")
		end
	end

	local zone = TouchZone.new(CRAFT_TOUCH)
	zone:Start()

	zone.Touched:Connect(function(plr: Player)
		if Players.LocalPlayer == plr then
			handleTouch(plr, true)
		end
	end)
	zone.TouchEnded:Connect(function(plr: Player)
		if Players.LocalPlayer == plr then
			handleTouch(plr, false)
		end
	end)

	Vide.root(function()
		Vide.effect(function()
			local current = UIState.CurrentFrame()
			if current == "Craft" then
				updateInventory()
			end
		end)
	end)
end

return CraftUI
