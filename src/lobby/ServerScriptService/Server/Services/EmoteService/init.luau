local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmotePropUtils = require(ReplicatedStorage.Shared.Modules.Utils.EmotePropUtils)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService

local EMOTE_COOLDOWN = 0.2
local MAX_EMOTE_SLOTS = 4
local LOADOUT_REMOTE_NAME = "EmoteLoadoutAction"

-------------------------------------------------
--// PlayerEmoteState Class
-------------------------------------------------
type EmoteConfig = EmoteData.EmoteConfig

local PlayerEmoteState = {}
PlayerEmoteState.__index = PlayerEmoteState

function PlayerEmoteState.new(player: Player)
	local self = setmetatable({
		Player = player,
		CurrentEmote = nil :: string?,
		SavedWalkSpeed = nil :: number?,
		Connections = {} :: { RBXScriptConnection },
		LastEmoteTime = 0 :: number,
	}, PlayerEmoteState)
	return self
end

function PlayerEmoteState:Play(emoteName: string, emoteConfig: EmoteConfig): boolean
	local now = os.clock()
	if now - self.LastEmoteTime < EMOTE_COOLDOWN then
		return false
	end
	self.LastEmoteTime = now

	local character = self.Player.Character
	if not character then
		return false
	end

	self:Stop(true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.SavedWalkSpeed = humanoid.WalkSpeed
	end

	self.CurrentEmote = emoteName
	character:SetAttribute("CurrentEmote", emoteName)

	if emoteConfig.Props then
		EmotePropUtils.AttachProps(character, emoteConfig.Props)
	end

	if humanoid then
		if emoteConfig.WalkSpeed then
			humanoid.WalkSpeed = emoteConfig.WalkSpeed
		end

		local conns: { RBXScriptConnection } = {}

		local jumpConn = humanoid.Jumping:Connect(function(isJump: boolean)
			if isJump then
				self:Stop()
			end
		end)
		table.insert(conns, jumpConn)

		local stateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
			if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
				self:Stop()
			end
		end)
		table.insert(conns, stateConn)

		self.Connections = conns
	end

	Net.EmoteService.EmoteStarted.FireAll({ Player = self.Player, EmoteId = emoteName })
	return true
end

function PlayerEmoteState:Stop(suppressNotify: boolean?): boolean
	local hadEmote = self.CurrentEmote ~= nil

	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	local character = self.Player.Character
	if character then
		character:SetAttribute("CurrentEmote", nil)
		EmotePropUtils.ClearProps(character)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and self.SavedWalkSpeed ~= nil then
			humanoid.WalkSpeed = self.SavedWalkSpeed
		end
	end
	self.SavedWalkSpeed = nil
	self.CurrentEmote = nil

	if hadEmote and not suppressNotify then
		Net.EmoteService.EmoteStopped.FireAll({ Player = self.Player })
	end

	return true
end

function PlayerEmoteState:Destroy()
	self:Stop()
end

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

-------------------------------------------------
--// EmoteService
-------------------------------------------------
local EmoteService = {}
local playerStates: { [Player]: any } = {}

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

	if playerEmote <= 1 then
		local loadout = table.clone(playerData.EmoteLoadout or {})
		local changed = false
		for slot, equippedName in loadout do
			if equippedName == emoteName then
				loadout[slot] = nil
				changed = true
			end
		end
		if changed then
			DataService:UpdateData(player, "EmoteLoadout", loadout)
		end
	end
end

