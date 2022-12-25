COMMANDS = COMMANDS or {};

COMMANDS.help = COMMANDS.help or {
    description = [[-------------------------------
Prints help for a given command. See all commands with 'commands'.

Help syntax has variables in <c=11aacc> [square-brackets]</c>.
The command comes first, then any <c=ff1111> arguments</c>, then <c=11ff11> parameters</c> and <c=1111ff> flags</c>.

If any of these types is prefixed by a <b>'?'</b>, it means it is <i>optional</i>.

<b><c=ff1111>Arguments:</c></b>
Just values, like in 'gamespeed [speed-multiplier]' ex: 'gamespeed 2.5'.

<b><c=11ff11>Parameters:</c></b>
<b>key=[value]</b> pairs, like in'attack ?attacker=[player-id] target=[player-id]' ex: 'attack attacker=0 target=1'.

<b><c=1111ff>Flags:</c></b>
Flags are off by default but are set when passed with '--[flag]' ex: 'research grant t=corvettedrive<b> --recurse</b>'.
-------------------------------
]],
    syntax = "help ?[command]",
    example = "help spawn",
    fn = function (_, words)
        local cmd = nil;
        if (words[2]) then
            cmd = COMMANDS[words[2]];
        end

        if (cmd) then
            consoleLog("-------------------------------");
            consoleLog("<b><c=ffffff>Command: " .. words[2] .. "</c></b>");
            consoleLog("-------------------------------");
            if (cmd.description) then
                local s, e = strfind(cmd.description, '\n');
                if (s and e) then
                    consoleMultiple(strsplit(cmd.description, '\n', 1));
                else
                    consoleLog(cmd.description);
                end
            end
            if (cmd.syntax) then
                consoleLog("<c=ffffff>SYNTAX</c>:  " .. cmd.syntax);
            end
            if (cmd.example) then
                consoleLog("<c=ffffff>EXAMPLE</c>: " .. cmd.example);
            end
            if (cmd.params) then
                consoleLog("Params:");
                for param, conf in (cmd.params or {}) do
                    consoleLog("\t" .. param .. ": [ " .. strimplode(conf.names, ", ") .. " ]");
                end
            end
            if (cmd.flags) then
                consoleLog("Flags:");
                for _, flag in (cmd.flags or {}) do
                    consoleLog("\t" .. flag);
                end
            end
            consoleLog('-------------------------------');
        else
            consoleLog("HWRM Ingame Console mod made by <c=11aaff> Fear (Novaras)</c>. Please see the README linked in the Steam workshop!");
            consoleLog("Use <b>'help [command]'</b> for details on a command, i.e: 'help spawn'");
            consoleLog("Use <b>'commands'</b> for a list of commands.");
            consoleLog("Use <b>'help help'</b> for details on how to read help [command] info.");
        end
    end
};
