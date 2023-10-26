--Math utility functions.

if (modkit == nil) then modkit = {}; end

if (modkit.math == nil) then
	modkit.math = {
		--- Rounds `num` to the nearest factor of `to_nearest`. Fractional values are accepted.
		---
		---@param num number
		---@param nearest_n? number Quantity to round 'to', default `1`
		---@return number
		round = function (num, nearest_n)
			nearest_n = nearest_n or 1;

			if (nearest_n == 1) then
				return floor(num + 0.5);
			end

			return modkit.math.round(num / nearest_n) * nearest_n;
		end,
		modulo = function (n, m)
			return n - floor(n / m) * m
		end,
		--- Raises `n` to the integer power `m`.
		---@param n number
		---@param m integer
		---@return number
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