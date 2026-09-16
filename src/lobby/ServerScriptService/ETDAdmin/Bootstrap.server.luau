local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local MessagingService = game:GetService("MessagingService")
local GroupService = game:GetService("GroupService")
local Config = require(script.Parent.Config)
local Policy = require(script.Parent.Policy)
local Audit = require(script.Parent.Audit)
local Persistent = require(script.Parent.Persistent)
local Match = require(script.Parent.Match)
local studio = RunService:IsStudio() and Config.StudioFullAccess == true
local folder = ReplicatedStorage:WaitForChild("ETDAdmin")
local request = folder:WaitForChild("Request")
local notice = folder:WaitForChild("Notice")
local roles, buckets, busy, pending, lastDenial, commandTimes = {}, {}, {}, {}, {}, {}
local targetLocks = {}
local subscriptionReady = false
local dangerous = {Ban=true, Kick=true, Unban=true, ResetData=true}
local persistentActions = {GiveItem=true, GiveCurrency=true, GiveTower=true, TowerLevel=true, Trait=true, ResetData=true}
local matchActions = {SpawnUnit=true, SpawnEnemy=true, Money=true, GameSpeed=true}
local currencyIds = {Coins=true, Gems=true, Blossom=true}
local cooldowns = {Announce=5, Ban=2, Kick=2, Unban=2, ResetData=3, SpawnEnemy=1, SpawnUnit=1, GiveTower=1}

local function roleFor(player)
	if studio then return "Owner" end
	local cached = roles[player]
	if cached and os.clock() - cached.at < 60 then return cached.role end
	local role = "None"
	if table.find(Config.OwnerUserIds, player.UserId) or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId) then
		role = "Owner"
	elseif Policy.ValidRole(Config.UserRoles[player.UserId]) then
		role = Policy.NormalizeRole(Config.UserRoles[player.UserId])
	elseif Config.GroupId > 0 then
		local rankRoles, nameRoles = Config.GroupRankRoles or {}, Config.GroupNameRoles or {}
		local ok, membership = pcall(function()
			return GroupService:GetRolesInGroupAsync(player.UserId, Config.GroupId)
		end)
		if ok then
			role = Policy.GroupMembershipRole(membership, rankRoles, nameRoles) or "None"
		else
			-- Compatibility with Studio versions that do not expose the multi-role API yet.
			local rankOk, rank = pcall(player.GetRankInGroupAsync, player, Config.GroupId)
			if rankOk then
				local groupRole = Policy.GroupRole(rank, nil, rankRoles, nameRoles)
				if not groupRole and rank > 0 then
					local nameOk, name = pcall(player.GetRoleInGroupAsync, player, Config.GroupId)
					if nameOk then groupRole = Policy.GroupRole(rank, name, rankRoles, nameRoles) end
				end
				role = groupRole or "None"
			end
		end
	end
	roles[player] = {role=role, at=os.clock()}
	return role
end
local function consume(player)
	local now = os.clock()
	local bucket = buckets[player] or {tokens=Config.RequestBurst, at=now}
	bucket.tokens = math.min(Config.RequestBurst, bucket.tokens + (now - bucket.at) * Config.RequestsPerSecond)
	bucket.at = now
	buckets[player] = bucket
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end
local function fail(message)
	message = tostring(message):gsub("^.-:%d+: ", "")
	return {ok=false, message=message}
end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function cleanArgs(args)
	if args == nil then return {} end
	if type(args) ~= "table" then error("Invalid command arguments.", 0) end
	local result, count = {}, 0
	for key, value in pairs(args) do
		count += 1
		if count > 12 or type(key) ~= "string" or #key > 32 then error("Invalid command arguments.", 0) end
		if type(value) == "number" then
			if not finite(value) then error("Numbers must be finite.", 0) end
		elseif type(value) == "string" then
			if #value > 500 or not utf8.len(value) then error("Text must be valid and at most 500 bytes.", 0) end
		elseif type(value) ~= "boolean" then error("Unsupported command argument.", 0) end
		result[key] = value
	end
	return result
end
local function targetFor(actor, action, id)
	id = id == nil and actor.UserId or id
	if not finite(id) or id % 1 ~= 0 then error("Select a valid player.", 0) end
	local target = Players:GetPlayerByUserId(id)
	if not target and action ~= "Ban" and action ~= "Unban" then error("That player is no longer in this server.", 0) end
	if not target and id <= 0 then error("A positive Roblox UserId is required.", 0) end
	return target, id
