local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local player = Players.LocalPlayer
local inputBar = TextChatService.ChatInputBarConfiguration

local KEYBOARD_OFFSET = CFrame.new(0, -0.051, 0) * CFrame.fromOrientation(math.rad(90), math.rad(90), 0)

local keyboard: BasePart? = nil
local keyboardWeld: Motor6D | Weld? = nil
local activeTrack: AnimationTrack? = nil
local activeAnimation: Animation? = nil
local activeSfx: any? = nil
local audioController: any? = nil
local chatId = 0
local isSending = false
local sendPending = false

local function escapeRichText(text: string): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return escaped
end

local function formatRoleTag(message: TextChatMessage): TextChatMessageProperties?
	local textSource = message.TextSource
	if not textSource then
		return nil
	end

	local messagePlayer = Players:GetPlayerByUserId(textSource.UserId)
	local roleName = messagePlayer and messagePlayer:GetAttribute("ChatRoleTag")
	if type(roleName) ~= "string" or roleName == "" then
		return nil
	end

	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = `<font color="#FFB6D9">[{escapeRichText(roleName)}]</font> {message.PrefixText}`
	return properties
end

local ChatController = {
	CurrentState = "Normal",
	AnimationIds = {
		Start = "rbxassetid://92643631657418",
		Loop = "rbxassetid://100699931808831",
		Enter = "rbxassetid://137895585559810",
	},
	SfxIds = {
		Start = "",
		Loop = "rbxassetid://7610391610",
		Enter = "rbxassetid://130990339683290",
	},
	Sfx = {
		Volume = 3,
		Distance = 50,
	},
	LoopSpeed = {
		Start = 1,
		Max = 10,
		Acceleration = 0.05,
	},
}

local function setState(state: string)
	ChatController.CurrentState = state
end

local function leaveHandAfterimages(speed)
	local character = player.Character
	if not character then
		return
	end

	for _, handName in { "Left Arm", "Right Arm" } do
		local hand = character:FindFirstChild(handName)
		if not hand or not hand:IsA("BasePart") then
			continue
		end

		local afterimage = hand:Clone()
		afterimage.Name = "ChatHandAfterimage"
		afterimage.Anchored = true
		afterimage.CanCollide = false
		afterimage.CanQuery = false
		afterimage.CanTouch = false
		afterimage.CastShadow = false
		afterimage.Transparency = 0.75
		afterimage.CFrame = hand.CFrame
		afterimage.Material = Enum.Material.Neon
		afterimage.Color = Color3.new(0, 1, 0.2)
		afterimage.Parent = workspace

		TweenService:Create(afterimage, TweenInfo.new(0.4 - speed * 0.01), { Color = Color3.new(0, 0.5, 1) }):Play()
		TweenService:Create(afterimage, TweenInfo.new(0.4 - speed * 0.01), { Transparency = 1 }):Play()
		Debris:AddItem(afterimage, 0.4 - speed * 0.01)
	end
end

local function startLoop(id: number)
	if id ~= chatId then
		return
	end

	setState("Typing")

	local track = ChatController.PlayAnimation(ChatController.AnimationIds.Loop, true)
	if not track then
		return
	end
	local sfx = ChatController.PlaySfx(ChatController.SfxIds.Loop, true)

	local speed = ChatController.LoopSpeed.Start
	local afterimageElapsed = 0
	track:AdjustSpeed(speed)

	local connection
	connection = RunService.PreRender:Connect(function(dt)
		if chatId ~= id or activeTrack ~= track then
			connection:Disconnect()
			connection = nil
		end

		speed = math.min(ChatController.LoopSpeed.Max, speed + ChatController.LoopSpeed.Acceleration * dt)
		track:AdjustSpeed(speed)

		if speed >= 2 then
			afterimageElapsed += dt
			local interval = 0.1 - speed * 0.01
			if afterimageElapsed >= interval then
				afterimageElapsed = 0
				leaveHandAfterimages(speed)
			end
		end

		if activeSfx == sfx and sfx.Player then
			sfx.Player.PlaybackSpeed = speed
		end
	end)
end

local function getAnimator(): Animator?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return humanoid:FindFirstChildOfClass("Animator") :: Animator?
end

local function unrigKeyboard()
	if keyboardWeld then
		keyboardWeld:Destroy()
		keyboardWeld = nil
	end

	if keyboard then
		keyboard:Destroy()
		keyboard = nil
	end
end

