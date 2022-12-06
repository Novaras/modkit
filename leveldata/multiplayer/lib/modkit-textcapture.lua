dofilepath("data:scripts/modkit/sobgroup.lua");
dofilepath("data:scripts/modkit/string_util.lua");
dofilepath("data:scripts/modkit/console.lua");
dofilepath("data:scripts/modkit/commands.lua");

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

bind_flag = 0;
prefix = "> ";
key_buffer = "";
screens_to_disable = {
	'ObjectivesList',
	'UnitCapInfoPopup',
	'EventsScreen',
	'BuildQueueMenu'
};

-- ===

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