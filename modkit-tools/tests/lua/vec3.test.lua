-- Offline unit tests for `scripts/modkit/vec3.lua` (`Vec3`). Run with `npm test` in `modkit-tools`.
--
-- Vec3s are tagged tables (their `gettable`/`settable` tag methods map x/y/z to 1/2/3), so they're compared by their components.

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/table_util.lua");
loadQuietly("scripts/modkit/vec3.lua");

--- A Vec3's components as a plain list.
function components(vec)
	if (type(vec) ~= "table") then
		return vec;
	end
	return { vec[1], vec[2], vec[3] };
end

--- Fails unless `vec` is a Vec3 (has the instance tag) with the components `expected`.
function expectVec(vec, expected, label)
	expectTruthy(type(vec) == "table" and tag(vec) == VEC3_INSTANCE_TAG, (label and (label .. ": ") or "") .. "a tagged Vec3");
	expectEq(components(vec), expected, label);
end

--- Fails unless `actual` is within 0.0001 of `expected`.
function expectNear(actual, expected, label)
	if (type(actual) ~= "number" or abs(actual - expected) > 0.0001) then
		fail((label and (label .. ": ") or "") .. "expected about " .. expected .. ", got " .. show(actual));
	end
end

describe("creating", function ()
	it("Vec3(list) copies the first three values", function ()
		expectVec(Vec3({ 1, 2, 3 }), { 1, 2, 3 });
		expectVec(Vec3:create({ 4, 5, 6 }), { 4, 5, 6 });
	end);
	it("fills missing values with 0", function ()
		expectVec(Vec3(), { 0, 0, 0 });
		expectVec(Vec3({ 1 }), { 1, 0, 0 });
	end);
	it("Vec3(number) repeats the number", function ()
		expectVec(Vec3(2), { 2, 2, 2 });
	end);
	it("makes a new table, even from a Vec3", function ()
		local original = Vec3({ 1, 2, 3 });
		local copy = Vec3(original);
		expectTruthy(copy ~= original, "a new table");
		expectVec(copy, { 1, 2, 3 });
	end);
	it("shares one tag between all vectors (a tag per vector leaked)", function ()
		expectEq(tag(Vec3({ 1, 2, 3 })), tag(Vec3({ 4, 5, 6 })));
	end);
end);

describe("x / y / z", function ()
	it("read the components", function ()
		local v = Vec3({ 1, 2, 3 });
		expectEq({ v.x, v.y, v.z }, { 1, 2, 3 });
	end);
	it("write the components", function ()
		local v = Vec3({ 1, 2, 3 });
		v.x = 7;
		v.z = 9;
		expectVec(v, { 7, 2, 9 });
	end);
	it("ignore any other key (reads give nil, writes do nothing)", function ()
		local v = Vec3({ 1, 2, 3 });
		---@diagnostic disable-next-line: inject-field
		v.foo = 5; -- (not a Vec3 field, on purpose)
		expectNil(v.foo);
		expectNil(rawget(v, "foo"));
	end);
end);

describe("operators", function ()
	it("+ and - work with Vec3s, plain lists, and numbers", function ()
		expectVec(Vec3({ 1, 2, 3 }) + Vec3({ 10, 20, 30 }), { 11, 22, 33 });
		expectVec(Vec3({ 1, 2, 3 }) + { 1, 1, 1 }, { 2, 3, 4 });
		expectVec(Vec3({ 1, 2, 3 }) + 1, { 2, 3, 4 });
		expectVec(Vec3({ 10, 20, 30 }) - Vec3({ 1, 2, 3 }), { 9, 18, 27 });
		expectVec(10 - Vec3({ 1, 2, 3 }), { 9, 8, 7 });
	end);
	it("unary - negates", function ()
		expectVec(-Vec3({ 1, -2, 3 }), { -1, 2, -3 });
	end);
	it("* and / scale by a number, on either side", function ()
		expectVec(Vec3({ 1, 2, 3 }) * 2, { 2, 4, 6 });
		expectVec(2 * Vec3({ 1, 2, 3 }), { 2, 4, 6 });
		expectVec(Vec3({ 2, 4, 6 }) / 2, { 1, 2, 3 });
	end);
	it("* refuses two vectors (use dot or cross)", function ()
		print = function () end; -- (it prints an error)
		local product = Vec3({ 1, 2, 3 }) * Vec3({ 1, 2, 3 });
		print = HARNESS_PRINT;
		expectNil(product);
	end);
	it("^ raises each component", function ()
		expectVec(Vec3({ 1, 2, 3 }) ^ 2, { 1, 4, 9 });
	end);
	it("don't change their operands", function ()
		local a = Vec3({ 1, 2, 3 });
		local _ = a + a;
		_ = -a;
		_ = a * 2;
		expectVec(a, { 1, 2, 3 });
	end);
	it(".. concatenates as a readable string", function ()
		local str = "pos: " .. Vec3({ 1, 2, 3 });
		expectTruthy(strfind(str, "pos: {", 1, 1), "starts with the other string");
		expectTruthy(strfind(str, "[1]: 1", 1, 1) and strfind(str, "[2]: 2", 1, 1) and strfind(str, "[3]: 3", 1, 1), "has each component");
	end);
end);

