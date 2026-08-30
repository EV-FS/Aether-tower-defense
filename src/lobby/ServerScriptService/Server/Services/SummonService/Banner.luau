local Banner = {}

Banner._UnitPool = {
	Common = { "Bacon", "Dummy", "Noob", "Batter Bacon", "Boxer Noob", "Scyther Dummy" },
	Rare = { "Gunner Dummy", "Katana Noob" },
	Epic = { "Lancer Dummy", "Poor Bacon", "Smith Dummy" },
	Legendary = { "Minigunner Dummy", "RPG Noob", "King Noob", "Mecha" },
	Mythic = { "Cyborg Dummy", "Poseidon Noob", "Laser Dummy" },
	Absolute = { "Hacker" },
}

Banner.UnitPool = {
	Common = { "Bacon", "Dummy", "Noob", "Batter Bacon", "Boxer Noob", "Scyther Dummy" },
	Rare = { "Gunner Dummy", "Katana Noob" },
	Epic = { "Lancer Dummy", "Poor Bacon" },
	Legendary = { "Minigunner Dummy", "King Noob" },
	Mythic = { "Cyborg Dummy", "Poseidon Noob" },
	Absolute = { "Hacker" },
}

Banner.RarityRates = {
	{ Rarity = "Common", Weight = 75 },
	{ Rarity = "Rare", Weight = 17.89 },
	{ Rarity = "Epic", Weight = 6 },
	{ Rarity = "Legendary", Weight = 1 },
	{ Rarity = "Mythic", Weight = 0.1 },
	{ Rarity = "Absolute", Weight = 0.01 },
}

local SECRET_SERVER_SALT = 8472957102
local currentBanner = nil
local bannerHour = -1

function Banner.GetActiveBanner()
	local currentHour = math.floor(os.time() / 3600)

	if currentHour == bannerHour and currentBanner then
		return currentBanner
	end

	bannerHour = currentHour

	local activeLineup = {}
	local totalWeight = 0

	for i, rateData in ipairs(Banner.RarityRates) do
		local pool = Banner.UnitPool[rateData.Rarity]
		if not pool or #pool == 0 then
			continue
		end

		local rng = Random.new(currentHour + (i * 9999) + SECRET_SERVER_SALT)
		local selectedUnit = pool[rng:NextInteger(1, #pool)]

		table.insert(activeLineup, {
			Unit = selectedUnit,
			Rarity = rateData.Rarity,
			Weight = rateData.Weight,
		})
		totalWeight += rateData.Weight
	end

	currentBanner = {
		Units = activeLineup,
		TotalWeight = totalWeight,
	}

	return currentBanner
end

function Banner.GetClientFormat()
	local activeBanner = Banner.GetActiveBanner()
	local clientData = {
		NextRerollTime = (bannerHour + 1) * 3600,
		Units = {},
	}

	for _, data in ipairs(activeBanner.Units) do
		table.insert(clientData.Units, {
			Rarity = data.Rarity,
			Name = data.Unit,
			RateText = tostring(data.Weight) .. "%",
		})
	end

	return clientData
end

return Banner
