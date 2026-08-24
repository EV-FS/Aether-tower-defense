local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)
local Config = require(ReplicatedStorage.AFKConfig)

local PlayerStore = ProfileStore.New(Config.ProfileStoreName, DataConstants.PROFILE_TEMPLATE)
local profiles: { [Player]: any } = {}
local returnPlaceIds: { [Player]: number } = {}

local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "AFKState"
stateEvent.Parent = ReplicatedStorage

local returnEvent = Instance.new("RemoteEvent")
returnEvent.Name = "ReturnToLobby"
returnEvent.Parent = ReplicatedStorage

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for _, currencyName in { "Coins", "Gems" } do
		local value = leaderstats:FindFirstChild(currencyName) or Instance.new("IntValue")
		value.Name = currencyName
		value.Value = data[currencyName] or 0
		value.Parent = leaderstats
	end
end

local function sendState(player: Player, playtime: number, data)
	stateEvent:FireClient(player, {
		Playtime = playtime,
		Coins = data.Coins or 0,
		Gems = data.Gems or 0,
	})
end

local function endProfile(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
		profiles[player] = nil
	end
end

local function loadPlayer(player: Player)
	player:SetAttribute("IsAFKWorld", true)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})
	if not profile then
		player:Kick("Data load failed. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profiles[player] = profile
	local teleportData = player:GetJoinData().TeleportData
	returnPlaceIds[player] = if type(teleportData) == "table" then teleportData.ReturnPlaceId or Config.DefaultReturnPlaceId else Config.DefaultReturnPlaceId
	updateLeaderstats(player, profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)

	local playtime = 0
	sendState(player, playtime, profile.Data)
	while player:IsDescendantOf(Players) and profiles[player] == profile do
		task.wait(Config.RewardInterval)
		if profiles[player] ~= profile then
			break
		end

		playtime += Config.RewardInterval
		profile.Data.Coins = (profile.Data.Coins or 0) + Config.CoinsPerInterval
		profile.Data.Gems = (profile.Data.Gems or 0) + Config.GemsPerInterval
		updateLeaderstats(player, profile.Data)
		profile:Save()
		sendState(player, playtime, profile.Data)
	end
end

returnEvent.OnServerEvent:Connect(function(player)
	local placeId = returnPlaceIds[player]
	if not placeId or placeId == 0 then
		return
	end

	local success, err = pcall(function()
		TeleportService:Teleport(placeId, player)
	end)
	if not success then
		warn(`[AFKWorld] Failed to return {player.Name} to lobby: {err}`)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)
Players.PlayerRemoving:Connect(endProfile)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		endProfile(player)
	end
end)
