COMMANDS = COMMANDS or {};

COMMANDS.move = COMMANDS.move or {
    description = "Causes ships to move to a position. If '--force' is set, teleports the units to the positon.",
    syntax = "move (type=[ship-type] or family=[attack-family]) player=[player-id] position=[x y z] ?--force",
    example = "move type=tai_assaultfrigate p=0 pos=0 0 0 --force",
    params = {
        type = PARAMS.str({ 't', 'type' }),
        family = PARAMS.str({ 'f', 'family '}),
        player = PARAMS.intToPlayer(),
        position = PARAMS.strToVec3({ 'pos', 'position' })
    },
    flags = {
        'force'
    },
    fn = function (param_vals, _, flags)
        ---@type Position?
        local pos = param_vals.position;

        -- modkit.table.printTbl(flags, "ye");

        if (pos) then
            ---@type Ship[]
            local src = shipsFromParamValues(param_vals);

            for _, ship in src do
                ship:move(pos); -- clears any parades etc.
                if (flags.force) then
                    ship:position(pos);
                end
            end
        else
            consoleLog("move: missing required param 'pos=[x y z]', i.e: 'pos=10 1000 -500'");
        end
    end,
};
