local RunService = game:GetService("RunService")
local Cleanup = require(script.Parent.Cleanup)
local ClientRigTracks = {}
ClientRigTracks.__index = ClientRigTracks

function ClientRigTracks.new(state)
	return setmetatable({ State = state, Tracks = {}, Seen = {}, Entries = {}, Closed = false }, ClientRigTracks)
end

function ClientRigTracks:Prepare(ready)
	local deadline = os.clock() + 30
	local refs = assert(self.State:WaitForChild("RigTracks", 10), "RigTracks missing")
	local lastStatus = nil
	while self.State.Parent and not self.Closed do
		local loaded, pending = 0, {}
		for _, reference in refs:GetChildren() do
			local optional = reference:GetAttribute("Optional") == true
			local animator = reference.Value
			local id = reference:GetAttribute("AnimationId")
			local entry = self.Entries[reference]
			if animator and id and not entry then
				entry = { Animator = animator, Since = os.clock(), Tracks = {} }
				self.Entries[reference] = entry
				local function collect(track)
					if self.Closed then return end
					local animation = track.Animation
					if animation and animation.AnimationId:match("%d+") == id and not self.Seen[track] then
						self.Seen[track] = true
						table.insert(self.Tracks, track)
						table.insert(entry.Tracks, track)
					end
				end
				entry.Collect = collect
				entry.Connection = animator.AnimationPlayed:Connect(collect)
			end
			local available = false
			if entry then
				for _, track in animator:GetPlayingAnimationTracks() do entry.Collect(track) end
				for _, track in entry.Tracks do
					if track.Length > 0 and track.IsPlaying then available = true end
				end
				-- A paused server track may not arrive with its Animator. Load a local
				-- rendering fallback; later replicated copies join the SAME clock too.
				if not optional and not available and not entry.OwnedTrack and os.clock() - entry.Since >= 2 then
					entry.Animation = Instance.new("Animation")
					entry.Animation.AnimationId = "rbxassetid://" .. id
					entry.OwnedTrack = animator:LoadAnimation(entry.Animation)
					entry.OwnedTrack.Priority = Enum.AnimationPriority.Action4
					entry.OwnedTrack.Looped = false
					entry.Collect(entry.OwnedTrack)
					entry.OwnedTrack:Play(0, 1, 0)
				end
			end
			if available then
				if not optional then loaded += 1 end
			elseif not optional then
				table.insert(pending, reference.Name .. " (" .. tostring(id) .. ")")
			end
		end
		local expected = self.State:GetAttribute("TrackCount")
		if expected and expected > 0 and loaded == expected then return self.Tracks end
		local status = "Animation rigs " .. loaded .. "/" .. tostring(expected) .. ": " .. table.concat(pending, ", ")
		if status ~= lastStatus then ready:FireServer("Stage", status); lastStatus = status end
		assert(os.clock() < deadline, status .. "; check animation permissions and rig replication")
		RunService.Heartbeat:Wait()
	end
	return self.Tracks
end

function ClientRigTracks:Destroy()
	if self.Closed then return end
	self.Closed = true
	for _, entry in self.Entries do
		if entry.Connection then entry.Connection:Disconnect() end
		if entry.OwnedTrack then
			Cleanup.Try("Stop fallback animation", function() entry.OwnedTrack:Stop(0) end)
			Cleanup.Try("Destroy fallback animation", function() entry.OwnedTrack:Destroy() end)
		end
		if entry.Animation then entry.Animation:Destroy() end
	end
	table.clear(self.Entries)
end
return ClientRigTracks
