local Budget = require("../src/Modules/Utils/FrameBudget")
local now, yields = 0, 0
local step = Budget.new(function() yields += 1 end, 3, 0.002, function() return now end)
step(); step()
assert(yields == 0)
step()
assert(yields == 1, "Count limit did not yield")
now = 0.003
step()
assert(yields == 2, "Time limit did not yield")
step()
assert(yields == 2, "Budget did not reset")
step(3)
assert(yields == 3)
assert(not pcall(Budget.new, function() end, 0, 0.002))
local slow, adaptiveYields = false, 0
local adaptive = Budget.new(function()
	adaptiveYields += 1
	slow = true
end, 8, 0.002, function() return 0 end, function()
	return if slow then 2 else 8, if slow then 0.001 else 0.002
end)
adaptive(8)
assert(adaptiveYields == 1)
adaptive(2)
assert(adaptiveYields == 2, "Slow-frame policy did not back off")
local weightedYields = 0
local weighted = Budget.new(function() weightedYields += 1 end, 256, 0.002, function() return 0 end)
for _ = 1, 2047 do weighted(1 / 8) end
assert(weightedYields == 0)
weighted(1 / 8)
assert(weightedYields == 1, "Cheap preparation should not yield every 128 nodes")
print("FrameBudget tests passed")
