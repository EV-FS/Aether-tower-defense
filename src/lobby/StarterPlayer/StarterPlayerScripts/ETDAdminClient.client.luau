-- Aether Tower Defense admin client. Authorization and validation live on the server.
-- Rayfield Gen2 is bundled locally; no HTTP loading or executor APIs are required.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local package = ReplicatedStorage:WaitForChild("ETDAdmin", 30)
if not package then return end
local remote = package:WaitForChild("Request", 15)
local noticeRemote = package:WaitForChild("Notice", 15)
if not remote or not remote:IsA("RemoteFunction") then return end

-- Announcements remain available to ordinary players who cannot open the admin panel.
local previousOverlay = playerGui:FindFirstChild("ETDAdminOverlay")
if previousOverlay then previousOverlay:Destroy() end
local overlay = Instance.new("ScreenGui")
overlay.Name = "ETDAdminOverlay"
overlay.ResetOnSpawn = false
overlay.DisplayOrder = 100002
overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
overlay.Parent = playerGui
local announcementNumber = 0
local thumbnailCache = {}
local noticeConnection
local function refreshNativeModule(path, method)
    task.spawn(function()
        local module = ReplicatedStorage
        for _, name in ipairs(path) do
            module = module:FindFirstChild(name)
            if not module then return end
        end
        if not module:IsA("ModuleScript") then return end
        local ok, result = pcall(function()
            local controller = require(module)
            if type(controller) == "table" and type(controller[method]) == "function" then
                return controller[method]()
            end
        end)
        if not ok then
            warn("ETD admin: native UI refresh failed:", result)
        elseif type(result) == "table" and type(result.catch) == "function" then
            result:catch(function(err) warn("ETD admin: inventory refresh failed:", err) end)
        end
    end)
end
if noticeRemote and noticeRemote:IsA("RemoteEvent") then
    noticeConnection = noticeRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then return end
        if payload.kind == "DataChanged" then
            refreshNativeModule({"Shared", "Controllers", "DataClient"}, "FetchAll")
            refreshNativeModule({"Shared", "Controllers", "InventoryClient"}, "Refresh")
            refreshNativeModule({"UI", "Views", "Tower", "LoadoutUI"}, "Refresh")
            return
        end
        if type(payload.text) ~= "string" then return end
        announcementNumber += 1
        local serial = announcementNumber
        local old = overlay:FindFirstChild("Announcement")
        if old then old:Destroy() end
        local announcer = type(payload.announcer) == "table" and payload.announcer or {}
        local color = type(announcer.color) == "table" and announcer.color or {}
        local function colorChannel(value, fallback)
            return type(value) == "number" and value == value and math.clamp(value, 0, 1) or fallback
        end
        local row = Instance.new("Frame")
        row.Name = "Announcement"
        row.AnchorPoint = Vector2.new(0.5, 0)
        row.Position = UDim2.new(0.5, 0, 0, 52)
        row.Size = UDim2.new(0.88, 0, 0, 56)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = overlay
        local constraint = Instance.new("UISizeConstraint")
        constraint.MaxSize = Vector2.new(720, 10000)
        constraint.Parent = row
        local avatar = Instance.new("ImageLabel")
        avatar.Name = "Avatar"
        avatar.BackgroundTransparency = 1
        avatar.BorderSizePixel = 0
        avatar.Size = UDim2.fromOffset(48, 48)
        avatar.Image = ""
        avatar.ScaleType = Enum.ScaleType.Crop
        avatar.Parent = row
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = avatar
        local title = Instance.new("TextLabel")
        title.Name = "DisplayName"
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(62, 0)
        title.Size = UDim2.new(1, -62, 0, 22)
        title.Text = tostring(announcer.displayName or "Aether")
        title.TextColor3 = Color3.new(colorChannel(color.r, 0.6), colorChannel(color.g, 0.8), colorChannel(color.b, 1))
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextWrapped = true
        title.TextStrokeColor3 = Color3.new(0, 0, 0)
        title.TextStrokeTransparency = 0.45
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextYAlignment = Enum.TextYAlignment.Top
        title.RichText = false
        title.Parent = row
        local body = Instance.new("TextLabel")
        body.Name = "Message"
        body.BackgroundTransparency = 1
        body.Position = UDim2.fromOffset(62, 25)
        body.Size = UDim2.new(1, -62, 0, 24)
        body.Text = payload.text
        body.TextColor3 = Color3.new(1, 1, 1)
        body.Font = Enum.Font.Gotham
        body.TextSize = 16
        body.TextWrapped = true
        body.TextStrokeColor3 = Color3.new(0, 0, 0)
        body.TextStrokeTransparency = 0.45
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.RichText = false
        body.Parent = row
        local measuredWidth = 0
        local function resizeAnnouncement()
            local width = math.max(1, row.AbsoluteSize.X - 62)
            if width == measuredWidth then return end
            measuredWidth = width
            local titleHeight = math.max(22, TextService:GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(width, 10000)).Y + 2)
            local bodyHeight = math.max(24, TextService:GetTextSize(body.Text, body.TextSize, body.Font, Vector2.new(width, 10000)).Y + 4)
            title.Size = UDim2.new(1, -62, 0, titleHeight)
            body.Position = UDim2.fromOffset(62, titleHeight + 3)
            body.Size = UDim2.new(1, -62, 0, bodyHeight)
            row.Size = UDim2.new(0.88, 0, 0, math.max(48, titleHeight + 3 + bodyHeight))
        end
        row:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeAnnouncement)
        task.defer(resizeAnnouncement)
        local userId = tonumber(announcer.userId)
        if userId and userId > 0 then
            if thumbnailCache[userId] then avatar.Image = thumbnailCache[userId] end
            task.spawn(function()
                if thumbnailCache[userId] then return end
                for attempt = 1, 3 do
                    if serial ~= announcementNumber or not avatar.Parent then return end
                    local ok, content, ready = pcall(function()
                        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
                    end)
                    if ok and type(content) == "string" and content ~= "" then
                        if serial == announcementNumber and avatar.Parent then avatar.Image = content end
                        if ready then thumbnailCache[userId] = content return end
                    end
                    if attempt < 3 then task.wait(0.75) end
                end
            end)
        end
        task.delay(12, function()
            if serial == announcementNumber and row.Parent then row:Destroy() end
        end)
    end)
