-- Offline unit tests for the console's command line parsing (`scripts/modkit/console/commands.lua`): `parseParams`, `parseFlags`,
-- the `PARAMS` param types, and `parseCommand`. Run with `npm test` in `modkit-tools`.

dofile("modkit-tools/tests/lua/harness.lua");

-- engine/game stubs
function doscanpath() end -- (would load the built-in commands; the tests add their own)
CONSOLE_OUTPUT = { log = {}, error = {} };
function consoleLog(line) CONSOLE_OUTPUT.log[getn(CONSOLE_OUTPUT.log) + 1] = line; end
function consoleError(line) CONSOLE_OUTPUT.error[getn(CONSOLE_OUTPUT.error) + 1] = line; end
GLOBAL_PLAYERS = {
	get = function (_, id) return { id = id }; end
};
STUB_SHIPS = {
	{ ship_type = "kus_scout", family = "Fighter" },
	{ ship_type = "kus_interceptor", family = "Fighter" },
	{ ship_type = "tai_carrier", family = "Mothership" },
};
GLOBAL_SHIPS = {
	filter = function (_, predicate) return modkit.table.filter(STUB_SHIPS, predicate); end
};

loadQuietly("scripts/modkit/table_util.lua");
loadQuietly("scripts/modkit/string_util.lua");
loadQuietly("scripts/modkit/vec3.lua");
loadQuietly("scripts/modkit/console/commands.lua");

--- `parseParams`, without its debug prints.
function parse(line, params)
	print = function () end;
	local result = parseParams(line, params);
	print = HARNESS_PRINT;
	return result;
end

--- A Vec3's components as a plain list (Vec3s are tagged tables; this compares just the numbers).
function components(vec)
	if (vec == nil) then
		return nil;
	end
	return { vec[1], vec[2], vec[3] };
end

describe("parseParams", function ()
	it("reads `name=value` for any of a param's names", function ()
		expectEq(parse("spawn t=kus_scout", { type = PARAMS.str({ "t", "type" }) }), { type = "kus_scout" });
		expectEq(parse("spawn type=kus_scout", { type = PARAMS.str({ "t", "type" }) }), { type = "kus_scout" });
	end);
	it("reads several params, in any order", function ()
		local params = { count = PARAMS.int({ "n" }), type = PARAMS.str({ "t" }) };
		expectEq(parse("spawn t=kus_scout n=5", params), { count = 5, type = "kus_scout" });
		expectEq(parse("spawn n=5 t=kus_scout", params), { count = 5, type = "kus_scout" });
	end);
	it("leaves a missing param nil, or uses its default (transformed like a given value)", function ()
		expectEq(parse("spawn", { count = PARAMS.int({ "n" }) }), {});
		expectEq(parse("spawn", { count = PARAMS.int({ "n" }, "7") }), { count = 7 });
	end);
	it("only matches a param's names in full (`grp=3` doesn't set a param named `p`)", function ()
		expectEq(parse("spawn grp=3", { player = PARAMS.int({ "p" }) }), {});
		expectEq(parse("spawn grp=3 p=1", { player = PARAMS.int({ "p" }) }), { player = 1 });
	end);
	it("matches a name at the very start of the line", function ()
		expectEq(parse("p=4", { player = PARAMS.int({ "p" }) }), { player = 4 });
	end);
	it("matches names case-insensitively, but keeps the value's case", function ()
		expectEq(parse("spawn T=Kus_Scout", { type = PARAMS.str({ "t" }) }), { type = "Kus_Scout" });
		expectEq(parse("spawn type=kus_scout", { type = PARAMS.str({ "TYPE" }) }), { type = "kus_scout" });
		expectEq(components(parse("move POS=1 2 3", { pos = PARAMS.strToVec3({ "pos" }) }).pos), { 1, 2, 3 });
	end);
end);

describe("parseFlags", function ()
	it("sets each flag found as `--flag`", function ()
		expectEq(parseFlags("move pos=0 0 0 --force", { "force", "quiet" }), { force = 1 });
		expectEq(parseFlags("move --quiet --force", { "force", "quiet" }), { force = 1, quiet = 1 });
	end);
	it("is empty without flags", function ()
		expectEq(parseFlags("move pos=0 0 0", { "force" }), {});
	end);
	it("only matches whole flags (`--forceful` doesn't set `force`)", function ()
		expectEq(parseFlags("move --forceful", { "force" }), {});
		expectEq(parseFlags("move --forceful --force", { "force" }), { force = 1 });
	end);
	it("doesn't match a flag inside a value", function ()
		expectEq(parseFlags("say msg=--force", { "force" }), {});
	end);
	it("matches flags case-insensitively, keyed by the flag's own name", function ()
		expectEq(parseFlags("move --FORCE", { "force" }), { force = 1 });
		expectEq(parseFlags("move --force", { "Force" }), { Force = 1 });
	end);
end);

