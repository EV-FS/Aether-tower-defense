local Components = require(script.Parent.Components)

return function(world)
	for entity, session, track in world:query(Components.Session, Components.VFXTrack) do
		local startedAt = session.State:GetAttribute("StartedAt")
		-- Frame zero fires only once the server's scheduled start is reached.
		if not session.State.Parent or not startedAt or workspace:GetServerTimeNow() < startedAt then continue end
		local duration = session.State:GetAttribute("CameraDuration")
		local fps = track.FPS or (duration and duration > 0 and track.EndFrame / duration)
		if not fps then continue end
		local frame = session.Elapsed * fps
		local nextIndex = track.NextIndex
		while nextIndex <= #track.Keys and track.Keys[nextIndex] <= frame do
			local event = track.Events[track.Keys[nextIndex]]
			nextIndex += 1
			-- Reserve the event before dispatching potentially yielding third-party VFX.
			task.spawn(track.Run, event)
		end
		if nextIndex ~= track.NextIndex then
			world:insert(entity, track:patch({ NextIndex = nextIndex }))
		end
	end
end
