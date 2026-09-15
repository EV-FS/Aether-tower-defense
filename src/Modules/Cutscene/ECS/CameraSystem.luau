local Components = require(script.Parent.Components)
local SampleTrack = require(script.Parent.SampleTrack)

return function(world)
	local camera = workspace.CurrentCamera
	if not camera then return end
	for _, session, target in world:query(Components.Session, Components.CameraTarget) do
		local part = target.Reference.Value
		if session.State.Parent and part and part.Parent then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = part.CFrame
		end
	end
	for _, session, track in world:query(Components.Session, Components.FOVTrack) do
		if not session.State.Parent then continue end
		local elapsed = session.Elapsed
		local duration = session.State:GetAttribute("CameraDuration")
		local fps = track.FPS
		if not fps then
			fps = if duration and duration > 0 then track.Keys[#track.Keys] / duration else 0
		end
		camera.FieldOfView = math.clamp(
			SampleTrack.Read(track.Samples, track.Keys, elapsed * fps, track.Cuts), 1, 120
		)
	end
end
