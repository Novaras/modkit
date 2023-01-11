COMMANDS = COMMANDS or {};

COMMANDS.destroy = COMMANDS.destroy or {
    description = "Destroys ships.",
    syntax = "destroy (type=[ship-type] or family=[attack-family]) player=[player-id]",
    example = "destroy type=vgr_resourcecollector player=1",
    params = {
        type = PARAMS.str({ 't', 'type' }),
        family = PARAMS.str({ 'f', 'family' }),
        player = PARAMS.intToPlayer()
    },
    fn = function (param_vals)
        ---@type Ship[]
        local src = shipsFromParamValues(param_vals);

        for _, ship in src do
            ship:die();
        end
    end,
};
