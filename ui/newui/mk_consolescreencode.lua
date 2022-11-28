dofilepath('data:scripts/modkit/scope_state.lua');
dofilepath('data:scripts/modkit/console.lua');

SCREEN_NAME = "MK_ConsoleScreen";
LISTBOX_NAME = "main_display";

out_str = "";




function onShow()
	print("SHOW CONSOLE SCREEN");
	
	-- UI_SetInterfaceEnabled(0);
end

function onHide()
	print("HIDE CONSOLE SCREEN");
end