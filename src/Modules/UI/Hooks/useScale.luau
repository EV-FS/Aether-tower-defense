local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsClient = require(ReplicatedStorage.Shared.Services.System.SettingsClient)

local source = Vide.source
local create = Vide.create
local action = Vide.action
local cleanup = Vide.cleanup

local function useScale()
	return action(function(instance: GuiObject)
		local scaleValue = source(1)

		task.spawn(function()
			local settings = SettingsClient.GetSettings()
			if settings and settings.UIScale ~= nil then
				scaleValue(settings.UIScale / 100)
			end
		end)

		local connection = SettingsClient:GetChangedSignal("UIScale"):Connect(function(newValue)
			if type(newValue) == "number" then
				scaleValue(newValue / 100)
			end
		end)

		local scale = create("UIScale")({
			Parent = instance,
			Scale = scaleValue,
		})

		cleanup(function()
			connection:Disconnect()
			scale:Destroy()
		end)
	end)
end

return useScale
