-- driver.lua
-- Ships hook here instead of their own nested scripts
-- Do not edit unless you know what you're doing.

function NOOP() end

if (H_DRIVER == nil) then

	if (modkit == nil) then
		dofilepath("data:scripts/modkit.lua");
	end

	GLOBAL_REGISTER = modkit.MemGroup.Create("mg-global");

	--- Registers the incoming sobgroup, player index, and ship id into a Ship table within the global registry.
	-- The Ship is a rich representation of the actual ingame ship as a proper workable table.
	function register(type_group, player_index, ship_id)
		type_group = strlower(type_group); -- immediately make this lowercase
		local caller = GLOBAL_REGISTER:get(ship_id);
		if (caller ~= nil) then -- fast return if already exists
			return caller;
		end
		-- Create a new Ship. The attributes and methods this ship has are a combination of any global attributes in
		-- `custom_code/global_attribs.lua`, combined with the custom attributes and methods you defined for this _type_ of ship,
		-- somewhere in `custom_code/<race>/<custom-ship>.lua`.
		local caller = GLOBAL_REGISTER:set(
			ship_id,
			modkit.compose:instantiate(type_group, player, ship_id)
		);
		-- ensure non-nil when calling these:
		for i, v in {
			"load",
			"create",
			"update",
			"destroy",
			"start",
			"go",
			"finish"
		} do
			if (caller[v] == nil) then
				caller[v] = NOOP;
			end
		end

		return caller;
	end

	-- === load, create, update, destroy ===

	function load(load)
		return NOOP;
	end
	
	function create(g, p, i)
		local caller = register(g, p, i);

		caller:create(); -- run the caller's custom create hook

		return caller;
	end

	function update(g, p, i)
		local caller = GLOBAL_REGISTER:get(i);
		if (caller == nil) then -- can happen when loading a save etc.
			caller = create(g, p, i);
		end

		SobGroup_SobGroupAdd(caller.own_group, g); -- ensure own group is filled on update
		caller:tick(caller:tick() + 1);

		caller:update(); -- run the caller's custom update hook

		-- local past_self = {};
		-- for k, v in caller do
		-- 	if (k ~= 'past_self') then -- very important to prevent memory pileup!
		-- 		if type(v) == 'function' then
		-- 			past_self[k] = caller[k](caller); -- collapse getters into values
		-- 		else
		-- 			past_self[k] = v;
		-- 		end
		-- 	end
		-- end
		-- caller.past_self = past_self; -- for next run comparisons

		return caller;
	end

	function destroy(g, p, i)
		local caller = GLOBAL_REGISTER:get(i);

		caller:destroy(); -- run the caller's custom destroy hook

		GLOBAL_REGISTER:delete(i);
		-- nil return
	end

	-- === start, go, finish ===

	function start(g, p, i)
		local caller = GLOBAL_REGISTER:get(i);

		caller:start();

		return caller;
	end

	function go(g, p, i)
		local caller = GLOBAL_REGISTER:get(i);

		caller:go();

		return caller;
	end

	function finish(g, p, i)
		local caller = GLOBAL_REGISTER:get(i);

		caller:finish();

		return caller;
	end

	H_DRIVER = 1;
	print("driver init");
end
