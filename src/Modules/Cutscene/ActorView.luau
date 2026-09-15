local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Cleanup = require(script.Parent.Cleanup)
local ActorView = {}
ActorView.__index = ActorView
local bodyNames = {
	HumanoidRootPart = true, Head = true, Torso = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function dispose(actor)
	actor.Active = false
	if actor.Connection then actor.Connection:Disconnect(); actor.Connection = nil end
	for _, saved in actor.Hidden do
		Cleanup.Try("Restore actor appearance", function()
			if saved.Instance.Parent then saved.Instance[saved.Property] = saved.Value end
		end)
	end
	table.clear(actor.Hidden)
	if actor.Track then
		local index = table.find(actor.Tracks, actor.Track)
		if index then table.remove(actor.Tracks, index) end
		Cleanup.Try("Stop avatar track", function() actor.Track:Stop(0) end)
		Cleanup.Try("Destroy avatar track", function() actor.Track:Destroy() end)
		actor.Track = nil
	end
	if actor.Animation then Cleanup.Try("Avatar animation", function() actor.Animation:Destroy() end); actor.Animation = nil end
	if actor.Model then Cleanup.Try("Avatar model", function() actor.Model:Destroy() end); actor.Model = nil end
end

function ActorView.new(state, config, tracks, onCreated)
	local self = setmetatable({ Actors = {}, Closed = false }, ActorView)
	if onCreated then onCreated(self) end -- publish ownership BEFORE any yielding work
	self.StateConnection = state.AncestryChanged:Connect(function()
		if not state.Parent then self:Destroy() end
	end)
	local deadline = os.clock() + 12
	for name, role in config.Actors or {} do
		local actor = { Active = true, Finished = false, Hidden = {}, Tracks = tracks }
		table.insert(self.Actors, actor)
		local function valid()
			return actor.Active and not self.Closed and state.Parent ~= nil and os.clock() < deadline
		end
		local function alive()
			return actor.Active and not self.Closed and state.Parent ~= nil
		end
		task.spawn(function()
			local ok, err = pcall(function()
				local slot, template
				while valid() do
					local profiles = state:FindFirstChild("ActorProfiles")
					local profile = profiles and profiles:FindFirstChild(tostring(Players.LocalPlayer.UserId))
					slot = profile and profile:FindFirstChild(role)
					local refs = state:FindFirstChild("RigTracks")
					local ref = refs and refs:FindFirstChild(name)
					local modelRef = ref and ref:FindFirstChild("Model")
					template = modelRef and modelRef.Value
					if slot and slot:GetAttribute("Status") then
						if slot:GetAttribute("Status") ~= "Ready" then return end
						if template and slot:FindFirstChild("Description") then break end
					end
					RunService.Heartbeat:Wait()
				end
				if not valid() then return end
				local sourceRoot = template:FindFirstChild("HumanoidRootPart")
				local sourceHumanoid = template:FindFirstChildOfClass("Humanoid")
				assert(sourceRoot, name .. " requires HumanoidRootPart")
				local rigType = if role == "Friend" then Enum.HumanoidRigType.R6
					elseif sourceHumanoid then sourceHumanoid.RigType
					elseif template:FindFirstChild("UpperTorso") then Enum.HumanoidRigType.R15
					elseif template:FindFirstChild("Torso") then Enum.HumanoidRigType.R6 else nil
				assert(rigType, name .. " requires a standard R6 or R15 skeleton")
				local description = slot.Description:Clone()
				-- Keep authored staging/proportions; clothing, colors, body assets and accessories are personal.
				local authored = if sourceHumanoid then sourceHumanoid:GetAppliedDescription() else Instance.new("HumanoidDescription")
				for _, property in { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" } do
					description[property] = authored[property]
				end
				authored:Destroy()
				local made, result = pcall(function()
					return Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
				end)
				description:Destroy()
				assert(made, tostring(result))
				if not valid() then result:Destroy(); return end -- late API result cannot resurrect a scene
				actor.Model = result
				local model = result
				model.Name = "LocalCutscene_" .. name
				model:SetAttribute("ActorUserId", slot:GetAttribute("UserId"))
				local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar has no root")
				local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar has no Humanoid")
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				humanoid.AutoRotate = false
				humanoid.BreakJointsOnDeath = false
				humanoid.EvaluateStateMachine = false
				local visibility = {}
				for _, item in model:GetDescendants() do
					if item:IsA("BaseScript") then item:Destroy()
					elseif item:IsA("BasePart") then
						item.Anchored = item == root
						item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
						item.Massless = true
						visibility[item] = item.LocalTransparencyModifier
						item.LocalTransparencyModifier = 1
					end
				end
				model:ScaleTo(template:GetScale())
				model:PivotTo(sourceRoot.CFrame * root.CFrame:Inverse() * model:GetPivot())
				model.Parent = workspace -- local-only; never replaces the real Player.Character
				actor.Root, actor.SourceRoot = root, sourceRoot
				actor.Animation = Instance.new("Animation")
				actor.Animation.AnimationId = "rbxassetid://" .. config.Animations[name]
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				actor.Track = animator:LoadAnimation(actor.Animation)
				actor.Track.Priority = Enum.AnimationPriority.Action4
				actor.Track.Looped = false
				actor.Track:Play(0, 1, 0)
				local animationDeadline = math.min(deadline, os.clock() + 2)
				while alive() and os.clock() < animationDeadline and actor.Track.Length <= 0 do RunService.Heartbeat:Wait() end
				if not alive() then return end
				if actor.Track.Length <= 0 then
					warn("[CutsceneActors] " .. name .. " animation unavailable; showing personalized static actor")
					Cleanup.Try("Unavailable avatar track", function() actor.Track:Stop(0); actor.Track:Destroy() end)
					actor.Track = nil
					actor.Animation:Destroy()
					actor.Animation = nil
				end
				-- Swap only after the replacement is fully ready. Keep source joints/VFX intact.
				local function hide(item)
					local owner = item
					local part = if item:IsA("BasePart") then item else item.Parent
					local isAppearance = part and part.Parent == template and bodyNames[part.Name] == true
					while owner and owner ~= template do
						if owner:IsA("Accessory") then
							isAppearance = true
							break
						end
						owner = owner.Parent
					end
					if not isAppearance then return end -- retain separately authored scene props/weapons
					local property = if item:IsA("BasePart") then "LocalTransparencyModifier"
						elseif item:IsA("Decal") then "Transparency" else nil
					if property then
						table.insert(actor.Hidden, { Instance = item, Property = property, Value = item[property] })
						item[property] = 1
					end
				end
				for _, item in template:GetDescendants() do hide(item) end
				actor.Connection = template.DescendantAdded:Connect(hide)
				if sourceHumanoid then
					table.insert(actor.Hidden, { Instance = sourceHumanoid, Property = "DisplayDistanceType", Value = sourceHumanoid.DisplayDistanceType })
					sourceHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
				for part, value in visibility do if part.Parent then part.LocalTransparencyModifier = value end end
				if actor.Track then table.insert(tracks, actor.Track) end -- same ECS PreAnimation clock
				actor.Committed = true
			end)
			actor.Finished = true
			if not actor.Committed then
				dispose(actor)
				warn("[CutsceneActors] " .. name .. ": using authored rig (" .. (if ok then "appearance unavailable" else tostring(err)) .. ")")
			end
		end)
	end
	while state.Parent and os.clock() < deadline do
		local finished = true
		for _, actor in self.Actors do if not actor.Finished then finished = false end end
		if finished then break end
		RunService.Heartbeat:Wait()
	end
	for _, actor in self.Actors do
		if not actor.Finished then dispose(actor) end
	end
	if not state.Parent then self:Destroy() end
	return self
end

function ActorView:PreAnimation()
	for _, actor in self.Actors do
		if actor.Committed and actor.Root and actor.Root.Parent and actor.SourceRoot.Parent then
			actor.Root.CFrame = actor.SourceRoot.CFrame
		end
	end
end

function ActorView:Destroy()
	if self.Closed then return end
	self.Closed = true
	if self.StateConnection then self.StateConnection:Disconnect(); self.StateConnection = nil end
	for _, actor in self.Actors do Cleanup.Try("Dispose avatar", function() dispose(actor) end) end
end

return ActorView
