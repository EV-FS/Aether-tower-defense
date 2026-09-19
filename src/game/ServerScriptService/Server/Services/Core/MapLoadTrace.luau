-- Start messages deliberately precede engine calls: an atomic engine stall can
-- prevent both the completion message and an xpcall error handler from running.
local MapLoadTrace = {}
MapLoadTrace.__index = MapLoadTrace

function MapLoadTrace.new(mapName, state)
	return setmetatable({ Name = mapName, State = state }, MapLoadTrace)
end

function MapLoadTrace:Run(phase, callback)
	task.wait()
	self.State:SetAttribute("MapLoadPhase", phase)
	print(string.format("[MapLoad] %s START %s", self.Name, phase))
	local started = os.clock()
	local ok, result = xpcall(callback, debug.traceback)
	local elapsed = os.clock() - started
	if not ok then
		local detail = string.format("[%s] %s", phase, tostring(result))
		-- Preserve the original failure BEFORE attempting scene cleanup.
		self.State:SetAttribute("MapLoadPhase", "Failed: " .. phase)
		self.State:SetAttribute("LoadError", string.sub(detail, 1, 1000))
		warn(string.format("[MapLoad] %s FAILED %s after %.3fs: %s", self.Name, phase, elapsed, result))
		error(detail, 0)
	end
	self.State:SetAttribute("Map" .. phase .. "Seconds", elapsed)
	print(string.format("[MapLoad] %s DONE %s %.3fs", self.Name, phase, elapsed))
	return result
end

return MapLoadTrace
