COMMANDS = COMMANDS or {};

COMMANDS.gametime = COMMANDS.gametime or {
    description = "Prints the current gametime.",
    syntax = "gametime",
    fn = function ()
        consoleLog("gametime is " .. Universe_GameTime());
    end,
};
