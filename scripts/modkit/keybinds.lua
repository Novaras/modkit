if (MODKIT_KEYBINDS == nil) then
    MK_KeyFunctions = {
        showConsoleScreen = {
            key = PKEY,
            fn = function ()
                if (modkit == nil or modkit.console == nil) then
                    dofilepath("data:scripts/modkit/console.lua");
                end
                UI_ToggleScreen("MK_ConsoleScreen", ePopup);
                textCaptureMode();
            end
        },
    };

    --- Force binds keys as defined in `MK_KeyFunctions`.
    ---
    function modkitBindKeys()
        print("== begin modkit keybinds ==");
		for k, v in MK_KeyFunctions do
			print("bind "  .. k .. " to key " .. tostring(v.key));
			-- make a global fn with a scoped name, then we refer to that in the call to UI_ForceBindKeyEvent
			local global_name = "MK_KEYBIND_" .. k .. "_" .. tostring(v.key);
			rawset(globals(), global_name, v.fn);
			UI_ForceBindKeyEvent(v.key, global_name);
		end
		MK_KEYBINDS_COMPLETE = 1;
		print("== keybinds applied ==");
    end

    MODKIT_KEYBINDS = 1;
end
