return {
	Name = "addCurrency",
	Aliases = { "ac" },
	Description = "플레이어에게 선택한 재화를 추가합니다.",
	Group = "Admin",

	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "추가 대상.",
		},
		{
			Type = "string",
			Name = "CurrencyName",
			Description = '재화 이름(예: Coins, Gems. 꼭 뒤에 "s"붙여주세요).',
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "추가할 수량",
		},
	},
}
