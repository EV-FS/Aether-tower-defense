local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local EmojiWheel = require(script.Parent.EmojiWheel)

local mount = Vide.mount
local source = Vide.source

return function(target: Instance)
	local container = Instance.new("Frame")
	container.Name = "EmojiWheelStoryContainer"
	container.BackgroundColor3 = Color3.fromRGB(25, 35, 55)
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = target

	local props = {
		Emoji1 = source({ Id = "Wave", DisplayName = "Hello!", Image = "" }),
		Emoji2 = source({ Id = "Laugh", DisplayName = "LOL", Image = "" }),
		Emoji3 = source({ Id = "Love", DisplayName = "Love", Image = "" }),
		Emoji4 = source({ Id = "Surprised", DisplayName = "Whoa!", Image = "" }),
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
