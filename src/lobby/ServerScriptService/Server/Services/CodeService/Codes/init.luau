local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)

-- Each ModuleScript in this folder is one code. Its name is the entered code;
-- matching ignores case and surrounding whitespace. StartsAt and ExpiresAt
-- may be Unix timestamps. Keep definitions server-side so unreleased codes
-- are not sent to clients.
local codes = {}
local allowedCurrencies = { Coins = true, Gems = true, Blossom = true }

for _, child in script:GetChildren() do
	if not child:IsA("ModuleScript") then
		continue
	end

	local key = string.upper(child.Name)
	assert(#key > 0 and #key <= 40 and not string.find(key, "%s"), `Invalid code name: {child.Name}`)
	assert(codes[key] == nil, `Duplicate code: {child.Name}`)

	local definition = require(child)
	assert(type(definition) == "table", `Code {child.Name} must return a table`)
	assert(definition.Enabled == nil or type(definition.Enabled) == "boolean", `Invalid Enabled in {child.Name}`)
	for _, field in { "StartsAt", "ExpiresAt" } do
		local value = definition[field]
		assert(value == nil or (type(value) == "number" and value % 1 == 0), `Invalid {field} in {child.Name}`)
	end
	assert(
		definition.StartsAt == nil or definition.ExpiresAt == nil or definition.StartsAt < definition.ExpiresAt,
		`Invalid time range in {child.Name}`
	)

	local rewards = definition.Rewards
	assert(type(rewards) == "table", `Code {child.Name} needs Rewards`)
	local rewardCount = 0
	for rewardType, value in rewards do
		if allowedCurrencies[rewardType] then
			assert(type(value) == "number" and value % 1 == 0 and value > 0 and value <= 1_000_000_000,
				`Invalid {rewardType} reward in {child.Name}`)
			rewardCount += 1
		elseif rewardType == "Emotes" then
			assert(type(value) == "table" and #value > 0, `Invalid Emotes in {child.Name}`)
			local seen = {}
			for index, emoteName in value do
				assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #value,
					`Emotes must be an array in {child.Name}`)
				assert(type(emoteName) == "string" and EmoteData.ByName[emoteName],
					`Unknown emote in {child.Name}: {tostring(emoteName)}`)
				assert(not seen[emoteName], `Duplicate emote in {child.Name}: {emoteName}`)
				seen[emoteName] = true
				rewardCount += 1
			end
		else
			error(`Unknown reward type in {child.Name}: {tostring(rewardType)}`)
		end
	end
	assert(rewardCount > 0, `Code {child.Name} has no rewards`)

	if rewards.Emotes then
		table.freeze(rewards.Emotes)
	end
	table.freeze(rewards)
	table.freeze(definition)
	codes[key] = definition
end

return table.freeze(codes)
