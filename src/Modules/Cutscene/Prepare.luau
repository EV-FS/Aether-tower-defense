local RunService = game:GetService("RunService")
local Prepare = {}

-- External asset loaders must not indefinitely prevent the camera-ready signal.
function Prepare.Try(label, timeout, callback)
	local finished, success, result = false, false, nil
	local thread = task.spawn(function()
		success, result = pcall(callback)
		finished = true
	end)
	local deadline = os.clock() + timeout
	while not finished and os.clock() < deadline do RunService.Heartbeat:Wait() end
	if not finished then
		pcall(task.cancel, thread)
		warn("[CutscenePrepare] " .. label .. " timed out after " .. timeout .. "s")
		return false, nil
	end
	if not success then warn("[CutscenePrepare] " .. label .. ": " .. tostring(result)) end
	return success, result
end

return Prepare
