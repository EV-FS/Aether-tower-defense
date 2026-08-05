return {
	Name = "addTower",
	Aliases = { "at" },
	Description = "플레이어에게 선택한 타워를 추가합니다.",
	Group = "Admin",

	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "추가 대상.",
		},
		{
			Type = "string",
			Name = "TowerName",
			Description = "타워 이름.",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "추가할 수량",
		},
	},
}
