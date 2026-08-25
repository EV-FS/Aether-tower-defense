local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net.client)
local Vide = require(ReplicatedStorage.Packages.Vide)

local DataClient = {}

DataClient.Coins = Vide.source(0)
DataClient.Gems = Vide.source(0)
DataClient.Blossom = Vide.source(0)
DataClient.Level = Vide.source(1)
DataClient.Exp = Vide.source(0)

function DataClient.ExpLogic(currentLevel: number): number
	return 50 * (currentLevel + math.ceil(currentLevel / 10)) + 50
end

function DataClient.GetMaxExp(): number
	return DataClient.ExpLogic(DataClient.Level())
end

function DataClient.FormatNumber(n: number): string
	local formatted = tostring(math.floor(n or 0))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

local function syncFromLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		DataClient.Coins(coins.Value)
		coins:GetPropertyChangedSignal("Value"):Connect(function()
			DataClient.Coins(coins.Value)
		end)
	end

	local gems = leaderstats:FindFirstChild("Gems") :: IntValue?
	if gems then
		DataClient.Gems(gems.Value)
		gems:GetPropertyChangedSignal("Value"):Connect(function()
			DataClient.Gems(gems.Value)
		end)
	end

	local blossom = leaderstats:FindFirstChild("Blossom") :: IntValue?
	if blossom then
		DataClient.Blossom(blossom.Value)
		blossom:GetPropertyChangedSignal("Value"):Connect(function()
			DataClient.Blossom(blossom.Value)
		end)
	end

	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	if level then
		DataClient.Level(level.Value)
		level:GetPropertyChangedSignal("Value"):Connect(function()
			DataClient.Level(level.Value)
		end)
	end
end

function DataClient.FetchAll()
	for _, key in ipairs({ "Coins", "Gems", "Blossom", "Level", "Exp" }) do
		task.spawn(function()
			local ok, val = pcall(function()
				return Net.DataService.GetDataValue.Invoke(key):expect()
			end)
			if ok and val ~= nil then
				if key == "Coins" then
					DataClient.Coins(val)
				elseif key == "Gems" then
					DataClient.Gems(val)
				elseif key == "Blossom" then
					DataClient.Blossom(val)
				elseif key == "Level" then
					DataClient.Level(val)
				elseif key == "Exp" then
					DataClient.Exp(val)
				end
			end
		end)
	end
end

function DataClient.Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 5)
		if leaderstats then
			syncFromLeaderstats(player)
		end
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				syncFromLeaderstats(player)
			end
		end)
	end)
end

function DataClient.Start()
	if not RunService:IsClient() then
		return
	end

	DataClient.FetchAll()

	Net.DataService.CurrencyChanged.On(function(data)
		if typeof(data) ~= "table" or not data.CurrencyName then
			return
		end

		if data.CurrencyName == "Coins" then
			DataClient.Coins(data.CurrencyValue)
		elseif data.CurrencyName == "Gems" then
			DataClient.Gems(data.CurrencyValue)
		elseif data.CurrencyName == "Blossom" then
			DataClient.Blossom(data.CurrencyValue)
		elseif data.CurrencyName == "Level" then
			DataClient.Level(data.CurrencyValue)
		elseif data.CurrencyName == "Exp" then
			DataClient.Exp(data.CurrencyValue)
		end
	end)
end

return DataClient
