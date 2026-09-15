local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net.client)
local Promise = require(ReplicatedStorage.Packages.Promise)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Collection = {
	Units: { [string]: boolean },
	Items: { [string]: boolean },
}

local IndexClient = {}

IndexClient.Collection = Vide.source({ Units = {}, Items = {} } :: Collection)
IndexClient.Units = Vide.source({} :: { [string]: boolean })
IndexClient.Items = Vide.source({} :: { [string]: boolean })

local InventoryClient
local activeRequest = nil
local requestVersion = 0

local function setCollection(value: any): Collection
	local collection = if typeof(value) == "table" then table.clone(value) else {}
	collection.Units = if typeof(collection.Units) == "table" then collection.Units else {}
	collection.Items = if typeof(collection.Items) == "table" then collection.Items else {}
	IndexClient.Collection(collection)
	IndexClient.Units(collection.Units)
	IndexClient.Items(collection.Items)
	return collection
end

function IndexClient.Refresh()
	requestVersion += 1
	local version = requestVersion
	local request = Net.DataService.GetDataValue.Invoke("Collection"):andThen(function(value)
		if version == requestVersion then
			activeRequest = nil
			return setCollection(value)
		end
		return IndexClient.Collection()
	end):catch(function(err)
		if version == requestVersion then activeRequest = nil end
		return Promise.reject(err)
	end)
	activeRequest = request
	return request
end

function IndexClient.Fetch()
	return activeRequest or IndexClient.Refresh()
end

local function discoverUnit(towerName: string)
	local current = IndexClient.Units()
	if current[towerName] then return end
	local updated = table.clone(current)
	updated[towerName] = true
	local collection = table.clone(IndexClient.Collection())
	collection.Units = updated
	IndexClient.Collection(collection)
	IndexClient.Units(updated)
end

local function discoverCurrentItems(inventory)
	local ownedItems = inventory and inventory.Items
	if typeof(ownedItems) ~= "table" then return end
	local current = IndexClient.Items()
	local updated = table.clone(current)
	local changed = false
	for itemName, count in ownedItems do
		if typeof(count) == "number" and count > 0 and not updated[itemName] then
			updated[itemName] = true
			changed = true
		end
	end
	if changed then
		local collection = table.clone(IndexClient.Collection())
		collection.Items = updated
		IndexClient.Collection(collection)
		IndexClient.Items(updated)
	end
end

function IndexClient.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
end

function IndexClient.Start()
	InventoryClient.TowerAdded:Connect(discoverUnit)
	InventoryClient.InventoryChanged:Connect(discoverCurrentItems)
	IndexClient.Refresh():catch(function(err)
		warn(`[IndexClient] Failed to load collection: {err}`)
	end)
end

return IndexClient
