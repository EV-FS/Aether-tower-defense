local Components = require(script.Parent.Components)

return function(world)
	for _, session, track in world:query(Components.Session, Components.ScreenEffectTrack) do
		local start = session.State:GetAttribute("StartedAt")
		local duration = session.State:GetAttribute("CameraDuration")
		local fps = track.FPS or (duration and duration > 0 and track.EndFrame / duration)
		if not session.State.Parent or not start or workspace:GetServerTimeNow() < start or not fps then
			track.View:ApplyFrame(0, false)
			continue
		end
		-- Same PreAnimation sample as the camera pose, FOV and impact images.
		track.View:ApplyFrame(session.Elapsed * fps, true)
	end
end
