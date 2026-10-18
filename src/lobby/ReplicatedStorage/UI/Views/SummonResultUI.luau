local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CurrencyData = require(ReplicatedStorage.Settings.Data.CurrencyData)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local UISFX = require(ReplicatedStorage.Settings.Visuals.UISFX)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useAudio = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useAudio)
local WorldTowerDisplay = require(ReplicatedStorage.UI.Components.WorldTowerDisplay)
local LocalEmotePlayer = require(ReplicatedStorage.Shared.Modules.UI.Emote.LocalEmotePlayer)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)

local create = Vide.create
local cleanup = Vide.cleanup
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

export type PulledUnit = {
	UnitName: string,
	Rarity: string,
	Sold: boolean?,
	SellPrice: number?,
}

local VIEW_ID = "SummonResult"
local PLAYER = Players.LocalPlayer
local CONTROL_LOCK_ATTRIBUTE = "SummonControlsLocked"

local UIController
local SprintClient

local resultsQueue = source({} :: { PulledUnit })
local currentIndex = source(0)
local revealPhase = source(false)
local isTransitioning = source(false)
local isClosing = source(false)
local slideSign = source(1)
local modelReady = source(false)
local queuedAdvance = false

local EXIT_DELAY = 0.34
local ENTER_DELAY = 0.42
local CLOSE_DELAY = 0.4
local SUMMON_MODEL_DEPTH = 7
local BACKDROP_FAR_INTENSITY = 0.65
local BACKDROP_FOCUS_RADIUS = 3
local FOCUS_FADE_IN_TIME = 0.32
local FOCUS_FADE_OUT_TIME = 0.38

local closeToken = 0
local completedCallback: (() -> ())? = nil

type SavedCameraState = {
	Camera: Camera,
	CameraType: Enum.CameraType,
	CameraSubject: Instance?,
}

local savedCameraState: SavedCameraState? = nil

type SavedHumanoidState = {
	Humanoid: Humanoid,
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
	AutoRotate: boolean,
	JumpingEnabled: boolean,
}

local controlsLocked = false
local playerControls
local savedHumanoidState: SavedHumanoidState? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local sprintWasEnabled = false
local sprintWasActive = false

local SummonResultUI = {}

local function flushQueuedAdvance()
	if not queuedAdvance or not UIController:IsOpen(VIEW_ID) or isTransitioning() or isClosing() then
		return
	end

	queuedAdvance = false
	task.defer(SummonResultUI.Advance)
end

local function restoreHumanoidState()
	local state = savedHumanoidState
	savedHumanoidState = nil
	if not state or not state.Humanoid.Parent then
		return
	end

	state.Humanoid.WalkSpeed = state.WalkSpeed
	state.Humanoid.JumpPower = state.JumpPower
	state.Humanoid.JumpHeight = state.JumpHeight
	state.Humanoid.AutoRotate = state.AutoRotate
	state.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, state.JumpingEnabled)
end

