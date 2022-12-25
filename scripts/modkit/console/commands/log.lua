COMMANDS = COMMANDS or {};

COMMANDS.log = COMMANDS.log or {
    description = "Logs (echos) the supplied string.",
    syntax = "log <string...>",
    example = "log hello world!",
    fn = function (_, _, _, line)
        consoleLog(strsub(line, 4, strlen(line)));
    end,
};
