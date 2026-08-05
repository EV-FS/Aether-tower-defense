return {
	Name = "rollbackData",
	Aliases = { "rollback" },
	Description = "[경고] 플레이어의 데이터를 해당 날짜로 롤백합니다. 주의해서 사용해 주세요.",
	Group = "Admin",

	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "롤백 대상.",
		},
		{
			Type = "string",
			Name = "Timezone",
			Description = "UTC(그리니치 시간대 GMT+0) 또는 KST(한국 시간 대 GMT+9)",
		},
		{
			Type = "integer",
			Name = "Year",
			Description = "연도",
		},
		{
			Type = "integer",
			Name = "Month",
			Description = "월",
		},
		{
			Type = "integer",
			Name = "Day",
			Description = "일",
		},
		{
			Type = "integer",
			Name = "Hour",
			Description = "시",
		},
		{
			Type = "integer",
			Name = "Minute",
			Description = "분",
		},
		{
			Type = "integer",
			Name = "Second",
			Description = "초",
		},
	},
}
