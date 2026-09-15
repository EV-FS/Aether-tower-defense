--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Net = require(ReplicatedStorage.Shared.Net)
local Room = require(script.Room)

--/Constants
local DEFAULT_MAX_PLAYERS = 5
local IN_GAME_PLACE_ID = 103108686790798

-------------------------------------------------
--// RoomService
-------------------------------------------------
local RoomService = {}
RoomService.Rooms = {}
RoomService.CurrentId = 1

function RoomService.Init() end

function RoomService.Start()
	Net.RoomService.GetRooms.On(function()
		return RoomService:GetRooms()
	end)

	Net.RoomService.RequestJoin.On(function(player: Player, roomId: number)
		return RoomService:JoinRoom(player, roomId)
	end)
	Net.RoomService.RequestStart.On(function(player: Player, roomId: number)
		print(player, roomId)
		return RoomService:StartGame(player, roomId)
	end)
	Net.RoomService.RequestLeave.On(function(player: Player, roomId: number)
		print(player, roomId)
		return RoomService:LeaveRoom(player, roomId)
	end)
	Net.RoomService.RequestCreate.On(
		function(player: Player, data: { MaxPlayers: number, OnlyFriends: boolean, Map: string, Difficulty: string })
			local room =
				RoomService:CreateRoom(player, data.MaxPlayers, nil, data.OnlyFriends, data.Map, data.Difficulty)
			if room then
				local roomId = RoomService.CurrentId - 1
				room.Id = roomId
				Net.RoomService.RoomRefreshed.FireAll(RoomService:GetRooms())
				return {
					Success = true,
					RoomId = roomId,
				}
			else
				return {
					Success = false,
					RoomId = 0,
				}
			end
		end
	)
end

function RoomService:CreateRoom(
	leader: Player,
	maxPlayer: number?,
	placeId: number?,
	onlyFriends: boolean?,
	map: string?,
	difficulty: string?
): Room.Room
	local newRoom = Room.new(
		leader,
		maxPlayer or DEFAULT_MAX_PLAYERS,
		placeId or IN_GAME_PLACE_ID,
		if onlyFriends ~= nil then onlyFriends else false,
		map or "DefaultMap",
		difficulty or "Normal"
	)

	self.Rooms[self.CurrentId] = newRoom
	newRoom.Id = self.CurrentId
	self.CurrentId += 1

	return newRoom
end

function RoomService:DisbandRoom(roomId: number): boolean
	local targetRoom = self.Rooms[roomId]
	if not targetRoom then
		return false
	end

	self.Rooms[roomId] = nil
	Net.RoomService.RoomRefreshed.FireAll(self:GetRooms())

	return true
end

function RoomService:JoinRoom(player: Player, roomId: number): boolean
	local targetRoom = self.Rooms[roomId]
	if not targetRoom then
		return false
	end
	if #targetRoom.Players >= targetRoom.MaxPlayers then
		return false
	end

	if targetRoom.OnlyFriends and player ~= targetRoom.Leader then
		local isFriend = false
		local success, err = pcall(function()
			isFriend = player:IsFriendsWithAsync(targetRoom.Leader.UserId)
		end)
		if not success then
			warn("Failed to check friendship status: " .. tostring(err))
			return false
		end
		if not isFriend then
			warn(`Player {player.Name} is not a friend of room leader {targetRoom.Leader.Name}`)
			return false
		end
	end

	local success = targetRoom:Join(player)
	if success then
		Net.RoomService.RoomRefreshed.FireAll(self:GetRooms())
	end

	return success
end

function RoomService:LeaveRoom(player: Player, roomId: number): boolean
	local targetRoom = self.Rooms[roomId]
	if not targetRoom then
		return false
	end

	local success = targetRoom:Leave(player)
	if success then
		if player == targetRoom.Leader or #targetRoom.Players == 0 then
			self:DisbandRoom(roomId)
		else
			Net.RoomService.RoomRefreshed.FireAll(self:GetRooms())
		end
	end

	return success
end

function RoomService:StartGame(player: Player, roomId: number): boolean
	local targetRoom = self.Rooms[roomId]
	if not targetRoom then
		return false
	end
	if player ~= targetRoom.Leader then
		return false
	end

	local success = targetRoom:StartGame(player)
	if success then
		Net.RoomService.RoomStarted.FireList(targetRoom.Players)
	end

	return success
end

function RoomService:GetRooms(): { [number]: Room.Room }
	return self.Rooms
end

return RoomService
