-- Add a ModuleScript under Definitions and compose its components with
-- Components.luau. The registry discovers, validates, and indexes it automatically.
local Definitions = script:WaitForChild("Definitions")

export type QuestEntity = {
	Id: string,
	Presentation: {
		Theme: string,
		Title: string,
		Description: string,
		NpcId: string?,
	},
	Objective: {
		Kind: "Currency" | "MapClear",
		Target: string,
		Amount: number,
	},
	Lifecycle: {
		AutoAccept: boolean,
		AutoClaim: boolean,
	},
	Rewards: { [string]: number? },
}

export type QuestConfig = {
	Id: string,
	Theme: string,
	Title: string,
	Description: string,
	TargetCurrency: string?,
	TargetMap: string?,
	TargetAmount: number,
	NpcId: string?,
	AutoAccept: boolean,
	AutoClaim: boolean,
	Rewards: { [string]: number? },
	Entity: QuestEntity,
}

local byId: { [string]: QuestConfig } = {}
local ordered: { QuestConfig } = {}
local byObjectiveKind: { [string]: { QuestConfig } } = {}
local byNpcId: { [string]: { QuestConfig } } = {}
local byLifecycleFlag: { [string]: { QuestConfig } } = {
	AutoAccept = {},
	AutoClaim = {},
}

local function validateEntity(entity: QuestEntity, moduleName: string)
	assert(type(entity) == "table", `{moduleName} must return a quest entity table`)
	assert(type(entity.Id) == "string" and entity.Id ~= "", `{moduleName} requires an Id`)
	assert(entity.Id == moduleName, `{moduleName} must use the same quest Id as its module name`)
	assert(entity.Presentation ~= nil, `{entity.Id} requires a Presentation component`)
	assert(entity.Objective ~= nil, `{entity.Id} requires an Objective component`)
	assert(entity.Lifecycle ~= nil, `{entity.Id} requires a Lifecycle component`)
	assert(entity.Rewards ~= nil, `{entity.Id} requires a Rewards component`)
	assert(
		entity.Objective.Kind == "Currency" or entity.Objective.Kind == "MapClear",
		`{entity.Id} has an unsupported objective kind`
	)
	assert(type(entity.Objective.Target) == "string" and entity.Objective.Target ~= "", `{entity.Id} requires an objective target`)
	assert(entity.Objective.Amount > 0, `{entity.Id} objective amount must be greater than zero`)
	for rewardName, amount in entity.Rewards do
		assert(type(rewardName) == "string" and rewardName ~= "", `{entity.Id} has an invalid reward name`)
		assert(type(amount) == "number" and amount >= 0, `{entity.Id} reward {rewardName} must be non-negative`)
	end
	assert(byId[entity.Id] == nil, `Duplicate quest Id: {entity.Id}`)
end

local function compile(entity: QuestEntity): QuestConfig
	local objective = entity.Objective
	local presentation = entity.Presentation
	local lifecycle = entity.Lifecycle

	return table.freeze({
		Id = entity.Id,
		Theme = presentation.Theme,
		Title = presentation.Title,
		Description = presentation.Description,
		TargetCurrency = if objective.Kind == "Currency" then objective.Target else nil,
		TargetMap = if objective.Kind == "MapClear" then objective.Target else nil,
		TargetAmount = objective.Amount,
		NpcId = presentation.NpcId,
		AutoAccept = lifecycle.AutoAccept,
		AutoClaim = lifecycle.AutoClaim,
		Rewards = entity.Rewards,
		Entity = entity,
	})
end

local modules = Definitions:GetChildren()
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

for _, moduleScript in modules do
	if moduleScript:IsA("ModuleScript") then
		local entity = require(moduleScript) :: QuestEntity
		validateEntity(entity, moduleScript.Name)

		local config = compile(entity)
		byId[config.Id] = config
		table.insert(ordered, config)

		local objectiveList = byObjectiveKind[entity.Objective.Kind]
		if not objectiveList then
			objectiveList = {}
			byObjectiveKind[entity.Objective.Kind] = objectiveList
		end
		table.insert(objectiveList, config)

		if config.NpcId then
			local npcList = byNpcId[config.NpcId]
			if not npcList then
				npcList = {}
				byNpcId[config.NpcId] = npcList
			end
			table.insert(npcList, config)
		end

		for flagName, list in byLifecycleFlag do
			if entity.Lifecycle[flagName] then
				table.insert(list, config)
			end
		end
	end
end

for _, list in byObjectiveKind do
	table.freeze(list)
end
for _, list in byLifecycleFlag do
	table.freeze(list)
end
for _, list in byNpcId do
	table.freeze(list)
end

local QuestRegistry = {
	ById = table.freeze(byId),
	Ordered = table.freeze(ordered),
}

function QuestRegistry.Get(questId: string): QuestConfig?
	return byId[questId]
end

function QuestRegistry.QueryObjective(kind: string, target: string?): { QuestConfig }
	local matches = byObjectiveKind[kind] or {}
	if target == nil then
		return matches
	end

	local filtered = {}
	for _, config in matches do
		if config.Entity.Objective.Target == target then
			table.insert(filtered, config)
		end
	end
	return filtered
end

function QuestRegistry.QueryLifecycle(flagName: "AutoAccept" | "AutoClaim"): { QuestConfig }
	return byLifecycleFlag[flagName] or {}
end

function QuestRegistry.QueryNpc(npcId: string): { QuestConfig }
	return byNpcId[npcId] or {}
end

return table.freeze(QuestRegistry)
