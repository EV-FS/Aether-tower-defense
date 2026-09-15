local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local DEFAULT_IMAGE = "rbxassetid://96421319964530"

local UnitCatalog = {}

function UnitCatalog.GetInfo(unitName: string)
	return TowerData.ByName[unitName]
end

function UnitCatalog.GetRarity(unitName: string): string
	local unitInfo = TowerData.ByName[unitName]
	if unitInfo and unitInfo.Rarity then
		return unitInfo.Rarity
	end

	return SummonConfig.LegacyUnitRarities[unitName] or "Unknown"
end

function UnitCatalog.GetImage(unitName: string): string
	if unitName == "" then
		return ""
	end

	local unitInfo = TowerData.ByName[unitName]
	if unitInfo and unitInfo.TowerImage and unitInfo.TowerImage ~= "" then
		return unitInfo.TowerImage
	end

	return SummonConfig.LegacyUnitImages[unitName] or DEFAULT_IMAGE
end

return table.freeze(UnitCatalog)
