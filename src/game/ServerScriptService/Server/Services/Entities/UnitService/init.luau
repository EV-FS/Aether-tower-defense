--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local BaseUnit = require(ServerScriptService.Server.Classes.Unit.BaseUnit)
local UnitData = require(ReplicatedStorage.Settings.Data.UnitData)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local Net = require(ReplicatedStorage.Shared.Net)
local UnitRegistry = require(script.Registry)

local TimeService

--/Variables
local isActived = false
local connection

local unitClasses = {}

-------------------------------------------------
--// UnitService
-------------------------------------------------
local UnitService = {}

UnitService.Get = UnitRegistry.get
UnitService.GetAll = UnitRegistry.getAll

function UnitService.Spawn(
	summoner,
	name: string,
	pathAlpha: number?,
	isEnemyType: boolean?,
	customUnitStats: { [string]: any }?
)
	local self
	if unitClasses[name] then
		self = unitClasses[name].new(summoner, UnitRegistry.generateId(), name, pathAlpha, isEnemyType, customUnitStats)
	else
		self = BaseUnit.new(summoner, UnitRegistry.generateId(), name, pathAlpha, isEnemyType, customUnitStats)
	end

	self.Destroyed:Connect(function(forcing: boolean?)
		self.IsDestroyed = true
		if forcing then
			Net.UnitService.UnitDestroyed.FireAll(self.Id)
		end

		UnitRegistry.remove(self.Id)
	end)

	UnitRegistry.add(self)

	UnitService:StartMoveUnits()

	local unitIndex
	if isEnemyType then
		unitIndex = EnemyData.ByName[self.Name].Index
	else
		unitIndex = UnitData.ByName[self.Name].Index
	end

	Net.UnitService.ReplicatedUnit.FireAll({
		unitId = self.Id,
		unitIndex = unitIndex,
		summonerId = summoner.Id,
		sentClockMs = NumberUtils.FormatSendClockTimeMs(),
		pathAlpha = self.PathAlpha and math.round(self.PathAlpha * 65535) or nil,
		isEnemyType = self.IsEnemyType,
	})

	return self
end

function UnitService:StartMoveUnits()
	if isActived then
		return
	end
	isActived = true

	connection = RunService.Heartbeat:Connect(function(dt)
		local toMoveUnits = UnitRegistry.getAll()

		if next(toMoveUnits) == nil then
			isActived = false

			connection:Disconnect()
			connection = nil

			return
		end

		local gameSpeed = TimeService:GetGameSpeed()
		for _, unit in pairs(toMoveUnits) do
			if not unit.PauseEndTime or os.clock() >= unit.PauseEndTime then
				local pathLength = GetPath:Get():GetPathLength()

				unit.PathAlpha -= ((unit.WalkSpeed * dt * gameSpeed) / pathLength)
				unit.PathAlpha = math.clamp(unit.PathAlpha, 0, 1)

				unit.Position = GetPath:Get():CalculateUniformPosition(unit.PathAlpha)
			end

			if unit.PathAlpha <= 0 then
				unit:Destroy()
			end
		end
	end)
end

function UnitService:DestroyAll()
	for _, unit in self.GetAll() do
		unit:Destroy(true)
	end
end

function UnitService.PlayerAdded(player: Player)
	for _, unit in UnitRegistry.getAll() do
		Net.UnitService.ReplicatedUnit.Fire(player, {
			unitId = unit.Id,
			unitIndex = UnitData.ByName[unit.Name].Index,
			summonerId = unit.SummonerId,
			sentClockMs = NumberUtils.FormatSendClockTimeMs(),
		})
	end
end

function UnitService.Init(services)
	TimeService = services:GetService("TimeService")

	local ClassesFolder = ServerScriptService.Server.Classes.Unit
	if ClassesFolder then
		for _, module in pairs(ClassesFolder:GetChildren()) do
			if module:IsA("ModuleScript") and module.Name ~= "BaseUnit" then
				unitClasses[module.Name] = require(module)
			end
		end
	end
end

function UnitService.Start() end

return UnitService
