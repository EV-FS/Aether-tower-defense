local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)

local OFFSET = 5

local HoverTracker = {}
HoverTracker.viewUIRef = nil
local hoverConn = nil

function HoverTracker.Start(entry)
	State.HoveredTower(entry)

	if hoverConn then
		hoverConn:Disconnect()
	end

	hoverConn = RunService.RenderStepped:Connect(function()
		if not HoverTracker.viewUIRef then
			return
		end

		local mousePos = UserInputService:GetMouseLocation()
		local viewSize = HoverTracker.viewUIRef.AbsoluteSize
		local viewportSize = workspace.CurrentCamera.ViewportSize

		local posX = math.clamp(mousePos.X + OFFSET, 0, viewportSize.X - viewSize.X)
		local posY = math.clamp(mousePos.Y + OFFSET, 0, viewportSize.Y - viewSize.Y)

		local parent = HoverTracker.viewUIRef.Parent
		if parent and parent:IsA("GuiObject") then
			local offset = Vector2.new(parent.AbsolutePosition.X, parent.AbsolutePosition.Y * 1.2)
			HoverTracker.viewUIRef.Position = UDim2.fromOffset(posX - offset.X, posY - offset.Y)
		else
			HoverTracker.viewUIRef.Position = UDim2.fromOffset(posX, posY)
		end
	end)
end

function HoverTracker.Stop()
	if hoverConn then
		hoverConn:Disconnect()
		hoverConn = nil
	end
	State.HoveredTower(nil)
end

return HoverTracker
