local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)

local TopbarFactory = {}
local Factory = {}
Factory.__index = Factory

TopbarFactory.Assets = table.freeze({
	Emote = "rbxassetid://111864869864776",
	Exit = "rbxassetid://100029434862717",
	Speed = "rbxassetid://108383245414954",
	Settings = "rbxassetid://119479235757807",
})

local ICON_THEME = {
	{ "Widget", "DesiredWidth", 46 },
	{ "Widget", "MinimumWidth", 46 },
	{ "Widget", "MinimumHeight", 46 },
	{ "Widget", "BorderSize", 0 },
	{ "IconButton", "BackgroundColor3", Color3.fromRGB(20, 20, 23) },
	{ "IconButton", "BackgroundTransparency", 1 },
	{ "IconCorners", "CornerRadius", UDim.new(1, 0) },
	{ "IconImageScale", "Value", 0.5 },
	{ "IconSpot", "BackgroundColor3", Color3.fromRGB(18, 18, 21) },
	{ "IconSpot", "BackgroundTransparency", 0.08 },
	{ "IconSpot", "BackgroundTransparency", 0.08, "Selected" },
}

local GROUP_THEME = {
	{ "Widget", "DesiredWidth", 46 },
	{ "Widget", "MinimumWidth", 46 },
	{ "Widget", "MinimumHeight", 46 },
	{ "Widget", "BorderSize", 0 },
	{ "IconButton", "BackgroundColor3", Color3.fromRGB(20, 20, 23) },
	{ "IconButton", "BackgroundTransparency", 1 },
	{ "IconCorners", "CornerRadius", UDim.new(0, 17) },
	{ "IconImageScale", "Value", 0.5 },
	{ "IconSpot", "BackgroundTransparency", 1 },
	{ "IconSpot", "BackgroundTransparency", 1, "Selected" },
}

local GROUP_CONTAINER_THEME = {
	{ "Widget", "MinimumHeight", 46 },
	{ "Widget", "BorderSize", 0 },
	{ "IconButton", "BackgroundTransparency", 1 },
	{ "IconCorners", "CornerRadius", UDim.new(1, 0) },
	{ "Menu", "BackgroundColor3", Color3.fromRGB(18, 18, 21) },
	{ "Menu", "BackgroundTransparency", 0.08 },
	{ "MenuUIListLayout", "Padding", UDim.new(0, 0) },
}

function TopbarFactory.new()
	local rightHolder = Topbarplus.container.TopbarStandard.Holders.Right
	local rightLayout = rightHolder:FindFirstChildOfClass("UIListLayout")
	if rightLayout then
		rightLayout.Padding = UDim.new(0, 6)
	end

	return setmetatable({
		_icons = {},
		_connections = {},
	}, Factory)
end

function Factory:_rememberIcon(icon)
	table.insert(self._icons, icon)
	return icon
end

function Factory:TrackConnection(connection)
	table.insert(self._connections, connection)
	return connection
end

function Factory:CreateImage(assetName: string, caption: string, order: number, standalone: boolean?)
	local image = TopbarFactory.Assets[assetName] or assetName
	local icon = self:_rememberIcon(Topbarplus.new())
	icon:setImage(image)
	icon:setImageScale(0.54)
	icon:setCaption(caption)
	icon:setOrder(order)

	if standalone ~= false then
		icon:align("Right")
		icon:modifyTheme(ICON_THEME)
	end

	return icon
end


function Factory:CreateLabel(label: string, caption: string, width: number?)
	local icon = self:_rememberIcon(Topbarplus.new())
	icon:setLabel(label)
	icon:setWidth(width or 64)
	icon:setTextSize(15)
	icon:setCaption(caption)
	return icon
end

function Factory:CreateGroup(icons: { any }, order: number)
	local groupIcon = self:_rememberIcon(Topbarplus.new())
	groupIcon:align("Right")
	groupIcon:setOrder(order)
	groupIcon:modifyChildTheme(GROUP_THEME)
	groupIcon:setFixedMenu(icons)
	groupIcon:modifyTheme(GROUP_CONTAINER_THEME)

	local menu = groupIcon:getInstance("Menu")
	local menuCorner = Instance.new("UICorner")
	menuCorner.Name = "GroupCorner"
	menuCorner.CornerRadius = UDim.new(1, 0)
	menuCorner.Parent = menu

	return groupIcon
end

function Factory:BindToggle(icon, onOpen: () -> (), onClose: () -> ())
	self:TrackConnection(icon.selected:Connect(onOpen))
	self:TrackConnection(icon.deselected:Connect(onClose))
	return icon
end

function Factory:BindOneClick(icon, callback: () -> ())
	icon:oneClick()
	self:TrackConnection(icon.selected:Connect(callback))
	return icon
end

function Factory:Destroy()
	for index = #self._connections, 1, -1 do
		self._connections[index]:Disconnect()
	end
	table.clear(self._connections)

	for index = #self._icons, 1, -1 do
		self._icons[index]:destroy()
	end
	table.clear(self._icons)
end

return TopbarFactory