describe("isVec3Like", function ()
	it("is 1 for anything with numbers at 1, 2 and 3", function ()
		expectEq(Vec3:isVec3Like({ 1, 2, 3 }), 1);
		expectEq(Vec3:isVec3Like(Vec3({ 1, 2, 3 })), 1);
		expectEq(Vec3:isVec3Like({ 1, 2, 3; extra = "ok" }), 1);
	end);
	it("is nil otherwise", function ()
		expectNil(Vec3:isVec3Like({ 1, 2 }));
		expectNil(Vec3:isVec3Like({ 1, 2, "3" }));
		expectNil(Vec3:isVec3Like(5));
		expectNil(Vec3:isVec3Like(nil));
	end);
end);

describe("isVec3", function ()
	it("is 1 for a list of exactly three numbers, or a Vec3", function ()
		expectEq(Vec3:isVec3({ 1, 2, 3 }), 1);
		expectEq(Vec3:isVec3(Vec3({ 1, 2, 3 })), 1);
	end);
	it("is nil with any other key, or for non-tables", function ()
		expectNil(Vec3:isVec3({ 1, 2, 3, 4 }));
		expectNil(Vec3:isVec3({ 1, 2, 3; extra = 1 }));
		expectNil(Vec3:isVec3("1 2 3"));
	end);
	it("is nil when a component isn't a number", function ()
		expectNil(Vec3:isVec3({ 1, 2, "a" }));
	end);
end);

describe("magnitude / mag", function ()
	it("is the vector's length", function ()
		expectEq(Vec3:magnitude({ 3, 4, 0 }), 5);
		expectEq(Vec3:mag({ 0, 0, 0 }), 0);
		expectNear(Vec3:mag({ 1, 1, 1 }), sqrt(3));
	end);
end);

describe("unit", function ()
	it("scales the vector to length 1", function ()
		expectVec(Vec3:unit({ 0, 0, 5 }), { 0, 0, 1 });
		expectNear(Vec3:mag(Vec3:unit({ 3, -4, 12 })), 1);
	end);
end);

describe("abs", function ()
	it("makes each component positive", function ()
		expectVec(Vec3:abs({ -1, 2, -3 }), { 1, 2, 3 });
	end);
end);

describe("dot / scalarProd", function ()
	it("is the sum of the products of the components", function ()
		expectEq(Vec3:dot({ 1, 2, 3 }, { 4, 5, 6 }), 32);
		expectEq(Vec3:scalarProd({ 1, 0, 0 }, { 0, 1, 0 }), 0);
	end);
end);

describe("cross / vectorProd", function ()
	it("is perpendicular to both (x cross y is z)", function ()
		expectVec(Vec3:cross({ 1, 0, 0 }, { 0, 1, 0 }), { 0, 0, 1 });
		expectVec(Vec3:vectorProd({ 0, 1, 0 }, { 1, 0, 0 }), { 0, 0, -1 });
		expectVec(Vec3:cross({ 1, 2, 3 }, { 4, 5, 6 }), { -3, 6, -3 });
	end);
end);

describe("angleBetween", function ()
	-- (Lua 4's trig functions use degrees, as do the game's)
	it("is the angle between the vectors, in degrees", function ()
		expectNear(Vec3:angleBetween({ 1, 0, 0 }, { 0, 1, 0 }), 90);
		expectNear(Vec3:angleBetween({ 1, 0, 0 }, { 1, 1, 0 }), 45);
		expectNear(Vec3:angleBetween({ 1, 0, 0 }, { -2, 0, 0 }), 180);
	end);
end);

describe("toStr", function ()
	it("uses tostring for anything that isn't a Vec3", function ()
		expectEq(Vec3:toStr(5), "5");
		expectEq(Vec3:toStr("hi"), "hi");
	end);
end);

finish();