function EmoteService.PlayEmote(player: Player, targetEmote: number | string): boolean
	local emoteName = resolveEmoteName(targetEmote)
	local emoteConfig = emoteName and EmoteData.ByName[emoteName]
	if not emoteConfig or not emoteName then
		warn(`존재하지 않는 이모트 {targetEmote}를 재생하려 시도함.`)
		return false
	end

	local playerData = DataService:GetData(player)
	local isStudio = RunService:IsStudio()
	if not isStudio then
		local playerEmote = playerData and playerData.Inventory and playerData.Inventory.Emotes[emoteName]
		if not playerEmote or playerEmote <= 0 then
			warn(`보유하지 않은 이모트 {emoteName}를 재생하려 시도함.`)
			return false
		end
	end

	local isEquipped = false
	for _, equippedName in (playerData and playerData.EmoteLoadout) or {} do
		if equippedName == emoteName then
			isEquipped = true
			break
		end
	end
	if not isEquipped then
		return false
	end

	local state = playerStates[player]
	if not state then
		state = PlayerEmoteState.new(player)
		playerStates[player] = state
	end

	return state:Play(emoteName, emoteConfig)
end

function EmoteService.UpdateLoadout(player: Player, request: any)
	if type(request) ~= "table" then
		return { Success = false, Message = "Invalid emote request." }
	end

	local slot = tonumber(request.Slot)
	if not slot or slot % 1 ~= 0 or slot < 1 or slot > MAX_EMOTE_SLOTS then
		return { Success = false, Message = "Invalid emote slot." }
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return { Success = false, Message = "Your data is still loading." }
	end

	local loadout = table.clone(playerData.EmoteLoadout or {})
	if request.Action == "Unequip" then
		loadout[tostring(slot)] = nil
		loadout[slot] = nil
	elseif request.Action == "Equip" then
		local emoteName = request.EmoteName
		local ownedCount = type(emoteName) == "string"
			and playerData.Inventory
			and playerData.Inventory.Emotes
			and tonumber(playerData.Inventory.Emotes[emoteName])
		if not ownedCount or ownedCount <= 0 or not EmoteData.ByName[emoteName] then
			return { Success = false, Message = "You do not own this emote." }
		end

		for existingSlot, equippedName in loadout do
			if equippedName == emoteName then
				loadout[existingSlot] = nil
			end
		end
		loadout[tostring(slot)] = emoteName
		loadout[slot] = nil
	else
		return { Success = false, Message = "Invalid emote action." }
	end

	DataService:UpdateData(player, "EmoteLoadout", loadout)
	return { Success = true, Loadout = loadout }
end

function EmoteService.StopEmote(player: Player): boolean
	local state = playerStates[player]
	if state then
		return state:Stop()
	end
	return false
end

function EmoteService.Init(services)
	DataService = services:GetService("DataService")
end

function EmoteService.Start()
	local runtimeRemotes = ReplicatedStorage:FindFirstChild("RuntimeRemotes")
	if not runtimeRemotes then
		runtimeRemotes = Instance.new("Folder")
		runtimeRemotes.Name = "RuntimeRemotes"
		runtimeRemotes.Parent = ReplicatedStorage
	end
	local loadoutRemote = runtimeRemotes:FindFirstChild(LOADOUT_REMOTE_NAME)
	if not loadoutRemote then
		loadoutRemote = Instance.new("RemoteFunction")
		loadoutRemote.Name = LOADOUT_REMOTE_NAME
		loadoutRemote.Parent = runtimeRemotes
	end
	assert(loadoutRemote:IsA("RemoteFunction"), "Emote loadout remote must be a RemoteFunction")
	loadoutRemote.OnServerInvoke = function(player: Player, request: any)
		return EmoteService.UpdateLoadout(player, request)
	end

	local function onPlayerAdded(player: Player)
		playerStates[player] = PlayerEmoteState.new(player)

		player.CharacterRemoving:Connect(function()
			local state = playerStates[player]
			if state then
				state:Stop()
			end
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		local state = playerStates[player]
		if state then
			state:Destroy()
			playerStates[player] = nil
		end
	end)

	Net.EmoteService.RequestPlayEmote.On(function(player: Player, data: { EmoteId: string }): boolean
		return EmoteService.PlayEmote(player, data.EmoteId)
	end)

	Net.EmoteService.RequestStopEmote.On(function(player: Player): boolean
		return EmoteService.StopEmote(player)
	end)
end

return EmoteService
