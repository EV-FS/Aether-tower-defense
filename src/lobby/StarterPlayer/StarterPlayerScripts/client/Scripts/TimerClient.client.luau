local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local timerGui = playerGui:WaitForChild("TimerGUI", 10)
local textLabel = timerGui and timerGui:WaitForChild("TextLabel", 10)

if not textLabel then return end

local function UpdateTimer()
	local targetTime = ReplicatedStorage:GetAttribute("NextHourTimestamp")
	if not targetTime then 
		textLabel.Text = "--:--"
		return 
	end

	local remaining = targetTime - os.time()
	if remaining < 0 then remaining = 0 end

	local minutes = math.floor(remaining / 60)
	local seconds = remaining % 60
	textLabel.Text = string.format("%02d:%02d", minutes, seconds)
end

Net.RaidService.RaidBossSpawned.On(function(data)
	local textChannels = TextChatService:WaitForChild("TextChannels", 10)
	local generalChannel = textChannels and textChannels:WaitForChild("RBXGeneral", 10)
	
	if generalChannel then
		generalChannel:DisplaySystemMessage(string.format("<font color='#FF4B4B'><b>[레이드]</b></font> 강력한 보스 <font color='#FFDF3A'><b>%s</b></font>가 곧 출현합니다! 준비하세요!", data.BossName))
	end
end)

task.spawn(function()
	while true do
		UpdateTimer()
		task.wait(1)
	end
end)
