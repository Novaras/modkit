COMMANDS = COMMANDS or {};

COMMANDS.tumble = COMMANDS.tumble or {
    description = "Tumbles specified ships, meaning they are given angular momentum (they spin).",
    syntax = "tumble (type=[ship-type] or family=[attack-family]) ?player=[player-id] amount=[x y z]",
    example = "tumble t=kus_mothership amount=3 0 1",
    params = {
        type = PARAMS.str({ 't', 'type' }),
        family = PARAMS.str({ 'f', 'family' }),
        player = PARAMS.intToPlayer(),
        amount = PARAMS.strToVec3({ 'v', 'val', 'tumble', 'vec' }, "0 0 0"),
    },
    fn = function (param_vals, _, _, line)
        if (not param_vals.amount) then
            consoleError("tumble: missing required param 'amount={x y z}', i.e 'amount=1 0 3");
            return nil;
        end

        local vec_str = "{ " .. strimplode(param_vals.amount, ", ") .. " }";
        local str = "foreach " .. strsub(line, 7, strlen(line)) .. " lua=SobGroup_Tumble($g, " .. vec_str .. ");";
        consoleLog("parsed to: " .. str);
        parseCommand(str);
    end
};
