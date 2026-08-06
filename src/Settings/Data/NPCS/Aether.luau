return {
    Name = "Aether",
    TypingSoundName = "BlackmarketNPCSpeaking",
    DialogueTree = {
        ["Start"] = {
            Text = "당신... 내 물건 한 번 보지 않을텨?",
            Choices = {
                { Text = "네, 한 번 볼게요.", Next = "Shop" },
                { Text = "아뇨, 가세요.", Next = "End" }
            }
        },
        ["Shop"] = {
            Text = "얼마 만에 손님이야! 고마워. 자네, 뭘 살 텐가?",
            Choices = {
                { Text = "다음에 다시 올게요.", Next = "Bye" }
            }
        },
        ["Bye"] = {
            Text = "알살거면 왜 온거야 다신 오지 말어! 자네같은 사람은 줘도 안받어",
            Choices = {
                { Text = "갈게요", Next = "End" }
            }
        },
        ["End"] = {
            Text = "",
            Choices = {}
        }
    }
}
