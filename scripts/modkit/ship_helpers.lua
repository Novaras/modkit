if (modkit == nil) then
	modkit = {};
end

if (modkit.shipGroup == nil) then
	---@class ShipCollectionExt : ShipCollection
	local lib = modkit.table.clone(GLOBAL_SHIPS);

	--- Returns the avg position of `ships` or `GLOBAL_SHIPS`.
	---
	---@param ships? Ship[]
	---@return Position
	function lib:avgPosition(ships)
		-- we could use the ship:position, but the game provides group position averaging already so we'll just use that
		-- print(self._entities);
		-- print(modkit.table.length(self._entities));
		-- print("so..");
		local group = SobGroup_FromShips(ships or self._entities, DEFAULT_SOBGROUP);
		return Vec3(SobGroup_GetPosition(group));
	end

	--- Finds a ship and returns it.
	---
	--- The argument may be a `Ship` or a filter predicate. If given a `Ship`, matches by `id`.
	---
	---@param predicate_or_ship Ship|ShipFilterPredicate
	---@return Ship?
	function lib:find(predicate_or_ship)
		if (predicate_or_ship == nil) then
			return nil;
		end

		local predicate = NOOP;
		if (type(predicate_or_ship) == "table") then
			predicate = function (other)
				return other.id == ship.id;
			end
		else
			---@cast predicate_or_ship ShipFilterPredicate
			predicate = predicate_or_ship;
		end
		return modkit.table.findVal(self._entities, predicate);
	end

	function lib:findType(type)
		return self:find(function (ship)
			return ship.type_group == %type;
		end);
	end

	function lib:fitlerType(type)
		return self:filter(function (ship)
			return ship.type_group == %type;
		end)
	end

	local _ships = function (ships)
		ships = ships or GLOBAL_SHIPS._entities;
		return %lib:shallowCopy(ships);
	end;

	---@type fun(ships?: Ship[]): ShipCollectionExt
	modkit.ships = _ships;
end