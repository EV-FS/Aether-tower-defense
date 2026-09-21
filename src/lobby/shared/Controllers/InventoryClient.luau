local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net.client)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ItemUtils = require(ReplicatedStorage.Shared.Modules.Utils.ItemUtils)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local Vide = require(ReplicatedStorage.Packages.Vide)

local MAX_TOWER_KEY_ID = 4_294_967_295
local MAX_LOADOUT_SIZE = 5

export type TowerKey = string | number
export type OwnedTowers = { [string]: { [string]: any } }
export type LoadoutEntry = {
	Name: string?,
	Key: string?,
	towerName: string?,
	towerKey: string?,
}
export type Loadout = { [string | number]: LoadoutEntry }
export type StackInventory = { [string]: number }
export type GeneralInventory = {
	Items: StackInventory,
	Skins: StackInventory,
	[string]: any,
}

type LoadoutRequestType = "Equip" | "Unequip" | "UnequipAll"
type TowerAddedData = { towerData: any, towerIndex: number, towerKeyId: number }
type TowerRemovedData = { towerIndex: number, towerKeyId: number }
type CountUpdatedData = { category: string, itemName: string, newCount: number }

local InventoryClient = {}

InventoryClient.Towers = Vide.source({} :: OwnedTowers)
InventoryClient.Loadout = Vide.source({} :: Loadout)
InventoryClient.Inventory = Vide.source({ Items = {}, Skins = {} } :: GeneralInventory)
InventoryClient.Items = Vide.source({} :: StackInventory)
InventoryClient.Skins = Vide.source({} :: StackInventory)

InventoryClient.TowersChanged = Signal.new()
InventoryClient.LoadoutChanged = Signal.new()
InventoryClient.InventoryChanged = Signal.new()
InventoryClient.TowerAdded = Signal.new()
InventoryClient.TowerRemoved = Signal.new()
InventoryClient.CountUpdated = Signal.new()

local towersRequest = nil
local loadoutRequest = nil
local inventoryRequest = nil
local towersLoaded = false
local loadoutLoaded = false
local inventoryLoaded = false
local towersRequestVersion = 0
local loadoutRequestVersion = 0
local inventoryRequestVersion = 0
local inventorySyncScheduled = false

local function normalizeItemStacks(rawItems: any): StackInventory
	return ItemUtils.NormalizeStacks(rawItems)
end

local function normalizeTowerKey(towerKey: TowerKey): (string?, number?)
	local keyId

	if typeof(towerKey) == "number" then
		keyId = towerKey
	else
		local keyIdText = string.match(towerKey, "^t_(%d+)$") or string.match(towerKey, "^(%d+)$")
		keyId = if keyIdText then tonumber(keyIdText) else nil
	end

	if not keyId or keyId % 1 ~= 0 or keyId < 0 or keyId > MAX_TOWER_KEY_ID then
		return nil, nil
	end

	return `t_{keyId}`, keyId
end

local function getTowerName(towerIndex: number): string?
	local towerInfo = TowerData.ByIndex[towerIndex]
	return if towerInfo then towerInfo.Name else nil
end

local function setTowers(towers: OwnedTowers)
	InventoryClient.Towers(towers)
	InventoryClient.TowersChanged:Fire(towers)
end

local function setLoadout(loadout: Loadout)
	InventoryClient.Loadout(loadout)
	InventoryClient.LoadoutChanged:Fire(loadout)
end

local function setInventory(inventory: GeneralInventory)
	local normalized = table.clone(inventory)
	normalized.Items = normalizeItemStacks(inventory.Items)
	normalized.Skins = if typeof(inventory.Skins) == "table" then inventory.Skins else {}

	InventoryClient.Inventory(normalized)
	InventoryClient.Items(normalized.Items)
	InventoryClient.Skins(normalized.Skins)
	InventoryClient.InventoryChanged:Fire(normalized)
end

local function loadTowers(forceRefresh: boolean?)
	if towersRequest and not forceRefresh then
		return towersRequest
	end
	if towersLoaded and not forceRefresh then
		return Promise.resolve(InventoryClient.Towers())
	end

	towersRequestVersion += 1
	local requestVersion = towersRequestVersion

	local request = Net.DataService.GetDataValue
		.Invoke("OwnedTowers")
		:andThen(function(value)
			local towers = if typeof(value) == "table" then value else {}

			if requestVersion == towersRequestVersion then
				towersLoaded = true
				towersRequest = nil
				setTowers(towers)
			end

			return towers
		end)
		:catch(function(err)
			if requestVersion == towersRequestVersion then
				towersRequest = nil
			end

			return Promise.reject(err)
		end)

	towersRequest = request
	return request
end

local function loadLoadout(forceRefresh: boolean?)
	if loadoutRequest and not forceRefresh then
		return loadoutRequest
	end
	if loadoutLoaded and not forceRefresh then
		return Promise.resolve(InventoryClient.Loadout())
	end

	loadoutRequestVersion += 1
	local requestVersion = loadoutRequestVersion

	local request = Net.DataService.GetDataValue
		.Invoke("Loadout")
		:andThen(function(value)
			local loadout = if typeof(value) == "table" then value else {}

			if requestVersion == loadoutRequestVersion then
				loadoutLoaded = true
				loadoutRequest = nil
				setLoadout(loadout)
			end

			return loadout
		end)
		:catch(function(err)
			if requestVersion == loadoutRequestVersion then
				loadoutRequest = nil
			end

			return Promise.reject(err)
		end)

	loadoutRequest = request
	return request
