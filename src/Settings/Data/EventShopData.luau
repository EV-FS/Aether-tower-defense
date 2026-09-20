local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)

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

local function itemProduct(
	id: string,
	title: string,
	itemName: string,
	price: number,
	amount: number,
	layoutOrder: number
): Product
	local item = assert(ItemData.ByName[itemName], `Event shop item "{itemName}" is missing from ItemData`)
	return {
		Id = id,
		Title = title,
		Price = price,
		Image = item.ItemImage,
		RewardCategory = "Items",
		RewardName = itemName,
		RewardAmount = amount,
		LayoutOrder = layoutOrder,
		Gradient = RarityData.Get(item.Rarity).Presentation.Gradient,
	}
end

local products: { Product } = {
	itemProduct("IronBundle", "IRON x10", "Iron", 550, 10, 1),
	itemProduct("GoldBundle", "GOLD x5", "Gold", 2_000, 5, 2),
	itemProduct("DragonHeart", "DRAGON'S HEART", "Dragon's Heart", 4_500, 1, 3),
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
