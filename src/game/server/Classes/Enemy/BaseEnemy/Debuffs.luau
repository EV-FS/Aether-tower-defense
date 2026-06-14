local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	["Burn"] = {
		Priority = 1,
		OnApplyStats = function(_, power, dotCollection)
			dotCollection.Burn = power
		end,
	},
	["Bleed"] = {
		Priority = 2,
		OnApplyStats = function(_, power, dotCollection)
			dotCollection.Bleed = power
		end,
	},
	["Slow"] = {
		Priority = 10,
		OnApplyStats = function(enemy, power)
			enemy.WalkSpeed = enemy.BaseSpeed * math.max(0, (100 - power) / 100)
		end,
	},

	["Stun"] = {
		Priority = 20,
		IgnoreBoss = true,
		OnApplyStats = function(enemy)
			enemy.WalkSpeed = 0
		end,
	},

	["Fear"] = {
		Priority = 30,
		IgnoreBoss = true,
		OnApplyStats = function(enemy)
			enemy.WalkSpeed = enemy.BaseSpeed
			enemy.MoveDirection = -1
		end,
	},
})
