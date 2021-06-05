-- global_attribs.lua
-- Here, we define the prototype which ALL ships assigning to the global registry will extend.
-- This is extremely useful for making certain properties and functions easy to define for all ships.
-- Edit this file!

if (H_GLOBAL_ATTRIBS == nil) then
	local proto = {
		attribs = function (type_group, player_index, id)
			return {
				-- These keys are essential for the driver code to work - beyond that, you can do anything.
				type_group = type_group,
				own_group = SobGroup_Fresh(type_group, type_group .. "-" .. id),
				player_index = player_index
				-- your keys here or below...
			};
		end
	};

	-- ==========================================================
	-- |   DEFINE YOUR OWN FUNCTIONS/ETC. AS YOU SEE FIT HERE   |
	-- ==========================================================

	-- here's an example, a function called 'hp' which gets and sets the ships HP fraction

	-- notice the ':' syntax means the function scope has a new variable `self`, which is the ship object itself
	-- If we used 'function proto.hp' instead, we'd need to pass our own ship as a param:
	-- 	my_ship.hp(my_ship, 0.5);
	-- by using ':', the call site is much nicer:
	-- 	my_ship:hp(0.5);

	--- Gets (& optionally sets) the hp of the ship.
	-- @param hp_fraction [number | nil] The new hp fraction (range 0-1)
	-- @return [number] The current/new hp fraction
	function proto:hp(hp_fraction)
		-- remember: 'attempt to index local `self' (a nil value)' means you called the function like this:
		-- 	my_ship.hp(<value>);
		-- but you should have called it like this:
		-- 	my_ship:hp(<value>);
		if (hp_fraction) then
			SobGroup_SetHealth(self.own_group, hp_fraction); -- hp_fraction is a number between 0 and 1 (a percentage)
		end
		return SobGroup_GetHealth(self.own_group);
	end

	GLOBAL_PROTO_KEY = "_global";
	CUSTOM_CODE[GLOBAL_PROTO_KEY] = proto;

	H_GLOBAL_ATTRIBS = 1;
	print("global_attribs init");
end