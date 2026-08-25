-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net.client)
local NpcDialogueData = require(ReplicatedStorage.Settings.Data.NpcDialogueData)
local AudioController = require(script.Parent.AudioController)
local SoundLibrary = require(ReplicatedStorage.Settings.Data.NPCS.Sounds.SoundLibrary)

local DialogueClient = {}

local playerGui: PlayerGui?
local dialogueGui: ScreenGui?
local backdrop: Frame?
local choiceContainer: Frame?
local choiceTemplate: Frame?
local dialogueFrame: Frame?
local frameScale: UIScale?
local nameText: TextLabel?
local npcInfoText: TextLabel?
local contextText: TextLabel?
local fastButton: GuiButton?
local headerMidFrame: Frame?
local leftWing: ImageLabel?
local rightWing: ImageLabel?

local originalFramePosition = UDim2.fromScale(0.5, 0.747184)
local originalChoicePosition = UDim2.fromScale(0.79, 0)
local originalCameraFOV = 70

local CurrentNpcId: string?
local CurrentDialogueId: string?
local _isOpen = false
local _suppressClose = false
local _pendingClose = false
local _skipRequested = false
local _currentDialogueCoroutine: thread?
local _activeTweens: { Tween } = {}
local _wingPulseTween: Tween?

-------------------------------------------------
--// Helper Functions
-------------------------------------------------
local function findDescendant(instance: Instance?, name: string): Instance?
	if not instance then
		return nil
	end
	return instance:FindFirstChild(name, true)
end

local function stopAllTweens()
	for _, tw in ipairs(_activeTweens) do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(_activeTweens)
end

local function trackTween(tw: Tween): Tween
	table.insert(_activeTweens, tw)
	tw.Completed:Once(function()
		local idx = table.find(_activeTweens, tw)
		if idx then
			table.remove(_activeTweens, idx)
		end
	end)
	tw:Play()
	return tw
end

local function getChoiceContainer(root: Instance?): Frame?
	if not root then
		return nil
	end

	local container = root:FindFirstChild("DialogueChoiceFrame") or root:FindFirstChild("Frame")
	if container and container:IsA("Frame") then
		return container
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Frame") and (child.Name == "DialogueChoiceFrame" or child.Name == "Frame") then
			return child
		end
	end

	return nil
end

local function clearChoices(animateOut: boolean?)
	if not choiceContainer or not choiceTemplate then
		return
	end

	local clones = {}
	for _, child in ipairs(choiceContainer:GetChildren()) do
		if child ~= choiceTemplate and child.Name:match("^ChoiceClone") then
			table.insert(clones, child)
		end
	end

	if animateOut and #clones > 0 then
		for index, clone in ipairs(clones) do
			local scale = clone:FindFirstChildOfClass("UIScale")
			if scale then
				trackTween(TweenService:Create(
					scale,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 0.6 }
				))
			end
			task.delay(0.03 * (index - 1), function()
				pcall(function()
					local tw = trackTween(TweenService:Create(
						clone,
						TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Position = UDim2.new(1.5, 0, 0, 0), BackgroundTransparency = 1 }
					))
					tw.Completed:Once(function()
						clone:Destroy()
					end)
				end)
			end)
		end
	else
		for _, clone in ipairs(clones) do
			clone:Destroy()
		end
	end
end

local function setTextObject(textObject: Instance?, value: string?)
	if textObject and textObject:IsA("TextLabel") then
		textObject.Text = value or ""
	end
end

-------------------------------------------------
--// Camera Focus Transition (Cinematic Zoom)
-------------------------------------------------
local function setCameraDialogueMode(active: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	if active then
		originalCameraFOV = camera.FieldOfView
		trackTween(TweenService:Create(
			camera,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = 62 }
		))
	else
		trackTween(TweenService:Create(
			camera,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = originalCameraFOV or 70 }
		))
	end
end

