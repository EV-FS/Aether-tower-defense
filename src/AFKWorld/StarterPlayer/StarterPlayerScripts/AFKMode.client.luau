local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local ACTION_NAME = "AFKBlockCharacterControls"
local CAMERA_BIND_NAME = "AFKCameraLock"
local AVATAR_LOAD_ATTEMPTS = 3

local function sinkInput(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function disableDefaultControls()
	local playerScripts = localPlayer:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		playerModule = playerScripts:WaitForChild("PlayerModule", 10)
	end
	if playerModule and playerModule:IsA("ModuleScript") then
		pcall(function()
			local controls = require(playerModule):GetControls()
			controls:Disable()
		end)
	end

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		sinkInput,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
end

local function disableChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
		TextChatService.BubbleChatConfiguration.Enabled = false
	end)
end

local function lockCamera()
	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 100, function()
		local camera = Workspace.CurrentCamera
		local cameraPart = Workspace:FindFirstChild("CamPart")
		if not camera or not cameraPart or not cameraPart:IsA("BasePart") then
			return
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
		camera.CFrame = cameraPart.CFrame
		camera.Focus = cameraPart.CFrame + cameraPart.CFrame.LookVector * 10
	end)
end

local function loadLocalAvatarOntoRig()
	local rig = Workspace:WaitForChild("Rig", 30)
	if not rig or not rig:IsA("Model") then
		warn("[AFKMode] Workspace.Rig must be a Model.")
		return
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid") or rig:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn("[AFKMode] Workspace.Rig requires a Humanoid.")
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local description: HumanoidDescription? = nil
	for attempt = 1, AVATAR_LOAD_ATTEMPTS do
		local success, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, localPlayer.UserId)
		if success and result then
			description = result
			break
		end
		if attempt < AVATAR_LOAD_ATTEMPTS then
			task.wait(attempt)
		end
	end

	if not description then
		warn(`[AFKMode] Could not load avatar description for {localPlayer.Name}.`)
		return
	end

	local applied = pcall(humanoid.ApplyDescriptionReset, humanoid, description)
	if not applied then
		pcall(humanoid.ApplyDescription, humanoid, description)
	end
end

disableDefaultControls()
disableChat()
lockCamera()
task.spawn(loadLocalAvatarOntoRig)

localPlayer.CharacterAdded:Connect(function()
	task.defer(disableDefaultControls)
	task.defer(disableChat)
end)
