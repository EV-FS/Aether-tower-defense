--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

--/UI Variables
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hoverGui = ReplicatedStorage.Assets.Visuals:WaitForChild("StatsGui")

--/Variables
local TowerHovered = {}
local renderConnection = nil

local currentGui

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function updateHoverUI(towerData)
	if not currentGui then
		return
	end

	local towerConfig = TowerData.ByName[towerData.Name]
	local currentStats = towerData.Stats
	local ownerName = towerData.Owner and towerData.Owner.DisplayName or "Unknown"

	local canvas = currentGui.Canvas

	canvas.Main.TowerName.TowerName.Text = `{towerData.Name} <font color="#aaaaaa">[{ownerName}]</font>`
	canvas.Main.Level.Level.Text = `Lv.{towerData.Level}`

	if currentStats.Damage then
		canvas.Stats.Damage.TextLabel.Text = `{NumberUtils.Abbreviate(currentStats.Damage, 2)}`
	end

	if currentStats.Range then
		canvas.Stats.Range.TextLabel.Text = `{NumberUtils.Abbreviate(currentStats.Range, 2)}`
	end

	if currentStats.Cooldown then
		canvas.Stats.Cooldown.TextLabel.Text = `{NumberUtils.Abbreviate(currentStats.Cooldown, 2)}`
	end

	canvas.TowerImage.Image = towerConfig.TowerImage
end

-------------------------------------------------
--// TowerHovered
-------------------------------------------------
function TowerHovered.OnHovered(towerModel: Model, towerData)
	TowerHovered.OnUnhovered()

	currentGui = hoverGui:Clone() :: BillboardGui
	currentGui.Adornee = towerModel.PrimaryPart
	currentGui.StudsOffset = Vector3.new(0, CharacterUtils.GetHipHeight(towerModel), 0)

	currentGui.Enabled = true
	currentGui.Parent = PlayerGui:WaitForChild("Billboard")

	if renderConnection then
		renderConnection:Disconnect()
	end

	updateHoverUI(towerData)
end

function TowerHovered.OnUnhovered(_: Model?)
	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

function TowerHovered.Init() end

function TowerHovered.Start()
	ClientSignals.TowerHovered:Connect(TowerHovered.OnHovered)
	ClientSignals.TowerUnhovered:Connect(TowerHovered.OnUnhovered)
end

return TowerHovered
