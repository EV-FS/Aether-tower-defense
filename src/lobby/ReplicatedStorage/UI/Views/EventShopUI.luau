local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local EventShopData = require(ReplicatedStorage.Settings.Data.EventShopData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local source = Vide.source

local VIEW_ID = "EventShop"
local BLOSSOM_ICON = "rbxassetid://129066851213188"

local DataClient
local InventoryClient
local UIController
local purchaseBusy = source(nil :: string?)

local EventShopUI = {}

local function formatNumber(value: number): string
	return DataClient.FormatNumber(value)
end

local function ownsProduct(product: EventShopData.Product): boolean
	if not product.Unique then
		return false
	end

	local inventory = if product.RewardCategory == "Skins" then InventoryClient.Skins() else InventoryClient.Items()
	return (inventory[product.RewardName] or 0) > 0
end

local function canPurchase(product: EventShopData.Product): boolean
	return purchaseBusy() == nil and not ownsProduct(product) and DataClient.Blossom() >= product.Price
end

local function purchaseProduct(product: EventShopData.Product)
	if not canPurchase(product) then
		return
	end

	purchaseBusy(product.Id)
	task.spawn(function()
		local ok, result = pcall(function()
			local folder = ReplicatedStorage:WaitForChild("RuntimeRemotes", 5)
			local remote = folder and folder:WaitForChild("EventShopPurchase", 5)
			if not remote or not remote:IsA("RemoteFunction") then
				error("EventShopPurchase remote is unavailable")
			end
			return remote:InvokeServer(product.Id)
		end)

		purchaseBusy(nil)
		if not ok or typeof(result) ~= "table" then
			warn("[EventShopUI] Purchase failed")
			return
		end

		if typeof(result.Balance) == "number" then
			DataClient.Blossom(result.Balance)
		end

		if result.Success then
			InventoryClient.RefreshInventory():catch(function(err)
				warn(`[EventShopUI] Failed to refresh inventory: {err}`)
			end)
		else
			warn(`[EventShopUI] Purchase rejected: {result.Message or "Unknown reason"}`)
		end
	end)
end

local function giftButton()
	return create("ImageButton")({
		Name = "GiftButton",
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://98844680499099",
		Position = UDim2.fromScale(0.881898, 0.842459),
		Size = UDim2.fromScale(0.173667, 0.249376),
		create("UIGradient")({
			Color = ColorSequence.new(Color3.fromRGB(255, 160, 43), Color3.fromRGB(255, 215, 123)),
			Rotation = 90,
		}),
		create("UIAspectRatioConstraint")({}),
		create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://128557996574921",
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.70253, 0.687405),
			ZIndex = 10,
			create("UIAspectRatioConstraint")({ AspectRatio = 0.83 }),
		}),
	})
end

local function purchaseButton(product: EventShopData.Product)
	return create("ImageButton")({
		Name = "PurchaseButton",
		Active = function()
			return canPurchase(product)
		end,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://139274506988816",
		ImageTransparency = function()
			return if canPurchase(product) then 0 else 0.14
		end,
		Position = UDim2.fromScale(0.387631, 0.842459),
		Size = UDim2.fromScale(0.757759, 0.249376),
		Activated = function()
			purchaseProduct(product)
		end,
		useButtonEffect(0.94, 1.05),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.149276, 0.214464),
			Size = UDim2.fromScale(0.68577, 0.527425),
			Text = function()
				if ownsProduct(product) then
					return "OWNED"
				end
				return if purchaseBusy() == product.Id then "WAIT..." else "PURCHASE"
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			create("UIStroke")({}),
		}),
		create("UIGradient")({
			Color = ColorSequence.new(Color3.fromRGB(13, 255, 0), Color3.fromRGB(234, 255, 0)),
		}),
		create("UIStroke")({ Color = Color3.new(1, 1, 1) }),
		create("UICorner")({}),
	})
end

local function blossomPrice(product: EventShopData.Product)
	return create("Frame")({
		Name = "Blossom",
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.2,
		BorderColor3 = Color3.new(),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.103804, 0.491441),
		Size = UDim2.fromScale(0.728345, 0.217537),
		create("ImageLabel")({
			Name = "ImageLabel",
			BackgroundTransparency = 1,
			Image = BLOSSOM_ICON,
			Position = UDim2.fromScale(0.140759, -0.0579331),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.207917, 1.29323),
			create("UIAspectRatioConstraint")({}),
		}),
		create("UIGradient")({
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.502475, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
		create("TextLabel")({
			Name = "TextLabel",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.398844, 0.0459998),
			Size = UDim2.fromScale(0.867052, 0.823529),
			Text = formatNumber(product.Price),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 112, 248)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 181, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(243, 79, 255)),
				}),
				Rotation = 90,
			}),
		}),
	})
end

