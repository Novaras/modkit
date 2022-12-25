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

        modkit.table.printTbl(flags, "flags");
        local recurse = flags.r or flags.recurse;

        local verb = words[2] or 'grant';

        if (verb == 'list') then
            ---@type Ship
            local ship = modkit.table.first(player:ships());
            print("prefix: " .. ship:racePrefix());
            local src = modkit.research:getRaceItems(ship:raceName());
            modkit.table.printTbl(src, "SRC");

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
            if (player:hasResearchCapableShip() == nil) then
                consoleError("research: no research capable ship found");
                return nil;
            end

            modkit.table.printTbl(modkit.table.firstValue(player:ships()):racePrefix(), "OH");
            ---@type ResearchItem
            local research_item = modkit.research:find(res_name, modkit.table.firstValue(player:ships()):racePrefix());

            if (research_item) then
                if (verb == 'grant') then
                    -- consoleLog("GRANT " .. research_item.name);
                    -- consoleLog("recurse?: " .. (recurse or 'no'));
                    player:grantResearchOption(research_item, recurse);
                elseif (verb == 'start') then
                    player:doResearch(research_item);
                elseif (verb == 'cancel') then
                    player:cancelResearch(research_item);
                elseif (verb == 'has') then
                    local phrase = "doesn't have";
                    if (player:hasResearch(research_item)) then
                        phrase = 'has';
                    end
                    consoleLog("Player " .. player.id .. " " .. phrase .. " tech " .. research_item.name);
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
