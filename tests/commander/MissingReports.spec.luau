
local now = 0
local os = { clock = function() return now end }
local function signal()
    local callbacks = {}
    return {
        Connect = function(self, fn)
            callbacks[fn] = true
            return { Disconnect = function() callbacks[fn] = nil end }
        end,
        Fire = function(self, ...)
            local snapshot = {}
            for fn in callbacks do table.insert(snapshot, fn) end
            for _, fn in snapshot do if callbacks[fn] then fn(...) end end
        end,
        Count = function() local n = 0 for _ in callbacks do n += 1 end return n end,
    }
end
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local UDim2 = { fromScale = function(x, y) return { x, y } end }
local utf8 = { graphemes = function(text) return string.gmatch(text, ".") end }
local Vide = { source = function(initial)
    local value = initial
    return function(...)
        if select("#", ...) > 0 then value = ... end
        return value
    end
end }
local ChapterData = (function()
--[[CHAPTER_DATA]]
end)()
local DialogueData = { CharactersPerSecond = 30, Presentation = { AccentColor = Color3.fromRGB(231, 193, 114) } }
local ClientSignals = {}
for _, name in { "WaveStarted", "WaveCompleted", "BossSpawned", "GameEnding", "Restarted", "TowerSelected", "TowerUnselected" } do
    ClientSignals[name] = signal()
end
local rig = { Archivable = true, IsA = function(self, name) return name == "Model" end }
local npcs = { WaitForChild = function() return rig end }
local assets = { WaitForChild = function() return npcs end }
local mapName = "Chapter 1"
local difficulty = "Normal"
local cutscene = nil
local ReplicatedStorage = {
    Packages = { Vide = Vide },
    Settings = { Data = { CommanderDialogueData = DialogueData, CommanderChapterData = ChapterData, MapData = {
        ["Chapter 1"] = { DifficultyWaves = { Normal = 20, Hard = 30, Eternal = 40 } },
    } } },
    Shared = { Modules = { UI = { MenuMotion = { ExitDuration = 0.3 } } } },
    ChildAdded = signal(), ChildRemoved = signal(),
    GetAttribute = function(self, name) return if name == "SelectedMap" then mapName else difficulty end,
    FindFirstChild = function() return cutscene end,
    WaitForChild = function() return assets end,
}
local StarterPlayer = { StarterPlayerScripts = { Client = { ClientSignals = ClientSignals } } }
local RunService = { Heartbeat = signal() }
local GameClient = { IsGameStarted = false, CurrentWave = 0, SelectedDifficulty = "Normal" }
local activeView = nil
local UIController = { GetActiveView = function() return activeView end }
local script = { Parent = { GameClient = GameClient, UIController = UIController } }
local services = { ReplicatedStorage = ReplicatedStorage, RunService = RunService, StarterPlayer = StarterPlayer }
local game = { GetService = function(self, name) return services[name] end }
local require = function(value) return value end
local deferred = {}
local task = {
    defer = function(fn)
        local thread = coroutine.create(fn)
        table.insert(deferred, thread)
        return thread
    end,
    cancel = function(thread) coroutine.close(thread) end,
}
local function flush()
    for _, thread in deferred do
        if coroutine.status(thread) ~= "dead" then assert(coroutine.resume(thread)) end
    end
    table.clear(deferred)
end
local function step(seconds)
    local count = math.ceil(seconds / 0.05)
    for _ = 1, count do
        now += 0.05
        RunService.Heartbeat:Fire(0.05)
    end
end
local function loadClient()
--[[COMMANDER_CLIENT]]

end
local TowerClient = { PendingStats = {}, PendingStuns = {}, ActiveTowers = {}, PlacedTowers = {} }
local selectedTowerId = nil
local stunnedTowers = {}
local hoveredTowerModel = nil
local TowerRenderer = { SellVisuals = function() end, Cleanup = function() end }
local PlaceValidator = { RemoveBorder = function() end }
ClientSignals.TowerDestroyed = signal()
--[[TOWER_REMOVE]]

local function startCombat()
    activeView = nil
    difficulty = "Eternal"
    GameClient.IsGameStarted = false
    GameClient.CurrentWave = 0
    local client = loadClient()
    client.Start()
    flush()
    ClientSignals.WaveStarted:Fire(1)
    step(0.1)
    client.Dismiss()
    step(0.5)
    return client
end

