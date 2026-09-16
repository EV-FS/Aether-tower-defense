-- Server-only settings. Never move this module into ReplicatedStorage.
return {
	StudioFullAccess = true,
	-- Studio never sends Discord webhooks or calls Roblox's persistent ban API.
	WebhookUrl = "https://discord.com/api/webhooks/1507585620757975131/CKuar5nPeDA6fjsYKvP0W8_Dv9a25oJ8ahnhzsPc0gVtSRRWgpGI6x_AdRaJNiqoxlom",
	WebhookEnabledInStudio = false,
	GroupId = 486359985,
	-- Exact numeric group ranks; leave empty until your roles exist.
	GroupRankRoles = {}, -- [255] = "Owner", [200] = "Head developer"
	-- Exact group role names; the pictured HeadOwner role has Owner permissions.
	GroupNameRoles = {
		KeonRoot = "Keonroot", Keonroot = "Keonroot",
		Admin = "Admin", Developer = "Developer",
		HeadDeveloper = "Head developer", ["Head developer"] = "Head developer",
		HeadOwner = "Owner", Owner = "Owner",
	},
	UserRoles = {}, -- [123456789] = "Developer" (use immutable UserIds)
	OwnerUserIds = {7092748279}, -- EvanforsaIe: full access,
	AnnouncementTopic = "ETD_Admin_Announcement_v1",
	AuditCapacity = 100,
	ConfirmationSeconds = 30,
	RequestBurst = 12,
	RequestsPerSecond = 3,
}
