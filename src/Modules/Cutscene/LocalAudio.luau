local SoundService = game:GetService("SoundService")

local LocalAudio = {}
LocalAudio.__index = LocalAudio

function LocalAudio.new(config)
	local sound = Instance.new("Sound")
	sound.Name = "CutsceneAudio"
	sound.SoundId = `rbxassetid://{config.SoundId}`
	sound.Volume = config.Volume or 1
	sound.Looped = false
	sound.Parent = SoundService
	return setmetatable({ Sound = sound, Paused = false, Destroyed = false }, LocalAudio)
end

-- Called with the same elapsed time as poses, camera, FOV, and screen effects.
function LocalAudio:Step(elapsed: number, paused: boolean)
	if self.Destroyed then return end
	local sound = self.Sound
	if not sound.IsLoaded then
		if elapsed >= 8 and not self.Warned then
			self.Warned = true
			warn(`[CutsceneAudio] {sound.SoundId} has not loaded; check asset permissions.`)
		end
		return
	end
	if sound.TimeLength > 0 and elapsed >= sound.TimeLength then
		if sound.IsPlaying then sound:Stop() end
		return
	end
	if paused then
		if sound.IsPlaying then
			sound:Pause()
			self.Paused = true
		end
		return
	end
	if self.Paused then
		sound.TimePosition = elapsed
		sound:Resume()
		self.Paused = false
		return
	end
	if not sound.IsPlaying then
		-- Play resets TimePosition; seek immediately after starting, including
		-- when the asset loads after the cutscene has already begun.
		sound:Play()
		sound.TimePosition = elapsed
	elseif math.abs(sound.TimePosition - elapsed) > 0.15 then
		-- Correct actual drift without seeking on every rendered frame.
		sound.TimePosition = elapsed
	end
end

function LocalAudio:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Sound:Stop()
	self.Sound:Destroy()
end

return LocalAudio
