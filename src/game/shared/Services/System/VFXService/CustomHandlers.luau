local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)
local TimeService = require(script.Parent.Parent.TimeService)
local CustomHandlers = {}

local KITSUNE_CLONE_ANIMATIONS = {
	[1] = "rbxassetid://133911301867999",
	[2] = "rbxassetid://110931334362071",
	[3] = "rbxassetid://128258077329376",
	[4] = "rbxassetid://88135449447525",
}
local KitsuneTracks = setmetatable({}, { __mode = "k" })

local function getSourceCFrame(source: Instance): CFrame
	if source:IsA("Model") then
		return if source.PrimaryPart then source.PrimaryPart.CFrame else source:GetPivot()
	end
	return (source :: BasePart).CFrame
end

local function playKitsuneAnimation(cloneModel: Model, cloneIndex: number): AnimationTrack?
	local animationId = KITSUNE_CLONE_ANIMATIONS[cloneIndex]
	if animationId == "" then
		return nil
	end

	local tracks = KitsuneTracks[cloneModel]
	if not tracks then
		tracks = {}
		KitsuneTracks[cloneModel] = tracks
	end

	local track = tracks[animationId]
	if not track then
		local controller = cloneModel:FindFirstChildOfClass("AnimationController")
			or cloneModel:FindFirstChildOfClass("Humanoid")
		if not controller then
			controller = Instance.new("AnimationController")
			controller.Parent = cloneModel
		end
		local animator = controller:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = controller
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local success, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		animation:Destroy()
		if not success then
			warn(`Kitsune clone {cloneIndex} animation failed: {result}`)
			return nil
		end
		track = result
		tracks[animationId] = track
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0, 1, TimeService:GetGameSpeed())
	return track
end

function CustomHandlers.Hacked(_, sourceModel, targetModel)
	local target = targetModel or sourceModel
	if not target then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(0, 241, 12)
	highlight.FillTransparency = -10
	highlight.OutlineTransparency = 1
	highlight.Parent = target

	for _, descendant: Instance in target:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Texture") then
			descendant:Destroy()
		elseif descendant:IsA("MeshPart") then
			descendant.TextureID = ""
		end

		if descendant:IsA("BasePart") then
			if target.PrimaryPart == descendant or target.Name == "HumanoidRootPart" then
				descendant.Transparency = 1
				continue
			end
			descendant.Material = Enum.Material.Glass
			descendant.Color = Color3.new(0.25, 0.5, 0)
			descendant.Transparency = -10000
			descendant.Reflectance = 10000
		end
	end
end

function CustomHandlers.KitsuneCloneAttack(_, sourceModel)
	if not sourceModel or not sourceModel:IsDescendantOf(workspace) then
		return
	end
	if not sourceModel:IsA("Model") and not sourceModel:IsA("BasePart") then
		return
	end

	if not CustomHandlers.KitsunePool then
		local cloneModel = ReplicatedStorage.Assets.VFX.Towers["Kitsune Samurai"].KitsuneClone
		assert(cloneModel:IsA("Model"), "KitsuneClone must be a Model")
		CustomHandlers.KitsunePool = InstanceCache.new(cloneModel, 4, workspace:WaitForChild("Caches"))
	end

	local pool = CustomHandlers.KitsunePool
	local clones = {}
	local activeTracks = {}
	local sourceCFrame = getSourceCFrame(sourceModel)
	for cloneIndex = 1, 4 do
		local cloneModel = pool:GetInstance(sourceCFrame) :: Model
		cloneModel:SetAttribute("CloneIndex", cloneIndex)
		local root = cloneModel.PrimaryPart or cloneModel:FindFirstChild("HumanoidRootPart")
		for _, descendant in cloneModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				if root then
					descendant.Anchored = descendant == root
				end
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		clones[cloneIndex] = cloneModel
	end

	local elapsed = 0
	local connection
	local speedConnection
	local function cleanup()
		connection:Disconnect()
		if speedConnection then
			speedConnection:Disconnect()
		end
		for _, track in activeTracks do
			track:Stop(0)
		end
		for _, cloneModel in clones do
			cloneModel:SetAttribute("CloneIndex", nil)
			pool:ReturnInstance(cloneModel)
		end
	end

	connection = RunService.PreRender:Connect(function(dt)
		elapsed += dt * TimeService:GetGameSpeed()
		if elapsed >= 2.5 or not sourceModel:IsDescendantOf(workspace) then
			cleanup()
			return
		end

		local currentCFrame = getSourceCFrame(sourceModel)
		for _, cloneModel in clones do
			cloneModel:PivotTo(currentCFrame)
		end
	end)

	local ClientSignals = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ClientSignals)
	speedConnection = ClientSignals.GameSpeedChanged:Connect(function(newSpeed)
		for _, track in activeTracks do
			if track.IsPlaying then
				track:AdjustSpeed(newSpeed)
			end
		end
	end)

	for cloneIndex, cloneModel in clones do
		local track = playKitsuneAnimation(cloneModel, cloneIndex)
		if track then
			table.insert(activeTracks, track)
		end
	end
end

return CustomHandlers
