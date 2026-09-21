local CutsceneValidator = {}
local ScreenEffects = require(script.Parent.ScreenEffects)

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
	if fovEndFrame and trackEndFrame and fovEndFrame ~= trackEndFrame then
		warn(`[CutsceneValidator] {name}: FOV ends at frame {fovEndFrame}, other tracks end at frame {trackEndFrame}`)
	end
	return true
end

return CutsceneValidator
