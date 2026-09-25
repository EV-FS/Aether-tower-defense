local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local PropertyTrack = require(script.Parent.ECS.PropertyTrack)
local CubicBezier = require(script.Parent.ECS.CubicBezier)

local ScreenEffects = {}
ScreenEffects.__index = ScreenEffects
local PROPERTY_TYPES = {
	Enabled = "boolean", Saturation = "number", Contrast = "number",
	Brightness = "number", TintColor = "Color3",
}

local function enumValue(enumType, value, fallback)
	if typeof(value) == "EnumItem" then
		return if value.EnumType == enumType then value else fallback
	end
	if type(value) == "string" then
		return enumType[value]
	end
	return fallback
end

local function resolveEase(info)
	if type(info) == "string" or typeof(info) == "EnumItem" then
		info = { Type = info }
	end
	assert(type(info) == "table", "Ease must be a table, string, or EnumItem")

	local rawType = info.Type or info.Style or info.EasingStyle or "Linear"
	local typeName = if typeof(rawType) == "EnumItem" then rawType.Name else rawType
	-- Moon's None/Constant segments hold until the next authored key.
	if typeName == "None" or typeName == "Constant" then
		return function() return 0 end
	end
	if typeName == "Bezier" or typeName == "CubicBezier" then
		local ok, curve = pcall(CubicBezier.Create, info.Params)
		if ok then return curve end
		warn("[CutsceneScreen] Invalid Bezier; using Linear: " .. tostring(curve))
		return nil
	end
	local params = info.Params or {}
	local style = enumValue(Enum.EasingStyle, rawType, nil)
	local rawDirection = info.Direction or info.EasingDirection or params.Direction or params.Dir or "In"
	local direction = enumValue(Enum.EasingDirection, rawDirection, nil)
	if not style or not direction then
		warn("[CutsceneScreen] Invalid easing; using Linear")
		return nil
	end
	if style == Enum.EasingStyle.Linear then return nil end
	return function(alpha) return TweenService:GetValue(alpha, style, direction) end
end

local function prepareConfig(config)
	assert(type(config) == "table", "ScreenEffects config must be a table")
	assert(config.Name == nil or (type(config.Name) == "string" and config.Name ~= ""),
		"ScreenEffects.Name must be a nonempty string")
	assert(config.EndFrame > 0 and config.EndFrame < math.huge, "ScreenEffects.EndFrame must be positive and finite")
	assert(not config.FPS or (config.FPS > 0 and config.FPS < math.huge), "ScreenEffects.FPS must be positive and finite")
	local tracks = {}
	-- Validate/copy before creating any instance; exported frozen data stays untouched.
	assert(type(config.Tracks) == "table", "ScreenEffects.Tracks must be a property-track table")
	for property, keys in config.Tracks do
		local expectedType = assert(PROPERTY_TYPES[property], "Unsupported screen property: " .. property)
		tracks[property] = PropertyTrack.Prepare(keys, expectedType, resolveEase)
		local lastKey = tracks[property][#tracks[property]]
		assert(not lastKey or lastKey.Frame <= config.EndFrame,
			`ScreenEffects.{property} has a key after EndFrame ({config.EndFrame})`)
	end
	return tracks
end

function ScreenEffects.Validate(config): boolean
	prepareConfig(config)
	return true
end

function ScreenEffects.new(config)
	local tracks = prepareConfig(config)
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = config.Name or "CutsceneColorCorrection"
	effect.Enabled = false
	effect.Saturation = 0
	effect.Contrast = 0
	effect.Brightness = 0
	effect.TintColor = Color3.new(1, 1, 1)
	-- Local, session-owned instance: never overwrite the map's existing effects.
	effect.Parent = Lighting
	return setmetatable({ Effect = effect, Tracks = tracks, EndFrame = config.EndFrame }, ScreenEffects)
end

function ScreenEffects:ApplyFrame(frame, playing)
	if self.Destroyed then return end
	if not playing then
		self.Effect.Enabled = false
		return
	end
	frame = math.clamp(frame, 0, self.EndFrame)
	local enabled = true
	for property, track in self.Tracks do
		-- Preserve authored values: Saturation > 1 and high Contrast are valid.
		local value = PropertyTrack.Read(track, frame)
		if value ~= nil then
			if property == "Enabled" then enabled = value else self.Effect[property] = value end
		end
	end
	self.Effect.Enabled = enabled
end

function ScreenEffects:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	-- Neutralize before removal so a delayed render cannot show the last dark key.
	self.Effect.Enabled = false
	self.Effect.Brightness = 0
	self.Effect.Contrast = 0
	self.Effect.Saturation = 0
	self.Effect.TintColor = Color3.new(1, 1, 1)
	self.Effect:Destroy()
end

return ScreenEffects
