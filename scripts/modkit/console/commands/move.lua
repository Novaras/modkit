COMMANDS = COMMANDS or {};

COMMANDS.move = COMMANDS.move or {
    description = "Causes ships to move to a position. If '--force' is set, teleports the units to the positon.",
    syntax = "move ?(type=[ship-type] or family=[attack-family]) player=[player-id] position=[x y z] ?--force",
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
    fn = function (param_vals, _, flags, line)
        ---@type Position?
        local pos = param_vals.position;

        if (not pos) then
            consoleError("move: missing required param 'pos=[x y z]', i.e: 'pos=10 1000 -500'");
        end

        local vec_str = "{ " .. strimplode(pos, ", ") .. " }";
        if (flags.force) then
            local lua_str = " lua=SobGroup_SetPosition($g, " .. vec_str .. ");";
            local cmd_str = "foreach " .. strsub(line, strlen("move") + 1, strlen(line)) .. lua_str;
            consoleLog("parsed to: " .. cmd_str);
            parseCommand(cmd_str);
        else
            local players = {};
            if (param_vals.player) then
                players = { [player.id] = player };
            else
                players = GLOBAL_PLAYERS:all();
            end
            for id, _ in players do
                if (id ~= -1) then
                    local lua_str = " lua=SobGroup_MoveToPoint(" .. id .. ", $g, " .. vec_str .. ");";
                    local cmd_str = "foreach " .. strsub(line, strlen("move") + 1, strlen(line)) .. lua_str;
                    consoleLog("parsed to: " .. cmd_str);
                    parseCommand(cmd_str);
                end
            end
        end
    end,
};
