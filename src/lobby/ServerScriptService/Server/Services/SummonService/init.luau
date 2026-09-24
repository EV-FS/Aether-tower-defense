local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local AutoSellConfig = require(ReplicatedStorage.Settings.Data.AutoSellConfig)
local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local UnitSellRewards = require(ReplicatedStorage.Settings.Data.UnitSellRewards)
local Banner = require(script.Banner)
local DataService

local SummonService = {}
local RANDOM = Random.new()
local PRICES = SummonConfig.Prices
local BANNER_TIMER_DURATION = SummonConfig.BannerTimerDuration
local MYTHIC_PITY_LIMIT = SummonConfig.Pity.Mythic.Limit
local ABSOLUTE_PITY_LIMIT = SummonConfig.Pity.Absolute.Limit
local MYTHIC_PITY_ATTRIBUTE = SummonConfig.Pity.Mythic.Attribute
local ABSOLUTE_PITY_ATTRIBUTE = SummonConfig.Pity.Absolute.Attribute

local ActiveSummons = {}

local function sanitizePity(value, limit: number): number
	return math.clamp(math.floor(tonumber(value) or 0), 0, limit - 1)
end

local function getPity(playerData)
	local savedPity = if type(playerData.SummonPity) == "table" then playerData.SummonPity else {}
	return {
		Mythic = sanitizePity(savedPity.Mythic, MYTHIC_PITY_LIMIT),
		Absolute = sanitizePity(savedPity.Absolute, ABSOLUTE_PITY_LIMIT),
	}
end

local function syncPityAttributes(player: Player, pity)
	player:SetAttribute(MYTHIC_PITY_ATTRIBUTE, pity.Mythic)
	player:SetAttribute(ABSOLUTE_PITY_ATTRIBUTE, pity.Absolute)
end

local function rollSingleUnit(bannerData)
	local randomNum = RANDOM:NextNumber(0, bannerData.TotalWeight)
	local currentWeight = 0

	for _, unitData in ipairs(bannerData.Units) do
		currentWeight += unitData.Weight
		if randomNum <= currentWeight then
			return unitData.Unit, unitData.Rarity
		end
	end

	warn("Summon roll failed to select a unit.")
	return nil, nil
end

function SummonService.Summon(player: Player, amount: number)
	if type(amount) ~= "number" or not PRICES[amount] then
		warn(`Invalid summon amount: {amount}`)
		return { Success = false, PulledUnits = {} }
	end

	if ActiveSummons[player] then
		warn(`A summon is already active for {player.Name}.`)
		return { Success = false, PulledUnits = {} }
	end

	local playerData = DataService:GetData(player)
	local totalCost = PRICES[amount]

	if not playerData or playerData.Coins < totalCost then
		warn(`Not enough coins to summon for {player.Name}.`)
		return { Success = false, PulledUnits = {} }
	end

	ActiveSummons[player] = true

	local ok, success, pulledUnits = pcall(function()
		local currentBanner = Banner.GetActiveBanner()
		if currentBanner.TotalWeight <= 0 or #currentBanner.Units == 0 then
			warn("Summon banner has no units with usable tower models.")
			return false, {}
		end

		DataService:AddData(player, "Coins", -totalCost)

		local pity = getPity(playerData)
		local results = {}
		local autoSellCoins = 0
		local autoSellShards = 0

		for _ = 1, amount do
			pity.Mythic += 1
			pity.Absolute += 1

			local forcedRarity
			if pity.Absolute >= ABSOLUTE_PITY_LIMIT then
				forcedRarity = "Absolute"
			elseif pity.Mythic >= MYTHIC_PITY_LIMIT then
				forcedRarity = "Mythic"
			end

			local unitName, rarity
			if forcedRarity then
				unitName = Banner.GetUnitForRarity(forcedRarity)
				if unitName then
					rarity = forcedRarity
				else
					unitName, rarity = rollSingleUnit(currentBanner)
				end
			else
				unitName, rarity = rollSingleUnit(currentBanner)
			end

			if unitName then
				local autoSellEntry = AutoSellConfig.ByRarity[rarity]
				local wasAutoSold = autoSellEntry ~= nil and playerData.Settings[autoSellEntry.SettingName] == true
				local sellPrice = if wasAutoSold then autoSellEntry.Price else 0
				table.insert(results, {
					UnitName = unitName,
					Rarity = rarity,
					Sold = wasAutoSold,
					SellPrice = sellPrice,
				})
				if wasAutoSold then
					autoSellCoins += sellPrice
					if UnitSellRewards.Roll(rarity, RANDOM) then
						autoSellShards += 1
					end
				else
					DataService:AddTower(player, unitName)
				end
			end

			if rarity == "Absolute" then
				pity.Absolute = 0
				pity.Mythic = 0
			elseif rarity == "Mythic" then
				pity.Mythic = 0
			end
		end

		DataService:UpdateData(player, "SummonPity", pity)
		if autoSellCoins > 0 then
			DataService:AddData(player, "Coins", autoSellCoins)
		end
		if autoSellShards > 0 then
			DataService:AddData(player, "Inventory", autoSellShards, "Items", UnitSellRewards.ItemName)
		end
		syncPityAttributes(player, pity)

		return true, results
	end)

	ActiveSummons[player] = nil

	if not ok then
		warn(`Summon failed:\n{success}`)
		return { Success = false, PulledUnits = {} }
	end

	return { Success = success, PulledUnits = pulledUnits }
end

function SummonService.Init(services)
	DataService = services:GetService("DataService")
end

function SummonService.Start()
	Players.PlayerRemoving:Connect(function(player)
		ActiveSummons[player] = nil
	end)

	task.spawn(function()
		while true do
			local serverTime = workspace:GetServerTimeNow()
			local secondsUntilTimerReset = BANNER_TIMER_DURATION - (serverTime % BANNER_TIMER_DURATION)
			task.wait(secondsUntilTimerReset)
			Net.SummonService.BannerUpdated.FireAll(Banner.GetClientFormat())
		end
	end)

	Net.SummonService.GetBanner.On(function(player: Player)
		local playerData = DataService:GetData(player)
		if playerData then
			syncPityAttributes(player, getPity(playerData))
		end
		return Banner.GetClientFormat()
	end)

	Net.SummonService.DoSummon.On(function(player: Player, amount: number)
		return SummonService.Summon(player, amount)
	end)
end

return SummonService