-------------------------------------------------
--// Choice Creation & Staggered Swipe-in (싹- 싹- 싹-)
-------------------------------------------------
local function createChoiceClone(choice: { Text: string, Next: string }, index: number)
	if not choiceTemplate or not choiceContainer then
		return
	end

	local clone = choiceTemplate:Clone()
	clone.Name = "ChoiceClone" .. tostring(index)
	clone.LayoutOrder = index
	clone.Visible = true
	-- 초기 상태: 화면 오른쪽 밖 (1.6)에서 대기
	clone.Position = UDim2.new(1.6, 0, 0, 0)
	clone.BackgroundTransparency = 0.5
	clone.Parent = choiceContainer

	local choiceScale = clone:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	choiceScale.Name = "ChoiceScale"
	choiceScale.Scale = 0.8
	choiceScale.Parent = clone

	local stroke = clone:FindFirstChildOfClass("UIStroke")
	local textLabel: TextLabel? = nil
	local button: TextButton? = nil

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("TextLabel") and not textLabel then
			textLabel = desc
		elseif desc:IsA("TextButton") and not button then
			button = desc
		end
	end

	if textLabel then
		textLabel.Text = choice.Text or ""
		textLabel.TextScaled = true
		textLabel.TextTransparency = 0
		textLabel.TextColor3 = Color3.new(1, 1, 1)
	end

	-- 버튼 개별 트윈 충돌 방지 맵
	local itemTweens: { [Instance]: Tween } = {}
	local function playItemTween(instance: Instance, tweenInfo: TweenInfo, properties: { [string]: any }): Tween
		if itemTweens[instance] then
			pcall(function()
				itemTweens[instance]:Cancel()
			end)
		end
		local tw = TweenService:Create(instance, tweenInfo, properties)
		itemTweens[instance] = tw
		tw:Play()
		return tw
	end

	-- 🌟 핵심 연출: 오른쪽 밖에서 차례대로 "싹- 싹- 싹-" 날아와 찰지게 꽂히는 스와이프 등장
	task.delay((index - 1) * 0.08, function()
		if not clone.Parent then
			return
		end

		playItemTween(
			clone,
			TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0 }
		)
		playItemTween(
			choiceScale,
			TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.0 }
		)
	end)

	-- 🌟 쫀득한 Hover / Press / Selection 인터랙션
	if button then
		local isHovered = false
		local isPressed = false

		button.MouseEnter:Connect(function()
			if isPressed then
				return
			end
			isHovered = true

			-- 마우스 올렸을 때: 왼쪽으로 살짝 튀어나옴 + 1.05x 확대 + 골드 테두리 발광
			playItemTween(
				clone,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(-0.06, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(65, 80, 100) }
			)
			playItemTween(
				choiceScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1.05 }
			)

			if stroke then
				playItemTween(
					stroke,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Color = Color3.fromRGB(255, 215, 75), Thickness = 2.8 }
				)
			end

			if textLabel then
				playItemTween(
					textLabel,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextColor3 = Color3.fromRGB(255, 240, 150), TextTransparency = 0 }
				)
			end
		end)

		button.MouseLeave:Connect(function()
			isHovered = false
			isPressed = false

			-- 마우스 나갈 때: 제자리로 100% 복귀
			playItemTween(
				clone,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(45, 55, 64) }
			)
			playItemTween(
				choiceScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.0 }
			)

			if stroke then
				playItemTween(
					stroke,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Color = Color3.fromRGB(120, 121, 105), Thickness = 2 }
				)
			end

			if textLabel then
				playItemTween(
					textLabel,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0 }
				)
			end
		end)

		button.MouseButton1Down:Connect(function()
			isPressed = true
			playItemTween(
				choiceScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 0.94 }
			)
			playItemTween(
				clone,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = Color3.fromRGB(35, 45, 55) }
			)
		end)

		button.MouseButton1Up:Connect(function()
			isPressed = false
			local targetScale = isHovered and 1.05 or 1.0
			local targetPos = isHovered and UDim2.new(-0.06, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
			playItemTween(
				choiceScale,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = targetScale }
			)
			playItemTween(
				clone,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = targetPos }
			)
		end)

		button.MouseButton1Click:Connect(function()
			-- 🌟 클릭 피드백: 선택한 버튼 팝핑 & 나머지 버튼 빠른 퇴장
			playItemTween(
				choiceScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.08 }
			)
			playItemTween(
				clone,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = Color3.fromRGB(80, 100, 130) }
			)

			-- 다른 선택지들은 오른쪽으로 즉시 슬라이드 퇴장
			if choiceContainer then
				for _, other in ipairs(choiceContainer:GetChildren()) do
					if other ~= clone and other:IsA("GuiObject") and other ~= choiceTemplate then
						TweenService:Create(
							other,
							TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{ Position = UDim2.new(1.6, 0, 0, 0), BackgroundTransparency = 1 }
						):Play()
					end
				end
			end

			task.delay(0.12, function()
				DialogueClient.ChooseDialogue(index)
			end)
		end)
	end
