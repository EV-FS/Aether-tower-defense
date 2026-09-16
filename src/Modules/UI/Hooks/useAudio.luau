-- useAudio.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local cleanup = Vide.cleanup
local read = Vide.read

type Reactive<T> = T | (() -> T)

export type Config = {
	Id: Reactive<string | number>,
	Volume: Reactive<number>?,
	Looped: Reactive<boolean>?,
}

return function(config: Config)
	local output = SoundService:FindFirstChild("AudioDeviceOutput")
	assert(output, "AudioDeviceOutput이 먼저 준비되어야 함.")

	local player = create("AudioPlayer")({
		Parent = SoundService,

		Asset = function()
			local id = read(config.Id)
			return if typeof(id) == "number" then `rbxassetid://{id}` else id
		end,

		Volume = config.Volume or 1,
		Looping = config.Looped or false,
	})

	create("Wire")({
		Parent = player,
		SourceInstance = player,
		TargetInstance = output,
	})

	cleanup(function()
		player:Stop()
		player:Destroy()
	end)

	return {
		Play = function()
			player:Stop()
			player.TimePosition = 0
			player:Play()
		end,

		Stop = function()
			player:Stop()
		end,
	}
end
