local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local InputService
local TimeService

local HOTKEYS = {
	Enum.KeyCode.Q,
	Enum.KeyCode.F,
	Enum.KeyCode.G,
	Enum.KeyCode.H,
	Enum.KeyCode.J,
	Enum.KeyCode.K,
}

export type Skill = {
	TowerId: number,
	Config: { [string]: any },
	ReadyAt: number,
	IsRequesting: boolean,
	SyncedAt: number,
	CooldownRevision: number,
}

export type Group = {
	Name: string,
	Slot: number,
	Key: Enum.KeyCode?,
	Towers: { [number]: Skill },
}

type Snapshot = {
	towerId: number,
	skills: { [string]: { Config: { [string]: any }, CooldownLeft: number } },
	sendTimeMs: number,
	revision: number,
}

local started = false
local speedChanges: { { Time: number, Before: number } } = {}

local TowerSkills = {}
TowerSkills.GroupByName = {} :: { [string]: Group }
TowerSkills.GroupByKey = {} :: { [Enum.KeyCode]: Group }

-------------------------------------------------
--// Cooldown synchronization
-------------------------------------------------
local function getSentAt(sendTimeMs: number, now: number): number
	local currentTimeMs = math.floor(now * 1000) % 65536
	local difference = (currentTimeMs - sendTimeMs) % 65536
	if difference > 32768 then
		difference -= 65536
	end
	return now - math.max(0, difference) / 1000
end

local function getElapsedGameTime(sentAt: number, now: number): number
	local elapsed = 0
	local speed = TimeService:GetGameSpeed()
	local cursor = now

	for i = #speedChanges, 1, -1 do
		local change = speedChanges[i]
		if change.Time <= sentAt then
			break
		end
		elapsed += (cursor - change.Time) * speed
		cursor = change.Time
		speed = change.Before
	end
	return elapsed + (cursor - sentAt) * speed
end

local function syncCooldown(skill: Skill, cooldownLeft: number, sendTimeMs: number, revision: number)
	if revision <= skill.CooldownRevision then
		return
	end
	local now = workspace:GetServerTimeNow()
	local sentAt = getSentAt(sendTimeMs, now)
	skill.CooldownRevision = revision
	skill.SyncedAt = sentAt
	skill.ReadyAt = TimeService:Now() + cooldownLeft - getElapsedGameTime(sentAt, now)
end

function TowerSkills._OnGameSpeedChanged(newSpeed: number, oldSpeed: number, pingTime: number?)
	local now = workspace:GetServerTimeNow()
	local changedAt = now - (pingTime or 0)

	table.insert(speedChanges, { Time = changedAt, Before = oldSpeed })

	while speedChanges[1] and speedChanges[1].Time < now - 32.768 do
		table.remove(speedChanges, 1)
	end

	for _, group in TowerSkills.GroupByName do
		for _, skill in group.Towers do
			local elapsed = math.max(0, now - math.max(changedAt, skill.SyncedAt))
			skill.ReadyAt -= elapsed * (newSpeed - oldSpeed)
		end
	end
	ClientSignals.SkillsChanged:Fire()
end

-------------------------------------------------
--// Groups and server snapshots
-------------------------------------------------
local function createGroup(skillName: string): Group
	local usedSlots = {}
	for _, group in TowerSkills.GroupByName do
		usedSlots[group.Slot] = true
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end

	local group: Group = {
		Name = skillName,
		Slot = slot,
		Key = HOTKEYS[slot],
		Towers = {},
	}

	TowerSkills.GroupByName[skillName] = group
	if group.Key then
		TowerSkills.GroupByKey[group.Key] = group
	end
	return group
end

local function removeSkill(group: Group, towerId: number)
	group.Towers[towerId] = nil

	if not next(group.Towers) then
		TowerSkills.GroupByName[group.Name] = nil
		if group.Key then
			TowerSkills.GroupByKey[group.Key] = nil
		end
	end
end

function TowerSkills._SyncSkills(data: Snapshot)
	for skillName, group in TowerSkills.GroupByName do
		if group.Towers[data.towerId] and not data.skills[skillName] then
			removeSkill(group, data.towerId)
		end
	end

	local skillNames = {}
	for skillName in data.skills do
		table.insert(skillNames, skillName)
	end
	table.sort(skillNames)

	for _, skillName in skillNames do
		local dataSkill = data.skills[skillName]
		local group = TowerSkills.GroupByName[skillName] or createGroup(skillName)

		local skill = group.Towers[data.towerId]
		if not skill then
			skill = {
				TowerId = data.towerId,
				Config = dataSkill.Config,
				ReadyAt = 0,
				IsRequesting = false,
				SyncedAt = 0,
				CooldownRevision = 0,
			}
			group.Towers[data.towerId] = skill
		end

		skill.Config = dataSkill.Config
		syncCooldown(skill, dataSkill.CooldownLeft, data.sendTimeMs, data.revision)
	end
	ClientSignals.SkillsChanged:Fire()
