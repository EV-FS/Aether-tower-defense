local PlaybackClock = {}

function PlaybackClock.Elapsed(state, now)
	local start = state:GetAttribute("StartedAt")
	return if start then math.max(0, now - start) else 0
end

function PlaybackClock.Apply(tracks, elapsed)
	for _, track in tracks do
		if track.IsPlaying then
			-- No independent advancement between sampling and pose evaluation.
			track:AdjustSpeed(0)
			track.TimePosition = math.clamp(elapsed, 0, math.max(0, track.Length - 0.000001))
		end
	end
end

return PlaybackClock
