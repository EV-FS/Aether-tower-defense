local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-------------------------------------------------
--// Services & Modules
-------------------------------------------------
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmitParticles = require(ReplicatedStorage.Shared.Modules.Utils.EmitParticles)
local EmotePropUtils = require(ReplicatedStorage.Shared.Modules.Utils.EmotePropUtils)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local Net = require(ReplicatedStorage.Shared.Net.client)

-------------------------------------------------
--// Types
-------------------------------------------------
type KeyframeEventData = {
	SFX: (number | string)?,
	Volume: number?,
	Distance: number?,
	VFX: string?,
	VFXRecipes: any?,
	EmitCount: number?,
}

type EmoteConfig = {
	Name: string,
	Index: number,
	AnimationId: string | number,
	Priority: Enum.AnimationPriority?,
	WalkSpeed: number?,
	SoundId: (number | string)?,
	SoundVolume: number?,
	SoundDistance: number?,
	KeyframeEvents: { [string]: KeyframeEventData }?,
}

-------------------------------------------------
--// State Variables
-------------------------------------------------
local DEFAULT_WALKSPEED = 16

local localPlayer = Players.LocalPlayer
local AudioController: any = nil
local VFXController: any = nil
local SprintClient: any = nil

local currentTrack: AnimationTrack? = nil
local currentEmoteId: string? = nil
local emoteJumpConn: RBXScriptConnection? = nil
local emoteStateConn: RBXScriptConnection? = nil

local activeConnections: { [AnimationTrack]: { RBXScriptConnection } } = {}
local trackedAnimators: { [Animator]: boolean } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getAudioController()
	if not AudioController then
		AudioController = ServiceRegistry:GetService("AudioController")
	end
	return AudioController
end

local function getVFXController()
	if not VFXController then
		VFXController = ServiceRegistry:GetService("VFXController")
	end
	return VFXController
end

local function getSprintClient()
	if not SprintClient then
		SprintClient = ServiceRegistry:GetService("SprintClient")
	end
	return SprintClient
end

local function extractNumericId(assetUrl: string): string
	return string.match(assetUrl, "%d+") or assetUrl
end

local function findEmoteConfig(animationId: string): EmoteConfig?
	local cleanId = extractNumericId(animationId)
	return (EmoteData.ByAnimationId[cleanId] or EmoteData.ByAnimationId[animationId]) :: EmoteConfig?
end

local function handleKeyframeEvent(character: Model, eventData: KeyframeEventData, activeSounds: { any }?)
	local rootPart = character.PrimaryPart or (character:FindFirstChild("HumanoidRootPart") :: BasePart)
	if not rootPart then
		return
	end

	if eventData.SFX then
		local audioCtrl = getAudioController()
		if audioCtrl then
			local soundPlayer =
				audioCtrl.PlayOn3D(eventData.SFX, eventData.Volume or 1, eventData.Distance or 100, rootPart)
			if soundPlayer and activeSounds then
				table.insert(activeSounds, soundPlayer)
			end
		end
	end

	if eventData.VFXRecipes then
		local vfxCtrl = getVFXController()
		if vfxCtrl then
			local recipes = if typeof(eventData.VFXRecipes) == "table"
				then eventData.VFXRecipes
				else vfxCtrl.GetRecipes(eventData.VFXRecipes, "Emote")
			if recipes then
				vfxCtrl.PlayVFX(recipes, character, character)
			end
		end
	elseif eventData.VFX then
		local vfxCtrl = getVFXController()
		local recipes = vfxCtrl and vfxCtrl.GetRecipes and vfxCtrl.GetRecipes("Emote", eventData.VFX)
		if recipes then
			vfxCtrl.PlayVFX(recipes, character, character)
		else
			local vfxTarget = character:FindFirstChild(eventData.VFX, true)
			if vfxTarget then
				EmitParticles(vfxTarget)
			end
		end
	end
end

local function bindTrackMarkers(character: Model, track: AnimationTrack, emoteConfig: EmoteConfig)
	if activeConnections[track] then
		return
	end

	local connections: { RBXScriptConnection } = {}
	activeConnections[track] = connections

	local activeSounds: { any } = {}

	if emoteConfig.SoundId then
		local rootPart = character.PrimaryPart or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if rootPart then
			local audioCtrl = getAudioController()
			if audioCtrl then
				local soundPlayer = audioCtrl.PlayOn3D(
					emoteConfig.SoundId,
					emoteConfig.SoundVolume or 1,
					emoteConfig.SoundDistance or 100,
					rootPart
				)
				if soundPlayer then
					table.insert(activeSounds, soundPlayer)
				end
			end
		end
	end

	local keyframeEvents = emoteConfig.KeyframeEvents
	if keyframeEvents then
		for markerName, eventData in pairs(keyframeEvents) do
			local markerConn = track:GetMarkerReachedSignal(markerName):Connect(function()
				handleKeyframeEvent(character, eventData, activeSounds)
			end)
			table.insert(connections, markerConn)

			local legacyConn = track.KeyframeReached:Connect(function(reachedKeyframe: string)
				if reachedKeyframe == markerName then
					handleKeyframeEvent(character, eventData, activeSounds)
				end
			end)
			table.insert(connections, legacyConn)
		end
	end

	local stopConn: RBXScriptConnection
	stopConn = track.Stopped:Once(function()
		local storedConns = activeConnections[track]
		if not storedConns then
			return
		end

		for _, soundPlayer in ipairs(activeSounds) do
			if soundPlayer and typeof(soundPlayer.Stop) == "function" then
				soundPlayer:Stop()
			end
		end

		for _, conn in ipairs(storedConns) do
			conn:Disconnect()
		end
		activeConnections[track] = nil
	end)
	table.insert(connections, stopConn)
