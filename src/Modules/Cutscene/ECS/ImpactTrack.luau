-- A held image state, not a queue of callbacks: skipped frames never replay old flashes.
local ImpactTrack = {}

function ImpactTrack.Keys(events)
	local keys = {}
	for frame, imageId in pairs(events) do
		assert(type(frame) == "number" and frame >= 0 and frame % 1 == 0, "Impact frame must be a nonnegative integer")
		assert(imageId == false or (type(imageId) == "number" and imageId > 0 and imageId % 1 == 0), "Impact image must be an asset ID or false")
		table.insert(keys, frame)
	end
	table.sort(keys)
	return keys
end

function ImpactTrack.Read(events, keys, frame)
	local low, high = 1, #keys
	local result = false
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if keys[middle] <= frame then
			result = events[keys[middle]]
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return result
end

return ImpactTrack
