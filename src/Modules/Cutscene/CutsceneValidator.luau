local CutsceneValidator = {}
local ScreenEffects = require(script.Parent.ScreenEffects)
local LightingSession = require(script.Parent.LightingSession)
local ScenePaths = require(script.Parent.ScenePaths)

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function validatePositive(value: any, label: string)
	assert(isFinite(value) and value > 0, `{label} must be a positive finite number`)
end

local function validateFrame(value: any, label: string)
	assert(isFinite(value) and value >= 0 and value % 1 == 0, `{label} must be a nonnegative integer`)
end

local function getLastSampleFrame(samples): number
	local lastFrame = nil
	for frame, value in samples do
		validateFrame(frame, "FOV sample frame")
		assert(isFinite(value) and value > 0, `FOV sample at frame {frame} must be positive and finite`)
		if not lastFrame or frame > lastFrame then
			lastFrame = frame
		end
	end
	assert(lastFrame ~= nil, "FOV samples cannot be empty")
	return lastFrame
end

local function validateTrackEndFrames(config)
	local endFrame = nil
	local function add(label: string, value: any)
		validatePositive(value, `{label}.EndFrame`)
		assert(value % 1 == 0, `{label}.EndFrame must be an integer`)
		if endFrame and endFrame ~= value then
			warn(`[CutsceneValidator] {label}.EndFrame ({value}) differs from another track EndFrame ({endFrame})`)
		else
			endFrame = value
		end
	end

	for label, track in {
		ScreenEffects = config.ScreenEffects,
		ImpactFrames = config.ImpactFrames,
		VFX = config.VFX,
	} do
		if track then
			add(label, track.EndFrame)
			if track.FPS ~= nil then validatePositive(track.FPS, `{label}.FPS`) end
		end
	end

	if config.FPS ~= nil then validatePositive(config.FPS, "Cutscene.FPS") end
	return endFrame
end

function CutsceneValidator.Validate(name: string, config)
	assert(type(config) == "table", `Missing cutscene config: {name}`)
	assert(type(config.Camera) == "table", `Cutscene "{name}" is missing Camera config`)
	assert(type(config.Camera.Model) == "string" and config.Camera.Model ~= "", `Cutscene "{name}" has an invalid camera model`)
	assert(type(config.Camera.Part) == "string" and config.Camera.Part ~= "", `Cutscene "{name}" has an invalid camera part`)
	assert(type(config.Animations) == "table", `Cutscene "{name}" is missing Animations`)
	assert(config.Animations[config.Camera.Model] ~= nil, `Cutscene "{name}" is missing the camera animation "{config.Camera.Model}"`)
	if config.Actors then
		assert(type(config.Actors) == "table", `Cutscene "{name}" Actors must be a table`)
		for actorName, role in config.Actors do
			assert(type(actorName) == "string" and config.Animations[actorName] ~= nil,
				`Cutscene "{name}" actor {tostring(actorName)} has no animation`)
			assert(role == "Self" or role == "Friend", `Cutscene "{name}" actor {actorName} has invalid role`)
		end
	end
	if config.SceneTransform ~= nil then
		assert(typeof(config.SceneTransform) == "CFrame", `Cutscene "{name}" has an invalid SceneTransform`)
		assert(not config.UseWorkspaceScene, `Cutscene "{name}" cannot transform a live Workspace scene`)
	end

	local fov = config.Camera.FOV
	local fovEndFrame = nil
	if fov then
		assert(type(fov.Samples) == "table", `Cutscene "{name}" has invalid FOV samples`)
		fovEndFrame = getLastSampleFrame(fov.Samples)
		if fov.FPS ~= nil then validatePositive(fov.FPS, "Camera.FOV.FPS") end
	end

	local trackEndFrame = validateTrackEndFrames(config)
	if config.ScreenEffects then
		ScreenEffects.Validate(config.ScreenEffects)
	end
	if config.VFX then
		local vfx = config.VFX
		assert(type(vfx.Events) == "table", `Cutscene "{name}" VFX.Events must be a table`)
		for frame, event in vfx.Events do
			validateFrame(frame, "VFX event frame")
			assert(frame <= vfx.EndFrame, `Cutscene "{name}" VFX event exceeds EndFrame`)
			assert(type(event) == "table", `Cutscene "{name}" VFX event at {frame} must be a table`)
			local count = 0
			for _, kind in { "Emit", "AbsoluteEmit" } do
				local paths = event[kind]
				if paths then
					assert(type(paths) == "table", `Cutscene "{name}" VFX {kind} at {frame} must be a table`)
					for _, path in paths do
						assert(type(path) == "table", `Cutscene "{name}" VFX path at {frame} must be a table`)
						ScenePaths.Key(path)
						count += 1
					end
				end
			end
			assert(count > 0, `Cutscene "{name}" VFX event at {frame} has no targets`)
		end
	end
	if config.Audio then
		assert(type(config.Audio) == "table", `Cutscene "{name}" Audio must be a table`)
		assert(isFinite(config.Audio.SoundId) and config.Audio.SoundId > 0
			and config.Audio.SoundId % 1 == 0, `Cutscene "{name}" has an invalid audio asset ID`)
		if config.Audio.Volume ~= nil then
			assert(isFinite(config.Audio.Volume) and config.Audio.Volume >= 0,
				`Cutscene "{name}" has an invalid audio volume`)
		end
	end
	if config.Presentation then
		assert(type(config.Presentation) == "table", `Cutscene "{name}" Presentation must be a table`)
		for _, field in { "ReadyHold", "BlackHold", "ReturnHold", "FadeIn", "FadeOut" } do
			local value = config.Presentation[field]
			assert(isFinite(value) and value >= 0, `Cutscene "{name}" Presentation.{field} must be nonnegative`)
		end
		validatePositive(config.Presentation.PreloadTimeout, `Cutscene "{name}" Presentation.PreloadTimeout`)
		if config.Presentation.ExitFOVScale ~= nil then
			local exitFOVScale = config.Presentation.ExitFOVScale
			assert(isFinite(exitFOVScale) and exitFOVScale > 0 and exitFOVScale <= 1,
				`Cutscene "{name}" Presentation.ExitFOVScale must be in (0, 1]`)
		end
	end
	if config.Lighting then
		LightingSession.Validate(config.Lighting)
	end
	if fovEndFrame and trackEndFrame and fovEndFrame ~= trackEndFrame then
		warn(`[CutsceneValidator] {name}: FOV ends at frame {fovEndFrame}, other tracks end at frame {trackEndFrame}`)
	end
	return true
end

return CutsceneValidator
