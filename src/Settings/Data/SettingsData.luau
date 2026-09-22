local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local AutoSellConfig = require(ReplicatedStorage.Settings.Data.AutoSellConfig)

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

}

for _, entry in AutoSellConfig.Rarities do
	RawSettingsData[entry.SettingName] = newBoolean(false, "Auto Sell", entry.Name, entry.Order)
end

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
