-- Select only IDs returned by Roblox for this user's friends; never invent a fallback ID.
local FriendSelection = {}
function FriendSelection.FromPage(page, userId, randomIndex)
	local candidates, seen = {}, {}
	for _, item in page do
		local id = item.Id
		if type(id) == "number" and id > 0 and id % 1 == 0 and id ~= userId and not seen[id] then
			seen[id] = true
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then return nil end
	return candidates[randomIndex(#candidates)]
end
return FriendSelection
