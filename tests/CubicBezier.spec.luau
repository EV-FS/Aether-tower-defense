local Bezier = require("../src/Modules/Cutscene/ECS/CubicBezier")
local Track = require("../src/Modules/Cutscene/ECS/PropertyTrack")
local function close(a, b, tolerance)
	assert(math.abs(a - b) < (tolerance or 1e-5), tostring(a) .. " ~= " .. tostring(b))
end
local linear = Bezier.Create({ X1 = 0, Y1 = 0, X2 = 1, Y2 = 1 })
for index = 0, 100 do close(linear(index / 100), index / 100) end
local default = Bezier.Create()
close(default(0.5), 0.8024033876)
assert(default(-1) == 0 and default(2) == 1)
local lowercase = Bezier.Create({ x1 = 0.42, y1 = 0, x2 = 0.58, y2 = 1 })
close(lowercase(0.5), 0.5)
local flat = Bezier.Create({ X1 = 0, Y1 = 0, X2 = 0, Y2 = 1 })
close(flat(0.125), 0.5)
local overshoot = Bezier.Create({ X1 = 0, Y1 = 2, X2 = 1, Y2 = 2 })
assert(overshoot(0.5) > 1)
assert(not pcall(Bezier.Create, { X1 = -1 }))
assert(not pcall(Bezier.Create, { X2 = 2 }))
assert(not pcall(Bezier.Create, { Y1 = math.huge }))
local prepared = Track.Prepare({ Default = 0, Sequence = {
	{ Frame = 0, Value = 0, Ease = { Type = "Bezier", Params = {} } },
	{ Frame = 10, Value = 10 },
} }, "number", function(info) return Bezier.Create(info.Params) end)
close(Track.Read(prepared, 5), default(0.5) * 10)
print("CubicBezier tests passed")
