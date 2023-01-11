COMMANDS = COMMANDS or {};

COMMANDS.foreach = COMMANDS.foreach or {
    description = [[Runs a command or Lua string for a ship selection.
If you pass a lua string with 'lua=', you can include replacement tokens in your code which will be replaced with certain values:
- $f: the value of 'family='
- $t: the value of 'type='
- $g: a sobgroup name containing filtered ships
- $s: a modkit memgroup containing all the universe ships]],
    syntax = "foreach (type=[ship-type] or family=[attack-family]) player=[player-id] (lua=[lua-str] or command=[console-command])",
    example = "foreach type=kus_resourcecollector player=0 lua=SobGroup_SetHealth($g, 0.1)",
    params = {
        lua = {
            names = { "lua" },
            pattern = ".+"
        },
        type = PARAMS.str({ 't', 'type' }),
        family = PARAMS.str({ 'f', 'family' }),
        player = PARAMS.intToPlayer(),
        command = {
            names = { "cmd", "command" },
            pattern = "%w+",
            transform = function (value)
                return COMMANDS[value];
            end
        }
    },
    fn = function (param_vals, _, _, line)
        if (param_vals.lua) then
            ---@type string?
            local lua_str = param_vals.lua;
            ---@type string?
            local type = param_vals.type;
            ---@type string?
            local family = param_vals.family;
            ---@type Player?
            local player = param_vals.player;
            local pid;
            if (player) then
                pid = player.id;
            end

            local src = shipsFromParamValues(param_vals);
            makeStateHandle()({
                foreach_src = modkit.table.map(src, function (ship)
                    return { id = ship.id, type = ship.type_group, player_id = ship.player.id };
                end)
            });

            local parsed = gsub(lua_str, "$t", type or '');
            parsed = gsub(parsed, "$f", family or '');
            parsed = gsub(parsed, "$p", pid or '');
            parsed = gsub(parsed, "$g", "'" .. SobGroup_FromShips(src) .. "'");
            parsed = gsub(parsed, "$s", 'modkit.table.map(makeStateHandle()().foreach_src, function(ship_def) return register(ship_def.type, ship_def.player_id, ship_def.id); end)');

            -- consoleLog("EXEC: " .. parsed);

            parsed = "dofilepath('data:scripts/modkit/scope_state.lua'); " ..
                "dofilepath('data:scripts/modkit/driver.lua'); " ..
                parsed;

            print("foreach >> " .. parsed);
            dostring(parsed);

        elseif (param_vals.command) then
            local cmd = param_vals.command;

            local s = cmd .. strsub(gsub(line, "cmd=%w+", ""), 8, strlen(line));
            print(s);
            parseCommand(s);
        else
            consoleLog("foreach: missing one of either 'lua={lua code}' or 'cmd={console command}'");
        end
    end,
};
