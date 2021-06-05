# `driver.lua`

The _'Driver'_ is a concept which allows all ships to call the same three customcode functions: `create`, `update`, and `destroy`.

Furthermore, it keeps records of all ships which hook to these functions in a global [MemGroup](MemGroup.md) (named `GLOBAL_REGISTER`), which allows it to assign 'common' attributes to these ships, such as `playerIndex` and anything else which is desirable to have in all contexts.

## How we can still run custom code:

Since `driver.lua` is providing the hook functions (`create` etc.), how do we manage to run our own custom code on these hooks?

To do this, we define objects for a ships _'type'_, which is just the name of the initial `CustomGroup` passed into `create`.

**These definitions must be contained in `scripts/custom_code/<race>/*.lua`**, e.g: `scripts/custom_code/hgn/foo.lua`.

> Note: if you want to add scripts for custom races, you need to update `custom_code.lua` to scan that race's directory.

## Example Usage

Let's achieve the same result as exampled in [MemGroup](MemGroup.md): a torpedo frigate who's HP we can track between calls.

```lua
-- hgn_torpedofrigate.ship:

-- ...other stuff...
addCustomCode(
	NewShipType,
	"data:scripts/driver.lua", -- important!
	"",
	"create", -- essential to use these functions provided
	"update",
	"destroy",
	"Hgn_TorpedoFrigate",
	1
);
-- ... other stuff ...
```

```lua
-- scripts/custom_code/hgn/torps.lua:

-- notice we can skip defining 'create' and 'destroy' since we have no custom behavior we want to add to those hooks
-- also, these hooks will have the ship found via its shipID as the first and only argument
CUSTOM_CODE["hgn_torpedofrigate"] = {
	-- attribs: a function or table
	-- if a function, takes the following params, and must return a table
	attribs = function(CustomGroup, playerIndex, shipID)
		return {
			c_group = CustomGroup,
			hp = nil -- not necessary to define here (nil), but good for self-documenting
		};
	end,
	update = function (this_ship)
		local current_hp = SobGroup_CurrentHealthTotal(this_ship.c_group);

		-- we can't get the HP on the creation hook, since CustomGroup is empty there,
		-- so we ensure hp is set by a previous update run before using it
		if (this_ship.hp) then
			print("hp last time: " .. this_ship.hp);
			print("hp this time: " .. current_hp);
			print("change: " .. (current_hp - this_ship.hp));
		end

		this_ship.hp = current_hp; -- update hp for next run

	end,
};
```