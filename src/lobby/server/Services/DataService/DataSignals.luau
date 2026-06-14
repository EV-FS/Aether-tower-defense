local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local KeySignals = {}
local DataSignals = {}

function DataSignals:GetChangedSignal(mainKey: string)
	if not KeySignals[mainKey] then
		KeySignals[mainKey] = Signal.new()
	end

	return KeySignals[mainKey]
end

function DataSignals:Fire(player: Player, mainKey: string, value: any)
	local signal = KeySignals[mainKey]
	if signal then
		signal:Fire(player, value)
	end
end

return DataSignals
