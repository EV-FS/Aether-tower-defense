local ScenePaths = {}

function ScenePaths.Key(path)
	assert(#path > 0, "Empty VFX path")
	local segments = {}
	for _, name in path do
		assert(type(name) == "string" and name ~= "", "Invalid VFX path segment")
		table.insert(segments, #name .. ":" .. name)
	end
	return table.concat(segments)
end

function ScenePaths.Collect(events)
	local paths = {}
	for _, event in events or {} do
		for _, kind in { "Emit", "AbsoluteEmit" } do
			for _, path in event[kind] or {} do paths[ScenePaths.Key(path)] = path end
		end
	end
	return paths
end

local function finishResolve(candidates, path)
	for index = 2, #path do
		local nextCandidates = {}
		for _, current in candidates do
			for _, child in current:GetChildren() do
				if child.Name == path[index] then table.insert(nextCandidates, child) end
			end
		end
		candidates = nextCandidates
	end
	if #candidates == 1 then return candidates[1] end
	if #candidates == 0 then return nil, "Missing scene path: " .. table.concat(path, ".") end
	local names = {}
	for _, candidate in candidates do table.insert(names, candidate:GetFullName()) end
	return nil, "Ambiguous scene path: " .. table.concat(path, ".") .. " -> " .. table.concat(names, ", ")
end

-- Local scenes retain a single cloned container. The first segment names one
-- of its direct children; every later segment names a direct child of the
-- previous segment. Descendants with the same name cannot shadow that path.
function ScenePaths.ResolveTopLevel(containers, path)
	local candidates = {}
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child.Name == path[1] then table.insert(candidates, child) end
		end
	end
	return finishResolve(candidates, path)
end

-- Server cutscenes mount each top-level scene object separately. Preserve
-- their existing unique-descendant shorthand until those assets are migrated.
function ScenePaths.Resolve(roots, path)
	local candidates = {}
	for _, root in roots do
		if root.Name == path[1] then table.insert(candidates, root) end
	end
	if #candidates == 0 then
		for _, root in roots do
			for _, child in root:GetDescendants() do
				if child.Name == path[1] then table.insert(candidates, child) end
			end
		end
	end
	return finishResolve(candidates, path)
end

return ScenePaths
