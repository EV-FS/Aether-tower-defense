local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = require(ReplicatedStorage.Shared.Modules.Cutscene.FriendSelection)
local Profiles = {}

-- Session-owned, server-verified identities. Only descriptions + the selected ID
-- replicate, not the player's full friend list. No client-supplied user IDs.
function Profiles.Begin(state, actors)
	local folder = Instance.new("Folder")
	folder.Name = "ActorProfiles"
	folder.Parent = state
	local alive, entries = true, {}
	local random = Random.new()
	local function add(player)
		if not alive or entries[player] then return end
		local entry = Instance.new("Folder")
		entry.Name = tostring(player.UserId)
		entry.Parent = folder
		entries[player] = entry
		local roles = {}
		for _, role in actors do roles[role] = true end
		for role in roles do
			local slot = Instance.new("Folder")
			slot.Name = role
			slot.Parent = entry
			local done = false
			local function valid()
				return alive and not done and player.Parent == Players and slot.Parent ~= nil
			end
			task.delay(8, function()
				if valid() then
					done = true
					slot:SetAttribute("Status", "Timeout")
				end
			end)
			task.spawn(function()
				local ok, descriptionOrError = pcall(function()
					local userId = player.UserId
					if userId <= 0 then return nil end -- Studio test identities
					if role == "Friend" then
						local pages = Players:GetFriendsAsync(userId)
						repeat
							if not valid() then return nil end
							userId = Selection.FromPage(pages:GetCurrentPage(), player.UserId, function(count)
								return random:NextInteger(1, count)
							end)
							if userId or pages.IsFinished then break end
							pages:AdvanceToNextPageAsync()
						until false
						if not userId then return nil end
					end
					if not valid() then return nil end
					slot:SetAttribute("UserId", userId)
					-- Prefer the current in-game appearance for Self, including custom outfits.
					local humanoid = role == "Self" and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and player:HasAppearanceLoaded() then return humanoid:GetAppliedDescription() end
					return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
				end)
				if not valid() then
					if ok and descriptionOrError then descriptionOrError:Destroy() end
					return
				end
				done = true
				if ok and descriptionOrError then
					descriptionOrError.Name = "Description"
					descriptionOrError.Parent = slot
					slot:SetAttribute("Status", "Ready")
				else
					slot:SetAttribute("Status", if ok then "Unavailable" else "Failed")
					if not ok then warn("[CutsceneProfiles] " .. player.Name .. "/" .. role .. ": " .. tostring(descriptionOrError)) end
				end
			end)
		end
	end
	local added = Players.PlayerAdded:Connect(add)
	local removing = Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		entries[player] = nil
		if entry then entry:Destroy() end
	end)
	for _, player in Players:GetPlayers() do add(player) end
	return function()
		alive = false
		added:Disconnect()
		removing:Disconnect()
		table.clear(entries)
	end
end
return Profiles
