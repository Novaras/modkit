-- protected_call.lua: calls a function, catching any error it raises (so a bad callback can't take down its caller).
-- By: Fear (Novaras)
--
-- Lua 4's `call(fn, args, "x", handler)` installs `handler` by assigning the global `_ERRORMESSAGE`. The game refuses normal
-- assignments to globals holding a Lua function (a `setglobal` tag method, `function_set_error`, logs "Cannot overwrite function
-- <name>" and keeps the old value), so `call` never installs the handler, and logs that line on every call.
-- `rawset` on the globals table skips tag methods, so `protectedCall` swaps the handler in and out with that instead.

if (protectedCall == nil) then
	-- the game's own `_ERRORMESSAGE`, saved by the outermost `protectedCall` (so a nested call's handler passes errors to the game's
	-- handler, rather than to the outer call's `onError`)
	PROTECTED_CALL = {
		depth = 0,
		game_handler = nil
	};

	--- Calls `fn` with the values in the list `args`, catching any error it raises.
	---
	--- On an error, `onError` gets the message, then the original `_ERRORMESSAGE` runs, so the game still logs the error and traceback.
	---
	--- Returns `1` and `fn`'s first return value on success, or `nil` if `fn` raised an error.
	---
	---@param fn function
	---@param args? table A list (set `n` if it can contain `nil`s)
	---@param onError? fun(message: string)
	---@return 1|nil succeeded
	---@return any value
	function protectedCall(fn, args, onError)
		local env = globals();
		local original = rawget(env, "_ERRORMESSAGE"); -- (put back afterwards; the outer call's handler, if nested)
		if (PROTECTED_CALL.depth == 0) then
			PROTECTED_CALL.game_handler = original;
		end
		PROTECTED_CALL.depth = PROTECTED_CALL.depth + 1;

		rawset(env, "_ERRORMESSAGE", function (message)
			if (%onError) then
				%onError(message);
			end
			if (PROTECTED_CALL.game_handler) then
				PROTECTED_CALL.game_handler(message);
			end
		end);

		-- the leading `1` tells success apart from an error (`call` with "x" returns `nil`), since `fn` can return `nil` itself
		local succeeded, value = call(
			function (wrapped_fn, wrapped_args)
				return 1, call(wrapped_fn, wrapped_args);
			end,
			{ fn, args or {} },
			"x"
		);

		rawset(env, "_ERRORMESSAGE", original);
		PROTECTED_CALL.depth = PROTECTED_CALL.depth - 1;

		return succeeded, value;
	end
end
