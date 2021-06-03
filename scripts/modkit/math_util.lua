--Math utility functions.

if (modkit == nil) then modkit = {}; end

if (modkit.math == nil) then
	modkit.math = {
		round = function (num, numDecimalPlaces)
			local mult = 10^(numDecimalPlaces or 0)
			return floor(num * mult + 0.5) / mult
		end,
		modulo = function (n, m)
			return n - floor(n / m) * m
		end,
		pow = function (n, m)
			local out = 1
			for i = 0, m do
				out = out * n
			end
			return out
		end
	}
	print("math_util init")
end