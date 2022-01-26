-- load hooks, to match in .ship files
-- the default load hook, 'load', does nothing
-- there is no other way for a load hook to know which ship type called it

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

--- ===[ research ships ]===

-- global wrapper actual for hook in ship file
function load_kus_res_ship(player_index)
	if (res_ships_proto == nil) then
		dofilepath("data:scripts/hw1/research-ships.lua");
	end

	res_ships_proto:load("kus_researchship", createPlayer(player_index));
end

-- "
function load_tai_res_ship(player_index)
	if (res_ships_proto == nil) then
		dofilepath("data:scripts/hw1/research-ships.lua");
	end

	res_ships_proto:load("tai_researchship", createPlayer(player_index));
end

--- ===[ end research ships ]===