local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Cleanup = require(script.Parent.Cleanup)

local BODY_PARTS = {
	HumanoidRootPart = true, Head = true, Torso = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}
local SCALE_PROPERTIES = {
	"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale",
}

local LocalActorView = {}
LocalActorView.__index = LocalActorView

function LocalActorView.new(name: string, source: Model, animationId: number, tracks: { AnimationTrack }, isCurrent: () -> boolean)
	return setmetatable({
		Name = name,
		Source = source,
		AnimationId = animationId,
		Tracks = tracks,
		IsCurrent = isCurrent,
		Closed = false,
		Finished = false,
		Committed = false,
		Hidden = {},
	}, LocalActorView)
end

function LocalActorView:_alive(): boolean
	return not self.Closed and self.Source.Parent ~= nil and self.IsCurrent()
end

function LocalActorView:_hideSource(item: Instance)
	local source = self.RigModel or self.Source
	if not item:IsDescendantOf(source) then return end
	local part = if item:IsA("BasePart") then item else item.Parent
	local isAppearance = part and part.Parent == source and BODY_PARTS[part.Name] == true
	local ancestor = item
	while ancestor and ancestor ~= source do
		if ancestor:IsA("Accessory") then
			isAppearance = true
			break
		end
		ancestor = ancestor.Parent
	end
	if not isAppearance then return end -- Leave authored weapons and VFX alone.
	local property = if item:IsA("BasePart") then "LocalTransparencyModifier"
		elseif item:IsA("Decal") then "Transparency" else nil
	if property then
		table.insert(self.Hidden, { Instance = item, Property = property, Value = item[property] })
		item[property] = 1
	end
end

function LocalActorView:_build(deadline: number)
	local source = self.Source
	local sourceRoot = assert(source:FindFirstChild("HumanoidRootPart", true), `{self.Name} needs HumanoidRootPart`)
	assert(sourceRoot:IsA("BasePart"), `{self.Name} HumanoidRootPart must be a BasePart`)
	self.RigModel = if sourceRoot.Parent and sourceRoot.Parent:IsA("Model") then sourceRoot.Parent else source
	local sourceHumanoid = self.RigModel:FindFirstChildOfClass("Humanoid")
	local rigType = if sourceHumanoid then sourceHumanoid.RigType
		elseif self.RigModel:FindFirstChild("UpperTorso") then Enum.HumanoidRigType.R15
		elseif self.RigModel:FindFirstChild("Torso") then Enum.HumanoidRigType.R6 else nil
	assert(rigType, `{self.Name} needs a standard R6 or R15 skeleton`)

	local player = Players.LocalPlayer
	local characterHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local description = nil
	if characterHumanoid and player:HasAppearanceLoaded() then
		local applied, result = pcall(function() return characterHumanoid:GetAppliedDescription() end)
		if applied then description = result end
	end
	if not description then
		description = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end
	if not self:_alive() then description:Destroy(); return end
	local authored = nil
	if sourceHumanoid then
		local applied, result = pcall(function() return sourceHumanoid:GetAppliedDescription() end)
		if applied then authored = result end
	end
	if authored then
		for _, property in SCALE_PROPERTIES do
			description[property] = authored[property]
		end
		authored:Destroy()
	end

	local made, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
	end)
	description:Destroy()
	assert(made, tostring(model))
	if not self:_alive() then model:Destroy(); return end
	self.Model = model
	model.Name = `LocalCutscene_{self.Name}`
	model:SetAttribute("ActorUserId", player.UserId)
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Player avatar has no root")
	assert(root:IsA("BasePart"), "Player avatar root must be a BasePart")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Player avatar has no Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.EvaluateStateMachine = false

	local visibility = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item == root
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			item.Massless = true
			visibility[item] = { Property = "LocalTransparencyModifier", Value = item.LocalTransparencyModifier }
			item.LocalTransparencyModifier = 1
		elseif item:IsA("Decal") then
			visibility[item] = { Property = "Transparency", Value = item.Transparency }
			item.Transparency = 1
		end
	end
	model:ScaleTo(self.RigModel:GetScale())
	model:PivotTo(sourceRoot.CFrame * root.CFrame:Inverse() * model:GetPivot())
	model.Parent = workspace -- The real Player.Character is never moved or replaced.
	self.Root = root
	self.SourceRoot = sourceRoot
	self.Animation = Instance.new("Animation")
	self.Animation.AnimationId = `rbxassetid://{self.AnimationId}`
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	self.Track = animator:LoadAnimation(self.Animation)
	self.Track.Priority = Enum.AnimationPriority.Action4
	self.Track.Looped = false
	self.Track:Play(0, 1, 0)
	local animationDeadline = math.min(deadline, os.clock() + 3)
	while self:_alive() and os.clock() < animationDeadline and self.Track.Length <= 0 do
		RunService.Heartbeat:Wait()
	end
	if not self:_alive() then return end
	if self.Track.Length <= 0 then
		warn(`[CutsceneActors] {self.Name} avatar animation {self.AnimationId} was unavailable; using the personalized model in its default pose`)
		self.Track:Stop(0)
		self.Track:Destroy()
		self.Track = nil
		self.Animation:Destroy()
		self.Animation = nil
	else
	self.Track:AdjustSpeed(0)
	self.Track.TimePosition = 0
	end

	-- Keep the authored rig, its joints, props, and effect targets. Hide only
	-- its body after the personal avatar has a working animation track.
	for _, item in source:GetDescendants() do self:_hideSource(item) end
	self.Connection = source.DescendantAdded:Connect(function(item) self:_hideSource(item) end)
	if sourceHumanoid then
		table.insert(self.Hidden, {
			Instance = sourceHumanoid, Property = "DisplayDistanceType", Value = sourceHumanoid.DisplayDistanceType,
		})
		sourceHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for item, saved in visibility do
		if item.Parent then item[saved.Property] = saved.Value end
	end
	if self.Track then table.insert(self.Tracks, self.Track) end
	self.Committed = true
end

function LocalActorView:Prepare(timeout: number): boolean
	local deadline = os.clock() + timeout
	task.spawn(function()
		local ok, err = xpcall(function() self:_build(deadline) end, debug.traceback)
		self.Finished = true
		if not ok then
			warn(`[CutsceneActors] {self.Name} avatar failed: {tostring(err)}`)
		end
	end)
	while self:_alive() and not self.Finished and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	if not self.Finished or not self.Committed then
		if not self.Finished and self:_alive() then
			warn(`[CutsceneActors] {self.Name} avatar construction exceeded {timeout}s`)
		end
		self:Destroy()
		return false
	end
	return true
end

function LocalActorView:PreAnimation()
	if self.Committed and self:_alive() and self.Root.Parent and self.SourceRoot.Parent then
		self.Root.CFrame = self.SourceRoot.CFrame
	end
end

function LocalActorView:Destroy()
	if self.Closed then return end
	self.Closed = true
	if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
	for _, saved in self.Hidden do
		Cleanup.Try("Restore actor appearance", function()
			if saved.Instance.Parent then saved.Instance[saved.Property] = saved.Value end
		end)
	end
	table.clear(self.Hidden)
	if self.Track then
		local index = table.find(self.Tracks, self.Track)
		if index then table.remove(self.Tracks, index) end
		Cleanup.Try("Stop avatar track", function() self.Track:Stop(0) end)
		Cleanup.Try("Destroy avatar track", function() self.Track:Destroy() end)
		self.Track = nil
	end
	if self.Animation then self.Animation:Destroy(); self.Animation = nil end
	if self.Model then self.Model:Destroy(); self.Model = nil end
end

return LocalActorView