end
local function authorize(actor, role, action, targetId)
	local allowed, reason = Policy.Allowed(role, studio, action, actor.UserId, targetId, #Players:GetPlayers())
	if not allowed then
		Audit.Record(actor, role, action, targetId, "denied", reason)
		error(reason, 0)
	end
end
local function reasonFor(args)
	local reason = args.reason
	if type(reason) ~= "string" or not reason:match("%S") or #reason > 200 then error("Enter a moderation reason (1–200 bytes).", 0) end
	return reason
end
local function filtered(text, actor)
	if RunService:IsStudio() then return text end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, actor.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then error("Roblox text filtering is unavailable. Nothing was sent.", 0) end
	return result
end
local seen, seenOrder = {}, {}
-- A seeded random hue gives each announcer one consistent color across servers.
-- Identity and color are generated here, never taken from client arguments.
local function announcerFor(actor)
	local random = Random.new(math.abs(actor.UserId) % 2147483647)
	local color = Color3.fromHSV(random:NextNumber(), 0.48, 1)
	return {userId=actor.UserId, displayName=actor.DisplayName, color={r=color.R, g=color.G, b=color.B}}
end
local function validAnnouncer(announcer)
	if type(announcer) ~= "table" or not finite(announcer.userId) or announcer.userId % 1 ~= 0 then return false end
	if type(announcer.displayName) ~= "string" or #announcer.displayName == 0 or #announcer.displayName > 100 or not utf8.len(announcer.displayName) then return false end
	if type(announcer.color) ~= "table" then return false end
	for _, channel in ipairs({"r", "g", "b"}) do
		local value = announcer.color[channel]
		if not finite(value) or value < 0 or value > 1 then return false end
	end
	return true
end
local function deliverAnnouncement(data)
	if type(data) ~= "table" or (data.version ~= 1 and data.version ~= 2) or type(data.id) ~= "string" or #data.id > 64 or seen[data.id] then return end
	if type(data.text) ~= "string" or #data.text > 650 or type(data.title) ~= "string" or #data.title > 100 then return end
	if (data.version == 2 or data.announcer ~= nil) and not validAnnouncer(data.announcer) then return end
	if not finite(data.time) or math.abs(os.time() - data.time) > 120 then return end
	seen[data.id] = true
	table.insert(seenOrder, data.id)
	if #seenOrder > 100 then seen[table.remove(seenOrder, 1)] = nil end
	notice:FireAllClients({text=data.text, title=data.title, announcer=data.announcer})
end
task.spawn(function()
	if RunService:IsStudio() then return end
	for attempt = 1, 3 do
		local ok = pcall(function()
			MessagingService:SubscribeAsync(Config.AnnouncementTopic, function(message) deliverAnnouncement(message.Data) end)
		end)
		if ok then subscriptionReady = true; return end
		task.wait(attempt * 5)
	end
	warn("[ETD Admin] Universe announcement subscription unavailable.")
end)
local function perform(actor, role, action, target, targetId, args)
	if persistentActions[action] then
		if action == "GiveCurrency" then
			if Match.Available() then error("Currency grants are available in the lobby only.", 0) end
			if type(args.currencyId) ~= "string" or not currencyIds[args.currencyId] then error("Select Coins, Gems, or Blossom.", 0) end
			if not finite(args.amount) or args.amount % 1 ~= 0 or args.amount < 1 or args.amount > 1_000_000 then
				error("Currency amount must be a whole number between 1 and 1000000.", 0)
			end
			-- Forward only the allowlisted currency and amount, never arbitrary profile fields.
			args = {currencyId=args.currencyId, amount=args.amount}
		end
		local message = Persistent.Perform(action, actor, target, args)
		notice:FireClient(target, {kind="DataChanged"})
		if action == "ResetData" and not RunService:IsStudio() then
			task.delay(0.5, function() if target.Parent == Players then target:Kick("Your data was reset by an administrator. Please rejoin.") end end)
		end
		return message
	end
	if matchActions[action] then return Match.Perform(action, actor, target, args) end
	if action == "Announce" then
		if type(args.text) ~= "string" or not args.text:match("%S") or #args.text > 400 then error("Enter an announcement (1–400 bytes).", 0) end
		if args.scope ~= "Server" and args.scope ~= "Universe" then error("Select Server or Universe announcement scope.", 0) end
		local data = {version=1, id=HttpService:GenerateGUID(false), time=os.time(), text=filtered(args.text, actor), title=actor.DisplayName, announcer=announcerFor(actor)}
		if args.scope == "Universe" and not RunService:IsStudio() then
			if not subscriptionReady then error("Universe announcements are not connected yet.", 0) end
			local ok = pcall(MessagingService.PublishAsync, MessagingService, Config.AnnouncementTopic, data)
			if not ok then error("Universe announcement could not be published.", 0) end
		end
		deliverAnnouncement(data)
		return RunService:IsStudio() and "Studio announcement displayed in this test session only." or ("Announcement sent: " .. args.scope)
	elseif action == "Kick" then
		local reason = filtered(reasonFor(args), actor)
		target:Kick(reason)
		return "Kicked " .. target.Name
	elseif action == "Ban" then
		local reason = reasonFor(args)
		local duration = args.duration
		if not finite(duration) or duration % 1 ~= 0 or (duration ~= -1 and (duration < 60 or duration > 31536000)) then error("Ban duration must be 60–31536000 seconds, or -1 for permanent.", 0) end
		if RunService:IsStudio() then return "Studio ban simulation passed for UserId " .. targetId .. "; no live ban was created." end
		local ok = pcall(Players.BanAsync, Players, {UserIds={targetId}, Duration=duration, DisplayReason=filtered(reason, actor), PrivateReason=string.format("Admin %s (%d): %s", actor.Name, actor.UserId, reason), ExcludeAltAccounts=true, ApplyToUniverse=true})
		if not ok then error("Roblox could not apply the ban. Check BanningEnabled and server output.", 0) end
		return "Universe ban applied to " .. targetId
	elseif action == "Unban" then
		reasonFor(args)
		if RunService:IsStudio() then return "Studio unban simulation passed for UserId " .. targetId .. "; live bans were unchanged." end
		local ok = pcall(Players.UnbanAsync, Players, {UserIds={targetId}, ApplyToUniverse=true})
		if not ok then error("Roblox could not remove the ban.", 0) end
		return "Universe ban removed for " .. targetId
	end
	error("Unknown action.", 0)
end
local function run(actor, role, action, target, targetId, args)
	authorize(actor, role, action, targetId)
	local times = commandTimes[actor] or {}
	commandTimes[actor] = times
	local now = os.clock()
	if times[action] and now - times[action] < (cooldowns[action] or 0.25) then error("Please wait before repeating that action.", 0) end
	times[action] = now
	local lockKey = (action == "SpawnUnit" or action == "SpawnEnemy" or action == "GameSpeed") and "match" or targetId
	if targetLocks[lockKey] then return fail("Another admin command for this target is running. Please wait.") end
	targetLocks[lockKey] = true
	local ok, message = pcall(perform, actor, role, action, target, targetId, args)
	targetLocks[lockKey] = nil
	local detail = message
	if args.reason then detail = tostring(message) .. " · reason: " .. args.reason end
	if action == "Money" or action == "GiveItem" then detail = tostring(message) .. " · amount: " .. tostring(args.amount) end
	if action == "GiveCurrency" then detail = tostring(message) .. " · currency: " .. tostring(args.currencyId) .. " · amount: " .. tostring(args.amount) end
	Audit.Record(actor, role, action, targetId, ok and "success" or "failed", detail)
	if not ok then return fail(tostring(message):sub(1, 350)) end
	return {ok=true, message=message}
end
local function snapshot(actor, role)
	local catalog, warnings = {}, {}
	local ok, data = pcall(Persistent.Catalog)
	if ok then for key, value in pairs(data) do catalog[key] = value end else table.insert(warnings, "Player data is not ready: " .. tostring(data):sub(1, 180)) end
	local matchReady = Match.Available()
	if matchReady then
		local matchOk, matchData = pcall(Match.Catalog)
		if matchOk then for key, value in pairs(matchData) do catalog[key] = value end end
	end
	local capabilities = {}
	for _, action in ipairs(Policy.Actions) do
		capabilities[action] = Policy.Allowed(role, studio, action, actor.UserId, actor.UserId, #Players:GetPlayers())
			and (not matchActions[action] or matchReady) and (action ~= "GiveCurrency" or not matchReady)
	end
	local playerList = {}
	for _, player in ipairs(Players:GetPlayers()) do table.insert(playerList, {userId=player.UserId, name=player.Name, displayName=player.DisplayName}) end
	table.sort(playerList, function(a,b) return a.name:lower() < b.name:lower() end)
	table.insert(warnings, Audit.Status())
	if studio then table.insert(warnings, "STUDIO: all commands unlocked; profile changes use session-only mock data. Bans and universe announcements are simulated.") end
	if role == "Developer" or role == "Keonroot" then table.insert(warnings, "Self only. Shared match controls require a solo server.") end
	return {ok=true, role=role, studio=studio, placeKind=matchReady and "Match" or "Lobby", capabilities=capabilities, catalog=catalog, players=playerList, warnings=warnings, audit=Audit.Read(actor, role, studio)}
end
local function handle(actor, payload)
	local role = roleFor(actor)
	if role == "None" then
		if not lastDenial[actor] or os.clock()-lastDenial[actor]>5 then
			lastDenial[actor] = os.clock()
			Audit.Record(actor, role, "Access", actor.UserId, "denied", "Unprivileged remote request")
		end
		return fail("You do not have admin access.")
	end
	if type(payload) ~= "table" or type(payload.action) ~= "string" or #payload.action > 32 then return fail("Malformed request.") end
	local action = payload.action
	if action == "Snapshot" then return snapshot(actor, role) end
	if action == "Inventory" then
		local target, id = targetFor(actor, action, payload.targetUserId)
		authorize(actor, role, "TowerLevel", id)
		return {ok=true, towers=Persistent.Inventory(target)}
	end
	if action == "Confirm" then
		local intent = pending[actor]
		pending[actor] = nil -- Single-use even when confirmation fails.
		if not intent or type(payload.token) ~= "string" or intent.token ~= payload.token or os.clock() > intent.expires then return fail("Confirmation expired. Open the action again.") end
		local target, id = targetFor(actor, intent.action, intent.targetId)
		return run(actor, role, intent.action, target, id, intent.args)
	end
	if action == "Cancel" then
		local intent = pending[actor]
		if intent and type(payload.token) == "string" and intent.token == payload.token then pending[actor] = nil end
		return {ok=true, message="Action cancelled."}
	end
	if action == "Prepare" then
		local command = payload.command
		if not dangerous[command] then return fail("This command does not use confirmation.") end
		local args = cleanArgs(payload.args)
		local target, id = targetFor(actor, command, payload.targetUserId)
		authorize(actor, role, command, id)
		if command ~= "ResetData" then reasonFor(args) end
		if command == "Ban" and (not finite(args.duration) or args.duration % 1 ~= 0 or (args.duration ~= -1 and (args.duration < 60 or args.duration > 31536000))) then return fail("Enter a valid ban duration in seconds.") end
		local targetLabel = target and (target.DisplayName .. " (@" .. target.Name .. ")") or ("User " .. id)
		local titles = {Ban="Ban player?", Kick="Kick player?", Unban="Unban player?", ResetData="Reset player data?"}
		local summary = "Target: " .. targetLabel
		if args.reason then summary ..= "\nReason: " .. args.reason end
		if command == "Ban" then
			local duration
			if args.duration == -1 then duration = "Permanent"
			elseif args.duration % 86400 == 0 then duration = (args.duration / 86400) .. " day(s)"
			elseif args.duration % 3600 == 0 then duration = (args.duration / 3600) .. " hour(s)"
			elseif args.duration % 60 == 0 then duration = (args.duration / 60) .. " minute(s)"
			else duration = args.duration .. " seconds" end
			summary ..= "\nDuration: " .. duration
		end
		if command == "ResetData" then summary ..= studio and "\nResets this Studio session's profile." or "\nResets saved progress and disconnects the target." end
		local token = HttpService:GenerateGUID(false)
		pending[actor] = {token=token, action=command, targetId=id, args=args, expires=os.clock()+Config.ConfirmationSeconds}
		Audit.Record(actor, role, command, id, "prepared", summary)
		return {ok=true, token=token, title=titles[command], summary=summary}
	end
	if dangerous[action] then return fail("Prepare and confirm this action first.") end
	local args = cleanArgs(payload.args)
	local target, id = targetFor(actor, action, payload.targetUserId)
	return run(actor, role, action, target, id, args)
end
request.OnServerInvoke = function(actor, payload)
	if not consume(actor) then
		if not lastDenial[actor] or os.clock()-lastDenial[actor]>5 then
			lastDenial[actor] = os.clock()
			Audit.Record(actor, roles[actor] and roles[actor].role or "Unknown", "RateLimit", actor.UserId, "denied", "Remote request flood blocked")
		end
		return fail("Too many requests. Please wait a moment.")
	end
	if busy[actor] then return fail("Your previous command is still running.") end
	busy[actor] = true
	local ok, result = pcall(handle, actor, payload)
	busy[actor] = nil
	if not ok then return fail(tostring(result):sub(1, 350)) end
	return result
end
Players.PlayerRemoving:Connect(function(player)
	roles[player]=nil; buckets[player]=nil; busy[player]=nil; pending[player]=nil; lastDenial[player]=nil; commandTimes[player]=nil
end)
print("[ETD Admin] Ready · " .. (Match.Available() and "In Game" or "Lobby") .. (studio and " · Studio full access" or " · server permissions enforced"))
