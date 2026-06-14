local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local BossHealthBar = require(script.Components.BossHealthBar)

local create = Vide.create
local source = Vide.source
local indexes = Vide.indexes

local BossBarUI = {}
local bosses = source({})

function BossBarUI.RenderUI()
	return create("Frame")({
		Name = "BossHealthbar",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.1, 7),
		Size = UDim2.fromScale(1, 0.125),

		create("UIListLayout")({
			Name = "UIListLayout",
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.2, 0),
		}),

		indexes(bosses, function(bossSource, _)
			return BossHealthBar({
				Name = function()
					return bossSource().Name
				end,
				Health = function()
					return bossSource().Health()
				end,
				MaxHealth = function()
					return bossSource().MaxHealth
				end,
			})
		end),
	})
end

function BossBarUI.Init() end

function BossBarUI.Start()
	ClientSignals.BossSpawned:Connect(function(enemy)
		local currentBosses = table.clone(bosses())

		local healthSource = source(enemy.Health)

		table.insert(currentBosses, {
			Id = enemy.Id,
			Name = enemy.Name,
			Health = healthSource,
			MaxHealth = enemy.MaxHealth,
		})

		bosses(currentBosses)
	end)

	ClientSignals.BossDamaged:Connect(function(enemyId, health)
		local currentBosses = bosses()
		for _, boss in ipairs(currentBosses) do
			if boss.Id == enemyId then
				boss.Health(health)
				break
			end
		end
	end)

	ClientSignals.BossDestroyed:Connect(function(enemyId)
		local currentBosses = table.clone(bosses())
		for i, boss in ipairs(currentBosses) do
			if boss.Id == enemyId then
				table.remove(currentBosses, i)
				break
			end
		end
		bosses(currentBosses)
	end)
end

return BossBarUI
