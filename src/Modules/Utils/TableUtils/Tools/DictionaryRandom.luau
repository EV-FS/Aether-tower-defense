local RANDOM = Random.new()

return function(randomTable): (any, any)
	local length = 0
	for _ in pairs(randomTable) do
		length += 1
	end

	local randomIndex = RANDOM:NextInteger(1, length)
	local count = 1
	for idx, val in pairs(randomTable) do
		if randomIndex == count then
			return idx, val
		end
	end

	return nil
end
