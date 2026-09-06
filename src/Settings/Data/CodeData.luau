local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

-- Code names are matched without case sensitivity and ignore surrounding spaces.
-- StartsAt and ExpiresAt are optional Unix timestamps.
return TableUtils.DeepFreeze({
	WELCOME = {
		Enabled = true,
		Rewards = {
			Coins = 500,
			Gems = 25,
		},
	},
})
