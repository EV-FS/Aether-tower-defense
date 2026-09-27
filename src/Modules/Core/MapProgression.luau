local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapData = require(ReplicatedStorage.Settings.Data.MapData)

local MapProgression = {}

local storyMaps = {}
for mapName, definition in MapData do
	if definition.Mode == "Story" then
		table.insert(storyMaps, mapName)
	end
end
table.sort(storyMaps, function(left, right)
	return MapData[left].LayoutOrder < MapData[right].LayoutOrder
end)
table.freeze(storyMaps)

MapProgression.StoryMaps = storyMaps

function MapProgression.IsUnlocked(mapName: string, clears: { [string]: number }?): boolean
	local definition = MapData[mapName]
	if not definition then return false end
	if not definition.UnlockAfter then return true end
	if (tonumber(clears and clears[mapName]) or 0) > 0 then return true end
	return (tonumber(clears and clears[definition.UnlockAfter]) or 0) > 0
end

function MapProgression.CurrentStoryMap(clears: { [string]: number }?): string
	local current = storyMaps[1]
	for _, mapName in storyMaps do
		if MapProgression.IsUnlocked(mapName, clears) then
			current = mapName
		end
	end
	return current
end

return table.freeze(MapProgression)
