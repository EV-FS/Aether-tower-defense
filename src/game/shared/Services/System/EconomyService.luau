--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)

local playerCash: { [number]: number } = {}

local function updateLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local CashValue = leaderstats:FindFirstChild("Cash") or Instance.new("IntValue")
	CashValue.Name = "Cash"
	CashValue.Parent = leaderstats

	CashValue.Value = playerCash[player.UserId]
end

-------------------------------------------------
--// EconomyService
-------------------------------------------------
local EconomyService = {}

function EconomyService.Init() end

function EconomyService.Start()
	if RunService:IsClient() then
		task.spawn(function()
			local player = Players.LocalPlayer
			local leaderstats = player:WaitForChild("leaderstats", 10)
			local cashValue = leaderstats:WaitForChild("Cash", 10)

			cashValue.Changed:Connect(function(newValue)
				ClientSignals.CashChanged:Fire(newValue)
			end)

			ClientSignals.CashChanged:Fire(cashValue.Value)
		end)
		return
	end

	local function onPlayerAdded(player: Player)
		EconomyService.SetCash(player, GameSettings.StartMoney)
		updateLeaderstats(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function EconomyService.AddCash(player: Player, amount: number)
	if not playerCash[player.UserId] then
		return
	end

	playerCash[player.UserId] += amount

	updateLeaderstats(player)
end

function EconomyService.AddCashToAll(amount: number)
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.AddCash(player, amount)
	end
end

function EconomyService.AddKillCash(enemyMaxHealth: number)
	EconomyService.AddCashToAll(math.round(1.3 * math.pow(enemyMaxHealth, 0.525)))
end

function EconomyService.SubtractCash(player: Player, amount: number, isForce: boolean | nil)
	if not playerCash[player.UserId] then
		return
	end

	if not isForce then
		if playerCash[player.UserId] < amount then
			return
		end
	end

	playerCash[player.UserId] -= amount

	updateLeaderstats(player)
end

function EconomyService.SetCash(player: Player, value: number | nil)
	local toValue = value or 0
	playerCash[player.UserId] = toValue

	updateLeaderstats(player)
end

function EconomyService.SetCashToAll(value: number | nil)
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.SetCash(player, value)
	end
end

function EconomyService.GetCash(player): number
	if RunService:IsClient() then
		return player:WaitForChild("leaderstats").Cash.Value
	end

	return playerCash[player.UserId]
end

return EconomyService
