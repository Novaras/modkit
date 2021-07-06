dofilepath("data:scripts/modkit/player.lua"); -- stuff for players like GLOBAL_PLAYERS
dofilepath("data:scripts/modkit/research.lua"); -- research...

modkit_base = {
	attribs = function (g, p, s)
		local player = function ()
			return
				GLOBAL_PLAYERS:get(%p) or
				GLOBAL_PLAYERS:set(%p,
					modkit.table:merge(
						modkit_player_proto,
						{
							id = %p
						}
					)
				);
		end;
		return {
			type_group = g,
			own_group = SobGroup_Clone(g, g .. "-" .. s),
			player = player,
			_tick = 0,
			created_at = Universe_GameTime()
		};
	end
};

function modkit_base:tick(set)
	if (set and type(set) == "number") then
		self._tick = set;
	end
	return self._tick;
end

modkit.compose:addBaseProto(modkit_base);

print("go base!");