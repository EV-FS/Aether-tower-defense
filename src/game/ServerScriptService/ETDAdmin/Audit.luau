local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Audit = {}
local entries, queue = {}, {}
local deliveryStatus = Config.WebhookUrl == "" and "Discord webhook is not configured." or "Discord delivery is ready."
if RunService:IsStudio() and Config.WebhookUrl ~= "" and not Config.WebhookEnabledInStudio then
	deliveryStatus = "Discord audit is configured; delivery is disabled in Studio."
end
local sequence = 0
local function truncate(text, limit)
	text = tostring(text)
	if #text <= limit then return text end
	local nextCharacter = utf8.offset(text, 0, limit + 1)
	return text:sub(1, (nextCharacter or limit + 1) - 1)
end
function Audit.Record(actor, role, action, targetId, outcome, detail)
	sequence += 1
	local entry = {
		id = sequence, time = os.time(), actor = actor.Name, actorId = actor.UserId,
		role = role, action = truncate(action, 48), targetId = targetId,
		outcome = outcome, detail = truncate(detail or "", 300),
		placeId = game.PlaceId, jobId = game.JobId,
	}
	table.insert(entries, 1, entry)
	if #entries > Config.AuditCapacity then table.remove(entries) end
	if Config.WebhookUrl ~= "" and (not RunService:IsStudio() or Config.WebhookEnabledInStudio) then
		if #queue < 100 then table.insert(queue, entry) else deliveryStatus = "Discord queue is full; check server output." end
	end
	if outcome == "denied" then warn("[ETD Admin] denied", entry.actorId, entry.action, entry.detail) end
	return entry
end
function Audit.Read(actor, role, studio)
	local result = {}
	for _, entry in ipairs(entries) do
		if studio or role == "Owner" or role == "Head developer" or entry.actorId == actor.UserId then
			table.insert(result, table.clone(entry))
			if #result == 30 then break end
		end
	end
	return result
end
function Audit.Status() return deliveryStatus end
task.spawn(function()
	while true do
		task.wait(5)
		if #queue == 0 then continue end
		local batch = {}
		-- Three bounded records fit without silently dropping trailing audit entries.
		for _ = 1, math.min(#queue, 3) do table.insert(batch, table.remove(queue, 1)) end
		local lines = {}
		for _, entry in ipairs(batch) do
			table.insert(lines, string.format("[%s] %s (%d) · %s · %s → %s · %s", entry.outcome, entry.actor, entry.actorId, entry.role, entry.action, tostring(entry.targetId), entry.detail))
		end
		local ok, response = pcall(function()
			local body = HttpService:JSONEncode({username="Aether Admin", content=truncate(table.concat(lines, "\n"), 1900), allowed_mentions={parse={}}})
			return HttpService:RequestAsync({Url=Config.WebhookUrl, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
		end)
		if ok and response.Success then
			deliveryStatus = "Discord audit delivered at " .. os.date("!%H:%M:%S UTC")
		else
			deliveryStatus = "Discord delivery failed; check HTTP access and server webhook configuration."
			warn("[ETD Admin] " .. deliveryStatus)
			-- Bounded retries; do not flood Discord or grow memory indefinitely.
			for _, entry in ipairs(batch) do
				entry.retries = (entry.retries or 0) + 1
				if entry.retries < 3 and #queue < 100 then table.insert(queue, entry) end
			end
			task.wait(10)
		end
	end
end)
return Audit
