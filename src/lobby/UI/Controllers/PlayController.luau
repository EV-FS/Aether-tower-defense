--/Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local DifficultyColor = require(ReplicatedStorage.Settings.Visuals.DifficultyColor)
local ButtonEffects = require(ReplicatedStorage.Shared.Modules.UI.ButtonEffects)
local Net = require(ReplicatedStorage.Shared.Net.client)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local UIController

--/Fusion setup
local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent

local scope = Fusion:scoped()

--/Constants
local MAXIMUM_PLAYERS = 5

--/UI Instances
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local PlayGuiFolder = MainGui:WaitForChild("PlayGui")
local MainFrame = PlayGuiFolder:WaitForChild("Main")
local CreateFrame = PlayGuiFolder:WaitForChild("Play(Create)")
local JoinFrame = PlayGuiFolder:WaitForChild("Play(Join)")
local RoomFrame = PlayGuiFolder:WaitForChild("Play(Room)")

--/React State
local Rooms = scope:Value({})
local MainVisible = scope:Value(false)
local IsCreateOpen = scope:Value(false)
local IsJoinOpen = scope:Value(false)
local OnlyFriends = scope:Value(false)
local MaxPlayers = scope:Value(5)
local SelectedMap = scope:Value("Chapter 1")
local SelectedDifficulty = scope:Value("Normal")

local CurrentRoom = scope:Computed(function(use)
	local rooms = use(Rooms)
	local localPlayer = Players.LocalPlayer
	for roomId, room in pairs(rooms) do
		if type(room) ~= "table" or not room.Players then
			continue
		end
		for _, ply in ipairs(room.Players) do
			if ply == localPlayer then
				room.Id = roomId
				return room
			end
		end
	end
	return nil
end)

-------------------------------------------------
--// PlayController
-------------------------------------------------
local PlayController = {}

function PlayController:RefreshRooms()
	local success, rooms = Net.RoomService.GetRooms.Invoke():await()
	if success then
		Rooms:set(rooms)
	else
		warn("방 목록 가져오기 실패")
	end
end

function PlayController:CreateRoom(maxPlayersCount: number, onlyFriends: boolean, map: string, difficulty: string)
	local success, result = Net.RoomService.RequestCreate
		.Invoke({
			MaxPlayers = maxPlayersCount,
			OnlyFriends = onlyFriends,
			Map = map,
			Difficulty = difficulty,
		})
		:await()
	if success and result.Success then
		self:RefreshRooms()
		IsCreateOpen:set(false)
	else
		warn("방 생성 실패")
	end
end

function PlayController:JoinRoom(roomId: number)
	local success, joined = Net.RoomService.RequestJoin.Invoke(roomId):await()
	if success and joined then
		self:RefreshRooms()
		IsJoinOpen:set(false)
	else
		warn("방 참가 실패")
	end
end

function PlayController:LeaveRoom()
	local currentRoom = peek(CurrentRoom)
	if not currentRoom then
		return
	end

	local success, left = Net.RoomService.RequestLeave.Invoke(currentRoom.Id):await()
	if success and left then
		self:RefreshRooms()
	else
		warn("방 나가기 실패")
	end
end

function PlayController:StartRoom()
	local currentRoom = peek(CurrentRoom)
	if not currentRoom then
		return
	end

	local success, started = Net.RoomService.RequestStart.Invoke(currentRoom.Id):await()
	if not (success and started) then
		warn("게임 시작 실패")
	end
end

