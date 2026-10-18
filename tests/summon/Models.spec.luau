local allSignals = {}
local function signal()
    local callbacks = {}
    local event = {}
    function event:Connect(fn)
        callbacks[fn] = true
        return { Disconnect = function() callbacks[fn] = nil end }
    end
    function event:Fire(...)
        local copy = table.clone(callbacks)
        for fn in copy do if callbacks[fn] then fn(...) end end
    end
    function event:Count() local n = 0; for _ in callbacks do n += 1 end; return n end
    table.insert(allSignals, event)
    return event
end
local function node(name, class)
    local n = { Name = name, ClassName = class, Archivable = true, Children = {},
        ChildAdded = signal(), ChildRemoved = signal(), DescendantAdded = signal(), DescendantRemoving = signal(), Properties = {} }
    function n:IsA(kind) return self.ClassName == kind end
    function n:FindFirstChild(childName) return self.Children[childName] end
    function n:FindFirstChildWhichIsA(kind, recursive)
        for _, child in self.Children do
            if child:IsA(kind) then return child end
            if recursive then local found = child:FindFirstChildWhichIsA(kind, true); if found then return found end end
        end
        return nil
    end
    function n:GetPropertyChangedSignal(property)
        self.Properties[property] = self.Properties[property] or signal()
        return self.Properties[property]
    end
    function n:Add(child)
        self.Children[child.Name] = child
        child.Parent = self
        self.ChildAdded:Fire(child)
        local parent = self
        while parent do parent.DescendantAdded:Fire(child); parent = parent.Parent end
    end
    function n:Remove(child)
        local parent = self
        while parent do parent.DescendantRemoving:Fire(child); parent = parent.Parent end
        self.Children[child.Name] = nil
        child.Parent = nil
        self.ChildRemoved:Fire(child)
    end
    function n:Destroy() self.Destroyed = true end
    return n
end
local deferred = {}
local task = {
    defer = function(fn) local thread = coroutine.create(fn); table.insert(deferred, thread); return thread end,
    cancel = coroutine.close,
}
local function flush()
    while #deferred > 0 do
        local threads = deferred; deferred = {}
        for _, thread in threads do
            if coroutine.status(thread) ~= "dead" then assert(coroutine.resume(thread)) end
        end
    end
end
local warn = print
local ReplicatedStorage = node("ReplicatedStorage", "Folder")
local game = { GetService = function() return ReplicatedStorage end }
local require = function(value) return value end
local TowerAssets = (function()
--[[ASSETS]]
end)()
local observed, reason
local changes = 0
local unsubscribe = TowerAssets.Observe("A", function(asset, failure) observed, reason = asset, failure; changes += 1 end)
assert(observed == nil and reason == "missing model")
local assets = node("Assets", "Folder")
ReplicatedStorage:Add(assets)
flush()
local towers = node("Towers", "Folder")
assets:Add(towers)
flush()
local a = node("A", "Model")
towers:Add(a)
flush()
assert(observed == nil and reason == "model has no BasePart")
local before = changes
a:Add(node("Head", "BasePart"))
a:Add(node("Torso", "BasePart"))
flush()
assert(observed == a and changes == before + 1)
print("PASS: delayed folders, models, and batched geometry recover automatically")
a.Archivable = false
a:GetPropertyChangedSignal("Archivable"):Fire()
flush()
assert(observed == nil and reason == "Archivable is disabled")
a.Archivable = true
a:GetPropertyChangedSignal("Archivable"):Fire()
flush()
assert(observed == a)
towers:Remove(a)
flush()
assert(observed == nil)
local replacement = node("A", "Model")
replacement:Add(node("Body", "BasePart"))
towers:Add(replacement)
flush()
assert(observed == replacement)
print("PASS: invalid templates and replacements never retain a stale model")
replacement:Add(node("Arm", "BasePart"))
unsubscribe()
before = changes
flush()
assert(changes == before)
for _, event in allSignals do assert(event:Count() == 0, "asset watcher leaked a connection") end
print("PASS: unsubscribe cancels deferred refreshes and releases every listener")
ReplicatedStorage.Settings = { Data = {
    SummonConfig = { RarityRates = { { Rarity = "Common", Weight = 80 }, { Rarity = "Rare", Weight = 20 } } },
    SummonBannerPool = { Common = {"A"}, Rare = {"B"} },
    TowerData = { ByName = { A = { Rarity = "Common" }, B = { Rarity = "Rare" } } },
    CraftRecipes = {},
} }
ReplicatedStorage.Shared = { Modules = {
    Core = { Summon = { BannerSchedule = { GetSlot = function() return 1 end, GetNextChange = function() return 1800 end } } },
    Utils = { TowerAssets = TowerAssets },
} }
local Random = { new = function() return { NextInteger = function(_, first) return first end } end }
local workspace = { GetServerTimeNow = function() return 1 end, CurrentCamera = {} }
local banner = (function()
--[[BANNER]]
end)()
local first = banner.GetActiveBanner()
assert(#first.Units == 1 and first.TotalWeight == 80)
local b = node("B", "Model")
b:Add(node("Body", "BasePart"))
towers:Add(b)
local second = banner.GetActiveBanner()
assert(first ~= second and #second.Units == 2 and second.TotalWeight == 100)
assert(banner.GetActiveBanner() == second)
towers:Remove(b)
assert(#banner.GetActiveBanner().Units == 1)
print("PASS: banner cache revalidates late and removed assets within the same interval")

local owned = {}
local function source(initial)
    local value = initial
    return function(...)
        if select("#", ...) > 0 then value = ... end
        return value
    end
end
local function read(value) return if type(value) == "function" then value() else value end
local function effect(fn) fn() end
local function cleanup(fn) table.insert(owned, fn) end
local function create() return function(props) return props end end
local RunService = { PreRender = signal() }
local RaycastParams = { new = function() return {} end }
local Enum = { HighlightDepthMode = { AlwaysOnTop = true }, RaycastFilterType = { Exclude = true } }
local Color3 = { new = function() return {} end }
local UDim2 = { fromOffset = function() return {} end }
local Instance = { new = function() return node("Highlight", "Highlight") end }
local model
function replacement:Clone() model = node("Display", "Model"); return model end
local useTowerAsset = function() return function() return replacement end end
local prepareModel = function(clone) return { Instance = clone } end
local prepareSummonEffects = function() error("simulated VFX failure") end
local playAnimation = function() error("simulated animation failure") end
local cleanupSummonEffects = function() end
local restoreOccluders = function() end
local display = (function()
--[[WORLD_DISPLAY]]
end)()
local presented = false
display({ TowerName = "A", OnModelChanged = function(value) presented = value ~= nil end })
assert(presented and model.Parent == workspace.CurrentCamera)
flush()
assert(presented and not model.Destroyed)
for index = #owned, 1, -1 do owned[index]() end
assert(not presented and model.Destroyed and RunService.PreRender:Count() == 0)
print("PASS: animation and VFX failures preserve the unit display and clean up on close")
