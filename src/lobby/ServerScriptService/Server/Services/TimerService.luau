local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local RaidSettings = require(ReplicatedStorage.Settings.Game.RaidSettings)
local Net = require(ReplicatedStorage.Shared.Net)

local KST_OFFSET = 9 * 3600

local TimerService = {}

local lastTargetTime = 0
local debugOverrideTime = nil

local TARGET_COMPONENTS_MAP = {}
local MAP = workspace:WaitForChild("MAP", 10)

local function findComponents(parent)
    for _, child in parent:GetDescendants() do
        for _, bossColors in pairs(RaidSettings.ComponentColors) do
            if bossColors[child.Name] then
                if not TARGET_COMPONENTS_MAP[child.Name] then
                    TARGET_COMPONENTS_MAP[child.Name] = {}
                end
                table.insert(TARGET_COMPONENTS_MAP[child.Name], child)
                break
            end
        end
    end
end

for _, child in MAP:GetDescendants() do
    if child.Name == "RaidPortal" or child.Name == "PortalArea" or child.Name == "PortalLantern" or child.Name == "PortalStone" or child.Name == "Portalfloor" or child.Name == "SmokeVFX" then
        findComponents(child)
    end
end

function TimerService.Init() end

function TimerService.ForceTimer(seconds)
	debugOverrideTime = os.time() + seconds
	ReplicatedStorage:SetAttribute("NextHourTimestamp", debugOverrideTime)
end

function TimerService.SelectRaidBoss()
	local totalWeight = 0
	for _, weight in pairs(RaidSettings.BossWeights) do
		totalWeight += weight
	end

	local randomValue = math.random() * totalWeight
	local currentWeight = 0
	local selectedBoss = nil

	for bossName, weight in pairs(RaidSettings.BossWeights) do
		currentWeight += weight
		if randomValue <= currentWeight then
			selectedBoss = bossName
			break
		end
	end

	if selectedBoss then
		print("새로운 레이드 보스: " .. selectedBoss)
        
        TimerService.TransitionPortalColor(selectedBoss, 3)

		Net.RaidService.RaidBossSpawned.FireAll({
			BossName = selectedBoss
		})
	end
end

function TimerService.ApplyColor(child, color)
    if child:IsA("ParticleEmitter") or child:IsA("Beam") then
        child.Color = ColorSequence.new(color)
    elseif child:IsA("Light") then
        child.Color = color
    elseif child:IsA("BasePart") then
        child.Color = color
    elseif child:IsA("Decal") or child:IsA("Texture") then
        child.Color3 = color
    end
end

function TimerService.GetStartColor(child)
    if child:IsA("ParticleEmitter") or child:IsA("Beam") then
        return child.Color.Keypoints[1].Value
    elseif child:IsA("Light") or child:IsA("BasePart") then
        return child.Color
    elseif child:IsA("Decal") or child:IsA("Texture") then
        return child.Color3
    end
    return nil
end

function TimerService.TransitionPortalColor(bossName, duration)
    local colorMap = RaidSettings.ComponentColors[bossName]
    if not colorMap then return end

    local steps = 30
    local interval = duration / steps

    local startColors = {}
    for name, instances in pairs(TARGET_COMPONENTS_MAP) do
        local targetColor = colorMap[name]
        if targetColor then
            for _, child in instances do
                startColors[child] = TimerService.GetStartColor(child)
            end
        end
    end

    task.spawn(function()
        for i = 1, steps do
            local alpha = i / steps
            local smoothAlpha = 0.5 - 0.5 * math.cos(alpha * math.pi)
            
            for child, startColor in pairs(startColors) do
                local targetColor = colorMap[child.Name]
                if targetColor and startColor then
                    TimerService.ApplyColor(child, startColor:Lerp(targetColor, smoothAlpha))
                end
            end
            task.wait(interval)
        end
    end)
end

function TimerService.Start()
	local function UpdateNextHour()
		local now = os.time()
		
		if debugOverrideTime then
			if now >= debugOverrideTime then
				debugOverrideTime = nil
				TimerService.SelectRaidBoss()
				
				local secondsPassedInHour = (now + KST_OFFSET) % 3600
				local nextHour = now + (3600 - secondsPassedInHour)
				lastTargetTime = nextHour
				ReplicatedStorage:SetAttribute("NextHourTimestamp", nextHour)
			end
			return
		end

		local secondsPassedInHour = (now + KST_OFFSET) % 3600
		local nextHour = now + (3600 - secondsPassedInHour)
		
		if nextHour ~= lastTargetTime then
			lastTargetTime = nextHour
			ReplicatedStorage:SetAttribute("NextHourTimestamp", nextHour)
			
			TimerService.SelectRaidBoss()
		end
	end

	UpdateNextHour()

	if RunService:IsStudio() then
		_G.ForceTimer = function(seconds)
			TimerService.ForceTimer(seconds)
		end

		local function onPlayerAdded(player)
			player.Chatted:Connect(function(message)
				if message:sub(1, 6) == "/timer" then
					local seconds = tonumber(message:sub(8)) or 10
					TimerService.ForceTimer(seconds)
				end
			end)
		end

		for _, player in Players:GetPlayers() do
			onPlayerAdded(player)
		end
		Players.PlayerAdded:Connect(onPlayerAdded)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			UpdateNextHour()
		end
	end)
end

return TimerService
