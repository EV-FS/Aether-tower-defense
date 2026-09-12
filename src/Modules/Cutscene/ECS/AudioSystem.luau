local Components = require(script.Parent.Components)

return function(world)
	for entity, session, audio in world:query(Components.Session, Components.AudioTrack) do
		local start = session.State:GetAttribute("StartedAt")
		if audio.Started or not start or not session.State.Parent then continue end
		local elapsed = workspace:GetServerTimeNow() - start
		if elapsed < 0 or not audio.Sound.IsLoaded then continue end
		-- Seek once on start to compensate for a late frame; never seek every frame.
		if audio.Sound.TimeLength <= 0 or elapsed < audio.Sound.TimeLength then
			audio.Sound.TimePosition = elapsed
			audio.Sound:Play()
		end
		world:insert(entity, audio:patch({ Started = true }))
	end
end
