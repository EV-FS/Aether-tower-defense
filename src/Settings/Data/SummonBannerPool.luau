-- Only units listed here can appear in a rotating summon banner.
-- Keep crafting-only, event-only, and development units out of this roster.
-- Names must match TowerData and ReplicatedStorage.Assets.Towers exactly.
return table.freeze({
	Common = table.freeze({ "Fighter", "Harvester" }),
	Rare = table.freeze({ "YoungkkYongSa" }),
	Epic = table.freeze({ "Cowboy", "Elder Wizard", "Lancer", "Ganet" }),
	Legendary = table.freeze({ "장애인해적", "Knight" }),
	Mythic = table.freeze({ "Emperor", "Chronos" }),
	Absolute = table.freeze({ "Wizard", "Kitsune Samurai", "Galahad", "Ranger Super Tower" }),
})
