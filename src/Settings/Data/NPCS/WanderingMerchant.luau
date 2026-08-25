return {
	Name = "방랑 상인",
	TypingSoundName = "WanderingMerchantNPCSpeaking",
	DialogueTree = {
		["Start"] = {
			Text = "반갑구만,, 혹시 내 물건에 관심이 있어?",
			Choices = {
				{ Text = "물건들을 보여줘.", Next = "Shop" },
				{ Text = "여행하면서 들은 소문이 있어?", Next = "Rumors" },
				{ Text = "너에 대해 알고 싶어.", Next = "About" },
				{ Text = "다음에 다시 올게.", Next = "End" },
			},
		},

		["Shop"] = {
			Text = "후후, 보는 눈이 있구나! 지금은 특별히 엄선된 장비와 소모품들이 준비되어 있어.",
			Choices = {
				{ Text = "다른 이야기도 듣고 싶어.", Next = "Start" },
				{ Text = "둘러보고 올게.", Next = "End" },
			},
		},

		["Rumors"] = {
			Text = "흠,, 여기 '키츠네 이벤트'에 들어가 키츠네를 물리쳐줘..",
			Choices = {
				{ Text = "더 자세한 정보는 없어?", Next = "RumorDetail" },
				{ Text = "조심할게. 고마워.", Next = "Start" },
				{ Text = "알겠어, 이만 가볼게.", Next = "End" },
			},
		},

		["RumorDetail"] = {
			Text = "듣기로는 강력한 보스가 봉인에서 깨어나려 한다더군. 단단히 준비하고 가야 할 거다!",
			Choices = {
				{ Text = "처음으로 돌아가기", Next = "Start" },
				{ Text = "좋은 정보 고마워.", Next = "End" },
			},
		},

		["About"] = {
			Text = "나는 여기 '키츠네 이벤트'를 당담하고 있는, 방랑 상인 이라고 할세",
			Choices = {
				{ Text = "처음으로 돌아가기", Next = "Start" },
				{ Text = "좋은 여행 되길 바라.", Next = "End" },
			},
		},
	},
}
