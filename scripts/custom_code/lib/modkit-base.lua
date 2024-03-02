dofilepath("data:scripts/modkit/vec3.lua");
dofilepath("data:scripts/modkit/player.lua"); -- stuff for players like GLOBAL_PLAYERS
dofilepath("data:scripts/modkit/research.lua"); -- research...

---@alias Position Vec3

---@class Attribs
---@field id integer
---@field type_group string
---@field ship_type string
---@field own_group string
---@field player Player
---@field _tick integer
---@field created_at number

---@class Base : Attribs
modkit_base = {
	--- Attribs callback allows modders to define data on ships which depends on their initialisation values.
	---@param g string
	---@param p integer
	---@param s integer
	---@return Attribs
	attribs = function (g, p, s, t)
		return {
			type_group = t or g,
			ship_type = t or g,
			own_group = SobGroup_Clone(g, g .. "-" .. s),
			player = GLOBAL_PLAYERS:get(p),
			_tick = 0,
			created_at = Universe_GameTime()
		};
	end
};

--- Gets and/or sets the tick of this ship (how many `update` calls have been performed since creation).
---
---@param set? integer
---@return integer
function modkit_base:tick(set)
	if (set and type(set) == "number") then
		self._tick = set;
	end
	return self._tick;
end

--- Returns the count of the ships in this ship's `own_group`. This may be more than one, i.e in the case of HW2 strike which
-- are built in _batches_.
---
---@return integer
function modkit_base:count()
	return SobGroup_Count(self.own_group);
end

--- Returns the build batch size of this ship type. `hgn_interceptor` returns `5`, for example.
---
---@return integer
function modkit_base:batchSize()
	return SobGroup_GetStaticF(self.ship_type, "buildBatch");
end

modkit.compose:addBaseProto(modkit_base);

print("go base!");