end

local function invoke(payload)
    local ok, result = pcall(function() return remote:InvokeServer(payload) end)
    if not ok then return {ok = false, error = "서버 연결 실패 / Server request failed. Try again."} end
    if type(result) ~= "table" then return {ok = false, error = "Invalid server response."} end
    return result
end
local snapshot = invoke({action = "Snapshot"})
if not snapshot.ok then return end
local module = package:WaitForChild("RayfieldGen2", 15)
if not module then warn("ETD admin: RayfieldGen2 module is missing.") return end
local okLibrary, Rayfield = pcall(require, module)
if not okLibrary then warn("ETD admin: RayfieldGen2 failed to load:", Rayfield) return end

local window = Rayfield:CreateWindow({
    name = "AETHER • ADMIN",
    subtitle = "Aether Tower Defense",
    sidebarLayout = true,
    theme = "cobalt",
    profile = tostring(snapshot.role),
    showName = "Aether Admin",
    locale = "en",
})
local home = window:CreateTab({name = "대상 / Players", icon = 93364949241311})
local match = window:CreateTab({name = "인게임 / In-game", icon = 84750991656135})
local universal = window:CreateTab({name = "유니버셜 / Universal", icon = 85925158736685})
local moderation = window:CreateTab({name = "관리 / Moderation", icon = 83277910885129})
local auditTab = window:CreateTab({name = "기록 / Audit", icon = 93364949241311})
local settings = window:CreateTab({name = "설정 / Settings"})

local selectedTarget = player.UserId
local offlineTarget = ""
local inFlight = false
local pending = nil
local targetRevision = 0
local targetMap = {}
local unitMap = {}
local selectedUnitId = nil
local selectedTower = nil
local selectedItem = nil
local selectedTrait = nil
local selectedEnemy = nil
local actionButtons = {}
local inventoryDropdown, targetDropdown
local function roleIsSelfOnly()
    local role = string.lower(tostring(snapshot.role or "")):gsub("[%s_%-]", "")
    return not snapshot.studio and (role == "keonroot" or role == "developer")
