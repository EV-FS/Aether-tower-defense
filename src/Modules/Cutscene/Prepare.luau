local RunService = game:GetService("RunService")
local Prepare = {}

-- External asset loaders must not indefinitely prevent the camera-ready signal.
function Prepare.Try(label, timeout, callback, onCancel)
	local finished, success, result = false, false, nil
	local thread = task.spawn(function()
		success, result = pcall(callback)
		finished = true
	end)
	local deadline = os.clock() + timeout
	while not finished and os.clock() < deadline do RunService.Heartbeat:Wait() end
	if not finished then
		if onCancel then pcall(onCancel) end
		pcall(task.cancel, thread)
		local message = label .. " timed out after " .. timeout .. "s"
		warn("[CutscenePrepare] " .. message)
		return false, nil, message
	end
	if not success then
		if onCancel then pcall(onCancel) end
		warn("[CutscenePrepare] " .. label .. ": " .. tostring(result))
		return false, nil, result
	end
	return true, result, nil
end

-- Independent bounded jobs share the preparation window instead of stacking it.
function Prepare.All(jobs)
	local results = {}
	local pending = 0
	for _ in jobs do pending += 1 end
	for name, job in jobs do
		task.spawn(function()
			local ok, value, err = Prepare.Try(name, job.Timeout, job.Run, job.Cancel)
			results[name] = { Success = ok, Value = value, Error = err }
			pending -= 1
		end)
	end
	while pending > 0 do RunService.Heartbeat:Wait() end
	return results
end

return Prepare
