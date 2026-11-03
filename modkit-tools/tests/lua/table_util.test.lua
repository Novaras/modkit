-- Offline unit tests for `scripts/modkit/table_util.lua` (`modkit.table`). Run with `npm test` in `modkit-tools`.
--
-- Lua 4.0 tables have no array part, so `for k, v in t` order isn't guaranteed even for lists: results that depend on
-- iteration order are compared with `expectSameItems`, or use single-entry tables.

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/table_util.lua");

T = modkit.table; -- (a global: in Lua 4, `%upvalue` can only reach the immediately enclosing function)

-- ===[ List operations ]===

describe("push", function ()
	it("adds to the end, in place, and returns the table", function ()
		local list = { "a", "b" };
		local returned = T.push(list, "c");
		expectEq(list, { "a", "b", "c" });
		expectTruthy(returned == list, "returns the same table");
	end);
	it("works on an empty table", function ()
		expectEq(T.push({}, "a"), { "a" });
	end);
	it("doesn't write an `n` field", function ()
		local list = T.push({ "a" }, "b");
		expectNil(list.n);
	end);
end);

describe("pop", function ()
	it("removes and returns the last value, in place", function ()
		local list = { "a", "b", "c" };
		expectEq(T.pop(list), "c");
		expectEq(list, { "a", "b" });
	end);
	it("returns nil for an empty table", function ()
		expectNil(T.pop({}));
	end);
	it("doesn't write an `n` field, and push fills the freed slot", function ()
		local list = { "a", "b", "c" };
		T.pop(list);
		expectNil(list.n);
		T.push(list, "d");
		expectEq(list, { "a", "b", "d" });
	end);
end);

describe("shift", function ()
	it("removes and returns the first value, moving the rest down", function ()
		local list = { "a", "b", "c" };
		expectEq(T.shift(list), "a");
		expectEq(list, { "b", "c" });
	end);
	it("returns nil for an empty table", function ()
		expectNil(T.shift({}));
	end);
	it("leaves a list push can extend (no gap, no `n` field)", function ()
		local list = { "a", "b", "c" };
		T.shift(list);
		T.push(list, "d");
		expectEq(list, { "b", "c", "d" });
		expectNil(list.n);
	end);
end);

describe("unshift", function ()
	it("adds to the start, in place, moving the rest up, and returns the table", function ()
		local list = { "b", "c" };
		local returned = T.unshift(list, "a");
		expectEq(list, { "a", "b", "c" });
		expectTruthy(returned == list, "returns the same table");
	end);
	it("works on an empty table", function ()
		expectEq(T.unshift({}, "a"), { "a" });
	end);
	it("is undone by shift", function ()
		local list = { "b", "c" };
		T.unshift(list, "a");
		expectEq(T.shift(list), "a");
		expectEq(list, { "b", "c" });
		expectNil(list.n);
	end);
end);

describe("length", function ()
	it("counts every key, not just the list part", function ()
		expectEq(T.length({ "a", "b"; x = 1 }), 3);
		expectEq(T.length({ "a", "b"; n = 2 }), 3);
	end);
	it("is 0 for an empty table", function ()
		expectEq(T.length({}), 0);
	end);
end);

describe("isEmpty", function ()
	it("is 1 for an empty table, and nil otherwise", function ()
		expectEq(T.isEmpty({}), 1);
		expectNil(T.isEmpty({ "a" }));
		expectNil(T.isEmpty({ x = 1 }));
	end);
end);

describe("firstKey / first / firstValue", function ()
	it("return the only entry's key and value", function ()
		expectEq(T.firstKey({ x = "v" }), "x");
		expectEq(T.first({ x = "v" }), "v");
		expectEq(T.firstValue({ x = "v" }), "v");
	end);
	it("return nil for an empty table (rather than erroring)", function ()
		expectNil(T.firstKey({}));
		expectNil(T.first({}));
		expectNil(T.firstValue({}));
	end);
end);

