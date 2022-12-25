COMMANDS = COMMANDS or {};

COMMANDS.gamespeed = COMMANDS.gamespeed or {
    description = "Sets the game speed to a multiplier of the default speed. Accepts any positive number.",
    syntax = "gamespeed [speed-multiplier]",
    example = "gamespeed 0.5",
    fn = function (_, words)
        local stateHnd = makeStateHandle();
        local speed = words[2];

        if (speed) then
            speed = tonumber(speed);
            if (speed > 0) then
                local existing_stack = stateHnd().ui_scope_exec;
                stateHnd({
                    ui_scope_exec = modkit.table.push(existing_stack or {}, 'SetTurboSpeed(1); SetTurboSpeed(' .. speed .. ")");
                });
            else
                consoleLog("gamespeed: must be a positive float i.e 'gamespeed 12'");
            end
        else
            consoleLog("gamespeed: missing required argument 1 'speed': gamespeed {speed} i.e: 'gamespeed 8'");
        end
    end,
};
