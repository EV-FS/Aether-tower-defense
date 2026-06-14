local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	--/SelectedTower
	DamageIcon = "rbxassetid://7485051715",
	CooldownIcon = "rbxassetid://11726391094",
	RangeIcon = "rbxassetid://103285003019046",

	--/BaseUI
	ShakeIntensity = 60, --기지 체력 감소 시 체력바가 흔들리는 정도

	--/ButtonEffects
	PressedScale = 0.85,
	Speed = 35,
	Damping = 0.65,
})
