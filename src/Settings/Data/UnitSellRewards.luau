local CHANCES = table.freeze({
	Common = 0.005,
	Rare = 0.01,
	Epic = 0.04,
	Legendary = 0.20,
	Mythic = 1,
	Absolute = 1,
	Secret = 1,
})

local UnitSellRewards = {
	ItemName = "ShardStone",
	Chances = CHANCES,
}

function UnitSellRewards.Roll(rarity: string, random: Random): boolean
	local chance = CHANCES[rarity] or 0
	return chance >= 1 or (chance > 0 and random:NextNumber() < chance)
end

return table.freeze(UnitSellRewards)
