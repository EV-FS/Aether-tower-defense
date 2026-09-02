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

	--/Units

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
