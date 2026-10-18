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
local activePlayers: { [Model]: any } = setmetatable({}, { __mode = "k" })
local actionVersions: { [Model]: number } = setmetatable({}, { __mode = "k" })

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
	Humanoid: Humanoid?,
	Character: Model?,
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
		Humanoid = nil :: Humanoid?,
		Character = nil :: Model?,
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
	if localPlayer:GetAttribute("SummonControlsLocked") or character:GetAttribute("Dashing") then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local state = humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.RunningNoPhysics
		and state ~= Enum.HumanoidStateType.Landed then
		return false
	end
	if character:FindFirstChildOfClass("Tool") then
		return false
	end
	local previous = activePlayers[character]
	if previous and previous ~= self then
		previous:_autoStop()
	end
	self.Character = character
	self.Humanoid = humanoid
	activePlayers[character] = self

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
		if newState ~= Enum.HumanoidStateType.Running and newState ~= Enum.HumanoidStateType.RunningNoPhysics
			and newState ~= Enum.HumanoidStateType.Landed then
			self:_autoStop()
		end
	end)
	table.insert(self.Connections, stateConn)
	table.insert(self.Connections, humanoid.Died:Connect(function()
		self:_autoStop()
	end))
	table.insert(self.Connections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then self:_autoStop() end
	end))
	table.insert(self.Connections, localPlayer.CharacterRemoving:Connect(function(removing)
		if removing == character then self:_autoStop() end
	end))
	table.insert(self.Connections, localPlayer:GetAttributeChangedSignal("SummonControlsLocked"):Connect(function()
		if localPlayer:GetAttribute("SummonControlsLocked") then self:_autoStop() end
	end))

	self.CurrentEmoteId = emoteId

	local function playTrack(rawAnimationId, looped: boolean, onStopped: (() -> ())?): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = tostring(rawAnimationId)
		animation.Parent = animator
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			animation:Destroy()
			error(track)
		end
		track.Priority = emoteConfig.Priority or Enum.AnimationPriority.Action
		track.Looped = looped
		self.CurrentAnimation = animation
		self.CurrentTrack = track
		if onStopped then
			local stopConn = track.Stopped:Once(onStopped)
			table.insert(self.Connections, stopConn)
		end
		track:Play(0.1, 1, emoteConfig.PlaybackSpeed or 1)
		return track
	end

	local function playMainAnimation()
		if self.CurrentEmoteId ~= emoteId then return end
		local oldTrack = self.CurrentTrack
		local oldAnimation = self.CurrentAnimation
		self.CurrentTrack = nil
		self.CurrentAnimation = nil
		if oldTrack then
			oldTrack:Destroy()
		end
		if oldAnimation then
			oldAnimation:Destroy()
		end
		local mainTrack
		mainTrack = playTrack(emoteConfig.AnimationId, emoteConfig.Looped == true, function()
			if self.CurrentEmoteId == emoteId and self.CurrentTrack == mainTrack then
				self:_autoStop()
			end
		end)
	end

	local function startAnimation()
		if emoteConfig.IntroAnimationId then
			local introTrack
			introTrack = playTrack(emoteConfig.IntroAnimationId, false, function()
				if self.CurrentEmoteId == emoteId and self.CurrentTrack == introTrack then
					local ok, err = pcall(playMainAnimation)
					if not ok then
						self:_autoStop()
						warn(`[LocalEmotePlayer] Could not continue {emoteId}: {err}`)
					end
				end
			end)
		else
			playMainAnimation()
		end
	end
	local ok, err = pcall(startAnimation)
	if not ok then
		self:Stop()
		warn(`[LocalEmotePlayer] Could not play {emoteId}: {err}`)
		return false
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
		pcall(function()
			currentTrack:Stop(0)
			currentTrack:Destroy()
		end)
	end
	if currentAnimation then
		currentAnimation:Destroy()
	end

	local character = self.Character
	if character and activePlayers[character] == self then
		activePlayers[character] = nil
	end
	local humanoid = self.Humanoid
	if humanoid and humanoid.Parent and self.SavedWalkSpeed ~= nil then
		humanoid.WalkSpeed = self.SavedWalkSpeed
	end
	self.SavedWalkSpeed = nil
	self.Character = nil
	self.Humanoid = nil
end

--[[ Cancels a character's local emote before another action takes control. ]]
function LocalEmotePlayer.Interrupt(character: Model?): boolean
	if character then
		actionVersions[character] = (actionVersions[character] or 0) + 1
	end
	local player = if character then activePlayers[character] else nil
	if not player then return false end
	player:_autoStop()
	return true
end

--[[ Identifies whether a newer action superseded an emote request. ]]
function LocalEmotePlayer.GetActionVersion(character: Model?): number
	return if character then actionVersions[character] or 0 else 0
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
