local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local State = {
	SearchText = Vide.source(""),
	SelectedTower = Vide.source(nil),
	HoveredTower = Vide.source(nil),
	HoveredExistCount = Vide.source(0),
	EquippedSlots = Vide.source({}),

	ButtonEntries = Vide.source({}),
	RarityEntries = {},
	RarityState = {},

	ExistCounts = {},
}

State.COLORS = {
	DEFAULT = Color3.new(1, 1, 1),
	EQUIP = Color3.new(0, 1, 0.5),
}

State.RARITY_CONFIG = {
	Exclusive = {
		Order = 1,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(204, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 234)),
		}),
	},
	Absolute = {
		Order = 2,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 187, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 0, 255)),
		}),
	},
	Mythic = {
		Order = 3,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 8, 204)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 4)),
		}),
	},
	Legendary = {
		Order = 4,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
		}),
	},
	Epic = {
		Order = 5,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(234, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(106, 0, 255)),
		}),
	},
	Rare = {
		Order = 6,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 238, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 119, 255)),
		}),
	},
	Uncommon = {
		Order = 7,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 255, 0)),
		}),
	},
	Common = {
		Order = 8,
		Colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(127, 127, 127)),
		}),
	},
}
State.RARITY_NAMES = { "Exclusive", "Absolute", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

for _, rarity in ipairs(State.RARITY_NAMES) do
	State.RarityEntries[rarity] = Vide.source({})
	State.RarityState[rarity] = { Exist = Vide.source(false), Opened = Vide.source(true) }
end

function State.generateAttributesKey(towerName: string, towerData: any): string
	return `{towerName}_Level:{towerData.Lv or 0}_Stars:{towerData.Stars or 0}`
end

function State.generateTowerId(towerName, towerKey)
	if not towerName or not towerKey then
		return nil
	end
	local numberText = string.match(tostring(towerKey), "^t_(%d+)$")
	local towerKeyId = numberText and tonumber(numberText) or tonumber(towerKey)
	if not towerKeyId then
		return nil
	end
	return `{towerName}:{towerKeyId}`
end

function State.getRepresentativeTower(name, stack, slots)
	local equipped, unequipped = nil, nil
	for _, tower in ipairs(stack.Towers) do
		local id = State.generateTowerId(name, tower.Key)
		if id and slots[id] then
			equipped = tower
			break
		else
			unequipped = tower
		end
	end
	return equipped or unequipped
end

function State.calculateExpProgress(exp, currentLv)
	local maxExp = (currentLv or 0) * 100
	if maxExp == 0 then
		return 0
	end
	return math.clamp(exp / maxExp, 0, 1)
end

return State
