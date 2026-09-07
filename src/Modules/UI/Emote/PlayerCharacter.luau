-- Shared character preview used by lobby and in-game emote wheels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source
local effect = Vide.effect
local cleanup = Vide.cleanup
local read = Vide.read

local characterCache: { [number]: Model } = {}
local loadingCallbacks: { [number]: { (Model) -> () } } = {}

export type Props = {
	UserId: (number | (() -> number))?,
	Origin: (CFrame | (() -> CFrame))?,
	UseWorldModel: (boolean | (() -> boolean))?,
	Children: any?,
	AnimationId: (number | string | (() -> number | string))?,
	PlaybackSpeed: number?,
}

local function fetchCharacterModel(userId: number, callback: (Model) -> ())
	local cachedModel = characterCache[userId]
	if cachedModel then
		callback(cachedModel:Clone())
		return
	end

	if loadingCallbacks[userId] then
		table.insert(loadingCallbacks[userId], callback)
		return
	end

	loadingCallbacks[userId] = { callback }

	task.spawn(function()
		local success, result = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
			local r6Model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)

			return r6Model
		end)

		local callbacks = loadingCallbacks[userId]
		loadingCallbacks[userId] = nil

		if not success or not result then
			warn(`[PlayerCharacter] Failed to load character model for UserId {userId}: {result}`)
			return
		end

		if result.HumanoidRootPart then
			result.HumanoidRootPart.Anchored = true
		end

		local animateScript = result:FindFirstChild("Animate")
		if animateScript then
			animateScript:Destroy()
		end

		local healthScript = result:FindFirstChild("Health")
		if healthScript then
			healthScript:Destroy()
		end

		characterCache[userId] = result

		for _, cb in callbacks do
			cb(result:Clone())
		end
	end)
end

local function resetPose(model: Model, origin: CFrame?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			descendant.Transform = CFrame.new()
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and origin then
		hrp.CFrame = origin
	elseif origin then
		model:PivotTo(origin)
	end
end

return function(props: Props)
	local userId = read(props.UserId) or (Players.LocalPlayer and Players.LocalPlayer.UserId) or 1
	local useWorldModel = read(props.UseWorldModel)
	local containerType = if useWorldModel then "WorldModel" else "Model"
	local character = source(nil :: Model?)

	fetchCharacterModel(userId, function(clonedModel)
		character(clonedModel)
	end)

	effect(function()
		local model = character()
		if not model then
			return
		end

		local origin = read(props.Origin) or CFrame.new(0, 0, 0)
		resetPose(model, origin)

		local rawAnimId = read(props.AnimationId)
		local playbackSpeed = read(props.PlaybackSpeed) or 1
		if not rawAnimId or rawAnimId == "" then
			return
		end

		local track
		local animation
		local active = true

		task.spawn(function()
			while active and not model:IsDescendantOf(game) do
				model.AncestryChanged:Wait()
			end
			if not active then
				return
			end

			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return
			end

			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid

			local animId = tostring(rawAnimId)
			animation = Instance.new("Animation")
			animation.AnimationId = if string.sub(animId, 1, 13) == "rbxassetid://"
				then animId
				else `rbxassetid://{animId}`

			track = animator:LoadAnimation(animation)
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action4
			track:AdjustSpeed(playbackSpeed)
			track:Play()
		end)

		cleanup(function()
			active = false
			if track then
				track:Stop()
				track:Destroy()
			end
			if animation then
				animation:Destroy()
			end
			if model and model.Parent then
				resetPose(model, origin)
			end
		end)
	end)

	cleanup(function()
		local model = character()
		if model then
			model:Destroy()
		end
	end)

	return create(containerType)({
		character,
		props.Children,
	})
end
