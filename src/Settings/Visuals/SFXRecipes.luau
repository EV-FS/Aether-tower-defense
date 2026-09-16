local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type Options = {
	Type: "2D" | "3D",

	Delay: number?,
	Volume: number?,
	At: string?,
}

export type Step = {
	Sound: string,
	Type: "2D" | "3D",

	Delay: number?,
	Volume: number?,
	At: string?,
}

local function newStep(sound: string, options: Options): Step
	return TableUtils.DeepFreeze({
		Sound = sound,
		Type = options.Type,

		Delay = options.Delay,
		Volume = options.Volume,
		At = options.At,
	})
end

return TableUtils.DeepFreeze({
	["TowerShared"] = {
		Place_Common = {
			newStep("UI/Common", { Type = "3D", At = "Source" }),
		},
		Place_Rare = {
			newStep("UI/Rare", { Type = "3D", At = "Source" }),
		},
		Place_Epic = {
			newStep("UI/Epic", { Type = "3D", At = "Source" }),
		},
		Place_Legendary = {
			newStep("UI/Legendary", { Type = "3D", At = "Source" }),
		},
		Place_Mythic = {
			newStep("UI/Mythic", { Type = "3D", At = "Source" }),
		},
		Place_Absolute = {
			newStep("UI/Absolute", { Type = "3D", At = "Source" }),
		},

		Upgrade_Common = {
			newStep("UI/Common", { Type = "3D", At = "Source" }),
		},
		Upgrade_Rare = {
			newStep("UI/Rare", { Type = "3D", At = "Source" }),
		},
		Upgrade_Epic = {
			newStep("UI/Epic", { Type = "3D", At = "Source" }),
		},
		Upgrade_Legendary = {
			newStep("UI/Legendary", { Type = "3D", At = "Source" }),
		},
		Upgrade_Mythic = {
			newStep("UI/Mythic", { Type = "3D", At = "Source" }),
		},
		Upgrade_Absolute = {
			newStep("UI/Absolute", { Type = "3D", At = "Source" }),
		},
	},

	["Knight"] = {
		AttackCombo1End = {
			[0] = {
				newStep("Towers/Knight/KnightA1", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo2End = {
			[0] = {
				newStep("Towers/Knight/KnightA2", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo3End = {
			[0] = {
				newStep("Towers/Knight/KnightA3", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo4End = {
			[0] = {
				newStep("Towers/Knight/KnightA4", { Type = "3D", At = "Source" }),
			},
		},
	},
	["Galahad"] = {
		AttackCombo1Start = {
			[0] = {
				newStep("Towers/Galahad/GalahadA1", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo2Start = {
			[0] = {
				newStep("Towers/Galahad/GalahadA2", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo3Start = {
			[0] = {
				newStep("Towers/Galahad/GalahadA3", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo4Start = {
			[0] = {
				newStep("Towers/Galahad/GalahadA4", { Type = "3D", At = "Source" }),
			},
		},
	},
	["Kitsune Samurai"] = {
		AttackCombo1Start = {
			[0] = {
				newStep("Towers/Kitsune Samurai/KitsuneA1", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo2Start = {
			[0] = {
				newStep("Towers/Kitsune Samurai/KitsuneA2", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo3Start = {
			[0] = {
				newStep("Towers/Kitsune Samurai/KitsuneA3", { Type = "3D", At = "Source" }),
			},
		},
		AttackCombo4Start = {
			[0] = {
				newStep("Towers/Kitsune Samurai/KitsuneA4", { Type = "3D", At = "Source" }),
			},
		},
		AttackStart = {
			[2] = {
				newStep("Towers/Kitsune Samurai/KitsuneLv2", { Type = "3D", At = "Source" }),
			},
			[4] = {
				newStep("Towers/Kitsune Samurai/CloneAttack", { Type = "3D", At = "Source" }),
			},
		},
	},
	["Dragon Slayer"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/Dragon Slayer/DragonSlayerA1", { Type = "3D", At = "Source" }),
			},
		},
	},
	["Ranger Super Tower"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/Ranger Super Tower/A1", { Type = "3D", At = "Source" }),
			},
		},
	},
	["dingding"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/dingding/dingdingattack", { Type = "3D", At = "Source" }),
			},
		},
	},
})
