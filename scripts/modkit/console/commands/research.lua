COMMANDS = COMMANDS or {};

COMMANDS.research = COMMANDS.research or {
    description = [[Grants, starts, or cancels research for a player. If '--recurse' is set with 'grant', also grants all the
required research for this item.

Valid<b><c=ffffff> verb</c></b> arguments are: grant, all, start, cancel, has, list. By default, the verb is<b> grant</b>.]],
    syntax = "research ?[verb] ?player=[player-id] name=[research-name] ?--recurse",
    example = "research grant name=ioncannons -r",
    params = {
        player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
        research_name = modkit.table:merge(
            PARAMS.str({ 'r', 'research', 't', 'type', 'name' })
        )
    },
    flags = {
        'r',
        'recurse'
    },
    fn = function (param_vals, words, flags)
        ---@type Player
        local player = param_vals.player;
        ---@type string?
        local res_name = param_vals.research_name;

        local recurse = flags.r or flags.recurse;

        local verb = words[2] or 'grant';

        if (not player:race()) then
            consoleError("No race was resolvable for current race (id: " .. Player_GetRace(player.id) .. "), see `races.lua`");
            return nil;
        end

        if (verb == 'list') then
            local src = modkit.research:getRaceItems(player:race()) or {};
            -- modkit.table.printTbl(src, "SRC");

            local names = modkit.table.map(src, function (item)
                if (%player:hasResearch(item)) then
                    return '<c=11ff66>' .. item.name .. '</c>';
                end
                return item.name;
            end);

            consoleLogRows(names, 3);
            return nil;
        elseif (verb == 'all') then
            player:grantAllResearch();
            return nil;
        end

        if (res_name) then
            ---@type ResearchItem
            local research_item = modkit.research:find(res_name, player:race());

            if (research_item) then
                if (verb == 'has') then
                    local phrase = "<cff0000> doesn't have</c>";
                    if (player:hasResearch(research_item)) then
                        phrase = '<c=00ff00> has</c>';
                    end
                    consoleLog("Player " .. player.id .. "<b>" .. phrase .. " </b>tech " .. research_item.name);
                    return nil;
                end

                if (player:hasResearchCapableShip() == nil) then
                    consoleError("research: no research capable ship found");
                    return nil;
                end

                if (verb == 'grant') then
                    -- consoleLog("GRANT " .. research_item.name);
                    -- consoleLog("recurse?: " .. (recurse or 'no'));
                    player:grantResearchOption(research_item, recurse);
                elseif (verb == 'start') then
                    player:doResearch(research_item);
                elseif (verb == 'cancel') then
                    player:cancelResearch(research_item);
                else
                    consoleError("research: missing required argument 1 'verb' {grant|start|cancel|has}, i.e 'research start t=corvettedrive");
                end
            else
                consoleError("research: cant resolve research by the name '" .. res_name .. "'");
            end
        else
            consoleError("research: missing required param 'type', i.e research grant t=corvettedrive (see 'help research')");
        end
    end
};
