local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local peek = Fusion.peek
local fusionScope = Fusion.scoped(Fusion)

local State = require(script.State)
local InventoryUI = require(script.Components.InventoryUI)

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")

local UIController = nil
local LoadoutController = nil
local InventoryClient = nil

local InventoryController = {}
InventoryController.OwnedTowers = {}

local function getNumericKey(rawTowerKey)
	return type(rawTowerKey) == "string" and tonumber(rawTowerKey:match("%d+$") or rawTowerKey) or rawTowerKey
end

function InventoryController:AddTowerButton(towerName, rawTowerKey, towerData)
	local towerInfo = TowerData.ByName[towerName]
	local towerKeyId = getNumericKey(rawTowerKey)
	if not towerInfo or not towerKeyId then
		return
	end

	local attributesKey = State.generateAttributesKey(towerName, towerData)

	local entries = State.ButtonEntries()

	local entry = entries[attributesKey]
	if entry then
		local newStack = table.clone(entry.Stack)
		table.insert(newStack.Towers, { Key = towerKeyId, Data = towerData })
		entry.Stack = newStack
		entry.Count(entry.Count() + 1)
	else
		local stack = {
			AttributesKey = attributesKey,
			Name = towerName,
			Towers = { { Key = towerKeyId, Data = towerData } },
		}

		entry = {
			Name = towerName,
			Key = towerKeyId,
			Data = towerData,
			Stack = stack,
			Count = Vide.source(1),
			RarityRank = State.RARITY_CONFIG[towerInfo.Rarity] and State.RARITY_CONFIG[towerInfo.Rarity].Order or 999,
		}

		local newEntries = table.clone(entries)
		newEntries[attributesKey] = entry
		State.ButtonEntries(newEntries)

		local rarityList = State.RarityEntries[towerInfo.Rarity]
		if rarityList then
			local newList = table.clone(rarityList())
			table.insert(newList, entry)
			rarityList(newList)
			State.RarityState[towerInfo.Rarity].Exist(true)
		end
	end
end

function InventoryController:RemoveTowerButton(towerName, rawTowerKey)
	local towerInfo = TowerData.ByName[towerName]
	local towerKeyId = getNumericKey(rawTowerKey)
	if not towerInfo or not towerKeyId then
		return
	end

	local selected = State.SelectedTower()
	if selected and selected.Name == towerName and selected.Key == towerKeyId then
		State.SelectedTower(nil)
	end

	local entries = State.ButtonEntries()
	for attrKey, entry in pairs(entries) do
		if entry.Name == towerName then
			local newTowers = {}
			local found = false
			for _, t in ipairs(entry.Stack.Towers) do
				if t.Key == towerKeyId then
					found = true
				else
					table.insert(newTowers, t)
				end
			end
			if found then
				local newStack = table.clone(entry.Stack)
				newStack.Towers = newTowers
				entry.Stack = newStack

				local newCount = entry.Count() - 1
				entry.Count(newCount)

				if newCount <= 0 then
					local newEntries = table.clone(entries)
					newEntries[attrKey] = nil
					State.ButtonEntries(newEntries)

					local rarityList = State.RarityEntries[towerInfo.Rarity]
					if rarityList then
						local newList = {}
						for _, e in ipairs(rarityList()) do
							if e ~= entry then
								table.insert(newList, e)
							end
						end
						rarityList(newList)
						State.RarityState[towerInfo.Rarity].Exist(#newList > 0)
					end
				end
				break
			end
		end
	end
end

function InventoryController:LoadTowers(towers)
	towers = towers or {}
	State.ButtonEntries({})
	for rarity, listSrc in pairs(State.RarityEntries) do
		listSrc({})
		State.RarityState[rarity].Exist(false)
	end

	for towerName, towerList in pairs(towers) do
		for rawKey, towerData in pairs(towerList) do
			self:AddTowerButton(towerName, rawKey, towerData)
		end
	end
end

function InventoryController:ToggleEquip()
	local selected = State.SelectedTower()
	if not selected then
		return
	end

	if not LoadoutController then
		warn("LoadoutController is not available.")
		return
	end

	LoadoutController:ToggleEquip(selected.Name, selected.Key)
end

function InventoryController.Init(controllers)
	LoadoutController = controllers.LoadoutController
	UIController = controllers.UIController

	InventoryClient = ServiceRegistry:GetService("InventoryClient")

	local existing = MainGui:FindFirstChild("Inventory")
	if existing then
		existing:Destroy()
	end

	local uiInst
	Vide.mount(function()
		uiInst = InventoryUI({
			OnClose = function()
				if UIController then
					UIController:Close("Inventory")
				end
			end,
			OnToggleEquip = function()
				InventoryController:ToggleEquip()
			end,
		})
		return uiInst
	end, MainGui)

	if UIController and UIController.Frames then
		UIController.Frames.Inventory = uiInst
	end

	if LoadoutController and LoadoutController.EquippedSlots then
		State.EquippedSlots(peek(LoadoutController.EquippedSlots) or {})
		fusionScope:Observer(LoadoutController.EquippedSlots):onChange(function()
			State.EquippedSlots(peek(LoadoutController.EquippedSlots) or {})
		end)
	end

	task.spawn(function()
		local towers = InventoryClient.GetOwnedTowers()
		InventoryController.OwnedTowers = towers
		InventoryController:LoadTowers(towers)
	end)

	InventoryClient.TowerAdded:Connect(function(towerName, towerKeyId, towerData)
		if not InventoryController.OwnedTowers[towerName] then
			InventoryController.OwnedTowers[towerName] = {}
		end
		local towerKey = `t_{towerKeyId}`
		InventoryController.OwnedTowers[towerName][towerKey] = towerData
		InventoryController:AddTowerButton(towerName, towerKeyId, towerData)
	end)

	InventoryClient.TowerRemoved:Connect(function(towerName, towerKeyId)
		if InventoryController.OwnedTowers[towerName] then
			local towerKey = `t_{towerKeyId}`
			InventoryController.OwnedTowers[towerName][towerKey] = nil
		end
		InventoryController:RemoveTowerButton(towerName, towerKeyId)
	end)

	InventoryClient.CountUpdated:Connect(function(category, itemName, newCount)
		if category == "Towers" and State.ExistCounts[itemName] then
			State.ExistCounts[itemName](newCount)
		end
	end)
end

return InventoryController