end

-------------------------------------------------
--// Typewriter Animation
-------------------------------------------------
local function animateText(
	textObject: TextLabel,
	fullText: string,
	typingSoundName: string?,
	onChoicesTriggered: (() -> ())?,
	onComplete: (() -> ())?
)
	if _currentDialogueCoroutine then
		coroutine.close(_currentDialogueCoroutine)
	end

	_skipRequested = false

	_currentDialogueCoroutine = coroutine.create(function()
		textObject.Text = fullText
		textObject.MaxVisibleGraphemes = 0

		local sound = typingSoundName and pcall(function()
			return SoundLibrary(typingSoundName)
		end) and SoundLibrary(typingSoundName) or nil
		local soundId: string?
		if sound and typeof(sound) == "Instance" and sound:IsA("Sound") then
			soundId = sound.SoundId
		elseif sound and typeof(sound) == "string" then
			soundId = sound
		end

		local utf8Len = utf8.len(fullText) or #fullText
		local triggerIndex = math.max(1, math.floor(utf8Len * 0.25))
		local choicesTriggered = false

		local i = 1
		while i <= utf8Len do
			textObject.MaxVisibleGraphemes = i

			if not _skipRequested and soundId and i % 2 == 1 then
				AudioController.PlayOn2D(soundId, 0.28)
			end

			if not choicesTriggered and i >= triggerIndex then
				choicesTriggered = true
				if onChoicesTriggered then
					pcall(onChoicesTriggered)
				end
			end

			local startByte = utf8.offset(fullText, i)
			local nextByte = utf8.offset(fullText, i + 1)
			local char = if startByte and nextByte
				then string.sub(fullText, startByte, nextByte - 1)
				elseif startByte then string.sub(fullText, startByte, #fullText)
				else ""

			local typingSpeed: number
			if _skipRequested then
				typingSpeed = 0.005
			else
				if char == "." or char == "," or char == "!" or char == "?" then
					typingSpeed = 0.22
				elseif char == " " then
					typingSpeed = 0.02
				else
					typingSpeed = 0.035
				end
			end

			task.wait(typingSpeed)
			i += 1
		end

		textObject.MaxVisibleGraphemes = -1

		if not choicesTriggered then
			choicesTriggered = true
			if onChoicesTriggered then
				pcall(onChoicesTriggered)
			end
		end

		if type(onComplete) == "function" then
			pcall(onComplete)
		end
	end)

	coroutine.resume(_currentDialogueCoroutine)
end

-------------------------------------------------
--// GUI Setup
-------------------------------------------------
local function setupGui()
	if dialogueGui and dialogueFrame and choiceContainer then
		return
	end

	if not playerGui then
		local player = Players.LocalPlayer
		if player then
			playerGui = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
		end
	end

	if not playerGui then
		return
	end

	dialogueGui = playerGui:FindFirstChild("DialogueGui") or playerGui:WaitForChild("DialogueGui", 5) :: ScreenGui?
	if not dialogueGui then
		return
	end

	backdrop = findDescendant(dialogueGui, "Backdrop") :: Frame?
	dialogueFrame = findDescendant(dialogueGui, "DialogueFram") :: Frame?
	if dialogueFrame then
		frameScale = dialogueFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		frameScale.Name = "FramScale"
		frameScale.Parent = dialogueFrame
		originalFramePosition = dialogueFrame.Position
	end

	nameText = findDescendant(dialogueFrame, "NameText") :: TextLabel?
	npcInfoText = findDescendant(dialogueFrame, "NpcInfoText") :: TextLabel?
	contextText = findDescendant(dialogueFrame, "Context") :: TextLabel?
	headerMidFrame = findDescendant(dialogueFrame, "MidFrame") :: Frame?

	if headerMidFrame then
		leftWing = headerMidFrame:FindFirstChild("LeftSide") :: ImageLabel?
		rightWing = headerMidFrame:FindFirstChild("RightSide") :: ImageLabel?
	end

	choiceContainer = getChoiceContainer(dialogueGui)
	if choiceContainer then
		originalChoicePosition = choiceContainer.Position
	end
	choiceTemplate = choiceContainer and choiceContainer:FindFirstChild("Template") :: Frame?

	fastButton = findDescendant(dialogueFrame, "FastButton") :: GuiButton?
	if fastButton and fastButton:IsA("GuiButton") then
		fastButton.MouseButton1Click:Connect(function()
			DialogueClient.SkipTyping()
		end)
	end

	if dialogueGui then
		dialogueGui.Enabled = false
	end
end

-------------------------------------------------
--// Open & Close Dialogue Functions
-------------------------------------------------
local function openDialogue(npcId: string, dialogueId: string, isNodeTransition: boolean?)
	if not dialogueGui or not dialogueFrame or not choiceContainer then
		setupGui()
	end

	if not dialogueGui or not dialogueFrame or not contextText then
		warn("[DialogueClient] Dialogue UI 요소를 찾을 수 없음")
		return
	end

	local npcData = NpcDialogueData[npcId]
	if not npcData then
		warn(string.format("[DialogueClient] 대화 데이터를 찾을 수 없음: %s", tostring(npcId)))
		return
	end

	local dialogue = npcData.DialogueTree[dialogueId]
	if not dialogue then
		warn(string.format("[DialogueClient] 대화 노드를 찾을 수 없음: %s.%s", tostring(npcId), tostring(dialogueId)))
		return
	end

	CurrentNpcId = npcId
	CurrentDialogueId = dialogueId

	setTextObject(nameText, npcData.Name or npcId)
	if npcInfoText then
		setTextObject(npcInfoText, npcData.Info or "")
		npcInfoText.Visible = (npcData.Info ~= nil and npcData.Info ~= "")
	end

	-- 이전 선택지 청소 (노드 전환 시 부드러운 퇴장)
	clearChoices(isNodeTransition == true)

	if not dialogue.Choices or #dialogue.Choices == 0 then
		DialogueClient.Close()
		return
	end

	dialogueGui.Enabled = true
	dialogueFrame.Visible = true

	-- 1. 대화창 진입 연출 (카메라 줌인 + 백드롭 + 대화창 슬라이드업)
	if not isNodeTransition or not _isOpen then
		_isOpen = true
		stopAllTweens()

		-- 카메라 줌인
		setCameraDialogueMode(true)

		-- 백드롭 페이드인
		if backdrop then
			backdrop.BackgroundTransparency = 1
			trackTween(TweenService:Create(
				backdrop,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 0.45 }
			))
		end

		-- 모든 텍스트/장식 투명도 복구
		if contextText then
			contextText.TextTransparency = 0
		end
		if nameText then
			nameText.TextTransparency = 0
		end
		for _, desc in ipairs(dialogueFrame:GetDescendants()) do
			if desc:IsA("ImageLabel") then
				desc.ImageTransparency = 0
			end
		end

		-- 메인 대화창 아래에서 위로 쫀득하게 등장
		if frameScale then
			frameScale.Scale = 0.9
			trackTween(TweenService:Create(
				frameScale,
				TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			))
		end

		dialogueFrame.Position = originalFramePosition + UDim2.fromScale(0, 0.18)
		dialogueFrame.BackgroundTransparency = 0.8
		trackTween(TweenService:Create(
			dialogueFrame,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = originalFramePosition, BackgroundTransparency = 0.08 }
		))

		-- 이름표 날개 호흡 애니메이션
		if leftWing and rightWing then
			if _wingPulseTween then
				_wingPulseTween:Cancel()
			end
			_wingPulseTween = TweenService:Create(
				leftWing,
				TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ ImageColor3 = Color3.fromRGB(255, 225, 80) }
			)
			_wingPulseTween:Play()
		end
	end

	if choiceContainer then
		choiceContainer.Visible = false
	end

	_suppressClose = true
	_pendingClose = false

	-- 2. 타이핑 애니메이션 및 완료 시 선택지 팝업 트리거
	animateText(
		contextText,
		dialogue.Text or "",
		npcData.TypingSoundName,
		function()
			-- 선택지 생성 및 표시
			if choiceContainer then
				choiceContainer.Visible = true
			end
			for index, choice in ipairs(dialogue.Choices) do
				createChoiceClone(choice, index)
			end
		end,
		function()
			_suppressClose = false
			if _pendingClose then
				_pendingClose = false
				DialogueClient.Close()
			end
		end
	)
