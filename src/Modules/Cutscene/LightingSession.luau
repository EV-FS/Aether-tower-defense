local Lighting = game:GetService("Lighting")
local Cleanup = require(script.Parent.Cleanup)

local LightingSession = {}
LightingSession.__index = LightingSession
local activeSession = nil

local LIGHTING_PROPERTIES = {
	Ambient = "Color3",
	Brightness = "number",
	ClockTime = "number",
	ColorShift_Bottom = "Color3",
	ColorShift_Top = "Color3",
	EnvironmentDiffuseScale = "number",
	EnvironmentSpecularScale = "number",
	ExposureCompensation = "number",
	FogColor = "Color3",
	FogEnd = "number",
	FogStart = "number",
	GeographicLatitude = "number",
	GlobalShadows = "boolean",
	OutdoorAmbient = "Color3",
	ShadowSoftness = "number",
}

local CHILD_PROPERTIES = {
	BlurEffect = { Enabled = "boolean", Size = "number" },
	BloomEffect = { Enabled = "boolean", Intensity = "number", Size = "number", Threshold = "number" },
	Sky = {
		CelestialBodiesShown = "boolean", MoonAngularSize = "number", MoonTextureId = "string",
		SkyboxBk = "string", SkyboxDn = "string", SkyboxFt = "string",
		SkyboxLf = "string", SkyboxRt = "string", SkyboxUp = "string",
		SkyboxOrientation = "Vector3", StarCount = "number",
		SunAngularSize = "number", SunTextureId = "string",
	},
	Atmosphere = {
		Color = "Color3", Decay = "Color3", Density = "number",
		Glare = "number", Haze = "number", Offset = "number",
	},
	ColorCorrectionEffect = {
		Brightness = "number", Contrast = "number", Enabled = "boolean",
		Saturation = "number", TintColor = "Color3",
	},
	DepthOfFieldEffect = {
		Enabled = "boolean", FarIntensity = "number", FocusDistance = "number",
		InFocusRadius = "number", NearIntensity = "number",
	},
}

local function validateProperties(properties, allowed, label)
	assert(type(properties) == "table", `{label}.Properties must be a table`)
	for name, value in properties do
		local expected = allowed[name]
		assert(expected, `{label}.{name} cannot be set by a cutscene lighting profile`)
		assert(typeof(value) == expected, `{label}.{name} must be {expected}`)
		if expected == "number" then
			assert(value == value and math.abs(value) < math.huge, `{label}.{name} must be finite`)
		end
	end
end

function LightingSession.Validate(profile)
	assert(type(profile) == "table", "Cutscene Lighting must be a table")
	validateProperties(profile.Properties, LIGHTING_PROPERTIES, "Lighting")
	assert(type(profile.Children) == "table", "Lighting.Children must be an array")
	for index, child in profile.Children do
		assert(type(child) == "table", `Lighting.Children[{index}] must be a table`)
		assert(type(child.ClassName) == "string" and CHILD_PROPERTIES[child.ClassName],
			`Unsupported cutscene lighting child at index {index}`)
		assert(type(child.Name) == "string" and child.Name ~= "", `Lighting.Children[{index}] needs a name`)
		validateProperties(child.Properties, CHILD_PROPERTIES[child.ClassName], child.Name)
	end
	return true
end

local function isVisualChild(instance: Instance): boolean
	return instance:IsA("Sky") or instance:IsA("Atmosphere") or instance:IsA("PostEffect")
end

function LightingSession.new(profile)
	LightingSession.Validate(profile)
	-- Only one cutscene can own the client's rendered Lighting at a time.
	-- Retire the previous owner before taking a new baseline snapshot.
	if activeSession then
		activeSession:Destroy()
	end
	local self = setmetatable({
		SavedProperties = {},
		Owned = {},
		Connections = {},
		Parked = Instance.new("Folder"),
		Destroyed = false,
	}, LightingSession)
	self.Parked.Name = "SuspendedCutsceneLighting"
	local ok, err = xpcall(function()
		for name in profile.Properties do
			self.SavedProperties[name] = Lighting[name]
		end
		for _, child in Lighting:GetChildren() do
			if isVisualChild(child) then
				child.Parent = self.Parked
			end
		end
		for name, value in profile.Properties do
			Lighting[name] = value
		end
		for _, definition in profile.Children do
			local child = Instance.new(definition.ClassName)
			table.insert(self.Owned, child)
			child.Name = definition.Name
			for name, value in definition.Properties do
				child[name] = value
			end
			child.Parent = Lighting
		end
		-- A day/night tween or a settings update can otherwise overwrite the shot.
		for name, value in profile.Properties do
			table.insert(self.Connections, Lighting:GetPropertyChangedSignal(name):Connect(function()
				if not self.Destroyed and Lighting[name] ~= value then
					Lighting[name] = value
				end
			end))
		end
	end, debug.traceback)
	if not ok then
		self:Destroy()
		error(err, 0)
	end
	activeSession = self
	return self
end

function LightingSession:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if activeSession == self then
		activeSession = nil
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	for _, child in self.Owned do
		Cleanup.Try("Cutscene lighting child", function() child:Destroy() end)
	end
	for name, value in self.SavedProperties do
		Cleanup.Try("Lighting." .. name, function() Lighting[name] = value end)
	end
	for _, child in self.Parked:GetChildren() do
		Cleanup.Try("Restore Lighting child " .. child.Name, function() child.Parent = Lighting end)
	end
	self.Parked:Destroy()
end

return LightingSession
