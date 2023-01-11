COMMANDS = COMMANDS or {};

COMMANDS.kill = COMMANDS.kill or {
    description = "Kills a player.",
    syntax = "kill [player-id]",
    example = "kill 1",
    fn = function (_, words)
        local player_index = tonumber(words[2]);
        if (player_index) then
            Player_Kill(player_index);
        else
            consoleLog("kill: invalid argument 1 'player id': 'kill {id}', i.e 'kill 1'");
        end
    end,
};
