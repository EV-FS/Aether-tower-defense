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
		At = options.At,
	})
end

return TableUtils.DeepFreeze({
	["Bacon"] = {
		AttackEnd = {
			[0] = {
				newStep("Towers/Shared/Punch", { Type = "3D", At = "Target" }),
			},
		},
	},
	["Dummy"] = {
		AttackEnd = {
			[0] = {
				newStep("Towers/Shared/Punch", { Type = "3D", At = "Target" }),
			},
		},
	},
	["Noob"] = {
		AttackEnd = {
			[0] = {
				newStep("Towers/Shared/Punch", { Type = "3D", At = "Target" }),
			},
		},
	},

	["Minigunner Dummy"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/Minigunner Dummy/Fire", { Type = "3D", At = "Source" }),
			},
		},
	},
	["Hacker"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/Hacker/Slash", { Type = "3D", At = "Source" }),
			},
		},
		Summon = {
			[0] = {
				newStep("Towers/Hacker/Hacked", { Type = "3D", At = "Target" }),
			},
		},
	},
	["Mecha Demian"] = {
		AttackStart = {
			[0] = {
				newStep("Towers/Mecha Demian/Lunge", { Type = "3D", At = "Source" }),
			},
			[3] = {
				newStep("Towers/Mecha Demian/Charge", { Type = "3D", At = "Source" }),
			},
		},
		AttackEnd = {
			[3] = {
				newStep("Towers/Mecha Demian/Explosion", { Type = "3D", At = "Target" }),
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
})
