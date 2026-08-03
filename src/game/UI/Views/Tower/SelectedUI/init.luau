-- UI/Features/Tower/SelectedUI/init.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local SelectedFrame = require(script.Components.SelectedFrame)

local EconomyService
local InputService
local SelectedTowerScope

local source = Vide.source

--/Constants
local TARGET_MODES = { "First", "Last", "Strongest", "Weakest", "Closest", "Farthest", "Random" }

--/UI States
local currentTowerId = source(nil)
local currentTowerData = source(nil)
local playerCash = source(0)

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getNextTargetMode(step: number, currentMode: string)
	local currentIndex = table.find(TARGET_MODES, currentMode) or 1
	local nextIndex = (currentIndex + step - 1) % #TARGET_MODES + 1
	return TARGET_MODES[nextIndex]
end

local function changeTarget(step: number)
	local tId = currentTowerId()
	local data = currentTowerData()
	if not (tId and data) then
		return
	end

	local nextMode = getNextTargetMode(step, data.Target or "First")
	ClientSignals.ChangeTargetRequested:Fire(tId, nextMode)
end

local function requestUpgrade()
	local tId = currentTowerId()
	local data = currentTowerData()
	if not tId or not data then
		return
	end

	local config = TowerData.ByName[data.Name]
	local nextLevel = config and config.Stats[data.Level + 1]
	if not nextLevel then
		return
	end

	local cost = nextLevel.Cost or 0
	if playerCash() < cost then
		return
	end

	ClientSignals.UpgradeRequested:Fire(tId)
end

local function requestSell()
	local tId = currentTowerId()
	if not tId then
		return
	end
	ClientSignals.SellRequested:Fire(tId)
end

-------------------------------------------------
--// SelectedUI
-------------------------------------------------
local SelectedUI = {}

function SelectedUI.ShowUI(towerId, towerInfo)
	currentTowerId(towerId)
	currentTowerData(towerInfo)
	if SelectedTowerScope then
		SelectedTowerScope:Enable()
	end
end

function SelectedUI.HideMenu()
	currentTowerId(nil)
	currentTowerData(nil)
	if SelectedTowerScope then
		SelectedTowerScope:Disable()
	end
end

function SelectedUI.Init()
	EconomyService = ServiceRegistry:GetService("EconomyService")
	InputService = ServiceRegistry:GetService("InputService")
end

function SelectedUI.Start()
	playerCash(EconomyService.GetCash(Players.LocalPlayer))

	-- Keyboard Hotkeys (InputService Scopes)
	local iScope = InputService.Scope
	local iAction = InputService.Action
	local iInfo = InputService.Info

	SelectedTowerScope = iScope("SelectedTowerInput", {
		iAction("Upgrade", iInfo({ Enum.KeyCode.E })),
		iAction("Sell", iInfo({ Enum.KeyCode.X, Enum.KeyCode.Backspace })),
		iAction("CycleTarget", iInfo({ Enum.KeyCode.T })),
	}):Disable()

	SelectedTowerScope.Actions.Upgrade.Began:Connect(requestUpgrade)
	SelectedTowerScope.Actions.Sell.Began:Connect(requestSell)
	SelectedTowerScope.Actions.CycleTarget.Began:Connect(function()
		changeTarget(1)
	end)

	-- Network connections
	ClientSignals.CashChanged:Connect(function(newCash)
		playerCash(newCash)
	end)

	ClientSignals.TowerUpdated:Connect(function(updatedId, newData)
		if updatedId == currentTowerId() then
			currentTowerData(newData)
		end
	end)

	ClientSignals.TowerDestroyed:Connect(function(towerId)
		if towerId == currentTowerId() then
			SelectedUI.HideMenu()
		end
	end)

	ClientSignals.TowerSelected:Connect(SelectedUI.ShowUI)
	ClientSignals.TowerUnselected:Connect(SelectedUI.HideMenu)
end

function SelectedUI.RenderUI()
	return SelectedFrame({
		towerId = currentTowerId,
		towerData = currentTowerData,
		playerCash = playerCash,
		OnChangeTarget = changeTarget,
		OnUpgrade = requestUpgrade,
		OnSell = requestSell,
		OnClose = SelectedUI.HideMenu,
	})
end

return SelectedUI