local cases = {
    { "wave numbers remain independent when copied entries share an id", function()
        local originalId = ChapterData.Waves[6].Id
        ChapterData.Waves[6].Id = ChapterData.Waves[3].Id
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(3)
        step(0.1)
        assert(client.Caption() == ChapterData.Waves[3].Caption and client.IsVisible())
        client.Dismiss()
        step(0.5)
        ClientSignals.WaveStarted:Fire(6)
        step(0.1)
        assert(client.Caption() == ChapterData.Waves[6].Caption and client.IsVisible())
        client.Destroy()
        ChapterData.Waves[6].Id = originalId
    end },
    { "boss warnings bypass tower selection and repeat on later boss waves", function()
        local client = startCombat()
        ClientSignals.TowerSelected:Fire(7)
        ClientSignals.WaveStarted:Fire(3)
        step(0.5)
        assert(not client.IsVisible(), "routine advice still waits for tower selection")
        ClientSignals.BossSpawned:Fire({ Id = 100 })
        step(0.5)
        assert(client.IsVisible() and client.IsDanger() and client.Caption() == ChapterData.BossContact.Caption)
        client.Dismiss()
        ClientSignals.BossSpawned:Fire({ Id = 101 })
        step(0.5)
        assert(not client.IsVisible(), "bosses in the same wave must not spam warnings")
        ClientSignals.WaveStarted:Fire(4)
        ClientSignals.BossSpawned:Fire({ Id = 102 })
        step(0.5)
        assert(client.IsVisible() and client.IsDanger(), "a later boss wave must warn again")
        ClientSignals.GameEnding:Fire(false)
        assert(not client.IsOpen() and not client.IsDanger())
        client.Destroy()
    end },
    { "boss warnings wait through cutscenes without expiring", function()
        local client = startCombat()
        cutscene = { Name = "ActiveCutscene" }
        ReplicatedStorage.ChildAdded:Fire(cutscene)
        ClientSignals.BossSpawned:Fire({ Id = 200 })
        step(20)
        assert(not client.IsVisible())
        local removed = cutscene
        cutscene = nil
        ReplicatedStorage.ChildRemoved:Fire(removed)
        step(0.5)
        assert(client.IsVisible() and client.IsDanger())
        client.Destroy()
    end },
    { "skipped milestone and duplicate completion", function()
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(2)
        ClientSignals.WaveCompleted:Fire(2)
        step(0.1)
        assert(not client.IsOpen(), "wave 3 advice must wait for wave 3 to start")
        ClientSignals.WaveStarted:Fire(3)
        step(0.1)
        assert(client.IsVisible() and client.Caption() == ChapterData.Waves[3].Caption)
        client.Dismiss()
        step(0.5)
        ClientSignals.WaveCompleted:Fire(2)
        step(0.5)
        assert(not client.IsOpen(), "completion and advancement must not duplicate a milestone")
        client.Destroy()
    end },
    { "queued messages survive a long menu pause", function()
        local client = startCombat()
        activeView = "Settings"
        ClientSignals.WaveStarted:Fire(6)
        ClientSignals.WaveCompleted:Fire(5)
        step(40)
        activeView = nil
        step(0.1)
        assert(client.Caption() == ChapterData.Waves[3].Caption and client.IsVisible())
        client.Dismiss()
        step(0.5)
        assert(client.Caption() == ChapterData.Waves[6].Caption and client.IsVisible())
        client.Destroy()
    end },
    { "active messages survive hidden time and wave advancement", function()
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(3)
        step(0.1)
        local visible = client.VisibleGraphemes()
        activeView = "Settings"
        ClientSignals.WaveStarted:Fire(15)
        step(40)
        assert(client.VisibleGraphemes() == visible)
        activeView = nil
        step(0.1)
        assert(client.Caption() == ChapterData.Waves[3].Caption and client.IsVisible())
        client.Destroy()
    end },
    { "boss interruption resumes reveal and reading progress", function()
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(3)
        step(0.1)
        client.Advance()
        step(0.5)
        local progress = client.ReadProgress()
        assert(progress > 0)
        ClientSignals.BossSpawned:Fire({})
        step(0.5)
        assert(client.Caption() == ChapterData.BossContact.Caption)
		assert(client.IsDanger(), "boss warning must request the danger animation")
        client.Dismiss()
		assert(not client.IsDanger(), "dismissal must release the danger animation")
        step(0.5)
        assert(client.Caption() == ChapterData.Waves[3].Caption and client.IsVisible())
        assert(not client.IsTyping() and client.ReadProgress() >= progress)
		assert(not client.IsDanger(), "resumed routine reports must use idle")
        client.Destroy()
    end },
    { "all configured reports survive a full backlog", function()
        local client = startCombat()
        activeView = "Settings"
        for wave = 2, 40 do ClientSignals.WaveStarted:Fire(wave) end
        ClientSignals.BossSpawned:Fire({})
        step(40)
        activeView = nil
        local expected = { ChapterData.BossContact.Caption, ChapterData.FinalWave.Caption }
        for _, wave in { 3, 6, 11, 16, 26, 36 } do
            table.insert(expected, ChapterData.Waves[wave].Caption)
        end
        for _, caption in expected do
            step(0.5)
            assert(client.IsVisible() and client.Caption() == caption, `Missing or unordered report: {caption}`)
			assert(client.IsDanger() == (caption == ChapterData.BossContact.Caption or caption == ChapterData.FinalWave.Caption), "only urgent reports must request danger")
            client.Dismiss()
        end
        step(0.5)
        assert(not client.IsOpen() and RunService.Heartbeat.Count() == 0)
        client.Destroy()
    end },
    { "removing the selected tower releases the hidden dialogue", function()
        local client = startCombat()
        selectedTowerId = 7
        TowerClient.ActiveTowers[7] = { Name = "Test", Model = {} }
        TowerClient.ActiveTowers[8] = { Name = "Other", Model = {} }
        ClientSignals.TowerSelected:Fire(7)
        ClientSignals.WaveStarted:Fire(3)
        step(1)
        assert(not client.IsVisible())
        TowerClient.RemoveTower(8)
        step(0.5)
        assert(not client.IsVisible(), "removing another tower must not clear the current selection")
        TowerClient.RemoveTower(7)
        step(0.5)
        assert(client.IsVisible() and client.Caption() == ChapterData.Waves[3].Caption)
        client.Destroy()
    end },
    { "automatic reading, end cleanup, and retry dedup reset", function()
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(3)
        step(14)
        assert(not client.IsOpen() and RunService.Heartbeat.Count() == 0)
        ClientSignals.WaveStarted:Fire(6)
        step(0.1)
        assert(client.IsOpen())
        ClientSignals.GameEnding:Fire(false)
        assert(not client.IsOpen() and not client.CanPresent() and RunService.Heartbeat.Count() == 0)
        ClientSignals.WaveCompleted:Fire(5)
        step(1)
        assert(not client.IsOpen())
        ClientSignals.Restarted:Fire()
        ClientSignals.WaveStarted:Fire(1)
        step(0.1)
        assert(client.Caption() == ChapterData.Briefing.Caption)
        client.Dismiss()
        step(0.5)
        ClientSignals.WaveStarted:Fire(3)
        step(0.1)
        assert(client.Caption() == ChapterData.Waves[3].Caption and client.IsVisible())
        client.Destroy()
    end },
    { "progress follows elapsed reveal and reading time exactly", function()
        local client = startCombat()
        ClientSignals.WaveStarted:Fire(3)
        RunService.Heartbeat:Fire(0)
        assert(client.IsVisible() and client.ReadProgress() == 0)
        local length = #client.Text()
        local typingDuration = length / DialogueData.CharactersPerSecond
        local readDuration = math.clamp(length / ChapterData.ReadingCharactersPerSecond, ChapterData.MinimumReadTime, ChapterData.MaximumReadTime)
        RunService.Heartbeat:Fire(typingDuration * 0.5)
        local expected = typingDuration * 0.5 / (typingDuration + readDuration)
        assert(math.abs(client.ReadProgress() - expected) < 0.00001, "progress must move during typing")
        activeView = "Settings"
        RunService.Heartbeat:Fire(20)
        assert(math.abs(client.ReadProgress() - expected) < 0.00001, "hidden time must not advance the bar")
        activeView = nil
        RunService.Heartbeat:Fire(typingDuration * 0.5 + 0.25)
        expected = (typingDuration + 0.25) / (typingDuration + readDuration)
        assert(math.abs(client.ReadProgress() - expected) < 0.00001, "phase boundaries must retain the remaining frame time")
        RunService.Heartbeat:Fire(readDuration - 0.251)
        assert(client.IsOpen() and client.ReadProgress() < 1)
        RunService.Heartbeat:Fire(0.002)
        assert(not client.IsOpen() and client.ReadProgress() == 1, "bar must reach full at the exact completion boundary")
        client.Destroy()
    end },
}
for _, case in cases do
    case[2]()
    assert(RunService.Heartbeat.Count() == 0)
    for _, event in ClientSignals do assert(event.Count() == 0, "signal connection leaked") end
    assert(ReplicatedStorage.ChildAdded.Count() == 0 and ReplicatedStorage.ChildRemoved.Count() == 0)
    print(`PASS: {case[1]}`)
end
print(`PASS: {#cases} commander regressions`)
