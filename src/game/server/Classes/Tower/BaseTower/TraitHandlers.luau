local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	DamageMultiflier = function(self, val)
		if not self.Stats.Damage then
			return
		end

		self.Stats.Damage *= 1 + val
	end,
	RangeMultiflier = function(self, val)
		if not self.Stats.Range then
			return
		end

		self.Stats.Range *= 1 + val
	end,
	CooldownMultiflier = function(self, val)
		if not self.Stats.Cooldown then
			return
		end

		self.Stats.Cooldown *= 1 - val
	end,
})
