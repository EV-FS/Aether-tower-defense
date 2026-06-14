--/ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

--/ Modules
local TimeService
local AnimationService
local VisualService

-------------------------------------------------
--// UnitRenderer
-------------------------------------------------
local UnitRenderer = {}
UnitRenderer.TrackingUnits = {} -- { [unitId]: { UnitModel, TargetPart, EndTime } }

function UnitRenderer.Init(services)
	AnimationService = services:GetService("AnimationService")
	VisualService = services:GetService("VisualService")
end

function UnitRenderer.Start()
	RunService.PreRender:Connect(function()
		if next(UnitRenderer.TrackingUnits) == nil then
			return
		end

		local now = os.clock()
		for unitId, data in pairs(UnitRenderer.TrackingUnits) do
			if
				now > data.EndTime
				or not data.UnitModel.Parent
				or not data.TargetPart.Parent
				or data.TargetPart:GetAttribute("Dead")
			then
				UnitRenderer.TrackingUnits[unitId] = nil
				continue
			end

			UnitRenderer.LookAt(data.UnitModel, data.TargetPart.Position)
		end
	end)
end

function UnitRenderer.LookAt(unitModel: Model, targetPosition: Vector3)
	if not unitModel or not targetPosition then
		return
	end

	local unitPivot = unitModel:GetPivot()
	local lookTarget = Vector3.new(targetPosition.X, unitPivot.Position.Y, targetPosition.Z)

	unitModel:PivotTo(CFrame.lookAt(unitPivot.Position, lookTarget))
end

function UnitRenderer.OnAttack(
	unitId: number,
	unitModel: Model,
	unitName: string,
	enemyModel: Model,
	stats,
	attackVariant: string?
)
	if not (unitModel and enemyModel and enemyModel.PrimaryPart) then
		return
	end

	local targetPart = enemyModel.PrimaryPart
	local attackDelay = stats.AttackDelay or 0

	local variant = attackVariant or ""

	AnimationService.Play(unitModel, `{variant}Attack`)

	VisualService.Play(unitName, `{variant}AttackStart`, 0, unitModel, enemyModel, stats.Range)
	VisualService.Play(unitName, `{variant}AttackEnd`, 0, unitModel, enemyModel, stats.Range, attackDelay)

	if not targetPart:GetAttribute("Dead") then
		UnitRenderer.LookAt(unitModel, targetPart.Position)
		UnitRenderer.TrackingUnits[unitId] = {
			UnitModel = unitModel,
			TargetPart = targetPart,
			EndTime = os.clock() + attackDelay,
		}
	end
end

function UnitRenderer.Cleanup(unitId: number, unitModel: Model?)
	if unitModel then
		AnimationService.Clear(unitModel)
	end
	UnitRenderer.TrackingUnits[unitId] = nil
end

return UnitRenderer
