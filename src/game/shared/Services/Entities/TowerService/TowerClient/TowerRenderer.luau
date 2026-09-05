--/ Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/ Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local CreateRangeIndicator = require(ReplicatedStorage.Shared.Services.Entities.TowerService.Utils.CreateRangeIndicator)
local TimeService
local AnimationService
local VisualService

local GROUND_VISUAL_OFFSET = 0.05

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function SetAccessoryVisible(accessory, visible: boolean)
	local applyTrans = visible and 0 or 1
	local noDisplay = accessory:GetAttribute("NoDisplay")

	if accessory:IsA("BasePart") and not noDisplay then
		accessory.Transparency = applyTrans
	end
	if accessory:IsA("ParticleEmitter") and not noDisplay then
		accessory.Enabled = visible
	end

	for _, part in accessory:GetDescendants() do
		local partNoDisplay = part:GetAttribute("NoDisplay")
		if part:IsA("BasePart") and not partNoDisplay then
			part.Transparency = applyTrans
		end
		if part:IsA("ParticleEmitter") and not partNoDisplay then
			part.Enabled = visible
		end
	end
end

local function ResolveAttackSet(towerModel: Model, attackVariant: string?, towerLevel: number): (boolean, number?)
	local variant = attackVariant or ""
	local comboName = `{variant}AttackCombo1`
	local attackName = `{variant}Attack`

	for level = towerLevel, 0, -1 do
		if AnimationService.GetExactTrack(towerModel, comboName, level) then
			return true, level
		end

		if AnimationService.GetExactTrack(towerModel, attackName, level) then
			return false, level
		end
	end

	return AnimationService.GetExactTrack(towerModel, comboName) ~= nil, nil
end

local function GetMaxCombo(renderData, towerModel, attackVariant: string?, stats, comboLevel: number?): number
	local maxComboKey = `MaxCombo_{attackVariant or "Default"}`
	local maxCombo = renderData[maxComboKey]
	if not maxCombo then
		maxCombo = stats.ComboCount
		if not maxCombo then
			maxCombo = 0
			while true do
				local checkName = `{attackVariant or ""}AttackCombo{maxCombo + 1}`
				if AnimationService.GetExactTrack(towerModel, checkName, comboLevel) then
					maxCombo += 1
				else
					break
				end
			end
			maxCombo = math.max(1, maxCombo)
		end
		renderData[maxComboKey] = maxCombo
	end
	return maxCombo
end

-------------------------------------------------
--// TowerRenderer
-------------------------------------------------
local TowerRenderer = {}
TowerRenderer.RenderStates = {}
TowerRenderer.PlacedBorders = {}
TowerRenderer.TrackingTowers = {}
TowerRenderer.SelectionHighlight = nil
TowerRenderer.CurrentRange = nil

function TowerRenderer.Init(services)
	AnimationService = services:GetService("AnimationService")
	VisualService = services:GetService("VisualService")
	TimeService = services:GetService("TimeService")
end

function TowerRenderer.Start()
	RunService.PreRender:Connect(function(dt)
		if next(TowerRenderer.TrackingTowers) == nil and not TowerRenderer.CurrentRange then
			return
		end

		for towerId, data in pairs(TowerRenderer.TrackingTowers) do
			data.RemainingTime -= dt * TimeService:GetGameSpeed()

			if
				data.RemainingTime <= 0
				or not data.TowerModel.Parent
				or not data.TargetPart.Parent
				or data.TargetPart:GetAttribute("Dead")
			then
				TowerRenderer.TrackingTowers[towerId] = nil
				continue
			end

			TowerRenderer.LookAt(data.TowerModel, data.TargetPart.Position)
		end

		if TowerRenderer.CurrentRange and TowerRenderer.CurrentRangeTowerId then
			local towerId = TowerRenderer.CurrentRangeTowerId
			local targetTower = TowerRenderer.RenderStates[towerId]
			if targetTower then
				local trackingData = TowerRenderer.TrackingTowers[towerId]
				local targetPos = trackingData and trackingData.TargetPart and trackingData.TargetPart.Position

				local offset = CharacterUtils.GetHipHeight(targetTower.Model)
				local towerCenter = targetTower.Model:GetPivot().Position
				TowerRenderer.CurrentRange:UpdateRange(
					targetTower.Model:GetPivot() - Vector3.new(0, offset, 0),
					targetPos,
					towerCenter
				)
			end
		end
	end)
