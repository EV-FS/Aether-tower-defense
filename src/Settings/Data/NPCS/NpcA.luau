return {
    Name = "지나가는 상인",
    TypingSoundName = "BlackmarketNPCSpeaking",
    DialogueTree = {
        ["Start"] = {
            Text = "안녕! 물건 좀 볼래?",
            Choices = {
                { Text = "그래, 보여줘.", Next = "Shop" },
                { Text = "아니, 다음에.", Next = "End" }
            }
        },
        ["Shop"] = {
            Text = "무엇을 살래?",
            Choices = {
                { Text = "나가기", Next = "End" }
            }
        },
        ["End"] = {
            Text = "다음에 또 봐!",
            Choices = {}
        }
    }
}
