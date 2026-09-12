local SampleTrack = {}

function SampleTrack.Keys(samples)
	local keys = {}
	for frame, value in samples do
		assert(type(frame) == "number" and type(value) == "number", "FOV samples must be numeric")
		table.insert(keys, frame)
	end
	table.sort(keys)
	assert(#keys > 0, "Empty FOV track")
	return keys
end

function SampleTrack.Read(samples, keys, frame, cuts)
	if frame <= keys[1] then return samples[keys[1]] end
	if frame >= keys[#keys] then return samples[keys[#keys]] end
	local low, high = 1, #keys
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if keys[middle] <= frame then low = middle else high = middle end
	end
	local left, right = keys[low], keys[high]
	if cuts and cuts[right] then return samples[left] end
	local alpha = (frame - left) / (right - left)
	return samples[left] + (samples[right] - samples[left]) * alpha
end

return SampleTrack