end

function TowerRenderer.Setup(towerId: number, towerModel: Model, towerName: string, borderData)
	towerModel:SetAttribute("Id", towerId)
	towerModel:SetAttribute("TowerName", towerName)
	CollectionService:AddTag(towerModel, "Tower")

	CharacterUtils.SetCollisionGroup(towerModel, "Tower", function(part)
		part.CanCollide = false
		part.CanTouch = false
	end)
	towerModel.Parent = workspace.Towers

	AnimationService.Load(towerModel, towerName)

	if AnimationService.GetTrack(towerModel, "OnSpawn") then
		AnimationService.PlayOnce(towerModel, "OnSpawn", { Resume = "Idle" })
	else
		AnimationService.Play(towerModel, "Idle", 0, 0)
	end

	local towerInfo = TowerData.ByName[towerName]
	local towerRarity = towerInfo and towerInfo.Rarity
	if towerRarity then
		VisualService.Play("TowerShared", `Place_{towerRarity}`, nil, towerModel)
	end

	TowerRenderer.RenderStates[towerId] = {
		Accessories = {},
		RangeIndicator = nil,
		Model = towerModel,
		Name = towerName,
		Level = 0,
	}

	TowerRenderer.ApplyAppearence(0, towerId)
	TowerRenderer.AddBorder(towerId, borderData)

	if VisualService then
		VisualService.Play(towerName, "OnSpawn", 0, towerModel, towerModel)
	end
end

function TowerRenderer.UpgradeVisuals(towerLevel: number, towerId: number)
	local targetTower = TowerRenderer.RenderStates[towerId]
	if not targetTower then
		return
	end

	local towerInfo = TowerData.ByName[targetTower.Name]
	local towerRarity = towerInfo and towerInfo.Rarity
	if towerRarity then
		VisualService.Play("TowerShared", `Upgrade_{towerRarity}`, nil, targetTower.Model)
	end

	TowerRenderer.ApplyAppearence(towerLevel, towerId)
end

function TowerRenderer.SellVisuals(towerId: number)
	local targetTower = TowerRenderer.RenderStates[towerId]
	if not targetTower then
		return
	end

	VisualService.Play("TowerShared", `Sell`, nil, targetTower.Model)
end

function TowerRenderer.ApplyAppearence(towerLevel: number, towerId: number)
	local targetTower = TowerRenderer.RenderStates[towerId]
	if not targetTower then
		return
	end

	targetTower.Level = towerLevel

	for key in pairs(targetTower) do
		if string.match(key, "^MaxCombo_") or string.match(key, "^ComboIndex_") then
			targetTower[key] = nil
		end
	end
	local levelFolder = targetTower.Model:WaitForChild("Upgrades"):FindFirstChild(tostring(towerLevel))
	if not levelFolder then
		warn(`{towerLevel}레벨에 해당하는 외형이 존재하지 않음.`)
		return
	end

	local removeTargets = levelFolder:GetAttribute("Remove")
	if removeTargets then
		for targetName in string.gmatch(removeTargets, "[^,]+") do
			targetName = targetName:match("^%s*(.-)%s*$")
			if targetName == "" then
				continue
			end

			local targetAccessory = targetTower.Accessories[targetName]
			if targetAccessory then
				SetAccessoryVisible(targetAccessory, false)
			end
		end
	end

	for _, newAccessory in ipairs(levelFolder:GetChildren()) do
		SetAccessoryVisible(newAccessory, true)
		targetTower.Accessories[newAccessory.Name] = newAccessory
	end