end

function TowerSkills.RemoveTower(towerId: number)
	local changed = false
	for _, group in TowerSkills.GroupByName do
		if group.Towers[towerId] then
			removeSkill(group, towerId)
			changed = true
		end
	end

	if changed then
		ClientSignals.SkillsChanged:Fire()
	end
end

-------------------------------------------------
--// Public API
-------------------------------------------------
function TowerSkills.GetGroups(): { Group }
	local groups = {}
	for _, group in TowerSkills.GroupByName do
		table.insert(groups, group)
	end
	table.sort(groups, function(a, b)
		return a.Slot < b.Slot
	end)
	return groups
end

function TowerSkills.GetGroup(skillName: string): Group?
	return TowerSkills.GroupByName[skillName]
end

function TowerSkills.GetSkill(towerId: number, skillName: string): Skill?
	local group = TowerSkills.GroupByName[skillName]
	return if group then group.Towers[towerId] else nil
end

function TowerSkills.GetCooldown(towerId: number, skillName: string): number
	local skill = TowerSkills.GetSkill(towerId, skillName)
	return if skill then math.max(0, skill.ReadyAt - TimeService:Now()) else 0
end

function TowerSkills.CanUseSkill(towerId: number, skillName: string): boolean
	local skill = TowerSkills.GetSkill(towerId, skillName)
	return skill ~= nil and not skill.IsRequesting and skill.ReadyAt <= TimeService:Now()
end

function TowerSkills.UseSkill(towerId: number, skillName: string): boolean
	local skill = TowerSkills.GetSkill(towerId, skillName)
	if not skill or not TowerSkills.CanUseSkill(towerId, skillName) then
		return false
	end
	skill.IsRequesting = true
	ClientSignals.SkillsChanged:Fire()

	local ok, response = Net.TowerService.UseSkill
		.Invoke({
			towerId = towerId,
			skillName = skillName,
		})
		:await()

	if TowerSkills.GetSkill(towerId, skillName) == skill then
		skill.IsRequesting = false
		if ok and response.cooldownLeft ~= nil then
			syncCooldown(skill, response.cooldownLeft, response.sendTimeMs, response.revision)
		end
		ClientSignals.SkillsChanged:Fire()
	end
	if not ok then
		warn(`스킬 사용 요청 실패: {response}`)
	end
	return ok and response.success == true
end

function TowerSkills.UseGroup(skillName: string): boolean
	local group = TowerSkills.GroupByName[skillName]
	if not group then
		return false
	end
	local selectedId: number? = nil
	for towerId in group.Towers do
		if TowerSkills.CanUseSkill(towerId, skillName) and (not selectedId or towerId < selectedId) then
			selectedId = towerId
		end
	end
	return if selectedId then TowerSkills.UseSkill(selectedId, skillName) else false
end

function TowerSkills.UseKey(key: Enum.KeyCode): boolean
	local group = TowerSkills.GroupByKey[key]
	return if group then TowerSkills.UseGroup(group.Name) else false
end

-------------------------------------------------
--// Lifecycle
-------------------------------------------------
function TowerSkills.Init(services)
	InputService = services:GetService("InputService")
	TimeService = services:GetService("TimeService")
end

function TowerSkills.Start()
	if started then
		return
	end
	started = true

	local actions = {}
	for slot, key in HOTKEYS do
		local action = InputService.Action(`TowerSkill{slot}`, InputService.Info({ key }))
		action.Began:Connect(function()
			if not UserInputService:GetFocusedTextBox() then
				TowerSkills.UseKey(key)
			end
		end)
		table.insert(actions, action)
	end
	InputService.Scope("TowerSkillInput", actions):Enable()

	ClientSignals.TowerDestroyed:Connect(TowerSkills.RemoveTower)
	ClientSignals.GameSpeedChanged:Connect(TowerSkills._OnGameSpeedChanged)
	Net.TowerService.SkillsUpdated.On(TowerSkills._SyncSkills)
end

return TowerSkills
