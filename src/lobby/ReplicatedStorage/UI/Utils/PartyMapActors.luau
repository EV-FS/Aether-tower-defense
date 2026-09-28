local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local PartyInviteOverlay = require(ReplicatedStorage.UI.Components.PartyInviteOverlay)

local PartyMapActors = {}

local ANIMATIONS = {
	["1"] = 110396570773663,
	["2"] = 72879440763525,
	["3"] = 106754121905137,
	["4"] = 109699689048649,
}

local FOOT_NAMES = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }
local FOOT_CLEARANCE = 0.08
local FLOOR_ATTRIBUTE = "PartyFloorY"
local nextGroundingId = 0

type AvatarPlacement = {
	RootCFrame: CFrame,
	Scale: number,
	RigType: Enum.HumanoidRigType,
	FootY: number?,
}

local function findRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart", true)
	return if root and root:IsA("BasePart") then root else nil
end

local function inviteAnchor(model: Model): { Root: BasePart, Torso: BasePart? }?
	local root = findRoot(model)
	if not root then return nil end
	local torso = model:FindFirstChild("UpperTorso", true)
		or model:FindFirstChild("Torso", true)
		or model:FindFirstChild("LowerTorso", true)
	return {
		Root = root,
		Torso = if torso and torso:IsA("BasePart") then torso else nil,
	}
end

local function footBottom(model: Model): number?
	local bottom: number? = nil
	for _, name in FOOT_NAMES do
		local foot = model:FindFirstChild(name, true)
		if foot and foot:IsA("BasePart") then
			local cframe = foot.CFrame
			local halfHeight = (math.abs(cframe.RightVector.Y) * foot.Size.X
				+ math.abs(cframe.UpVector.Y) * foot.Size.Y
				+ math.abs(cframe.LookVector.Y) * foot.Size.Z) * 0.5
			bottom = math.min(bottom or math.huge, foot.Position.Y - halfHeight)
		end
	end
	if not bottom then
		local root = findRoot(model)
		local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
		if root and humanoid then
			return root.Position.Y - root.Size.Y * 0.5 - humanoid.HipHeight
		end
	end
	return bottom
end

local function findModel(scene: Instance, name: string): Model?
	local found: Model? = nil
	for _, descendant in scene:GetDescendants() do
		if descendant.Name == name and descendant:IsA("Model") then
			if found then
				warn(`[PartyMapActors] More than one model is named "{name}".`)
				return nil
			end
			found = descendant
		end
	end
	if not found then
		warn(`[PartyMapActors] Model "{name}" was not found in PartyMap.`)
	end
	return found
end

local function setOutline(model: Model)
	local highlight: Highlight? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Highlight") then
			if not highlight then
				highlight = descendant
			else
				descendant.Enabled = false
			end
		end
	end
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "PartyOutline"
		highlight.Parent = model
	end
	highlight.Adornee = model
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.Enabled = true
end

local function prepareRig(model: Model): boolean
	local root = findRoot(model)
	if not root then
		warn(`[PartyMapActors] Rig "{model.Name}" is missing a HumanoidRootPart.`)
		return false
	end
	local motor = model:FindFirstChildWhichIsA("Motor6D", true)
	local animatedJoint = motor or model:FindFirstChildWhichIsA("AnimationConstraint", true)

	-- LocalSceneView anchors the whole map. Keep the actor's root in place while
	-- allowing its animated joints to move the other parts.
	if animatedJoint then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= root then
				descendant.Anchored = false
			end
		end
	end
	root.Anchored = true
	return true
end

local function getAnimator(model: Model): Animator
	local host = model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)
	if not host then
		host = Instance.new("AnimationController")
		host.Name = "PartyAnimationController"
		host.Parent = model
	end
	local animator = host:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = host
	end
	return animator
end

local function playAnimation(model: Model, assetId: number): () -> ()
	local animation = Instance.new("Animation")
	animation.Name = "PartyIdleAnimation"
	animation.AnimationId = `rbxassetid://{assetId}`
	animation.Parent = model
	local ok, result = pcall(function()
		return getAnimator(model):LoadAnimation(animation)
	end)
	if not ok then
		warn(`[PartyMapActors] Could not play animation {assetId} on model "{model.Name}": {result}`)
		animation:Destroy()
		return function() end
	end
	local track = result :: AnimationTrack
	track.Looped = true
	track:Play(0.15)
	return function()
		track:Stop(0)
		track:Destroy()
		animation:Destroy()
	end
end

