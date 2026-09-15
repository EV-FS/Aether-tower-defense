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

local function resolveEase(info)
	if type(info) == "table" and (info.Type == "Bezier" or info.Type == "CubicBezier") then
		local ok, curve = pcall(CubicBezier.Create, info.Params)
		if ok then return curve end
		warn("[CutsceneScreen] Invalid Bezier; using Linear: " .. tostring(curve))
		return nil
	end
	local ok, style, direction = pcall(function()
		local params = info.Params or {}
		return Enum.EasingStyle[info.Type or "Linear"],
			Enum.EasingDirection[params.Direction or params.Dir or "In"]
	end)
	if not ok or not style or not direction then
		warn("[CutsceneScreen] Invalid easing; using Linear")
		return nil
	end
	if style == Enum.EasingStyle.Linear then return nil end
	return function(alpha) return TweenService:GetValue(alpha, style, direction) end
end

function ScreenEffects.new(config)
	assert(config.EndFrame > 0 and config.EndFrame < math.huge, "ScreenEffects.EndFrame must be positive and finite")
	assert(not config.FPS or (config.FPS > 0 and config.FPS < math.huge), "ScreenEffects.FPS must be positive and finite")
	local tracks = {}
	-- Validate/copy before creating any instance; exported frozen data stays untouched.
	for property, keys in config.Tracks do
		local expectedType = assert(PROPERTY_TYPES[property], "Unsupported screen property: " .. property)
		tracks[property] = PropertyTrack.Prepare(keys, expectedType, resolveEase)
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "CutsceneColorCorrection"
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
	if not playing then
		self.Effect.Enabled = false
		return
	end
	frame = math.clamp(frame, 0, self.EndFrame)
	local enabled = true
	for property, track in self.Tracks do
		local value = PropertyTrack.Read(track, frame)
		if value ~= nil then
			if property == "Enabled" then enabled = value else self.Effect[property] = value end
		end
	end
	self.Effect.Enabled = enabled
end

function ScreenEffects:Destroy()
	-- Neutralize before removal so a delayed render cannot show the last dark key.
	self.Effect.Enabled = false
	self.Effect.Brightness = 0
	self.Effect.Contrast = 0
	self.Effect.Saturation = 0
	self.Effect.TintColor = Color3.new(1, 1, 1)
	self.Effect:Destroy()
end

return ScreenEffects
