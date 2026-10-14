local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Net = require(ReplicatedStorage.Shared.Net)

local ALLOWED_SPEED = { 1, 1.5, 2 }

local ClientSignals

type ClockState = {
	clockTime: number,
	serverTime: number,
	gameSpeed: number,
	revision: number,
}

-------------------------------------------------
--// TimeService
-------------------------------------------------
local TimeService = {}
TimeService.GameSpeed = 1
TimeService.GameTime = 0
TimeService.ClockTime = 0
TimeService.RealGameTime = 0
TimeService.IsTimerRunning = false
TimeService.IsSynced = RunService:IsServer()
TimeService.AnchorClock = 0
TimeService.AnchorReal = workspace:GetServerTimeNow()
TimeService.Revision = if TimeService.IsSynced then 0 else -1

function TimeService:Now(): number
	self.ClockTime = self.AnchorClock + (workspace:GetServerTimeNow() - self.AnchorReal) * self.GameSpeed
	return self.ClockTime
end

function TimeService:GetClockState(): ClockState
	return {
		clockTime = self.AnchorClock,
		serverTime = self.AnchorReal,
		gameSpeed = self.GameSpeed,
		revision = self.Revision,
	}
end

function TimeService:_ApplyClockState(state: ClockState)
	-- The initial response can arrive after a newer speed-change event.
	if state.revision <= self.Revision then
		return
	end

	local oldSpeed = self.GameSpeed
	local wasSynced = self.IsSynced
	self.AnchorClock = state.clockTime
	self.AnchorReal = state.serverTime
	self.GameSpeed = state.gameSpeed
	self.Revision = state.revision
	self.IsSynced = true
	self:Now()

	if wasSynced and ClientSignals and oldSpeed ~= self.GameSpeed then
		-- Existing movement/animation listeners expect a delay in real seconds.
		local realDelay = math.max(0, workspace:GetServerTimeNow() - state.serverTime)
		ClientSignals.GameSpeedChanged:Fire(self.GameSpeed, oldSpeed, realDelay)
	end
end

function TimeService.DeltaWait(duration: number): number
	local endsAt = TimeService:Now() + duration
	local leftTime = duration

	while leftTime > 0 do
		RunService.Heartbeat:Wait()
		leftTime = endsAt - TimeService:Now()
	end

	return leftTime
end

function TimeService.DeltaDelay(duration: number)
	local endsAt = TimeService:Now() + duration
	return Promise.new(function(resolve, _, onCancel)
		if duration <= 0 then
			return resolve()
		end

		local connection

		connection = RunService.Heartbeat:Connect(function()
			if TimeService:Now() >= endsAt then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				resolve()
			end
		end)

		onCancel(function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end)

		return
	end)
end

function TimeService:StartGameTimer()
	self.GameTime = 0
	self.RealGameTime = 0
	self._TimerClockStart = self:Now()
	self._TimerRealStart = workspace:GetServerTimeNow()
	self.IsTimerRunning = true
end

function TimeService:StopGameTimer()
	if self.IsTimerRunning then
		self.GameTime = self:Now() - self._TimerClockStart
		self.RealGameTime = workspace:GetServerTimeNow() - self._TimerRealStart
		self.IsTimerRunning = false
	end
end

function TimeService:GetGameSpeed()
	return self.GameSpeed
end

function TimeService:SetGameSpeed(speed: number): boolean
	if typeof(speed) ~= "number" or speed ~= speed or speed < 0 or speed == math.huge then
		return false
	end

	if RunService:IsClient() then
		if not table.find(ALLOWED_SPEED, speed) then
			return false
		end
		return Net.TimeService.ChangeGameSpeed.Invoke(speed * 10):expect() == true
	end

	if speed == self.GameSpeed then
		return true
	end

	-- Sample once so changing speed keeps the timeline continuous.
	local serverTime = workspace:GetServerTimeNow()
	self.AnchorClock += (serverTime - self.AnchorReal) * self.GameSpeed
	self.AnchorReal = serverTime
	self.GameSpeed = speed
	self.Revision += 1
	self:Now()
	Net.TimeService.GameSpeedChanged.FireAll(self:GetClockState())
	return true
end

function TimeService.Init()
	if RunService:IsServer() then
		Net.TimeService.GetClockState.On(function(): ClockState
			return TimeService:GetClockState()
		end)
		Net.TimeService.ChangeGameSpeed.On(function(_: Player, newSpeed: number): boolean
			local speed = newSpeed / 10
			return table.find(ALLOWED_SPEED, speed) ~= nil and TimeService:SetGameSpeed(speed)
		end)
	else
		ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
		Net.TimeService.GameSpeedChanged.On(function(state: ClockState)
			TimeService:_ApplyClockState(state)
		end)
		TimeService:_ApplyClockState(Net.TimeService.GetClockState.Invoke():expect())
	end
end

function TimeService.Start()
	RunService.Heartbeat:Connect(function()
		local clockTime = TimeService:Now()
		if TimeService.IsTimerRunning then
			TimeService.GameTime = clockTime - TimeService._TimerClockStart
			TimeService.RealGameTime = workspace:GetServerTimeNow() - TimeService._TimerRealStart
		end
	end)
end

return TimeService
