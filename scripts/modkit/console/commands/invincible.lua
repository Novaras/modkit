COMMANDS = COMMANDS or {};

COMMANDS.invincible = COMMANDS.invincible or {
    description = "Makes a target selection invincible.",
    syntax = "invincible ?(type=[ship-type] or family=[attack-family]) ?player=[player-id] ?set=[0/1]",
    example = "invincible player=0",
    params = {
        type = PARAMS.str({ 't', 'type' }),
        family = PARAMS.str({ 'f', 'family' }),
        player = PARAMS.intToPlayer(),
        set = PARAMS.int({ 'v', 'value', 'set' }, 1)
    },
    fn = function (param_vals, _, _, line)
        local set_value = param_vals.set;
        local str = "foreach " .. strsub(line, strlen("invincible") + 1, strlen(line)) .. " lua=SobGroup_SetInvulnerability($g, " .. set_value .. ");";
        consoleLog("parsed to: " .. str);
        parseCommand(str);
    end,
};
