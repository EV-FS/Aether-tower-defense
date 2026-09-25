local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local dragonMoonLighting = require(ReplicatedStorage.Shared.Modules.Cutscene.MoonLightingTracks).ColorCorrection(
	require(script.Parent.CutsceneTracks.DragonSlayerMoonLighting), 7
)

export type CameraConfig = {
	Model: string,
	Part: string,
	FOV: {
		Samples: { [number]: number },
		FPS: number?,
		Cuts: { [number]: boolean }?,
	}?,
}

export type ScreenKey = {
	Frame: number,
	Value: number | boolean | Color3,
	Ease: (string | EnumItem | {
		Type: (string | EnumItem)?,
		Style: (string | EnumItem)?,
		EasingStyle: (string | EnumItem)?,
		Direction: (string | EnumItem)?,
		EasingDirection: (string | EnumItem)?,
		Params: { [string]: any }?,
	})?,
}

export type ScreenTrack = { ScreenKey } | { Default: (number | boolean | Color3)?, Sequence: { ScreenKey } }

export type CutsceneInfo = {
	ScenePath: { string },
	SceneTransform: CFrame?,
	PreloadScene: boolean?,
	UseWorkspaceScene: boolean?,
	FocusMode: boolean?,
	Animations: { [string]: number },
	Actors: { [string]: "Self" | "Friend" }?,
	Lifecycle: { FastMount: boolean?, FastCleanup: boolean? }?,
	Camera: CameraConfig,
	MaxDuration: number?,
	FPS: number?,
	Audio: { SoundId: number, Volume: number? }?,
	Presentation: { ReadyHold: number, BlackHold: number, ReturnHold: number, FadeIn: number, FadeOut: number, ExitFOVScale: number?, PreloadTimeout: number }?,
	Lighting: {
		Properties: { [string]: any },
		Children: { { ClassName: string, Name: string, Properties: { [string]: any } } },
	}?,
	ScreenEffects: {
		Name: string?,
		Tracks: { [string]: ScreenTrack },
		EndFrame: number,
		FPS: number?,
	}?,
	ImpactFrames: {
		Events: { [number]: number | boolean },
		EndFrame: number,
		FPS: number?,
		PersistentImage: { ImageId: number, ImageTransparency: number? }?,
	}?,
	VFX: {
		Events: { [number]: { Emit: { { string } }?, AbsoluteEmit: { { string } }? } },
		EndFrame: number,
		FPS: number?,
	}?,
}

export type CutsceneData = {
	[string]: CutsceneInfo,
}

return TableUtils.DeepFreeze({
	Summon = {
		UseWorkspaceScene = true,
		FocusMode = true,
		ScenePath = {},
		ScreenEffects = {
			Tracks = require(script.Parent.CutsceneTracks.SummonScreen),
			EndFrame = 300,
			FPS = 60,
		},
		Animations = {
			Cam = 114738772563001,
			Bookrig = 108276115487738,
			["Summon NPC"] = 90899610441522,
		},
		Camera = {
			Model = "Cam",
			Part = "CamPart",
			FOV = {
				Samples = require(script.Parent.CutsceneTracks.SummonFOV),
				FPS = 60,
			},
		},
		FPS = 60,
		MaxDuration = 5,
	},

	DragonSlayer = {
		ScenePath = { "DragonSlayer_Cutscenes" },
		Presentation = { ReadyHold = 0, BlackHold = 0.12, ReturnHold = 1, FadeIn = 0.58, FadeOut = 0.55, ExitFOVScale = 0.92, PreloadTimeout = 35 },
		Lighting = require(script.Parent.CutsceneLighting.DragonSlayer),
		Audio = { SoundId = 129406672557005, Volume = 1 },
		ScreenEffects = dragonMoonLighting,
		VFX = {
			Events = require(script.Parent.CutsceneTracks.DragonSlayerVFX),
			EndFrame = 1526,
			FPS = 60,
		},
		SceneTransform = CFrame.new(10000, 0, 0),
		PreloadScene = false,
		FocusMode = true,
		Animations = {
			Cam = 87879187364917,
			PlayerRig = 121655745862741,
			OrbFracture = 112498144790669,
			DragonSlayer = 77587160779056,
		},
		Actors = { PlayerRig = "Self" },
		Camera = {
			Model = "Cam",
			Part = "CamPart",
			FOV = {
				Samples = require(script.Parent.CutsceneTracks.DragonSlayerFOV),
				FPS = dragonMoonLighting.FPS,
			},
		},
	},

	RaidIntro = {
		Lifecycle = { FastMount = true, FastCleanup = true },
		ScenePath = { "Raid", "Intro", "Workspace" },
		Animations = {
			PlayerRig = 123376886571527,
			PlayerFriendRig = 117994110297108,
			RaidBoss = 116563833173937,
			Cam = 92652239085170,
		},
		Actors = { PlayerRig = "Self", PlayerFriendRig = "Friend" },
		Camera = {
			Model = "Cam",
			Part = "CamPart",
			FOV = {
				Samples = require(script.Parent.CutsceneTracks.RaidIntroFOV),
				-- Omit FPS to fit the exported frames to the camera animation length.
			},
		},
		MaxDuration = 60,
		Audio = { SoundId = 102459673372986, Volume = 1 },
		ScreenEffects = {
			Tracks = require(script.Parent.CutsceneTracks.RaidIntroScreen),
			EndFrame = 840,
			-- Match FOV/VFX/impact timing. Set FPS = 60 only for fixed-rate playback.
		},
		ImpactFrames = {
			Events = require(script.Parent.CutsceneTracks.RaidIntroImpact),
			EndFrame = 840,
			PersistentImage = { ImageId = 228322184, ImageTransparency = 0.12 },
		},
		VFX = {
			Events = require(script.Parent.CutsceneTracks.RaidIntroVFX),
			EndFrame = 840,
		},
	},
}) :: CutsceneData