end
local function currentTarget()
    if roleIsSelfOnly() then return player.UserId end
    if offlineTarget ~= "" then return tonumber(offlineTarget) or 0 end
    return selectedTarget
end
local function targetName()
    local id = currentTarget()
    if id == player.UserId then return player.Name .. " (나 / self)" end
    for _, entry in ipairs(snapshot.players or {}) do
        if entry.userId == id then return tostring(entry.name) .. " • " .. tostring(id) end
    end
    return "User ID " .. tostring(id)
end
local status = home:CreateText({name = "운영 상태 / Session", text = "Loading…"})
local targetSummary = home:CreateText({name = "선택된 대상 / Selected target", text = player.Name})
local environment = home:CreateText({name = "환경 / Environment", text = ""})
local activity = auditTab:CreateConsole({name = "실행 결과 / Activity", text = "Admin session started.", height = 230, maxLines = 120, follow = true})
local serverAudit = auditTab:CreateConsole({name = "서버 기록 / Server audit", text = "Refresh to load recent records.", height = 180, maxLines = 100, follow = false})
local function append(message)
    activity:Append(os.date("%H:%M:%S") .. "  " .. tostring(message))
end
local function feedback(title, message)
    window:Notify({title = title, content = tostring(message), duration = 5})
    append(title .. ": " .. tostring(message))
end
local function responseMessage(result)
    return tostring(result.message or result.error or result.summary or (result.ok and "완료 / Completed." or "요청 실패 / Request denied."))
end
local function can(action)
    return type(snapshot.capabilities) == "table" and snapshot.capabilities[action] == true
end
local function cancelPending()
    local review = pending
    pending = nil
    if review then
        if review.popup then review.popup:Close() end
        task.spawn(function() invoke({action = "Cancel", token = review.token}) end)
    end
end
local function targetChanged()
    targetRevision += 1
    selectedUnitId = nil
    unitMap = {}
    if inventoryDropdown then inventoryDropdown:Refresh({}) end
    cancelPending()
    targetSummary:Set(targetName() .. "\nThis target applies to player-specific commands in every tab.")
end
local function run(action, args)
    if inFlight or pending then feedback("진행 중 / Busy", "Finish the current request or confirmation first.") return nil end
    if not can(action) then feedback("권한 없음 / Unavailable", "This command is not available for your role or this place.") return nil end
    inFlight = true
    local result = invoke({action = action, targetUserId = currentTarget(), args = args or {}})
    inFlight = false
    feedback(result.ok and "성공 / Success" or "실패 / Denied", action .. " • " .. responseMessage(result))
    return result
end
local function commandButton(tab, action, name, description, callback)
    local button = tab:CreateButton({name = name, description = description, callback = callback})
    table.insert(actionButtons, {action = action, button = button})
    if not can(action) then button:Lock("Unavailable for this role or place.") end
    return button
end
local function integer(input, name, min, max)
    local value = tonumber(input.value)
    if not value or value ~= value or value % 1 ~= 0 or value < min or value > max then
        feedback("입력 확인 / Check input", name .. ": enter a whole number from " .. min .. " to " .. max .. ".")
        return nil
    end
    return value
end
local function catalog(kind)
    local values = {}
    local source = snapshot.catalog and snapshot.catalog[kind] or {}
    for key, entry in pairs(source) do
        local value = type(entry) == "table" and (entry.id or entry.name) or entry
        if type(value) ~= "string" and type(key) == "string" then value = key end
        if type(value) == "string" then table.insert(values, value) end
    end
    table.sort(values)
    return values
end
local catalogDropdowns = {}
local function catalogDropdown(tab, kind, name, callback)
    local values = catalog(kind)
    callback(values[1])
    local handle = tab:CreateDropdown({name = name, options = values, value = values[1], placeholder = "No entries available", forgetState = true, callback = callback})
    table.insert(catalogDropdowns, {handle = handle, kind = kind, callback = callback})
    return handle
end
local function requireSelection(value, label)
    if value and value ~= "" then return true end
    feedback("선택 필요 / Choose an entry", label)
    return false
