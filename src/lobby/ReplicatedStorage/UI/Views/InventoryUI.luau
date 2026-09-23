local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local ItemCard = require(ReplicatedStorage.UI.Components.ItemCard)
local EmoteCard = require(ReplicatedStorage.UI.Components.EmoteCard)
local PlayerCharacter = require(ReplicatedStorage.Shared.Modules.UI.Emote.PlayerCharacter)
local EmoteUI = require(ReplicatedStorage.UI.Views.EmoteUI)

local create = Vide.create
local action = Vide.action
local changed = Vide.changed
local cleanup = Vide.cleanup
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring
local values = Vide.values

local InventoryClient
local UIController

local VIEW_ID = "Inventory"
local CATEGORIES = { "Material", "Skin", "Emote" }
local SORT_CRITERIA = { "Rarity", "ABC", "Quantity" }
local selectedCategory = source("Material")
local currentSort = source("Rarity")
local searchQuery = source("")
local selectedItemName = source(nil :: string?)
local emoteActionPending = source(false)
-- The category rail is intentionally chunkier than the original export.  The
-- old 5.7 ratio forced the buttons into thin strips on wider screens.
local CATEGORY_BUTTON_ASPECT_RATIO = 2.55

local isLast = false

local function normalizeSearch(text: string): string
	return string.lower(text):gsub("^%s+", ""):gsub("%s+$", "")
end

local function categoryStacks(): { [string]: number }
	if selectedCategory() == "Skin" then return InventoryClient.Skins() end
	if selectedCategory() == "Emote" then return InventoryClient.Emotes() end
	return InventoryClient.Items()
end

local function getInfo(itemName: string, category: string?)
	local targetCategory = category or selectedCategory()
	if targetCategory == "Emote" then
		local emote = EmoteData.ByName[itemName]
		return if emote then {
			Name = emote.Name,
			DisplayName = emote.DisplayName,
			Rarity = "Rare",
			ItemImage = "",
			Description = "Equip this emote to one of your four emote-wheel slots.",
			AnimationId = emote.AnimationId,
			IntroAnimationId = emote.IntroAnimationId,
			Looped = emote.Looped,
			PlaybackSpeed = emote.PlaybackSpeed,
		} else nil
	end
	return ItemData.ByName[itemName]
		or {
			Name = itemName,
			Rarity = if (category or selectedCategory()) == "Skin" then "Secret" else "Common",
			ItemImage = "",
		}
end

local function matchesSearch(itemName: string): boolean
	local query = normalizeSearch(searchQuery())
	if query == "" then
		return true
	end
	local info = getInfo(itemName)
	return string.find(string.lower(`{itemName} {info.Rarity}`), query, 1, true) ~= nil
end

local function matchingItemCount(): number
	local count = 0
	for itemName, amount in categoryStacks() do
		if typeof(amount) == "number" and amount > 0 and matchesSearch(itemName) then
			count += 1
		end
	end
	return count
end

local function comesBefore(aName: string, aCount: number, bName: string, bCount: number): boolean
	local criterion = currentSort()
	if criterion == "Quantity" and aCount ~= bCount then
		return aCount > bCount
	elseif criterion == "Rarity" then
		local aOrder = RarityRegistry.GetOrder(getInfo(aName).Rarity)
		local bOrder = RarityRegistry.GetOrder(getInfo(bName).Rarity)
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
	end
	return string.lower(aName) < string.lower(bName)
end

local function selectFirstAvailable()
	local bestName: string? = nil
	local bestCount = 0
	for itemName, count in categoryStacks() do
		if typeof(count) == "number" and count > 0 and matchesSearch(itemName) then
			if not bestName or comesBefore(itemName, count, bestName, bestCount) then
				bestName, bestCount = itemName, count
			end
		end
	end
	selectedItemName(bestName)
end

local function setCategory(category: string)
	if table.find(CATEGORIES, category) then
		selectedCategory(category)
		selectFirstAvailable()
	end
end

