-- src/Settings/Data/NPCS/Sounds/SoundLibrary.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundsFolder = ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Data"):WaitForChild("NPCS"):WaitForChild("Sounds")

return function(soundName: string): Sound?
    return SoundsFolder:FindFirstChild(soundName) :: Sound?
end
