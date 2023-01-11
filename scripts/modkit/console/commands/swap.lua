COMMANDS = COMMANDS or {};

COMMANDS.swap = COMMANDS.swap or {
    description = "Swaps all the ships of two given players.",
    syntax = "swap [player-id] [player-id]",
    example = "swap 0 1",
    fn = function (_, words)
        -- consoleLog("swap?");

        if (words[2] == nil or words[3] == nil) then
            consoleLog("swap: missing one or both required arguments 'swap {player-1} {player-2}' i.e 'swap 0 1'");
            return nil;
        end

        ---@type Player[]
        local players = modkit.table.map({ words[2], words[3] }, function (id_str)
            return GLOBAL_PLAYERS:get(tonumber(id_str));
        end);

        local old_groups = modkit.table.map(players, function (player)
            return SobGroup_Clone(player:shipsGroup());
        end);

        local temp_group = SobGroup_Fresh();
        for idx = 1, modkit.table.length(players) do
            local p = players[idx];
            local g = old_groups[idx];
            local n = modkit.table.length(players) + 1;
            SobGroup_SpawnNewShipInSobGroup(p.id, "kpr_destroyer", "", temp_group, Volume_Fresh());

            local other_idx = max(1, mod(idx + 1, n));
            -- print("get at " .. other_idx);
            -- print("g: " .. g);
            -- print("g.c: " .. SobGroup_Count(g));
            -- print("from " .. p.id .. " to " .. players[other_idx].id);
            SobGroup_SwitchOwner(g, players[other_idx].id);
        end

        SobGroup_Despawn(temp_group);
        SobGroup_SetHealth(temp_group, 0);
    end
};
