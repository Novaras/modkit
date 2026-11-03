if (MODKIT_CONSOLE_COMMANDS == nil) then
	if (modkit == nil or modkit.table == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end
	if (strsplit == nil) then
		dofilepath("data:scripts/modkit/string_util.lua");
	end
	if (protectedCall == nil) then
		dofilepath("data:scripts/modkit/protected_call.lua");
	end

	---@class ParamConfig
	---@field names string[] The param name(s), i.e 'p' in 'p=10'
	---@field pattern string The regex pattern to match for the value, i.e '%S+' for 'hello' in 'word=hello'
	---@field default? any The optional default value if the param is not provided
	---@field transform? fun(value: any): any

	---@class CommandFn
	---@field params? ParamConfig[]
	---@field flags? string[]
	---@field description? string
	---@field syntax? string
	---@field example? string
	---@field fn fun(params: any[], words: string[], flags: any[], line: string): any

	---@alias ParamConfigGenerator fun(names: string[], default: any): ParamConfig

	function makeSpawnVolGenerator(radius)
		radius = radius or 1500;
		return function (pos)
			local p = modkit.table.clone(pos or { 0, 0, 0 });
			for k, v in p do
				p[k] = v + random(-%radius, %radius);
			end
			-- consoleLog("new vol at " .. pos[1] .. ", " .. pos[2] .. ", " .. pos[3]);
			-- consoleLog("name = " .. "__console_spawn_area" .. Universe_GameTime() .. pos[1] .. pos[2] .. pos[3]);
			return Volume_Fresh("__console_spawn_area" .. Universe_GameTime() .. p[1] .. p[2] .. p[3], p);
		end
	end

	function consoleMultiple(lines)
		print("ok");
		print(tostring(line));

		for _, line in lines do
			consoleLog(strsub(line, 1, strlen(line) - 1));
		end
	end

	function shipsFromParamValues(params)
		local src = GLOBAL_SHIPS:all();

		if (params.type and params.family) then
			consoleLog("warning: ignoring family param (f=" .. params.family .. ") due to presence of type param (t=" .. params.type .. ")");
		end

		if (params.type) then
			src = modkit.table.filter(src, function (ship)
				return strfind(ship.ship_type, %params.type, 1, 1);
			end);
		elseif (params.family) then
			src = modkit.table.filter(src, function (ship)
				return strfind(ship:attackFamily(), %params.family, 1, 1);
			end);
		end

		if (params.player) then
			src = modkit.table.filter(src, function (ship)
				return ship.player.id == %params.player.id;
			end);
		end

		return src;
	end

	--- Escapes `str`'s pattern characters, so it matches literally inside a pattern.
	---
	---@param str string
	---@return string
	function escapePattern(str)
		local escaped = gsub(str, "(%W)", "%%%1"); -- (a local, so only the string is returned, not `gsub`'s count too)
		return escaped;
	end

	--- Finds `pattern` in `str` only where it starts `str` or follows whitespace (so a name isn't found inside a longer word).
	--- Returns the match's start and end, like `strfind` (not including the whitespace).
	---
	---@param str string
	---@param pattern string
	---@return integer|nil start
	---@return integer|nil finish
	function findAtWordStart(str, pattern)
		local s, e = strfind(str, "^" .. pattern);
		if (s == nil) then
			s, e = strfind(str, "%s" .. pattern);
			if (s) then
				s = s + 1;
			end
		end
		return s, e;
	end

	--- Reads each param in `params` from `line`, as `name=value` (for any of the param's names). Names are matched case-insensitively,
	--- and must start the line or follow whitespace. Values keep their case. Missing params use their default (if any).
	---
	---@param line string
	---@param params ParamConfig[]
	function parseParams(line, params)
		local res = {};
		local lower_line = strlower(line); -- (the same length as `line`, so positions found in it can be read from `line`)

		for label, conf in params do
			local value = nil;
			for _, name in conf.names do
				local s, e = findAtWordStart(lower_line, escapePattern(strlower(name)) .. "=" .. conf.pattern);
				if (s) then
					value = strsub(line, s + strlen(name) + 1, e); -- (after `name=`)
					print("parsed val for name " .. name .. " as " .. tostring(value));
				end
			end
			if (conf.default and value == nil) then -- no name patterns matched, use default if exists
				value = conf.default;
			end
			if (conf.transform and value) then
				value = conf.transform(value);
			end

			res[label] = value;
		end

		-- consoleLog("parseParams:");
		-- consoleLog("\tline: " .. line);
		-- modkit.table.printTbl(res, "res");

		return res;
	end

	--- Returns `{ [flag] = 1 }` for each of `flags` found in `line` as a whole word, `--flag` (case-insensitively).
	---
	---@param line string
	---@param flags string[]
	---@return table<string, 1>
	function parseFlags(line, flags)
		local res = {};
		local lower_line = strlower(line);
		for _, flag in flags do
			-- (followed by whitespace or the end of the line, so `--forceful` doesn't set `force`)
			local flag_pattern = "%-%-" .. escapePattern(strlower(flag));
			if (findAtWordStart(lower_line, flag_pattern .. "%s") or findAtWordStart(lower_line, flag_pattern .. "$")) then
				res[flag] = 1;
			end
		end
		return res;
	end

	function parseCommand(line)
		--- @type string[]
		local words = strsplit(strlower(line), ' ', 1);
		local command_str = words[1];

		-- modkit.table.printTbl(words, "command words");

		if (modkit.table.includesKey(COMMANDS, command_str)) then
			local command = COMMANDS[command_str];
			local param_values = parseParams(line, command.params or {});
			local flags = parseFlags(line, command.flags or {});

			-- consoleLog("> " .. command_str);
			-- COMMANDS[command].fn(line, words);
			-- protected call: this runs from a key binding (`flushKeyBuffer`), where an uncaught error is a FATAL EXIT for the game
			local caught = {}; -- (a table, since upvalues can't be assigned to)
			local succeeded = protectedCall(
				command.fn,
				{ param_values, words, flags, line; n = 4 }, -- (Lua 4: `;` separates list and record parts)
				function (message)
					%caught.message = message;
				end
			);
			if (not succeeded) then
				local printErr = consoleError or print;
				printErr("command '" .. command_str .. "' failed: " .. tostring(caught.message or "unknown error") .. " (see the game log for the traceback)");
			end
		else
			consoleLog("no such command: '" .. command_str .. "'");
		end
	end

	PARAMS = {
		int = function (names, default)
			names = names or { 'n', 'v', 'val', 'value' };
			return {
				names = names,
				default = default,
				pattern = "[+-]?%d+", -- (an integer, with an optional sign)
				transform = function (number_str)
					return tonumber(number_str);
				end
			};
		end,
		intToPlayer = function (names, default)
			names = names or { 'p', 'player' };
			return modkit.table:merge(
				PARAMS.int(names, default),
				{
					transform = function (value)
						value = tonumber(value);
						print("trying to fetch player id " .. value);
						if (value == nil) then return nil; end
						return GLOBAL_PLAYERS:get(value);
					end
				}
			);
		end,
		str = function (names, default)
			return {
				names = names,
				default = default,
				pattern = "[%a%d_-]+"
			};
		end,
		vec3 = function (names, default)
			return {
				names = names,
				default = default,
				-- three numbers, each with an optional sign and decimal part (i.e `10 -5.5 +.25`)
				pattern = "[+-]?%d*%.?%d+%s+[+-]?%d*%.?%d+%s+[+-]?%d*%.?%d+",
			};
		end,
		strToVec3 = function (names, default)
			return modkit.table:merge(
				PARAMS.vec3(names, default),
				{
					transform = function (value)
						-- components arrive as strings; convert them, so the result is a proper (numeric) Vec3
						return Vec3:create(modkit.table.map(strsplit(value, "%s+", 1), function (component)
							return tonumber(component);
						end));
					end
				}
			);
		end,
		strToShipsOfType = function (names, default)
			return modkit.table:merge(
				PARAMS.str(names, default),
				{
					transform = function (value)
						return GLOBAL_SHIPS:filter(function (ship)
							return strfind(ship.ship_type, %value);
						end);
					end
				}
			);
		end,
		strToShipsOfFamily = function (names, default)
			return modkit.table:merge(
				PARAMS.str(names, default),
				{
					transform = function (value)
						return GLOBAL_SHIPS:filter(function (ship)
							return strfind(ship:attackFamily(), %value);
						end);
					end
				}
			);
		end
	};

	---@class COMMANDS: table
	COMMANDS = {};
	doscanpath("data:scripts/modkit/console/commands", "*.lua");

	MODKIT_CONSOLE_COMMANDS = 1;
end