-- ===[ Transforms ]===

describe("map", function ()
	it("transforms each value, keeping keys", function ()
		expectEq(T.map({ 1, 2; x = 3 }, function (v) return v * 10; end), { 10, 20; x = 30 });
	end);
	it("passes the key and the table", function ()
		local source = { x = 1 };
		local seen = {};
		T.map(source, function (v, k, tbl) %seen.k = k; %seen.tbl = tbl; return v; end);
		expectEq(seen.k, "x");
		expectTruthy(seen.tbl == source, "passes the original table");
	end);
	it("doesn't change the original", function ()
		local source = { 1, 2 };
		T.map(source, function (v) return v * 10; end);
		expectEq(source, { 1, 2 });
	end);
end);

describe("filter", function ()
	it("keeps the values passing the predicate, under their original keys", function ()
		expectEq(T.filter({ 1, 2, 3, 4 }, function (v) return mod(v, 2) == 0; end), { [2] = 2, [4] = 4 });
	end);
	it("returns an empty table when nothing passes", function ()
		expectEq(T.filter({ 1, 2 }, function () return nil; end), {});
	end);
end);

describe("reduce", function ()
	it("folds values into the initial value", function ()
		expectEq(T.reduce({ 1, 2, 3 }, function (acc, v) return acc + v; end, 10), 16);
	end);
	it("starts from nil without an initial value", function ()
		expectEq(T.reduce({ 1, 2, 3 }, function (acc, v) return (acc or 0) + v; end), 6);
	end);
	it("returns the initial value for an empty table", function ()
		expectEq(T.reduce({}, function (acc, v) return acc + v; end, 5), 5);
	end);
end);

describe("keys / values", function ()
	it("list every key / value", function ()
		local source = { "a"; x = "b" };
		expectSameItems(T.keys(source), { 1, "x" });
		expectSameItems(T.values(source), { "a", "b" });
	end);
	it("return 1..n lists", function ()
		local keys = T.keys({ x = 1, y = 2 });
		expectTruthy(keys[1] and keys[2] and keys[3] == nil, "keys at 1 and 2 only");
	end);
end);

describe("entries", function ()
	it("lists { key, value } pairs (1-based)", function ()
		expectSameItems(T.entries({ "a"; x = "b" }), { { 1, "a" }, { "x", "b" } });
	end);
	it("is empty for an empty table", function ()
		expectEq(T.entries({}), {});
	end);
end);

describe("pack", function ()
	it("re-numbers the values as a 1..n list", function ()
		local packed = T.pack({ [3] = "a", x = "b" });
		expectSameItems(packed, { "a", "b" });
		expectTruthy(packed[1] and packed[2] and packed[3] == nil, "values at 1 and 2 only");
	end);
end);

-- ===[ Searching ]===

describe("includesValue / includesKey", function ()
	it("find values and keys", function ()
		expectEq(T.includesValue({ "a"; x = "b" }, "b"), 1);
		expectNil(T.includesValue({ "a" }, "z"));
		expectEq(T.includesKey({ "a"; x = "b" }, "x"), 1);
		expectNil(T.includesKey({ "a" }, 2));
	end);
end);

describe("findVal", function ()
	it("finds by predicate or by value", function ()
		expectEq(T.findVal({ 1, 5, 3 }, function (v) return v > 4; end), 5);
		expectEq(T.findVal({ "a", "b" }, "b"), "b");
	end);
	it("returns nil when nothing matches", function ()
		expectNil(T.findVal({ 1, 2 }, function (v) return v > 4; end));
		expectNil(T.findVal({}, "a"));
	end);
end);

describe("findIndex", function ()
	it("returns the key of the match, by predicate or by value", function ()
		expectEq(T.findIndex({ x = 1, y = 5 }, function (v) return v > 4; end), "y");
		expectEq(T.findIndex({ "a", "b" }, "b"), 2);
	end);
	it("returns nil when nothing matches", function ()
		expectNil(T.findIndex({ "a" }, "z"));
	end);
end);

