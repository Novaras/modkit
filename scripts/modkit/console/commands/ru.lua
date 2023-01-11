COMMANDS = COMMANDS or {};

COMMANDS.ru = COMMANDS.ru or {
    description = "Grants (adds) or sets RU for a player.",
    syntax = "ru ?<grant|reduce|set> ?player=[player-id] amount=[ru-amount]",
    example = "ru set p=0 amount=12345678",
    params = {
        player = PARAMS.intToPlayer({ 'p', 'player' }, 0),
        amount = PARAMS.int({ 'n', 'v', 'val', 'value' })
    },
    fn = function (param_vals, words)
        local verb = words[2] or 'grant';
        ---@type Player
        local player = param_vals.player;
        local amount = param_vals.amount;

        if (amount == nil) then
            consoleLog("ru: missing require param 'val={amount}' i.e 'value=1000'");
        else
            if (verb == 'grant') then
                player:RU(player:RU() + amount);
            elseif (verb == 'set') then
                player:RU(amount);
            elseif (verb == 'reduce') then
                player:RU(max(0, player:RU() - amount));
            else
                consoleLog("ru: invalid argument 1 'verb': 'ru {grant|set}', i.e 'ru grant val=1000 p=0'");
            end
        end
    end,
};
