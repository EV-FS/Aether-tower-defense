-- Solve x(t) = progress, then sample y(t); y may overshoot while x must be monotonic.
local CubicBezier = {}

function CubicBezier.Create(params)
	params = params or {}
	local x1, y1 = params.X1 or params.x1 or 0.25, params.Y1 or params.y1 or 0.1
	local x2, y2 = params.X2 or params.x2 or 0.25, params.Y2 or params.y2 or 1
	for _, value in { x1, y1, x2, y2 } do
		assert(type(value) == "number" and value == value and math.abs(value) < math.huge, "Bezier controls must be finite numbers")
	end
	assert(x1 >= 0 and x1 <= 1 and x2 >= 0 and x2 <= 1, "Bezier X controls must be in [0, 1]")
	local function sample(t, a, b)
		local inverse = 1 - t
		return 3 * inverse * inverse * t * a + 3 * inverse * t * t * b + t * t * t
	end
	return function(alpha)
		if alpha <= 0 then return 0 end
		if alpha >= 1 then return 1 end
		local guess = alpha
		for _ = 1, 6 do
			local errorX = sample(guess, x1, x2) - alpha
			if math.abs(errorX) < 1e-7 then return sample(guess, y1, y2) end
			local inverse = 1 - guess
			local derivative = 3 * inverse * inverse * x1 + 6 * inverse * guess * (x2 - x1)
				+ 3 * guess * guess * (1 - x2)
			if math.abs(derivative) < 1e-7 then break end
			local nextGuess = guess - errorX / derivative
			if nextGuess < 0 or nextGuess > 1 then break end
			guess = nextGuess
		end
		local low, high = 0, 1
		for _ = 1, 30 do
			guess = (low + high) * 0.5
			local x = sample(guess, x1, x2)
			if math.abs(x - alpha) < 1e-7 then break end
			if x < alpha then low = guess else high = guess end
		end
		return sample(guess, y1, y2)
	end
end

return CubicBezier
