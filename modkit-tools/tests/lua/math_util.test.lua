-- Offline unit tests for `scripts/modkit/math_util.lua` (`modkit.math`). Run with `npm test` in `modkit-tools`.

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/math_util.lua");

M = modkit.math; -- (a global: in Lua 4, `%upvalue` can only reach the immediately enclosing function)

--- Fails unless `actual` is within 0.000001 of `expected` (for results with floating point error).
function expectNear(actual, expected, label)
	if (type(actual) ~= "number" or abs(actual - expected) > 0.000001) then
		fail((label and (label .. ": ") or "") .. "expected about " .. expected .. ", got " .. show(actual));
	end
end

describe("round", function ()
	it("rounds to the nearest integer by default", function ()
		expectEq(M.round(2.4), 2);
		expectEq(M.round(2.6), 3);
		expectEq(M.round(-2.6), -3);
		expectEq(M.round(5), 5);
	end);
	it("rounds halves up (towards positive infinity)", function ()
		-- (pins current behaviour: `floor(num + 0.5)`, so negative halves round towards zero)
		expectEq(M.round(2.5), 3);
		expectEq(M.round(-2.5), -2);
	end);
	it("rounds to the nearest multiple of nearest_n", function ()
		expectEq(M.round(7, 5), 5);
		expectEq(M.round(8, 5), 10);
		expectEq(M.round(-7, 5), -5);
		expectEq(M.round(1234, 100), 1200);
	end);
	it("accepts a fractional nearest_n", function ()
		expectNear(M.round(1.234, 0.1), 1.2);
		expectNear(M.round(0.26, 0.25), 0.25);
	end);
end);

describe("modulo", function ()
	it("is the remainder for positive numbers", function ()
		expectEq(M.modulo(7, 3), 1);
		expectEq(M.modulo(6, 3), 0);
		expectEq(M.modulo(2, 5), 2);
	end);
	it("takes the sign of the divisor (unlike Lua 4's `mod`, which takes the dividend's)", function ()
		expectEq(M.modulo(-1, 5), 4);
		expectEq(M.modulo(7, -3), -2);
		expectEq(mod(-1, 5), -1, "Lua 4's mod, for comparison");
	end);
	it("works with fractions", function ()
		expectNear(M.modulo(5.5, 2), 1.5);
		expectNear(M.modulo(-0.5, 2), 1.5);
	end);
end);

finish();
