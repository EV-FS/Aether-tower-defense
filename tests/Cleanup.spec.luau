local Cleanup = require("../src/Modules/Cutscene/Cleanup")
local errors, visited = {}, {}
local function report(message) table.insert(errors, message) end
assert(not Cleanup.All({
	{ Name = "Track", Run = function() table.insert(visited, "Track"); error("Already destroyed") end },
	{ Name = "Model", Run = function() table.insert(visited, "Model") end },
	{ Name = "Camera", Run = function() table.insert(visited, "Camera"); error("Camera removed") end },
	{ Name = "Loading", Run = function() table.insert(visited, "Loading") end },
}, report))
assert(table.concat(visited, ",") == "Track,Model,Camera,Loading", "Cleanup must not abort on the first error")
assert(#errors == 2 and string.find(errors[1], "Track") and string.find(errors[2], "Camera"))
assert(Cleanup.All({}, report))
assert(Cleanup.Try("Success", function() end, report))
print("Cleanup tests passed")
