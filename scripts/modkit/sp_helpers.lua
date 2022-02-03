-- no-dependency helper functions for mission scripts and levels

if (H_SP_HELPERS == nil) then
	SHIP_NEXT_ID = 0;

	--- In the context of a .level script, creates squads & groups for the ships and positions them on the map etc.
	--- In the context of a .lua script, creates `Ship` definitions from this information instead, stored in `GLOBAL_MISSION_SHIPS`
	---@param type string
	---@param player integer
	---@param position Vec3
	---@param rotation Vec3
	---@param in_hyperspace '0'|'1'
	---@param id_override string
	function RegisterShip(type, player, position, rotation, in_hyperspace, id_override, group_name_override)
		local group_name = group_name_override or ("_registergroup_" .. SHIP_NEXT_ID);

		player = player or 0;
		position = position or { 0, 0, 0 };
		rotation = rotation or { 0, 0, 0 };
		in_hyperspace = in_hyperspace or 0;

		if (id_override == nil) then
			id_override = SHIP_NEXT_ID;
		end
		SHIP_NEXT_ID = SHIP_NEXT_ID + 1;

		if (addSquadron ~= nil and createSOBGroup ~= nil) then -- defined only during .level load by engine
			print("LEVEL CONTEXT");
			local squad_name = group_name .. "_squad";
			addSquadron(squad_name, type, position,	player, rotation, 1, in_hyperspace);
			createSOBGroup(group_name); -- group is accessible in the script
			addToSOBGroup(squad_name, group_name); -- this fn assigns the squad to the sob
		else
			print("GAMETIME CONTEXT");
			if (GLOBAL_MISSION_SHIPS == nil) then
				dofilepath("data:scripts/modkit.lua");

				---@class GLOBAL_MISSION_SHIPS : MemGroup
				---@field _entities Ship[]
				---@field all fun(): Ship[]
				---@field get fun(id: string): Ship
				GLOBAL_MISSION_SHIPS = modkit.MemGroup.Create("mg-global-mission-ships");
			end
			GLOBAL_MISSION_SHIPS:set(id_override, modkit.compose:instantiate(group_name, player, id_override, type));
		end
	end

	--- Called in the .level to place squads and assign them to groups
	--- Called in the .lua gametime to register Ship objects for these defined ships
	---@param level_path string The full path to the .level of the mission
	function RegisterShips(level_path)
		if (MODKIT_MISSION_SHIPS == nil) then
			dofilepath(level_path);
		end
		for id, ship in MODKIT_MISSION_SHIPS do
			RegisterShip(
				ship.type,
				ship.player,
				ship.position,
				ship.rotation,
				ship.in_hyperspace,
				id,
				ship.group_name_override
			);
		end
	end

	H_SP_HELPERS = 1;
end
