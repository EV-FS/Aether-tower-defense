local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Recipe paths are relative to ReplicatedStorage.Assets.SFX.
return function(soundPath: string): Sound?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local current: Instance? = assets and assets:FindFirstChild("SFX")

	for name in string.gmatch(soundPath, "[^/]+") do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	if current and current:IsA("Sound") then
		return current
	end

	return nil
end
