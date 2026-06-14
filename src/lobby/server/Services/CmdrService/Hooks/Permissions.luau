local GROUP_ID = 492293332
local ADMINS = {
	[1242101228] = true,
	[1308083463] = true,
	[3409318128] = true,
	[5034834338] = true,
	[7092748279] = true,
}

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local player = context.Executor

		local isInAdminsList = ADMINS[player.UserId]
		local isHaveAdminRole = player:GetRoleInGroup(GROUP_ID) == "Developer"

		if not isInAdminsList and not isHaveAdminRole then
			return "이 명령어를 사용할 권한이 없습니다."
		end
	end)
end