local function cycleSort()
	local currentIndex = table.find(SORT_CRITERIA, currentSort()) or 1
	currentSort(SORT_CRITERIA[currentIndex % #SORT_CRITERIA + 1])
	selectFirstAvailable()
end

local function categoryButton(category: string, layout: number, isVisible: () -> boolean)
	local isSelected = function()
		return selectedCategory() == category
	end
	return create("ImageButton")({
		Name = category,
		Active = true,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://131630835944461",
		LayoutOrder = layout,
		Size = spring(function()
			if not isVisible() then
				return UDim2.fromScale(0.72, 0.14)
			end
			return if isSelected() then UDim2.fromScale(0.94, 0.14) else UDim2.fromScale(0.903, 0.14)
		end, 0.42 + layout * 0.08, 0.78),
		Selectable = true,
		Activated = function()
			setCategory(category)
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
			create("UIStroke")({ Name = "UIStroke" }),
		}),
		create("UIGradient")({
			Name = "StateGradient",
			Color = function()
				local color = if isSelected() then Color3.fromRGB(255, 85, 28) else Color3.fromRGB(97, 97, 97)
				return ColorSequence.new(color)
			end,
		}),
		create("UICorner")({ Name = "UICorner", CornerRadius = UDim.new(0, 6) }),
		create("UIAspectRatioConstraint")({
			AspectRatio = CATEGORY_BUTTON_ASPECT_RATIO,
			DominantAxis = Enum.DominantAxis.Width,
		}),
		create("UIStroke")({
			Name = "StateStroke",
			Color = function()
				return if isSelected() then Color3.fromRGB(255, 158, 88) else Color3.fromRGB(109, 109, 109)
			end,
			Thickness = function()
				return if isSelected() then 2 else 1
			end,
		}),
	})
end

local function textButton(name: string, image: string, label: any, active: boolean, activated: (() -> ())?)
	local strokeColors = {
		SellButton = Color3.fromRGB(255, 2, 2),
		LockButton = Color3.fromRGB(142, 134, 255),
		SortButton = Color3.fromRGB(93, 78, 255),
	}
	return create("ImageButton")({
		Name = name,
		Active = active,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = image,
		Size = UDim2.fromScale(0.251482, 0.782844),
		Activated = activated,
		useButtonEffect(),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.16, 0.238),
			Size = UDim2.fromScale(0.8, 0.488),
			Text = label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),
		create("UICorner")({}),
		create("UIStroke")({ Color = strokeColors[name] or Color3.new(1, 1, 1) }),
	})
end

local InventoryUI = {}

function InventoryUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local searchTextBox: TextBox? = nil
	local selectedInfo = derive(function()
		local name = selectedItemName()
		return if name then getInfo(name) else nil
	end)
	local selectedCount = derive(function()
		local name = selectedItemName()
		return if name then categoryStacks()[name] or 0 else 0
	end)
	local selectedEmoteSlot = derive(function()
		local name = selectedItemName()
		return if selectedCategory() == "Emote" and name then InventoryClient.FindEquippedEmoteSlot(name) else nil
	end)
	local detailCamera = create("Camera")({
		FieldOfView = 38,
		CFrame = CFrame.lookAt(Vector3.new(0, 0.25, -6.4), Vector3.new(0, -0.45, 0)),
	})
	local visibleEntries = derive(function()
		local entries = {}
		if not isVisible() then
			return entries
		end

		local category = selectedCategory()
		for itemName, count in categoryStacks() do
			if typeof(count) == "number" and count > 0 and matchesSearch(itemName) then
				table.insert(entries, { Name = itemName, Count = count, Category = category })
			end
		end

		table.sort(entries, function(a, b)
			return comesBefore(a.Name, a.Count, b.Name, b.Count)
		end)

		return entries
	end)

	effect(function()
		if isVisible() then
			InventoryClient.RefreshInventory()
				:andThen(function()
					return InventoryClient.RefreshEmoteLoadout()
				end)
				:andThen(function()
					local name = selectedItemName()
					if not name or (categoryStacks()[name] or 0) <= 0 then
						selectFirstAvailable()
					end
				end)
				:catch(function(err)
					warn(`[InventoryUI] Failed to load items: {err}`)
				end)
		end
	end)

	effect(function()
		-- Keep the details pane synchronized with category, search and live inventory changes.
		local stacks = categoryStacks()
		local name = selectedItemName()
		local _sort = currentSort()
		local _query = searchQuery()
		if not name or (stacks[name] or 0) <= 0 or not matchesSearch(name) then
			selectFirstAvailable()
		end
	end)

	local openSFX = useAudio({
		Id = UISFX.InventoryOpen.Id,
		Volume = UISFX.InventoryOpen.Volume,
	})
	local closeSFX = useAudio({
		Id = UISFX.Close.Id,
		Volume = UISFX.Close.Volume,
	})

	effect(function()
		if UIController:IsVisible(VIEW_ID)() then
			isLast = true
			openSFX:Play()
		elseif isLast then
			isLast = false
			closeSFX:Play()
		end
	end)

	return create("CanvasGroup")({
		GroupTransparency = menuMotion.Transparency,
		Interactable = isVisible,
		Name = VIEW_ID,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = menuMotion.IsMounted,
		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://107486254365437",
			Position = UDim2.fromScale(0.501648, 0.499042),
			Rotation = menuMotion:WindowRotation(),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.593865)),
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://95305627117639",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.683091, 0.28349),
				ZIndex = 10,
				create("ImageLabel")({
					Name = "Star",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://111343804919469",
					Position = UDim2.fromScale(0.133, 0.478),
					Rotation = menuMotion:IconRotation(),
					Size = menuMotion:IconSize(UDim2.fromScale(0.184974, 0.837933)),
				}),
				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = "rbxassetid://96280313244013",
					ImageTransparency = menuMotion:Fade(),
					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529802, 0.048735)),
					Size = UDim2.fromScale(0.507418, 1.06417),
					create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }),
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
					TextTransparency = menuMotion:Fade(),
				}),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
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
					Position = menuMotion:Spring(UDim2.fromScale(-0.00261403, 0.882837), UDim2.fromScale(-0.00261403, 1.08), "Action"),
					Size = UDim2.fromScale(1, 0.117596),
					ZIndex = 20,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					textButton("SellButton", "rbxassetid://76383008324602", "SELL", false, nil),
					textButton("LockButton", "rbxassetid://70564113534462", "LOCK", false, nil),
					textButton("SortButton", "rbxassetid://128977854458302", function()
						return `SORT : {string.upper(currentSort())}`
					end, true, cycleSort),
				}),
				create("CanvasGroup")({
					Name = "ScrollBackground",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = menuMotion:Spring(UDim2.fromScale(0.261138, 0.0364527), UDim2.fromScale(0.31, 0.0364527), "Content"),
					Size = UDim2.fromScale(0.738862, 0.846385),
					create("ScrollingFrame")({
						Name = "Items",
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(1, 1),
						create("UIGridLayout")({
							CellPadding = UDim2.fromScale(0.012, 0.018),
							CellSize = UDim2.fromScale(0.239841, 0.354932),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						create("UIPadding")({
							PaddingTop = UDim.new(0, 4),
							PaddingBottom = UDim.new(0, 4),
							PaddingLeft = UDim.new(0, 4),
							PaddingRight = UDim.new(0, 4),
						}),
						values(visibleEntries, function(entry, rank)
							if entry.Category == "Emote" then
								return EmoteCard({
									EmoteName = entry.Name,
									LayoutOrder = function() return rank() end,
									IsSelected = function() return selectedItemName() == entry.Name end,
									EquippedSlot = function()
										return InventoryClient.FindEquippedEmoteSlot(entry.Name)
									end,
									Activated = function() selectedItemName(entry.Name) end,
								})
							end
							return ItemCard({
								ItemName = entry.Name,
								Count = entry.Count,
								Category = entry.Category,
								LayoutOrder = function() return rank() end,
								IsSelected = function() return selectedItemName() == entry.Name end,
								Activated = function() selectedItemName(entry.Name) end,
							})
						end),
					}),
					create("TextLabel")({
						Name = "EmptyResult",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.48),
						Size = UDim2.fromScale(0.8, 0.1),
						Text = function()
							if normalizeSearch(searchQuery()) ~= "" then
								return "NO ITEMS FOUND"
							end
							if selectedCategory() == "Skin" then return "NO SKINS OWNED" end
							if selectedCategory() == "Emote" then return "NO EMOTES OWNED" end
							return "NO MATERIALS OWNED"
						end,
						TextColor3 = Color3.fromRGB(218, 218, 226),
						TextScaled = true,
						Visible = function()
							return matchingItemCount() == 0
						end,
						ZIndex = 4,
						create("UIStroke")({ Color = Color3.fromRGB(32, 28, 60), Thickness = 2 }),
					}),
				}),
				create("ImageLabel")({
					Name = "SearchBox",
					BackgroundTransparency = 1,
					Image = "rbxassetid://107178039915972",
					Position = UDim2.fromScale(1.006, -0.09),
					Size = menuMotion:SearchSize(UDim2.fromScale(0.565461, 0.0921883)),
					create("TextBox")({
						Name = "TextBox",
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						PlaceholderText = "ITEM NAME",
						Position = UDim2.fromScale(0.0363427, 0),
						Size = UDim2.fromScale(0.82, 1),
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
						create("UITextSizeConstraint")({ MaxTextSize = 30 }),
					}),
					create("ImageButton")({
						Name = "SearchButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://97005389138079",
						Position = UDim2.fromScale(0.91, 0.5),
						Size = UDim2.fromScale(0.12, 0.8),
						Activated = function()
							if normalizeSearch(searchQuery()) ~= "" then
								searchQuery("")
							elseif searchTextBox then
								searchTextBox:CaptureFocus()
							end
						end,
						useButtonEffect(0.94, 1.06),
						create("UIAspectRatioConstraint")({}),
					}),
				}),
				create("ImageLabel")({
					Name = "Shadow",
					BackgroundTransparency = 1,
					Image = "rbxassetid://78891351891737",
					Position = UDim2.fromScale(0.265911, 0.671846),
					Size = UDim2.fromScale(0.734089, 0.211848),
				}),
				create("CanvasGroup")({
					Name = "CategoryClip",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					AnchorPoint = Vector2.new(0, 0),
					Position = menuMotion:Spring(UDim2.fromScale(0, 0.0172544), UDim2.fromScale(-0.08, 0.0172544), "Content"),
					Size = UDim2.fromScale(0.259, 0.865746),
					ZIndex = 1,
					create("ScrollingFrame")({
						Name = "Category", AnchorPoint = Vector2.new(0, 0),
						Active = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = UDim2.new(),
						Position = UDim2.fromScale(0, 0),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(1, 1),
						create("UIListLayout")({
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, 7),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						create("UIPadding")({
							PaddingTop = UDim.new(0, 4),
							PaddingLeft = UDim.new(0, 3),
							PaddingRight = UDim.new(0, 3),
						}),
						categoryButton("Material", 1, isVisible),
						categoryButton("Skin", 2, isVisible),
						categoryButton("Emote", 3, isVisible),
					}),
				}),
			}),
			create("ImageLabel")({
				Name = "Avatar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://121523581447419",
				Position = menuMotion:Spring(UDim2.fromScale(0.786234, 0.417049), UDim2.fromScale(0.815, 0.417049), "Detail"),
				Size = menuMotion:Spring(UDim2.fromScale(0.382446, 0.497524), UDim2.fromScale(0.425, 0.497524), "Detail"),
				ZIndex = 10,
				create("UIGradient")({
					Color = function()
						local info = selectedInfo()
						local glow = if info
							then RarityRegistry.Get(info.Rarity).Presentation.Glow
							else Color3.fromRGB(100, 100, 100)
						return ColorSequence.new(Color3.fromRGB(100, 100, 100), glow)
					end,
					Rotation = 90,
				}),
				create("TextLabel")({
					Name = "Name",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.49695, 0.055326),
					Size = UDim2.fromScale(0.83363, 0.0605149),
					Text = function()
						return selectedItemName() or "SELECT AN ITEM"
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					create("UIStroke")({}),
				}),
				create("TextLabel")({
					Name = "Grade",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.49695, 0.107853),
					Size = UDim2.fromScale(0.83363, 0.0479085),
					Text = function()
						local info = selectedInfo()
						if not info then return "" end
						return if selectedCategory() == "Emote" then "EMOTE" else string.upper(info.Rarity)
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					create("UIStroke")({}),
					create("UIGradient")({
						useColorSequenceCycle(function()
							local info = selectedInfo()
							return if info
								then RarityRegistry.Get(info.Rarity).Presentation.Gradient
								else ColorSequence.new(Color3.new(1, 1, 1))
						end, function()
							local info = selectedInfo()
							return if info then RarityRegistry.Get(info.Rarity).Presentation.ShimmerSpeed else 1
						end),
					}),
				}),
				create("ImageLabel")({
					Name = "Item",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = function()
						local info = selectedInfo()
						return if info then info.ItemImage or "" else ""
					end,
					Position = UDim2.fromScale(0.501848, 0.494182),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.558716, 0.578273),
					Visible = function() return selectedCategory() ~= "Emote" end,
					create("UIAspectRatioConstraint")({}),
				}),
				create("ViewportFrame")({
					Name = "EmotePreview",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					CurrentCamera = detailCamera,
					Position = UDim2.fromScale(0.5, 0.52),
					Size = UDim2.fromScale(0.78, 0.75),
					Visible = function() return selectedCategory() == "Emote" and selectedInfo() ~= nil end,
					ZIndex = 4,
					detailCamera,
					PlayerCharacter({
						UseWorldModel = true,
						Origin = CFrame.new(0, -2.2, 1.5),
						IntroAnimationId = function()
							local info = selectedInfo()
							return if selectedCategory() == "Emote" and info then info.IntroAnimationId else nil
						end,
						AnimationId = function()
							local info = selectedInfo()
							return if selectedCategory() == "Emote" and info then info.AnimationId else nil
						end,
						Looped = function()
							local info = selectedInfo()
							return info ~= nil and info.Looped == true
						end,
						PlaybackSpeed = 1,
					}),
				}),
			}),
			create("Frame")({
				Name = "OwnedFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				Position = UDim2.fromScale(0.786718, 0.709934),
				Size = UDim2.fromScale(0.33857, 0.0596065),
				ZIndex = 11,
				create("UICorner")({ CornerRadius = UDim.new(0, 5) }),
				create("UIStroke")({ Color = Color3.fromRGB(48, 48, 48), Thickness = 2 }),
				create("UIPadding")({
					PaddingLeft = UDim.new(0, 9),
					PaddingRight = UDim.new(0, 9),
				}),
				create("TextLabel")({
					Name = "OwnedText",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(0.32, 0.72),
					Text = function() return if selectedCategory() == "Emote" then "Slot" else "Owned" end,
					TextColor3 = Color3.fromRGB(192, 192, 192),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					create("UIStroke")({ Thickness = 2 }),
				}),
				create("TextLabel")({
					Name = "OwnedNumText",
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromScale(0.64, 0.72),
					Text = function()
						if selectedCategory() == "Emote" then
							local slot = selectedEmoteSlot()
							return if slot then `SLOT {slot}` else "NOT EQUIPPED"
						end
						return `{selectedCount()}x`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
					create("UIStroke")({ Thickness = 2 }),
				}),
			}),
			create("Frame")({
				Name = "DescriptionFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(),
				Position = UDim2.fromScale(0.786718, 0.804356),
				Size = UDim2.fromScale(0.33857, 0.09),
				ZIndex = 11,
				create("UICorner")({ CornerRadius = UDim.new(0, 5) }),
				create("UIStroke")({ Color = Color3.fromRGB(48, 48, 48), Thickness = 2 }),
				create("TextLabel")({
					Name = "DescriptionText",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.946, 0.78),
					Text = function()
						local info = selectedInfo()
						return if info then info.Description or "No description available." else "Select an item to view details."
					end,
					TextColor3 = Color3.fromRGB(192, 192, 192),
					TextScaled = true,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					create("UIStroke")({ Thickness = 2 }),
					create("UITextSizeConstraint")({ MaxTextSize = 18, MinTextSize = 10 }),
				}),
			}),
			create("ImageButton")({
				Name = "EquipButton",
				Active = function()
					return selectedCategory() == "Emote" and selectedItemName() ~= nil and not emoteActionPending()
				end,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://83967774994235",
				ImageTransparency = function()
					return if selectedCategory() == "Emote" and selectedItemName() and not emoteActionPending() then 0 else 0.45
				end,
				Position = menuMotion:Spring(UDim2.fromScale(0.787698, 0.920119), UDim2.fromScale(0.787698, 1.05), "Action"),
				Size = UDim2.fromScale(0.337246, 0.0842378),
				ZIndex = 11,
				Activated = function()
					local emoteName = selectedItemName()
					if selectedCategory() ~= "Emote" or not emoteName or emoteActionPending() then return end
					if selectedEmoteSlot() then
						emoteActionPending(true)
						InventoryClient.UnequipEmote(emoteName):andThen(function(result)
							emoteActionPending(false)
							if not result.Success then warn(`[InventoryUI] Could not unequip emote: {result.Message}`) end
						end):catch(function(err)
							emoteActionPending(false)
							warn(`[InventoryUI] Could not unequip emote: {err}`)
						end)
					else
						EmoteUI.OpenEquipMode(emoteName)
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
						if emoteActionPending() then return "WAIT" end
						return if selectedEmoteSlot() then "UNEQUIP" else "EQUIP"
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),
				create("UIGradient")({
					Color = ColorSequence.new(Color3.fromRGB(32, 255, 88), Color3.fromRGB(230, 255, 1)),
					Rotation = 90,
				}),
				create("UICorner")({}),
				create("UIStroke")({ Color = Color3.new(1, 1, 1) }),
			}),
			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Rotation = menuMotion:CloseRotation(),
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Size = UDim2.fromScale(0.0822234, 0.15458),
				Activated = function()
					UIController:Close(VIEW_ID)
				end,
				useButtonEffect(nil, 1.1),
				create("UIAspectRatioConstraint")({}),
			}),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function InventoryUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function InventoryUI.Start() end

return InventoryUI
