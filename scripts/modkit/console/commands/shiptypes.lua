COMMANDS = COMMANDS or {};

COMMANDS.shiptypes = COMMANDS.shiptypes or {
    description = "Lists all ship types, or just those matching a Lua pattern.",
    syntax = "shiptypes ?[pattern]",
    example = "shiptypes vgr_",
    fn = function (_, words)
        local pattern = words[2];

        local src = modkit.ship_types;
        if (pattern) then
            src = modkit.table.filter(src, function (ship_type)
                -- print("type: " .. ship_type);
                -- print("pattern: " .. %pattern);
                -- local s, e = strfind(ship_type, %pattern);
                -- print("s: " .. (s or 'nil') .. ", e: " .. (e or 'nil'));
                return strfind(ship_type, %pattern);
            end);

            -- modkit.table.printTbl(src, "src");
        end

        if (src and modkit.table.length(src) > 0) then
            consoleLogRows(src, 4);
        end
    end
};
