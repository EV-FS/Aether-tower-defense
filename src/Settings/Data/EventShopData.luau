local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type Product = {
	Id: string,
	Title: string,
	Price: number,
	Image: string,
	RewardCategory: "Items" | "Skins",
	RewardName: string,
	RewardAmount: number,
	Unique: boolean?,
	LayoutOrder: number,
	Gradient: ColorSequence,
}

local products: { Product } = {
	{
		Id = "EventChest",
		Title = "CHEST",
		Price = 550,
		Image = "rbxassetid://74082959709680",
		RewardCategory = "Items",
		RewardName = "Event Chest",
		RewardAmount = 1,
		LayoutOrder = 1,
		Gradient = ColorSequence.new(Color3.fromRGB(255, 67, 246), Color3.fromRGB(255, 111, 173)),
	},
	{
		Id = "PremiumEventChest",
		Title = "CHEST -(PREMIUM)-",
		Price = 2_000,
		Image = "rbxassetid://74082959709680",
		RewardCategory = "Items",
		RewardName = "Premium Event Chest",
		RewardAmount = 1,
		LayoutOrder = 2,
		Gradient = ColorSequence.new(Color3.fromRGB(255, 67, 246), Color3.fromRGB(255, 111, 173)),
	},
	{
		Id = "KitsuneEmoticon",
		Title = "Emoticon",
		Price = 4_500,
		Image = "rbxassetid://74082959709680",
		RewardCategory = "Items",
		RewardName = "Kitsune Emoticon",
		RewardAmount = 1,
		Unique = true,
		LayoutOrder = 3,
		Gradient = ColorSequence.new(Color3.fromRGB(255, 67, 246), Color3.fromRGB(255, 111, 173)),
	},
	{
		Id = "KitsuneUnitFrame",
		Title = "UNIT FRAME",
		Price = 12_500,
		Image = "rbxassetid://103789559110745",
		RewardCategory = "Items",
		RewardName = "Kitsune Unit Frame",
		RewardAmount = 1,
		Unique = true,
		LayoutOrder = 4,
		Gradient = ColorSequence.new(Color3.fromRGB(255, 67, 246), Color3.fromRGB(255, 111, 173)),
	},
	{
		Id = "MaidKitsuneSkin",
		Title = "Maid Kitune -(SKIN)-",
		Price = 25_500,
		Image = "rbxassetid://74082959709680",
		RewardCategory = "Skins",
		RewardName = "Maid Kitsune",
		RewardAmount = 1,
		Unique = true,
		LayoutOrder = 5,
		Gradient = ColorSequence.new(Color3.fromRGB(255, 32, 36), Color3.fromRGB(34, 15, 23)),
	},
}

local EventShopData = {
	Products = products,
	ById = {} :: { [string]: Product },
}

for _, product in products do
	assert(EventShopData.ById[product.Id] == nil, `Duplicate event shop product id: {product.Id}`)
	EventShopData.ById[product.Id] = product
end

return TableUtils.DeepFreeze(EventShopData)
