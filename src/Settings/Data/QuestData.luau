export type QuestConfig = {
	Id: string,
	Theme: string,
	Title: string,
	Description: string,
	TargetCurrency: string?,
	TargetAmount: number,
	NpcId: string?,
	Rewards: {
		Coins: number?,
		Gems: number?,
		Exp: number?,
		[string]: any,
	},
}

local QuestData: { [string]: QuestConfig } = {
	["BlossomCollector"] = {
		Id = "BlossomCollector",
		Theme = "EVENT",
		Title = "벚꽃 수집가",
		Description = "벚꽃 재화 1,500개 수집하기",
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
