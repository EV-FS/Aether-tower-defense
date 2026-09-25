-- Run in Studio with ReplicatedStorage.Shared.Modules.Cutscene.LightingSession.
return function(LightingSession)
	local lighting = game:GetService("Lighting")
	local previousBrightness = lighting.Brightness
	local previousClockTime = lighting.ClockTime
	local originalBloom = Instance.new("BloomEffect")
	originalBloom.Name = "LightingSessionTestOriginal"
	originalBloom.Enabled = true
	originalBloom.Parent = lighting
	local session
	local ok, err = xpcall(function()
		session = LightingSession.new({
			Properties = { Brightness = 3, ClockTime = 14.5 },
			Children = {
				{ ClassName = "BloomEffect", Name = "LightingSessionTestCutscene", Properties = {
					Enabled = true, Intensity = 1, Size = 23, Threshold = 2,
				} },
			},
		})
		assert(lighting.Brightness == 3 and lighting.ClockTime == 14.5, "Cutscene lighting was not applied")
		assert(originalBloom.Parent ~= lighting, "Original bloom still affects the cutscene")
		local cutsceneBloom = lighting:FindFirstChild("LightingSessionTestCutscene")
		assert(cutsceneBloom and cutsceneBloom:IsA("BloomEffect"), "Cutscene bloom is missing")
		lighting.ClockTime = 4
		-- Property changed signals may be deferred by Workspace.SignalBehavior.
		game:GetService("RunService").Heartbeat:Wait()
		assert(lighting.ClockTime == 14.5, "External lighting changes must not override the cutscene")
		session:Destroy()
		session:Destroy()
		assert(lighting.Brightness == previousBrightness and lighting.ClockTime == previousClockTime,
			"Original lighting properties were not restored")
		assert(originalBloom.Parent == lighting, "Original bloom was not restored")
		assert(cutsceneBloom.Parent == nil, "Cutscene bloom survived cleanup")
		local replacedSession = LightingSession.new({ Properties = { Brightness = 2 }, Children = {} })
		session = replacedSession
		session = LightingSession.new({ Properties = { Brightness = 4 }, Children = {} })
		assert(replacedSession.Destroyed and lighting.Brightness == 4,
			"A new cutscene must own Lighting without inheriting the prior session")
		replacedSession:Destroy()
		session:Destroy()
		assert(lighting.Brightness == previousBrightness, "Replacing a session lost the original brightness")

		local dragonProfile = require(game.ReplicatedStorage.Settings.Data.CutsceneLighting.DragonSlayer)
		session = LightingSession.new(dragonProfile)
		for name, value in dragonProfile.Properties do
			assert(lighting[name] == value, `DragonSlayer Lighting.{name} differs from the profile`)
		end
		for _, definition in dragonProfile.Children do
			local effect = lighting:FindFirstChild(definition.Name)
			assert(effect and effect.ClassName == definition.ClassName,
				`DragonSlayer {definition.Name} was not created`)
			for name, value in definition.Properties do
				assert(effect[name] == value, `DragonSlayer {definition.Name}.{name} differs from the profile`)
			end
		end
		session:Destroy()
		assert(originalBloom.Parent == lighting, "Original bloom was not restored after DragonSlayer")
	end, debug.traceback)
	if session then session:Destroy() end
	lighting.Brightness = previousBrightness
	lighting.ClockTime = previousClockTime
	originalBloom:Destroy()
	if not ok then error(err, 0) end
	print("PASS: cutscene lighting applies, resists overrides, and restores the original state")
end
