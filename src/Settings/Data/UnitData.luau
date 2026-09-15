local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawUnitData = {
	["Knight Noob"] = {
		Index = 1,
		WalkSpeed = 3,
		MaxHealth = 400,
		Stats = {
			Damage = 50,
			Cooldown = 1,
			Range = 5,
			StopWhenAttacking = true,
			AttackDelay = 0.35,
			AttackType = "Single",
		},
	},
	["Archer Noob"] = {
		Index = 2,
		WalkSpeed = 3,
		MaxHealth = 400,
		Stats = {
			Damage = 200,
			Cooldown = 1.5,
			Range = 12,
			StopWhenAttacking = true,
			AttackDelay = 0.35,
			AttackType = "Single",
		},
	},
}

local UnitData = {
	ByName = RawUnitData,
	ByIndex = {},
}

for name, data in pairs(RawUnitData) do
	data.Name = name

	UnitData.ByIndex[data.Index] = data
end

return TableUtils.DeepFreeze(UnitData)