local function lockCharacter(character: Model)
	if not controlsLocked then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not controlsLocked or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	savedHumanoidState = {
		Humanoid = humanoid,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		JumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
	}

	humanoid:Move(Vector3.zero, true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("LinearVelocity") and descendant.Name == "DashVelocity" then
			descendant:Destroy()
		end
	end
end

local function getPlayerControls()
	if playerControls then
		return playerControls
	end

	local playerScripts = PLAYER:FindFirstChildOfClass("PlayerScripts")
	local playerModuleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModuleScript or not playerModuleScript:IsA("ModuleScript") then
		return nil
	end

	local ok, playerModule = pcall(require, playerModuleScript)
	if not ok or type(playerModule) ~= "table" or type(playerModule.GetControls) ~= "function" then
		return nil
	end

	playerControls = playerModule:GetControls()
	return playerControls
end

local function lockPlayerControls()
	if controlsLocked then
		return
	end
	LocalEmotePlayer.Interrupt(PLAYER.Character)
	controlsLocked = true
	PLAYER:SetAttribute(CONTROL_LOCK_ATTRIBUTE, true)

	local controls = getPlayerControls()
	if controls then
		controls:Disable()
	end

	sprintWasEnabled = SprintClient and SprintClient.IsEnabled() or false
	sprintWasActive = SprintClient and SprintClient.IsSprinting() or false
	if SprintClient then
		SprintClient.Disable()
	end

	if PLAYER.Character then
		lockCharacter(PLAYER.Character)
	end
	characterAddedConnection = PLAYER.CharacterAdded:Connect(function(character)
		task.defer(lockCharacter, character)
	end)
end

local function restorePlayerControls()
	if not controlsLocked then
		return
	end
	controlsLocked = false
	PLAYER:SetAttribute(CONTROL_LOCK_ATTRIBUTE, nil)

	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end

	local controls = getPlayerControls()
	if controls then
		controls:Enable()
	end
	restoreHumanoidState()
	if SprintClient and sprintWasEnabled then
		SprintClient.SetEnabled(true, sprintWasActive)
	end
	sprintWasEnabled = false
	sprintWasActive = false
end

local function lockResultCamera()
	if savedCameraState then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	savedCameraState = {
		Camera = camera,
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
	}
	camera.CameraType = Enum.CameraType.Scriptable
end

local function restoreResultCamera()
	local state = savedCameraState
	savedCameraState = nil
	if not state or not state.Camera.Parent then
		return
	end

	if state.CameraSubject and state.CameraSubject.Parent then
		state.Camera.CameraSubject = state.CameraSubject
	end
	state.Camera.CameraType = state.CameraType
end

local function getCurrentUnit(): PulledUnit?
	local queue = resultsQueue()
	local index = currentIndex()
	if index < 1 or index > #queue then
		return nil
	end

	return queue[index]
end

local function isRevealed(): boolean
	return UIController:IsOpen(VIEW_ID) and revealPhase()
end

local function isHintVisible(): boolean
	return isRevealed() and not isTransitioning() and not isClosing()
end

local function playInitialReveal()
	isTransitioning(false)
	revealPhase(false)
	task.defer(function()
		if UIController:IsOpen(VIEW_ID) then
			revealPhase(true)
			flushQueuedAdvance()
		end
	end)
end

local function playTransition(onSwitch: () -> ())
	isTransitioning(true)
	revealPhase(false)

	task.delay(EXIT_DELAY, function()
		if not UIController:IsOpen(VIEW_ID) then
			isTransitioning(false)
			return
		end

		slideSign(-slideSign())
		onSwitch()

		task.defer(function()
			if not UIController:IsOpen(VIEW_ID) then
				isTransitioning(false)
				return
			end

			revealPhase(true)

			task.delay(ENTER_DELAY, function()
				isTransitioning(false)
				flushQueuedAdvance()
			end)
		end)
	end)
end

local function playClose(onFinished: () -> ())
	if isTransitioning() or isClosing() then
		return
	end

	closeToken += 1
	local token = closeToken

	isTransitioning(true)
	isClosing(true)
	revealPhase(false)

	task.delay(CLOSE_DELAY, function()
		if token ~= closeToken or not UIController:IsOpen(VIEW_ID) then
			isClosing(false)
			isTransitioning(false)
			return
		end

		onFinished()
	end)
end

function SummonResultUI.ShowResults(
	units: { PulledUnit },
	onCompleted: (() -> ())?,
	lockCameraDuringResults: boolean?
): boolean
	if #units == 0 then
		return false
	end

	closeToken += 1
	completedCallback = onCompleted
	resultsQueue(units)
	currentIndex(1)
	slideSign(1)
	isTransitioning(false)
	isClosing(false)
	revealPhase(false)
	queuedAdvance = false
	if not UIController:OpenExclusive(VIEW_ID) then
		completedCallback = nil
		resultsQueue({})
		currentIndex(0)
		return false
	end
	if lockCameraDuringResults ~= false then
		lockResultCamera()
	end
	lockPlayerControls()
	playInitialReveal()
	return true
end

function SummonResultUI.Advance()
	if not UIController:IsOpen(VIEW_ID) or isClosing() then
		return
	end

	if isTransitioning() or not revealPhase() then
		queuedAdvance = true
		return
	end
	queuedAdvance = false

	local queue = resultsQueue()
	local index = currentIndex()

	if index < #queue then
		playTransition(function()
			currentIndex(index + 1)
		end)
		return
	end

	playClose(function()
		SummonResultUI.Close()
	end)
end

function SummonResultUI.Close()
	closeToken += 1
	local onCompleted = completedCallback
	completedCallback = nil
	UIController:Close(VIEW_ID)
	resultsQueue({})
	currentIndex(0)
	revealPhase(false)
	isTransitioning(false)
	isClosing(false)
	queuedAdvance = false
	restoreResultCamera()
	restorePlayerControls()
	if onCompleted then
		task.defer(onCompleted)
	end
end

function SummonResultUI.RenderUI()
	-- Create audio in the mounted Vide scope so its properties and cleanup are owned by the UI.
	local revealSounds = {}
	for rarity in RarityData.DisplayNames do
		local sfx = UISFX[rarity]
		if sfx then
			revealSounds[rarity] = useAudio({ Id = sfx.Id, Volume = sfx.Volume })
		end
	end

	effect(function()
		if not isRevealed() then
			return
		end

		local unit = getCurrentUnit()
		local sound = unit and revealSounds[unit.Rarity]
		if sound then
			sound:Play()
		end
	end)

	local backdropFocus = Instance.new("DepthOfFieldEffect")
	backdropFocus.Name = "SummonResultBackdropFocus"
	backdropFocus.FarIntensity = 0
	backdropFocus.NearIntensity = 0
	backdropFocus.FocusDistance = SUMMON_MODEL_DEPTH
	backdropFocus.InFocusRadius = BACKDROP_FOCUS_RADIUS
	backdropFocus.Enabled = false
	backdropFocus.Parent = Lighting
	cleanup(function()
		backdropFocus:Destroy()
	end)
	cleanup(restoreResultCamera)
	cleanup(restorePlayerControls)

	effect(function()
		-- Keep the local 3D summon sharp while softening the world behind it.
		local shouldFocus = UIController:IsOpen(VIEW_ID) and not isClosing()
		local tween = TweenService:Create(
			backdropFocus,
			TweenInfo.new(
				if shouldFocus then FOCUS_FADE_IN_TIME else FOCUS_FADE_OUT_TIME,
				Enum.EasingStyle.Quad,
				if shouldFocus then Enum.EasingDirection.Out else Enum.EasingDirection.InOut
			),
			{ FarIntensity = if shouldFocus then BACKDROP_FAR_INTENSITY else 0 }
		)

		if shouldFocus then
			backdropFocus.Enabled = true
		end

		local completed = tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and not shouldFocus then
				backdropFocus.Enabled = false
			end
		end)
		tween:Play()
		cleanup(function()
			completed:Disconnect()
			tween:Cancel()
		end)
	end)

	return create("Frame")({
		Name = "SummonResultUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),
		ZIndex = 50,

		create("TextButton")({
			Name = "Backdrop",
			AutoButtonColor = false,
			Active = function()
				return UIController:IsOpen(VIEW_ID) and not isClosing()
			end,
			BackgroundColor3 = Color3.fromRGB(5, 5, 10),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 50,

			Activated = SummonResultUI.Advance,
		}),

		WorldTowerDisplay({
			OnModelChanged = function(model) modelReady(model ~= nil) end,
			TowerName = function()
				local unit = getCurrentUnit()
				return unit and unit.UnitName or ""
			end,
			Rarity = function()
				local unit = getCurrentUnit()
				return unit and unit.Rarity or nil
			end,
			RevealKey = currentIndex,
			AnimationName = "Idle",
			ScreenPosition = Vector2.new(0.5, 0.39),
			ScreenHeight = 0.44,
			ScreenWidth = 0.4,
			UseCharacterBounds = true,
			Darkened = function()
				local unit = getCurrentUnit()
				return unit ~= nil and unit.Sold == true
			end,
			Depth = SUMMON_MODEL_DEPTH,
			Visible = function()
				return UIController:IsOpen(VIEW_ID)
			end,
			Transparency = spring(function()
				return if isRevealed() then 0 else 1
			end, 0.4, 0.82),
			DisplayScale = spring(function()
				return if isRevealed() then 1 else if isClosing() then 0.88 else 0.94
			end, if isClosing() then 0.3 else 0.38, 0.72),
			ModelRotation = spring(function()
				return if isRevealed() then 0 else slideSign() * 14
			end, if isClosing() then 0.34 else 0.4, 0.72),
		}),

		create("ImageLabel")({
			Name = "UnitImageFallback",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.39),
			Size = UDim2.fromScale(0.4, 0.44),
			ScaleType = Enum.ScaleType.Fit,
			Image = function()
				local unit = getCurrentUnit()
				return if unit then UnitCatalog.GetImage(unit.UnitName) else ""
			end,
			ImageColor3 = function()
				local unit = getCurrentUnit()
				return if unit and unit.Sold then Color3.fromRGB(100, 100, 100) else Color3.new(1, 1, 1)
			end,
			ImageTransparency = spring(function() return if isRevealed() then 0 else 1 end, 0.4, 0.82),
			Visible = function() return UIController:IsOpen(VIEW_ID) and not modelReady() end,
			ZIndex = 50,
		}),

		create("Frame")({
			Name = "ResultPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				if isRevealed() then
					return 0
				end

				if isClosing() then
					return -6
				end

				return slideSign() * 8
			end, if isClosing() then 0.32 else 0.38, 0.68),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 51,

			create("UIScale")({
				Scale = spring(function()
					if isRevealed() then
						return 1
					end

					if isClosing() then
						return 0.88
					end

					return 0.94
				end, if isClosing() then 0.3 else 0.38, 0.68),
			}),

			create("TextLabel")({
				Name = "TowerName",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.66)
					end

					return UDim2.fromScale(0.5 - slideSign() * 0.08, 0.74)
				end, 0.38, 0.68),
				Size = UDim2.fromScale(0.7, 0.07),
				Text = function()
					local unit = getCurrentUnit()
					return unit and unit.UnitName or ""
				end,
				TextColor3 = Color3.fromRGB(245, 242, 230),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.45, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 1.5,
					Transparency = spring(function()
						return if isRevealed() then 0.4 else 1
					end, 0.45, 0.85),
				}),
			}),

			create("Frame")({
				Name = "AutoSoldOverlay",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.28, 0.2),
				Visible = function()
					local unit = getCurrentUnit()
					return isRevealed() and unit ~= nil and unit.Sold == true
				end,
				ZIndex = 56,
				create("ImageLabel")({
					Name = "Coin",
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = CurrencyData.ByName.Coins.CurrencyImage,
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.32, 0.48),
					ZIndex = 56,
					create("UIAspectRatioConstraint")({}),
				}),
				create("TextLabel")({
					Name = "SoldPrice",
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.53),
					Size = UDim2.fromScale(1, 0.28),
					Text = function()
						local unit = getCurrentUnit()
						return `+{if unit then unit.SellPrice or 0 else 0} COINS`
					end,
					TextColor3 = Color3.fromRGB(255, 220, 70),
					TextScaled = true,
					ZIndex = 57,
					create("UIStroke")({ Color = Color3.fromRGB(50, 28, 0), Thickness = 3 }),
				}),
				create("TextLabel")({
					Name = "AutoSoldText",
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.83),
					Size = UDim2.fromScale(0.86, 0.17),
					Text = "AUTO SOLD",
					TextColor3 = Color3.fromRGB(225, 225, 225),
					TextScaled = true,
					ZIndex = 57,
					create("UIStroke")({ Thickness = 2 }),
				}),
			}),

			create("TextLabel")({
				Name = "Rarity",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.735)
					end

					return UDim2.fromScale(0.5 + slideSign() * 0.08, 0.8)
				end, 0.4, 0.68),
				Size = UDim2.fromScale(0.5, 0.055),
				Text = function()
					local unit = getCurrentUnit()
					return unit and RarityData.DisplayNames[unit.Rarity] or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.5, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 2,
					Transparency = spring(function()
						return if isRevealed() then 0.15 else 1
					end, 0.5, 0.85),
				}),

				create("UIGradient")({
					Color = function()
						local unit = getCurrentUnit()
						local rarity = unit and unit.Rarity or "Common"
						return RarityData.Get(rarity).Presentation.Gradient
					end,
					Rotation = 90,
				}),
			}),

			create("TextLabel")({
				Name = "Progress",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.805),
				Size = UDim2.fromScale(0.3, 0.04),
				Text = function()
					local total = #resultsQueue()
					if total <= 1 then
						return ""
					end

					return `{currentIndex()} / {total}`
				end,
				TextColor3 = Color3.fromRGB(180, 175, 150),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0.15 else 1
				end, 0.45, 0.85),
				ZIndex = 54,
			}),

			create("TextLabel")({
				Name = "ContinueHint",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isHintVisible() then
						return UDim2.fromScale(0.5, 0.94)
					end

					return UDim2.fromScale(0.5, 1.06)
				end, 0.42, 1),
				Size = UDim2.fromScale(0.45, 0.04),
				Text = function()
					local total = #resultsQueue()
					local index = currentIndex()
					if total <= 1 then
						return "Tap to close"
					end

					return if index < total then "Tap to continue" else "Tap to finish"
				end,
				TextColor3 = Color3.fromRGB(150, 145, 120),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isHintVisible() then 0.25 else 1
				end, 0.4, 1),
				ZIndex = 54,
			}),
		}),
	})
end

function SummonResultUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	SprintClient = ServiceRegistry:GetService("SprintClient")
end

function SummonResultUI.Start() end

return SummonResultUI
