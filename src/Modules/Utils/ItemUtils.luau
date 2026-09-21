local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)

export type StackInventory = { [string]: number }

local function normalizeKey(value: any): string
	return string.lower(tostring(value)):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end

local canonicalNames = {}
for itemName in ItemData.ByName do
	canonicalNames[normalizeKey(itemName)] = itemName
end

local ItemUtils = {}

function ItemUtils.GetCanonicalName(value: any): string?
	if typeof(value) == "number" then
		local itemInfo = ItemData.ByIndex[value]
		return if itemInfo then itemInfo.Name else nil
	end
	return canonicalNames[normalizeKey(value)]
end

function ItemUtils.NormalizeStacks(rawItems: any): StackInventory
	local merged: StackInventory = {}
	if typeof(rawItems) ~= "table" then
		return merged
	end

	for rawName, rawAmount in rawItems do
		local canonicalName = ItemUtils.GetCanonicalName(rawName)
		local amount = tonumber(rawAmount)
		if canonicalName and amount and amount > 0 then
			merged[canonicalName] = (merged[canonicalName] or 0) + math.floor(amount)
		end
	end

	return merged
end

return ItemUtils