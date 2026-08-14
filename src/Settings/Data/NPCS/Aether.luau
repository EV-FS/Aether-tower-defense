return {
	Name = "Aether",
	TypingSoundName = "BlackmarketNPCSpeaking",
	DialogueTree = {
		["Start"] = {
			Text = "처음 보는 얼굴이네. 이곳을 둘러보기 전에 도움이 필요해?",
			Choices = {
				{ Text = "메뉴 사용법을 알려줘.", Next = "Tutorial" },
				{ Text = "괜찮아, 혼자 둘러볼게.", Next = "End" },
			},
		},
		["Tutorial"] = {
			Text = "좋아. 네가 필요한 기능부터 차례로 보여줄게. 준비됐으면 시작하자.",
			Choices = {
				{ Text = "튜토리얼 시작", Next = "StartTutorial" },
				{ Text = "나중에 할게.", Next = "End" },
			},
		},
		["StartTutorial"] = {
			Text = "",
			Choices = {},
		},
	},
}
