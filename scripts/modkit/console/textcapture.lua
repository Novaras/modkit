if (MODKIT_TEXTCAPTURE == nil) then
    if ((modkit or modkit.table or modkitBindKeys) == nil) then
        dofilepath("data:scripts/modkit/table_util.lua");
        dofilepath("data:scripts/modkit/console/main.lua");
        dofilepath("data:scripts/modkit/keybinds.lua");
    end

    ---@type string The prefix shown before the user input in the console window
    prefix = "> ";

    ---@type string The user's buffered input (input which has not been submitted with `flushKeyBuffer`)
    key_buffer = "";

    -- ===

    --!!TODO!! this is still just global state

    input_recall = {
        ---@type integer
        idx = 0,
        ---@type string[]
        lines = {},
    };

    function input_recall:set(lines)
        self.lines = lines;
        self:resetIdx();
    end

    function input_recall:clear()
        self.lines = {};
    end

    function input_recall:resetIdx()
        self.idx = modkit.table.length(self.lines) + 1;
    end

    function input_recall:push(line)
        modkit.table.push(self.lines, line);
    end

    function input_recall:next()
        -- print("get next line");
        -- print("idx is " .. self.idx);
        if (self.lines[1] == nil) then
            return nil;
        end
        self.idx = max(1, self.idx - 1);
        -- print("set to " .. self.idx);
        -- print("returning " .. self.lines[self.idx]);
        return self.lines[self.idx];
    end

    function input_recall:previous()
        self.idx = min(modkit.table.length(self.lines), self.idx + 1);
        return self.lines[self.idx];
    end

    -- ===

    input_cursor = {
        pos = -1,
    };

    function input_cursor:reset()
        pos = strlen(key_buffer);
    end

    function input_cursor:back(amount)
        return self:set(self.pos + (amount or 1))
    end

    function input_cursor:forward(amount)
        return self:set(self.pos - (amount or 1));
    end

    function input_cursor:set(pos)
        -- print("attempt set cursor pos to " .. (pos or 'nil'));
        self.pos = max(-1, min(strlen(key_buffer), pos));
        -- print("cursor pos now " .. self.pos);
        UI_SetTextLabelText("MK_ConsoleScreen", 'cursor_offset', strsub(prefix .. key_buffer, 1, self.pos + strlen(prefix) + 1));
        return self.pos;
    end

    -- ===

    ---@type bool Whether or not the console's input is in capslock/shift
    shift_state = nil;

    -- ===

    --- Sets the key buffer and displays it in the console input label
    ---
    ---@param val string
    function setKeyBuffer(val)
        key_buffer = val;
        local full = prefix .. (key_buffer or '');
        UI_SetTextLabelText("MK_ConsoleScreen", 'input_target', full);
    end

    --- Pushes a character to the end of the key buffer, implementing character input behavior.
    ---
    ---@param letter string
    function pushKeyBuffer(letter)
        input_cursor:back();
        input_recall:resetIdx();
        local pre = strsub(key_buffer, 1, input_cursor.pos);
        local post = strsub(key_buffer, input_cursor.pos + 1, strlen(key_buffer));
        setKeyBuffer(pre .. letter .. post);
    end

    --- Pops a character from the end of the key buffer, implementing backspace/delete behavior.
    ---
    ---@return string popped The popped char
    function popKeyBuffer()
        local popped = "";
        if (strlen(key_buffer) > 0) then
            popped = strsub(key_buffer, input_cursor.pos, input_cursor.pos - 1);
            local pre = strsub(key_buffer, 0, input_cursor.pos);
            local post = strsub(key_buffer, input_cursor.pos + 2, strlen(key_buffer));
            setKeyBuffer(pre .. post);
            if (strlen(key_buffer) > 0) then
                input_cursor:forward();
            else
                input_cursor:reset();
            end
            input_recall:resetIdx();
        end
        return popped;
    end

    --- Toggles the capslock/shift state.
    function toggleCaps()
        if (shift_state == nil) then
            shift_state = 1;
        else
            shift_state = nil;
        end
        -- print("SHIFT TOGGLE TO " .. tostring(shift_state));
    end

    --- Enables/disables various UI screens which would otherwise interrupt user input (UI is unbindable).
    ---@param disable? bool
    function setScreens(disable)
        -- !!TODO!! Maybe can truly bind a key by implementing some kind of 'bindkey' event which also sends a message to the UI scope?

        local arg = 1;
        if (disable) then
            arg = 0;
        end

        for _, screen_name in {
            'ObjectivesList',
            'UnitCapInfoPopup',
            'EventsScreen',
            'BuildQueueMenu'
        } do
            UI_SetScreenEnabled(screen_name, arg);
        end
    end

    --- Does nothing: no-operation
    NOOP = NOOP or function()
        --
    end

    --- Flushes the key buffer.
    function flushKeyBuffer()
        print("received buffer: " .. key_buffer);
        if (strlen(key_buffer) > 0) then
            input_recall:push(key_buffer);
            input_recall:resetIdx();
            local line = gsub(key_buffer, "\"", "\'");
            consoleLog('<c=2255ff><b>' .. line .. '</b></c>');

            local words = strsplit(line, " ", 1);

            if (words[1] == "do") then -- run as Lua code
                local lua_str = strsub(line, 4);
                print("DO: " .. (lua_str or 'nil'));
                dostring(lua_str);
            elseif (words[1] == "run") then -- load & execute a file
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
            else -- parse as a command
                parseCommand(line);
            end
        end

        setKeyBuffer('');
        input_cursor:reset();
        input_recall:resetIdx();
    end

    --- Enables/disables 'text capture mode', which force binds most of the keys on the keyboard to custom events used by the console.
    ---
    --- The captured keypresses are mostly pushed to the key buffer, which is flushed using `flushKeyBuffer`.
    ---
    ---@param disable? bool
    function textCaptureMode(disable)
        local verb = "BEGIN";
        if (disable) then
            verb = "DISABLE";
        end
        print("=== " .. verb .. " TEXT CAPTURE MODE ===");

        if (input_cursor.pos == -1) then
            input_cursor:reset();
        end

        -- !!TODO!! All of these definition tables should be moved into conf files or at least free tables

        local letters = {
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        };
        local numbers = {
            'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'ZERO',
        };
        local extras = {
            'PLUS', 'MINUS', 'SLASH', 'APOSTROPHE', 'SPACE', 'F1', 'F2', 'F3', 'F4',
        };
        local recall = {
            'PAGEUP', 'ARRUP', 'PAGEDOWN', 'ARRDOWN',
        };
        local cursor = {
            'ARRRIGHT', 'ARRLEFT',
        }

        for group_type, group in { letters = letters, numbers = numbers, extras = extras, recall = recall, cursor = cursor } do
            for i, keyname in group do
                local char = keyname;

                if (group_type == 'numbers') then
                    if (keyname == 'ZERO') then
                        char = '0';
                    else
                        char = tostring(i);
                    end
                elseif (group_type == 'extras') then
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

                local keycode = globals()[keyname .. 'KEY'] or globals()[keyname];
                local callback_name = "pushKeyBuffer" .. keyname;
                -- print('binding key ' .. keyname .. ' (' .. tostring(keycode) .. ')');

                if (group_type == 'letters') then -- its a letter
                    -- print("letter bind is " .. callback_name .. " char = " .. char);
                    rawset(globals(), callback_name, function ()
                        -- print("call for key " .. %char);
                        if (shift_state == 1) then
                            pushKeyBuffer(%char);
                        else
                            pushKeyBuffer(strlower(%char));
                        end
                    end);
                elseif (group_type == 'numbers') then
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
                elseif (group_type == 'recall') then
                    rawset(globals(), callback_name, function ()
                        local keyname = %keyname;

                        ---@type string?
                        local line = '';

                        if (keyname == 'PAGEUP' or keyname == 'ARRUP') then
                            line = input_recall:next();
                        end

                        if (keyname == 'PAGEDOWN' or keyname == 'ARRDOWN') then
                            if (input_recall.idx == modkit.table.length(input_recall.lines)) then
                                line = '';
                            else
                                line = input_recall:previous();
                            end
                        end

                        -- modkit.table.printTbl(input_recall.lines, "rec lines");
                        setKeyBuffer(line or '');
                        input_cursor:reset();
                    end);
                elseif (group_type == 'cursor') then
                    rawset(globals(), callback_name, function ()
                        local keyname = %keyname;

                        -- print("HELLO: " .. keyname .. ", " .. %group_type);

                        if (keyname == 'ARRRIGHT') then
                            input_cursor:back();
                        end

                        if (keyname == 'ARRLEFT') then
                            input_cursor:forward();
                        end

                        setKeyBuffer(key_buffer or '');
                        input_recall:resetIdx();
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

                if (disable) then
                    UI_ForceBindKeyEvent(keycode);
                else
                    UI_ForceBindKeyEvent(keycode, callback_name);
                end
            end
        end

        __bindConsoleClose = __bindConsoleClose or function ()
            -- print("ok hide the screen");
            UI_ToggleScreen('MK_ConsoleScreen', ePopup);
            textCaptureMode(1);
        end

        --!!TODO!! needs refactor
        if (disable) then
            Universe_Pause(0, 0);
            MainUI_DisableAllCommands(0);
            UI_ForceBindKeyEvent(ENTERKEY);
            UI_ForceBindKeyEvent(ESCKEY);
            UI_ForceBindKeyEvent(BACKSPACEKEY);
            UI_ForceBindKeyEvent(CAPSLOCKKEY);
            setScreens();
            modkitBindKeys();
        else
            Universe_Pause(1, 0);
            MainUI_DisableAllCommands(1);
            UI_ForceBindKeyEvent(ENTERKEY, "flushKeyBuffer");
            UI_ForceBindKeyEvent(ESCKEY, "__bindConsoleClose")
            UI_ForceBindKeyEvent(BACKSPACEKEY, "popKeyBuffer");
            UI_ForceBindKeyEvent(CAPSLOCKKEY, "toggleCaps");
            setScreens(1);
        end
    end
    MODKIT_TEXTCAPTURE = 1;
end
