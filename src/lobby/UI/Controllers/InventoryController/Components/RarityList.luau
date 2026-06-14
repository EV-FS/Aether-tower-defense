local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local State = require(script.Parent.Parent.State)
local TowerButton = require(script.Parent.TowerButton)

return function(props)
	local sortedEntries = Vide.derive(function()
		local list = table.clone(props.ListSource())
		local slots = State.EquippedSlots()

		table.sort(list, function(a, b)
			local aSlot, bSlot
			for _, t in ipairs(a.Stack.Towers) do
				local id = State.generateTowerId(a.Name, t.Key)
				local s = id and slots[id]
				if s and (not aSlot or s < aSlot) then
					aSlot = s
				end
			end
			for _, t in ipairs(b.Stack.Towers) do
				local id = State.generateTowerId(b.Name, t.Key)
				local s = id and slots[id]
				if s and (not bSlot or s < bSlot) then
					bSlot = s
				end
			end

			if aSlot ~= bSlot then
				return (aSlot or 9999) < (bSlot or 9999)
			end
			if a.RarityRank ~= b.RarityRank then
				return a.RarityRank < b.RarityRank
			end
			if a.Name ~= b.Name then
				return a.Name < b.Name
			end

			local aLevel = a.Data and a.Data.Lv or 0
			local bLevel = b.Data and b.Data.Lv or 0
			if aLevel ~= bLevel then
				return aLevel > bLevel
			end

			return tostring(a.Key) < tostring(b.Key)
		end)
		return list
	end)

	return Vide.create("Frame")({
		Name = props.Rarity,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.979, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = function()
			return props.Exist() and props.Opened()
		end,

		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			ItemLineAlignment = Enum.ItemLineAlignment.End,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),

		Vide.indexes(sortedEntries, TowerButton),
	})
end
