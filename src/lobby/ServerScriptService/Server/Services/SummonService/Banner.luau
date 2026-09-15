local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local Banner = {}

Banner.UnitPool = SummonConfig.UnitPool
Banner.RarityRates = SummonConfig.RarityRates

local SECRET_SERVER_SALT = 8472957102
local BANNER_TIMER_DURATION = SummonConfig.BannerTimerDuration
local currentBanner = nil

local function hasTowerModel(unitName: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towers = assets and assets:FindFirstChild("Towers")
	local towerModel = towers and towers:FindFirstChild(unitName)
	return towerModel ~= nil and towerModel:IsA("Model")
end

local function getModelBackedPool(rarity: string, configuredPool: { string }): { string }
	local validPool = {}
	for _, unitName in configuredPool do
		local unitInfo = TowerData.ByName[unitName]
		if unitInfo and unitInfo.Rarity == rarity and hasTowerModel(unitName) then
			table.insert(validPool, unitName)
		elseif not unitInfo or unitInfo.Rarity ~= rarity then
			warn(`[SummonBanner] Ignoring invalid {rarity} unit: {unitName}`)
		end
	end

	if #validPool > 0 then
		return validPool
	end

	-- If every configured candidate is missing a model, keep the rarity slot and
	-- repopulate it from all model-backed towers of that same rarity.
	for unitName, unitInfo in TowerData.ByName do
		if unitInfo.Rarity == rarity and hasTowerModel(unitName) then
			table.insert(validPool, unitName)
		end
	end
	table.sort(validPool)
	return validPool
end

function Banner.GetActiveBanner()
	if currentBanner then
		return currentBanner
	end

	local activeLineup = {}
	local totalWeight = 0

	for i, rateData in ipairs(Banner.RarityRates) do
		local pool = Banner.UnitPool[rateData.Rarity]
		if not pool or #pool == 0 then
			continue
		end

		local validPool = getModelBackedPool(rateData.Rarity, pool)
		if #validPool == 0 then
			continue
		end

		local rng = Random.new(SECRET_SERVER_SALT + (i * 9999))
		local selectedUnit = validPool[rng:NextInteger(1, #validPool)]

		table.insert(activeLineup, {
			Unit = selectedUnit,
			Rarity = rateData.Rarity,
			Weight = rateData.Weight,
		})
		totalWeight += rateData.Weight
	end

	currentBanner = {
		Units = activeLineup,
		TotalWeight = totalWeight,
	}

	return currentBanner
end

function Banner.GetUnitForRarity(rarity: string): string?
	for _, unitData in ipairs(Banner.GetActiveBanner().Units) do
		if unitData.Rarity == rarity then
			return unitData.Unit
		end
	end

	return nil
end

function Banner.GetClientFormat()
	local activeBanner = Banner.GetActiveBanner()
	local serverTime = workspace:GetServerTimeNow()
	local clientData = {
		NextRerollTime = math.floor(serverTime + (BANNER_TIMER_DURATION - (serverTime % BANNER_TIMER_DURATION))),
		Units = {},
	}

	for _, data in ipairs(activeBanner.Units) do
		table.insert(clientData.Units, {
			Rarity = data.Rarity,
			Name = data.Unit,
			RateText = tostring(data.Weight) .. "%",
		})
	end

	return clientData
end

return Banner
