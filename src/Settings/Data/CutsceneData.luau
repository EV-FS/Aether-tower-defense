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

export type CutsceneInfo = {
	ScenePath: { string },
	Animations: { [string]: number },
	Camera: CameraConfig,
	MaxDuration: number?,
	Audio: { SoundId: number, Volume: number? }?,
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
	RaidIntro = {
		ScenePath = { "Raid", "Intro", "Workspace" },
		Animations = {
			PlayerRig = 117994110297108,
			RaidBoss = 116563833173937,
			Cam = 92652239085170,
		},
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
		VFX = {
			Events = require(script.Parent.CutsceneTracks.RaidIntroVFX),
			EndFrame = 840,
		},
	},
}) :: CutsceneData
