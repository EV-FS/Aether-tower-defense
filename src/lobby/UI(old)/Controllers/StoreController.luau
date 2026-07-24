local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local Net = require(ReplicatedStorage.Shared.Net.client)
local UIController

--/Fusion setup
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local scope = Fusion:scoped()

--/Constants
local BANNER_OPEN = UDim2.fromScale(0.95, 0.37)
local BANNER_CLOSE = UDim2.fromScale(0.95, 0.15)

--/Variables
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local StoreFrame = MainGui:WaitForChild("Store"):WaitForChild("Canvas")

--/React State
local IsBannerOpen = scope:Value(true)
local MaxBoughts = {}

for _, item in PurchaseData.ByName.DevProducts do
	MaxBoughts[item.Id] = scope:Value(false)
end

-------------------------------------------------
--// LocalFunctions
-------------------------------------------------
local function updateMaxPurchases(purchaseInfo, productId)
	if purchaseInfo.MaxPurchases and purchaseInfo.MaxPurchases > 0 then
		local playerPurchaseInfo = Net.DataService.GetDataValue.Invoke("DevProducts"):expect()
		if not playerPurchaseInfo then
			return
		end
		local purchaseTimes = playerPurchaseInfo[tostring(productId)] or 0
		if purchaseTimes >= purchaseInfo.MaxPurchases then
			MaxBoughts[productId] = MaxBoughts[productId] or scope:Value(false)
			MaxBoughts[productId]:set(true)
			return
		end
	end
end

-------------------------------------------------
--// StoreController
-------------------------------------------------
local StoreController = {}

function StoreController.Hydrate()
	scope:Hydrate(StoreFrame.Bar.Close)({
		[OnEvent("MouseButton1Click")] = function()
			UIController:Close("Store")
		end,
	})

	local bannerProduct = PurchaseData.ByName.DevProducts[StoreFrame.Banner:GetAttribute("ProductName")]
	local bannerId = if bannerProduct then bannerProduct.Id else nil
	scope:Hydrate(StoreFrame.Banner)({
		Visible = scope:Computed(function(use)
			return if bannerId and MaxBoughts[bannerId] then not use(MaxBoughts[bannerId]) else true
		end),
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(IsBannerOpen) then BANNER_OPEN else BANNER_CLOSE
			end),
			25,
			0.7
		),
	})
	scope:Hydrate(StoreFrame.Banner.FoldButton)({
		Rotation = scope:Tween(
			scope:Computed(function(use)
				return if use(IsBannerOpen) then 0 else 180
			end),
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		),
		[OnEvent("MouseButton1Click")] = function()
			IsBannerOpen:set(not peek(IsBannerOpen))
		end,
	})
	scope:Hydrate(StoreFrame.Banner.Price)({
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(IsBannerOpen) then UDim2.fromScale(0.028, 0.8) else UDim2.fromScale(0.028, 0.65)
			end),
			25,
			0.7
		),
	})
	scope:Hydrate(StoreFrame.Banner.Description)({
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(IsBannerOpen) then UDim2.fromScale(0.029, 0.49) else UDim2.fromScale(0.11, 1)
			end),
			25,
			0.7
		),
	})

	scope:Hydrate(StoreFrame.ScollBar)({
		Size = scope:Spring(
			scope:Computed(function(use)
				return if bannerId
						and MaxBoughts[bannerId]
						and use(MaxBoughts[bannerId])
					then UDim2.fromScale(0.016, 0.87)
					elseif use(IsBannerOpen) then UDim2.fromScale(0.016, 0.5)
					else UDim2.fromScale(0.016, 0.72)
			end),
			20,
			0.9
		),
	})
	scope:Hydrate(StoreFrame.GamepassList)({
		Size = scope:Spring(
			scope:Computed(function(use)
				return if bannerId
						and MaxBoughts[bannerId]
						and use(MaxBoughts[bannerId])
					then UDim2.fromScale(0.963, 0.87)
					elseif use(IsBannerOpen) then UDim2.fromScale(0.963, 0.5)
					else UDim2.fromScale(0.963, 0.72)
			end),
			20,
			0.9
		),
	})
end

function StoreController.NewGamePassButton(button: GuiButton)
	local passId = button:GetAttribute("PassId")
	local passName = button:GetAttribute("PassName")
	if not passId then
		if not passName then
			return
		end

		local purchaseInfo = PurchaseData.ByName.GamePasses[passName]
		if not purchaseInfo then
			warn(`Purchase 데이터가 존재하지 않음: {passName}`)
			return
		end

		passId = purchaseInfo.Id
	end

	scope:Hydrate(button)({
		[OnEvent("MouseButton1Click")] = function()
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
		end,
	})

	local priceText = button:FindFirstChild("Price")
	if priceText and priceText:IsA("TextLabel") then
		local productInfo = MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)
		scope:Hydrate(priceText)({
			Text = string.format(
				"%s%s",
				'<font family="rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json">robux</font>',
				`{productInfo.PriceInRobux or "N/A"}`
			),
		})
	end
end

function StoreController.NewDevProductButton(button: GuiButton)
	local productId = button:GetAttribute("ProductId")
	local productName = button:GetAttribute("ProductName")
	local purchaseInfo = if not productId
		then PurchaseData.ByName.DevProducts[productName]
		else PurchaseData.ById[productId]

	if not productId then
		if not productName then
			return
		end
		if not purchaseInfo then
			warn(`Purchase 데이터가 존재하지 않음: {productName}`)
			return
		end

		productId = purchaseInfo.Id
	end

	scope:Hydrate(button)({
		Visible = scope:Computed(function(use)
			return not use(MaxBoughts[productId])
		end),
		[OnEvent("MouseButton1Click")] = function()
			if peek(MaxBoughts[productId]) then
				return
			end
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end,
	})

	local priceText = button:FindFirstChild("Price")
	if priceText and priceText:IsA("TextLabel") then
		local productInfo = MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
		scope:Hydrate(priceText)({
			Text = string.format(
				"%s%s",
				'<font family="rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json">robux</font>',
				`{productInfo.PriceInRobux or "N/A"}`
			),
		})
	end

	updateMaxPurchases(purchaseInfo, productId)
end

function StoreController.Init(controllers)
	UIController = controllers.UIController

	for _, button in CollectionService:GetTagged("GamePass") do
		task.spawn(StoreController.NewGamePassButton, button)
	end
	for _, button in CollectionService:GetTagged("DevProduct") do
		task.spawn(StoreController.NewDevProductButton, button)
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, isPurchased: boolean)
			if userId ~= Players.LocalPlayer.UserId or not isPurchased then
				return
			end
			local purchaseInfo = PurchaseData.ById[productId]
			if not purchaseInfo then
				return
			end

			updateMaxPurchases(purchaseInfo, productId)
		end
	)

	StoreController.Hydrate()
end

return StoreController
