--/Service
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local UISettings = require(ReplicatedStorage.Settings.Visuals.UISettings)
local Net = require(ReplicatedStorage.Shared.Net)

--/Fusion
local peek = Fusion.peek

--/UI Elements
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Interface = PlayerGui:WaitForChild("Interface")
local InfoFrame = Interface:WaitForChild("Info")
local HealthBarFrame = InfoFrame:WaitForChild("HealthBar")
local BarFrame: GuiObject = HealthBarFrame:WaitForChild("Bar")
local WhiteBarFrame: GuiObject = HealthBarFrame:WaitForChild("WhiteBar")
local HealthText: TextLabel = HealthBarFrame:WaitForChild("Health")

--/Variables
local uiScope = Fusion.scoped(Fusion)
local MaxHealth = GameSettings.BaseHealth
local ChangedHealth = uiScope:Value(MaxHealth)

local fadeTask = nil

-------------------------------------------------
--// BaseUI
-------------------------------------------------
local BaseUI = {}

function BaseUI.HydrateUI()
	local targetHealthRatio = uiScope:Computed(function(use)
		return use(ChangedHealth) / use(MaxHealth)
	end)

	local whiteRatio = uiScope:Spring(targetHealthRatio, 12, 1)

	local targetTransparency = uiScope:Value(1)
	local fadeSpeed = uiScope:Value(TweenInfo.new(0))
	local smoothTransparency = uiScope:Tween(targetTransparency, fadeSpeed)

	uiScope:Hydrate(BarFrame)({
		Size = uiScope:Computed(function(use)
			return UDim2.fromScale(use(targetHealthRatio), 1)
		end),
	})

	uiScope:Hydrate(WhiteBarFrame)({
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = uiScope:Computed(function(use)
			return use(smoothTransparency)
		end),
		Size = uiScope:Computed(function(use)
			return UDim2.fromScale(use(whiteRatio), 1)
		end),
	})

	uiScope:Hydrate(HealthText)({
		Text = uiScope:Computed(function(use)
			return `{use(ChangedHealth)}/{use(MaxHealth)}`
		end),
	})

	local shakeOffset = uiScope:Value(Vector2.new(0, 0))
	local smoothShake = uiScope:Spring(shakeOffset, 80, 0.3)

	uiScope:Hydrate(HealthBarFrame)({
		Position = uiScope:Computed(function(use)
			local offset = use(smoothShake)
			return UDim2.new(0, offset.X, 0.029, offset.Y)
		end),
	})

	local previousHealth = peek(ChangedHealth)
	uiScope:Observer(ChangedHealth):onChange(function()
		local currentHp = peek(ChangedHealth)
		local damage = previousHealth - currentHp

		if damage > 0 then
			local intensity = math.clamp(damage / peek(MaxHealth), 0, 1) * UISettings.ShakeIntensity

			shakeOffset:set(Vector2.new(math.max(intensity, 5), 0))
			task.delay(0.05, function()
				shakeOffset:set(Vector2.new(0, 0))
			end)

			fadeSpeed:set(TweenInfo.new(0))
			targetTransparency:set(0.15)

			if fadeTask then
				task.cancel(fadeTask)
			end

			fadeTask = task.delay(0.05, function()
				fadeSpeed:set(TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
				targetTransparency:set(1)
			end)
		end

		previousHealth = currentHp
	end)
end

function BaseUI.Init()
	BaseUI.HydrateUI()
end

function BaseUI.Start()
	Net.BaseService.BaseHealthChanged.On(function(changed)
		ChangedHealth:set(math.max(changed, 0))
	end)
end

return BaseUI
