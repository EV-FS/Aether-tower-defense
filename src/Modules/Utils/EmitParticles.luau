local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TimeService

local function GetTimeService()
	if not TimeService then
		pcall(function()
			TimeService = ServiceRegistry:GetService("TimeService")
		end)
	end
	return TimeService
end

return function(effect: Instance)
	local rootInstance = effect
	local isModel = effect:IsA("BasePart")
		and effect.Parent
		and effect.Parent:IsA("Model")
		and effect.Parent.PrimaryPart == effect
	if isModel then
		rootInstance = effect.Parent
	end

	local gameSpeed = if GetTimeService() then GetTimeService():GetGameSpeed() else 1

	for _, descendant in rootInstance:GetDescendants() do
		if not descendant:IsA("ParticleEmitter") and not descendant:IsA("Beam") and not descendant:IsA("Trail") then
			continue
		end

		local emitter = descendant

		pcall(function()
			(emitter :: any).TimeScale = gameSpeed
		end)

		local emitCount = emitter:GetAttribute("EmitCount") or 0
		local emitDelay = emitter:GetAttribute("EmitDelay") or 0
		local emitDuration = emitter:GetAttribute("EmitDuration") or 0

		task.spawn(function()
			if emitDelay > 0 then
				if TimeService then
					TimeService.DeltaWait(emitDelay)
				else
					task.wait(emitDelay)
				end
			end

			if emitCount > 0 then
				emitter:Emit(emitCount)
			end

			if emitDuration > 0 then
				emitter.Enabled = true
				if TimeService then
					TimeService.DeltaWait(emitDuration)
				else
					task.wait(emitDuration)
				end
				emitter.Enabled = false
			end
		end)
	end
end
