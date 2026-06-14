local CustomHandlers = {}

function CustomHandlers.Hacked(_, sourceModel, targetModel)
	local target = targetModel or sourceModel
	if not target then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(0, 241, 12)
	highlight.FillTransparency = -10
	highlight.OutlineTransparency = 1
	highlight.Parent = target

	for _, descendant: Instance in target:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Texture") then
			descendant:Destroy()
		elseif descendant:IsA("MeshPart") then
			descendant.TextureID = ""
		end

		if descendant:IsA("BasePart") then
			if target.PrimaryPart == descendant or target.Name == "HumanoidRootPart" then
				descendant.Transparency = 1
				continue
			end
			descendant.Material = Enum.Material.Glass
			descendant.Color = Color3.new(0.25, 0.5, 0)
			descendant.Transparency = -10000
			descendant.Reflectance = 10000
		end
	end
end

return CustomHandlers
