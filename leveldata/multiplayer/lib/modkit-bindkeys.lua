dofilepath("data:scripts/modkit/console.lua");

MK_KEYBINDS_COMPLETE = nil;

MK_KeyFunctions = {
	showConsoleScreen = {
		key = PKEY,
		fn = function ()
			UI_ToggleScreen("MK_ConsoleScreen", ePopup);
			bind_flag = 1;
		end
	},
};

function modkit_bindkeys(force)
	local tidyRule = function ()
		if (Rule_Exists("modkit_bindkeys") == 1) then
			Rule_Remove("modkit_bindkeys");
		end
	end
	if (MK_KEYBINDS_COMPLETE == nil or force == 1) then
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
	elseif (MK_KEYBINDS_COMPLETE == 1) then
		print("== keybinds already applied, noop ==");
	end
	tidyRule();
end
