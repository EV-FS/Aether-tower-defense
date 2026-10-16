local Players = game:GetService("Players")
local Aura = require(script.Aura)
local bound = {}

local function addPlayer(player)
	if bound[player] then
		return
	end
	local state = { ready = false, auraName = nil }
	bound[player] = state
	local function applyCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 15)
		local head = character:WaitForChild("Head", 15)
		if not root or not head or not state.ready or player.Character ~= character then
			return
		end
		local ok, message = Aura.Apply(character, state.auraName)
		if not ok then
			warn("[CharacterAura] " .. tostring(message))
		end
	end
	state.connection = player.CharacterAdded:Connect(applyCharacter)
	task.spawn(function()
		local rank = 0
		if player.UserId ~= Aura.SpecialUserId then
			local success = false
			for attempt = 1, 3 do
				local ok, result = pcall(player.GetRankInGroupAsync, player, Aura.GroupId)
				if ok and type(result) == "number" then
					rank = result
					success = true
					break
				end
				if attempt < 3 then
					task.wait(attempt)
				end
			end
			if not success then
				warn("[CharacterAura] Group rank lookup failed for " .. player.Name)
			end
		end
		if bound[player] ~= state then
			return
		end
		state.auraName = Aura.Select(player.UserId, rank)
		state.ready = true
		if player.Character then
			applyCharacter(player.Character)
		end
	end)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local state = bound[player]
	if state then
		state.connection:Disconnect()
	end
	bound[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end
