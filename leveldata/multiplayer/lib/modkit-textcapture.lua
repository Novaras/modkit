dofilepath("data:scripts/modkit/sobgroup.lua");
dofilepath("data:scripts/modkit/string_util.lua");

function modkit_poll_text_capture()
	if (bind_flag == 1) then
		print("TRIGGER");
		popKeyBuffer();
		textCaptureMode();
	elseif (bind_flag == 2) then
		print("UNBINDING");
		textCaptureMode(1); -- unbind
	end

	bind_flag = 0;
end

-- ===

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
bind_flag = 0;
prefix = "> ";
key_buffer = "";
screens_to_disable = {
	'ObjectivesList',
	'UnitCapInfoPopup',
	'EventsScreen',
	'BuildQueueMenu'
};
COMMAND_FNS = {
	spawn = function (line, words)
		local ship_type = words[2];
		if (ship_type) then
			local player_index = tonumber(getParamVal(line, "p=", "%d+")) or 0;
			local spawn_count = tonumber(getParamVal(line, "c=","%d+")) or 1;

			local newSpawnAreaVol = makeSpawnVolGenerator(1000 + (20 * min(spawn_count, 100)));

			local pos = {0, 0, 0};
			local pos_str = getParamVal(line, "pos=", "[%d-]+%s+[%d-]+%s+[%d-]+");
			if (pos_str) then
				consoleLog("spawn at " .. pos_str);
				pos = strsplit(pos_str, " ", 1);
			end

			consoleLog("\tspawning " .. spawn_count .. "x ".. ship_type .. " for player " .. player_index);
			for _ = 0, spawn_count - 1 do
				SobGroup_SpawnNewShipInSobGroup(
					player_index,
					ship_type,
					'__console_spawn' .. Universe_GameTime(),
					"Player_Ships" .. player_index,
					newSpawnAreaVol(pos)
				);
			end
		else
			consoleLog("spawn: missing required argument 1 'ship_type': 'spawn {ship_type}', i.e 'spawn hgn_interceptor'")
		end
	end,
	attack = function (line)
		local attacking_player = tonumber(getParamVal(line, "attacker=", "[-%d]+")) or 0;
		local target_player = tonumber(getParamVal(line, "target=", "[-%d]+"));

		if (target_player) then
			consoleLog(attacking_player .. " attacking player " .. target_player);
			SobGroup_Attack(attacking_player, "Player_Ships" .. attacking_player, "Player_Ships" .. target_player);
		else
			consoleLog("attack: missing required param 'target={player id}' i.e 'target=1'");
		end
	end,
	fight = function (_, words)
		local player_a = words[2];
		local player_b = words[3];

		COMMAND_FNS['attack']('attack attacker=' .. player_a .. " target=" .. player_b);
		COMMAND_FNS['attack']('attack attacker=' .. player_b .. " target=" .. player_a);
	end,
	ru = function (line, words)
		local verb = words[2];
		local player_index = tonumber(getParamVal(line, "p=", "[-%d]+")) or 0;
		local amount = tonumber(getParamVal(line, "val=", "%d+"));

		if (amount == nil) then
			consoleLog("ru: missing require param 'val={amount}' i.e 'value=1000'");
		else
			if (verb == 'give') then
				Player_SetRU(player_index, Player_GetRU(player_index) + amount);
			elseif (verb == 'set') then
				Player_SetRU(player_index, amount);
			else
				consoleLog("ru: invalid argument 1 'verb': 'ru {give|set}', i.e 'ru give val=1000 p=0'");
			end
		end
	end,
	kill = function (_, words)
		local player_index = tonumber(words[2]);
		if (player_index) then
			Player_Kill(player_index);
		else
			consoleLog("kill: invalid argument 1 'player id': 'kill {id}', i.e 'kill 1'");
		end
	end,
	destroy = function (line)
		local type = getParamVal(line, "t=", "[%a_]+");
		local family = getParamVal(line, "f=", "[%a]+");
		local player_index = tonumber(getParamVal(line, "p=", "[-%d]+"));

		local source_group = "";
		if (player_index == nil) then
			source_group = Universe_GetAllActiveShips();
		else
			source_group = "Player_Ships" .. player_index;
		end

		if (type and family) then
			consoleLog("destroy: ignoring family param (f=" .. family .. ") due to presence of type param (t=" .. t .. ")");
		end

		local target_group = SobGroup_Fresh("__console_destroy_target");
		if (type) then
			SobGroup_FillShipsByType(target_group, source_group, type);
		elseif (family) then
			SobGroup_FilterInclude(target_group, source_group, "attackFamily", family);
		else
			consoleLog("destroy: missing one of either 't={ship-type}' or 'f={ship-family}', i.e 'destroy p=1 t=kus_scout'");
		end
		SobGroup_SetHealth(target_group, 0);
	end,
	gametime = function ()
		consoleLog("gametime is " .. Universe_GameTime());
	end,
	log = function (line)
		consoleLog(strsub(line, 4, strlen(line)));
	end
};

