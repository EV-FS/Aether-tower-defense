-- Pure permission rules, shared by requests and their confirmation step.
local Policy = {}
Policy.Actions = {"SpawnUnit", "SpawnEnemy", "Money", "GameSpeed", "Announce", "Ban", "Kick", "Unban", "GiveItem", "GiveCurrency", "ResetData", "GiveTower", "TowerLevel", "Trait"}
-- Only these exact spellings are accepted; display strings are canonical everywhere else.
local roleAliases = {
	Keonroot="Keonroot", KeonRoot="Keonroot", Admin="Admin", Developer="Developer",
	["Head developer"]="Head developer", HeadDeveloper="Head developer",
	Owner="Owner", HeadOwner="Owner",
}
function Policy.NormalizeRole(role)
	return type(role) == "string" and roleAliases[role] or nil
end
function Policy.ValidRole(role)
	return Policy.NormalizeRole(role) ~= nil
end
function Policy.GroupRole(rank, name, rankRoles, nameRoles)
	if type(rank) ~= "number" or rank ~= rank or rank % 1 ~= 0 or rank < 1 or rank > 255 then return nil end
	if rank == 255 then return "Owner" end
	-- An explicit numeric override takes priority, including invalid entries that fail closed.
	if rankRoles[rank] ~= nil then return Policy.NormalizeRole(rankRoles[rank]) end
	if type(name) == "string" then return Policy.NormalizeRole(nameRoles[name]) end
	return nil
end
function Policy.GroupMembershipRole(membership, rankRoles, nameRoles)
	if type(membership) ~= "table" or membership.IsMember ~= true or type(membership.Roles) ~= "table" then return nil end
	local role, highestRank = nil, -1
	for _, groupRole in ipairs(membership.Roles) do
		if type(groupRole) == "table" then
			local candidate = Policy.GroupRole(groupRole.Rank, groupRole.Name, rankRoles, nameRoles)
			if candidate and groupRole.Rank > highestRank then
				role, highestRank = candidate, groupRole.Rank
			end
		end
	end
	return role
end
local known = {}
for _, action in ipairs(Policy.Actions) do known[action] = true end
local selfActions = {SpawnUnit=true, SpawnEnemy=true, Money=true, GameSpeed=true, GiveItem=true, GiveCurrency=true, ResetData=true, GiveTower=true, TowerLevel=true, Trait=true}
local sharedMatch = {SpawnUnit=true, SpawnEnemy=true, GameSpeed=true}
function Policy.Allowed(role, studio, action, actorId, targetId, playerCount)
	if not known[action] then return false, "Unknown command." end
	role = Policy.NormalizeRole(role)
	if studio or role == "Owner" or role == "Head developer" then return true end
	if role == "Admin" then
		return action == "Ban" or action == "Kick", "Admins can ban and kick only."
	end
	if role == "Developer" or role == "Keonroot" then
		if not selfActions[action] then return false, "This role cannot moderate or announce." end
		if targetId ~= actorId then return false, "Your role can change your own data only." end
		if sharedMatch[action] and playerCount > 1 then
			return false, "Spawns and match speed affect everyone; your role can use them in a solo server only."
		end
		return true
	end
	return false, "You do not have admin access."
end
return Policy
