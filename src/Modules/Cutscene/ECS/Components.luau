local Matter = require(game:GetService("ReplicatedStorage").Packages.Matter)

return {
	Session = Matter.component("CutsceneSession"),
	CameraTarget = Matter.component("CutsceneCameraTarget"),
	FOVTrack = Matter.component("CutsceneFOVTrack"),
	VFXTrack = Matter.component("CutsceneVFXTrack"),
	AudioTrack = Matter.component("CutsceneAudioTrack"),
}
