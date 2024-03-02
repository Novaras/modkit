COMMANDS = COMMANDS or {};

COMMANDS.fight = COMMANDS.fight or {
    description = "Causes the given players to attack eachother.",
    syntax = "fight [player-id] [player-id]",
    example = "fight 0 1",
    fn = function (_, words)
        local player_a = words[2];
        local player_b = words[3];

        if (not (player_a and player_b)) then
            consoleLog("fight: requires two player ids, i.e 'fight 0 1'");
            return nil;
        end

        parseCommand('attack attacker=' .. player_a .. " target=" .. player_b);
        parseCommand('attack attacker=' .. player_b .. " target=" .. player_a);
    end,
};