end

local function observeAnimator(character: Model, animator: Animator)
	if trackedAnimators[animator] then
		return
	end
	trackedAnimators[animator] = true

	local function processTrack(track: AnimationTrack)
		local anim = track.Animation
		if not anim then
			return
		end

		local emoteConfig = findEmoteConfig(anim.AnimationId)
		if emoteConfig then
			bindTrackMarkers(character, track, emoteConfig)
		end
	end

	animator.AnimationPlayed:Connect(processTrack)

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		processTrack(track)
	end
end

local function observeCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	local animator = humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end

	observeAnimator(character, animator)
end

local function observePlayer(player: Player)
	if player.Character then
		task.spawn(observeCharacter, player.Character)
	end

	player.CharacterAdded:Connect(observeCharacter)
end

local function stopLocalEmote()
	if emoteJumpConn then
		emoteJumpConn:Disconnect()
		emoteJumpConn = nil
	end
	if emoteStateConn then
		emoteStateConn:Disconnect()
		emoteStateConn = nil
	end

	local character = localPlayer.Character
	if character then
		EmotePropUtils.ClearProps(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_WALKSPEED
		end
	end

	if currentTrack then
		currentTrack:Stop(0)
		currentTrack = nil
	end

	currentEmoteId = nil
end

-------------------------------------------------
--// EmoteClient
-------------------------------------------------
local EmoteClient = {}

function EmoteClient.PlayEmote(emoteId: string)
	local emoteConfig = EmoteData.ByName[emoteId] :: EmoteConfig?
	if not emoteConfig then
		warn(`[EmoteClient] Emote data not found: {emoteId}`)
		return
	end

	stopLocalEmote()

	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not humanoid then
		return
	end

	local sprintCtrl = getSprintClient()
	if sprintCtrl then
		sprintCtrl.Disable()
	end

	if emoteConfig.Props then
		EmotePropUtils.AttachProps(character, emoteConfig.Props)
	end

	if emoteConfig.WalkSpeed then
		humanoid.WalkSpeed = emoteConfig.WalkSpeed
	end

	emoteJumpConn = humanoid.Jumping:Connect(function(isJumping: boolean)
		if isJumping then
			EmoteClient.StopEmote()
		end
	end)

	emoteStateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
			EmoteClient.StopEmote()
		end
	end)

	local animation = Instance.new("Animation")
	animation.AnimationId = tostring(emoteConfig.AnimationId)

	local track = animator:LoadAnimation(animation)
	track.Priority = emoteConfig.Priority or Enum.AnimationPriority.Action
	track:Play()

	currentTrack = track
	currentEmoteId = emoteId

	track.Stopped:Once(function()
		if currentTrack == track then
			EmoteClient.StopEmote()
		end
	end)

	bindTrackMarkers(character, track, emoteConfig)

	Net.EmoteService.RequestPlayEmote
		.Invoke({ EmoteId = emoteId })
		:andThen(function(success: boolean)
			if not success and currentTrack == track then
				warn(`[EmoteClient] Server rejected emote play: {emoteId}`)
				EmoteClient.StopEmote()
			end
		end)
		:catch(function(err: any)
			warn(`[EmoteClient] RequestPlayEmote network error: {err}`)
			if currentTrack == track then
				EmoteClient.StopEmote()
			end
		end)
end

function EmoteClient.StopEmote()
	local hadEmote = currentEmoteId ~= nil
	stopLocalEmote()

	if hadEmote then
		Net.EmoteService.RequestStopEmote.Invoke():catch(function(err: any)
			warn(`[EmoteClient] RequestStopEmote error: {err}`)
		end)
	end

	local sprintCtrl = getSprintClient()
	if sprintCtrl then
		sprintCtrl.Enable()
	end
end

function EmoteClient.Init() end

function EmoteClient.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		observePlayer(player)
	end

	Players.PlayerAdded:Connect(observePlayer)

	Net.EmoteService.EmoteStopped.On(function(data: { Player: unknown })
		local targetPlayer = data.Player :: Player?
		if targetPlayer == localPlayer and currentTrack then
			stopLocalEmote()
			local sprintCtrl = getSprintClient()
			if sprintCtrl then
				sprintCtrl.Enable()
			end
		end
	end)
end

return EmoteClient
