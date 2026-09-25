-- Run in Studio with ReplicatedStorage.Shared.Modules.Cutscene.ScenePaths.
return function(ScenePaths)
	local scene = Instance.new("Folder")
	scene.Name = "DragonSlayer_Cutscenes"
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = scene
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = scene
	local mapFx = Instance.new("Folder")
	mapFx.Name = "FX"
	mapFx.Parent = map
	local numbered = Instance.new("Folder")
	numbered.Name = "1"
	numbered.Parent = scene
	local nestedNumbered = Instance.new("Folder")
	nestedNumbered.Name = "1"
	nestedNumbered.Parent = mapFx
	local orb = Instance.new("Model")
	orb.Name = "OrbFracture"
	orb.Parent = scene
	local bowlight = Instance.new("Folder")
	bowlight.Name = "bowlight2"
	bowlight.Parent = orb

	local ok, err = xpcall(function()
		assert(ScenePaths.ResolveTopLevel({ scene }, { "FX" }) == fx,
			"A nested FX must not shadow the top-level FX")
		assert(ScenePaths.ResolveTopLevel({ scene }, { "1" }) == numbered,
			"Numeric names must resolve at the top level")
		assert(ScenePaths.ResolveTopLevel({ scene }, { "Map", "FX", "1" }) == nestedNumbered,
			"Explicit paths must follow direct children")
		assert(ScenePaths.ResolveTopLevel({ scene }, { "OrbFracture", "bowlight2" }) == bowlight,
			"A named rig child must resolve")
		local missing, reason = ScenePaths.ResolveTopLevel({ scene }, { "bowlight2" })
		assert(missing == nil and string.find(reason, "Missing scene path", 1, true),
			"A descendant-only shorthand must fail")

		local otherFx = Instance.new("Folder")
		otherFx.Name = "FX"
		otherFx.Parent = scene
		local duplicate, duplicateReason = ScenePaths.ResolveTopLevel({ scene }, { "FX" })
		assert(duplicate == nil and string.find(duplicateReason, "Ambiguous scene path", 1, true),
			"Duplicate top-level names must not be chosen arbitrarily")
	end, debug.traceback)
	scene:Destroy()
	if not ok then error(err, 0) end
	print("PASS: local VFX paths only follow explicit scene levels")
end