describe("PARAMS", function ()
	describe("int", function ()
		it("reads digits as a number", function ()
			expectEq(parse("x n=42", { v = PARAMS.int({ "n" }) }), { v = 42 });
		end);
		it("defaults to the names n, v, val and value", function ()
			expectEq(parse("x val=3", { v = PARAMS.int() }), { v = 3 });
		end);
		it("accepts a sign", function ()
			expectEq(parse("x n=-5", { v = PARAMS.int({ "n" }) }), { v = -5 });
			expectEq(parse("x n=+5", { v = PARAMS.int({ "n" }) }), { v = 5 });
		end);
		it("ignores a lone sign", function ()
			expectEq(parse("x n=-", { v = PARAMS.int({ "n" }) }), {});
		end);
	end);

	describe("intToPlayer", function ()
		it("reads `p=` or `player=` as a player, via GLOBAL_PLAYERS:get", function ()
			expectEq(parse("x p=2", { player = PARAMS.intToPlayer() }), { player = { id = 2 } });
			expectEq(parse("x player=0", { player = PARAMS.intToPlayer() }), { player = { id = 0 } });
		end);
	end);

	describe("str", function ()
		it("reads letters, digits, _ and -", function ()
			expectEq(parse("x t=kus_scout-2", { t = PARAMS.str({ "t" }) }), { t = "kus_scout-2" });
		end);
		it("stops at a space", function ()
			expectEq(parse("x t=kus scout", { t = PARAMS.str({ "t" }) }), { t = "kus" });
		end);
	end);

	describe("strToVec3", function ()
		it("reads three numbers into a Vec3", function ()
			expectEq(components(parse("move pos=10 -5 3", { pos = PARAMS.strToVec3({ "pos" }) }).pos), { 10, -5, 3 });
		end);
		it("accepts signs and decimals", function ()
			expectEq(components(parse("move pos=+10 -2.25 .5", { pos = PARAMS.strToVec3({ "pos" }) }).pos), { 10, -2.25, 0.5 });
			expectEq(components(parse("move pos=-0.5 0 1000.125", { pos = PARAMS.strToVec3({ "pos" }) }).pos), { -0.5, 0, 1000.125 });
		end);
		it("reads the vector when other params and flags follow", function ()
			local params = { pos = PARAMS.strToVec3({ "pos" }), player = PARAMS.intToPlayer() };
			local result = parse("move pos=1 2 3 p=1 --force", params);
			expectEq(components(result.pos), { 1, 2, 3 });
			expectEq(result.player, { id = 1 });
		end);
		it("uses a string default, as a Vec3", function ()
			expectEq(components(parse("spawn", { pos = PARAMS.strToVec3({ "pos" }, "0 0 0") }).pos), { 0, 0, 0 });
		end);
		it("rejects malformed vectors", function ()
			local params = { pos = PARAMS.strToVec3({ "pos" }) };
			local malformed = { "pos=1 2", "pos=+ 5 3", "pos=5+ 1 2", "pos=. 1 2", "pos=5. 1 2", "pos=1..2 3 4", "pos= 1 2 3" };
			for i = 1, getn(malformed) do
				expectNil(parse("move " .. malformed[i], params).pos, malformed[i]);
			end
		end);
	end);

	describe("strToShipsOfType", function ()
		it("returns the ships whose type contains the value", function ()
			local result = parse("x t=kus", { ships = PARAMS.strToShipsOfType({ "t" }) });
			expectSameItems(modkit.table.map(result.ships, function (ship) return ship.ship_type; end), { "kus_scout", "kus_interceptor" });
		end);
	end);
end);

describe("parseCommand", function ()
	COMMANDS.probe = {
		params = { count = PARAMS.int({ "n" }) },
		flags = { "loud" },
		fn = function (params, words, flags, line)
			PROBE_CALL = { params = params, words = words, flags = flags, line = line };
		end
	};
	COMMANDS.broken = {
		fn = function ()
			local missing = nil;
			---@diagnostic disable-next-line: need-check-nil, undefined-field
			return missing.field; -- (an error, on purpose)
		end
	};

	it("calls the command with its params, words, flags and line", function ()
		PROBE_CALL = nil;
		print = function () end;
		parseCommand("probe n=3 --loud");
		print = HARNESS_PRINT;
		expectEq(PROBE_CALL, {
			params = { count = 3 },
			words = { "probe", "n=3", "--loud" },
			flags = { loud = 1 },
			line = "probe n=3 --loud",
		});
	end);
	it("finds commands case-insensitively, and lowercases the words", function ()
		PROBE_CALL = nil;
		print = function () end;
		parseCommand("PROBE Hello");
		print = HARNESS_PRINT;
		expectTruthy(PROBE_CALL, "the command ran");
		expectEq(PROBE_CALL.words, { "probe", "hello" });
	end);
	it("logs unknown commands", function ()
		CONSOLE_OUTPUT.log = {};
		parseCommand("nonsense here");
		expectEq(CONSOLE_OUTPUT.log, { "no such command: 'nonsense'" });
	end);
	it("catches an error in a command, and reports it with the message", function ()
		CONSOLE_OUTPUT.error = {};
		local quiet = _ERRORMESSAGE;
		_ERRORMESSAGE = function () end; -- (keeps the expected traceback out of the test output)
		parseCommand("broken");
		_ERRORMESSAGE = quiet;
		expectEq(getn(CONSOLE_OUTPUT.error), 1, "one error line");
		expectTruthy(strfind(CONSOLE_OUTPUT.error[1], "command 'broken' failed: ", 1, 1), "names the command");
		expectTruthy(strfind(CONSOLE_OUTPUT.error[1], "attempt to index", 1, 1), "includes the error message");
	end);
end);

finish();
