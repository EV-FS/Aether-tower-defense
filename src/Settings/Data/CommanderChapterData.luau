return {
	Map = "Chapter 1",
	MinimumReadTime = 2.5,
	MaximumReadTime = 7,
	ReadingCharactersPerSecond = 18,
	WarningColor = Color3.fromRGB(244, 142, 98),
	Layout = {
		PanelPosition = UDim2.fromScale(0.5, 0.78),
		PanelSize = UDim2.fromScale(0.32, 0.2),
		PortraitPosition = UDim2.fromScale(0.18, 0.2),
		PortraitSize = UDim2.fromScale(0.32, 0.9),
	},
	Briefing = {
		Id = "Briefing",
		Caption = "CHAPTER 1 / COMMS ONLINE",
		Priority = 1,
		Lines = { "Commander here. Cover the route, and keep some cash ready for upgrades. I'll stay on comms." },
	},
	Waves = {
		[3] = {
			Id = "Wave2",
			Caption = "WAVE 2 PASSED",
			Priority = 1,
			Lines = { "Good start. Watch where enemies get through, then strengthen those gaps." },
		},
		[6] = {
			Id = "Wave5",
			Caption = "WAVE 5 PASSED",
			Priority = 1,
			Lines = { "You're holding steady. A timely upgrade can help more than spreading your squad too thin." },
		},
		[11] = {
			Id = "Wave10",
			Caption = "WAVE 10 PASSED",
			Priority = 1,
			Lines = { "Ten waves down. Check your coverage and save a reserve for the next push." },
		},
		[16] = {
			Id = "Wave15",
			Caption = "WAVE 15 PASSED",
			Priority = 1,
			Lines = { "Stay focused. Keep your strongest units upgraded and leave no weak spots in the line." },
		},
		[26] = {
			Id = "Wave25",
			Caption = "WAVE 25 PASSED",
			Priority = 1,
			Lines = { "Good endurance. Review your targeting before the next group reaches your defenses." },
		},
		[36] = {
			Id = "Wave35",
			Caption = "WAVE 35 PASSED",
			Priority = 1,
			Lines = { "You've come a long way. Keep your formation tight and make every upgrade count." },
		},
	},
	FinalWave = {
		Id = "FinalWave",
		Caption = "FINAL WAVE / HOLD THE LINE",
		Priority = 2,
		Lines = { "This is the final wave. Commit your reserves and hold the line!" },
	},
	BossContact = {
		Id = "BossContact",
		Caption = "WARNING / BOSS CONTACT",
		Priority = 3,
		Lines = { "Boss contact confirmed. Check your targeting and keep the rest of the route covered!" },
	},
}