end

function TowerRenderer.ToggleRangeIndicator(action: boolean, towerId: number?, towerData)
	local targetTower = TowerRenderer.RenderStates[towerId]

	if TowerRenderer.CurrentRange then
		TowerRenderer.CurrentRange:Destroy()
		TowerRenderer.CurrentRange = nil
		TowerRenderer.CurrentRangeTowerId = nil
	end

	if TowerRenderer.SelectionHighlight then
		TowerRenderer.SelectionHighlight.Adornee = nil
	end

	if action == false then
		return
	end

	if not TowerRenderer.SelectionHighlight then
		TowerRenderer.SelectionHighlight = Instance.new("Highlight")
		TowerRenderer.SelectionHighlight.Name = "TowerSelectionHighlight"
		TowerRenderer.SelectionHighlight.FillTransparency = 0.8
		TowerRenderer.SelectionHighlight.OutlineTransparency = 0.2
		TowerRenderer.SelectionHighlight.FillColor = Color3.fromRGB(255, 255, 255)
		TowerRenderer.SelectionHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		TowerRenderer.SelectionHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		TowerRenderer.SelectionHighlight.Parent = workspace:FindFirstChild("Visuals") or workspace
	end

	if targetTower and targetTower.Model then
		TowerRenderer.SelectionHighlight.Adornee = targetTower.Model
	end

	local offset = CharacterUtils.GetHipHeight(targetTower.Model)
	TowerRenderer.CurrentRange = CreateRangeIndicator.newRange(
		towerData.Stats.Range,
		targetTower.Model:GetPivot() - Vector3.new(0, offset, 0),
		towerData.Stats,
		targetTower.Model:GetPivot().Position
	)
	TowerRenderer.CurrentRangeTowerId = towerId

	if TowerRenderer.CurrentRange then
		TowerRenderer.CurrentRange:SetColor(Color3.new(1, 1, 1))
	end
end

function TowerRenderer.AddBorder(towerId: number, borderData)
	local targetTower = TowerRenderer.RenderStates[towerId]

	local border = ReplicatedStorage.Assets.Visuals.Border:Clone()
	border.Name = "Border_" .. tostring(towerId)
	border.Size = Vector3.new(0.001, borderData.r * 2.5, borderData.r * 2.5)

	local offset = CharacterUtils.GetHipHeight(targetTower.Model) - GROUND_VISUAL_OFFSET
	border.Position = Vector3.new(borderData.x, targetTower.Model:GetPivot().Y - offset, borderData.z)

	border.Parent = workspace.Visuals.Borders

	if border:FindFirstChild("SurfaceGui") then
		border.SurfaceGui.ImageLabel.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
		border.SurfaceGui.ImageLabel.BackgroundTransparency = 0.8
		border.SurfaceGui.ImageLabel.ImageTransparency = 1
		border.SurfaceGui.ImageLabel.UIStroke.Color = Color3.new(1, 0.2, 0.2)
		border.SurfaceGui.Enabled = false
	end

	TowerRenderer.PlacedBorders[towerId] = border
end

function TowerRenderer.LookAt(towerModel: Model, targetPosition: Vector3)
	if not towerModel or not targetPosition then
		return
	end

	local towerPivot = towerModel:GetPivot()
	local lookTarget = Vector3.new(targetPosition.X, towerPivot.Position.Y, targetPosition.Z)

	towerModel:PivotTo(CFrame.lookAt(towerPivot.Position, lookTarget))
end

function TowerRenderer.OnPassiveTriggered(towerId: number, passiveType: string, arg: { [string]: any }?)
	local targetTower = TowerRenderer.RenderStates[towerId]
	if not targetTower then
		return
	end

	local towerModel = targetTower.Model
	local eventName = `Passive{passiveType}`
	local targetModel = if typeof(arg) == "table" and arg.EnemyId
		then workspace.Enemies:FindFirstChild(`Enemy_{arg.EnemyId}`)
		else nil

	VisualService.Play(targetTower.Name, eventName, targetTower.Level, towerModel, targetModel)
