local HttpService = game:GetService("HttpService")
local WEBHOOK_URL =
	"https://discord.com/api/webhooks/1507585620757975131/CKuar5nPeDA6fjsYKvP0W8_Dv9a25oJ8ahnhzsPc0gVtSRRWgpGI6x_AdRaJNiqoxlom"

return function(title: string, description: string, executor: Player, player: Player, arg)
	local fields = {
		{ name = "실행자 유저", value = `{executor.Name} ({executor.UserId})`, inline = true },
		{ name = "대상 유저", value = `{player.Name} ({player.UserId})`, inline = true },
	}

	if arg and typeof(arg) == "table" then
		for argName, argValue in arg do
			table.insert(fields, {
				name = tostring(argName),
				value = tostring(argValue),
				inline = true,
			})
		end
	end

	local payload = HttpService:JSONEncode({
		["username"] = "커맨드 로그",
		["embeds"] = {
			{
				["title"] = title,
				["description"] = description,
				["color"] = 5814783,
				["fields"] = fields,
				["timestamp"] = DateTime.now():ToIsoDate(),
			},
		},
	})

	pcall(function()
		return HttpService:PostAsync(WEBHOOK_URL, payload)
	end)
end
