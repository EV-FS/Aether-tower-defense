local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Banner = require(script.Banner)
local DataService

local SummonService = {}
local RANDOM = Random.new()
local PRICES = { [1] = 100, [10] = 900 }

local ActiveSummons = {}

local function rollSingleUnit(bannerData)
	local randomNum = RANDOM:NextNumber(0, bannerData.TotalWeight)
	local currentWeight = 0

	for _, unitData in ipairs(bannerData.Units) do
		currentWeight += unitData.Weight
		if randomNum <= currentWeight then
			return unitData.Unit
		end
	end

	warn("roll 실패.")
	return nil
end

function SummonService.Summon(player: Player, amount: number)
	if type(amount) ~= "number" or not PRICES[amount] then
		warn(`유효하지 않은 뽑기 횟수: {amount}`)
		return { Success = false, PulledUnits = nil }
	end

	if ActiveSummons[player] then
		warn("뽑기가 이미 진행 중임.")
		return { Success = false, PulledUnits = nil }
	end

	local playerData = DataService:GetData(player)
	local totalCost = PRICES[amount]

	if not playerData or playerData.Coins < totalCost then
		warn("코인이 충분하지 않음.")
		return { Success = false, PulledUnits = nil }
	end

	ActiveSummons[player] = true

	local ok, success, pulledUnits = pcall(function()
		DataService:AddData(player, "Coins", -totalCost)

		local currentBanner = Banner.GetActiveBanner()
		local results = {}

		for _ = 1, amount do
			local unitName = rollSingleUnit(currentBanner)
			if unitName then
				table.insert(results, unitName)
				DataService:AddTower(player, unitName)
			end
		end

		return true, results
	end)

	ActiveSummons[player] = nil

	if not ok then
		warn(`Summon failed:\n{success}`)
		return { Success = false, PulledUnits = nil }
	end

	return { Success = success, PulledUnits = pulledUnits }
end

function SummonService.Init(services)
	DataService = services:GetService("DataService")
end

function SummonService.Start()
	task.spawn(function()
		while true do
			local secondsUntilNextHour = 3600 - (workspace:GetServerTimeNow() % 3600)
			task.wait(secondsUntilNextHour)
			Net.SummonService.BannerUpdated.FireAll(Banner.GetClientFormat())
		end
	end)

	Net.SummonService.GetBanner.On(function()
		print(Banner.GetClientFormat())
		return Banner.GetClientFormat()
	end)

	Net.SummonService.DoSummon.On(function(player: Player, amount: number)
		return SummonService.Summon(player, amount)
	end)
end

return SummonService
