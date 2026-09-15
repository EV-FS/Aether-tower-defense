-- Settings/Data/TowerData/TowerDescriptions.luau
-- Passive ability descriptions for each tower (English for translation)

local TowerDescriptions = {
	["Hacker"] = {
		PassiveName = "Infection",
		PassiveIcon = "rbxassetid://76888510287982",
		PassiveDescription = "When this tower kills an enemy, there is a chance to hack the defeated enemy and convert it into an allied unit that fights alongside your towers.",
		PassiveDetails = {
			{ Label = "Hacking Chance", Key = "HackingChance", Suffix = "%" },
		},
	},
	["Wizard"] = {
		PassiveName = "Elemental Magic",
		PassiveIcon = "rbxassetid://135870452733899",
		PassiveDescription = "Attacks apply a slow effect to enemies. At higher levels, spells gain a chance to stun or knock back targets on hit.",
		PassiveDetails = {
			{ Label = "Slow Amount", Key = "Slow", Suffix = "%" },
			{ Label = "Slow Duration", Key = "SlowDuration", Suffix = "s" },
			{ Label = "Stun Chance", Key = "StunChance", Suffix = "%" },
			{ Label = "Stun Duration", Key = "StunDuration", Suffix = "s" },
			{ Label = "Knockback Chance", Key = "KnockbackChance", Suffix = "%" },
			{ Label = "Knockback Distance", Key = "KnockbackDistance", Suffix = " studs" },
		},
	},
}

return TowerDescriptions
