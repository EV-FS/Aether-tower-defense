-- Pure sampling tests: luau tests/PropertyTrack.spec.luau
local Track = require("../src/Modules/Cutscene/ECS/PropertyTrack")
local data = require("../src/Settings/Data/CutsceneTracks/RaidIntroScreen")
local contrast = Track.Prepare(data.Contrast, "number")
local saturation = Track.Prepare(data.Saturation, "number")
local function expect(track, frame, expected)
	local actual = Track.Read(track, frame)
	assert(type(actual) == "number" and math.abs(actual - expected) < 1e-8, "Wrong property value at frame " .. frame)
end
for _, key in data.Contrast.Sequence do expect(contrast, key.Frame, key.Value) end
for _, key in data.Saturation.Sequence do expect(saturation, key.Frame, key.Value) end
expect(contrast, -10, 0)
expect(contrast, 4, 2)
expect(saturation, 4, 0.5)
expect(contrast, 14, 2)
expect(contrast, 211, 6)
expect(contrast, 226.5, 6)
expect(contrast, 303, 7.5)
expect(contrast, 318.5, 7.5)
expect(contrast, 400.5, 1)
expect(contrast, 840, 0)
expect(contrast, 900, 0)
-- Skips/seeks sample the destination, without replaying intermediate values.
expect(contrast, 312, 15)
expect(contrast, 8, 4)
expect(contrast, 409, 0)
assert(Track.Read(Track.Prepare({}, "number"), 200) == nil)
expect(Track.Prepare({ Default = 0.25, Sequence = {} }, "number"), 200, 0.25)
assert(Track.Read(Track.Prepare({ Default = false, Sequence = {} }, "boolean"), 200) == false)
assert(not pcall(Track.Prepare, { Default = true, Sequence = {} }, "number"))
assert(not pcall(Track.Prepare, { Default = math.huge, Sequence = {} }, "number"))
local enabled = Track.Prepare({ { Frame = 0, Value = true }, { Frame = 10, Value = false } }, "boolean")
assert(Track.Read(enabled, 9.999) == true)
assert(Track.Read(enabled, 10) == false)
local unordered = { { Frame = 10, Value = 10 }, { Frame = 0, Value = 0 } }
expect(Track.Prepare(unordered, "number"), 5, 5)
assert(unordered[1].Frame == 10, "Preparation mutated source data")
-- Easing applies to the left key's outgoing segment, matching the supplied exporter.
local eased = Track.Prepare({
	{ Frame = 0, Value = 0, Ease = { Type = "Quad" } },
	{ Frame = 10, Value = 10 },
}, "number", function(info)
	assert(info.Type == "Quad")
	return function(alpha) return alpha * alpha end
end)
expect(eased, 5, 2.5)
expect(eased, 10, 10)
assert(not pcall(Track.Prepare, { { Frame = 0, Value = 0 }, { Frame = 0, Value = 1 } }, "number"))
assert(not pcall(Track.Prepare, { { Frame = 1, Value = true } }, "number"))
assert(not pcall(Track.Prepare, { { Frame = 1, Value = math.huge } }, "number"))
assert(not pcall(Track.Prepare, { { Frame = -1, Value = 1 } }, "number"))
print("PropertyTrack tests passed")
