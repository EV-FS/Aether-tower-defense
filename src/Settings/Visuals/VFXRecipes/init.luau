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

	["Bacon"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/Hit", { At = "Target" }),
			},
		},
	},
	["Dummy"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/Hit", { At = "Target" }),
			},
		},
	},
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
	["Noob"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/Hit", { At = "Target" }),
			},
		},
	},
	["Batter Bacon"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/Hit", { At = "Target" }),
			},
		},
	},
	["Gunner Dummy"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/MuzzleFlash", { Lifetime = 1, LockToSource = true, At = "Source.Muzzle" }),
				Steps.Projectile("Towers/Shared/Bullet", {
					From = "Source.Muzzle",
					To = "Target",

					Lifetime = 0.3,

					Speed = 400,
				}),
			},
		},
	},
	["Minigunner Dummy"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Shared/MuzzleFlash", { Lifetime = 0.1, LockToSource = true, At = "Source.Muzzle" }),
				Steps.Projectile("Towers/Shared/Bullet", {
					From = "Source.Muzzle",
					To = "Target",

					Delay = 0.02,
					Lifetime = 0.08,

					Speed = 800,
				}),
			},
		},
	},
	["Lancer Dummy"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Lancer Dummy/Lance", { At = "Source" }),
			},
		},
	},
	["Mecha Demian"] = {
		OnSpawn = {
			[0] = {
				Steps.Emit("Towers/Mecha Demian/demianSpawnVFX", { At = "Source.demianSpawnVFX" }),
			},
		},
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Mecha Demian/Mecha Lunge", { Lifetime = 3, At = "Source" }),
			},
			[3] = {
				Steps.Emit("Towers/Mecha Demian/Impact", { Lifetime = 3, At = "Target.@Ground" }),
			},
		},
	},
	["Mecha Fist"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Mecha Fist/ZoomPunch", { Lifetime = 3, At = "Source.EffectStart" }),
			},
		},
	},
	["Cyborg Dummy"] = {
		OnSpawn = {
			[0] = {
				Steps.Emit("Towers/Cyborg Dummy/SpawnVFX", { At = "Source.SpawnVFX" }),
			},
		},
		AttackStart = {
			[0] = {
				Steps.Projectile("Towers/Cyborg Dummy/Projectile", {
					From = "Source.EffectStart",
					To = "Target",

					Delay = 0.166,

					CurveHeight = 2,
					CurveOffset = 1,
					TravelTime = 0.15,

					OnHit = Steps.Emit("Towers/Cyborg Dummy/OnHit", { At = "Target.@Ground" }),
				}),
			},
			[3] = {
				Steps.Beam("Towers/Cyborg Dummy/Beam", {
					From = "Source.EffectStart",
					To = "Target",
				}),
			},
		},
		SecondaryAttackStart = {
			[3] = {
				Steps.Projectile("Towers/Cyborg Dummy/Projectile", {
					From = "Source.EffectStart",
					To = "Target",

					Delay = 0.25,

					CurveHeight = 5,
					CurveOffset = 5,
					TravelTime = 0.2,

					OnHit = Steps.Emit("Towers/Cyborg Dummy/OnHit", { At = "Target.@Ground" }),
				}),
			},
		},
	},
	["Cowboy Dummy"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Cowboy Dummy/Shot1", { Lifetime = 5, At = "Source" }),
			},
		},
	},
	["Hacker"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Hacker/Slash", { Lifetime = 3, At = "Source" }),
			},
		},
		Summon = {
			[0] = {
				Steps.Custom("Hacked", { At = "Target" }),
			},
		},
	},
	["Bomb"] = {
		AttackStart = {
			[0] = {
				Steps.Projectile("Towers/Bomb/BombProjectile", {
					From = "Source.Muzzle",
					To = "Target",

					Lifetime = 0,

					Delay = 0.866,
					CurveHeight = 3,
					TravelTime = 0.334,

					OnHit = Steps.Emit("Towers/Bomb/Explosion", {
						Lifetime = 3,

						At = "Target.@Ground",
					}),
				}),
			},
		},
	},
	["Poseidon Noob"] = {
		AttackEnd = {
			[0] = {
				Steps.Emit("Towers/Poseidon Noob/Lunge", { Lifetime = 2, At = "Source.Fork" }),
			},
		},
	},
	["Wizard"] = {
		AttackStart = {
			[0] = {
				Steps.Emit("Towers/Wizard/A1", { Lifetime = 3, Delay = 0.45, LockToSource = true, At = "Source" }),
			},
			[3] = {
				Steps.Emit("Towers/Wizard/A2", { Lifetime = 3, Delay = 0.036, LockToSource = true, At = "Source" }),
			},
		},
	},
	["Archer Noob"] = {
		AttackStart = {
			[0] = {
				Steps.Projectile("Units/Archer Noob/Arrow", {
					From = "Source.EffectStart",
					To = "Target",

					Delay = 0.25,

					CurveHeight = 4,
					CurveOffset = 0,
					TravelTime = 0.2,
				}),
			},
		},
	},
})
