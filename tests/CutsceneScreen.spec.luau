-- Call this function from a Studio test runner with ScreenEffects, PropertyTrack
-- and SummonScreen modules. CLI runs need engine stubs and a module bundle.
return function(ScreenEffects, PropertyTrack, SummonScreen)
	local checks = 0
	local function expect(condition, message)
		assert(condition, message)
		checks += 1
	end
	local function near(actual, expected)
		expect(math.abs(actual - expected) < 1e-6, `Expected {expected}, got {actual}`)
	end
	local view = ScreenEffects.new({ Tracks = SummonScreen, EndFrame = 300, FPS = 60 })
	local effect = view.Effect
	expect(not effect.Enabled, "Preparation must not affect the screen")
	for _, sample in {
		{ 0, 0 }, { 74, 0 }, { 78.5, 0.5 }, { 83, 1 }, { 97, 0 },
		{ 124, 0.15 }, { 284, 0.14 }, { 292, 0.07 }, { 300, 0 },
	} do
		view:ApplyFrame(sample[1], true)
		near(effect.Brightness, sample[2])
	end
	view:ApplyFrame(83, true)
	near(effect.Contrast, 2)
	view:ApplyFrame(83, false)
	expect(not effect.Enabled, "Inactive playback must disable the effect")
	view:ApplyFrame(83, true)
	expect(effect.Enabled, "Playback must enable the effect")
	view:Destroy()
	expect(effect.Parent == nil, "Cleanup must remove the session effect")
	near(effect.Brightness, 0)
	view:Destroy()
	view:ApplyFrame(83, true)
	expect(not effect.Enabled, "Late callbacks must not revive a destroyed effect")

	local hold = ScreenEffects.new({ EndFrame = 20, Tracks = {
		Brightness = { { Frame = 0, Value = 0, Ease = { Type = "None" } }, { Frame = 10, Value = 1 } },
		Saturation = { Default = 2, Sequence = {} },
		Enabled = { Default = false, Sequence = {} },
	} })
	hold:ApplyFrame(9.9, true)
	near(hold.Effect.Brightness, 0)
	near(hold.Effect.Saturation, 2)
	expect(not hold.Effect.Enabled, "Explicit false Default must be respected")
	hold:ApplyFrame(10, true)
	near(hold.Effect.Brightness, 1)
	hold:Destroy()

	local adapter = ScreenEffects.new({ EndFrame = 10, Tracks = {
		Brightness = {
			{ Frame = 0, Value = 0, Ease = { EasingStyle = "Linear", EasingDirection = "Out" } },
			{ Frame = 10, Value = 1 },
		},
		Contrast = {
			{ Frame = 0, Value = 0, Ease = "Constant" },
			{ Frame = 10, Value = 1 },
		},
	} })
	adapter:ApplyFrame(5, true)
	near(adapter.Effect.Brightness, 0.5)
	near(adapter.Effect.Contrast, 0)
	adapter:Destroy()

	local keys = table.freeze({ table.freeze({ Frame = 10, Value = 1 }), table.freeze({ Frame = 0, Value = 0 }) })
	local prepared = PropertyTrack.Prepare(keys, "number")
	near(PropertyTrack.Read(prepared, 5), 0.5)
	expect(keys[1].Frame == 10, "Frozen export must not be reordered")
	expect(not pcall(ScreenEffects.new, { EndFrame = 5, Tracks = { Brightness = keys } }), "Unreachable end keys must fail validation")
	expect(not pcall(ScreenEffects.Validate, { EndFrame = 5, Tracks = { Brightness = keys } }), "Server-side validation must reject unreachable keys")
	expect(not pcall(PropertyTrack.Prepare, { { Frame = 0, Value = 0/0 } }, "number"), "NaN must be rejected")
	print(`PASS: {checks} screen-effect regression checks`)
end
