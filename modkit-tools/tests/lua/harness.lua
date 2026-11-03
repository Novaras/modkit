-- harness.lua: a tiny test library for modkit's offline unit tests (Lua 4.0, the game's dialect).
-- By: Fear (Novaras)
--
-- Run from the repo root (`npm test` in `modkit-tools` does this), so modkit files load with repo-relative paths.
-- Offline there's no "Cannot overwrite function" guard, so `call`'s error handler argument works here.

-- ===[ Stubs ]===

--- Loads a game path (`data:...`) relative to the repo root, like the game does relative to the mod.
function dofilepath(path)
	return dofile(gsub(path, "^data:", ""));
end

-- modkit prints on load ("table_util init" etc.); hide those while loading, keeping `print` for the tests' own output
HARNESS_PRINT = print;

--- Loads a modkit file without its load-time prints.
---
---@param path string Repo-relative, i.e `"scripts/modkit/table_util.lua"`
function loadQuietly(path)
	print = function () end;
	dofile(path);
	print = HARNESS_PRINT;
end

-- ===[ Formatting ]===

--- A readable representation of `value` for failure messages (sorted keys, so it's stable; doesn't use modkit, which is under test).
---
---@param value any
---@param seen? table<table, 1>
---@return string
function show(value, seen)
	if (type(value) == "string") then
		return format("%q", value);
	elseif (type(value) ~= "table") then
		return tostring(value);
	end

	seen = seen or {};
	if (seen[value]) then
		return "<cycle>";
	end
	seen[value] = 1;

	local keys = {};
	for k, _ in value do
		keys[getn(keys) + 1] = k;
	end
	sort(keys, function (a, b)
		if (type(a) == type(b) and (type(a) == "number" or type(a) == "string")) then
			return a < b;
		end
		return type(a) < type(b);
	end);

	local out = "{";
	for i = 1, getn(keys) do
		local k = keys[i];
		if (i > 1) then
			out = out .. ", ";
		end
		out = out .. "[" .. show(k) .. "]=" .. show(value[k], seen);
	end
	seen[value] = nil;
	return out .. "}";
end

-- ===[ Comparison ]===

--- Whether `a` and `b` are equal, comparing tables by their contents (recursively).
---
---@return 1|nil
function deepEq(a, b)
	if (type(a) ~= "table" or type(b) ~= "table") then
		if (a == b) then
			return 1;
		end
		return nil;
	end
	for k, v in a do
		if (not deepEq(v, b[k])) then
			return nil;
		end
	end
	for k, _ in b do
		if (a[k] == nil) then
			return nil;
		end
	end
	return 1;
end

-- ===[ Assertions ]===

function fail(message)
	error(message, 2);
end

--- Fails unless `actual` equals `expected` (deep, for tables).
function expectEq(actual, expected, label)
	if (not deepEq(actual, expected)) then
		fail((label and (label .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual));
	end
end

--- Fails unless the lists `actual` and `expected` hold the same values, in any order (for results whose order depends on table iteration).
function expectSameItems(actual, expected, label)
	local remaining = {};
	for _, v in expected do
		remaining[getn(remaining) + 1] = v;
	end
	local count = 0;
	for _, v in actual do
		count = count + 1;
		local found = nil;
		for i, r in remaining do
			if (deepEq(v, r)) then
				found = i;
				break;
			end
		end
		if (found == nil) then
			fail((label and (label .. ": ") or "") .. "unexpected item " .. show(v) .. " in " .. show(actual) .. ", expected the items of " .. show(expected));
		end
		---@cast found integer
		remaining[found] = nil;
	end
	if (next(remaining, nil)) then
		fail((label and (label .. ": ") or "") .. "missing items " .. show(remaining) .. " from " .. show(actual));
	end
end

function expectNil(value, label)
	if (value ~= nil) then
		fail((label and (label .. ": ") or "") .. "expected nil, got " .. show(value));
	end
end

function expectTruthy(value, label)
	if (value == nil) then
		fail((label and (label .. ": ") or "") .. "expected a non-nil value");
	end
end

--- Fails unless calling `fn` raises an error.
function expectError(fn, label)
	local quiet = function () end; -- (keeps the expected error's message and traceback out of the output)
	if (call(fn, {}, "x", quiet) ~= nil) then
		fail((label and (label .. ": ") or "") .. "expected an error");
	end
end

-- ===[ Running ]===

HARNESS = {
	suite = "",
	passed = 0,
	failures = {},
};

--- Groups the `it`s inside `fn` under `name`.
function describe(name, fn)
	local outer = HARNESS.suite;
	HARNESS.suite = (outer == "" and name) or (outer .. " > " .. name);
	fn();
	HARNESS.suite = outer;
end

--- Runs one test. An error (from an `expect...`, or anything else) fails it without stopping the rest.
function it(name, fn)
	local full_name = HARNESS.suite .. " > " .. name;
	local caught = {};
	local succeeded = call(function (test_fn)
		test_fn();
		return 1;
	end, { fn }, "x", function (message)
		%caught.message = message;
	end);

	if (succeeded) then
		HARNESS.passed = HARNESS.passed + 1;
		HARNESS_PRINT("  pass  " .. full_name);
	else
		HARNESS.failures[getn(HARNESS.failures) + 1] = full_name .. "\n        " .. tostring(caught.message);
		HARNESS_PRINT("  FAIL  " .. full_name);
	end
end

--- Prints the summary, and exits with code 1 if anything failed (so the runner can tell).
function finish()
	local failed = getn(HARNESS.failures);
	if (failed > 0) then
		HARNESS_PRINT("\nFailures:");
		for i = 1, failed do
			HARNESS_PRINT("  " .. HARNESS.failures[i]);
		end
	end
	HARNESS_PRINT("\n" .. HARNESS.passed .. " passed, " .. failed .. " failed");
	if (failed > 0) then
		exit(1);
	end
end
