if (MODKIT_CONSOLE == nil) then
	print("Console init...");
	dofilepath("data:scripts/modkit/scope_state.lua");
	doscanpath("data:scripts/modkit/console", "*.lua");

	if (consoleLog) then
		consoleLog("Type 'help' for help, or 'help [command]' for details on a command.");
	end

	MODKIT_CONSOLE = 1;
end