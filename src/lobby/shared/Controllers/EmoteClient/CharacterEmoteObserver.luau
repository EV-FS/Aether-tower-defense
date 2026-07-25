--// CharacterEmoteObserver
-- Observes a character's Animator for emote animations and creates
-- EmoteTrackState instances to manage their SFX/VFX lifecycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteTrackState = require(script.Parent.EmoteTrackState)

-------------------------------------------------
--// CharacterEmoteObserver Class
-------------------------------------------------
local CharacterEmoteObserver = {}
CharacterEmoteObserver.__index = CharacterEmoteObserver

export type CharacterEmoteObserver = typeof(setmetatable({} :: {
	Character: Model,
	Connections: { RBXScriptConnection },
	ActiveTracks: { [AnimationTrack]: EmoteTrackState.EmoteTrackState },
}, CharacterEmoteObserver))

function CharacterEmoteObserver.new(character: Model): CharacterEmoteObserver
	local self = setmetatable({
		Character = character,
		Connections = {} :: { RBXScriptConnection },
		ActiveTracks = {} :: { [AnimationTrack]: EmoteTrackState.EmoteTrackState },
	}, CharacterEmoteObserver)

	self:_startObserving()
	return self
end

-------------------------------------------------
--// Private Methods
-------------------------------------------------

function CharacterEmoteObserver._startObserving(self: CharacterEmoteObserver)
	local humanoid = self.Character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	local animator = humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end

	local function processTrack(track: AnimationTrack)
		local anim = track.Animation
		if not anim then
			return
		end

		local cleanId = string.match(anim.AnimationId, "%d+") or anim.AnimationId
		local emoteConfig = EmoteData.ByAnimationId[cleanId] or EmoteData.ByAnimationId[anim.AnimationId]
		if not emoteConfig then
			return
		end

		if self.ActiveTracks[track] then
			return
		end

		local trackState = EmoteTrackState.new(self.Character, track, emoteConfig, function()
			self.ActiveTracks[track] = nil
		end)
		self.ActiveTracks[track] = trackState
	end

	local playConn = animator.AnimationPlayed:Connect(processTrack)
	table.insert(self.Connections, playConn)

	-- Process any tracks that are already playing
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		processTrack(track)
	end
end

-------------------------------------------------
--// Public Methods
-------------------------------------------------

function CharacterEmoteObserver.Destroy(self: CharacterEmoteObserver)
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	for _, trackState in pairs(self.ActiveTracks) do
		trackState:Destroy()
	end
	table.clear(self.ActiveTracks)
end

return CharacterEmoteObserver
