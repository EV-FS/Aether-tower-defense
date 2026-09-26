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
		self:_SyncPassives()
	end
end

function PassiveComponent:_SyncPassives()
	local remainingPassives = table.clone(self.ActivePassives)
	table.clear(self.ActivePassives)

	for _, config in self.Passives do
		local passive
		for index, activePassive in remainingPassives do
			if activePassive.Config.Type == config.Type then
				passive = table.remove(remainingPassives, index)
				break
			end
		end

		if passive then
			passive:UpdateConfig(config)
			table.insert(self.ActivePassives, passive)
			continue
		end

		local module = script.Passives:FindFirstChild(config.Type)
		if not module then
			warn(`알 수 없는 패시브: {config.Type}.`)
			continue
		end

		table.insert(self.ActivePassives, require(module).new(self.Tower, config, self.FireTriggered))
	end

	for _, passive in remainingPassives do
		passive:Destroy()
	end
end

function PassiveComponent:Start()
	self.Started = true
	self:_SyncPassives()
end

function PassiveComponent:_DestroyPassives()
	for _, passive in self.ActivePassives do
		passive:Destroy()
	end

	table.clear(self.ActivePassives)
end

function PassiveComponent:Destroy()
	self.Started = false

	self:_DestroyPassives()
end

return PassiveComponent
