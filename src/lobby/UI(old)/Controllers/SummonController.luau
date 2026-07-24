local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local SummonGui = player:WaitForChild("PlayerGui"):WaitForChild("SummonGui")
local SummonFrame = SummonGui:WaitForChild("Summon")
local ListFrame = SummonGui:WaitForChild("ListFrame")

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SUMMON_TOUCH: BasePart = workspace:WaitForChild("TouchZone"):WaitForChild("SummonTouch")

local zone

local SummonController = {
	CurrentBanner = nil,
	IsSummoning = false,
	ActiveFrames = {},
}

function SummonController.ClearPopups()
	for _, frame in SummonController.ActiveFrames do
		if frame then
			frame:Destroy()
		end
	end
	table.clear(SummonController.ActiveFrames)
end

function SummonController.DoSummon(amount)
	if SummonController.IsSummoning or (amount ~= 1 and amount ~= 10) then
		return
	end

	SummonController.IsSummoning = true
	SummonController.ClearPopups()

	local data = Net.SummonService.DoSummon.Invoke(amount):expect()
	if data.Success and data.PulledUnits then
		SummonController.ShowSummonedTowers(data.PulledUnits, amount)
	else
		warn("뽑기 요청이 실패함.")
		SummonController.IsSummoning = false
	end
end

function SummonController.ShowSummonedTowers(pulledUnits, amount)
	local scale = amount == 1 and 0.35 or 0.16
	local currentDelay = 0

	ListFrame.Visible = true

	for _, towerName in pulledUnits do
		local currentData = TowerData.ByName[towerName]
		if not currentData then
			warn(`{towerName}의 데이터가 존재하지 않음`)
			continue
		end

		local frame = ListFrame.Template:Clone()
		frame.Size = UDim2.fromScale(scale * 0.85, scale * 0.85)
		frame.TowerImage.Image = currentData.TowerImage
		frame.Rarity.Text = currentData.Rarity
		frame.Outline.Color = RarityColor[currentData.Rarity]
		frame.TowerName.Text = towerName

		frame.Name = towerName
		frame.Visible = true

		table.insert(SummonController.ActiveFrames, frame)

		task.delay(currentDelay, function()
			frame.Parent = ListFrame

			local tween = TweenService:Create(frame, TWEEN_INFO, { Size = UDim2.fromScale(scale * 1, scale * 1) })
			tween:Play()
		end)

		currentDelay += 0.065
	end

	UIController:CloseAll()

	task.delay(2, function()
		SummonController.ClearPopups()
		ListFrame.Visible = false
		SummonController.IsSummoning = false

		if zone:IsTouching(player) then
			UIController:Open("Summon")
		end
	end)
end

function SummonController.UpdateBanner(bannerData)
	if not bannerData or type(bannerData.Units) ~= "table" then
		warn(`bannerData의 타입에 오류가 존재함.`)
		return
	end
	SummonController.CurrentBanner = bannerData

	for rarity, data in pairs(bannerData.Units) do
		local rarityFrame = SummonFrame.ChanceList:FindFirstChild(rarity)
		local currentData = TowerData.ByName[data.Name]

		if rarityFrame and currentData then
			rarityFrame.UnitImage.Image = currentData.TowerImage
			rarityFrame.UnitName.Text = data.Name
			rarityFrame.TextLabel.Text = data.RateText
		end

		local mainRairtyFrame = SummonFrame.MainTowers.Frame:FindFirstChild(rarity)
		if mainRairtyFrame then
			mainRairtyFrame:WaitForChild("Title").Text = data.Name
			mainRairtyFrame:WaitForChild("Shadow").Text = data.Name
		end
	end
end

function SummonController.Init(controllers)
	UIController = controllers.UIController

	SummonFrame["1Summon"].MouseButton1Click:Connect(function()
		SummonController.DoSummon(1)
	end)
	SummonFrame["10Summon"].MouseButton1Click:Connect(function()
		SummonController.DoSummon(10)
	end)
	SummonFrame.Info.MouseButton1Click:Connect(function()
		SummonFrame.MainTowers.Visible = not SummonFrame.MainTowers.Visible
		SummonFrame.ChanceList.Visible = not SummonFrame.ChanceList.Visible
	end)

	local function handleTouch(_, targetState: boolean)
		if SummonFrame.Visible == targetState then
			return
		end

		if targetState then
			UIController:Open("Summon")
		else
			UIController:Close("Summon")
		end
	end

	zone = TouchZone.new(SUMMON_TOUCH)
	zone:Start()

	zone.Touched:Connect(function(plr)
		if player == plr then
			handleTouch(plr, true)
		end
	end)
	zone.TouchEnded:Connect(function(plr)
		if player == plr then
			handleTouch(plr, false)
		end
	end)

	task.spawn(function()
		local success, bannerData = Net.SummonService.GetBanner.Invoke():await()
		if success then
			SummonController.UpdateBanner(bannerData)
		end
	end)

	Net.SummonService.BannerUpdated.On(SummonController.UpdateBanner)
end

return SummonController
