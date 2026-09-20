export type Presentation = {
	Theme: string,
	Title: string,
	Description: string,
	NpcId: string?,
}

export type Objective = {
	Kind: "Currency" | "MapClear",
	Target: string,
	Amount: number,
}

export type Lifecycle = {
	AutoAccept: boolean,
	AutoClaim: boolean,
}

export type Rewards = {
	Coins: number?,
	Gems: number?,
	Exp: number?,
	[string]: number?,
}

local Components = {}

function Components.Presentation(theme: string, title: string, description: string, npcId: string?): Presentation
	return table.freeze({
		Theme = theme,
		Title = title,
		Description = description,
		NpcId = npcId,
	})
end

function Components.CurrencyObjective(currencyName: string, amount: number): Objective
	return table.freeze({
		Kind = "Currency",
		Target = currencyName,
		Amount = amount,
	})
end

function Components.MapClearObjective(mapName: string, amount: number?): Objective
	return table.freeze({
		Kind = "MapClear",
		Target = mapName,
		Amount = amount or 1,
	})
end

function Components.Lifecycle(autoAccept: boolean?, autoClaim: boolean?): Lifecycle
	return table.freeze({
		AutoAccept = autoAccept == true,
		AutoClaim = autoClaim == true,
	})
end

function Components.Rewards(rewards: Rewards): Rewards
	return table.freeze(table.clone(rewards))
end

return table.freeze(Components)
