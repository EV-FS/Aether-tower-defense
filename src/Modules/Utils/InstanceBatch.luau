-- Tree operations only: never clone nodes separately (would break cross-node references).
local InstanceBatch = {}

function InstanceBatch.Visit(roots, callback, step)
	local stack = table.clone(roots)
	local seen = {}
	while #stack > 0 do
		local instance = table.remove(stack)
		if seen[instance] then continue end
		seen[instance] = true
		for _, child in instance:GetChildren() do
			table.insert(stack, child)
			step()
		end
		callback(instance)
		step()
	end
end

function InstanceBatch.Plan(root, isAtomic, step)
	local entries = {}
	for _, child in root:GetChildren() do
		table.insert(entries, { Instance = child, Parent = root })
		step()
	end
	local index = 1
	while index <= #entries do
		local entry = entries[index]
		local instance = entry.Instance
		local atomic = isAtomic(instance)
		if not atomic and instance:IsA("Model") then
			entry.IsModel = true
			entry.PrimaryPart = instance.PrimaryPart
			entry.WorldPivot = instance.WorldPivot
		end
		if not atomic then
			for _, child in instance:GetChildren() do
				table.insert(entries, { Instance = child, Parent = instance })
				step()
			end
		end
		index += 1
		step()
	end
	return entries
end

-- Count ALL descendants, including trees parented beneath Parts/Attachments.
-- Build once in breadth-first order, then sum bottom-up in O(n). Never call
-- GetDescendants for every model (quadratic on deeply nested imported maps).
function InstanceBatch.PlanBounded(root, maxNodes, step, visit)
	assert(maxNodes >= 1, "Chunk size must be positive")
	local nodes = { { Instance = root, Count = 1 } }
	local index = 1
	while index <= #nodes do
		local node = nodes[index]
		if index > 1 and visit then visit(node.Instance) end
		for _, child in node.Instance:GetChildren() do
			table.insert(nodes, { Instance = child, ParentIndex = index, Count = 1 })
			step()
		end
		index += 1
		step()
	end
	for i = #nodes, 2, -1 do
		local node = nodes[i]
		nodes[node.ParentIndex].Count += node.Count
		step()
	end
	local entries = {}
	nodes[1].Split = true
	for i = 2, #nodes do
		local node = nodes[i]
		local parent = nodes[node.ParentIndex]
		if parent.Split then
			node.Split = node.Count > maxNodes
			local entry = {
				Instance = node.Instance,
				Parent = parent.Instance,
				-- Split containers are empty when mounted; intact subtrees cost
				-- their entire node count, not just one Parent assignment.
				Cost = if node.Split then 1 else node.Count,
			}
			if node.Split and node.Instance:IsA("Model") then
				entry.IsModel = true
				entry.PrimaryPart = node.Instance.PrimaryPart
				entry.WorldPivot = node.Instance.WorldPivot
			end
			table.insert(entries, entry)
		end
		step()
	end
	return entries, nodes[1].Count - 1
end

function InstanceBatch.Detach(entries, step)
	for index = #entries, 1, -1 do
		entries[index].Instance.Parent = nil
		step(entries[index].Cost or 1)
	end
end

function InstanceBatch.Mount(root, destination, entries, step, prepareStep, detached)
	prepareStep = prepareStep or step
	-- Off-world child-first detach, then parent-first mount in small batches.
	-- Each entry is the SAME clone, so ObjectValues/joints retain their references.
	if not detached then InstanceBatch.Detach(entries, prepareStep) end
	for _, entry in entries do
		entry.Instance.Parent = if entry.Parent == root then destination else entry.Parent
		step(entry.Cost or 1)
	end
	-- Roblox can clear PrimaryPart when it is detached across simulation steps.
	-- Restore model metadata after descendants exist; do NOT PivotTo/move geometry.
	for _, entry in entries do
		if entry.IsModel then
			entry.Instance.PrimaryPart = entry.PrimaryPart
			entry.Instance.WorldPivot = entry.WorldPivot
			step()
		end
	end
end

function InstanceBatch.Destroy(roots, step, scanStep)
	scanStep = scanStep or step
	local stack, seen = {}, {}
	for _, root in roots do
		table.insert(stack, { Instance = root })
		scanStep()
	end
	while #stack > 0 do
		local entry = table.remove(stack)
		local instance = entry.Instance
		if entry.Expanded then
			instance:Destroy()
			step()
		elseif not seen[instance] then
			seen[instance] = true
			table.insert(stack, { Instance = instance, Expanded = true })
			for _, child in instance:GetChildren() do
				table.insert(stack, { Instance = child })
				scanStep()
			end
			scanStep()
		end
	end
end

return InstanceBatch