function getParamVal(str, flag_pattern, value_pattern)
	local s, e = strfind(str, flag_pattern .. value_pattern);
	e = e or strlen(str);
	if (s) then
		local offset = strlen(strsub(str, strfind(str, flag_pattern)));
		return strsub(str, s + offset, e);
	end
	return nil;
end

function parseCommand(line)
	--- @type string[]
	local words = strsplit(strlower(line), ' ', 1);
	local command = words[1];

	-- modkit.table.printTbl(words, "command words");

	if (modkit.table.includesKey(COMMAND_FNS, command)) then
		consoleLog("> " .. command);
		COMMAND_FNS[command](line, words);
	else
		consoleLog("no such command: '" .. command .. "'");
	end
end

function printKeyBuffer()
	print("received buffer: " .. key_buffer);
	if (strlen(key_buffer) > 0) then
		local line = gsub(key_buffer, "\"", "\'");
		consoleLog(line);

		local words = strsplit(line, " ", 1);
		if (words[1] == "do") then
			local lua_str = modkit.table.reduce(modkit.table.slice(words, 2), function (acc, word)
				return acc .. word;
			end, '');
			dostring(lua_str);
		elseif (words[1] == "run") then
			local has_prefix = nil;
			local s, e = strfind(words[2], "^%a+:");
			if (s and e) then
				has_prefix = 1;
			end

			if (has_prefix == nil) then
				words[2] = "data:" .. words[2];
			end

			consoleLog("run file: " .. words[2]);
			local success = dofilepath(words[2]);
			if (success == nil) then
				consoleLog("error attempting to run file at path " .. words[2]);
			end
		else
			parseCommand(line);
		end
	end

	key_buffer = "";
	UI_SetTextLabelText("MK_ConsoleScreen", 'input_target', prefix .. key_buffer);
end

function pushKeyBuffer(letter)
	key_buffer = (key_buffer or "") .. letter;
	UI_SetTextLabelText("MK_ConsoleScreen", 'input_target', prefix .. key_buffer);
end

function popKeyBuffer()
	local popped = "";
	if (strlen(key_buffer) > 0) then
		popped = strsub(key_buffer, strlen(key_buffer) - 1, strlen(key_buffer));
		key_buffer = strsub(key_buffer, 0, strlen(key_buffer) - 1);
	end
	UI_SetTextLabelText("MK_ConsoleScreen", 'input_target', prefix .. key_buffer);
	return popped;
end

shift_state = 0;
function toggleCaps()
	if (shift_state == 0) then
		shift_state = 1;
	else
		shift_state = 0;
	end
	print("SHIFT TOGGLE TO " .. tostring(shift_state));
end

function setScreens(enable)
	for _, screen_name in screens_to_disable do
		UI_SetScreenEnabled(screen_name, enable or 1);
	end
end

function NOOP()
end

