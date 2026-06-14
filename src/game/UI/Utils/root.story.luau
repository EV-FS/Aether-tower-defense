local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CashFrame = require(ReplicatedStorage.UI.Features.HUD.Cash.Components.CashFrame)

local source = Vide.source
local spring = Vide.spring
local mount = Vide.mount

return function(target)
	local testContainer = Instance.new("Frame")
	testContainer.Size = UDim2.fromScale(1, 1)
	testContainer.Position = UDim2.fromScale(0.5, 0.5)
	testContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	testContainer.BackgroundTransparency = 1
	testContainer.Parent = target

	local mockCash = source(1000)

	local destroyVide = mount(function()
		return CashFrame({
			Cash = spring(mockCash, 0.175, 1),
		})
	end, testContainer)

	local thread = task.spawn(function()
		while true do
			task.wait(1)
			mockCash(mockCash() + 1000)
		end
	end)

	return function()
		task.cancel(thread)
		destroyVide()
		testContainer:Destroy()
	end
end
