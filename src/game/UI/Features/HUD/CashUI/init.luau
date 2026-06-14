--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local CashFrame = require(script.Components.CashFrame)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EconomyService

local source = Vide.source
local spring = Vide.spring

--/UI Variables
local playerCash = source(0)

-------------------------------------------------
--// CashUI
-------------------------------------------------
local CashUI = {}

function CashUI.RenderUI()
	local animatedCash = spring(playerCash, 0.1, 1)

	return CashFrame({ Cash = animatedCash })
end

function CashUI.Init()
	EconomyService = ServiceRegistry:GetService("EconomyService")
end

function CashUI.Start()
	playerCash(EconomyService.GetCash(Players.LocalPlayer))

	ClientSignals.CashChanged:Connect(function(val: number)
		playerCash(val)
	end)
end

return CashUI
