local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ResolveSoundAsset(soundPath: string): Sound?
	if soundPath == "" then
		return nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local current: Instance? = assets and assets:FindFirstChild("SFX")

	for name in string.gmatch(soundPath, "[^/]+") do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return if current and current:IsA("Sound") then current else nil
end

return ResolveSoundAsset
