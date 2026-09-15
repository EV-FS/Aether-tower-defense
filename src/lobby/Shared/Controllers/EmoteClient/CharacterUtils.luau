--// CharacterUtils
-- Character-related utility functions for the emote system.

local CharacterUtils = {}

--[[ Returns the root part (HumanoidRootPart) of a character. ]]
function CharacterUtils.GetRootPart(character: Model): BasePart?
	return character.PrimaryPart or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

return CharacterUtils
