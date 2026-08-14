local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

type towerKey = string | number

local InventoryClient = {}
InventoryClient.OwnedTowers = {}
InventoryClient.Loadout = Vide.source({})
InventoryClient.LoadedPromise = nil
InventoryClient.LoadoutLoadedPromise = nil
InventoryClient.TowersChanged = Vide.source(0)

InventoryClient.TowersLoaded = Signal.new()
InventoryClient.TowerAdded = Signal.new()
InventoryClient.TowerRemoved = Signal.new()
InventoryClient.CountUpdated = Signal.new()

function InventoryClient.GetOwnedTowers()
	if InventoryClient.LoadedPromise then
		InventoryClient.LoadedPromise:expect()
	else
		InventoryClient.FetchTowers():expect()
	end
	return InventoryClient.OwnedTowers
end

function InventoryClient.FetchTowers()
	if InventoryClient.LoadedPromise then
		return InventoryClient.LoadedPromise
	end

	InventoryClient.LoadedPromise = Net.DataService.GetDataValue
		.Invoke("OwnedTowers")
		:andThen(function(towers)
			InventoryClient.OwnedTowers = towers or {}
			InventoryClient.TowersLoaded:Fire(InventoryClient.OwnedTowers)
			return InventoryClient.OwnedTowers
		end)
		:catch(function(err)
			warn(`타워 인벤토리 불러오기 실패: {err}`)
			InventoryClient.OwnedTowers = {}
		end)

	return InventoryClient.LoadedPromise
end

function InventoryClient.FetchLoadout()
	if InventoryClient.LoadoutLoadedPromise then
		return InventoryClient.LoadoutLoadedPromise
	end

	InventoryClient.LoadoutLoadedPromise = Net.DataService.GetDataValue
		.Invoke("Loadout")
		:andThen(function(loadout)
			InventoryClient.Loadout(loadout or {})
			return InventoryClient.Loadout()
		end)
		:catch(function(err)
			warn(`로드아웃 불러오기 실패: {err}`)
			InventoryClient.Loadout({})
		end)

	return InventoryClient.LoadoutLoadedPromise
end

local function getTowerKeyId(towerKey: towerKey): number?
	local keyText = tostring(towerKey)
	local keyId = tonumber(string.match(keyText, "(%d+)$"))
	return keyId
end

function InventoryClient.EquipTower(towerName: string, towerKey: towerKey)
	local towerKeyId = getTowerKeyId(towerKey)
	if not towerKeyId then
		return false
	end

	local ok, success = pcall(function()
		return Net.LoadoutService.SetLoadout.Invoke({
			requestType = "Equip",
			targetTower = {
				towerName = towerName,
				towerKey = towerKeyId,
			},
		}):expect()
	end)

	if ok and success then
		InventoryClient.LoadoutLoadedPromise = nil
		InventoryClient.FetchLoadout()
	end

	return ok and success == true
end

function InventoryClient.SellTower(towerName: string, towerKey: towerKey) end

function InventoryClient.Init() end

function InventoryClient.Start()
	InventoryClient.FetchTowers()
	InventoryClient.FetchLoadout()

	Net.DataService.OwnedTowersAdded.On(function(data: { towerData: any, towerIndex: number, towerKeyId: number })
		local towerName = TowerData.ByIndex[data.towerIndex] and TowerData.ByIndex[data.towerIndex].Name
		if towerName then
			if not InventoryClient.OwnedTowers[towerName] then
				InventoryClient.OwnedTowers[towerName] = {}
			end
			local towerKey = `t_{data.towerKeyId}`
			InventoryClient.OwnedTowers[towerName][towerKey] = data.towerData
			InventoryClient.TowersChanged(InventoryClient.TowersChanged() + 1)
			InventoryClient.TowerAdded:Fire(towerName, data.towerKeyId, data.towerData)
		end
	end)

	Net.DataService.OwnedTowersRemoved.On(function(data: { towerIndex: number, towerKeyId: number })
		local towerName = TowerData.ByIndex[data.towerIndex] and TowerData.ByIndex[data.towerIndex].Name
		if towerName and InventoryClient.OwnedTowers[towerName] then
			local towerKey = `t_{data.towerKeyId}`
			InventoryClient.OwnedTowers[towerName][towerKey] = nil
			InventoryClient.TowersChanged(InventoryClient.TowersChanged() + 1)
			InventoryClient.TowerRemoved:Fire(towerName, data.towerKeyId)
		end
	end)

	Net.GlobalExistService.CountUpdated.On(function(data: { category: string, itemName: string, newCount: number })
		InventoryClient.CountUpdated:Fire(data.category, data.itemName, data.newCount)
	end)
end

return InventoryClient
