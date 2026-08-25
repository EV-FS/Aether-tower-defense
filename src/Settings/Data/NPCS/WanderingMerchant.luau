return {
	Name = "방랑 상인",
	TypingSoundName = "WanderingMerchantNPCSpeaking",
	DialogueTree = {
		["Start"] = {
			Text = "반갑구만,, 혹시 내 물건에 관심이 있어?",
			Choices = {
				{ Text = "도움이 필요한 일이 있어? [퀘스트]", Next = "Quest_Check" },
				{ Text = "물건들을 보여줘.", Next = "Shop" },
				{ Text = "여행하면서 들은 소문이 있어?", Next = "Rumors" },
				{ Text = "너에 대해 알고 싶어.", Next = "About" },
				{ Text = "다음에 다시 올게.", Next = "End" },
			},
		},

		["Quest_Check"] = {
			Text = "마침 잘 왔네! 키츠네의 결계를 정화하기 위해선 '벚꽃' 1,500개가 꼭 필요하다네. 자네가 좀 모아다 줄 수 있겠나?",
			Choices = {
				{ Text = "좋아! 벚꽃 1,500개를 모아올게. [수락]", Next = "Quest_Accepted" },
				{ Text = "지금은 바빠서 힘들 것 같아.", Next = "Start" },
			},
		},

		["Quest_Accepted"] = {
			Text = "고맙네! 벚꽃 1,500개를 모아서 다시 나를 찾아오게나. 보상은 두둑이 챙겨주지!",
			Choices = {
				{ Text = "알겠어, 금방 다녀올게!", Next = "End" },
			},
		},

		["Quest_Progress"] = {
			Text = "아직 벚꽃이 부족하구만... 목표는 1,500개라네! 힘내게나.",
			Choices = {
				{ Text = "더 모아올게.", Next = "End" },
				{ Text = "처음으로 돌아가기", Next = "Start" },
			},
		},

		["Quest_Ready"] = {
			Text = "오오! 벚꽃 1,500개를 모두 모아왔군! 정말 대단해. 약속대로 보상을 주겠네!",
			Choices = {
				{ Text = "보상 받기! [완료]", Next = "Quest_Completed" },
			},
		},

		["Quest_Completed"] = {
			Text = "자네 덕분에 큰 힘이 되었네. 앞으로도 잘 부탁하네! (보상: 5,000 코인, 50 젬, 200 EXP 지급)",
			Choices = {
				{ Text = "언제든 불러줘.", Next = "End" },
				{ Text = "처음으로 돌아가기", Next = "Start" },
			},
		},

		["Quest_AlreadyDone"] = {
			Text = "자네 덕분에 벚꽃은 아주 충분하다네. 고마운 마음 잊지 않겠네!",
			Choices = {
				{ Text = "천만에!", Next = "End" },
				{ Text = "처음으로 돌아가기", Next = "Start" },
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
