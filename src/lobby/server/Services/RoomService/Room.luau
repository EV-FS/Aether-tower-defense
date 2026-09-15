local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeTeleport = require(ReplicatedStorage.Shared.Modules.Core.SafeTeleport)

local TELEPORT_OPTIONS = Instance.new("TeleportOptions")
TELEPORT_OPTIONS.ShouldReserveServer = true

--/Types
export type Room = {
	Leader: Player,
	Players: { Player },
	MaxPlayers: number,
	OnlyFriends: boolean,
	Map: string,
	Difficulty: string,
}

-------------------------------------------------
--// Room
-------------------------------------------------
local Room = {}
Room.__index = Room

function Room.new(
	leader: Player,
	maxPlayer: number,
	placeId: number,
	onlyFriends: boolean,
	map: string,
	difficulty: string
): Room
	local self = setmetatable({} :: Room, Room)
	self.Leader = leader
	self.Players = { leader }
	self.MaxPlayers = maxPlayer
	self.OnlyFriends = onlyFriends
	self.Map = map
	self.Difficulty = difficulty

	self.PlaceId = placeId
	self.IsTeleporting = false

	return self
end

function Room:Join(player: Player): boolean
	if #self.Players >= self.MaxPlayers then
		return false
	end

	table.insert(self.Players, player)
	return true
end

function Room:Leave(player: Player): boolean
	local targetIndex = table.find(self.Players, player)
	if not targetIndex then
		return false
	end

	table.remove(self.Players, targetIndex)
	return true
end

function Room:StartGame(player: Player): boolean
	if player ~= self.Leader then
		return false
	end
	if self.IsTeleporting then
		return false
	end

	self.IsTeleporting = true
	task.spawn(function()
		local teleportOptions = Instance.new("TeleportOptions")
		teleportOptions.ShouldReserveServer = true
		teleportOptions:SetTeleportData({
			Map = self.Map,
			Difficulty = self.Difficulty,
		})

		local success, result = SafeTeleport(self.PlaceId, table.clone(self.Players), teleportOptions)
		if not success then
			warn("텔레포트 실패:", result)
			self.IsTeleporting = false
		end
	end)

	return true
end

return Room
