local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local EmojiWheel = require(script.Parent.EmojiWheel)
local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)

local mount = Vide.mount
local source = Vide.source

return function(target: Instance)
	local container = Instance.new("Frame")
	container.Name = "EmojiWheelStoryContainer"
	container.BackgroundColor3 = Color3.fromRGB(25, 35, 55)
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = target

	local entries = {}
	for index = 1, 4 do
		local config = EmojiData.ByIndex[index]
		table.insert(entries, source({
			Id = config.Id,
			Name = config.Id,
			DisplayName = config.DisplayName,
			Image = config.Image,
			Symbol = config.Symbol,
		}))
	end
	local props = {
		Emojis = entries,
		EquipMode = source(false),
		OnSelected = function(emojiId: string)
			print(`Selected emoji: {emojiId}`)
		end,
	}

	local destroyVide = mount(function()
		return EmojiWheel(props)
	end, container)

	return function()
		destroyVide()
		container:Destroy()
	end
end
