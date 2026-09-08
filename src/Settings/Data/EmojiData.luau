local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type EmojiConfig = {
	Id: string,
	Index: number,
	DisplayName: string,
	Image: string,
	Duration: number,
}

type RawEmojiConfig = {
	Index: number,
	DisplayName: string,
	Image: string,
	Duration: number?,
}

local DEFAULT_DURATION = 3

local RawEmojiData: { [string]: RawEmojiConfig } = {
	Wave = {
		Index = 1,
		DisplayName = "Kitsune",
		Image = "rbxassetid://85986637320725",
	},
	Laugh = {
		Index = 2,
		DisplayName = "LOL",
		Image = "",
	},
	Love = {
		Index = 3,
		DisplayName = "Love",
		Image = "",
	},
	Surprised = {
		Index = 4,
		DisplayName = "Whoa!",
		Image = "",
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
		Duration = rawData.Duration or DEFAULT_DURATION,
	}

	EmojiData.ByName[id] = config
	EmojiData.ByIndex[config.Index] = config
end

return TableUtils.DeepFreeze(EmojiData)
