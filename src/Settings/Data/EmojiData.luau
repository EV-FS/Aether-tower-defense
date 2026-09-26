local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type EmojiConfig = {
	Id: string,
	Index: number,
	DisplayName: string,
	Image: string,
	Symbol: string,
	Duration: number,
}

type RawEmojiConfig = {
	Index: number,
	DisplayName: string,
	Image: string,
	Symbol: string,
	Duration: number?,
}

local DEFAULT_DURATION = 3

local RawEmojiData: { [string]: RawEmojiConfig } = {
	Wave = {
		Index = 1,
		DisplayName = "Kitsune",
		Image = "rbxassetid://85986637320725",
		Symbol = "W",
	},
	Laugh = {
		Index = 2,
		DisplayName = "LOL",
		Image = "",
		Symbol = "LOL",
	},
	Love = {
		Index = 3,
		DisplayName = "Love",
		Image = "",
		Symbol = "<3",
	},
	Surprised = {
		Index = 4,
		DisplayName = "Whoa!",
		Image = "",
		Symbol = "!",
	},
}

local EmojiData = {
	ByName = {} :: { [string]: EmojiConfig },
	ByIndex = {} :: { [number]: EmojiConfig },
}

for id, rawData in pairs(RawEmojiData) do
	local config: EmojiConfig = {
		Id = id,
		Index = rawData.Index,
		DisplayName = rawData.DisplayName,
		Image = rawData.Image,
		Symbol = rawData.Symbol,
		Duration = rawData.Duration or DEFAULT_DURATION,
	}

	EmojiData.ByName[id] = config
	EmojiData.ByIndex[config.Index] = config
end

return TableUtils.DeepFreeze(EmojiData)
