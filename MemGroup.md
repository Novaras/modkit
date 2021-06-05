# MemGroup

MemGroup is a state management utility.

It is designed to allow a modder to maintain state about ships through successive script calls, and even between different scripts.

## Example Usage

> **NOTE:** This example shows direct usage of MemGroup, which is a non-standard, albiet highly appropriate usage for simple/small scripts. See [Driver.md](Driver.md) for a more turbocharged system.

I will demonstrate a very simple use-case in the following example.

**Let's say we want to measure the change in the HP of a torpedo frigate from one call to `update` to the next, and so on.**

```lua
-- hgn_torpedofrigate.lua:

dofilepath("data:scripts/modkit.lua"); -- ensure loaded

my_memgroup = modkit.memgroup.Create("my-memgroup");

function create(CustomGroup, playerIndex, shipID)
	my_memgroup:set(shipID); -- here, the ship is stored in the memgroup by shipID
end

function update(CustomGroup, playerIndex, shipID)
	local this_ship = my_memgroup:get(shipID); -- this will be the same ship
end

function destroy(CustomGroup, playerIndex, shipID)
	my_memgroup:delete(shipID); -- remove from memory if destroyed
end
```

Called from a `.ship` file like in this example:

```lua
-- hgn_torpedofrigate.ship:

-- ...other stuff...
addCustomCode(
	NewShipType,
	"data:ship/hgn_torpedofrigate/hgn_torpedofrigate.lua",
	"",
	"create",
	"update",
	"destroy",
	"Hgn_TorpedoFrigate",
	1
);
-- ... other stuff ...
```

This is already working - we are saving a reference to the ship in the MemGroup, and are able to access that specific ship later via its `shipID`.

### Assigning State

Memgroup allows you to attach custom properties to your entities:

```lua
-- 'static' attributes can be set once when creating the group:
my_memgroup = modkit.memgroup.Create("my-memgroup", {
	torp_weapon_range = 4250
});
```

```lua
-- 'instance' attributes can be set once when registering to the group:
function create(CustomGroup, playerIndex, shipID)
	my_memgroup:set(shipID, {
		this_torps_hp = SobGroup_CurrentHealthTotal(CustomGroup)
	});
end
```

You can, of course, add any attribute you like at any time to a ship:

```lua
function update(CustomGroup, playerIndex, shipID)
	local this_ship = my_memgroup:get(shipID);
	-- Attribute 'foo' is found only on ships which run this statement:
	this_ship.custom_attribute = "foo";
end
```

As a rule of thumb, keep instance attributes visible for the lifetime of a ship (set them in `create` instead of `update` etc.). This ensures you wont bump into random `nil` indexing, concatenation, or invokation errors (etc.).

### Finished Product

We can use the patterns above to keep track of our ship's HP like this:

```lua
-- hgn_torpedofrigate.lua:

dofilepath("data:scripts/modkit.lua"); -- ensure loaded

my_memgroup = modkit.memgroup.Create("my-memgroup");

function create(CustomGroup, playerIndex, shipID)
	my_memgroup:set(shipID, {
		c_group = CustomGroup,
		hp = nil -- not necessary to define here (nil), but good for self-documenting
	});
end

-- notice we don't make use of any arguments except shipID
function update(CustomGroup, playerIndex, shipID)
	local this_ship = my_memgroup:get(shipID);
	-- this is the same group assigned in `create` (`c_group`):
	local current_hp = SobGroup_CurrentHealthTotal(this_ship.c_group);

	-- we can't get the HP on the creation hook, since CustomGroup is empty there,
	-- so we ensure hp is set by a previous update run before using it
	if (this_ship.hp) then
		print("hp last time: " .. this_ship.hp);
		print("hp this time: " .. current_hp);
		print("change: " .. (current_hp - this_ship.hp));
	end

	this_ship.hp = current_hp; -- update hp for next run
end

function destroy(CustomGroup, playerIndex, shipID)
	my_memgroup:delete(shipID); -- remove from memory if destroyed
end
```
