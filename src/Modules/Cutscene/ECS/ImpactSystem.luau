local Components = require(script.Parent.Components)
local ImpactTrack = require(script.Parent.ImpactTrack)

return function(world)
	for _, session, track in world:query(Components.Session, Components.ImpactTrack) do
		local startedAt = session.State:GetAttribute("StartedAt")
		local duration = session.State:GetAttribute("CameraDuration")
		local fps = track.FPS or (duration and duration > 0 and track.EndFrame / duration)
		if not session.State.Parent or not startedAt or workspace:GetServerTimeNow() < startedAt or not fps then
			track.View:Show(false, false)
			continue
		end
		-- Use the same PreAnimation sample as rig poses and FOV, without yielding/tweens.
		track.View:Show(ImpactTrack.Read(track.Events, track.View.Keys, session.Elapsed * fps), true)
	end
end
