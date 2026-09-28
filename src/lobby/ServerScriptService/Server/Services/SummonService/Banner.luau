local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local SummonBannerPool = require(ReplicatedStorage.Settings.Data.SummonBannerPool)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local BannerSchedule = require(ReplicatedStorage.Shared.Modules.Core.Summon.BannerSchedule)

local Banner = {}

local SERVER_SALT = 8472957102
local MAX_RANDOM_SEED = 2147483647
local currentSlot: number? = nil
local currentBanner = nil
local craftOnlyUnits = {}
for _, recipe in CraftRecipes do
	if recipe.ResultType == "Tower" then
		craftOnlyUnits[recipe.ResultName] = true
	end
end

local function hasTowerModel(unitName: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towers = assets and assets:FindFirstChild("Towers")
	local towerModel = towers and towers:FindFirstChild(unitName)
	return towerModel ~= nil and towerModel:IsA("Model")
end

local function getValidPool(rarity: string): { string }
	local configuredPool = SummonBannerPool[rarity]
	local validPool = {}
	local seen = {}
	if not configuredPool then
		warn(`[SummonBanner] No candidates configured for {rarity}.`)
		return validPool
	end
	for _, unitName in configuredPool do
		if seen[unitName] then continue end
		seen[unitName] = true
		local unitInfo = TowerData.ByName[unitName]
		if craftOnlyUnits[unitName] then
			warn(`[SummonBanner] Skipping craft-only unit {unitName}.`)
		elseif not unitInfo or unitInfo.Rarity ~= rarity then
			warn(`[SummonBanner] Skipping {unitName}: TowerData rarity does not match {rarity}.`)
		elseif not hasTowerModel(unitName) then
			warn(`[SummonBanner] Skipping {unitName}: ReplicatedStorage.Assets.Towers model is missing.`)
		else
			table.insert(validPool, unitName)
		end
	end
	return validPool
end

local function buildBanner(slot: number)
	local units = {}
	local totalWeight = 0
	for index, rateData in SummonConfig.RarityRates do
		local validPool = getValidPool(rateData.Rarity)
		if #validPool == 0 then
			warn(`[SummonBanner] No summonable {rateData.Rarity} units; this rarity is disabled for the current interval.`)
			continue
		end
		local seed = (SERVER_SALT + slot * 1103515245 + index * 12345) % MAX_RANDOM_SEED
		local rng = Random.new(seed)
		local selectedUnit = validPool[rng:NextInteger(1, #validPool)]
		table.insert(units, {
			Unit = selectedUnit,
			Rarity = rateData.Rarity,
			Weight = rateData.Weight,
		})
		totalWeight += rateData.Weight
	end
	return { Units = units, TotalWeight = totalWeight, Slot = slot }
end

function Banner.GetActiveBanner(timestamp: number?)
	local slot = BannerSchedule.GetSlot(timestamp or workspace:GetServerTimeNow())
	if currentSlot ~= slot then
		currentBanner = buildBanner(slot)
		currentSlot = slot
	end
	return currentBanner
end

function Banner.GetUnitForRarity(rarity: string, bannerData): string?
	for _, unitData in (bannerData or Banner.GetActiveBanner()).Units do
		if unitData.Rarity == rarity then
			return unitData.Unit
		end
	end
	return nil
end

function Banner.GetClientFormat()
	local serverTime = workspace:GetServerTimeNow()
	local activeBanner = Banner.GetActiveBanner(serverTime)
	local clientData = {
		NextRerollTime = math.floor(BannerSchedule.GetNextChange(serverTime)),
		Units = {},
	}
	for _, data in activeBanner.Units do
		table.insert(clientData.Units, {
			Rarity = data.Rarity,
			Name = data.Unit,
			RateText = string.format("%.2f%%", data.Weight / activeBanner.TotalWeight * 100),
		})
	end
	return clientData
end

return Banner
