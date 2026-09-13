-- Tree operations only: never clone nodes separately (would break cross-node references).
local InstanceBatch = {}

function InstanceBatch.Visit(roots, callback, step)
	local stack = table.clone(roots)
	local seen = {}
	while #stack > 0 do
		local instance = table.remove(stack)
		if seen[instance] then continue end
		seen[instance] = true
		for _, child in instance:GetChildren() do table.insert(stack, child) end
		callback(instance)
		step()
	end
end

function InstanceBatch.Plan(root, isAtomic, step)
	local entries = {}
	for _, child in root:GetChildren() do
		table.insert(entries, { Instance = child, Parent = root })
	end
	local index = 1
	while index <= #entries do
		local entry = entries[index]
		local instance = entry.Instance
		if instance:IsA("Model") then
			entry.IsModel = true
			entry.PrimaryPart = instance.PrimaryPart
			entry.WorldPivot = instance.WorldPivot
		end
		if not isAtomic(instance) then
			for _, child in instance:GetChildren() do
				table.insert(entries, { Instance = child, Parent = instance })
			end
		end
		index += 1
		step()
	end
	return entries
end

function InstanceBatch.Mount(root, destination, entries, step, prepareStep)
	prepareStep = prepareStep or step
	-- Off-world child-first detach, then parent-first mount in small batches.
	-- Each entry is the SAME clone, so ObjectValues/joints retain their references.
	for index = #entries, 1, -1 do
		entries[index].Instance.Parent = nil
		prepareStep()
	end
	for _, entry in entries do
		entry.Instance.Parent = if entry.Parent == root then destination else entry.Parent
		step()
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
	for _, root in roots do table.insert(stack, { Instance = root }) end
	while #stack > 0 do
		local entry = table.remove(stack)
		local instance = entry.Instance
		if entry.Expanded then
			instance:Destroy()
			step()
		elseif not seen[instance] then
			seen[instance] = true
			table.insert(stack, { Instance = instance, Expanded = true })
			for _, child in instance:GetChildren() do table.insert(stack, { Instance = child }) end
			scanStep()
		end
	end
end

return InstanceBatch
