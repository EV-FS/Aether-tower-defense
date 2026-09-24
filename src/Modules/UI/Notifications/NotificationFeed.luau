local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local LogMessage = require(script.Parent.LogMessage)

local create = Vide.create
local source = Vide.source
local values = Vide.values

local entries = source({})
local nextId = 0
local DEFAULT_LIFETIME = 3
local MAX_ENTRIES = 5

local NotificationFeed = {}

local function push(entry, lifetime: number?)
	nextId += 1
	entry.Id = nextId
	entry.State = source("Entering")

	local updated = table.clone(entries())
	table.insert(updated, entry)
	while #updated > MAX_ENTRIES do
		table.remove(updated, 1)
	end
	entries(updated)

	-- Leave one render frame in the entering state so the spring can animate in.
	task.delay(0.05, function()
		entry.State("Alive")
	end)
	task.delay(lifetime or DEFAULT_LIFETIME, function()
		entry.State("Leaving")
		task.delay(0.4, function()
			local current = table.clone(entries())
			local index = table.find(current, entry)
			if index then
				table.remove(current, index)
				entries(current)
			end
		end)
	end)
end

function NotificationFeed.Pull(message: string, logType: string?, lifetime: number?)
	push({ Message = message or "", LogType = logType or "Normal" }, lifetime)
end

function NotificationFeed.PullItem(itemName: string, amount: number, lifetime: number?)
	if not ItemData.ByName[itemName] or typeof(amount) ~= "number" or amount <= 0 then
		return
	end
	push({ ItemName = itemName, Amount = amount }, lifetime)
end

function NotificationFeed.RenderUI()
	return create("Frame")({
		Name = "Log",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.075),
		Size = UDim2.fromScale(0.45, 0.5),
		Visible = true,
		ZIndex = 100,
		values(entries, function(entry)
			return LogMessage({
				Message = entry.Message,
				LogType = entry.LogType,
				ItemName = entry.ItemName,
				Amount = entry.Amount,
				LayoutOrder = entry.Id,
				State = entry.State,
			})
		end),
		create("UIListLayout")({
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

return NotificationFeed
