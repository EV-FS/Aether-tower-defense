local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataService = require(script.Parent.DataService)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmotePropUtils = require(ReplicatedStorage.Shared.Modules.Utils.EmotePropUtils)
local Net = require(ReplicatedStorage.Shared.Net.server)

local DEFAULT_WALKSPEED = 16

local activeConnections: { [Player]: { RBXScriptConnection } } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function resolveEmoteName(targetEmote: number | string): string?
	if typeof(targetEmote) == "number" then
		local config = EmoteData.ByIndex[targetEmote]
		return if config then config.Name else nil
	end
	return targetEmote :: string
end

local function cleanupPlayerEmoteState(player: Player)
	local conns = activeConnections[player]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		activeConnections[player] = nil
	end

	local character = player.Character
	if character then
		character:SetAttribute("CurrentEmote", nil)
		EmotePropUtils.ClearProps(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_WALKSPEED
		end
	end
end

-------------------------------------------------
--// EmoteService
-------------------------------------------------
local EmoteService = {}

function EmoteService.AddEmote(player: Player, targetEmote: number | string)
	local emoteName = resolveEmoteName(targetEmote)
	if not emoteName or not EmoteData.ByName[emoteName] then
		warn(`존재하지 않는 이모트 {targetEmote}를 추가하려 시도함.`)
		return
	end

	DataService:AddData(player, "Inventory", 1, "Emotes", emoteName)
end

function EmoteService.RemoveEmote(player: Player, targetEmote: number | string)
	local emoteName = resolveEmoteName(targetEmote)
	if not emoteName or not EmoteData.ByName[emoteName] then
		warn(`존재하지 않는 이모트 {targetEmote}를 제거하려 시도함.`)
		return
	end

	local playerData = DataService:GetData(player)
	local playerEmote = playerData and playerData.Inventory and playerData.Inventory.Emotes[emoteName]
	if not playerEmote or playerEmote <= 0 then
		warn(`보유하지 않은 이모트 {emoteName}를 제거하려 시도함.`)
		return
	end

	DataService:AddData(player, "Inventory", -1, "Emotes", emoteName)
end

function EmoteService.PlayEmote(player: Player, targetEmote: number | string): boolean
	local emoteName = resolveEmoteName(targetEmote)
	local emoteConfig = emoteName and EmoteData.ByName[emoteName]
	if not emoteConfig or not emoteName then
		warn(`존재하지 않는 이모트 {targetEmote}를 재생하려 시도함.`)
		return false
	end

	local isStudio = RunService:IsStudio()
	local playerData = DataService:GetData(player)
	local playerEmote = playerData and playerData.Inventory and playerData.Inventory.Emotes[emoteName]
	if not isStudio and (not playerEmote or playerEmote <= 0) then
		warn(`보유하지 않은 이모트 {emoteName}를 재생하려 시도함.`)
		return false
	end

	cleanupPlayerEmoteState(player)

	local character = player.Character
	if not character then
		return false
	end

	character:SetAttribute("CurrentEmote", emoteName)

	if emoteConfig.Props then
		EmotePropUtils.AttachProps(character, emoteConfig.Props)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if emoteConfig.WalkSpeed then
			humanoid.WalkSpeed = emoteConfig.WalkSpeed
		end

		local conns: { RBXScriptConnection } = {}

		local jumpConn = humanoid.Jumping:Connect(function(isJump: boolean)
			if isJump then
				EmoteService.StopEmote(player)
			end
		end)
		table.insert(conns, jumpConn)

		local stateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
			if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
				EmoteService.StopEmote(player)
			end
		end)
		table.insert(conns, stateConn)

		activeConnections[player] = conns
	end

	Net.EmoteService.EmoteStarted.FireAll({ Player = player, EmoteId = targetEmote :: string })
	return true
end

function EmoteService.StopEmote(player: Player): boolean
	cleanupPlayerEmoteState(player)
	Net.EmoteService.EmoteStopped.FireAll({ Player = player })
	return true
end

function EmoteService.Init() end

function EmoteService.Start()
	Net.EmoteService.RequestPlayEmote.On(function(player: Player, data: { EmoteId: string }): boolean
		return EmoteService.PlayEmote(player, data.EmoteId)
	end)

	Net.EmoteService.RequestStopEmote.On(function(player: Player): boolean
		return EmoteService.StopEmote(player)
	end)
end

return EmoteService
