local RunService = game:GetService("RunService")

local DEFAULT_FOV = 70
local SMOOTH_SPEED = 12

local FOVController = {}

local defaultFOV = DEFAULT_FOV
local targetFOV = DEFAULT_FOV

function FOVController.SetFOV(fov: number, instant: boolean?)
	targetFOV = fov

	if instant then
		workspace.CurrentCamera.FieldOfView = fov
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
	return workspace.CurrentCamera.FieldOfView
end

function FOVController.Start()
	RunService.PreRender:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local alpha = 1 - math.exp(-SMOOTH_SPEED * dt)
		camera.FieldOfView += (targetFOV - camera.FieldOfView) * alpha
	end)
end

return FOVController
