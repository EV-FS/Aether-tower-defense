local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local LoadingScreen = require(script.Parent.LoadingScreen)

local mount = Vide.mount
local source = Vide.source

return function(target: Instance)
	local isVisible = source(false)
	local destroyVide = mount(function()
		return LoadingScreen({
			IsVisible = isVisible,
			UseScreenGui = false,
		})
	end, target)

	task.defer(function()
		if target.Parent then
			isVisible(true)

			task.delay(100, function()
				if not target.Parent then
					return
				end

				isVisible(false)
				task.delay(1.6, function()
					if target.Parent then
						isVisible(true)
					end
				end)
			end)
		end
	end)

	return function()
		destroyVide()
	end
end
