local Clock = require("../src/Modules/Cutscene/PlaybackClock")
local function track(length, playing)
	return {
		Length = length, IsPlaying = playing, Plays = 0,
		Play = function(self, fade, weight, speed)
			assert(fade == 0 and weight == 1 and speed == 0)
			self.IsPlaying = true
			self.Plays += 1
		end,
		AdjustSpeed = function(self, value) assert(value == 0); self.Speed = value end,
	}
end
local camera, actor, stopped = track(14, true), track(60, true), track(14, false)
Clock.Apply({ camera, actor, stopped }, 7.125)
assert(camera.TimePosition == actor.TimePosition and actor.TimePosition == stopped.TimePosition)
assert(stopped.Plays == 1 and camera.Plays == 0)
Clock.Apply({ stopped }, 8)
assert(stopped.Plays == 1, "Do not restart a healthy paused track every frame")
Clock.Apply({ camera }, 100)
assert(camera.TimePosition < camera.Length and camera.TimePosition > 13.999)
assert(Clock.Duration(camera.Length, 60) == 14, "Character idle tails must not prolong the shot")
assert(Clock.Duration(120, 60) == 60)
assert(not pcall(Clock.Duration, 0) and not pcall(Clock.Duration, math.huge))
assert(Clock.Elapsed({ GetAttribute = function() return nil end }, 200) == 0)
assert(Clock.Elapsed({ GetAttribute = function() return 100 end }, 99) == 0)
assert(Clock.Elapsed({ GetAttribute = function() return 100 end }, 103) == 3)
print("PlaybackClock tests passed")
