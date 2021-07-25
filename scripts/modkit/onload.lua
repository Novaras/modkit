-- load hooks, to match in .ship files
-- the default load hook, 'load', does nothing
-- there is no other way for a load hook to know which ship type called it, since `addCustomCode` only provides this hook with a player index

if (modkit.player == nil) then
	dofilepath("data:scripts/driver.lua");
end

function createPlayer(index)
	return GLOBAL_PLAYERS:set(index,
		modkit.table:merge(
			modkit_player_proto,
			{
				id = index
			}
		)
	);
end

-- define your own load hooks here:

-- in `kus_mothership.ship`: `addCustomCode(NewShipType, "data:scripts/driver.lua", "kus_mothership_load", "create", "update", "destroy", "kus_mothership", 1);`

-- function kus_mothership_load(player_index)
-- 	print("load from kus ms");
-- 	print("pidx: " .. player_index);
-- end
