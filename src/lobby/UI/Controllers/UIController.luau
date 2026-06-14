local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local UIState = require(script.Parent.Parent.Utils.UIState)

local camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local summonGui = playerGui:WaitForChild("SummonGui")

-------------------------------------------------
--// UIController
-------------------------------------------------
local UIController = {}

UIController.CameraZoomed = false
UIController.OpenedFrame = nil :: GuiObject?
UIController.Frames = {} :: { [string]: GuiObject? }

function UIController.Init()
	local mainGui = playerGui:WaitForChild("MainGui")

	UIController.Frames = {
		Daily = mainGui:FindFirstChild("Daily") :: GuiObject?,
		Inventory = mainGui:FindFirstChild("Inventory") :: GuiObject?,
		Store = mainGui:FindFirstChild("Store") :: GuiObject?,
		Quest = mainGui:FindFirstChild("Quest") :: GuiObject?,
		Index = mainGui:FindFirstChild("Index") :: GuiObject?,
		Settings = mainGui:FindFirstChild("Settings") :: GuiObject?,
		Summon = summonGui:FindFirstChild("Summon") :: GuiObject?,
	}

	UIController:Start()
end

function UIController:Start()
	for _, frame in self.Frames do
		if frame then
			frame.Visible = false
		end
	end

	Vide.root(function()
		Vide.effect(function()
			local currentName = UIState.CurrentFrame()

			for name, frame in self.Frames do
				if not frame then
					continue
				end

				local shouldBeVisible = (currentName == name)
				if frame.Visible == shouldBeVisible then
					continue
				end

				if shouldBeVisible then
					local originalPos = frame:GetAttribute("OriginalPos") or frame.Position
					frame:SetAttribute("OriginalPos", originalPos)
					frame.Position = originalPos + UDim2.fromScale(0, 0.15)

					frame.Visible = true
					self.OpenedFrame = frame

					TweenService:Create(
						frame,
						TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
						{ Position = originalPos }
					):Play()
				else
					frame.Visible = false
					if self.OpenedFrame == frame then
						self.OpenedFrame = nil
					end
				end
			end

			local isZoomed = (currentName ~= nil)
			if isZoomed ~= self.CameraZoomed then
				self.CameraZoomed = isZoomed
				local targetFoV = if isZoomed then 55 else 70
				TweenService:Create(
					camera,
					TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ FieldOfView = targetFoV }
				):Play()
			end
		end)
	end)
end

function UIController:RegisterFrame(name: string, frame: GuiObject)
	if not frame then
		return
	end

	self.Frames[name] = frame

	local shouldBeVisible = (UIState.CurrentFrame() == name)
	frame.Visible = shouldBeVisible

	if not shouldBeVisible then
		return
	end

	self.OpenedFrame = frame
	local originalPos = frame:GetAttribute("OriginalPos") or frame.Position
	frame:SetAttribute("OriginalPos", originalPos)
	frame.Position = originalPos
end

function UIController:IsOpen(name: string): boolean
	return UIState.CurrentFrame() == name
end

function UIController:Open(name: string)
	if summonGui.ListFrame.Visible then
		return
	end

	UIState.CurrentFrame(name)
end

function UIController:Close(name: string)
	if UIState.CurrentFrame() == name then
		UIState.CurrentFrame(nil)
	end
end

function UIController:CloseAll()
	UIState.CurrentFrame(nil)
end

function UIController:Toggle(name: string)
	if UIState.CurrentFrame() == name then
		self:Close(name)
	else
		self:Open(name)
	end
end

return UIController
