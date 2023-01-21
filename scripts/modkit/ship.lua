
initShips = initShips or function ()
	if (modkit == nil) then modkit = {}; end
	dofilepath("data:scripts/modkit/table_util.lua");
	dofilepath("data:scripts/modkit/memgroup.lua");
		
	---@class ShipCollection : SheduledFilters, MemGroupInst
	---@field _entities Ship[]
	---@field get fun(self: ShipCollection, entity_id: number): Ship
	---@field set fun(self: ShipCollection, entity_id: number, ship: Ship): Ship
	---@field all fun(self: ShipCollection): Ship[]
	---@field find fun(self: ShipCollection, predicate: ShipFilterPredicate): Ship | 'nil'
	---@field filter fun(self: ShipCollection, predicate: ShipFilterPredicate): Ship[]
	GLOBAL_SHIPS = modkit.MemGroup.Create("mg-ships-global");

	--- Returns all ships which are allied with the `caller`.
	---
	---@param caller Ship
	---@param filter_predicate ShipFilterPredicate
	---@return Ship[]
	function GLOBAL_SHIPS:allied(caller, filter_predicate)
		local allied_ships = {};
		for index, ship in self:all() do
			if (ship:alliedWith(caller) and filter_predicate(ship)) then
				allied_ships[index] = ship;
			end
		end
		return allied_ships;
	end

	--- Returns all ships which are not allied with the `caller`.
	---
	---@param caller Ship
	---@param filter_predicate ShipFilterPredicate
	---@return Ship[]
	function GLOBAL_SHIPS:enemies(caller, filter_predicate)
		local enemy_ships = {};
		for index, ship in self:all() do
			if (ship:alliedWith(caller) == nil and filter_predicate(ship)) then
				enemy_ships[index] = ship;
			end
		end
		return enemy_ships;
	end
end