describe("findPosition", function ()
	it("returns how many steps of iteration reach the match", function ()
		expectEq(T.findPosition({ x = "a" }, "a"), 1);
		expectEq(T.findPosition({ x = 5 }, function (_, k, position) return k == "x" and position == 1; end), 1);
	end);
	it("returns nil when nothing matches", function ()
		expectNil(T.findPosition({ "a", "b" }, "z"));
	end);
end);

describe("any / all", function ()
	it("any: 1 if some value passes", function ()
		expectEq(T.any({ 1, 5 }, function (v) return v > 4; end), 1);
		expectNil(T.any({ 1, 2 }, function (v) return v > 4; end));
		expectNil(T.any({}, function () return 1; end));
	end);
	it("all: 1 if every value passes (including none)", function ()
		expectEq(T.all({ 5, 6 }, function (v) return v > 4; end), 1);
		expectNil(T.all({ 5, 1 }, function (v) return v > 4; end));
		expectEq(T.all({}, function () return nil; end), 1);
	end);
end);

-- ===[ Sets and ranges ]===

describe("difference", function ()
	it("keeps the values of A not in B, under their original keys", function ()
		expectEq(T.difference({ 1, 2, 3 }, { 2 }), { [1] = 1, [3] = 3 });
	end);
	it("keeps function values of A which aren't in B (not called as predicates)", function ()
		local fn = function () return 1; end;
		local result = T.difference({ fn }, { "unrelated" });
		expectTruthy(result[1] == fn, "the function is kept");
	end);
end);

describe("slice", function ()
	-- (unlike JS, keeps the original indices; this pins the current behaviour)
	it("copies i..j, keeping the original indices", function ()
		expectEq(T.slice({ "a", "b", "c", "d" }, 2, 3), { [2] = "b", [3] = "c" });
	end);
	it("goes to the end without j", function ()
		expectEq(T.slice({ "a", "b", "c" }, 2), { [2] = "b", [3] = "c" });
	end);
end);

describe("reverse", function ()
	it("returns a new 1..n list in reverse order", function ()
		local source = { "a", "b", "c" };
		local reversed = T.reverse(source);
		expectEq(reversed, { "c", "b", "a" });
		expectEq(source, { "a", "b", "c" }, "the original is unchanged");
	end);
	it("handles a single value", function ()
		expectEq(T.reverse({ "a" }), { "a" });
	end);
	it("is empty for an empty table", function ()
		expectEq(T.reverse({}), {});
	end);
end);

-- ===[ Copying and merging ]===

describe("clone", function ()
	it("copies deeply by default", function ()
		local source = { a = 1, sub = { b = 2 } };
		local copy = T.clone(source);
		expectEq(copy, source);
		expectTruthy(copy ~= source, "a new table");
		expectTruthy(copy.sub ~= source.sub, "a new sub-table");
	end);
	it("stops recursing at recurse_stop_depth", function ()
		local source = { sub = { inner = { c = 3 } } };
		local shallow = T.clone(source, nil, 0);
		expectTruthy(shallow.sub == source.sub, "depth 0 shares sub-tables");
		local one = T.clone(source, nil, 1);
		expectTruthy(one.sub ~= source.sub, "depth 1 copies the first level");
		expectTruthy(one.sub.inner == source.sub.inner, "depth 1 shares the second level");
	end);
	it("omits and overrides keys", function ()
		local copy = T.clone({ a = 1, b = 2, c = 3 }, { omit = { "a" }, override = { b = 20 } });
		expectEq(copy, { b = 20, c = 3 });
	end);
	it("prefers omit when a key is both omitted and overridden", function ()
		expectEq(T.clone({ a = 1 }, { omit = { "a" }, override = { a = 2 } }), {});
	end);
end);

