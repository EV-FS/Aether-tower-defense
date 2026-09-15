-- Inject the yield/clock functions so scheduling can be tested without Roblox.
local FrameBudget = {}

function FrameBudget.new(yieldFrame, maxItems, maxSeconds, clock, limits)
	clock = clock or os.clock
	maxItems = maxItems or 64
	maxSeconds = maxSeconds or 0.002
	assert(maxItems > 0 and maxSeconds > 0, "Frame budget must be positive")
	local count, started = 0, clock()
	local itemLimit, timeLimit = maxItems, maxSeconds
	local function refresh()
		if limits then
			local items, seconds = limits()
			assert(items > 0 and seconds > 0, "Adaptive budget must be positive")
			itemLimit, timeLimit = math.min(maxItems, items), math.min(maxSeconds, seconds)
		end
	end
	refresh()
	return function(cost)
		count += cost or 1
		if count >= itemLimit or clock() - started >= timeLimit then
			yieldFrame()
			count, started = 0, clock()
			refresh()
		end
	end
end

return FrameBudget
