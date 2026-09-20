local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useMenuMotion = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useMenuMotion)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

local VIEW_ID = "Shop"
local UIController
local purchaseBusy = source(false)

local isLast = false

local PRODUCTS = {
	{
		Name = "Vip",
		PurchaseName = "VIP",
		Title = "VIP",
		Price = 199,
		Description = "VIP유저 전용칭호+\n코인 획득량 25% 증가\n배너 비용할인 20% 할인\nAfk 보상 100% 증가",
		TitleSize = UDim2.fromScale(0.0827651, 0.240001),
		DescriptionSize = UDim2.fromScale(0.264445, 0.606204),
		Background = "rbxassetid://133871780628906",
		Icon = "rbxassetid://123749123428448",
		Gradient = ColorSequence.new(Color3.fromRGB(255, 207, 34), Color3.fromRGB(255, 91, 26)),
		Glow = Color3.fromRGB(255, 160, 43),
		LayoutOrder = 1,
	},
	{
		Name = "Inventory+",
		PurchaseName = "+500 Backpack",
		Title = "INVENTORY +",
		Price = 79,
		Description = "유닛 인벤토리 칸 갯수 200개 증가",
		TitleSize = UDim2.fromScale(0.331405, 0.240001),
		DescriptionSize = UDim2.fromScale(0.227433, 0.359308),
		Background = "rbxassetid://105641848752305",
		Icon = "rbxassetid://130689328733111",
		Gradient = ColorSequence.new(Color3.fromRGB(98, 70, 22), Color3.fromRGB(255, 91, 26)),
		Glow = Color3.fromRGB(255, 160, 43),
		LayoutOrder = 2,
	},
	{
		Name = "Coin2x",
		PurchaseName = "Double Coins",
		Title = "COIN 2X",
		Price = 199,
		Description = "획득하는 코인의 양 2배로 증가",
		TitleSize = UDim2.fromScale(0.213931, 0.240001),
		DescriptionSize = UDim2.fromScale(0.248993, 0.359308),
		Background = "rbxassetid://90822099076746",
		Icon = "rbxassetid://129529718006323",
		Gradient = ColorSequence.new(Color3.fromRGB(255, 247, 16), Color3.fromRGB(203, 255, 32)),
		Glow = Color3.fromRGB(210, 255, 64),
		LayoutOrder = 3,
	},
	{
		Name = "Luck2x",
		PurchaseName = "Lucky",
		Title = "LUCK 2X",
		Price = 299,
		Description = "행운이 2배로 상승",
		TitleSize = UDim2.fromScale(0.235257, 0.240001),
		DescriptionSize = UDim2.fromScale(0.248993, 0.359308),
		Background = "rbxassetid://103389399438277",
		Icon = "rbxassetid://112209565451582",
		Gradient = ColorSequence.new(Color3.fromRGB(255, 247, 16), Color3.fromRGB(203, 255, 32)),
		Glow = Color3.fromRGB(108, 255, 125),
		LayoutOrder = 4,
	},
	{
		Name = "AbsoluteHunter",
		PurchaseName = "Absolute Hunter",
		Title = "ABSOLUTE HUNTER",
		Price = 799,
		Description = "코인배너에서 앱솔루트 등급 유닛을 획득할 확률이 100% 증가",
		TitleSize = UDim2.fromScale(0.485076, 0.240001),
		DescriptionSize = UDim2.fromScale(0.264445, 0.606204),
		Background = "rbxassetid://99037659221779",
		Icon = "rbxassetid://101324511525362",
		Gradient = ColorSequence.new(Color3.fromRGB(144, 249, 255), Color3.fromRGB(235, 125, 255)),
		Glow = Color3.fromRGB(255, 170, 248),
		LayoutOrder = 5,
	},
}

local ShopUI = {}

local function promptPurchase(purchaseName: string)
	if purchaseBusy() then
		return
	end
	local product = PurchaseData.ByName.GamePasses[purchaseName]
	if not product then
		warn(`[ShopUI] Missing game pass data: {purchaseName}`)
		return
	end
	purchaseBusy(true)
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, product.Id)
	end)
	purchaseBusy(false)
	if not ok then
		warn(`[ShopUI] Could not open purchase prompt: {err}`)
	end
end

local function priceLabel(price: number)
	return create("Frame")({
		Name = "Price",
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.687, 0.5),
		Size = UDim2.fromScale(0.183943, 0.197901),
		create("ImageLabel")({
			Name = "Robux",
			BackgroundTransparency = 1,
			Image = "rbxassetid://72670054461157",
			Position = UDim2.fromScale(0.0520515, -0.0882353),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.2911, 1.11765),
			create("UIAspectRatioConstraint")({}),
			create("UIGradient")({
				Color = ColorSequence.new(Color3.fromRGB(17, 255, 17), Color3.fromRGB(194, 255, 185)),
				Rotation = -90,
			}),
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
			Position = UDim2.fromScale(0.39097, 0.0588235),
			Size = UDim2.fromScale(1.1811, 0.882353),
			Text = tostring(price),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Thickness = 0.08 }),
			create("UIGradient")({
				Color = ColorSequence.new(Color3.fromRGB(17, 255, 17), Color3.fromRGB(194, 255, 185)),
				Rotation = -90,
			}),
		}),
	})
end

