-- Offline unit tests for `scripts/modkit/protected_call.lua` (`protectedCall`). Run with `npm test` in `modkit-tools`.
--
-- `protectedCall` passes errors on to the game's own `_ERRORMESSAGE` (which logs the traceback), so the tests stand in a recording
-- one for that (via `asGame`; the harness's `it` installs its own `_ERRORMESSAGE` while a test runs, to catch failed expectations).

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/protected_call.lua");

-- stands in for the game's handler: records the messages it gets
GAME_HANDLED = {};
function gameHandler(message)
	GAME_HANDLED[getn(GAME_HANDLED) + 1] = message;
end

--- Runs `fn` with `gameHandler` as the game's `_ERRORMESSAGE`, then puts the harness's back (so expectations made afterwards are caught).
--- Returns `fn`'s result, and whether `gameHandler` was still installed when `fn` returned (i.e `protectedCall` put it back).
function asGame(fn)
	GAME_HANDLED = {};
	local harness_handler = _ERRORMESSAGE;
	_ERRORMESSAGE = gameHandler;
	local result = fn();
	local restored = (_ERRORMESSAGE == gameHandler);
	_ERRORMESSAGE = harness_handler;
	return result, restored;
end

describe("protectedCall", function ()
	it("returns 1 and fn's first return value on success", function ()
		local succeeded, value = protectedCall(function (a, b) return a + b, "ignored"; end, { 2, 3 });
		expectEq(succeeded, 1);
		expectEq(value, 5);
	end);
	it("tells success apart from fn returning nil", function ()
		local succeeded, value = protectedCall(function () return nil; end);
		expectEq(succeeded, 1);
		expectNil(value);
	end);
	it("passes nil arguments, when args has `n`", function ()
		local seen = {};
		protectedCall(function (a, b, c) %seen.a = a; %seen.b = b; %seen.c = c; end, { 1, nil, 3; n = 3 });
		expectEq(seen, { a = 1, c = 3 });
	end);
	it("returns nil when fn errors, and gives onError the message", function ()
		local caught = {};
		local result = asGame(function ()
			local caught_here = %caught; -- (re-localised: `%upvalue` only reaches the immediately enclosing function)
			return { protectedCall(function () error("boom"); end, {}, function (message) %caught_here.message = message; end) };
		end);
		expectEq(result, {}, "nil, nil");
		expectEq(caught.message, "boom");
	end);
	it("passes the error on to the game's handler too (after onError)", function ()
		local order = {};
		asGame(function ()
			local order_here = %order;
			protectedCall(function () error("logged"); end, {}, function () %order_here[getn(%order_here) + 1] = "onError"; end);
		end);
		expectEq(GAME_HANDLED, { "logged" });
		expectEq(order, { "onError" });
	end);
	it("catches the error without onError", function ()
		local succeeded = asGame(function ()
			return protectedCall(function () error("unhandled"); end);
		end);
		expectNil(succeeded);
		expectEq(GAME_HANDLED, { "unhandled" });
	end);
	it("puts the game's handler back afterwards, whether fn errors or not", function ()
		local _, after_success = asGame(function () protectedCall(function () return 1; end); end);
		local _, after_error = asGame(function () protectedCall(function () error("x"); end, {}, function () end); end);
		expectTruthy(after_success, "after success");
		expectTruthy(after_error, "after an error");
		expectEq(PROTECTED_CALL.depth, 0);
	end);
	it("gives a nested call's error to its own onError only (and the game's handler), not the outer one's", function ()
		local inner_seen = {};
		local outer_seen = {};
		local succeeded, restored = asGame(function ()
			local outer_here = %outer_seen;
			return protectedCall(function (inner)
				protectedCall(function () error("inner"); end, {}, function (message) %inner[getn(%inner) + 1] = message; end);
				error("outer");
			end, { %inner_seen }, function (message) %outer_here[getn(%outer_here) + 1] = message; end);
		end);
		expectNil(succeeded);
		expectEq(inner_seen, { "inner" });
		expectEq(outer_seen, { "outer" });
		expectEq(GAME_HANDLED, { "inner", "outer" });
		expectTruthy(restored, "the game's handler is back");
		expectEq(PROTECTED_CALL.depth, 0);
	end);
	it("lets a successful nested call return to the outer call", function ()
		local succeeded, value = protectedCall(function ()
			local _, inner_value = protectedCall(function () return 21; end);
			return inner_value * 2;
		end);
		expectEq(succeeded, 1);
		expectEq(value, 42);
	end);

	-- (last: the guard also stops this file from defining global functions, so it's removed again afterwards)
	it("works despite the game's guard against overwriting global functions", function ()
		-- like the game's `function_set_error` tag method: refuses to replace a global holding a function with a Lua function
		-- (installed inside `asGame`, which itself swaps `_ERRORMESSAGE` the normal way, and removed before it swaps back)
		REFUSED = {};
		local caught = {};
		local succeeded, restored = asGame(function ()
			settagmethod(tag(print), "setglobal", function (name)
				REFUSED[getn(REFUSED) + 1] = name;
			end);

			local caught_here = %caught;
			local result = protectedCall(function () error("guarded"); end, {}, function (message) %caught_here.message = message; end);

			settagmethod(tag(print), "setglobal", nil);
			return result;
		end);

		expectNil(succeeded);
		expectEq(caught.message, "guarded");
		expectEq(GAME_HANDLED, { "guarded" });
		expectEq(REFUSED, {}, "no refused writes (it uses rawset)");
		expectTruthy(restored, "the game's handler is back");
	end);
end);

finish();
