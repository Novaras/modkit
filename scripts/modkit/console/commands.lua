if (MODKIT_CONSOLE_COMMANDS == nil) then
	if (modkit == nil or modkit.table == nil) then
		dofilepath("data:scripts/modkit/string_util.lua");
		dofilepath("data:scripts/modkit/table_util.lua");
	end

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


	---@class ParamConfig
	---@field names string[] The param name(s), i.e 'p' in 'p=10'
	---@field pattern string The regex pattern to match for the value, i.e '%S+' for 'hello' in 'word=hello'
	---@field default? any The optional default value if the param is not provided
	---@field transform? fun(value: any): any

	---@class CommandFn
	---@field params? ParamConfig[]
	---@field flags? string[]
	---@field description? string
	---@field fn fun(params: any[], words: string[], flags: any[], line: string): any

	---@alias ParamConfigGenerator fun(names: string[], default: any): ParamConfig

	---@type ParamConfigGenerator[]
	PARAMS = {
		int = function (names, default)
			names = names or { 'n' };
			return {
				names = names,
				default = default,
				pattern = "%d+"
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
				pattern = "[%a_-]+"
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
	COMMANDS = {
		spawn = {
			description = "Spawns ships for a player",
			params = {
				player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
				count = PARAMS.int({ 'c', 'count', 'n' }, 1),
				position = PARAMS.strToVec3({ 'pos', 'position' }, "0 0 0")
			},
			fn = function (param_vals, words)
				local ship_type = words[2];
				if (ship_type) then
					---@type Player
					local player = param_vals.player;
					---@type integer
					local spawn_count = param_vals.count;
					---@type Position
					local pos = param_vals.position;

					local makeVol = makeSpawnVolGenerator(1000 + (20 * min(spawn_count, 100)));

					consoleLog("\tspawning " .. spawn_count .. "x ".. ship_type .. " for player " .. player.id);
					for _ = 0, spawn_count - 1 do
						SobGroup_SpawnNewShipInSobGroup(
							player.id,
							ship_type,
							'__console_spawn' .. Universe_GameTime(),
							player:shipsGroup(),
							makeVol(pos)
						);
					end
				else
					consoleLog("spawn: missing required argument 1 'ship_type': 'spawn {ship_type}', i.e 'spawn hgn_interceptor'")
				end
			end,
		},
		attack = {
			description = "Causes all of one player's ships to attack all of another player's ships.",
			params = {
				attacker = PARAMS.intToPlayer({ 'a', 'atk', 'attacker' }, 0),
				target = PARAMS.intToPlayer({ 't', 'trg', 'target' }),
			},
			fn = function (param_vals)
				---@type Player
				local attacker = param_vals.attacker;
				---@type Player
				local target = param_vals.target;

				if (target) then
					consoleLog(attacker.id .. " attacking player " .. target.id);
					attacker:attack(target);
				else
					consoleLog("attack: missing required param 'target={player id}' i.e 'target=1'");
				end
			end
		},
		fight = {
			description = "Causes the given players to attack eachother.",
			fn = function (_, words)
				local player_a = words[2];
				local player_b = words[3];

				parseCommand('attack attacker=' .. player_a .. " target=" .. player_b);
				parseCommand('attack attacker=' .. player_b .. " target=" .. player_a);
			end,
		},
		research = {
			description = "Grants, starts, or cancels research for a player.",
			params = {
				player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
				research_name = modkit.table:merge(
					PARAMS.str({ 'r', 'research', 't', 'type', 'name' })
				)
			},
			fn = function (param_vals, words, flags)
				local verb = words[2] or 'grant';

				---@type Player
				local player = param_vals.player;
				---@type string
				local res_name = param_vals.research_name;

				---@type ResearchItem
				-- local research_item = modkit.research:find(res_name, player:race;

				if (research_item) then
					if (verb == 'grant') then
						local all = research_name == 'all';

						if (all) then
							player:grantAllResearch();
						else
							consoleLog("GRANT " .. research_item.name);
							player:grantResearchOption(research_item);
						end
					elseif (verb == 'start') then
						player:doResearch(research_item);
					elseif (verb == 'cancel') then
						player:cancelResearch(research_item);
					elseif (verb == 'has') then
						local phrase = "doesn't have";
						if (player:hasResearch(research_item)) then
							phrase = 'has';
						end
						consoleLog("Player " .. player.id .. " " .. phrase .. " tech " .. research_item.name);
					else
						consoleLog("research: missing required argument 1 'verb' {grant|start|cancel|has}, i.e 'research start t=corvettedrive");
					end
				else
					consoleLog("research: missing required param 'research_name', i.e 'research type=CorvetteDrive'");
				end
			end
		},
		ru = {
			description = "Grants (adds) or sets RU for a player.",
			params = {
				player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
				amount = PARAMS.int({ 'n', 'v', 'val', 'value', 'amount' })
			},
			fn = function (param_vals, words)
				local verb = words[2];
				local player = param_vals.player;
				local amount = param_vals.amount;

				if (amount == nil) then
					consoleLog("ru: missing require param 'val={amount}' i.e 'value=1000'");
				else
					if (verb == 'grant') then
						Player_SetRU(player.id, Player_GetRU(player.id) + amount);
					elseif (verb == 'set') then
						Player_SetRU(player.id, amount);
					else
						consoleLog("ru: invalid argument 1 'verb': 'ru {grant|set}', i.e 'ru grant val=1000 p=0'");
					end
				end
			end,
		},
		kill = {
			description = "Kills a player.",
			fn = function (_, words)
				local player_index = tonumber(words[2]);
				if (player_index) then
					Player_Kill(player_index);
				else
					consoleLog("kill: invalid argument 1 'player id': 'kill {id}', i.e 'kill 1'");
				end
			end,
		},
		destroy = {
			description = "Destroys ships.",
			params = {
				type = PARAMS.str({ 't', 'type' }),
				family = PARAMS.str({ 'f', 'family' }),
				player = PARAMS.intToPlayer()
			},
			fn = function (param_vals)
				---@type Ship[]
				local src = shipsFromParamValues(param_vals);

				for _, ship in src do
					ship:die();
				end
			end,
		},
		gametime = {
			description = "Prints the current gametime.",
			fn = function ()
				consoleLog("gametime is " .. Universe_GameTime());
			end,
		},
		log = {
			description = "Logs (echos) the supplied string.",
			fn = function (line)
				consoleLog(strsub(line, 4, strlen(line)));
			end,
		},
		gamespeed = {
			description = "Sets the game speed to a multiplier of the default speed.",
			fn = function (_, words)
				local stateHnd = makeStateHandle();
				local speed = words[2];

				if (speed) then
					local existing_stack = stateHnd().ui_scope_exec;
					stateHnd({
						ui_scope_exec = modkit.table.push(existing_stack or {}, 'SetTurboSpeed(1); SetTurboSpeed(' .. speed .. ")");
					});
				else
					consoleLog("gamespeed: missing required argument 1 'speed': gamespeed {speed} i.e: 'gamespeed 8'");
				end
			end,
		},
		move = {
			description = "Causes ships to move (or teleport) to a position.",
			params = {
				type = PARAMS.str({ 't', 'type' }),
				family = PARAMS.str({ 'f', 'family '}),
				player = PARAMS.intToPlayer(),
				position = PARAMS.strToVec3({ 'p', 'pos', 'position' })
			},
			flags = {
				'force'
			},
			fn = function (param_vals, _, flags)
				---@type Position?
				local pos = param_vals.position;

				modkit.table.printTbl(flags, "ye");

				if (pos) then
					---@type Ship[]
					local src = shipsFromParamValues(param_vals);

					for _, ship in src do
						ship:move(pos); -- clears any parades etc.
						if (flags.force) then
							ship:position(pos);
						end
					end
				else
					consoleLog("move: missing required param 'pos={x y z}', i.e: 'pos=10 1000 -500'");
				end
			end,
		},
		foreach = {
			description = "Runs a command or Lua string for a ship selection.",
			params = {
				lua = {
					names = { "lua" },
					pattern = ".+"
				},
				type = PARAMS.str({ 't', 'type' }),
				family = PARAMS.str({ 'f', 'family' }),
				player = PARAMS.intToPlayer(),
				command = {
					names = { "cmd", "command" },
					pattern = "%w+",
					transform = function (value)
						return COMMANDS[value];
					end
				}
			},
			fn = function (param_vals, _, _, line)
				if (param_vals.lua) then
					---@type string?
					local lua_str = param_vals.lua;
					---@type string?
					local type = param_vals.type;
					---@type string?
					local family = param_vals.family;
					---@type Player?
					local player = param_vals.player;
					local pid;
					if (player) then
						pid = player.id;
					end

					local src = shipsFromParamValues(param_vals);
					makeStateHandle()({
						foreach_src = modkit.table.map(src, function (ship)
							return { id = ship.id, type = ship.type_group, player_id = ship.player.id };
						end)
					});

					local parsed = gsub(lua_str, "$t", type or '');
					parsed = gsub(parsed, "$f", family or '');
					parsed = gsub(parsed, "$p", pid or '');
					parsed = gsub(parsed, "$g", "'" .. SobGroup_FromShips(src) .. "'");
					parsed = gsub(parsed, "$s", 'modkit.table.map(makeStateHandle()().foreach_src, function(ship_def) return register(ship_def.type, ship_def.player_id, ship_def.id); end)');

					-- consoleLog("EXEC: " .. parsed);

					parsed = "dofilepath('data:scripts/modkit/scope_state.lua'); " ..
						"dofilepath('data:scripts/modkit/driver.lua'); " ..
						parsed;

					print("foreach >> " .. parsed);
					dostring(parsed);

				elseif (param_vals.command) then
					local cmd = param_vals.command;

					local s = cmd .. strsub(gsub(line, "cmd=%w+", ""), 8, strlen(line));
					print(s);
					parseCommand(s);
				else
					consoleLog("foreach: missing one of either 'lua={lua code}' or 'cmd={console command}'");
				end
			end,
		},
		hp = {
			description = "Sets the HP (as a fraction [0..1]) for ships.",
			fn = function (_, words, _, line)
				if (words[2]) then
					local str = "foreach " .. strsub(line, 3, strlen(line)) .. " lua=SobGroup_SetHealth($g, " .. words[2] .. ");";
					-- consoleLog("parsed to: " .. str);
					parseCommand(str);
				end
			end,
		},
		swap = {
			description = "Swaps all the ships of two given players.",
			fn = function (_, words)
				-- consoleLog("swap?");

				if (words[2] == nil or words[3] == nil) then
					consoleLog("swap: missing one or both required arguments 'swap {player-1} {player-2}' i.e 'swap 0 1'");
					return nil;
				end

				---@type Player[]
				local players = modkit.table.map({ words[2], words[3] }, function (id_str)
					return GLOBAL_PLAYERS:get(tonumber(id_str));
				end);

				local old_groups = modkit.table.map(players, function (player)
					return SobGroup_Clone(player:shipsGroup());
				end);

				local temp_group = SobGroup_Fresh();
				for idx = 1, modkit.table.length(players) do
					local p = players[idx];
					local g = old_groups[idx];
					local n = modkit.table.length(players) + 1;
					SobGroup_SpawnNewShipInSobGroup(p.id, "kpr_destroyer", "", temp_group, Volume_Fresh());

					local other_idx = max(1, mod(idx + 1, n));
					-- print("get at " .. other_idx);
					-- print("g: " .. g);
					-- print("g.c: " .. SobGroup_Count(g));
					-- print("from " .. p.id .. " to " .. players[other_idx].id);
					SobGroup_SwitchOwner(g, players[other_idx].id);
				end

				SobGroup_Despawn(temp_group);
				SobGroup_SetHealth(temp_group, 0);
			end
		},
		help = {
			description = "Prints help for a given command.",
			fn = function (_, words)
				local cmd = nil;
				if (words[2]) then
					cmd = COMMANDS[words[2]];
				end

				if (cmd) then
					consoleLog("command " .. words[2]);
					consoleLog(cmd.description);
					consoleLog("params");
					for param, conf in (cmd.params or {}) do
						consoleLog("\t" .. param .. ": [ " .. strimplode(conf.names, ", ") .. " ]");
					end
					consoleLog("flags");
					for _, flag in (cmd.flags or {}) do
						consoleLog("\t" .. flag);
					end
				else
					consoleLog("HWRM Console made by Fear (Novaras). Please see the README linked in the Steam workshop!");
				end
			end
		},
	};


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
					print("OK GOT CAPTURE FROM " .. s .. " TO " .. e .. " (label is " .. label .. ")");
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
		modkit.table.printTbl(res, "res");

		return res;
	end

	function parseFlags(line, flags)
		local res = {};
		for _, flag in flags do
			print("look for " .. '--' .. flag);
			if (strfind(line, '--' .. flag)) then
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

	MODKIT_CONSOLE_COMMANDS = 1;
end