end

function TowerRenderer.OnAttack(towerId: number, enemyModel: Model, stats, attackVariant: string?)
	local renderData = TowerRenderer.RenderStates[towerId]
	if not (renderData and enemyModel and enemyModel.PrimaryPart) then
		return
	end

	local towerModel = renderData.Model
	local targetPart = enemyModel.PrimaryPart
	local hits = stats.Hits
	local hasHitConfig = hits and #hits > 0
	local attackEndDelay = stats.AttackDelay or 0

	if hasHitConfig then
		attackEndDelay = 0
		for _, hit in hits do
			attackEndDelay = math.max(attackEndDelay, hit.Delay or 0)
		end
	end

	local variant = attackVariant or ""
	local usesCombo, comboLevel = ResolveAttackSet(towerModel, attackVariant, renderData.Level)
	local animName = `{variant}Attack`
	local comboIndex: number?
	local comboIndexKey = `ComboIndex_{attackVariant or "Default"}`

	if usesCombo then
		local maxCombo = GetMaxCombo(renderData, towerModel, attackVariant, stats, comboLevel)
		comboIndex = (renderData[comboIndexKey] or 0) % maxCombo + 1
		renderData[comboIndexKey] = comboIndex
		animName = `{variant}AttackCombo{comboIndex}`
	else
		renderData[comboIndexKey] = nil
	end

	AnimationService.PlayOnce(towerModel, animName, {
		Level = renderData.Level,
		Resume = "Idle",
	})

	local comboEventPrefix = if comboIndex then `{variant}AttackCombo{comboIndex}` else nil
	local function playAttackVisual(eventSuffix: string, range: number?, delay: number?)
		local fallbackEventName = `{variant}Attack{eventSuffix}`
		local eventName = if comboEventPrefix then `{comboEventPrefix}{eventSuffix}` else fallbackEventName

		VisualService.Play(
			renderData.Name,
			eventName,
			renderData.Level,
			towerModel,
			enemyModel,
			range,
			delay,
			if comboEventPrefix then fallbackEventName else nil
		)
	end

	playAttackVisual("Start", stats.Range)

	if hasHitConfig then
		for hitIndex, hit in hits do
			local hitDelay = hit.Delay or 0
			local visualDelay = if hitDelay > 0 then hitDelay else nil
			local hitRange = hit.Range or stats.Range

			playAttackVisual("Hit", hitRange, visualDelay)
			playAttackVisual(`Hit{hitIndex}`, hitRange, visualDelay)
		end
	end

	playAttackVisual("End", stats.Range, if attackEndDelay > 0 then attackEndDelay else nil)

	if not targetPart:GetAttribute("Dead") then
		TowerRenderer.LookAt(towerModel, targetPart.Position)
		TowerRenderer.TrackingTowers[towerId] = {
			TowerModel = towerModel,
			TargetPart = targetPart,
			RemainingTime = attackEndDelay,
		}
	end
end

function TowerRenderer.Cleanup(towerId: number)
	local renderData = TowerRenderer.RenderStates[towerId]
	AnimationService.Clear(renderData.Model)

	if renderData and renderData.Model then
		renderData.Model:Destroy()
	end

	if TowerRenderer.PlacedBorders[towerId] then
		TowerRenderer.PlacedBorders[towerId]:Destroy()
		TowerRenderer.PlacedBorders[towerId] = nil
	end
	if TowerRenderer.CurrentRange then
		TowerRenderer.CurrentRange:Destroy()
		TowerRenderer.CurrentRange = nil
	end
	TowerRenderer.CurrentRangeTowerId = nil

	TowerRenderer.RenderStates[towerId] = nil
	TowerRenderer.TrackingTowers[towerId] = nil
end

return TowerRenderer
