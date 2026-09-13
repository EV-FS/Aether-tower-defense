-- Stateless sampling: no private clock, connections, Tween instances or accumulated dt.
local PropertyTrack = {}

function PropertyTrack.Prepare(keys, expectedType, resolveEase)
	local prepared = {}
	local sequence = keys.Sequence or keys -- support old arrays and new Moon exports
	if keys.Default ~= nil then
		assert(typeof(keys.Default) == expectedType, "Property Default must be " .. expectedType)
		if expectedType == "number" then
			assert(keys.Default == keys.Default and math.abs(keys.Default) < math.huge, "Property Default must be finite")
		end
		prepared.Default = keys.Default
	end
	for _, key in ipairs(sequence) do
		assert(type(key.Frame) == "number" and key.Frame >= 0 and key.Frame < math.huge
			and key.Frame % 1 == 0, "Property key Frame must be a nonnegative integer")
		assert(typeof(key.Value) == expectedType, "Property key Value must be " .. expectedType)
		if expectedType == "number" then
			assert(key.Value == key.Value and math.abs(key.Value) < math.huge, "Property value must be finite")
		end
		table.insert(prepared, {
			Frame = key.Frame, Value = key.Value,
			Ease = if key.Ease and resolveEase then resolveEase(key.Ease) else nil,
		})
	end
	table.sort(prepared, function(a, b) return a.Frame < b.Frame end)
	for index = 2, #prepared do
		assert(prepared[index - 1].Frame ~= prepared[index].Frame, "Duplicate property key frame")
	end
	return prepared
end

function PropertyTrack.Read(track, frame)
	if #track == 0 then return track.Default end
	if frame <= track[1].Frame then return track[1].Value end
	if frame >= track[#track].Frame then return track[#track].Value end
	local low, high = 1, #track
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if track[middle].Frame <= frame then low = middle else high = middle end
	end
	local left, right = track[low], track[high]
	local kind = typeof(left.Value)
	-- Discrete values switch at the actual key, not early when an easing overshoots.
	if kind == "boolean" then return left.Value end
	local alpha = (frame - left.Frame) / (right.Frame - left.Frame)
	if left.Ease then alpha = left.Ease(alpha) end
	if kind == "number" then return left.Value + (right.Value - left.Value) * alpha end
	if kind == "Color3" or kind == "Vector2" or kind == "Vector3" then
		return left.Value:Lerp(right.Value, alpha)
	end
	return left.Value
end

return PropertyTrack
