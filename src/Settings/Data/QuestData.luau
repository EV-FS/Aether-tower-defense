export type QuestConfig = {
	Id: string,
	Theme: string,
	Title: string,
	Description: string,
	TargetCurrency: string?,
	TargetMap: string?,
	TargetAmount: number,
	NpcId: string?,
	AutoAccept: boolean?,
	AutoClaim: boolean?,
	Rewards: {
		Coins: number?,
		Gems: number?,
		Exp: number?,
		[string]: any,
	},
}

local QuestData: { [string]: QuestConfig } = {
	["Chapter1Clear"] = {
		Id = "Chapter1Clear",
		Theme = "GUIDE",
		Title = "FIRST ADVENTURE",
		Description = "Clear Chapter 1.",
		TargetMap = "Chapter 1",
		TargetAmount = 1,
		AutoAccept = true,
		AutoClaim = true,
		Rewards = {
			Coins = 500,
			Gems = 5,
			Exp = 100,
		},
	},
	["BlossomCollector"] = {
		Id = "BlossomCollector",
		Theme = "EVENT",
		Title = "BLOSSOM COLLECTOR",
		Description = "Collect 1,500 Blossoms for the Kitsune purification.",
		TargetCurrency = "Blossom",
		TargetAmount = 1500,
		NpcId = "WanderingMerchant",
		Rewards = {
			Coins = 5000,
			Gems = 50,
			Exp = 200,
		},
	},
}

return QuestData
