--/Services
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local SettingsData = require(ReplicatedStorage.Settings.Data.SettingsData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local SliderModule = require(ReplicatedStorage.Shared.Modules.UI.SliderModule)
local SettingsClient
local NotificationService

--/Fusion setup
local peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local scope = Fusion:scoped()

--/Variables
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Interface = PlayerGui:WaitForChild("Interface")
local SettingsFrame = Interface:WaitForChild("Settings")
local SettingsList = SettingsFrame:WaitForChild("SettingsList")

--// ReactState
local SettingsState = {}

-------------------------------------------------
--// SettingsUI
-------------------------------------------------
local SettingsUI = {}

function SettingsUI.Hydrate()
	local categoryTemplate = SettingsList.TemplateCategory
	local templateFrame = SettingsList.TemplateFrame
	local elementTemplate = SettingsList.TemplateElement

	scope:Hydrate(SettingsFrame.Bar.Close)({
		[OnEvent("MouseButton1Click")] = function()
			SettingsFrame.Visible = false
		end,
	})

	scope:Hydrate(SettingsList)({
		[Children] = scope:ForPairs(SettingsData.ByCategory, function(_, innerScope, category, settingInfos)
			local CurrentOrder = SettingsData.CatgoryOrder[category] or 99

			local newCategoryHeader = categoryTemplate:Clone()
			newCategoryHeader.Name = `{category}Bar`
			newCategoryHeader.LayoutOrder = CurrentOrder
			newCategoryHeader.Title.Text = category
			newCategoryHeader.Visible = true
			innerScope:Hydrate(newCategoryHeader)({})

			local newTemplateFrame = templateFrame:Clone()
			newTemplateFrame.Name = category
			newTemplateFrame.LayoutOrder = CurrentOrder
			newTemplateFrame.Visible = true

			innerScope:Hydrate(newTemplateFrame)({
				[Children] = innerScope:ForPairs(settingInfos, function(_, elementScope, key, info)
					local elementTitle = info.Title or key

					local newElement = elementTemplate:Clone()
					newElement.LayoutOrder = info.Order or 100
					newElement.Name = key
					newElement.Canvas.TextLabel.Text = elementTitle

					newElement.Visible = true

					local settingValue = SettingsState[key]
					if not settingValue then
						settingValue = elementScope:Value(info.Default)
						SettingsState[key] = settingValue
					end

					if info.Type == "number" then
						newElement.Canvas.Slider.Visible = true
						newElement.Canvas.ToggleButton.Visible = false

						elementScope:Hydrate(newElement.Canvas.Slider.Canvas.Process)({
							Size = elementScope:Computed(function(use)
								return UDim2.new(
									UDim.new(use(settingValue) / 100, 0),
									newElement.Canvas.Slider.Canvas.Process.Size.Y
								)
							end),
						})

						local handler = newElement.Canvas.Slider.Handler
						elementScope:Hydrate(handler)({
							Position = elementScope:Computed(function(use)
								return UDim2.new(
									use(settingValue) / 100,
									0,
									handler.Position.Y.Scale,
									handler.Position.Y.Offset
								)
							end),
						})
						elementScope:Hydrate(newElement.Canvas.Slider.ProcessText)({
							Text = elementScope:Computed(function(use)
								return `{use(settingValue)}%`
							end),
						})

						SliderModule(elementScope, {
							Slider = newElement.Canvas.Slider,
							Handler = handler,
							Process = settingValue,

							OnRelease = function(finalValue)
								SettingsClient.ApplySetting(key, finalValue)
							end,
						})
					elseif info.Type == "boolean" then
						newElement.Canvas.Slider.Visible = false
						newElement.Canvas.ToggleButton.Visible = true

						elementScope:Hydrate(newElement.Canvas.ToggleButton)({
							BackgroundColor3 = elementScope:Computed(function(use)
								return use(settingValue) and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
							end),
							[OnEvent("MouseButton1Click")] = function()
								local newValue = not peek(settingValue)

								if key == "AutoSkip" and newValue == true and not player:IsInGroupAsync(492293332) then
									task.spawn(function()
										local success, result = pcall(function()
											return GroupService:PromptJoinAsync(492293332)
										end)

										if success then
											if result == Enum.GroupMembershipStatus.Joined then
												NotificationService:Popup(
													Players.LocalPlayer,
													"Thanks for joining! Auto skip is now available."
												)
											end

											settingValue:set(newValue)
											SettingsClient.ApplySetting(key, newValue)
										else
											warn("프롬프트 실패:", result)
										end
									end)

									return
								end

								settingValue:set(newValue)
								SettingsClient.ApplySetting(key, newValue)
							end,
						})

						elementScope:Hydrate(newElement.Canvas.ToggleButton.TextLabel)({
							Text = elementScope:Computed(function(use)
								return use(settingValue) and "ON" or "OFF"
							end),
						})
					end

					return key, newElement
				end),
			})

			return category, { newCategoryHeader, newTemplateFrame }
		end),
	})
end

function SettingsUI.Init()
	SettingsClient = ServiceRegistry:GetService("SettingsClient")
	NotificationService = ServiceRegistry:GetService("NotificationService")
end

function SettingsUI.Start()
	local currentSettings = SettingsClient.GetSettings() or {}

	local icon = Topbarplus.new()
	icon:setImage("rbxassetid://9405931578")
	icon:setLabel("Settings")
	icon:oneClick(true)
	icon:align("Left")

	icon:bindEvent("deselected", function()
		SettingsFrame.Visible = not SettingsFrame.Visible
	end)

	for _, settings in pairs(SettingsData.ByCategory) do
		for settingName, settingInfo in pairs(settings) do
			local serverValue = currentSettings[settingName]
			local InitialValue = if serverValue ~= nil then serverValue else settingInfo.Default

			SettingsState[settingName] = scope:Value(InitialValue)
		end
	end

	SettingsUI.Hydrate()
end

return SettingsUI
