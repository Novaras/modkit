if (MODKIT_CONSOLE == nil) then
	doscanpath("data:scripts/modkit/console", "*.lua");
	consoleLog("Console running...");

	MODKIT_CONSOLE = 1;
end