end

local function loadInventory(forceRefresh: boolean?)
	if inventoryRequest and not forceRefresh then
		return inventoryRequest
	end
	if inventoryLoaded and not forceRefresh then
		return Promise.resolve(InventoryClient.Inventory())
	end

	inventoryRequestVersion += 1
	local requestVersion = inventoryRequestVersion
	local request = Net.DataService.GetDataValue
		.Invoke("Inventory")
		:andThen(function(value)
			local inventory = if typeof(value) == "table" then value else {}
			if requestVersion == inventoryRequestVersion then
				inventoryLoaded = true
				inventoryRequest = nil
				setInventory(inventory)
			end
			return inventory
		end)
		:catch(function(err)
			if requestVersion == inventoryRequestVersion then
				inventoryRequest = nil
			end
			return Promise.reject(err)
		end)

	inventoryRequest = request
	return request
end

local function getEntryTowerName(entry: LoadoutEntry): string?
	return entry.Name or entry.towerName
end

local function getEntryTowerKey(entry: LoadoutEntry): string?
	local towerKey = entry.Key or entry.towerKey
	if not towerKey then
		return nil
	end

	local normalizedKey = normalizeTowerKey(towerKey)
	return normalizedKey
end

local function requestLoadoutChange(requestType: LoadoutRequestType, towerName: string?, towerKey: TowerKey?)
	local payload = {
		requestType = requestType,
	}

	if requestType ~= "UnequipAll" then
		if typeof(towerName) ~= "string" or towerKey == nil then
			return Promise.resolve(false)
		end

		local _, towerKeyId = normalizeTowerKey(towerKey)
		if not towerKeyId then
			return Promise.resolve(false)
		end

		payload.targetTower = {
			towerName = towerName,
			towerKey = towerKeyId,
		}
	end

	return Net.LoadoutService.SetLoadout.Invoke(payload):andThen(function(success)
		if success ~= true then
			return false
		end

		return InventoryClient.RefreshLoadout():andThenReturn(true)
	end)
end

local function onTowerAdded(data: TowerAddedData)
	local towerName = getTowerName(data.towerIndex)
	if not towerName then
		warn(`[InventoryClient] Unknown tower index received: {data.towerIndex}`)
		return
	end

	local towerKey = `t_{data.towerKeyId}`
	local currentTowers = InventoryClient.Towers()
	local updatedTowers = table.clone(currentTowers)
	local towersOfType = table.clone(currentTowers[towerName] or {})

	towersOfType[towerKey] = data.towerData
	updatedTowers[towerName] = towersOfType
	setTowers(updatedTowers)
	InventoryClient.TowerAdded:Fire(towerName, towerKey, data.towerData)
end

local function onTowerRemoved(data: TowerRemovedData)
	local towerName = getTowerName(data.towerIndex)
	local towerKey = `t_{data.towerKeyId}`
	local currentTowers = InventoryClient.Towers()
	local currentTowersOfType = if towerName then currentTowers[towerName] else nil

	if not towerName or not currentTowersOfType or currentTowersOfType[towerKey] == nil then
		return
	end

	local updatedTowers = table.clone(currentTowers)
	local updatedTowersOfType = table.clone(currentTowersOfType)
	updatedTowersOfType[towerKey] = nil

	if next(updatedTowersOfType) then
		updatedTowers[towerName] = updatedTowersOfType
	else
		updatedTowers[towerName] = nil
	end

	setTowers(updatedTowers)
	InventoryClient.TowerRemoved:Fire(towerName, towerKey)
end

function InventoryClient.Load()
	return Promise.all({ loadTowers(), loadLoadout(), loadInventory() }):andThen(function(values)
		return {
			Towers = values[1],
			Loadout = values[2],
			Inventory = values[3],
		}
	end)
end

function InventoryClient.RefreshInventory()
	return loadInventory(true)
end

function InventoryClient.FetchInventory()
	return loadInventory()
end

function InventoryClient.PerformUnitAction(action: "ToggleUnitLock" | "SellUnit", towerName: string, towerKey: TowerKey)
	return Promise.new(function(resolve, reject)
		task.spawn(function()
			local remotes = ReplicatedStorage:WaitForChild("RuntimeRemotes", 5)
			local remote = remotes and remotes:FindFirstChild("InventoryAction")
			if not remote or not remote:IsA("RemoteFunction") then
				reject("Inventory action service is unavailable.")
				return
			end

			local success, result = pcall(function()
				return remote:InvokeServer({
					Action = action,
					TowerName = towerName,
					TowerKey = towerKey,
				})
			end)
			if not success then
				reject(result)
				return
			end
			if typeof(result) ~= "table" then
				reject("Invalid unit action response.")
				return
			end

			if result.Success == true then
				Promise.all({ InventoryClient.RefreshTowers(), InventoryClient.RefreshLoadout() }):andThen(function()
					resolve(result)
				end):catch(reject)
			else
				resolve(result)
			end
		end)
	end)