function PlayController.Hydrate()
	--/MainFrame
	scope:Hydrate(MainFrame)({
		Size = scope:Spring(
			scope:Computed(function(use)
				return if use(MainVisible) then UDim2.fromScale(1, 1) else UDim2.fromScale(1.5, 1.5)
			end),
			40,
			2
		),
		Visible = scope:Computed(function(use)
			return use(MainVisible)
		end),
	})

	scope:Hydrate(MainFrame.CreateMatch)({
		[OnEvent("MouseButton1Click")] = function()
			IsCreateOpen:set(true)
			IsJoinOpen:set(false)
		end,
	})
	scope:Hydrate(MainFrame.JoinMatch)({
		[OnEvent("MouseButton1Click")] = function()
			IsCreateOpen:set(false)
			IsJoinOpen:set(true)
		end,
	})
	scope:Hydrate(MainFrame.LeaveButton)({
		[OnEvent("MouseButton1Click")] = function()
			MainVisible:set(false)
			IsCreateOpen:set(false)
			IsJoinOpen:set(false)
		end,
	})

	--/CreateFrame
	scope:Hydrate(CreateFrame)({
		Visible = scope:Computed(function(use)
			return use(IsCreateOpen) and not use(CurrentRoom)
		end),
	})

	scope:Hydrate(CreateFrame.MapSelect)({
		[Children] = scope:ForPairs(MapData, function(_, innerScope, mapName, map)
			local newButton = CreateFrame.MapSelect.Template:Clone()
			newButton.Visible = true
			newButton.Image = map.MapImage
			newButton.MapName.Text = mapName

			return mapName,
				innerScope:Hydrate(newButton)({
					[OnEvent("MouseButton1Click")] = function()
						SelectedMap:set(mapName)
					end,
				})
		end),
	})

	local selectableDiffs = scope:Computed(function(use)
		local currentMap = use(SelectedMap)
		return (currentMap and MapData[currentMap].Difficulties) or {}
	end)
	scope:Hydrate(CreateFrame.LevelSelect)({
		[Children] = scope:ForValues(selectableDiffs, function(use, innerScope, diff)
			local newButton = CreateFrame.LevelSelect.Template:Clone()
			newButton.Visible = true
			newButton.Image = if use(SelectedMap) then MapData[use(SelectedMap)].MapImage else nil
			newButton.Level.Text = diff
			newButton.Level.TextColor3 = DifficultyColor[diff] or Color3.new(1, 1, 1)

			return innerScope:Hydrate(newButton)({
				[OnEvent("MouseButton1Click")] = function()
					SelectedDifficulty:set(diff)
				end,
			})
		end),
	})

	scope:Hydrate(CreateFrame.Description.OnlyFriends)({
		BackgroundColor3 = scope:Computed(function(use)
			return if use(OnlyFriends) then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
		end),
		[OnEvent("MouseButton1Click")] = function()
			OnlyFriends:set(not peek(OnlyFriends))
		end,
	})
	scope:Hydrate(CreateFrame.Description.MapImage)({
		Image = scope:Computed(function(use)
			return if use(SelectedMap) then MapData[use(SelectedMap)].MapImage else nil
		end),
	})
	scope:Hydrate(CreateFrame.Description.MapImage.MapName)({
		Text = scope:Computed(function(use)
			return use(SelectedMap) or ""
		end),
	})
	scope:Hydrate(CreateFrame.Description.MapImage.Level)({
		TextColor3 = scope:Computed(function(use)
			return DifficultyColor[use(SelectedDifficulty)] or Color3.new(1, 1, 1)
		end),
		Text = scope:Computed(function(use)
			return use(SelectedDifficulty) or ""
		end),
	})
	scope:Hydrate(CreateFrame.Description.Amount.Amount)({
		Text = scope:Computed(function(use)
			return use(MaxPlayers)
		end),
	})
	scope:Hydrate(CreateFrame.Description.Amount.Subtract)({
		[OnEvent("MouseButton1Click")] = function()
			MaxPlayers:set(math.max(peek(MaxPlayers) - 1, 1))
		end,
	})
	scope:Hydrate(CreateFrame.Description.Amount.Add)({
		[OnEvent("MouseButton1Click")] = function()
			MaxPlayers:set(math.min(peek(MaxPlayers) + 1, MAXIMUM_PLAYERS))
		end,
	})
	scope:Hydrate(CreateFrame.Description.Create)({
		[OnEvent("MouseButton1Click")] = function()
			PlayController:CreateRoom(peek(MaxPlayers), peek(OnlyFriends), peek(SelectedMap), peek(SelectedDifficulty))
		end,
	})

	scope:Hydrate(CreateFrame.Description.RewardList.Coins.Amount)({
		Text = scope:Computed(function(use)
			local mapName = use(SelectedMap)
			local diff = use(SelectedDifficulty)
			if mapName then
				local rewards = MapData[mapName].Rewards
				local diffRewards = rewards and (rewards[diff] or rewards)
				if diffRewards then
					local text = `{diffRewards.WinCoins}C`
					if diffRewards.WinGems and diffRewards.WinGems > 0 then
						text ..= ` + {diffRewards.WinGems}💎`
					end
					return text
				end
			end
			return "0C"
		end),
	})

	scope:Hydrate(CreateFrame.Description.RewardList.Exp.Amount)({
		Text = scope:Computed(function(use)
			local mapName = use(SelectedMap)
			local diff = use(SelectedDifficulty)
			if mapName then
				local rewards = MapData[mapName].Rewards
				local diffRewards = rewards and (rewards[diff] or rewards)
				if diffRewards then
					return `{diffRewards.WinExp} Exp`
				end
			end
			return "0 Exp"
		end),
	})

	--/JoinFrame
	scope:Hydrate(JoinFrame)({
		Visible = scope:Computed(function(use)
			return use(IsJoinOpen) and not use(CurrentRoom)
		end),
	})

	local joinableRooms = scope:Computed(function(use)
		local rooms = use(Rooms)
		local list = {}
		for roomId, room in pairs(rooms) do
			if type(room) == "table" and room.Players then
				room.Id = roomId
				table.insert(list, room)
			end
		end
		return list
	end)
	scope:Hydrate(JoinFrame.JoinMatch.RoomList)({
		[Children] = scope:ForValues(joinableRooms, function(_, innerScope, room)
			local newButton = JoinFrame.JoinMatch.RoomList.Template:Clone()
			newButton.Visible = true

			newButton.Room.Text = room.Map
			newButton.Leader.Text = room.Leader.DisplayName .. "'s Room"
			newButton.Mode.Text = `Mode: {room.Difficulty}`
			newButton.OnlyFriends.Visible = room.OnlyFriends

			innerScope:Hydrate(newButton.MaxPlayers)({
				Text = scope:Computed(function(use)
					return `Players ({use(#room.Players)}/{room.MaxPlayers})`
				end),
			})
			innerScope:Hydrate(newButton.Join)({
				[OnEvent("MouseButton1Click")] = function()
					PlayController:JoinRoom(room.Id)
				end,
			})
			ButtonEffects.ApplyPressEffect(newButton.Join)

			return innerScope:Hydrate(newButton)({})
		end),
	})

	--/RoomFrame
	scope:Hydrate(RoomFrame)({
		Visible = scope:Computed(function(use)
			return use(CurrentRoom) ~= nil
		end),
	})

	scope:Hydrate(RoomFrame.OnlyFriends)({
		Visible = scope:Computed(function(use)
			local room = use(CurrentRoom)
			return room and room.OnlyFriends == true
		end),
	})
	scope:Hydrate(RoomFrame.Mode)({
		Text = scope:Computed(function(use)
			local room = use(CurrentRoom)
			return `Mode: {room and room.Difficulty}`
		end),
	})
	scope:Hydrate(RoomFrame.Players)({
		Text = scope:Computed(function(use)
			local room = use(CurrentRoom)
			if not room then
				return ""
			end
			return `Players {room.Players and #room.Players}/{room.MaxPlayers}`
		end),
	})

	scope:Hydrate(RoomFrame.StartBtn)({
		Visible = scope:Computed(function(use)
			local room = use(CurrentRoom)
			return room ~= nil and room.Leader == Players.LocalPlayer
		end),
		[OnEvent("MouseButton1Click")] = function()
			PlayController:StartRoom()
		end,
	})

	scope:Hydrate(RoomFrame.LeaveBtn)({
		[OnEvent("MouseButton1Click")] = function()
			PlayController:LeaveRoom()
		end,
	})

	local currrentRoomPlayers = scope:Computed(function(use)
		local room = use(CurrentRoom)
		return (room and room.Players) or {}
	end)
	scope:Hydrate(RoomFrame.PlayersList)({
		Visible = scope:Computed(function(use)
			return use(CurrentRoom) ~= nil
		end),

		[Children] = scope:ForValues(currrentRoomPlayers, function(_, innerScope, player)
			local newButton = RoomFrame.PlayersList.Template:Clone()
			newButton.Visible = true

			local room = peek(CurrentRoom)
			local isHost = room and room.Leader == player
			newButton.PlayerName.Text = `{player.DisplayName}{if isHost then " (👑)" else ""}`

			task.spawn(function()
				local imageUrl = Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
				newButton.PlayerIcon.Image = imageUrl
			end)

			return innerScope:Hydrate(newButton)({})
		end),
	})

	--/Effects
	ButtonEffects.ApplyPressEffect(MainFrame.CreateMatch)
	ButtonEffects.ApplyPressEffect(MainFrame.JoinMatch)
	ButtonEffects.ApplyPressEffect(MainFrame.LeaveButton)
	ButtonEffects.ApplyPressEffect(RoomFrame.StartBtn)
	ButtonEffects.ApplyPressEffect(RoomFrame.LeaveBtn)
end

function PlayController.Init(controllers)
	UIController = controllers.UIController

	Net.RoomService.RoomRefreshed.On(function(rooms)
		Rooms:set(rooms)
	end)

	Net.RoomService.RoomStarted.On(function()
		IsCreateOpen:set(false)
		IsJoinOpen:set(false)
	end)

	task.spawn(function()
		PlayController:RefreshRooms()
		PlayController.Hydrate()
	end)

	for _, part in CollectionService:GetTagged("PlayZone") do
		local newZone = TouchZone.new(part)
		newZone.Touched:Connect(function(player: Player)
			if player == Players.LocalPlayer then
				UIController:CloseAll()
				MainVisible:set(true)
			end
		end)

		newZone:Start()
	end
end

return PlayController
