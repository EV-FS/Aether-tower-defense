local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local Net = require(ReplicatedStorage.Shared.Net)

local TimerTextLabel
local ShadowLabel

local function GetTimerLabels()
	local map = Workspace:FindFirstChild("MAP")
	local overheadPart = map and map:FindFirstChild("OverheadPart")
	local attachment = overheadPart and overheadPart:FindFirstChild("Attachment")
	local overheadUI = attachment and attachment:FindFirstChild("OverheadUI")
	local holderFrame = overheadUI and overheadUI:FindFirstChild("HolderFrame")
	local raidBossTimer = holderFrame and holderFrame:FindFirstChild("RaidBossTimer")

	TimerTextLabel = raidBossTimer and raidBossTimer:FindFirstChild("TimerText")
	ShadowLabel = raidBossTimer and raidBossTimer:FindFirstChild("Shadow")
end

GetTimerLabels()

local function UpdateTimer()
	local targetTime = ReplicatedStorage:GetAttribute("NextHourTimestamp")
	if not targetTime then 
		if TimerTextLabel then TimerTextLabel.Text = "--:--" end
		if ShadowLabel then ShadowLabel.Text = "--:--" end
		return 
	end

	local remaining = targetTime - os.time()
	if remaining < 0 then remaining = 0 end

	local minutes = math.floor(remaining / 60)
	local seconds = remaining % 60
	local formattedTime = string.format("%02d:%02d", minutes, seconds)
	
	if TimerTextLabel then TimerTextLabel.Text = formattedTime end
	if ShadowLabel then ShadowLabel.Text = formattedTime end
end

ReplicatedStorage:GetAttributeChangedSignal("NextHourTimestamp"):Connect(UpdateTimer)

Net.RaidService.RaidBossSpawned.On(function(data)
	local textChannels = TextChatService:WaitForChild("TextChannels", 10)
	local generalChannel = textChannels and textChannels:WaitForChild("RBXGeneral", 10)
	
	if generalChannel then
		generalChannel:DisplaySystemMessage(string.format("<font color='#FF4B4B'><b>[레이드]</b></font> 강력한 보스 <font color='#FFDF3A'><b>%s</b></font>가 곧 출현합니다! 준비하세요!", data.BossName))
	end
end)

UpdateTimer()

task.spawn(function()
	while true do
		UpdateTimer()
		task.wait(1)
	end
end)
