local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ShopUI = require(script.Parent.ShopUI)

local create = Vide.create
local source = Vide.source

return {
	name = "Shop",
	summary = "Lobby shop preview with local visibility and purchase mocks. No Marketplace prompt or audio is used.",
	vide = Vide,
	controls = {
		Open = true,
	},
	story = function(props)
		local lastPurchase = source("구매 버튼을 눌러 상태를 확인하세요")
		local controller = {}

		function controller:IsVisible(viewName: string)
			return function()
				return viewName == "Shop" and props.controls.Open()
			end
		end

		function controller:GetActiveView(): string?
			return if props.controls.Open() then "Shop" else nil
		end

		function controller:Close(viewName: string): boolean
			if viewName ~= "Shop" then
				return false
			end
			props.controls.Open(false)
			return true
		end

		return create("Frame")({
			Name = "ShopStory",
			BackgroundColor3 = Color3.fromRGB(90, 119, 145),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),

			ShopUI.RenderUI({
				Controller = controller,
				DisableAudio = true,
				OnPurchase = function(purchaseName: string)
					lastPurchase(`미리보기 구매: {purchaseName}`)
				end,
			}),

			create("TextLabel")({
				Name = "PurchaseStatus",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(14, 18, 27),
				BackgroundTransparency = 0.15,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.5, 0.985),
				Size = UDim2.fromOffset(360, 34),
				Text = lastPurchase,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 18,
				ZIndex = 50,

				create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			}),
		})
	end,
}
