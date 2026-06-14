return function(_, best, new)
	if new.Health > best.Health then
		return true
	elseif new.Health == best.Health then
		return new.PathAlpha > best.PathAlpha
	else
		return false
	end
end
