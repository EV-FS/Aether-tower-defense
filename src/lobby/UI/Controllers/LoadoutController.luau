local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)
local InventoryController

local Peek = Fusion.peek

local scope = Fusion:scoped()

local Loadout = scope:Value({})
local EquippedSlots = scope:Value({})

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local SlotsUI = MainGui:WaitForChild("Slots")
local TowerSlots = SlotsUI:WaitForChild("TowerSlots")

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function towerKeyToNumber(towerKey: string | number): number?
	if typeof(towerKey) == "number" then
		return towerKey
	end

	local numberText = string.match(towerKey, "^t_(%d+)$")
	return numberText and tonumber(numberText) or nil
end

local function getTowerId(towerName: string?, towerKey: string | number?): string?
	if not towerName or not towerKey then
		return nil
	end

	local towerKeyId = towerKeyToNumber(towerKey)
	if not towerKeyId then
		return nil
	end

	return `{towerName}:{towerKeyId}`
end

-------------------------------------------------
--// LoadoutController
-------------------------------------------------
local LoadoutController = {}
LoadoutController.Loadout = {}
LoadoutController.EquippedSlots = EquippedSlots

function LoadoutController:GetTowerId(towerName, towerKey)
	return getTowerId(towerName, towerKey)
end

function LoadoutController:RebuildEquippedSlots()
	local equippedSlots = {}

	for slot, tower in self.Loadout do
		local towerName = tower.Name or tower.towerName
		local towerKey = tower.Key or tower.towerKey
		local towerId = getTowerId(towerName, towerKey)

		if towerId then
			equippedSlots[towerId] = tonumber(slot) or slot
		end
	end

	EquippedSlots:set(equippedSlots)
end

function LoadoutController:Refresh()
	self.Loadout = Net.DataService.GetDataValue.Invoke("Loadout"):expect()
	Loadout:set(self.Loadout)

	self:RebuildEquippedSlots()

	return self.Loadout
end

function LoadoutController:GetEquippedSlot(towerName: string, towerKey: string | number)
	local targetTowerId = getTowerId(towerName, towerKey)
	if not targetTowerId then
		return nil
	end

	local equippedSlots = Peek(EquippedSlots)
	if equippedSlots then
		return equippedSlots[targetTowerId]
	end

	return nil
end

function LoadoutController:ToggleEquip(towerName: string, towerKey: string | number, unequipAll: boolean?)
	local towerKeyId = towerKeyToNumber(towerKey)
	if not towerKeyId then
		return false
	end

	local requestType

	if unequipAll then
		requestType = "UnequipAll"
	elseif self:GetEquippedSlot(towerName, towerKeyId) then
		requestType = "Unequip"
	else
		requestType = "Equip"
	end

	local success = Net.LoadoutService.SetLoadout
		.Invoke({
			requestType = requestType,

			targetTower = {
				towerName = towerName,
				towerKey = towerKeyId,
			},
		})
		:expect()

	if success then
		self:Refresh()
	end

	return success
end

function LoadoutController:HydrateUI()
	for i = 1, 5 do
		local slotName = "Slot" .. i
		local slotFrame = TowerSlots:FindFirstChild(slotName)
		if not slotFrame then
			continue
		end

		local unitImage = slotFrame:WaitForChild("UnitImage")
		local levelText = slotFrame:WaitForChild("Level")
		local costText = slotFrame:WaitForChild("Cost")

		scope:Hydrate(slotFrame)({
			[Fusion.OnEvent("Activated")] = function()
				local loadout = Peek(Loadout)
				local tower = loadout[tostring(i)] or loadout[i]
				if tower then
					local towerName = tower.Name or tower.towerName
					local towerKey = tower.Key or tower.towerKey
					if towerName and towerKey then
						self:ToggleEquip(towerName, towerKey)
					end
				end
			end,
			ImageColor3 = scope:Computed(function(use)
				local loadout = use(Loadout)
				local tower = loadout[tostring(i)] or loadout[i]
				if not tower then
					return Color3.new(0.75, 0.75, 0.75)
				end

				local towerName = tower.Name or tower.towerName
				local towerInfo = TowerData.ByName[towerName]
				local rarity
				if towerInfo then
					rarity = towerInfo.Rarity
				end
				return RarityColor[rarity] or Color3.new(0.75, 0.75, 0.75)
			end),
		})

		scope:Hydrate(unitImage)({
			Visible = scope:Computed(function(use)
				local loadout = use(Loadout)
				return loadout[tostring(i)] ~= nil or loadout[i] ~= nil
			end),
			Image = scope:Computed(function(use)
				local loadout = use(Loadout)
				local tower = loadout[tostring(i)] or loadout[i]
				if not tower then
					return ""
				end

				local towerName = tower.Name or tower.towerName
				local towerInfo = TowerData.ByName[towerName]
				return towerInfo and towerInfo.TowerImage or ""
			end),
		})

		scope:Hydrate(levelText)({
			Visible = scope:Computed(function(use)
				local loadout = use(Loadout)
				return loadout[tostring(i)] ~= nil or loadout[i] ~= nil
			end),
			Text = scope:Computed(function(use)
				local loadout = use(Loadout)
				local tower = loadout[tostring(i)] or loadout[i]
				if not tower then
					return "Lv.0"
				end

				local towerName = tower.Name
				local towerKey = tower.Key

				if towerName and towerKey and InventoryController.OwnedTowers[towerName] then
					local towerData = InventoryController.OwnedTowers[towerName][towerKey]
					if towerData and towerData.Lv then
						return `Lv.{towerData.Lv}`
					end
				end

				return `Lv.{0}`
			end),
		})

		scope:Hydrate(costText)({
			Visible = scope:Computed(function(use)
				local loadout = use(Loadout)
				return loadout[tostring(i)] ~= nil or loadout[i] ~= nil
			end),
			Text = scope:Computed(function(use)
				local loadout = use(Loadout)
				local tower = loadout[tostring(i)] or loadout[i]
				if not tower then
					return "$0"
				end

				local towerName = tower.Name or tower.towerName
				local towerInfo = TowerData.ByName[towerName]
				local cost = 0
				if towerInfo and towerInfo.Stats and towerInfo.Stats[0] then
					cost = towerInfo.Stats[0].Cost or 0
				end
				return `${cost}`
			end),
		})
	end
end

function LoadoutController.Init(controllers)
	InventoryController = controllers.InventoryController

	task.spawn(function()
		LoadoutController:Refresh()
		LoadoutController:HydrateUI()
	end)
end

return LoadoutController
