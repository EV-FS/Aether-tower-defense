local RunService = game:GetService("RunService")

local DEFAULT_FOV = 70
local SMOOTH_SPEED = 12

local FOVController = {}

local defaultFOV = DEFAULT_FOV
local targetFOV = DEFAULT_FOV
local renderConnection: RBXScriptConnection? = nil

function FOVController.SetFOV(fov: number, instant: boolean?)
	targetFOV = fov

	local camera = workspace.CurrentCamera
	if instant and camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.FieldOfView = fov
	end
end

function FOVController.ResetFOV(instant: boolean?)
	FOVController.SetFOV(defaultFOV, instant)
end

function FOVController.SetDefaultFOV(fov: number, apply: boolean?)
	defaultFOV = fov

	if apply then
		FOVController.SetFOV(fov)
	end
end

function FOVController.GetFOV(): number
	local camera = workspace.CurrentCamera
	return if camera then camera.FieldOfView else targetFOV
end

function FOVController.Start()
	if renderConnection then return end
	renderConnection = RunService.PreRender:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera or camera.CameraType == Enum.CameraType.Scriptable then
			return
		end

		local alpha = 1 - math.exp(-SMOOTH_SPEED * dt)
		camera.FieldOfView += (targetFOV - camera.FieldOfView) * alpha
	end)
end

--[[ Releases the controller's owned update connection. ]]
function FOVController.Destroy()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

return FOVController
