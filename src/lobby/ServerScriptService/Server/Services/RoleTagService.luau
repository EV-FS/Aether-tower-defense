local Players = game:GetService("Players")

local GROUP_ID = 492293332
local ROLE_TAG_RANKS = {
	[250] = true,
}

local RoleTagService = {}

local function updateRoleTag(player: Player)
	local success, rank = pcall(player.GetRankInGroupAsync, player, GROUP_ID)
	if not success or not ROLE_TAG_RANKS[rank] then
		player:SetAttribute("ChatRoleTag", nil)
		return
	end

	local roleSuccess, roleName = pcall(player.GetRoleInGroupAsync, player, GROUP_ID)
	if roleSuccess and type(roleName) == "string" and roleName ~= "" then
		player:SetAttribute("ChatRoleTag", roleName)
	else
		player:SetAttribute("ChatRoleTag", "Developer")
	end
end

function RoleTagService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(updateRoleTag, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(updateRoleTag, player)
	end)
end

return RoleTagService
