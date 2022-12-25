COMMANDS = COMMANDS or {};

COMMANDS.spawn = COMMANDS.spawn or {
    description = "Spawns ships for a player. Also see the 'ship_types' command.",
    syntax = "spawn [ship-type] ?player=[player-index] ?count=[number-to-spawn] ?position=[x y z]",
    example = "spawn kpr_sajuuk p=0 c=5 pos=1000 -100 15000",
    params = {
        player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
        count = PARAMS.int({ 'c', 'count', 'n' }, 1),
        position = PARAMS.strToVec3({ 'pos', 'position' }, "0 0 0")
    },
    fn = function (param_vals, words)
        local ship_type = words[2];
        if (ship_type) then
            ---@type Player
            local player = param_vals.player;
            ---@type integer
            local spawn_count = param_vals.count;
            ---@type Position
            local pos = param_vals.position;

            local makeVol = makeSpawnVolGenerator(1000 + (20 * min(spawn_count, 100)));

            consoleLog("\tspawning " .. spawn_count .. "x ".. ship_type .. " for player " .. player.id);
            local spawn_group = SobGroup_Fresh();
            for _ = 0, spawn_count - 1 do
                SobGroup_SpawnNewShipInSobGroup(
                    player.id,
                    ship_type,
                    '__console_spawn',
                    spawn_group,
                    makeVol(pos)
                );
            end

            local spawned_count = SobGroup_Count(spawn_group);

            if (spawned_count == 0) then
                consoleError("unable to spawn ship type<b> '" .. ship_type .. "'</b>");
            elseif (spawned_count < spawn_count) then
                consoleError("only spawned " .. spawned_count .. " of " .. spawn_count .. " ships");
            end
        else
            consoleLog("spawn: missing required argument 1 'ship_type': 'spawn {ship_type}', i.e 'spawn hgn_interceptor'")
        end
    end,
};