local function productCard(product: EventShopData.Product)
	local isUnitFrame = product.Id == "KitsuneUnitFrame"
	local isPremiumChest = product.Id == "PremiumEventChest"
	local isMaidSkin = product.Id == "MaidKitsuneSkin"
	local highlightGradient = if isMaidSkin
		then ColorSequence.new(Color3.fromRGB(23, 21, 56), Color3.fromRGB(255, 60, 60))
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 98, 255)),
			ColorSequenceKeypoint.new(0.493197, Color3.fromRGB(250, 183, 250)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(82, 255, 255)),
		})
	local titleGradient = if isMaidSkin
		then ColorSequence.new(Color3.fromRGB(9, 11, 27), Color3.fromRGB(255, 53, 35))
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 112, 248)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 181, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(78, 255, 249)),
		})

	return create("ImageLabel")({
		Name = "Goods",
		BackgroundTransparency = 1,
		Image = "rbxassetid://134289402440935",
		ImageColor3 = function()
			return if canPurchase(product) then Color3.new(1, 1, 1) else Color3.fromRGB(225, 225, 225)
		end,
		LayoutOrder = product.LayoutOrder,
		Size = UDim2.fromScale(0.14292, 1),
		create("UIGradient")({ Color = product.Gradient, Rotation = 90 }),
		create("CanvasGroup")({
			Name = "Content",
			BackgroundTransparency = 1,
			GroupTransparency = function()
				if ownsProduct(product) then
					return 0.24
				end
				return if canPurchase(product) then 0 else 0.12
			end,
			Size = UDim2.fromScale(1, 1),
			create("ImageLabel")({
				Name = "Hightlight",
				BackgroundTransparency = 1,
				Image = "rbxassetid://126785452672730",
				Position = UDim2.fromScale(-1.82007e-07, 0),
				Size = UDim2.fromScale(1, 0.899494),
				ZIndex = -1,
				create("UIGradient")({
					Color = highlightGradient,
					Rotation = if isMaidSkin then 90 else -45,
				}),
				create("UIAspectRatioConstraint")({ AspectRatio = 0.81 }),
			}),
			create("ImageLabel")({
				Name = "Shadow",
				BackgroundTransparency = 1,
				Image = "rbxassetid://79924522079987",
				Position = UDim2.fromScale(0.018, 0.51),
				Size = UDim2.fromScale(0.974006, 0.47562),
				ZIndex = 2,
				create("UIGradient")({
					Color = ColorSequence.new(Color3.fromRGB(255, 255, 98), Color3.fromRGB(255, 111, 173)),
					Rotation = 90,
				}),
				giftButton(),
				purchaseButton(product),
				blossomPrice(product),
			}),
			create("TextLabel")({
				Name = "TextLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = if isPremiumChest then UDim2.fromScale(0.0767877, -0.00206829) else UDim2.fromScale(0.0708237, 0.0241507),
				Size = UDim2.fromScale(0.867052, if isPremiumChest then 0.183889 elseif isMaidSkin then 0.15767 else 0.092123),
				Text = product.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
				create("UIGradient")({ Color = titleGradient }),
			}),
			create("ImageLabel")({
				Name = "item",
				BackgroundTransparency = 1,
				Image = product.Image,
				Position = if isUnitFrame then UDim2.fromScale(0.238913, 0.234483) else UDim2.fromScale(0.0596399, 0.120643),
				ScaleType = Enum.ScaleType.Fit,
				Size = if isUnitFrame then UDim2.fromScale(0.5832, 0.376714) else UDim2.fromScale(0.890618, 0.657542),
				create("UIAspectRatioConstraint")({ AspectRatio = if isUnitFrame then 1 else 1.07 }),
			}),
		}),
	})
end

function EventShopUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local cards = {}
	for _, product in EventShopData.Products do
		table.insert(cards, productCard(product))
	end

	return create("CanvasGroup")({
		Name = "EventShopContainer", GroupTransparency = menuMotion.Transparency, Interactable = isVisible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = menuMotion.IsMounted,
		create("ImageLabel")({
			Name = "Main", Rotation = menuMotion:WindowRotation(), AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://127375273648665",
			Position = UDim2.fromScale(0.498839, 0.20195),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.668872)),
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://119392120885995",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,
				create("ImageLabel")({
					Name = "Icon", Rotation = menuMotion:IconRotation(), AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://135492889002201",
					Position = UDim2.fromScale(0.1377736, 0.4392036),
					Size = menuMotion:IconSize(UDim2.fromScale(0.211002, 0.747055)),
					create("UIAspectRatioConstraint")({ AspectRatio = 1.13 }),
				}),
				create("ImageLabel")({
					Name = "Cloud", ImageTransparency = menuMotion:Fade(),
					BackgroundTransparency = 1,
					Image = "rbxassetid://97738986977654",
					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)),
					Size = UDim2.fromScale(0.537766, 1.06417),
					create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }),
				}),
				create("TextLabel")({
					Name = "Title", TextTransparency = menuMotion:Fade(),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.354292, 0.290134),
					Text = "EVENT SHOP",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				create("UIAspectRatioConstraint")({ AspectRatio = 4.53 }),
			}),
			create("UIAspectRatioConstraint")({ AspectRatio = 1.88 }),
			create("ImageButton")({
				Name = "CancelButton", Rotation = menuMotion:CloseRotation(),
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = "rbxassetid://92651860309635",
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Size = UDim2.fromScale(0.102144, 0.15458),
				Activated = function()
					UIController:Close(VIEW_ID)
				end,
				useButtonEffect(nil, 1.1),
				create("UIAspectRatioConstraint")({}),
			}),
			create("CanvasGroup")({
				Name = "ScrollingFrameClip",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 0),
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.0369541, 0.187277)),
				Size = UDim2.fromScale(0.924581, 0.735607),
				ZIndex = 1,
				create("UIAspectRatioConstraint")({ AspectRatio = 2.37 }),
				create("ScrollingFrame")({
					Name = "ScrollingFrame", AnchorPoint = Vector2.new(0, 0),
					Active = true,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.fromScale(2, 0),
					Position = UDim2.fromScale(0, 0),
					ScrollBarImageColor3 = Color3.new(),
					ScrollBarThickness = 0,
					ScrollingDirection = Enum.ScrollingDirection.X,
					Size = UDim2.fromScale(1, 1),

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					unpack(cards),
				}),
			}),
		}),
		create("UIAspectRatioConstraint")({
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function EventShopUI.Init()
	DataClient = ServiceRegistry:GetService("DataClient")
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	UIController = ServiceRegistry:GetService("UIController")
end

return EventShopUI
