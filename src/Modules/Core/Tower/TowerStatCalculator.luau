local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitData = require(ReplicatedStorage.Settings.Data.UnitData)

local TowerStatCalculator = {}

local function applySummonHealth(stats, multiplier: number)
	local summons = stats.Summons or (stats.SummonUnit and { stats }) or {}
	for _, summon in summons do
		local unit = UnitData.ByName[summon.SummonUnit]
		summon.UnitStats = summon.UnitStats or {}
		local maxHealth = summon.UnitStats.MaxHealth or (unit and unit.MaxHealth)
		if maxHealth then
			summon.UnitStats.MaxHealth = maxHealth * (1 + multiplier)
		end
	end
end

local function applyIncome(stats, multiplier: number, additivePercent)
	for _, passive in stats.Passives or {} do
		if (passive.Type == "CashOnHit" or passive.Type == "CashPerSecond") and passive.Amount then
			passive.Amount *= 1 + multiplier
		end
	end
	if stats.Income then
		additivePercent.Income = (additivePercent.Income or 0) + multiplier
	end
end

local function roundStats(stats)
	if stats.Damage then
		stats.Damage = math.floor(stats.Damage)
	end
	if stats.Range then
		stats.Range = math.floor(stats.Range * 10) / 10
	end
	if stats.Cooldown then
		stats.Cooldown = math.floor(stats.Cooldown * 100) / 100
	end
end

function TowerStatCalculator.FromStats(rawStats, towerProfile, shouldRound: boolean?)
	if not rawStats then
		return nil
	end

	local stats = TableUtils.DeepCopy(rawStats)
	local additivePercent = {}
	local traitName = towerProfile and towerProfile.Trait
	local trait = traitName and TraitData.ByName[traitName]

	for _, effect in (trait and trait.Effects) or {} do
		local value = effect.Value
		if effect.Handler == "DamageMultiflier" and stats.Damage then
			additivePercent.Damage = (additivePercent.Damage or 0) + value
		elseif effect.Handler == "RangeMultiflier" and stats.Range then
			additivePercent.Range = (additivePercent.Range or 0) + value
		elseif effect.Handler == "CooldownMultiflier" and stats.Cooldown then
			additivePercent.Cooldown = (additivePercent.Cooldown or 0) - value
		elseif effect.Handler == "IncomeMultiplier" then
			applyIncome(stats, value, additivePercent)
		elseif effect.Handler == "SummonHealthMultiplier" then
			applySummonHealth(stats, value)
		end
	end

	local unitLevel = if towerProfile and typeof(towerProfile.Lv) == "number" then math.max(0, towerProfile.Lv) else 0
	if stats.Damage then
		additivePercent.Damage = (additivePercent.Damage or 0) + unitLevel * 0.006
	end

	for statName, multiplier in additivePercent do
		if stats[statName] then
			stats[statName] *= 1 + multiplier
		end
	end

	if shouldRound ~= false then
		roundStats(stats)
	end

	return stats
end

function TowerStatCalculator.Calculate(towerName: string, upgradeLevel: number, towerProfile, shouldRound: boolean?)
	local tower = TowerData.ByName[towerName]
	local rawStats = tower and tower.Stats[upgradeLevel]
	return TowerStatCalculator.FromStats(rawStats, towerProfile, shouldRound)
end

TowerStatCalculator.Round = roundStats

return TowerStatCalculator
