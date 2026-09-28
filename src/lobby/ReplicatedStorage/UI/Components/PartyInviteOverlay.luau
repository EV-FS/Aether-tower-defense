local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local source = Vide.source

local BUTTON_SIZE = Vector2.new(68, 68)
local REFERENCE_VIEWPORT = Vector2.new(1630, 800)
local MAX_CAMERA_DISTANCE = 250
local SLOT_NAMES = { "2", "3", "4" }
local nextOverlayId = 0

type RigAnchor = {
	Root: BasePart,
	Torso: BasePart?,
}

local function inviteButton(slotName: string, position, size, visible, onInvite: () -> ())
	return create("ImageButton")({
		Name = `Invite_{slotName}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Visible = visible,
		BackgroundTransparency = 1,
		Active = true,
		AutoButtonColor = false,
		Image = "rbxassetid://96374261144914",
		Activated = onInvite,
		useButtonEffect(0.93, 1.08),
		create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(16, 255, 16), Color3.fromRGB(230, 255, 10)), Rotation = 90 }),
		create("UIStroke")({ Color = Color3.new(1, 1, 1), Thickness = 1.5 }),
		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
		create("ImageLabel")({
			Name = "Deco",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
			BackgroundTransparency = 1,
			Image = "rbxassetid://107275506784451",
			ZIndex = 2,
		}),
	})
end

return function(actors: { [string]: RigAnchor }, onInvite: () -> (), shouldShow: () -> boolean)
	local positions = {}
	local visibility = {}
	local buttons = {}
	local lastPixels: { [string]: Vector2 } = {}
	local buttonSize = source(UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y))
	local lastScale = 1
	for _, slotName in SLOT_NAMES do
		positions[slotName] = source(UDim2.fromOffset(0, 0))
		visibility[slotName] = source(false)
		table.insert(buttons, inviteButton(slotName, positions[slotName], buttonSize, visibility[slotName], onInvite))
	end

	nextOverlayId += 1
	local renderStepName = `PartyInviteOverlay_{nextOverlayId}`
	local overlayGui: ScreenGui? = nil
	RunService:BindToRenderStep(renderStepName, Enum.RenderPriority.Camera.Value + 2, function()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		local show = shouldShow() and camera ~= nil and viewport ~= nil and viewport.X > 0 and viewport.Y > 0
		if overlayGui and overlayGui.Enabled ~= show then overlayGui.Enabled = show end
		local scale = if show then math.clamp(math.min(viewport.X / REFERENCE_VIEWPORT.X, viewport.Y / REFERENCE_VIEWPORT.Y), 0.65, 1.1) else lastScale
		if scale ~= lastScale then
			lastScale = scale
			buttonSize(UDim2.fromOffset(math.round(BUTTON_SIZE.X * scale), math.round(BUTTON_SIZE.Y * scale)))
		end
		for _, slotName in SLOT_NAMES do
			local actor = actors[slotName]
			local root = actor and actor.Root
			local isVisible = false
			if show and root and root.Parent and (root.Position - camera.CFrame.Position).Magnitude <= MAX_CAMERA_DISTANCE then
				-- Interface ignores the GUI inset, so viewport pixels map directly to UI pixels.
				-- The animated torso is the visible body center. The anchored root
				-- identifies the rig and is a fallback when no torso part exists.
				local torso = actor.Torso
				local anchor = if torso and torso.Parent then torso.Position else root.Position
				local point, onScreen = camera:WorldToViewportPoint(anchor)
				if onScreen and point.Z > 0 then
					local halfWidth = BUTTON_SIZE.X * scale * 0.5
					local halfHeight = BUTTON_SIZE.Y * scale * 0.5
					if point.X >= halfWidth and point.X <= viewport.X - halfWidth
						and point.Y >= halfHeight and point.Y <= viewport.Y - halfHeight then
						local pixel = Vector2.new(math.round(point.X), math.round(point.Y))
						if lastPixels[slotName] ~= pixel then
							lastPixels[slotName] = pixel
							positions[slotName](UDim2.fromOffset(pixel.X, pixel.Y))
						end
						isVisible = true
					end
				end
			end
			if visibility[slotName]() ~= isVisible then
				visibility[slotName](isVisible)
			end
		end
	end)
	Vide.cleanup(function()
		RunService:UnbindFromRenderStep(renderStepName)
		if overlayGui then overlayGui.Enabled = false end
	end)

	overlayGui = create("ScreenGui")({
		Name = "PartyInviteOverlay",
		DisplayOrder = 11,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		unpack(buttons),
	})
	return overlayGui
end
