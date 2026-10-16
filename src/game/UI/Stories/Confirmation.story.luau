local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ConfirmationService = require(ReplicatedStorage.Shared.Services.System.ConfirmationService)
local ConfirmationUI = require(ReplicatedStorage.UI.Views.Game.ConfirmationUI)

return function(target)
	local prompts = ConfirmationService.new()
	local destroy = Vide.root(function()
		ConfirmationUI.RenderUI(prompts).Parent = target
	end)

	prompts:Prompt({
		Title = "Return To Lobby",
		Text = "Are you sure to go back to lobby?",

		AcceptText = "Return",
		AcceptColor = Color3.fromRGB(255, 80, 80),

		OnAccept = function()
			print("a")
		end,
	})

	local destroyed = false
	return function()
		if destroyed then
			return
		end
		destroyed = true
		destroy()
	end
end
