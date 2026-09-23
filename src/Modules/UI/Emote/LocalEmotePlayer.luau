--// Shared LocalEmotePlayer
-- Manages the local player's emote animation playback:
-- creating/playing/stopping tracks, saving/restoring walkspeed,
-- and auto-stopping on jump/freefall.
--
-- Does NOT handle networking or sprint control — that's the controller's job.
-- Exposes OnAutoStopped callback for the controller to hook into.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)

-------------------------------------------------
--// Types
-------------------------------------------------
type EmoteConfig = EmoteData.EmoteConfig

-------------------------------------------------
--// Constants
-------------------------------------------------
local EMOTE_COOLDOWN = 0.2
local localPlayer = Players.LocalPlayer

-------------------------------------------------
--// LocalEmotePlayer Class
-------------------------------------------------
local LocalEmotePlayer = {}
LocalEmotePlayer.__index = LocalEmotePlayer

export type LocalEmotePlayer = typeof(setmetatable({} :: {
	CurrentEmoteId: string?,
	CurrentTrack: AnimationTrack?,
	CurrentAnimation: Animation?,
	Connections: { RBXScriptConnection },
	SavedWalkSpeed: number?,
	LastEmoteTime: number,
	OnAutoStopped: (() -> ())?,
}, LocalEmotePlayer))

function LocalEmotePlayer.new(): LocalEmotePlayer
	return setmetatable({
		CurrentEmoteId = nil :: string?,
		CurrentTrack = nil :: AnimationTrack?,
		CurrentAnimation = nil :: Animation?,
		Connections = {} :: { RBXScriptConnection },
		SavedWalkSpeed = nil :: number?,
		LastEmoteTime = 0 :: number,
		OnAutoStopped = nil :: (() -> ())?,
	}, LocalEmotePlayer)
end

-------------------------------------------------
--// Public Methods
-------------------------------------------------

--[[ Returns true if cooldown has elapsed since the last emote request. ]]
function LocalEmotePlayer.CheckCooldown(self: LocalEmotePlayer): boolean
	local now = os.clock()
	if now - self.LastEmoteTime < EMOTE_COOLDOWN then
		return false
	end
	self.LastEmoteTime = now
	return true
end

--[[ Starts playing an emote animation on the local character.
     Skips if the same emote is already playing. ]]
function LocalEmotePlayer.Start(self: LocalEmotePlayer, emoteId: string, emoteConfig: EmoteConfig): boolean
	if self.CurrentEmoteId == emoteId and self.CurrentTrack and self.CurrentTrack.IsPlaying then
		return true
	end

	self:Stop()

	local character = localPlayer.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not humanoid then
		return false
	end

	-- Save walkspeed before modification
	if self.SavedWalkSpeed == nil then
		self.SavedWalkSpeed = humanoid.WalkSpeed
	end

	if emoteConfig.WalkSpeed then
		humanoid.WalkSpeed = emoteConfig.WalkSpeed
	end

	-- Auto-stop on jump or freefall
	local jumpConn = humanoid.Jumping:Connect(function(isJumping: boolean)
		if isJumping then
			self:_autoStop()
		end
	end)
	table.insert(self.Connections, jumpConn)

	local stateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
			self:_autoStop()
		end
	end)
	table.insert(self.Connections, stateConn)

	self.CurrentEmoteId = emoteId

	local function playTrack(rawAnimationId, looped: boolean, onStopped: (() -> ())?): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = tostring(rawAnimationId)
		animation.Parent = animator
		local track = animator:LoadAnimation(animation)
		track.Priority = emoteConfig.Priority or Enum.AnimationPriority.Action
		track.Looped = looped
		track:AdjustSpeed(emoteConfig.PlaybackSpeed or 1)
		self.CurrentAnimation = animation
		self.CurrentTrack = track
		if onStopped then
			local stopConn = track.Stopped:Once(onStopped)
			table.insert(self.Connections, stopConn)
		end
		track:Play()
		return track
	end

	local function playMainAnimation()
		if self.CurrentEmoteId ~= emoteId then return end
		if self.CurrentTrack then
			self.CurrentTrack:Destroy()
		end
		if self.CurrentAnimation then
			self.CurrentAnimation:Destroy()
		end
		local mainTrack
		mainTrack = playTrack(emoteConfig.AnimationId, emoteConfig.Looped == true, function()
			if self.CurrentEmoteId == emoteId and self.CurrentTrack == mainTrack then
				self:_autoStop()
			end
		end)
	end

	if emoteConfig.IntroAnimationId then
		local introTrack
		introTrack = playTrack(emoteConfig.IntroAnimationId, false, function()
			if self.CurrentEmoteId == emoteId and self.CurrentTrack == introTrack then
				playMainAnimation()
			end
		end)
	else
		playMainAnimation()
	end

	return true
end

--[[ Stops the current emote and restores walkspeed.
     Does not trigger OnAutoStopped. ]]
function LocalEmotePlayer.Stop(self: LocalEmotePlayer)
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	local currentTrack = self.CurrentTrack
	local currentAnimation = self.CurrentAnimation
	self.CurrentTrack = nil
	self.CurrentAnimation = nil
	self.CurrentEmoteId = nil

	if currentTrack then
		currentTrack:Stop(0)
		pcall(function()
			currentTrack:Destroy()
		end)
	end
	if currentAnimation then
		currentAnimation:Destroy()
	end

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and self.SavedWalkSpeed ~= nil then
			humanoid.WalkSpeed = self.SavedWalkSpeed
		end
	end
	self.SavedWalkSpeed = nil
end

--[[ Returns true if an emote is currently playing. ]]
function LocalEmotePlayer.IsPlaying(self: LocalEmotePlayer): boolean
	return self.CurrentEmoteId ~= nil
end

-------------------------------------------------
--// Private Methods
-------------------------------------------------

--[[ Called on jump/freefall/track-end. Stops locally and notifies controller via callback. ]]
function LocalEmotePlayer._autoStop(self: LocalEmotePlayer)
	local hadEmote = self.CurrentEmoteId ~= nil
	self:Stop()

	if hadEmote and self.OnAutoStopped then
		self.OnAutoStopped()
	end
end

return LocalEmotePlayer
