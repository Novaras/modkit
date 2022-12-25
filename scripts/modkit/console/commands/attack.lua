COMMANDS = COMMANDS or {};

COMMANDS.attack = COMMANDS.attack or {
    description = "Causes all of one player's ships to attack all of another player's ships.",
    syntax = "attack ?attacker=[player-id] target=[player-id]",
    example = "attack atk=0 target=1",
    params = {
        attacker = PARAMS.intToPlayer({ 'a', 'atk', 'attacker' }, 0),
        target = PARAMS.intToPlayer({ 't', 'trg', 'target' }),
    },
    fn = function (param_vals)
        ---@type Player
        local attacker = param_vals.attacker;
        ---@type Player
        local target = param_vals.target;

        if (target) then
            consoleLog(attacker.id .. " attacking player " .. target.id);
            attacker:attack(target);
        else
            consoleLog("attack: missing required param 'target={player id}' i.e 'target=1'");
        end
    end
};
