local VisualService = {}

local AudioService
local VFXService
local TimeService

function VisualService.Init(services)
	AudioService = services:GetService("AudioService")
	VFXService = services:GetService("VFXService")
	TimeService = services:GetService("TimeService")
end

function VisualService.Start() end

function VisualService.Play(
	name: string,
	eventName: string,
	level: number?,
	sourceModel: Model,
	targetModel: Model?,
	range: number?,
	delay: number?
)
	local sfxRecipes = AudioService.GetRecipes(name, eventName, level)
	if sfxRecipes then
		if delay and delay > 0 then
			TimeService.DeltaDelay(delay):andThen(function()
				AudioService.PlayFromRecipes(sfxRecipes, sourceModel, targetModel)
			end)
		else
			AudioService.PlayFromRecipes(sfxRecipes, sourceModel, targetModel)
		end
	end

	local vfxRecipes = VFXService.GetRecipes(name, eventName, level)
	if vfxRecipes then
		VFXService.PlayVFX(vfxRecipes, sourceModel, targetModel, range, delay)
	end
end

return VisualService
