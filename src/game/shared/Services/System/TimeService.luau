local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Net = require(ReplicatedStorage.Shared.Net)

local ALLOWED_SPEED = { 1, 1.5, 2 }

local ClientSignals = nil

local latestSpeedChangeTime = 0
local latestSpeedCompensation = 0
local TimerConnection

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getPingTime(sendTimeMs: number): number
	local currentTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536
	local difference = (currentTimeMs - sendTimeMs) % 65536
	if difference > 32768 then
		difference -= 65536
	end
	return math.max(0, difference) / 1000
end

local function compensatePing(leftTime: number, lastCheckTime: number): (number, number)
	if latestSpeedChangeTime > lastCheckTime then
		leftTime -= latestSpeedCompensation
		lastCheckTime = latestSpeedChangeTime
	end
	return leftTime, lastCheckTime
end

-------------------------------------------------
--// TimeService
-------------------------------------------------
local TimeService = {}
TimeService.GameSpeed = 1
TimeService.GameTime = 0
TimeService.RealGameTime = 0
TimeService.IsTimerRunning = false

function TimeService.DeltaWait(duration: number): number
	local leftTime = duration
	local lastCheckTime = os.clock()

	while leftTime > 0 do
		leftTime -= RunService.Heartbeat:Wait() * TimeService.GameSpeed
		leftTime, lastCheckTime = compensatePing(leftTime, lastCheckTime)
	end

	return leftTime
end

function TimeService.DeltaDelay(duration: number)
	return Promise.new(function(resolve, _, onCancel)
		if duration <= 0 then
			return resolve()
		end

		local leftTime = duration
		local lastCheckTime = os.clock()
		local connection

		connection = RunService.Heartbeat:Connect(function(dt)
			leftTime -= dt * TimeService.GameSpeed
			leftTime, lastCheckTime = compensatePing(leftTime, lastCheckTime)

			if leftTime <= 0 then
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
	TimeService.GameTime = 0
	TimeService.RealGameTime = 0
	self:_RecordGameTime()
end

function TimeService:StopGameTimer()
	self:_StopRecording()
end

function TimeService:_RecordGameTime()
	if self.IsTimerRunning then
		return
	end
	self.IsTimerRunning = true

	TimerConnection = RunService.Heartbeat:Connect(function(dt)
		self.GameTime += dt * self.GameSpeed
		self.RealGameTime += dt
	end)
end

function TimeService:_StopRecording()
	if not self.IsTimerRunning then
		return
	end
	self.IsTimerRunning = false

	if TimerConnection then
		TimerConnection:Disconnect()
		TimerConnection = nil
	end
end

function TimeService:GetGameSpeed()
	return self.GameSpeed
end

function TimeService:SetGameSpeed(speed: number, pingTime: number?, isForce: boolean?): boolean
	if RunService:IsClient() and not isForce then
		local success = Net.TimeService.ChangeGameSpeed.Invoke(speed * 10):expect()
		return success == true
	end

	local oldSpeed = self.GameSpeed
	self.GameSpeed = speed

	if RunService:IsClient() then
		latestSpeedChangeTime = os.clock()
		latestSpeedCompensation = (pingTime or 0) * (speed - oldSpeed)

		if ClientSignals then
			ClientSignals.GameSpeedChanged:Fire(speed, oldSpeed, pingTime)
		end
	elseif RunService:IsServer() then
		Net.TimeService.GameSpeedChanged.FireAll({
			newSpeed = speed * 10,
			sendTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536,
		})
	end

	return true
end

function TimeService.Init()
	if RunService:IsClient() then
		ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
	end
end

function TimeService.Start()
	if RunService:IsClient() then
		Net.TimeService.GameSpeedChanged.On(function(data: { newSpeed: number, sendTimeMs: number })
			local convertNewSpeed = data.newSpeed / 10
			if typeof(convertNewSpeed) ~= "number" then
				return
			end

			local pingTime = getPingTime(data.sendTimeMs)
			TimeService:SetGameSpeed(convertNewSpeed, pingTime, true)
		end)
	elseif RunService:IsServer() then
		Net.TimeService.ChangeGameSpeed.On(function(_: Player, newSpeed: number): boolean
			local targetSpeed = newSpeed / 10
			if not table.find(ALLOWED_SPEED, targetSpeed) then
				return false
			end

			return TimeService:SetGameSpeed(targetSpeed)
		end)
	end
end

return TimeService
