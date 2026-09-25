-- Scroll a periodic palette by moving its stops, like wrapping texture UVs.
-- Only the two viewport edges need interpolated colors; interior colors stay intact.
local ColorSequenceScroll = {}

export type Palette = {
	Keypoints: { ColorSequenceKeypoint },
	Steps: number,
	IsSolid: boolean,
}

local MAX_STOPS = 20
local EDGE_EPSILON = 1e-6

local function evaluate(keypoints: { ColorSequenceKeypoint }, position: number): Color3
	for index = 2, #keypoints do
		local right = keypoints[index]
		if position <= right.Time then
			local left = keypoints[index - 1]
			local span = right.Time - left.Time
			return left.Value:Lerp(right.Value, if span > 0 then (position - left.Time) / span else 0)
		end
	end
	return keypoints[#keypoints].Value
end

function ColorSequenceScroll.Prepare(sequence: ColorSequence): Palette
	local keypoints = sequence.Keypoints
	local firstColor = keypoints[1].Value
	local isSolid = true
	for _, keypoint in keypoints do
		if keypoint.Value ~= firstColor then
			isSolid = false
			break
		end
	end

	local steps = #keypoints - 1
	if keypoints[#keypoints].Value ~= firstColor then
		steps += 1
		local scale = (steps - 1) / steps
		local closed = table.create(#keypoints + 1)
		for index, keypoint in keypoints do
			closed[index] = ColorSequenceKeypoint.new(keypoint.Time * scale, keypoint.Value)
		end
		closed[#closed + 1] = ColorSequenceKeypoint.new(1, firstColor)
		keypoints = closed
	end

	if #keypoints - 1 > MAX_STOPS - 2 then
		local resampled = table.create(MAX_STOPS - 1)
		for index = 0, MAX_STOPS - 2 do
			local position = index / (MAX_STOPS - 2)
			resampled[index + 1] = ColorSequenceKeypoint.new(position, evaluate(keypoints, position))
		end
		keypoints = resampled
	end

	return { Keypoints = keypoints, Steps = steps, IsSolid = isSolid }
end

function ColorSequenceScroll.Sample(palette: Palette, phase: number): ColorSequence
	phase %= 1
	local keypoints = palette.Keypoints
	local boundaryColor = evaluate(keypoints, (1 - phase) % 1)
	local shifted = table.create(#keypoints + 1)
	shifted[1] = ColorSequenceKeypoint.new(0, boundaryColor)

	local split = #keypoints
	for index = 1, #keypoints - 1 do
		if keypoints[index].Time + phase >= 1 then
			split = index
			break
		end
	end
	for index = split, #keypoints - 1 do
		local keypoint = keypoints[index]
		local position = keypoint.Time + phase - 1
		if position > EDGE_EPSILON and position < 1 - EDGE_EPSILON then
			shifted[#shifted + 1] = ColorSequenceKeypoint.new(position, keypoint.Value)
		end
	end
	for index = 1, split - 1 do
		local keypoint = keypoints[index]
		local position = keypoint.Time + phase
		if position > EDGE_EPSILON and position < 1 - EDGE_EPSILON then
			shifted[#shifted + 1] = ColorSequenceKeypoint.new(position, keypoint.Value)
		end
	end
	shifted[#shifted + 1] = ColorSequenceKeypoint.new(1, boundaryColor)
	return ColorSequence.new(shifted)
end

return ColorSequenceScroll
