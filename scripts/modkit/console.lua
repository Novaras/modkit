if (MODKIT_CONSOLE == nil) then
	dofilepath("data:scripts/modkit/scope_state.lua");
	doscanpath("data:scripts/modkit/console", "*.lua");

	print("Console init...");

	MODKIT_CONSOLE = 1;
end