describe("merge", function ()
	it("merges tables deeply, with B winning", function ()
		local merged = T:merge({ a = 1, keep = 1, sub = { x = 1 } }, { a = 2, sub = { y = 2 } });
		expectEq(merged, { a = 2, keep = 1, sub = { x = 1, y = 2 } });
	end);
	it("doesn't change either argument", function ()
		local a = { x = 1 };
		local b = { y = 2 };
		T:merge(a, b);
		expectEq(a, { x = 1 });
		expectEq(b, { y = 2 });
	end);
	it("returns the other table when one is nil, or an empty table for both", function ()
		local only = { x = 1 };
		expectTruthy(T:merge(nil, only) == only, "nil, b gives b");
		expectTruthy(T:merge(only, nil) == only, "a, nil gives a");
		expectEq(T:merge(nil, nil), {});
	end);
	it("uses a custom merger for keys in both", function ()
		local merged = T:merge({ a = 1, b = 1 }, { a = 2 }, function (a, b) return a + b; end);
		expectEq(merged, { a = 3, b = 1 });
	end);
	it("keeps A's list entries beyond B's length (merges by key)", function ()
		expectEq(T:merge({ 1, 2, 3 }, { 9 }), { 9, 2, 3 });
	end);
end);

-- ===[ Output and misc ]===

describe("stringify", function ()
	it("produces Lua that evaluates back to an equal table", function ()
		local source = { 1, "two"; x = { y = 3, z = "w" } };
		local str = T.stringify(source);
		expectEq(dostring("return " .. str), source);
	end);
	it("gives {} for an empty table", function ()
		expectEq(T.stringify({}), "{}");
	end);
	it("escapes quotes in string keys and values", function ()
		local source = { ['say "hi"'] = 'a "quoted" value' };
		expectEq(dostring("return " .. T.stringify(source)), source);
	end);
end);

describe("forEach", function ()
	it("calls back for every pair", function ()
		local seen = {};
		T.forEach({ "a"; x = "b" }, function (v, k) %seen[k] = v; end);
		expectEq(seen, { "a"; x = "b" });
	end);
	it("doesn't recurse without `recursive`, and passes function values to the callback", function ()
		local fn = function () end;
		local seen = {};
		T.forEach({ f = fn }, function (v, k) %seen[k] = v; end);
		expectTruthy(seen.f == fn, "the function is passed to the callback");
	end);
	it("recurses into tables when `recursive` is set", function ()
		local seen = {};
		T.forEach({ sub = { x = 1 } }, function (v, k) %seen[k] = v; end, 1);
		expectEq(seen, { x = 1 });
	end);
end);

describe("randomEntry", function ()
	it("returns one of the { key, value } entries", function ()
		randomseed(1);
		local source = { a = 1, b = 2, c = 3 };
		for _ = 1, 20 do
			local entry = T.randomEntry(source);
			expectEq(source[entry[1]], entry[2], "entry matches the table");
		end
	end);
	it("returns the only entry of a single-entry table (random(1, 1) is an error in the game)", function ()
		expectEq(T.randomEntry({ x = 5 }), { "x", 5 });
	end);
	it("returns nil for an empty table", function ()
		expectNil(T.randomEntry({}));
	end);
end);

describe("printTbl", function ()
	it("prints through output_fn, under the label", function ()
		local lines = {};
		T.printTbl({ x = 1, s = "v" }, "label", nil, function (line) %lines[getn(%lines) + 1] = line; end);
		expectSameItems(lines, { "\"label\": {", "\t\"x\": 1,", "\t\"s\": \"v\",", "}," });
	end);
	it("prints a cycle as <cycle: ...> instead of overflowing the stack", function ()
		local looped = { name = "a" };
		looped.self = looped;
		local lines = {};
		T.printTbl(looped, "looped", nil, function (line) %lines[getn(%lines) + 1] = line; end);
		local found = nil;
		for _, line in lines do
			if (strfind(line, "<cycle:", 1, 1)) then
				found = 1;
			end
		end
		expectTruthy(found, "a <cycle: ...> line");
	end);
end);

finish();
