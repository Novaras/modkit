if (MODKIT_CONSOLE == nil) then
	print("Console init...");

	if (modkit == nil) then
		modkit = {};
	end
	dofilepath("data:scripts/modkit/hypertable.lua");
	doscanpath("data:scripts/modkit/console", "*.lua");

	-- no `consoleLog` here: this file loads during level load, before the UI screens exist, so any UI
	-- calls just spam 'screen does not exist' warnings. The help hint is logged on first open (see `keybinds.lua`).

	local CONSOLE = {
		log = consoleLog,
		error = consoleError,
		rows = consoleLogRows
	};
	modkit.console = CONSOLE;

	MODKIT_CONSOLE = 1;
end