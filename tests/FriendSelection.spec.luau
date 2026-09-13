local Selection = require("../src/Modules/Cutscene/FriendSelection")
local function first(count) assert(count > 0); return 1 end
assert(Selection.FromPage({}, 10, first) == nil)
assert(Selection.FromPage({ { Id = 10 }, { Id = -1 }, { Id = "123" }, { Id = 1.5 }, {} }, 10, first) == nil)
local page = { { Id = 20 }, { Id = 20 }, { Id = 30 } }
assert(Selection.FromPage(page, 10, function(count) assert(count == 2); return count end) == 30)
assert(Selection.FromPage(page, 10, first) == 20)
-- Each viewer's own list is selected independently; strangers are never a fallback.
assert(Selection.FromPage({ { Id = 100 } }, 1, first) == 100)
assert(Selection.FromPage({ { Id = 200 } }, 2, first) == 200)
assert(Selection.FromPage({ { Id = 300 } }, 3, first) == 300)
assert(page[1].Id == 20 and #page == 3, "Friend API response must not be mutated")
print("FriendSelection tests passed")
