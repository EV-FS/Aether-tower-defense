local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

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
	Ease: { Type: string?, Params: { [string]: string | number }? }?,
}

export type ScreenTrack = { ScreenKey } | { Default: (number | boolean | Color3)?, Sequence: { ScreenKey } }

export type CutsceneInfo = {
	ScenePath: { string },
	UseWorkspaceScene: boolean?,
	FocusMode: boolean?,
	Animations: { [string]: number },
	Actors: { [string]: "Self" | "Friend" }?,
	Lifecycle: { FastMount: boolean?, FastCleanup: boolean? }?,
	Camera: CameraConfig,
	MaxDuration: number?,
	FPS: number?,
	Audio: { SoundId: number, Volume: number? }?,
	ScreenEffects: {
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
