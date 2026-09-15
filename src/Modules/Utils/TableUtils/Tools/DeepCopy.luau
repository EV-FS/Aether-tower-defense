return function<T>(original): T
	if type(original) ~= "table" then
		return original
	end

	local function recurse(value)
		if type(value) ~= "table" then
			return value
		end

		local newTable = {}

		for key, val in pairs(value) do
			local newKey = recurse(key)
			local newVal = recurse(val)
			newTable[newKey] = newVal
		end

		return newTable
	end

	return recurse(original)
end
