--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)

--/UI Variables
local source = Vide.source
local root = Vide.root
local effect = Vide.effect

--/States
local CurrentFrame = source(nil)
local IsLocked = source(false)

local camera = workspace.CurrentCamera

-------------------------------------------------
--// UIController
-------------------------------------------------
local UIController = {}
UIController.Frames = {}

function UIController.Init() end

function UIController.Start()
	for _, frame in UIController.Frames do
		if frame then
			frame.Visible = false
		end
	end

	root(function()
		effect(function()
			for name, frame in UIController.Frames do
				if not frame then
					continue
				end

				local shouldBeVisible = CurrentFrame() == name
				if frame.Visible == shouldBeVisible then
					continue
				end

				if shouldBeVisible then
					local originalPos = frame:GetAttribute("OriginalPos") or frame.Position
					frame:SetAttribute("OriginalPos", originalPos)
					frame.Position = originalPos + UDim2.fromScale(0, 0.15)

					frame.Visible = true

					TweenService:Create(
						frame,
						TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
						{ Position = originalPos }
					):Play()
				else
					frame.Visible = false
				end
			end

			TweenService:Create(
				camera,
				TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ FieldOfView = if CurrentFrame() ~= nil then 55 else 70 }
			):Play()
		end)
	end)
end

function UIController:RegisterFrame(name, frame)
	if not frame then
		return
	end

	self.Frames[name] = frame

	local shouldBeVisible = CurrentFrame() == name
	frame.Visible = shouldBeVisible

	if not shouldBeVisible then
		return
	end

	local originalPos = frame:GetAttribute("OriginalPos") or frame.Position
	frame:SetAttribute("OriginalPos", originalPos)
	frame.Position = originalPos
end

function UIController:IsOpen(name: string): boolean
	return CurrentFrame() == name
end

function UIController:Open(name: string)
	if IsLocked() then
		return
	end

	CurrentFrame(name)
end

function UIController:Close(name: string)
	if IsLocked() then
		return
	end

	if CurrentFrame() == name then
		CurrentFrame(nil)
	end
end

function UIController:CloseAll()
	if IsLocked() then
		return
	end

	CurrentFrame(nil)
end

function UIController:Lock(lock: boolean)
	IsLocked(lock)
end

function UIController:Toggle(name: string)
	if IsLocked() then
		return
	end

	if CurrentFrame() == name then
		self:Close(name)
	else
		self:Open(name)
	end
end

return UIController
