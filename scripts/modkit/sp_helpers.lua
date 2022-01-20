-- no-dependency helper functions for mission scripts and levels

if (H_SP_HELPERS == nil) then
	SHIP_NEXT_ID = 0;

	function RegisterShip(type, player, position, rotation, in_hyperspace, id_override)
		local group_name = "_registergroup_" .. SHIP_NEXT_ID;

		if (id_override == nil) then
			id_override = SHIP_NEXT_ID;
			SHIP_NEXT_ID = SHIP_NEXT_ID + 1;
		end

		if (addSquadron ~= nil or createSobGroup ~= nil) then -- defined only during .level load by engine
			local squad_name = "_registergroup_" .. SHIP_NEXT_ID;
			addSquadron(squad_name, type,	position,	player, rotation, 1, in_hyperspace);
			createSOBGroup(group_name); -- group is accessible in the script
			addToSOBGroup(squad_name, group_name); -- this fn assigns the squad to the sob
		else
			if (GLOBAL_SHIPS == nil) then
				dofilepath("data:scripts/modkit.lua");
			end
			GLOBAL_SHIPS:set(id_override, modkit.compose:instantiate(group_name, player, id_override, type));
		end
	end

	function RegisterShips(level_path)
		if (level_path) then
			dofilepath(level_path);
		end
		for id, ship in MODKIT_MISSION_SHIPS do
			RegisterShip(
				ship.type,
				ship.player,
				ship.position,
				ship.rotation,
				ship.in_hyperspace,
				id
			);
		end
	end

	H_SP_HELPERS = 1;
end
