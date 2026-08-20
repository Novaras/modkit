-- no-dependency helper functions for mission scripts and levels

---@class MissionShip
---@field type string
---@field player? integer
---@field position? Arr3
---@field rotation? Arr3
---@field in_hyperspace? 0|1
---@field id_override? string|number
---@field group_name_override? string

---@type MissionShip[]
MODKIT_MISSION_SHIPS = {};

if (H_SP_HELPERS == nil) then
	SHIP_NEXT_ID = 0;

	--- In the context of a .level script, creates squads & groups for the ships and positions them on the map etc.
	--- In the context of a .lua script, creates `Ship` definitions from this information instead, stored in `GLOBAL_MISSION_SHIPS`
	---@param mission_ship MissionShip
	function RegisterShip(mission_ship)
		local group_name = mission_ship.group_name_override or ("_registergroup_" .. SHIP_NEXT_ID);

		local type = mission_ship.type;

		local player = mission_ship.player or 0;
		local position = mission_ship.position or { 0, 0, 0 };
		local rotation = mission_ship.rotation or { 0, 0, 0 };
		local in_hyperspace = mission_ship.in_hyperspace or 0;

		local id_override = mission_ship.id_override or SHIP_NEXT_ID;
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

				---@class GLOBAL_MISSION_SHIPS : MemGroupInst
				GLOBAL_MISSION_SHIPS = modkit.MemGroup.Create("mg-global-mission-ships");
			end
			GLOBAL_MISSION_SHIPS:set(id_override, modkit.compose:instantiate(group_name, player, id_override, type));
		end
	end

	--- Called in the .level to place squads and assign them to groups
	--- Called in the .lua gametime to register Ship objects for these defined ships
	---@param mission_ships_path string The path to the file defining `MODKIT_MISSION_SHIPS`
	function RegisterShips(mission_ships_path)
		dofilepath("data:scripts/modkit/table_util.lua");

		if (modkit.table.length(MODKIT_MISSION_SHIPS) == 0) then
			dofilepath(mission_ships_path);

			-- modkit.table.printTbl(MODKIT_MISSION_SHIPS, "mission ships");
		end

		MODKIT_MISSION_SHIPS = MODKIT_MISSION_SHIPS or {};

		for id, ship in MODKIT_MISSION_SHIPS do
			if (not ship.count) then
				ship.count = 1;
			end
			for i = 1, ship.count do
				RegisterShip(ship);
			end
		end
	end

	H_SP_HELPERS = 1;
end