end

home:CreateSection({name = "공통 대상 / Shared target"})
targetDropdown = home:CreateDropdown({name = "온라인 플레이어 / Online player", options = {}, placeholder = "Choose a player", forgetState = true, callback = function(value)
    if targetMap[value] then selectedTarget = targetMap[value] targetChanged() end
end})
local offlineInput = home:CreateInput({name = "사용자 ID / User ID", description = "Optional target override. Leave blank to use the online selection. Offline support depends on the command.", value = "", numeric = true, forgetState = true, callback = function(value)
    offlineTarget = value:match("^%s*(.-)%s*$") or ""
    targetChanged()
end})
home:CreateText({name = "역할 / Role rules", text = "KeonRoot / Developer: 본인만 변경 가능, 공지·밴·킥 제외. Admin: 모든 대상 밴·킥만 가능. HeadDeveloper / HeadOwner (Owner): 모든 대상, 모든 명령. Studio: 전체 권한. 공유 소환·속도는 본인 전용 역할일 때 솔로 매치에서만 가능."})

local function updateSnapshot()
    if inFlight or pending then return end
    inFlight = true
    local result = invoke({action = "Snapshot"})
    inFlight = false
    if not result.ok then feedback("새로고침 실패 / Refresh failed", responseMessage(result)) return end
    snapshot = result
    status:Set("Role: " .. tostring(snapshot.role) .. "\nPlace: " .. tostring(snapshot.placeKind) .. "  •  " .. (snapshot.studio and "Studio access enabled" or "Live permissions enforced"))
    local warnings = {}
    for _, warning in ipairs(snapshot.warnings or {}) do table.insert(warnings, tostring(warning)) end
    environment:Set(#warnings > 0 and table.concat(warnings, "\n") or "Ready. Commands are checked and recorded by the server.")
    local options, selection = {}, nil
    targetMap = {}
    for _, entry in ipairs(snapshot.players or {}) do
        if not roleIsSelfOnly() or entry.userId == player.UserId then
            local label = tostring(entry.displayName or entry.name) .. " (@" .. tostring(entry.name) .. ") • " .. tostring(entry.userId)
            targetMap[label] = entry.userId
            table.insert(options, label)
            if entry.userId == selectedTarget then selection = label end
        end
    end
    table.sort(options)
    targetDropdown:Refresh(options)
    if not selection then
        selectedTarget = player.UserId
        for label, id in pairs(targetMap) do if id == selectedTarget then selection = label break end end
    end
    if selection then targetDropdown:Set(selection, true) end
    if roleIsSelfOnly() then offlineTarget = "" offlineInput:Set("", true) offlineInput:Lock("This role can target only itself.") else offlineInput:Unlock() end
    for _, entry in ipairs(actionButtons) do
        if can(entry.action) then entry.button:Unlock() else entry.button:Lock("Unavailable for this role or place.") end
    end
    for _, entry in ipairs(catalogDropdowns) do
        local values = catalog(entry.kind)
        entry.handle:Refresh(values)
        if #entry.handle.value == 0 and values[1] then entry.handle:Set(values[1]) end
    end
    local lines = {}
    for _, record in ipairs(snapshot.audit or {}) do
        if type(record) == "table" then
            local encoded, value = pcall(HttpService.JSONEncode, HttpService, record)
            table.insert(lines, encoded and value or tostring(record))
        else table.insert(lines, tostring(record)) end
    end
    serverAudit:Set(#lines > 0 and table.concat(lines, "\n") or "No recent server records.")
    targetSummary:Set(targetName() .. "\nThis target applies to player-specific commands in every tab.")
end
home:CreateButton({name = "플레이어 및 상태 새로고침 / Refresh", callback = updateSnapshot})
auditTab:CreateButton({name = "서버 기록 새로고침 / Refresh server audit", callback = updateSnapshot})

match:CreateText({name = "매치 제어 / Match controls", text = "Summon allied units, set the selected player's cash, and control the match. Enemy spawning and speed affect the shared match. Start a match first if a command is unavailable."})
match:CreateSection({name = "유닛 소환 / Spawn unit"})
catalogDropdown(match, "units", "유닛 / Unit", function(value) selectedTower = value end)
local alliedCount = match:CreateInput({name = "유닛 수 / Count", numeric = true, value = "1", forgetState = true})
commandButton(match, "SpawnUnit", "유닛 소환 / Spawn allies", "Summons allied units such as Archer Noob or Knight Noob into the current match.", function()
    local count = integer(alliedCount, "Allied unit count", 1, 25)
    if count and requireSelection(selectedTower, "Choose an allied unit.") then run("SpawnUnit", {towerId = selectedTower, count = count}) end
end)
match:CreateSection({name = "적 소환 / Spawn enemies"})
catalogDropdown(match, "enemies", "적 종류 / Enemy", function(value) selectedEnemy = value end)
local enemyCount = match:CreateInput({name = "적 수 / Count", numeric = true, value = "1", forgetState = true})
commandButton(match, "SpawnEnemy", "적 소환 / Spawn enemies", "Adds enemies to the current match.", function()
    local count = integer(enemyCount, "Enemy count", 1, 25)
    if count and requireSelection(selectedEnemy, "Choose an enemy.") then run("SpawnEnemy", {enemyId = selectedEnemy, count = count}) end
end)
match:CreateSection({name = "돈 및 속도 / Money and speed"})
local moneyAmount = match:CreateInput({name = "돈 / Cash", description = "Exact match cash balance to set.", numeric = true, value = "1000", forgetState = true})
commandButton(match, "Money", "돈 설정 / Set match cash", "Sets the selected player's match cash to this exact amount.", function()
    local amount = integer(moneyAmount, "Money", 0, 10000000)
    if amount then run("Money", {amount = amount}) end
end)
local speed = match:CreateSlider({name = "게임 속도 / Game speed", range = {0.5, 5}, increment = 0.5, value = 1, suffix = "×", forgetState = true})
commandButton(match, "GameSpeed", "속도 적용 / Apply game speed", "Changes the shared match simulation speed.", function() run("GameSpeed", {speed = speed.value}) end)

universal:CreateSection({name = "로비 재화 / Lobby currency"})
local selectedCurrency
catalogDropdown(universal, "currencies", "재화 종류 / Currency", function(value) selectedCurrency = value end)
local currencyAmount = universal:CreateInput({name = "지급량 / Currency amount", description = "로비에서 선택한 플레이어의 잔액에 더합니다. Adds to the selected player's balance in the lobby.", numeric = true, value = "1000", forgetState = true})
commandButton(universal, "GiveCurrency", "재화 지급 / Give currency", "Coins, Gems, Blossom · 한 번에 최대 1,000,000 지급. Adds currency; keeps the existing balance.", function()
    local amount = integer(currencyAmount, "Currency amount", 1, snapshot.catalog.maxCurrencyGrant or 1000000)
    if amount and requireSelection(selectedCurrency, "재화 종류를 선택하세요 / Choose a currency.") then
        run("GiveCurrency", {currencyId = selectedCurrency, amount = amount})
    end
end)

universal:CreateSection({name = "아이템 지급 / Give items"})
catalogDropdown(universal, "items", "아이템 / Item", function(value) selectedItem = value end)
local itemAmount = universal:CreateInput({name = "수량 / Amount", numeric = true, value = "1", forgetState = true})
commandButton(universal, "GiveItem", "아이템 지급 / Give item", "Adds this item to the target player's inventory.", function()
    local amount = integer(itemAmount, "Item amount", 1, 10000)
    if amount and requireSelection(selectedItem, "Choose an item.") then run("GiveItem", {itemId = selectedItem, amount = amount}) end
end)
universal:CreateSection({name = "타워 지급 / Give towers"})
local towerToGive
catalogDropdown(universal, "towers", "타워 / Tower", function(value) towerToGive = value end)
local towerCount = universal:CreateInput({name = "타워 수 / Count", numeric = true, value = "1", forgetState = true})
commandButton(universal, "GiveTower", "타워 지급 / Give tower", "Creates owned towers for the selected player.", function()
    local count = integer(towerCount, "Tower count", 1, 50)
    if count and requireSelection(towerToGive, "Choose a tower.") then run("GiveTower", {towerId = towerToGive, count = count}) end
end)
universal:CreateSection({name = "보유 타워 편집 / Owned tower editor"})
inventoryDropdown = universal:CreateDropdown({name = "보유 타워 / Owned tower", options = {}, placeholder = "Load target inventory first", forgetState = true, callback = function(value) selectedUnitId = unitMap[value] end})
universal:CreateButton({name = "대상 인벤토리 불러오기 / Load target inventory", callback = function()
    if inFlight or pending then return end
    inFlight = true
    local result = invoke({action = "Inventory", targetUserId = currentTarget()})
    inFlight = false
    if not result.ok then feedback("인벤토리 / Inventory", responseMessage(result)) return end
    local labels = {}
    unitMap = {}
    for _, unit in ipairs(result.towers or {}) do
        local label = tostring(unit.name) .. " • Lv." .. tostring(unit.level or 1) .. " • " .. tostring(unit.trait or "None") .. " • " .. tostring(unit.id)
        unitMap[label] = unit.id
        table.insert(labels, label)
    end
    table.sort(labels)
    inventoryDropdown:Refresh(labels)
    selectedUnitId = nil
    if labels[1] then inventoryDropdown:Set(labels[1]) end
    feedback("인벤토리 / Inventory", tostring(#labels) .. " owned towers loaded for " .. targetName() .. ".")
end})
local towerLevel = universal:CreateInput({name = "레벨 / Level", numeric = true, value = "1", forgetState = true})
commandButton(universal, "TowerLevel", "레벨 적용 / Set tower level", "Changes the selected owned tower. Refresh its inventory after applying.", function()
    local level = integer(towerLevel, "Tower level", 0, 30)
    if level and requireSelection(selectedUnitId, "Load inventory and select an owned tower.") then run("TowerLevel", {unitId = selectedUnitId, level = level}) end
end)
catalogDropdown(universal, "traits", "특성 / Trait", function(value) selectedTrait = value end)
commandButton(universal, "Trait", "특성 적용 / Set trait", "Changes the selected owned tower's trait.", function()
    if requireSelection(selectedUnitId, "Load inventory and select an owned tower.") and requireSelection(selectedTrait, "Choose a trait.") then run("Trait", {unitId = selectedUnitId, traitId = selectedTrait}) end
end)

local function prepare(action, args)
    if inFlight or pending then return end
    if not can(action) then feedback("권한 없음 / Unavailable", "This command is unavailable.") return end
    inFlight = true
    local revision = targetRevision
    local preparedTarget = currentTarget()
    local result = invoke({action = "Prepare", command = action, targetUserId = currentTarget(), args = args or {}})
    if result.ok and type(result.token) == "string" and (revision ~= targetRevision or preparedTarget ~= currentTarget()) then
        invoke({action = "Cancel", token = result.token})
        inFlight = false
        return
    end
    inFlight = false
    if not result.ok then feedback("준비 실패 / Cannot prepare", responseMessage(result)) return end
    if type(result.token) ~= "string" then feedback("준비 실패 / Cannot prepare", "The server did not return a valid confirmation.") return end
    local review = {token = result.token, summary = tostring(result.summary or action), action = action, target = preparedTarget}
    pending = review
    review.popup = window:Popup({title = tostring(result.title or "작업 확인 / Confirm action"), content = review.summary, dismissable = false, options = {
        {text = "취소 / Cancel", callback = function()
            if pending == review then cancelPending() end
        end},
        {text = "확인 / Confirm", style = "danger", callback = function()
            if pending ~= review then return end
            if inFlight then
                cancelPending()
                feedback("진행 중 / Busy", "Another request is running. Review the action again after it finishes.")
                return
            end
            if currentTarget() ~= review.target then cancelPending() return end
            inFlight = true
            pending = nil
            local confirmed = invoke({action = "Confirm", token = review.token})
            inFlight = false
            feedback(confirmed.ok and "성공 / Success" or "실패 / Denied", review.action .. " • " .. responseMessage(confirmed))
        end},
    }})
    if not review.popup then cancelPending() return end
    append("Reviewing " .. action .. " for " .. targetName() .. ".")
end
universal:CreateSection({name = "데이터 초기화 / Reset player data"})
commandButton(universal, "ResetData", "데이터 초기화 / Reset data", "Review the selected player, then confirm once to reset their data.", function() prepare("ResetData", {}) end)

moderation:CreateSection({name = "공지 / Announcements"})
local announceText = moderation:CreateInput({name = "공지 / Message", value = "", placeholder = "Enter an announcement", forgetState = true})
local announceScope = "Server"
moderation:CreateDropdown({name = "공지 범위 / Announcement scope", options = {"Server", "Universe"}, value = "Server", forgetState = true, callback = function(value) announceScope = value end})
commandButton(moderation, "Announce", "공지 전송 / Send announcement", "Server reaches this server; Universe reaches connected servers in this experience.", function()
    if not announceText.value:find("%S") then feedback("입력 확인 / Check input", "Enter announcement text.") return end
    run("Announce", {text = announceText.value, scope = announceScope})
end)
moderation:CreateSection({name = "플레이어 관리 / Player moderation"})
local reason = moderation:CreateInput({name = "사유 / Reason", value = "", placeholder = "A specific moderation reason is required", forgetState = true})
local duration = moderation:CreateInput({name = "기간 / Seconds", description = "Ban duration: use -1 for permanent. Example: 86400 = 24 hours.", numeric = true, value = "86400", forgetState = true})
local function moderationArgs(includeDuration)
    if not reason.value:find("%S") then feedback("사유 필요 / Reason required", "Enter a specific moderation reason.") return nil end
    local args = {reason = reason.value}
    if includeDuration then
        local seconds = tonumber(duration.value)
        if not seconds or seconds % 1 ~= 0 or (seconds ~= -1 and seconds < 60) then feedback("입력 확인 / Check input", "Ban duration must be -1 or at least 60 seconds.") return nil end
        args.duration = seconds
    end
    return args
end
commandButton(moderation, "Kick", "플레이어 킥 / Kick player", "Review the player and reason, then confirm once.", function() local args = moderationArgs(false) if args then prepare("Kick", args) end end)
commandButton(moderation, "Ban", "플레이어 밴 / Ban player", "Review the player, reason, and duration, then confirm once.", function() local args = moderationArgs(true) if args then prepare("Ban", args) end end)
commandButton(moderation, "Unban", "밴 해제 / Unban player", "Review the player and reason, then confirm once.", function() local args = moderationArgs(false) if args then prepare("Unban", args) end end)

settings:CreateText({name = "패널 열기 / Open the panel", text = "Press F4 or tap Rayfield's collapsed Aether Admin pill. Values never execute commands until you press an action button."})
settings:CreateDropdown({name = "테마 / Theme", options = {"cobalt", "default", "amethyst", "ember", "frost", "rose"}, value = "cobalt", forgetState = true, callback = function(value) window:ChangeTheme(value) end})
settings:CreateButton({name = "패널 숨기기 / Hide panel", callback = function() window:Hide() end})
settings:CreateText({name = "Rayfield Gen2", text = "Rayfield Gen2 v1.2.0 • Copyright 2026 Corridon Capital • MPL-2.0. Bundled for standard Roblox clients. UI preferences last for this session."})

local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F4 and not window.unloaded then window:ToggleHide() end
end)
local refreshScheduled = false
local function scheduleRefresh()
    if refreshScheduled then return end
    refreshScheduled = true
    task.delay(1, function()
        refreshScheduled = false
        if not window.unloaded and not inFlight then updateSnapshot() end
    end)
end
local joinedConnection = Players.PlayerAdded:Connect(scheduleRefresh)
local leftConnection = Players.PlayerRemoving:Connect(scheduleRefresh)
script.Destroying:Connect(function()
    cancelPending()
    inputConnection:Disconnect()
    joinedConnection:Disconnect()
    leftConnection:Disconnect()
    if noticeConnection then noticeConnection:Disconnect() end
    if not window.unloaded then window:Unload() end
    overlay:Destroy()
end)
updateSnapshot()
append("Ready • " .. tostring(snapshot.role) .. " • " .. tostring(snapshot.placeKind))
