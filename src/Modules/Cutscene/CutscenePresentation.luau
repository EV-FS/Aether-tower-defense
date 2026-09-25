local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CutscenePresentation = {}
CutscenePresentation.__index = CutscenePresentation

local function waitSeconds(seconds: number, alive: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while alive() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	return alive()
end

function CutscenePresentation.new(config)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneBlackout"
	gui.DisplayOrder = 100004
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local black = Instance.new("TextButton")
	black.Name = "Black"
	black.Active = true
	black.AutoButtonColor = false
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.Text = ""
	black.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return setmetatable({ Config = config, Gui = gui, Black = black,
		Destroyed = false, Tween = nil, SoundTween = nil, CameraTween = nil }, CutscenePresentation)
end

function CutscenePresentation:_alive(isCurrent: () -> boolean): boolean
	return not self.Destroyed and isCurrent()
end

function CutscenePresentation:_cover(duration: number, isCurrent: () -> boolean): boolean
	if not self:_alive(isCurrent) then return false end
	if self.Tween then self.Tween:Cancel() end
	self.Black.Visible = true
	local tween = TweenService:Create(self.Black,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ BackgroundTransparency = 0 })
	self.Tween = tween
	tween:Play()
	local playbackState = tween.Completed:Wait()
	if not self:_alive(isCurrent) then return false end
	if playbackState ~= Enum.PlaybackState.Completed then
		warn(`[CutscenePresentation] Blackout tween ended early: {playbackState.Name}`)
		return false
	end
	-- Tween completion can resume this thread before the final UI frame is drawn.
	-- Commit a fully opaque frame before Play starts cloning the large scene.
	self.Black.BackgroundTransparency = 0
	return true
end

-- Cover the crafting UI before any scene, lighting, avatar, or camera is changed.
function CutscenePresentation:CoverEntrance(isCurrent: () -> boolean): boolean
	if not self:_cover(self.Config.FadeOut, isCurrent) then return false end
	RunService.RenderStepped:Wait()
	RunService.Heartbeat:Wait()
	return self:_alive(isCurrent)
end

function CutscenePresentation:ReadyToReveal(isCurrent: () -> boolean): boolean
	if not waitSeconds(self.Config.ReadyHold, function() return self:_alive(isCurrent) end) then return false end
	return waitSeconds(self.Config.BlackHold, function() return self:_alive(isCurrent) end)
end

function CutscenePresentation:Reveal()
	if self.Destroyed then return end
	if self.Tween then self.Tween:Cancel() end
	local tween = TweenService:Create(self.Black,
		TweenInfo.new(self.Config.FadeIn, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 })
	self.Tween = tween
	tween:Play()
end

-- A small relative push on the last frame gives the exit some momentum without
-- collapsing a wide or already narrow authored shot into an extreme telephoto.
function CutscenePresentation:CoverExit(isCurrent: () -> boolean, sound: Sound?, camera: Camera?): boolean
	if not self:_alive(isCurrent) then return false end
	if sound and sound.Parent then
		self.SoundTween = TweenService:Create(sound, TweenInfo.new(self.Config.FadeOut), { Volume = 0 })
		self.SoundTween:Play()
	end
	if camera and camera.Parent then
		local targetFOV = math.clamp(camera.FieldOfView * (self.Config.ExitFOVScale or 0.88), 1, 120)
		self.CameraTween = TweenService:Create(camera,
			TweenInfo.new(self.Config.FadeOut, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ FieldOfView = targetFOV })
		self.CameraTween:Play()
	end
	local covered = self:_cover(self.Config.FadeOut, isCurrent)
	if self.SoundTween then self.SoundTween:Cancel(); self.SoundTween = nil end
	if self.CameraTween then self.CameraTween:Cancel(); self.CameraTween = nil end
	return covered
end

function CutscenePresentation:ReturnToLobby(isCurrent: () -> boolean): boolean
	if not waitSeconds(self.Config.ReturnHold, function() return self:_alive(isCurrent) end) then return false end
	if not self:_alive(isCurrent) then return false end
	if self.Tween then self.Tween:Cancel() end
	local tween = TweenService:Create(self.Black,
		TweenInfo.new(self.Config.FadeIn, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ BackgroundTransparency = 1 })
	self.Tween = tween
	tween:Play()
	local playbackState = tween.Completed:Wait()
	local completed = self:_alive(isCurrent) and playbackState == Enum.PlaybackState.Completed
	if completed then self:Destroy() end
	return completed
end

function CutscenePresentation:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.Tween then self.Tween:Cancel(); self.Tween = nil end
	if self.SoundTween then self.SoundTween:Cancel(); self.SoundTween = nil end
	if self.CameraTween then self.CameraTween:Cancel(); self.CameraTween = nil end
	self.Gui:Destroy()
end

return CutscenePresentation
