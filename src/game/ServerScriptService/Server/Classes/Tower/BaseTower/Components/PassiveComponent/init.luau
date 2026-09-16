local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local PassiveComponent = {}
PassiveComponent.__index = PassiveComponent

function PassiveComponent.new(tower, passives)
	local self = setmetatable({}, PassiveComponent)
	self.Tower = tower
	self.Passives = passives or {}
	self.ActivePassives = {}
	self.Started = false

	self.FireTriggered = function(passiveType: string, arg: { any }?)
		Net.TowerService.PassiveTriggered.FireAll({
			towerId = self.Tower.Id,
			passiveType = passiveType,
			["arg"] = arg,
		})
	end

	return self
end

function PassiveComponent:SetStats(passives)
	self.Passives = passives or {}

	if self.Started then
		self:_Rebuild()
	end
end

function PassiveComponent:_Rebuild()
	self:_DestroyPassives()

	for _, config in self.Passives do
		local module = script.Passives:FindFirstChild(config.Type)
		if not module then
			warn(`알 수 없는 패시브: {config.Type}.`)
			continue
		end

		table.insert(self.ActivePassives, require(module).new(self.Tower, config, self.FireTriggered))
	end
end

function PassiveComponent:Start()
	self.Started = true
	self:_Rebuild()
end

function PassiveComponent:_DestroyPassives()
	for _, passive in self.ActivePassives do
		passive:Destroy()
	end

	table.clear(self.ActivePassives)
end

function PassiveComponent:Destroy()
	self.Started = false

	for _, passive in self.ActivePassives do
		passive:Destroy()
	end

	table.clear(self.ActivePassives)
end

return PassiveComponent
