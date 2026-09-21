local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)

--/Types
export type ItemInfo = {
	Name: string,
	Index: number,
	Rarity: string,
	ItemImage: string,
	Description: string?,
}

export type ItemData = {
	ByName: { [string]: ItemInfo },
	ByIndex: { [number]: ItemInfo },
}

local ItemData = {
	ByName = {} :: { [string]: ItemInfo },
	ByIndex = {} :: { [number]: ItemInfo },
}

local itemFolder = script.Parent:FindFirstChild("Items")
assert(itemFolder and itemFolder:IsA("Folder"), "ItemData requires a Settings.Data.Items folder")

local itemModules = {}
for _, child in itemFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(itemModules, child)
	end
end
table.sort(itemModules, function(left, right)
	return left.Name < right.Name
end)

for _, itemModule in itemModules do
	local data = require(itemModule) :: ItemInfo
	local name = data.Name or itemModule.Name
	assert(ItemData.ByName[name] == nil, `Duplicate item name: {name}`)
	assert(ItemData.ByIndex[data.Index] == nil, `Duplicate item index: {data.Index}`)
	data.Name = name
	assert(RarityData.IsValid(data.Rarity), `Invalid rarity "{data.Rarity}" for item "{name}"`)
	ItemData.ByName[name] = data
	ItemData.ByIndex[data.Index] = data :: ItemInfo
end

return TableUtils.DeepFreeze(ItemData) :: ItemData
