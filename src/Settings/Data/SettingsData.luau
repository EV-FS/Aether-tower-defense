local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type BooleanSetting = {
	Default: boolean,
	Type: "boolean",

	Title: string?,
	Order: number?,
	Category: string,
}

export type NumberSetting = {
	Default: number,
	Min: number,
	Max: number,
	Type: "number",

	Title: string?,
	Order: number?,
	Category: string,
}

export type Setting = BooleanSetting | NumberSetting

local function newBoolean(default: boolean, category: string, title: string?, order: number?): BooleanSetting
	return {
		Default = default,
		Type = "boolean",

		Title = title,
		Order = order,
		Category = category,
	}
end

local function newNumber(
	default: number,
	min: number,
	max: number,
	category: string,
	title: string?,
	order: number?
): NumberSetting
	return {
		Default = default,
		Min = min,
		Max = max,
		Type = "number",

		Title = title,
		Order = order,
		Category = category,
	}
end

local RawSettingsData = {
	AutoSkip = newBoolean(false, "Gameplay", "Auto Skip Wave", 1),
	Trade = newBoolean(true, "Gameplay", "Trade Enabled", 2),

	Shadows = newBoolean(true, "Visuals", "Show Shadows", 1),
	Night = newBoolean(false, "Visuals", "Set Night", 2),
	VFX = newBoolean(true, "Visuals", "Visual Effects", 3),

	MusicVolume = newNumber(50, 0, 100, "Audio", "Music Volume", 1),
	SFXVolume = newNumber(50, 0, 100, "Audio", "SFX Volume", 2),

	--// Auto Sells
	AS_Common = newBoolean(false, "Auto Sell", "Common", 1),
	AS_Rare = newBoolean(false, "Auto Sell", "Rare", 2),
	AS_Epic = newBoolean(false, "Auto Sell", "Epic", 3),
	AS_Legendary = newBoolean(false, "Auto Sell", "Legendary", 4),
	AS_Mythic = newBoolean(false, "Auto Sell", "Mythic", 5),
	AS_Secret = newBoolean(false, "Auto Sell", "Secret", 6),
	AS_Absolute = newBoolean(false, "Auto Sell", "Absolute", 7),
}

local CatgoryOrder = {
	Gameplay = 1,
	Visuals = 2,
	Audio = 3,
	UI = 4,
	["Auto Sell"] = 5,
}

local SettingsData = {
	ByName = RawSettingsData,
	ByCategory = {},
	CatgoryOrder = CatgoryOrder,
}

for key, data in pairs(RawSettingsData) do
	data.Name = key

	SettingsData.ByCategory[data.Category] = SettingsData.ByCategory[data.Category] or {}
	SettingsData.ByCategory[data.Category][key] = data
end

return TableUtils.DeepFreeze(SettingsData) :: { [string]: { [string]: Setting } }
