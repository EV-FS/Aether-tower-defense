-- Cleanup must continue even if a destroyed track/property rejects an operation.
local Cleanup = {}
function Cleanup.Try(label, callback, report)
	local ok, err = pcall(callback)
	if not ok then (report or warn)("[CutsceneCleanup] " .. label .. ": " .. tostring(err)) end
	return ok
end
function Cleanup.All(steps, report)
	local ok = true
	for _, step in steps do
		if not Cleanup.Try(step.Name, step.Run, report) then ok = false end
	end
	return ok
end
return Cleanup