end

function InventoryClient.RefreshTowers()
	return loadTowers(true)
end

function InventoryClient.RefreshLoadout()
	return loadLoadout(true)
end

function InventoryClient.FetchTowers()
	return loadTowers()
end

function InventoryClient.FetchLoadout()
	return loadLoadout()
end

function InventoryClient.Refresh()
	return Promise.all({
		InventoryClient.RefreshTowers(),
		InventoryClient.RefreshLoadout(),
		InventoryClient.RefreshInventory(),
	}):andThen(function(values)
		return {
			Towers = values[1],
			Loadout = values[2],
			Inventory = values[3],
		}
	end)
end

function InventoryClient.GetTower(towerName: string, towerKey: TowerKey): any?
	local normalizedKey = normalizeTowerKey(towerKey)
	local towersOfType = InventoryClient.Towers()[towerName]
	return if normalizedKey and towersOfType then towersOfType[normalizedKey] else nil
end

function InventoryClient.OwnsTower(towerName: string, towerKey: TowerKey): boolean
	return InventoryClient.GetTower(towerName, towerKey) ~= nil
end

function InventoryClient.UpdateTowerField(towerName: string, towerKey: TowerKey, field: string, value: any): boolean
	local normalizedKey = normalizeTowerKey(towerKey)
	local currentTowers = InventoryClient.Towers()
	local currentTowersOfType = if normalizedKey then currentTowers[towerName] else nil
	local currentTower = if currentTowersOfType then currentTowersOfType[normalizedKey] else nil
	if not normalizedKey or not currentTowersOfType or not currentTower then
		return false
	end

	local updatedTowers = table.clone(currentTowers)
	local updatedTowersOfType = table.clone(currentTowersOfType)
	local updatedTower = table.clone(currentTower)
	updatedTower[field] = value
	updatedTowersOfType[normalizedKey] = updatedTower
	updatedTowers[towerName] = updatedTowersOfType
	setTowers(updatedTowers)
	return true
end

function InventoryClient.GetLoadoutSlot(slotNumber: number): LoadoutEntry?
	if slotNumber % 1 ~= 0 or slotNumber < 1 or slotNumber > MAX_LOADOUT_SIZE then
		return nil
	end

	local loadout = InventoryClient.Loadout()
	return loadout[tostring(slotNumber)] or loadout[slotNumber]
end

function InventoryClient.FindEquippedSlot(towerName: string, towerKey: TowerKey): number?
	local normalizedKey = normalizeTowerKey(towerKey)
	if not normalizedKey then
		return nil
	end

	for slotNumber = 1, MAX_LOADOUT_SIZE do
		local entry = InventoryClient.GetLoadoutSlot(slotNumber)
		if entry and getEntryTowerName(entry) == towerName and getEntryTowerKey(entry) == normalizedKey then
			return slotNumber
		end
	end

	return nil
end

function InventoryClient.IsEquipped(towerName: string, towerKey: TowerKey): boolean
	return InventoryClient.FindEquippedSlot(towerName, towerKey) ~= nil
end

function InventoryClient.EquipTower(towerName: string, towerKey: TowerKey)
	return requestLoadoutChange("Equip", towerName, towerKey)
end

function InventoryClient.UnequipTower(towerName: string, towerKey: TowerKey)
	return requestLoadoutChange("Unequip", towerName, towerKey)
end

function InventoryClient.UnequipAll()
	return requestLoadoutChange("UnequipAll")
end

function InventoryClient.SetEquipped(towerName: string, towerKey: TowerKey, equipped: boolean)
	if equipped then
		return InventoryClient.EquipTower(towerName, towerKey)
	end

	return InventoryClient.UnequipTower(towerName, towerKey)
end

function InventoryClient.ToggleTower(towerName: string, towerKey: TowerKey)
	return InventoryClient.SetEquipped(towerName, towerKey, not InventoryClient.IsEquipped(towerName, towerKey))
end

function InventoryClient.Init() end

function InventoryClient.Start()
	Net.DataService.OwnedTowersAdded.On(onTowerAdded)
	Net.DataService.OwnedTowersRemoved.On(onTowerRemoved)
	Net.GlobalExistService.CountUpdated.On(function(data: CountUpdatedData)
		InventoryClient.CountUpdated:Fire(data.category, data.itemName, data.newCount)
	end)
	Net.DataService.CurrencyChanged.On(function(data)
		if data.CurrencyName ~= "Inventory" or inventorySyncScheduled then
			return
		end
		inventorySyncScheduled = true
		task.defer(function()
			inventorySyncScheduled = false
			InventoryClient.RefreshInventory():catch(function(err)
				warn(`[InventoryClient] Failed to synchronize inventory: {err}`)
			end)
		end)
	end)

	InventoryClient.Load():catch(function(err)
		warn(`[InventoryClient] Failed to load inventory: {err}`)
	end)
end

return InventoryClient
