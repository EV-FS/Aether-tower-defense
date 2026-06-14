--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--/Modules
local Net = require(ReplicatedStorage.Shared.Net)

--/Constants
local DEFAULT_DURATION = 3
local MAX_DURATION = 65
local ENTER_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EXIT_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

--/Variables
local Initialized = false

local PlayerGui
local Notifications
local PopUpFrame

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function setTransparency(instance: Instance, target: number, tweenInfo: TweenInfo?)
	local properties = {}
	if instance:IsA("GuiObject") then
		table.insert(properties, "BackgroundTransparency")
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		table.insert(properties, "TextTransparency")
		table.insert(properties, "TextStrokeTransparency")
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		table.insert(properties, "ImageTransparency")
	elseif instance:IsA("UIStroke") then
		table.insert(properties, "Transparency")
	end

	for _, prop in properties do
		local attrName = "Original" .. prop
		local original = instance:GetAttribute(attrName)
		if original == nil then
			original = instance[prop]
			instance:SetAttribute(attrName, original)
		end

		local finalVal = if target == 1 then 1 else original
		if tweenInfo then
			TweenService:Create(instance, tweenInfo, { [prop] = finalVal }):Play()
		else
			instance[prop] = finalVal
		end
	end

	for _, child in instance:GetChildren() do
		setTransparency(child, target, tweenInfo)
	end
end

local function showPopup(message: string, duration: number?)
	local sourceTemplate = PopUpFrame:WaitForChild("Template")

	local popup = sourceTemplate:Clone()
	popup.Name = "Popup"
	popup.Visible = true
	popup.Parent = PopUpFrame

	popup.Text = message

	local scale = popup:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = popup

	setTransparency(popup, 1)

	local enterTween = TweenService:Create(scale, ENTER_TWEEN, { Scale = 1 })
	enterTween:Play()
	setTransparency(popup, 0, ENTER_TWEEN)

	task.delay(duration or DEFAULT_DURATION, function()
		if not popup.Parent then
			return
		end

		local exitTween = TweenService:Create(scale, EXIT_TWEEN, { Scale = 0.95 })
		exitTween:Play()
		setTransparency(popup, 1, EXIT_TWEEN)
		exitTween.Completed:Wait()

		if popup.Parent then
			popup:Destroy()
		end
	end)
end

local function getDurationPayload(duration: number?): number
	if typeof(duration) ~= "number" then
		return DEFAULT_DURATION * 1000
	end

	return math.clamp(math.floor(duration * 1000 + 0.5), 0, MAX_DURATION * 1000)
end

-------------------------------------------------
--// NotificationService
-------------------------------------------------
local NotificationService = {}

function NotificationService:Popup(playerOrMessage: any, message: string?, duration: number?)
	if not RunService:IsClient() then
		if typeof(playerOrMessage) == "Instance" and playerOrMessage:IsA("Player") and message then
			Net.NotificationService.Popup.Fire(playerOrMessage, {
				Message = message,
				DurationMs = getDurationPayload(duration),
			})
		end
		return
	end

	local popupMessage = if typeof(playerOrMessage) == "string" then playerOrMessage else message
	if typeof(playerOrMessage) == "string" and typeof(message) == "number" then
		duration = message
	end

	if popupMessage then
		showPopup(popupMessage, duration)
	end
end

function NotificationService:PopupAll(message: string, duration: number?)
	if not RunService:IsClient() then
		Net.NotificationService.Popup.FireAll({
			Message = message,
			DurationMs = getDurationPayload(duration),
		})
		return
	end

	for _, player in Players:GetPlayers() do
		self:Popup(player, message, duration)
	end
end

function NotificationService.Init()
	if Initialized then
		return
	end
	Initialized = true

	if not RunService:IsClient() then
		return
	end

	PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	Notifications = PlayerGui:WaitForChild("Notifications")
	PopUpFrame = Notifications:WaitForChild("PopUpFrame")

	Net.NotificationService.Popup.On(function(payload)
		showPopup(payload.Message, payload.DurationMs / 1000)
	end)
end

return NotificationService
