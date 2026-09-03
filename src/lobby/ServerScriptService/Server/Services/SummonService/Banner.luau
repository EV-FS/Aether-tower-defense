local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)

local Banner = {}

Banner.UnitPool = SummonConfig.UnitPool
Banner.RarityRates = SummonConfig.RarityRates

local SECRET_SERVER_SALT = 8472957102
local BANNER_TIMER_DURATION = SummonConfig.BannerTimerDuration
local currentBanner = nil

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

		local rng = Random.new(SECRET_SERVER_SALT + (i * 9999))
		local selectedUnit = pool[rng:NextInteger(1, #pool)]

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
