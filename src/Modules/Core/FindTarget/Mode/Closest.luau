return function(self, best, new)
	local newOffset = self.Position - new.Position
	local bestOffset = self.Position - best.Position

	return newOffset.X ^ 2 + newOffset.Z ^ 2 < bestOffset.X ^ 2 + bestOffset.Z ^ 2
end
