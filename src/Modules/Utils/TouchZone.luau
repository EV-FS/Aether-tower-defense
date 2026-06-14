local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Signal = require(ReplicatedStorage.Packages.Signal)

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetCharacters()
	local characters = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			characters[#characters + 1] = character
		end
	end

	return characters
end

local function GetPlayerFromPart(part: BasePart): (Player?, Model?)
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	return player, character
end

-------------------------------------------------
--// TouchZone
-------------------------------------------------
local TouchZone = {}
TouchZone.__index = TouchZone

TouchZone.DefaultInterval = 0.2

function TouchZone.new(zonePart: BasePart)
	local self = setmetatable({}, TouchZone)

	self.ZonePart = zonePart
	self.Interval = TouchZone.DefaultInterval
	self.OverlapParams = OverlapParams.new()
	self.OverlapParams.FilterType = Enum.RaycastFilterType.Include
	self.OverlapParams.FilterDescendantsInstances = {}

	self.Touched = Signal.new()
	self.TouchEnded = Signal.new()

	self._inside = {}
	self._elapsed = 0
	self._connection = nil

	return self
end

function TouchZone:Start()
	if self._connection then
		return
	end

	self._connection = RunService.Heartbeat:Connect(function(dt)
		self._elapsed += dt

		if self._elapsed < self.Interval then
			return
		end

		self._elapsed = 0
		self:_Update()
	end)
end

function TouchZone:Stop()
	if not self._connection then
		return
	end

	self._connection:Disconnect()
	self._connection = nil
end

function TouchZone:Destroy()
	self:Stop()

	self.Touched:Destroy()
	self.TouchEnded:Destroy()

	table.clear(self._inside)
	table.clear(self)
end

function TouchZone:_GetCurrent(): { [Player]: Model }
	local current = {}

	self.OverlapParams.FilterDescendantsInstances = GetCharacters()

	for _, part in workspace:GetPartsInPart(self.ZonePart, self.OverlapParams) do
		local player, character = GetPlayerFromPart(part)

		if player then
			current[player] = character
		end
	end

	return current
end

function TouchZone:_Update()
	local current = self:_GetCurrent()

	for player, character in current do
		if self._inside[player] then
			continue
		end

		self._inside[player] = character
		self.Touched:Fire(player, character)
	end

	for player, character in self._inside do
		if current[player] then
			continue
		end

		self._inside[player] = nil
		self.TouchEnded:Fire(player, character)
	end
end

function TouchZone:IsTouching(player: Player): boolean
	return self._inside[player] ~= nil
end

return TouchZone
