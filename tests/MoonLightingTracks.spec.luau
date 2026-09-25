-- Studio: pass ReplicatedStorage.Shared.Modules.Cutscene.MoonLightingTracks,
-- ScreenEffects, and Settings.Data.CutsceneTracks.DragonSlayerMoonLighting.
return function(MoonLightingTracks, ScreenEffects, dragonExport)
	local config = MoonLightingTracks.ColorCorrection(dragonExport, 7)
	assert(config.Name == "VFX" and config.EndFrame == 1526 and config.FPS == 60,
		"Moon target or authored FPS was lost")
	assert(#config.Tracks.Contrast.Sequence == 15 and #config.Tracks.Saturation.Sequence == 15,
		"Moon keyframes were lost")
	local view = ScreenEffects.new(config)
	local effect = view.Effect
	local function near(actual, expected)
		assert(math.abs(actual - expected) < 1e-5, `Expected {expected}, got {actual}`)
	end
	local ok, err = xpcall(function()
		assert(effect.Name == "VFX" and not effect.Enabled, "Moon effect mounted incorrectly")
		view:ApplyFrame(0, true)
		near(effect.Brightness, 0)
		near(effect.Contrast, 0)
		near(effect.Saturation, 0)
		view:ApplyFrame(36.5, true)
		near(effect.Contrast, 2)
		near(effect.Saturation, 3)
		view:ApplyFrame(40, true)
		near(effect.Contrast, 4)
		near(effect.Saturation, 6)
		view:ApplyFrame(418, true)
		near(effect.Contrast, 12)
		near(effect.Saturation, 3)
		view:ApplyFrame(1234, true)
		near(effect.Contrast, 12)
		view:ApplyFrame(1526, true)
		near(effect.Contrast, 0)
		near(effect.Saturation, 0)
		view:ApplyFrame(418, false)
		assert(not effect.Enabled, "Inactive preparation must hide the effect")
		assert(dragonExport.Items[7].Properties.Contrast.Keyframes[1].Frame == 33,
			"Source export was mutated")
	end, debug.traceback)
	view:Destroy()
	if not ok then error(err, 0) end
	assert(effect.Parent == nil, "Moon effect survived cleanup")
	print("PASS: Moon DragonSlayer lighting follows exported keys and cleans up")
end