end

-------------------------------------------------
--// Public Controller Methods
-------------------------------------------------
function DialogueClient.ChooseDialogue(choiceIndex: number)
	if not CurrentNpcId or not CurrentDialogueId then
		return
	end

	local npcData = NpcDialogueData[CurrentNpcId]
	local nextId: string?
	if npcData and CurrentDialogueId then
		local current = npcData.DialogueTree[CurrentDialogueId]
		if current and current.Choices and current.Choices[choiceIndex] then
			nextId = current.Choices[choiceIndex].Next
		end
	end

	Net.DialogueService.ChooseDialogue.Fire({
		NpcId = CurrentNpcId,
		ChoiceIndex = choiceIndex,
	})

	if nextId then
		if nextId == "End" then
			DialogueClient.Close()
		else
			openDialogue(CurrentNpcId, nextId, true)
		end
	end
end

function DialogueClient.SkipTyping()
	_skipRequested = true
end

function DialogueClient.Close()
	if not _isOpen and (not dialogueGui or not dialogueGui.Enabled) then
		return
	end

	_isOpen = false
	_suppressClose = false
	_pendingClose = false
	_skipRequested = false

	if _currentDialogueCoroutine then
		coroutine.close(_currentDialogueCoroutine)
		_currentDialogueCoroutine = nil
	end

	if _wingPulseTween then
		_wingPulseTween:Cancel()
		_wingPulseTween = nil
	end

	stopAllTweens()

	-- 1. 카메라 원래 시야각으로 부드럽게 복귀
	setCameraDialogueMode(false)

	-- 2. 백드롭 페이드아웃
	if backdrop then
		trackTween(TweenService:Create(
			backdrop,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		))
	end

	-- 3. 선택지들 오른쪽으로 부드럽게 페이드아웃
	if choiceContainer then
		for _, child in ipairs(choiceContainer:GetChildren()) do
			if child:IsA("GuiObject") and child ~= choiceTemplate then
				trackTween(TweenService:Create(
					child,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.new(1.6, 0, 0, 0), BackgroundTransparency = 1 }
				))
				for _, desc in ipairs(child:GetDescendants()) do
					if desc:IsA("TextLabel") then
						trackTween(TweenService:Create(
							desc,
							TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{ TextTransparency = 1 }
						))
					end
				end
			end
		end
	end

	-- 4. 메인 대화창 및 텍스트/아이콘 자연스럽게 슬라이드 다운 & 페이드아웃
	if dialogueFrame and dialogueGui then
		local offScreenPos = originalFramePosition + UDim2.fromScale(0, 0.25)
		local closeTween = trackTween(TweenService:Create(
			dialogueFrame,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = offScreenPos, BackgroundTransparency = 1 }
		))

		if frameScale then
			trackTween(TweenService:Create(
				frameScale,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.9 }
			))
		end

		if contextText then
			trackTween(TweenService:Create(
				contextText,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			))
		end

		if nameText then
			trackTween(TweenService:Create(
				nameText,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			))
		end

		if npcInfoText then
			trackTween(TweenService:Create(
				npcInfoText,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			))
		end

		for _, desc in ipairs(dialogueFrame:GetDescendants()) do
			if desc:IsA("ImageLabel") then
				trackTween(TweenService:Create(
					desc,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ ImageTransparency = 1 }
				))
			end
		end

		closeTween.Completed:Once(function()
			if not _isOpen and dialogueGui then
				dialogueGui.Enabled = false
				dialogueFrame.Visible = false
				dialogueFrame.Position = originalFramePosition
				dialogueFrame.BackgroundTransparency = 0.08
				if frameScale then
					frameScale.Scale = 1
				end
				if contextText then
					contextText.TextTransparency = 0
				end
				if nameText then
					nameText.TextTransparency = 0
				end
				if npcInfoText then
					npcInfoText.TextTransparency = 0
				end
				for _, desc in ipairs(dialogueFrame:GetDescendants()) do
					if desc:IsA("ImageLabel") then
						desc.ImageTransparency = 0
					end
				end
				clearChoices(false)
			end
		end)
	else
		clearChoices(false)
	end

	CurrentNpcId = nil
	CurrentDialogueId = nil
end

function DialogueClient.Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	playerGui = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	task.spawn(setupGui)
end

function DialogueClient.Start()
	if not RunService:IsClient() then
		return
	end

	Net.DialogueService.StartDialogue.On(function(npcId)
		openDialogue(npcId, "Start")
	end)

	Net.DialogueService.UpdateDialogueUI.On(function(data)
		if typeof(data) ~= "table" or not data.NpcId or not data.DialogueId then
			return
		end
		openDialogue(data.NpcId, data.DialogueId, true)
	end)

	Net.DialogueService.CloseDialogue.On(function()
		if _suppressClose then
			_pendingClose = true
			return
		end
		DialogueClient.Close()
	end)
end

return DialogueClient