local function createMemberAvatar(placement: AvatarPlacement, userId: number): Model?
	local player = Players:GetPlayerByUserId(userId)
	local description: HumanoidDescription? = nil
	local liveHumanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if liveHumanoid and player:HasAppearanceLoaded() then
		local ok, result = pcall(liveHumanoid.GetAppliedDescription, liveHumanoid)
		if ok then description = result end
	end
	if not description then
		local ok, result = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, userId)
		if ok then description = result end
	end
	if not description then
		warn(`[PartyMapActors] Could not load appearance for user {userId}.`)
		return nil
	end
	local made, avatar = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, placement.RigType)
	description:Destroy()
	if not made or not avatar then
		warn(`[PartyMapActors] Could not create avatar for user {userId}: {avatar}`)
		return nil
	end
	local avatarRoot = findRoot(avatar)
	if not avatarRoot then
		avatar:Destroy()
		warn(`[PartyMapActors] Avatar for user {userId} has no HumanoidRootPart.`)
		return nil
	end
	local humanoid = avatar:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.AutoRotate = false
		humanoid.EvaluateStateMachine = false
	end
	for _, descendant in avatar:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	avatar:ScaleTo(placement.Scale)
	avatar:PivotTo(placement.RootCFrame * avatarRoot.CFrame:Inverse() * avatar:GetPivot())
	local avatarFoot = footBottom(avatar)
	if placement.FootY and avatarFoot then
		avatar:PivotTo(CFrame.new(0, placement.FootY - avatarFoot + FOOT_CLEARANCE, 0) * avatar:GetPivot())
		avatar:SetAttribute(FLOOR_ATTRIBUTE, placement.FootY + FOOT_CLEARANCE)
	end
	avatar:SetAttribute("PartyActorUserId", userId)
	return avatar
end

function PartyMapActors.Personalize(scene: Instance): boolean
	local slot = findModel(scene, "1")
	if not slot then return false end
	local sourceRoot = findRoot(slot)
	if not sourceRoot then
		warn("[PartyMapActors] Slot 1 is missing a HumanoidRootPart; keeping the original rig.")
		return false
	end
	local sourceFootBottom = footBottom(slot)
	local player = Players.LocalPlayer
	local humanoid = slot:FindFirstChildWhichIsA("Humanoid", true)
	local rigType = if humanoid then humanoid.RigType else Enum.HumanoidRigType.R15
	local description: HumanoidDescription?
	local ownHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if ownHumanoid and player:HasAppearanceLoaded() then
		local ok, result = pcall(ownHumanoid.GetAppliedDescription, ownHumanoid)
		if ok then description = result end
	end
	if not description then
		local ok, result = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, player.UserId)
		if ok then description = result end
	end
	if not description or not scene.Parent then
		if description then description:Destroy() end
		warn("[PartyMapActors] Could not load the local player's appearance.")
		return false
	end
	local made, avatar = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, rigType)
	description:Destroy()
	if not made or not avatar then
		warn(`[PartyMapActors] Could not build the local player's rig: {avatar}`)
		return false
	end
	if not scene.Parent or not slot.Parent then avatar:Destroy(); return false end
	local scale = slot:GetScale()
	local avatarRoot = findRoot(avatar)
	if not avatarRoot then
		avatar:Destroy()
		warn("[PartyMapActors] Personalized avatar is missing a HumanoidRootPart; keeping the original rig.")
		return false
	end
	avatar.Name = "1"
	avatar:SetAttribute("PartyActorUserId", player.UserId)
	local avatarHumanoid = avatar:FindFirstChildWhichIsA("Humanoid", true)
	if avatarHumanoid then
		avatarHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		avatarHumanoid.AutoRotate = false
		avatarHumanoid.EvaluateStateMachine = false
	end
	for _, descendant in avatar:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	avatar:ScaleTo(scale)
	-- Match the authored root's facing, then match feet. Model pivots differ
	-- across avatar bodies, so pivot-only placement can sink the feet.
	avatar:PivotTo(sourceRoot.CFrame * avatarRoot.CFrame:Inverse() * avatar:GetPivot())
	local avatarFootBottom = footBottom(avatar)
	if sourceFootBottom and avatarFootBottom then
		local lift = sourceFootBottom - avatarFootBottom + FOOT_CLEARANCE
		avatar:PivotTo(CFrame.new(0, lift, 0) * avatar:GetPivot())
		avatar:SetAttribute(FLOOR_ATTRIBUTE, sourceFootBottom + FOOT_CLEARANCE)
	end
	avatar.Parent = slot.Parent
	slot:Destroy()
	return true
end

