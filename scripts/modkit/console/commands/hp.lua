COMMANDS = COMMANDS or {};

COMMANDS.hp = COMMANDS.hp or {
    description = "Sets the HP (as a fraction [0..1]) for ships.",
    syntax = "hp [hp-fraction] (type=[ship-type] or family=[attack-family]) player=[player-id]",
    example = "hp 0.9 type=kus_mothership p=1",
    fn = function (_, words, _, line)
        if (words[2]) then
            local str = "foreach " .. strsub(line, 3, strlen(line)) .. " lua=SobGroup_SetHealth($g, " .. words[2] .. ");";
            -- consoleLog("parsed to: " .. str);
            parseCommand(str);
        end
    end,
};
