local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local UnitData = require(ReplicatedStorage.Settings.Data.UnitData)

return TableUtils.DeepFreeze({
	IncomeMultiplier = function(self, val)
		for _, passive in self.Stats.Passives or {} do
			if (passive.Type == "CashOnHit" or passive.Type == "CashPerSecond") and passive.Amount then
				passive.Amount *= 1 + val
			end
		end
		if self.Stats.Income then return "Income", val end
	end,
	SummonHealthMultiplier = function(self, val)
		-- Each recalculation starts from a fresh deep copy, including upgrade stats.
		local summons = self.Stats.Summons or (self.Stats.SummonUnit and { self.Stats }) or {}
		for _, config in summons do
			local base = UnitData.ByName[config.SummonUnit]
			config.UnitStats = config.UnitStats or {}
			local health = config.UnitStats.MaxHealth or (base and base.MaxHealth)
			if health then config.UnitStats.MaxHealth = health * (1 + val) end
		end
	end,
	DamageMultiflier = function(self, val)
		if not self.Stats.Damage then
			return
		end

		return "Damage", val
	end,
	RangeMultiflier = function(self, val)
		if not self.Stats.Range then
			return
		end

		return "Range", val
	end,
	CooldownMultiflier = function(self, val)
		if not self.Stats.Cooldown then
			return
		end

		return "Cooldown", -val
	end,
})
