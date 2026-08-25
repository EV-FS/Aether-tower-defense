return {
	Name = "ClearData",
	Aliases = { "cd" },
	Description = "플레이어의 데이터를 초기화합니다.",
	Group = "Admin",

	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "초기화 대상.",
		},
	},
}
