COMMANDS = COMMANDS or {};

COMMANDS.commands = COMMANDS.commands or {
    description = "Lists all commands.",
    syntax = "commands",
    fn = function ()
        consoleLogRows(modkit.table.keys(COMMANDS), 3);
    end
};
