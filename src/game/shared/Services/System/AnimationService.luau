--/Serivces
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Variables
local ANIMATIONS = ReplicatedStorage.Assets.Animations
local Cache = {}
local currentSpeedMultiplier = 1

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		warn(`Controller 없음: {model.Name}`)
		return nil
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

local function getTrack(tracks, name: string, level: number?): AnimationTrack?
	if level then
		for i = level, 0, -1 do
			local track = tracks[`{name}_{i}`]
			if track then
				return track
			end
		end
	end

	return tracks[name]
end

local function getExactTrack(tracks, name: string, level: number?): AnimationTrack?
	return tracks[if level ~= nil then `{name}_{level}` else name]
end

local function wrapTrack(realTrack: AnimationTrack, data)
	local wrapper = {
		_realTrack = realTrack,
	}

	function wrapper:AdjustSpeed(speed: number)
		data.TrackSpeeds[wrapper] = speed
		realTrack:AdjustSpeed(speed * currentSpeedMultiplier)
	end

	function wrapper:Play(...)
		realTrack:Play(...)
		local targetSpeed = data.TrackSpeeds[wrapper] or 1
		realTrack:AdjustSpeed(targetSpeed * currentSpeedMultiplier)
	end

	setmetatable(wrapper, {
		__index = function(_, key)
			local val = (realTrack :: any)[key]
			if type(val) == "function" then
				return function(_, ...)
					return val(realTrack, ...)
				end
			end
			return val
		end,
		__newindex = function(_, key, val)
			(realTrack :: any)[key] = val
		end,
		__eq = function(a, b)
			local realA = type(a) == "table" and a._realTrack or a
			local realB = type(b) == "table" and b._realTrack or b
			return realA == realB
		end,
	})

	return (wrapper :: any) :: AnimationTrack
end

-------------------------------------------------
--// AnimationSerivce
-------------------------------------------------
local AnimationService = {}

function AnimationService.Load(model: Model, folderName: string, sharedFolderName: string?)
	AnimationService.Clear(model)

	if not model:IsDescendantOf(workspace) then
		warn(`{model.Name}이 Workspace 밖에 있음. AnimationTrack.Length 버그 가능.`)
	end

	local animator = getAnimator(model)
	local folder = ANIMATIONS:FindFirstChild(folderName)
	local sharedFolder = if sharedFolderName then ANIMATIONS:FindFirstChild(sharedFolderName) else nil

	if not animator or not (folder or sharedFolder) then
		return
	end

	local data = {
		Tracks = {},
		TrackSpeeds = {},
		Connection = nil,
	}

	local function loadFolder(animationFolder)
		if not animationFolder then
			return
		end
		for _, anim in ipairs(animationFolder:GetChildren()) do
			if anim:IsA("Animation") and not data.Tracks[anim.Name] then
				local realTrack = animator:LoadAnimation(anim)
				data.Tracks[anim.Name] = wrapTrack(realTrack, data)
			end
		end
	end
	loadFolder(folder)
	loadFolder(sharedFolder)

	data.Connection = model.Destroying:Connect(function()
		AnimationService.Clear(model)
	end)

	Cache[model] = data

	return data.Tracks
end

function AnimationService.Play(model: Model, name: string, level: number?, fadeTime: number?): AnimationTrack?
	local data = Cache[model]
	if not data then
		return nil
	end

	local track = getTrack(data.Tracks, name, level)
	if not track then
		warn(`Animation 없음: {name}`)
		return nil
	end

	track:Play(fadeTime or 0)
	return track
end

function AnimationService.GetTrack(model: Model, name: string, level: number?): AnimationTrack?
	local data = Cache[model]
	if not data then
		return nil
	end

	return getTrack(data.Tracks, name, level)
end

function AnimationService.GetExactTrack(model: Model, name: string, level: number?): AnimationTrack?
	local data = Cache[model]
	if not data then
		return nil
	end

	return getExactTrack(data.Tracks, name, level)
end

function AnimationService.PlayOnce(model: Model, name: string, options)
	options = options or {}

	local data = Cache[model]
	if not data then
		return nil
	end

	local level = options.Level
	local fadeTime = options.FadeTime or 0
	local resumeName = options.Resume or "Idle"

	local track = getTrack(data.Tracks, name, level)
	if not track then
		warn(`Animation 없음: {name}`)
		return nil
	end

	local playOnceId = (data.CurrentPlayOnceId or 0) + 1
	data.CurrentPlayOnceId = playOnceId

	for _, activeTrack in pairs(data.Tracks) do
		if activeTrack ~= track and activeTrack.IsPlaying then
			activeTrack:Stop(fadeTime)
		end
	end

	track:Play(fadeTime)

	track.Stopped:Once(function()
		if not Cache[model] or data.CurrentPlayOnceId ~= playOnceId then
			return
		end

		AnimationService.Play(model, resumeName, level, fadeTime)
	end)

	return track
end

function AnimationService.Stop(model: Model, name: string?, fadeTime: number?)
	local data = Cache[model]
	if not data then
		return
	end

	if not name then
		data.CurrentPlayOnceId = (data.CurrentPlayOnceId or 0) + 1
	end

	for trackName, track in pairs(data.Tracks) do
		if not name or trackName == name or trackName:match(`^{name}_%d+$`) then
			track:Stop(fadeTime or 0)
		end
	end
end

function AnimationService.Clear(model: Model)
	local data = Cache[model]
	if not data then
		return
	end

	if data.Connection then
		data.Connection:Disconnect()
	end

	for _, track in pairs(data.Tracks) do
		track:Stop(0)
		track:Destroy()
	end

	Cache[model] = nil
end

function AnimationService.ClearAll()
	for model in pairs(Cache) do
		AnimationService.Clear(model)
	end
end

function AnimationService.Init(services) end

function AnimationService.Start()
	if RunService:IsClient() then
		local StarterPlayer = game:GetService("StarterPlayer")
		local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)

		ClientSignals.GameSpeedChanged:Connect(function(newSpeed)
			currentSpeedMultiplier = newSpeed
			for _, data in pairs(Cache) do
				for _, track in pairs(data.Tracks) do
					if track.IsPlaying then
						local targetSpeed = data.TrackSpeeds[track] or 1
						track._realTrack:AdjustSpeed(targetSpeed * currentSpeedMultiplier)
					end
				end
			end
		end)
	end
end

return AnimationService