function PartyMapActors.Play(scene: Instance, onInvite: (() -> ())?, shouldShowInvites: (() -> boolean)?): (() -> (), (any) -> (), (number) -> ())
	local unmounts: { () -> () } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local inviteActors: { [string]: { Root: BasePart, Torso: BasePart? } } = {}
	local slots = {}
	local groundingActors = {}
	local stopOwnAnimation: (() -> ())? = nil
	local stopped = false
	for name, assetId in ANIMATIONS do
		local model = findModel(scene, name)
		if model then
			setOutline(model)
			if prepareRig(model) then
				local root = findRoot(model) :: BasePart
				if name == "1" then
					stopOwnAnimation = playAnimation(model, assetId)
					if typeof(model:GetAttribute(FLOOR_ATTRIBUTE)) == "number" then
						groundingActors[name] = { Model = model, Root = root, Lift = 0 }
					end
				else
					local baseFoot = footBottom(model)
					local templateHumanoid = model:FindFirstChildWhichIsA("Humanoid", true)
					inviteActors[name] = inviteAnchor(model)
					slots[name] = {
						Name = name,
						Template = model,
						Current = model,
						Parent = model.Parent,
						Placement = {
							RootCFrame = root.CFrame,
							Scale = model:GetScale(),
							RigType = if templateHumanoid then templateHumanoid.RigType else Enum.HumanoidRigType.R15,
							FootY = baseFoot,
						},
						StopAnimation = playAnimation(model, assetId),
						Token = 0,
						Pending = false,
						DesiredUserId = nil,
					}
				end
			end
		end
	end

	local function restoreSlot(state)
		groundingActors[state.Name] = nil
		state.StopAnimation()
		if state.Current ~= state.Template then
			state.Current:Destroy()
			state.Template.Parent = state.Parent
		end
		state.Current = state.Template
		state.StopAnimation = playAnimation(state.Template, ANIMATIONS[state.Name])
		inviteActors[state.Name] = inviteAnchor(state.Template)
	end

	local function updateParty(snapshot)
		if stopped then return end
		local otherMembers = {}
		local members = if snapshot and type(snapshot.Members) == "table" then snapshot.Members else {}
		for _, member in members do
			if type(member.UserId) == "number" and member.UserId ~= Players.LocalPlayer.UserId then
				table.insert(otherMembers, member.UserId)
			end
		end
		for index = 2, 4 do
			local state = slots[tostring(index)]
			if state then
				local userId = otherMembers[index - 1]
				if state.DesiredUserId ~= userId then
					state.Token += 1
					state.DesiredUserId = userId
					state.Pending = userId ~= nil
					local token = state.Token
					if state.Current ~= state.Template then restoreSlot(state) end
					if userId then
						inviteActors[state.Name] = nil
						task.spawn(function()
							local avatar: Model? = nil
							for attempt = 1, 2 do
								if stopped or state.Token ~= token then return end
								avatar = createMemberAvatar(state.Placement, userId)
								if avatar then break end
								if attempt == 1 then task.wait(1) end
							end
							if stopped or not scene.Parent or state.Token ~= token or state.DesiredUserId ~= userId then
								if avatar then avatar:Destroy() end
								return
							end
							state.Pending = false
							if not avatar then return end
							state.StopAnimation()
							state.Template.Parent = nil
							avatar.Name = state.Name
							avatar.Parent = state.Parent
							state.Current = avatar
							setOutline(avatar)
							if prepareRig(avatar) then
								state.StopAnimation = playAnimation(avatar, ANIMATIONS[state.Name])
								local root = findRoot(avatar)
								if root and typeof(avatar:GetAttribute(FLOOR_ATTRIBUTE)) == "number" then
									groundingActors[state.Name] = { Model = avatar, Root = root, Lift = 0 }
								end
							else
								state.StopAnimation = function() end
							end
						end)
					elseif state.Current == state.Template then
						inviteActors[state.Name] = inviteAnchor(state.Template)
					end
				end
			end
		end
	end
	local function waitForActors(timeout: number)
		local deadline = os.clock() + timeout
		while not stopped and scene.Parent and os.clock() < deadline do
			local pending = false
			for _, state in slots do
				if state.Pending then pending = true; break end
			end
			if not pending then return end
			RunService.Heartbeat:Wait()
		end
	end
	nextGroundingId += 1
	local renderName = `PartyAvatarGrounding_{nextGroundingId}`
	RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value - 2, function()
		for _, actor in groundingActors do
			local model = actor.Model
			local root = actor.Root
			local floorY = model:GetAttribute(FLOOR_ATTRIBUTE)
			if model.Parent and root.Parent and typeof(floorY) == "number" then
				local bottom = footBottom(model)
				if bottom then
					local desiredLift = math.max(0, floorY - (bottom - actor.Lift))
					local difference = desiredLift - actor.Lift
					if math.abs(difference) > 0.005 then
						root.CFrame = CFrame.new(0, difference, 0) * root.CFrame
						actor.Lift = desiredLift
					end
				end
			end
		end
	end)
	if onInvite and playerGui then
		table.insert(unmounts, Vide.mount(function()
			return PartyInviteOverlay(inviteActors, onInvite, shouldShowInvites or function() return true end)
		end, playerGui))
	end
	local function stop()
		if stopped then return end
		stopped = true
		RunService:UnbindFromRenderStep(renderName)
		for _, unmount in unmounts do unmount() end
		if playerGui then
			for _, child in playerGui:GetChildren() do
				if child:IsA("ScreenGui") and child.Name == "PartyInviteOverlay" then
					child.Enabled = false
					child:Destroy()
				end
			end
		end
		if stopOwnAnimation then stopOwnAnimation() end
		for _, state in slots do
			state.Token += 1
			state.StopAnimation()
			if state.Current ~= state.Template then state.Current:Destroy() end
			state.Template:Destroy()
		end
	end
	return stop, updateParty, waitForActors
end

return PartyMapActors
