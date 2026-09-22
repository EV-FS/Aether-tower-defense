local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
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
