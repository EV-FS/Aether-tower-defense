-- Converts Moon Animator 2 Lighting Exporter v1.0.0 data to the cutscene's
-- clock-driven screen effect format. The export stays immutable and data-only.
local MoonLightingTracks = {}

local PROPERTY_TYPES = {
	Brightness = "number",
	Contrast = "number",
	Enabled = "boolean",
	Saturation = "number",
	TintColor = "Color3",
}

local function finiteNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function MoonLightingTracks.ColorCorrection(export, itemId)
	assert(type(export) == "table" and type(export.Meta) == "table", "Moon lighting export needs Meta")
	local meta = export.Meta
	assert(meta.Format == "MoonAnimator2LightingTracks", "Unsupported Moon lighting export format")
	assert(meta.ExporterVersion == "1.0.0", "Unsupported Moon lighting exporter version")
	assert(finiteNumber(meta.FPS) and meta.FPS > 0, "Moon lighting FPS must be positive")
	assert(finiteNumber(meta.LengthFrames) and meta.LengthFrames > 0
		and meta.LengthFrames % 1 == 0, "Moon lighting LengthFrames must be a positive integer")
	assert(type(export.Items) == "table" and type(export.ItemOrder) == "table", "Moon lighting export needs Items and ItemOrder")
	assert(meta.ItemCount == #export.ItemOrder, "Moon lighting ItemCount does not match ItemOrder")
	assert(finiteNumber(meta.LengthSeconds)
		and math.abs(meta.LengthSeconds - meta.LengthFrames / meta.FPS) < 1e-4,
		"Moon lighting length does not match FPS")
	if itemId == nil then
		assert(#export.ItemOrder == 1, "Select an ItemId when the Moon lighting export contains multiple items")
		itemId = export.ItemOrder[1]
	end
	local found = false
	for _, orderedId in export.ItemOrder do
		if orderedId == itemId then found = true; break end
	end
	assert(found, `Moon lighting ItemId {itemId} is not in ItemOrder`)
	local item = assert(export.Items[itemId], `Moon lighting ItemId {itemId} is missing`)
	assert(item.ItemId == itemId and type(item.Target) == "table", "Moon lighting item identity is invalid")
	local target = item.Target
	assert(target.ClassName == "ColorCorrectionEffect"
		and target.ItemType == "ColorCorrectionEffect"
		and target.ItemId == itemId, "Moon lighting item must target a ColorCorrectionEffect")
	assert(type(target.InstanceNames) == "table" and target.InstanceNames[1] == "game"
		and target.InstanceNames[2] == "Lighting" and target.InstanceNames[3] == target.Name
		and type(target.Name) == "string" and target.Name ~= "", "Moon lighting target must be under game.Lighting")
	assert(target.Path == `game.Lighting.{target.Name}`,
		"Moon lighting target path does not match game.Lighting")
	assert(type(item.Properties) == "table", "Moon lighting item needs Properties")

	local tracks = {}
	local propertyCount = 0
	local keyframeCount = 0
	for name, property in item.Properties do
		local expected = assert(PROPERTY_TYPES[name], `Unsupported Moon ColorCorrectionEffect property: {name}`)
		assert(type(property) == "table" and property.Name == name,
			`Moon lighting property {name} has an invalid name`)
		assert(property.DefaultType == expected and property.HasDefault == true
			and typeof(property.Default) == expected, `Moon lighting {name} has an invalid default`)
		assert(type(property.Keyframes) == "table", `Moon lighting {name} needs Keyframes`)
		assert(property.KeyframeCount == #property.Keyframes,
			`Moon lighting {name} KeyframeCount does not match the export`)
		local lastFrame = -1
		for _, key in property.Keyframes do
			assert(finiteNumber(key.Frame) and key.Frame % 1 == 0
				and key.Frame > lastFrame and key.Frame <= meta.LengthFrames,
				`Moon lighting {name} has an invalid key frame`)
			assert(key.ValueType == expected and typeof(key.Value) == expected,
				`Moon lighting {name} has an invalid key value`)
			assert(finiteNumber(key.Time) and math.abs(key.Time - key.Frame / meta.FPS) < 1e-4,
				`Moon lighting {name} key time does not match FPS`)
			if expected == "number" then
				assert(finiteNumber(key.Value), `Moon lighting {name} has a nonfinite value`)
			end
			lastFrame = key.Frame
		end
		if expected == "number" then
			assert(finiteNumber(property.Default), `Moon lighting {name} has a nonfinite default`)
		end
		-- Sequence keeps each original key's outgoing Ease for PropertyTrack.
		tracks[name] = { Default = property.Default, Sequence = property.Keyframes }
		propertyCount += 1
		keyframeCount += #property.Keyframes
	end
	assert(propertyCount == item.PropertyCount and keyframeCount == item.KeyframeCount,
		"Moon lighting item counts do not match the export")
	if meta.ItemCount == 1 then
		assert(propertyCount == meta.PropertyCount and keyframeCount == meta.KeyframeCount,
			"Moon lighting total counts do not match the export")
	end
	return {
		Name = target.Name,
		Tracks = tracks,
		EndFrame = meta.LengthFrames,
		-- The export's Time fields are Frame / FPS. Preserve that clock rather
		-- than stretching flashes to an animation asset's reported length.
		FPS = meta.FPS,
	}
end

return MoonLightingTracks
