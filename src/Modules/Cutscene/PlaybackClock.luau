local PlaybackClock = {}

function PlaybackClock.Elapsed(state, now)
	local start = state:GetAttribute("StartedAt")
	return if start then math.max(0, now - start) else 0
end

function PlaybackClock.Apply(tracks, elapsed)
	for _, track in tracks do
		-- Recover a stopped track instead of silently leaving the actor frozen.
		if not track.IsPlaying then track:Play(0, 1, 0) end
		-- No independent advancement between sampling and pose evaluation.
		track:AdjustSpeed(0)
		track.TimePosition = math.clamp(elapsed, 0, math.max(0, track.Length - 0.000001))
	end
end

function PlaybackClock.Duration(cameraLength, maximum)
	assert(type(cameraLength) == "number" and cameraLength > 0 and cameraLength < math.huge, "Invalid camera duration")
	maximum = maximum or 60
	assert(maximum > 0 and maximum < math.huge, "Invalid maximum duration")
	return math.min(cameraLength, maximum)
end

return PlaybackClock
