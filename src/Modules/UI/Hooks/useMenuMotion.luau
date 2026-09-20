local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local MenuMotion = require(script.Parent.Parent.MenuMotion)

local function scaleSize(size: UDim2, x: number, y: number): UDim2
	return UDim2.new(size.X.Scale * x, size.X.Offset * x, size.Y.Scale * y, size.Y.Offset * y)
end

-- Keep controller visibility authoritative for gameplay; only the presentation
-- stays mounted during an exit. A view switch hides the previous menu immediately.
return function(isVisible: () -> boolean, getActiveView: () -> string?)
	local isOpen = Vide.source(false)
	local isMounted = Vide.source(false)
	local mounted = false
	local generation = 0

	Vide.effect(function()
		local shouldOpen = isVisible()
		local activeView = getActiveView()
		generation += 1
		local token = generation
		if shouldOpen then
			if mounted then
				isOpen(true)
			else
				mounted = true
				isMounted(true)
				-- Let springs start at the closed pose, including an initially open menu.
				task.defer(function()
					if generation == token then
						isOpen(true)
					end
				end)
			end
		else
			isOpen(false)
			if activeView ~= nil then
				mounted = false
				isMounted(false)
			elseif mounted then
				task.delay(MenuMotion.ExitDuration, function()
					if generation == token then
						mounted = false
						isMounted(false)
					end
				end)
			end
		end
	end)
	Vide.cleanup(function()
		generation += 1
	end)

	local motion = { IsOpen = isOpen, IsMounted = isMounted }

	function motion:Spring(open, closed, profileName: string)
		local profile = MenuMotion[profileName]
		assert(profile, `Unknown menu motion profile: {profileName}`)
		local value = Vide.spring(function()
			return if isOpen() then open else closed
		end, profile.Period, profile.Damping)
		return value
	end

	function motion:WindowSize(size: UDim2)
		return self:Spring(size, scaleSize(size, MenuMotion.WindowWidthRatio, 1), "Window")
	end

	function motion:WindowRotation()
		return self:Spring(0, -4, "Rotation")
	end

	function motion:HeaderPosition(position: UDim2)
		return self:Spring(position, position - UDim2.fromScale(0.0426388, 0), "Header")
	end

	function motion:IconRotation()
		return self:Spring(0, -90, "IconRotation")
	end

	function motion:IconSize(size: UDim2)
		return self:Spring(size, scaleSize(size, MenuMotion.IconSizeRatio, MenuMotion.IconSizeRatio), "IconSize")
	end

	function motion:CloudPosition(position: UDim2)
		return self:Spring(position, position - UDim2.fromScale(0.154887, 0), "Cloud")
	end

	function motion:Fade()
		return self:Spring(0, 1, "Fade")
	end

	function motion:ClosePosition(position: UDim2)
		return self:Spring(position, UDim2.new(0.2, position.X.Offset, position.Y.Scale, position.Y.Offset), "ClosePosition")
	end

	function motion:CloseRotation()
		return self:Spring(0, -1800, "CloseRotation")
	end

	function motion:ContentPosition(position: UDim2)
		return self:Spring(position, position - UDim2.fromScale(0.0639824, 0), "Content")
	end

	function motion:SearchSize(size: UDim2)
		return self:Spring(size, scaleSize(size, 0, 1), "Search")
	end

	motion.Transparency = motion:Spring(0, 1, "Visibility")
	return motion
end
