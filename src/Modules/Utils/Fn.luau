local Fn = {}

function Fn.Bind(func, ...)
	local boundArgs = { ... }
	local nBound = select("#", ...)
	return function(...)
		local nEvent = select("#", ...)
		local eventArgs = { ... }
		local allArgs = table.create(nBound + nEvent)
		table.move(boundArgs, 1, nBound, 1, allArgs)
		table.move(eventArgs, 1, nEvent, nBound + 1, allArgs)
		return func(unpack(allArgs, 1, nBound + nEvent))
	end
end

function Fn.Once(func)
	local ran = false
	local result = nil
	return function(...)
		if not ran then
			ran = true
			result = func(...)
		end
		return result
	end
end

return Fn
