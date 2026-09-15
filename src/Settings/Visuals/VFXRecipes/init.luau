local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Steps = require(script.Steps)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--[ 예시 ]--
--[[
{
	["Source Name"] = {
		["Attack"] = {
			[0(Level)] = {
				Steps.Emit("Towers/TestTower/Emit", {
					Delay = 0.2,
					Lifetime = 3,

					At = ("Source" | "Target"),
				}),
				Steps.Projectile("Towers/TestTower/Projectile", {
					Delay = 0.5,
					Lifetime = 3,

					From = "Source.GunModel.Muzzle",
					To = "Target",

					Speed = 5555,
					OnHit = Steps.Emit(...)
				}),
				Steps.Beam("Towers/TestTower/Beam", {
					Delay = 1.5,

					From = "Source.GunModel.Muzzle",
					To = "Target",
				}),
			},
			[1] = {
				...
			}
		},
		["SecondAttack"] = {
			...
		}	
	}
}
--]]

return TableUtils.DeepFreeze({
	--/Emotes
	["CameraFlash"] = {
		Emote = {
			Steps.Emit("Emote/CameraFlash", { At = "Source.EmoteProps.Camera" }),
		},
	},

	--/Towers
	["TowerShared"] = {
		Place_Common = {
			Steps.Emit("Towers/Shared/CommonPlace", { At = "Source.@Ground" }),
		},
		Place_Rare = {
			Steps.Emit("Towers/Shared/RarePlace", { At = "Source.@Ground" }),
		},
		Place_Epic = {
			Steps.Emit("Towers/Shared/EpicPlace", { At = "Source.@Ground" }),
		},
		Place_Legendary = {
			Steps.Emit("Towers/Shared/LegendaryPlace", { At = "Source.@Ground" }),
		},
		Place_Mythic = {
			Steps.Emit("Towers/Shared/MythicPlace", { At = "Source.@Ground" }),
		},
		Place_Absolute = {
			Steps.Emit("Towers/Shared/AbsolutePlace", { At = "Source.@Ground" }),
		},

		Upgrade_Common = {
			Steps.Emit("Towers/Shared/CommonUpgrade", { At = "Source.@Ground" }),
		},
		Upgrade_Rare = {
			Steps.Emit("Towers/Shared/RareUpgrade", { At = "Source.@Ground" }),
		},
		Upgrade_Epic = {
			Steps.Emit("Towers/Shared/EpicUpgrade", { At = "Source.@Ground" }),
		},
		Upgrade_Legendary = {
			Steps.Emit("Towers/Shared/LegendaryUpgrade", { At = "Source.@Ground" }),
		},
		Upgrade_Mythic = {
			Steps.Emit("Towers/Shared/MythicUpgrade", { At = "Source.@Ground" }),
		},
		Upgrade_Absolute = {
			Steps.Emit("Towers/Shared/AbsoluteUpgrade", { At = "Source.@Ground" }),
		},

		Sell = {
			Steps.Emit("Towers/Shared/Sell", { At = "Source.@Ground" }),
		},
	},

	--/Towers
	["Fighter"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/Hit2", { At = "Target" }),
			},
			[2] = {
				Steps.Emit("Towers/Shared/BlueHit2", { At = "Target" }),
			},
		},
	},
	["Knight"] = {
		AttackCombo1End = {
			[0] = {
				Steps.Emit("Towers/Knight/gisa1", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo2End = {
			[0] = {
				Steps.Emit("Towers/Knight/gisa2", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo3End = {
			[0] = {
				Steps.Emit("Towers/Knight/gisa3", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo4End = {
			[0] = {
				Steps.Emit("Towers/Knight/gisa4", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo5End = {
			[0] = {
				Steps.Emit("Towers/Knight/gisa5", { Lifetime = 3, At = "Source" }),
			},
		},
	},
	["Galahad"] = {
		AttackCombo1End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S1", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo2End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S2", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo3End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S3", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo4End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S4", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackStart = {
			[3] = {
				Steps.Emit("Towers/Galahad/1", { Lifetime = 3, Delay = 0.55, LockToSource = true, At = "Source" }),
				Steps.Emit("Towers/Galahad/2", { Lifetime = 3, Delay = 0.966, LockToSource = true, At = "Source" }),
				Steps.Emit("Towers/Galahad/3", { Lifetime = 3, Delay = 1.733, LockToSource = true, At = "Source" }),
			},
		},
	},
	["Kitsune Samurai"] = {
		AttackCombo1End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S1", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo2End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S2", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo3End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S3", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackCombo4End = {
			[0] = {
				Steps.Emit("Towers/Galahad/S4", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackStart = {
			[2] = {
				Steps.Emit("Towers/Kitsune Samurai/E1", { Lifetime = 3, Delay = 0.45, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/E2", { Lifetime = 3, Delay = 0.717, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/E3", { Lifetime = 3, Delay = 1.417, At = "Source" }),
			},
			[4] = {
				Steps.Custom("KitsuneCloneAttack", { Lifetime = 3, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK1", { Lifetime = 3, Delay = 0.283, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK2", { Lifetime = 3, Delay = 0.75, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK3", { Lifetime = 3, Delay = 0.816, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK4", { Lifetime = 3, Delay = 0.983, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK5", { Lifetime = 3, Delay = 2.166, At = "Source" }),
				Steps.Emit("Towers/Kitsune Samurai/CATK6", { Lifetime = 3, Delay = 2.35, At = "Source" }),
			},
		},
	},
	["Dragon Slayer"] = {
		AttackStart = {
			[0] = {
				Steps.Emit("Towers/Dragon Slayer/0", { Lifetime = 3, Delay = 0.3, At = "Source" }),
			},
		},
		AttackHit1 = {
			[0] = {
				Steps.Emit("Towers/Dragon Slayer/SlashzERO", { Lifetime = 3, At = "Source" }),
			},
		},
		AttackHit2 = {
			[0] = {
				Steps.Emit("Towers/Dragon Slayer/bbb1", { Lifetime = 3, At = "Source" }),
			},
		},
	},
})
