if (MODKIT_CONSOLE_COMMANDS == nil) then
	if (modkit == nil or modkit.table == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end
	if (strsplit == nil) then
		dofilepath("data:scripts/modkit/string_util.lua");
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
			consoleLog("destroy: ignoring family param (f=" .. params.family .. ") due to presence of type param (t=" .. params.type .. ")");
		end

		if (params.type) then
			src = modkit.table.filter(src, function (ship)
				return ship.ship_type == %params.type;
			end);
		elseif (params.family) then
			src = modkit.table.filter(src, function (ship)
				return ship:attackFamily() == %params.family;
			end);
		end

		if (params.player) then
			src = modkit.table.filter(src, function (ship)
				return ship.player.id == %params.player.id;
			end);
		end

		return src;
	end

	---comment
	---@param line string
	---@param params ParamConfig[]
	function parseParams(line, params)
		local res = {};

		-- int = function (names, default)
		-- 	names = names or { 'n' };
		-- 	return {
		-- 		names = names,
		-- 		default = default,
		-- 		pattern = "%d+"
		-- 	};
		-- end,

		for label, conf in params do
			local value = nil;
			for _, name in conf.names do
				local s, e = strfind(line, name .. "=" .. conf.pattern);
				e = e or strlen(line);
				if (s) then
					-- print("OK GOT CAPTURE FROM " .. s .. " TO " .. e .. " (label is " .. label .. ")");
					local capture = strsub(line, s, e);
					-- consoleLog("\tcapture: " .. capture);
					local parts = strsplit(capture, "=", 1);
					value = parts[2];
					-- consoleLog("\t\tval = " .. tostring(value));
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

	function parseFlags(line, flags)
		local res = {};
		for _, flag in flags do
			-- print("look for " .. '--' .. flag);
			if (strfind(line, '--' .. flag, 1, 1)) then
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
			command.fn(param_values, words, flags, line);
		else
			consoleLog("no such command: '" .. command_str .. "'");
		end
	end

	---@type ParamConfigGenerator[]
	PARAMS = {
		int = function (names, default)
			names = names or { 'n', 'v', 'val', 'value' };
			return {
				names = names,
				default = default,
				pattern = "%d+",
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
				pattern = "[%d-]+%s+[%d-]+%s+[%d-]+",
			};
		end,
		strToVec3 = function (names, default)
			return modkit.table:merge(
				PARAMS.vec3(names, default),
				{
					transform = function (value)
						return strsplit(value, "%s+", 1);
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

	---@type CommandFn[]
	COMMANDS = {};
	doscanpath("data:scripts/modkit/console/commands", "*.lua");

	MODKIT_CONSOLE_COMMANDS = 1;
end