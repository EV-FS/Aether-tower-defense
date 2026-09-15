-- Shared modal motion used by lobby and in-game emote wheels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local spring = Vide.spring
local source = Vide.source
local effect = Vide.effect

export type Props = {
	Name: string,
	IsOpen: () -> boolean,
	OnClose: () -> (),
	Content: GuiObject,
}

return function(props: Props)
	local isMounted = source(false)
	local transition = 0

	effect(function()
		local isOpen = props.IsOpen()
		transition += 1
		local currentTransition = transition

		if isOpen then
			isMounted(true)
		else
			task.delay(0.48, function()
				if transition == currentTransition then
					isMounted(false)
				end
			end)
		end
	end)

	return create("Frame")({
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = isMounted,
		ZIndex = 20,

		create("TextButton")({
			Name = "Backdrop",
			Active = props.IsOpen,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(7, 12, 22),
			BackgroundTransparency = spring(function()
				return if props.IsOpen() then 0.35 else 1
			end, 0.2, 0.9),
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 20,
			Activated = props.OnClose,
		}),

		create("Frame")({
			Name = "Content",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				return if props.IsOpen() then 0 else -3
			end, 0.35, 0.8),
			Size = spring(function()
				return if props.IsOpen() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 0)
			end, 0.48, 0.78),
			ZIndex = 30,
			props.Content,
		}),
	})
end