local function productCard(config)
	return create("ImageLabel")({
		Name = config.Name,
		BackgroundTransparency = 1,
		Image = config.Background,
		LayoutOrder = config.LayoutOrder,
		Size = UDim2.fromScale(0.91547, 0.191786),
		create("UIAspectRatioConstraint")({ AspectRatio = 4.27133 }),
		create("ImageLabel")({
			Name = "Highlight",
			BackgroundTransparency = 1,
			Image = "rbxassetid://70965852052957",
			Position = UDim2.fromScale(-0.0189164, -0.185892),
			Size = UDim2.fromScale(0.353226, 1.36897),
			ZIndex = -1,
			create("UIAspectRatioConstraint")({}),
		}),
		create("ImageLabel")({
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = config.Icon,
			Position = UDim2.fromScale(0.0397689, 0.0480611),
			Size = UDim2.fromScale(0.224649, 0.901063),
			create("UIAspectRatioConstraint")({ AspectRatio = 0.95 }),
		}),
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.263282, 0.0929992),
			Size = config.TitleSize,
			Text = config.Title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ Thickness = 3 }),
			create("UIGradient")({ Color = config.Gradient, Rotation = 90 }),
			create("UIShadow")({ BlurRadius = UDim.new(0, 20), Color = config.Glow, Transparency = 0.5 }),
		}),
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.271106, 0.326952),
			Size = config.DescriptionSize,
			Text = config.Description,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UIStroke")({ Thickness = 2 }),
			create("UIGradient")({ Rotation = 90 }),
			create("UIShadow")({ BlurRadius = UDim.new(0, 20), Color = config.Glow, Transparency = 0.5 }),
		}),
		priceLabel(config.Price),
		create("ImageButton")({
			Name = "GiftButton",
			Active = false,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://98844680499099",
			Position = UDim2.fromScale(0.963224, 0.842459),
			Size = UDim2.fromScale(0.221037, 0.249376),
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
			create("UIStroke")({ Color = Color3.new(1, 1, 1) }),
			create("UICorner")({}),
		}),
		create("ImageButton")({
			Name = "PurchaseButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = "rbxassetid://139274506988816",
			Position = UDim2.fromScale(0.813465, 0.84246),
			Size = UDim2.fromScale(0.228367, 0.249376),
			Activated = function()
				promptPurchase(config.PurchaseName)
			end,
			useButtonEffect(0.94, 1.05),
			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.149276, 0.214464),
				Size = UDim2.fromScale(0.68577, 0.527425),
				Text = "PURCHASE",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				create("UIStroke")({}),
			}),
			create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(13, 255, 0), Color3.fromRGB(234, 255, 0)) }),
			create("UIStroke")({ Color = Color3.new(1, 1, 1) }),
			create("UICorner")({}),
		}),
	})
end

function ShopUI.RenderUI()
	local isVisible = UIController:IsVisible(VIEW_ID)
	local menuMotion = useMenuMotion(isVisible, function()
		return UIController:GetActiveView()
	end)
	local cards = table.create(#PRODUCTS)
	for _, config in PRODUCTS do
		table.insert(cards, productCard(config))
	end

	local openSFX = useAudio({
		Id = UISFX.ShopOpen.Id,
		Volume = UISFX.ShopOpen.Volume,
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
		Name = "Container", GroupTransparency = menuMotion.Transparency, Interactable = isVisible,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.753032, 1),
		Visible = menuMotion.IsMounted,
		create("ImageLabel")({
			Name = "Main", AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://127375273648665",
			Position = UDim2.fromScale(0.498839, 0.20195),
			Rotation = menuMotion:WindowRotation(),
			Size = menuMotion:WindowSize(UDim2.fromScale(0.721698, 0.593865)),
			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = "rbxassetid://75329771755132",
				Position = menuMotion:HeaderPosition(UDim2.fromScale(-0.0573612, -0.111321)),
				Size = UDim2.fromScale(0.683091, 0.28349),
				ZIndex = 10,
				create("ImageLabel")({
					Name = "Icon", Rotation = menuMotion:IconRotation(), AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://103167904612614",
					Position = UDim2.fromScale(0.108448, 0.476615),
					Size = menuMotion:IconSize(UDim2.fromScale(0.157055, 0.629612)),
					create("UIAspectRatioConstraint")({ AspectRatio = 1.13 }),
				}),
				create("ImageLabel")({
					Name = "Cloud", ImageTransparency = menuMotion:Fade(),
					BackgroundTransparency = 1,
					Image = "rbxassetid://97738986977654",
					Position = menuMotion:CloudPosition(UDim2.fromScale(0.529887, 0.0551715)),
					Size = UDim2.fromScale(0.507418, 1.06417),
					create("UIAspectRatioConstraint")({ AspectRatio = 2.16 }),
				}),
				create("TextLabel")({
					Name = "Title", TextTransparency = menuMotion:Fade(),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.354292, 0.290134),
					Text = "SHOP",
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
				Position = menuMotion:ClosePosition(UDim2.fromScale(0.980096, 0.0289194)),
				Rotation = menuMotion:CloseRotation(),
				Size = UDim2.fromScale(0.0822234, 0.15458),
				Activated = function()
					UIController:Close(VIEW_ID)
				end,
				useButtonEffect(nil, 1.1),
				create("UIAspectRatioConstraint")({}),
			}),
			create("CanvasGroup")({
				Name = "ScrollClip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				GroupTransparency = 0,
				Position = menuMotion:ContentPosition(UDim2.fromScale(0.5, 0.55462)),
				Size = UDim2.fromScale(0.951938, 0.769024),
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
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.fromScale(1, 1),
					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.01, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					unpack(cards),
				}),
			}),
		}),
		create("UIAspectRatioConstraint")({ AspectRatio = 1.547, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
end

function ShopUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
end

function ShopUI.Start() end
return ShopUI
