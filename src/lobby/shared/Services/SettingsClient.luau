local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net)
local SettingsData = require(ReplicatedStorage.Settings.Data.SettingsData)

local AudioService

local Settings = {}
local dirtySettings = {}

local activeTimeTween

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function smoothSetTime(targetTime: number, duration: number?)
	duration = duration or 1.5

	if activeTimeTween then
		activeTimeTween:Cancel()
		activeTimeTween = nil
	end

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	activeTimeTween = TweenService:Create(Lighting, tweenInfo, { ClockTime = targetTime })

	activeTimeTween:Play()

	activeTimeTween.Completed:Connect(function()
		activeTimeTween = nil
	end)
end

local SettingApplier = {
	Shadows = function(value: boolean)
		Lighting.GlobalShadows = value
	end,
	Night = function(value: boolean)
		smoothSetTime(if value then 0 else 11, 3)
		if AudioService then
			AudioService.SetBGMState(
				nil,
				nil,
				if value then "rbxassetid://79315968132597" else "rbxassetid://109718857077158"
			)
		end
	end,

	MusicVolume = function(value: number)
		if AudioService then
			AudioService.SetBGMState(nil, (value / 50))
		end
	end,
	SFXVolume = function(value: number)
		if AudioService then
			AudioService.SFXVolume = (value / 50)
		end
	end,
}

-------------------------------------------------
--// SettingsClient
-------------------------------------------------
local SettingsClient = {}
SettingsClient.LoadedPromise = nil

function SettingsClient.ApplySetting(settingName: string, value: any)
	if Settings[settingName] == value then
		return value
	end

	Settings[settingName] = value
	dirtySettings[settingName] = true

	local handler = SettingApplier[settingName]
	if handler then
		task.spawn(handler, value)
	end

	SettingsClient._SaveSettings()

	return value
end

function SettingsClient.GetSettings()
	if SettingsClient.LoadedPromise then
		SettingsClient.LoadedPromise:expect()
	else
		SettingsClient.FetchSettings():expect()
	end

	return TableUtils.DeepCopy(Settings)
end

function SettingsClient.FetchSettings()
	if SettingsClient.LoadedPromise then
		return SettingsClient.LoadedPromise
	end

	SettingsClient.LoadedPromise = Net.SettingsService.GetSettings
		.Invoke()
		:andThen(function(playerSettings)
			if type(playerSettings) == "table" then
				Settings = playerSettings
			end
		end)
		:catch(function(err)
			warn(`설정값 불러오기 실패: {err}`)
			Settings = {}
		end)
		:andThen(function()
			for key, info in pairs(SettingsData.ByName) do
				if Settings[key] == nil then
					Settings[key] = info.Default
				end
			end

			for key, val in pairs(Settings) do
				local handler = SettingApplier[key]
				if handler then
					task.spawn(handler, val)
				end
			end

			return Settings
		end)

	return SettingsClient.LoadedPromise
end

function SettingsClient._SaveSettings()
	if not next(dirtySettings) then
		return
	end

	local savingKeys = {}
	for key in pairs(dirtySettings) do
		savingKeys[key] = Settings[key]
		dirtySettings[key] = nil
	end

	for key, val in pairs(savingKeys) do
		print(key)
		Net.SettingsService.SaveSetting
			.Invoke({
				SettingName = key,
				Value = val,
			})
			:catch(function(err)
				warn(`설정 저장 실패 ({key}):`, err)

				if Settings[key] == val then
					dirtySettings[key] = true
				end
			end)
	end
end

function SettingsClient.Init(services)
	AudioService = services:GetService("AudioService")

	SettingsClient.FetchSettings()
end

return SettingsClient
