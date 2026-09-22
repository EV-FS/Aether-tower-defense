local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SettingsData = require(ReplicatedStorage.Settings.Data.SettingsData)
local DataService

local SettingsService = {}

function SettingsService:SaveSetting(player: Player, settingName: string, value: any)
	local playerData = DataService:GetData(player)
	local settingInfo = SettingsData.ByName[settingName]
	if not playerData or not settingInfo then
		return false
	end

	if settingInfo.Type == "boolean" and typeof(value) ~= "boolean" then
		return false
	elseif settingInfo.Type == "number" then
		if typeof(value) ~= "number" or value ~= value or value < settingInfo.Min or value > settingInfo.Max then
			return false
		end
	else
		return false
	end

	if settingName == "AutoSkip" and value == true then
		if not player:IsInGroupAsync(492293332) then
			return false
		end
	end

	DataService:UpdateData(player, "Settings", value, settingName)

	return true
end

function SettingsService:GetSettings(player: Player, settingName: string?)
	local playerData = DataService:GetData(player)
	if not playerData then
		return if settingName then nil else {}
	end
	if settingName then
		if not SettingsData.ByName[settingName] then
			return nil
		end
		return playerData.Settings[settingName]
	end

	return playerData.Settings
end

function SettingsService:Reconcile(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end
	if playerData.Settings.AS_Absolute ~= nil then
		DataService:UpdateData(player, "Settings", nil, "AS_Absolute")
	end

	if playerData.Settings.AutoSkip == true then
		if not player:IsInGroupAsync(492293332) then
			DataService:UpdateData(player, "Settings", false, "AutoSkip")
		end
	end

	for key, settingInfo in SettingsData.ByName do
		if playerData.Settings[key] ~= nil then
			continue
		end
		DataService:UpdateData(player, "Settings", settingInfo.Default, key)
	end
end

function SettingsService.Init(services)
	DataService = services:GetService("DataService")
end

function SettingsService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if DataService:GetProfile(player) then
				SettingsService:Reconcile(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		if DataService:GetProfile(player) then
			SettingsService:Reconcile(player)
		end
	end)

	Net.SettingsService.SaveSetting.On(function(player: Player, data: { SettingName: string, Value: any })
		return SettingsService:SaveSetting(player, data.SettingName, data.Value)
	end)

	Net.SettingsService.GetSettings.On(function(player: Player, settingName: string?)
		return SettingsService:GetSettings(player, settingName)
	end)
end

return SettingsService
