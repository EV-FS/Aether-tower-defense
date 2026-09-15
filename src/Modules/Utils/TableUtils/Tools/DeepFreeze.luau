return function<T>(tbl): T
	if typeof(tbl) ~= "table" then
		return tbl
	end

	local function recurse(value)
		if typeof(value) ~= "table" or table.isfrozen(value) then
			return value
		end

		for _, val in pairs(value) do
			recurse(val)
		end

		return table.freeze(value)
	end

	return recurse(tbl)
end
