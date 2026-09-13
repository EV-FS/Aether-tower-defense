local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Prepare = require(script.Parent.Prepare)
local ImpactTrack = require(script.Parent.ECS.ImpactTrack)

local ImpactFrames = {}
ImpactFrames.__index = ImpactFrames

function ImpactFrames.new(config)
	assert(config.EndFrame > 0, "ImpactFrames.EndFrame must be positive")
	assert(not config.FPS or config.FPS > 0, "ImpactFrames.FPS must be positive")
	local keys = ImpactTrack.Keys(config.Events)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneImpactFrames"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10000
	gui.Enabled = false
	local images, assets = {}, {}
	for _, frame in ipairs(keys) do
		local imageId = config.Events[frame]
		if imageId and not images[imageId] then
			local label = Instance.new("ImageLabel")
			label.Name = tostring(imageId)
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.BorderSizePixel = 0
			label.Image = "rbxassetid://" .. imageId
			label.ScaleType = Enum.ScaleType.Stretch
			label.ZIndex = 1
			label.Visible = false
			label.Parent = gui
			images[imageId] = label
			table.insert(assets, label)
		end
	end
	local persistentImage = nil
	if config.PersistentImage then
		local settings = config.PersistentImage
		persistentImage = Instance.new("ImageLabel")
		persistentImage.Name = "PersistentImage"
		persistentImage.Size = UDim2.fromScale(1, 1)
		persistentImage.BackgroundTransparency = 1
		persistentImage.BorderSizePixel = 0
		persistentImage.Image = "rbxassetid://" .. settings.ImageId
		persistentImage.ImageTransparency = settings.ImageTransparency or 0
		persistentImage.ScaleType = Enum.ScaleType.Stretch
		persistentImage.ZIndex = 2
		persistentImage.Parent = gui
		table.insert(assets, persistentImage)
	end
	-- Preload the actual labels before the client acknowledges cutscene readiness.
	local loaded = Prepare.Try("Impact image preload", 8, function()
		local failed = {}
		ContentProvider:PreloadAsync(assets, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failed, assetId .. " (" .. status.Name .. ")")
			end
		end)
		assert(#failed == 0, "Impact images failed: " .. table.concat(failed, ", "))
	end)
	if not loaded then
		gui:Destroy()
		warn("[CutsceneImpactFrames] Disabled for this playback because images were not ready; check image permissions/network.")
		return nil
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return setmetatable({ Gui = gui, Images = images, Current = false, Keys = keys, PersistentImage = persistentImage }, ImpactFrames)
end

function ImpactFrames:Show(imageId, isPlaying)
	-- Hiding a timed impact must not hide the persistent overlay. Update even
	-- when the event stays false across the scheduled start/end boundary.
	self.Gui.Enabled = isPlaying and (imageId ~= false or self.PersistentImage ~= nil)
	if self.Current == imageId then return end
	if self.Current then self.Images[self.Current].Visible = false end
	if imageId then self.Images[imageId].Visible = true end
	self.Current = imageId
end

function ImpactFrames:Destroy()
	self.Gui:Destroy()
end

return ImpactFrames