textCaptureMode = textCaptureMode or function (unbind)
	local letters = {
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
	};
	local numbers = {
		'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'ZERO',
	};
	local extras = {
		'PLUS', 'MINUS', 'SLASH', 'APOSTROPHE', 'SPACE', 'F1', 'F2', 'F3', 'F4',
	};

	for _, group in { letters, numbers, extras } do
		for i, keyname in group do
			local char = keyname;
			local is_letter = modkit.table.includesValue(letters, keyname) == 1;
			local is_number = modkit.table.includesValue(numbers, keyname) == 1;

			if (modkit.table.includesValue(numbers, keyname) == 1) then
				if (keyname == 'ZERO') then
					char = '0';
				else
					char = tostring(i);
				end
			elseif (modkit.table.includesValue(extras, keyname) == 1) then
				if (keyname == 'PLUS') then
					char = '=';
				elseif (keyname == 'MINUS') then
					char = '-';
				elseif (keyname == 'SLASH') then
					char = '/';
				elseif (keyname == 'APOSTROPHE') then
					char = '\"';
				elseif (keyname == 'SPACE') then
					char = ' ';
				elseif (keyname == 'F1') then
					char = '.';
				elseif (keyname == 'F2') then
					char = ',';
				elseif (keyname == 'F3') then
					char = ';';
				elseif (keyname == 'F4') then
					char = '[';
				elseif (keyname == 'F5') then
					char = ']';
				end
			end
			local keycode = globals()[keyname .. 'KEY'];
			local callback_name = "pushKeyBuffer" .. keyname;
			-- print('binding key ' .. keyname .. ' (' .. tostring(keycode) .. ')');

			if (is_letter) then -- its a letter
				-- print("letter bind is " .. callback_name .. " char = " .. char);
				rawset(globals(), callback_name, function ()
					-- print("call for key " .. %char);
					if (shift_state == 1) then
						pushKeyBuffer(%char);
					else
						pushKeyBuffer(strlower(%char));
					end
				end);
			elseif (is_number) then
				rawset(globals(), callback_name, function ()
					local keyname = %keyname;
					local char = %char;
					-- print("call for key " .. char);
					if (shift_state == 1) then
						print("setting shift char for number " .. keyname);
						if (keyname == 'ONE') then
							char = "!";
						elseif (keyname == 'TWO') then
							char = '@';
						elseif (keyname == 'THREE') then
							char = '#';
						elseif (keyname == 'FOUR') then
							char = '$';
						elseif (keyname == 'FIVE') then
							char = '%';
						elseif (keyname == 'SIX') then
							char = '^';
						elseif (keyname == 'SEVEN') then
							char = '&';
						elseif (keyname == 'EIGHT') then
							char = '*';
						elseif (keyname == 'NINE') then
							char = '(';
						elseif (keyname == 'ZERO') then
							char = ')';
						end
					end
					pushKeyBuffer(char);
				end);
			else
				rawset(globals(), callback_name, function ()
					local char = %char;
					local keyname = %keyname;
					if (shift_state == 1) then
						if (keyname == 'MINUS') then
							char = '_';
						elseif (keyname == 'PLUS') then
							char = '+';
						elseif (keyname == 'APOSTROPHE') then
							char = '\'';
						end
					end
					pushKeyBuffer(char);
				end);
			end

			if (unbind) then
				UI_ForceBindKeyEvent(keycode);
			else
				UI_ForceBindKeyEvent(keycode, callback_name);
			end
		end
	end

	if (unbind) then
		Universe_Pause(0, 0);
		MainUI_DisableAllCommands(0);
		UI_ForceBindKeyEvent(ENTERKEY);
		UI_ForceBindKeyEvent(ESCKEY);
		UI_ForceBindKeyEvent(BACKSPACEKEY);
		UI_ForceBindKeyEvent(CAPSLOCKKEY);
		setScreens(1);
		modkit_bindkeys(1);
	else
		Universe_Pause(1, 0);
		MainUI_DisableAllCommands(1);
		setScreens(0);
		UI_ForceBindKeyEvent(ENTERKEY, "printKeyBuffer");
		if (_bindConsoleClose == nil) then
			__bindConsoleClose = function ()
				print("ok hide the screen");
				UI_ToggleScreen('MK_ConsoleScreen', ePopup);
				bind_flag = 2;
			end
		end
		UI_ForceBindKeyEvent(ESCKEY, "__bindConsoleClose")
		UI_ForceBindKeyEvent(BACKSPACEKEY, "popKeyBuffer");
		UI_ForceBindKeyEvent(CAPSLOCKKEY, "toggleCaps");
	end
end