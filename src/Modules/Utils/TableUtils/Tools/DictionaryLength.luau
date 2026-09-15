return function(countTable): number
	local count = 0
	for _ in pairs(countTable) do
		count += 1
	end

	return count
end