local function rigKeyboard(): boolean
	if keyboard then
		return true
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Props"):FindFirstChild("Keyboard")
	if not template or not template:IsA("BasePart") then
		warn("[ChatController] Missing Assets.Props.Keyboard")
		return false
	end

	local clone = template:Clone()
	clone.Anchored = false
	clone.CanCollide = false
	clone.Massless = true

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end

	clone.Parent = character
	keyboard = clone
	keyboardWeld = CharacterUtils.RigInstance(rootPart, clone, KEYBOARD_OFFSET, true)

	return true
end

function ChatController.StopSfx()
	if activeSfx then
		activeSfx.Stop()
		activeSfx = nil
	end
end

function ChatController.PlaySfx(soundId: string | number, looped: boolean?, emitter: Instance?)
	local assetId = tostring(soundId)
	emitter = emitter or keyboard or (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
	ChatController.StopSfx()

	if not audioController or assetId == "" or not emitter then
		return nil
	end

	local soundAsset = if string.find(assetId, "rbxassetid://", 1, true) then assetId else `rbxassetid://{assetId}`
	activeSfx =
		audioController.PlayOn3D(soundAsset, ChatController.Sfx.Volume, ChatController.Sfx.Distance, emitter, looped)

	return activeSfx
end

function ChatController.StopAnimation(fadeTime: number?)
	local track = activeTrack
	local animation = activeAnimation
	activeTrack = nil
	activeAnimation = nil

	if track then
		track:Stop(fadeTime or 0.1)
		track:Destroy()
	end
	if animation then
		animation:Destroy()
	end
end

function ChatController.PlayAnimation(animationId: string, looped: boolean?, onStopped: (() -> ())?): AnimationTrack?
	local animator = getAnimator()
	local assetId = tostring(animationId)
	if not animator or assetId == "" then
		return nil
	end

	ChatController.StopAnimation()

	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	animation.Parent = animator

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = looped == true
	track:Play(0.1)

	activeTrack = track
	activeAnimation = animation

	track.Stopped:Once(function()
		if activeTrack ~= track then
			return
		end

		activeTrack = nil
		activeAnimation = nil
		track:Destroy()
		animation:Destroy()

		if onStopped then
			onStopped()
		end
	end)

	return track
end

function ChatController.OnChatStarted()
	chatId += 1
	local id = chatId

	ChatController.StopAnimation(0)
	unrigKeyboard()
	setState("Started")

	if not rigKeyboard() then
		setState("Normal")
		return
	end
	ChatController.PlaySfx(ChatController.SfxIds.Start)

	local startTrack = ChatController.PlayAnimation(ChatController.AnimationIds.Start, false, function()
		startLoop(id)
	end)

	if not startTrack then
		startLoop(id)
	end
end

function ChatController.OnChatCancelled()
	chatId += 1
	ChatController.StopAnimation()
	ChatController.StopSfx()
	unrigKeyboard()
	setState("Normal")
end

function ChatController.OnChatSent()
	if ChatController.CurrentState ~= "Started" and ChatController.CurrentState ~= "Typing" then
		return
	end

	chatId += 1
	local id = chatId
	setState("Sent")
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	ChatController.PlaySfx(ChatController.SfxIds.Enter, false, rootPart)

	local enterTrack = ChatController.PlayAnimation(ChatController.AnimationIds.Enter, false, function()
		if id ~= chatId then
			return
		end

		unrigKeyboard()
		setState("Normal")
	end)

	if not enterTrack then
		unrigKeyboard()
		setState("Normal")
	end
end

function ChatController.Init(registry)
	audioController = registry:GetService("AudioController")
end

function ChatController.Start()
	TextChatService.OnIncomingMessage = formatRoleTag

	UserInputService.InputBegan:Connect(function(input)
		if not inputBar.IsFocused then
			return
		end

		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			sendPending = true

			task.delay(0.1, function()
				if not sendPending or isSending then
					return
				end

				sendPending = false
				if not inputBar.IsFocused then
					ChatController.OnChatCancelled()
				end
			end)
		end
	end)

	inputBar:GetPropertyChangedSignal("IsFocused"):Connect(function()
		if inputBar.IsFocused then
			isSending = false
			sendPending = false
			ChatController.OnChatStarted()
		elseif not isSending and not sendPending then
			ChatController.OnChatCancelled()
		end
	end)

	TextChatService.SendingMessage:Connect(function()
		isSending = true
		sendPending = false
		ChatController.OnChatSent()
	end)

	player.CharacterAdded:Connect(ChatController.OnChatCancelled)
end

return ChatController
