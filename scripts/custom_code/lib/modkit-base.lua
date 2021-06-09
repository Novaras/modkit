
modkit_base = {
	attribs = function (g, p, s)
		return {
			id = s,
			type_group = g,
			own_group = SobGroup_Clone(g, g .. "-" .. s),
			player_index = p,
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