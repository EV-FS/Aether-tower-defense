--/Services
local BaseService = {}

--/Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyService
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local Net = require(ReplicatedStorage.Shared.Net)

--/Variables
BaseService.MaxHealth = GameSettings.BaseHealth
BaseService.Health = BaseService.MaxHealth

--/Signals
BaseService.HealthChanged = Signal.new()
BaseService.BaseDestroyed = Signal.new()

function BaseService:TakeDamage(amount: number)
	if self.Health <= 0 then
		return
	end

	self.Health = math.max(0, self.Health - amount)

	self.HealthChanged:Fire(self.Health, self.MaxHealth)
	Net.BaseService.BaseHealthChanged.FireAll(self.Health)

	if self.Health <= 0 then
		self.BaseDestroyed:Fire()
	end
end

function BaseService:OnEnemyReachedBase(enemy)
	local damage = enemy.Health or 1

	self:TakeDamage(damage)

	enemy:Destroy()
end

function BaseService:Reset()
	self.Health = self.MaxHealth
	self.HealthChanged:Fire(self.Health, self.MaxHealth)
	Net.BaseService.BaseHealthChanged.FireAll(self.Health)
end

function BaseService.Init(services)
	EnemyService = services:GetService("EnemyService")
end

function BaseService.Start()
	EnemyService.EnemyReached:Connect(function(enemy)
		BaseService:OnEnemyReachedBase(enemy)
	end)
end

return BaseService
