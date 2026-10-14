local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)
local TimeService

local syncRevision = 0
local function getSyncStamp(): number
	syncRevision += 1
	return syncRevision
end

local SkillComponent = {}
SkillComponent.__index = SkillComponent

function SkillComponent.new(tower, skills)
	local self = setmetatable({}, SkillComponent)
	self.Tower = tower
	self.Skills = skills or {}
	self.ActiveSkills = {}
	self.Started = false
	self.IsDestroyed = false

	self.FireTriggered = function(skillName: string, arg: any?)
		if self.IsDestroyed or self.Tower.IsDestroyed then
			return
		end

		Net.TowerService.SkillTriggered.FireAll({
			towerId = self.Tower.Id,
			skillName = skillName,
			arg = arg,
		})
	end

	return self
end

function SkillComponent:Start()
	if self.Started or self.IsDestroyed then
		return
	end
	self.Started = true
	self:_Rebuild()
end

function SkillComponent:SetStats(skills)
	if self.IsDestroyed then
		return
	end
	self.Skills = skills or {}

	if self.Started then
		self:_Rebuild()
	end
end

function SkillComponent:UseSkill(skillName: string)
	if self.IsDestroyed or self.Tower.IsDestroyed then
		return false
	end
	local skill = self.ActiveSkills[skillName]
	if not skill then
		warn(`알 수 없는 스킬: {skillName}.`)
		return false
	end
	if self.Tower.StunRemaining > 0 then
		return false
	end

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	local now = TimeService:Now()
	if now < skill.ReadyAt then
		self:_SyncClient()
		return false
	end

	if not skill:Validate() then
		return false
	end

	local previousReadyAt = skill.ReadyAt
	skill.ReadyAt = now + skill.Config.Cooldown

	if skill:Use() == false then
		skill.ReadyAt = previousReadyAt
		self:_SyncClient()
		return false
	end

	self:_SyncClient()
	return true
end

function SkillComponent:_BuildSkill(config)
	local module = script.Skills:FindFirstChild(config.Name)
	if not module then
		warn(`알 수 없는 스킬: {config.Name}.`)
		return
	end

	local skill = require(module).new(self.Tower, config, self.FireTriggered)
	skill.Name = config.Name
	skill.Config = config
	skill.ReadyAt = skill.ReadyAt or 0

	if typeof(skill.SetStats) ~= "function" then
		function skill:SetStats(config)
			self.Config = config
		end
	end

	self.ActiveSkills[skill.Name] = skill

	return skill
end

function SkillComponent:_Rebuild()
	if self._Rebuilding then
		return
	end
	self._Rebuilding = true
	local seen = {}

	for key, config in self.Skills do
		if config.Name == nil and type(key) == "string" then
			config = table.clone(config)
			config.Name = key
		end
		if type(config.Name) ~= "string" then
			warn("스킬 이름이 없는 설정입니다.")
			continue
		end

		seen[config.Name] = true
		local skill = self.ActiveSkills[config.Name]

		if skill then
			skill:SetStats(config)
		else
			self:_BuildSkill(config)
		end
	end

	for _, skill in self.ActiveSkills do
		if not seen[skill.Name] then
			self.ActiveSkills[skill.Name] = nil
			skill:Destroy()
		end
	end
	self._Rebuilding = false
	self:_SyncClient()
end

function SkillComponent:_SyncClient()
	local skills = {}
	for skillName, skill in self.ActiveSkills do
		skills[skillName] = {
			Config = skill.Config,
			ReadyAt = skill.ReadyAt,
		}
	end

	local revision = getSyncStamp()
	Net.TowerService.SkillsUpdated.Fire(self.Tower.Owner, {
		towerId = self.Tower.Id,
		skills = skills,
		revision = revision,
	})
end

function SkillComponent:GetCooldownState(skillName: string)
	local skill = self.ActiveSkills[skillName]
	local revision = getSyncStamp()
	return {
		readyAt = if skill then skill.ReadyAt else nil,
		revision = revision,
	}
end

function SkillComponent:Destroy()
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true
	self.Started = false

	for _, skill in self.ActiveSkills do
		self.ActiveSkills[skill.Name] = nil
		skill:Destroy()
	end

	table.clear(self.ActiveSkills)
	self:_SyncClient()
end

return SkillComponent
