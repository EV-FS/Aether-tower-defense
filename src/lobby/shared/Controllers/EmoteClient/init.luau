--// EmoteClient Controller
-- Orchestrates the emote system: coordinates local playback,
-- network communication, sprint toggling, and per-player observation.
--
-- Public API (unchanged from previous architecture):
--   EmoteClient.PlayEmote(emoteId)     — Request server to play emote
--   EmoteClient.StopEmote()            — Stop emote and notify server
--   EmoteClient.StartLocalEmote(id)    — Start emote locally (server-confirmed)
--   EmoteClient.StopLocalEmote()       — Stop emote locally (no network)
--   EmoteClient.Init()                 — Initialize state
--   EmoteClient.Start()                — Start observation and net listeners

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-------------------------------------------------
--// Dependencies
-------------------------------------------------
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local Net = require(ReplicatedStorage.Shared.Net.client)
local CharacterUtils = require(script.CharacterUtils)
local ServiceUtils = require(script.ServiceUtils)
local CharacterEmoteObserver = require(script.CharacterEmoteObserver)
local LocalEmotePlayer = require(ReplicatedStorage.Shared.Modules.UI.Emote.LocalEmotePlayer)

-------------------------------------------------
--// State
-------------------------------------------------
local localPlayer = Players.LocalPlayer
local emotePlayer: LocalEmotePlayer.LocalEmotePlayer
local characterObservers: { [Player]: CharacterEmoteObserver.CharacterEmoteObserver } = {}

-------------------------------------------------
--// EmoteClient Controller
-------------------------------------------------
local EmoteClient = {}

--[[ Starts an emote on the local player (called when server confirms). ]]
function EmoteClient.StartLocalEmote(emoteId: string)
	local emoteConfig = EmoteData.ByName[emoteId]
	if not emoteConfig then
		warn(`[EmoteClient] Emote data not found: {emoteId}`)
		return
	end

	local didStart = emotePlayer:Start(emoteId, emoteConfig)
	local sprintCtrl = ServiceUtils.Get("SprintClient")
	if sprintCtrl then
		if didStart then
			sprintCtrl.Disable()
		else
			sprintCtrl.Enable()
		end
	end
end

--[[ Stops the local player's emote without notifying the server. ]]
function EmoteClient.StopLocalEmote()
	emotePlayer:Stop()
end

--[[ Requests the server to play an emote (with cooldown check). ]]
function EmoteClient.PlayEmote(emoteId: string)
	if not emotePlayer:CheckCooldown() then
		return
	end

	local emoteConfig = EmoteData.ByName[emoteId]
	if not emoteConfig then
		warn(`[EmoteClient] Emote data not found: {emoteId}`)
		return
	end

	Net.EmoteService.RequestPlayEmote
		.Invoke({ EmoteId = emoteId })
		:andThen(function(success: boolean)
			if not success then
				warn(`[EmoteClient] Server rejected emote: {emoteId}`)
			end
		end)
		:catch(function(err: any)
			warn(`[EmoteClient] Network error: {err}`)
		end)
end

--[[ Stops the current emote and notifies the server. ]]
function EmoteClient.StopEmote()
	local hadEmote = emotePlayer:IsPlaying()
	emotePlayer:Stop()

	if hadEmote then
		Net.EmoteService.RequestStopEmote.Invoke():catch(function(err: any)
			warn(`[EmoteClient] StopEmote error: {err}`)
		end)
	end

	local sprintCtrl = ServiceUtils.Get("SprintClient")
	if sprintCtrl then
		sprintCtrl.Enable()
	end
end

-------------------------------------------------
--// Lifecycle
-------------------------------------------------

function EmoteClient.Init()
	emotePlayer = LocalEmotePlayer.new()

	-- When emote auto-stops (jump/freefall/track ended), notify server & re-enable sprint
	emotePlayer.OnAutoStopped = function()
		Net.EmoteService.RequestStopEmote.Invoke():catch(function(err: any)
			warn(`[EmoteClient] Auto-stop network error: {err}`)
		end)

		local sprintCtrl = ServiceUtils.Get("SprintClient")
		if sprintCtrl then
			sprintCtrl.Enable()
		end
	end
end

function EmoteClient.Start()
	-------------------------------------------------
	-- Player observation (SFX/VFX for all players)
	-------------------------------------------------
	local function observePlayer(player: Player)
		local function onCharacterAdded(character: Model)
			local oldObserver = characterObservers[player]
			if oldObserver then
				oldObserver:Destroy()
				characterObservers[player] = nil
			end

			characterObservers[player] = CharacterEmoteObserver.new(character)
		end

		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end

		player.CharacterAdded:Connect(onCharacterAdded)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		observePlayer(player)
	end

	Players.PlayerAdded:Connect(observePlayer)

	Players.PlayerRemoving:Connect(function(player: Player)
		local observer = characterObservers[player]
		if observer then
			observer:Destroy()
			characterObservers[player] = nil
		end
	end)

	-------------------------------------------------
	-- Network event listeners
	-------------------------------------------------
	Net.EmoteService.EmoteStarted.On(function(data: { Player: unknown, EmoteId: string })
		local targetPlayer = data.Player :: Player?
		if targetPlayer == localPlayer and emotePlayer.CurrentEmoteId ~= data.EmoteId then
			EmoteClient.StartLocalEmote(data.EmoteId)
		end
	end)

	Net.EmoteService.EmoteStopped.On(function(data: { Player: unknown })
		local targetPlayer = data.Player :: Player?
		if targetPlayer == localPlayer and emotePlayer:IsPlaying() then
			EmoteClient.StopLocalEmote()

				local sprintCtrl = ServiceUtils.Get("SprintClient")
			if sprintCtrl then
				sprintCtrl.Enable()
			end
		end
	end)
end

return EmoteClient
