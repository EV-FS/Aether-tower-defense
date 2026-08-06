return {
    Name = "Aether",
    TypingSoundName = "BlackmarketNPCSpeaking",
    DialogueTree = {
        ["Start"] = {
            Text = "이봐 당신 내 물건에 관심이 있는 거군,맞지?",
            Choices = {
                { Text = "한 번 볼게요.", Next = "Shop" },
                { Text = "안믿습니다.", Next = "What" }
            }
        },
        ["Shop"] = {
            Text = "으흐흐.. 역시 내 감을 틀리지 않는다랄까? 어떤걸 구매 할테지?",
            Choices = {
                { Text = "다음에 다시 올게요.", Next = "Bye" }
            }
        },
        ["What"] = {
            Text = "다신 오지 말게나!",
            Choices = {
                { Text = "...", Next = "End" }
            }
        },
        ["Bye"] = {
            Text = "이봐 안살거면 그냥 가라구, 내 물건은 소중하니까.",
            Choices = {
                { Text = "갈게요", Next = "End" }
            }
        }
    }
}
