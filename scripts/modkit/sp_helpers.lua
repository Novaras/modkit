-- no-dependency helper functions for mission scripts and levels

if (H_SP_HELPERS == nil) then
	SHIP_NEXT_ID = 0;

	function syncGlobalShips()
		if (GLOBAL_SHIPS == nil) then
			dofilepath("data:scripts/modkit.lua");
			dofilepath("data:scripts/driver.lua");
		end

		local SGS = makeStateHandle()().GLOBAL_SHIPS or {};

		for id, own_group in SGS do
			local current = GLOBAL_SHIPS:get(id);
			if (current == nil or current.own_group ~= own_group) then
				GLOBAL_SHIPS:delete(id);
				local pid = SobGroup_GetPlayerOwner(own_group);
				GLOBAL_SHIPS:set(
					id,
					modkit.compose:instantiate(strsplit(own_group, "-", 1)[1], pid, id)
				);
			end
		end
	end

	function initGlobalMissionShips()
		if (GLOBAL_MISSION_SHIPS == nil) then
			dofilepath("data:scripts/modkit.lua");
			initPlayers();

			---@class GLOBAL_MISSION_SHIPS : MemGroupInst
			---@field _entities Ship[]
			---@field all fun(): Ship[]
			---@field get fun(id: string): Ship
			GLOBAL_MISSION_SHIPS = modkit.MemGroup.Create("mg-global-mission-ships");
		end
	end

	--- In the context of a .level script, creates squads & groups for the ships and positions them on the map etc.
	--- In the context of a .lua script, creates `Ship` definitions from this information instead, stored in `GLOBAL_MISSION_SHIPS`
	---@param type string
	---@param player? integer
	---@param position? Vec3
	---@param rotation? Vec3
	---@param in_hyperspace? 0|1
	---@param id? integer
	---@param group_name? string
	function registerShip(type, player, position, rotation, in_hyperspace, id, group_name)
		local group_name = group_name or ("_registergroup_" .. SHIP_NEXT_ID);

		player = player or 0;
		position = position or { 0, 0, 0 };
		rotation = rotation or { 0, 0, 0 };
		in_hyperspace = in_hyperspace or 0;

		if (id == nil) then
			id = SHIP_NEXT_ID;
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
			initGlobalMissionShips();
			id = id or modkit.table.length(GLOBAL_MISSION_SHIPS._entities);
			GLOBAL_MISSION_SHIPS:set(id, modkit.compose:instantiate(group_name, player, id, type));
		end
	end

	---@class MissionShip
	---@field type string
	---@field player? integer
	---@field position? Vec3
	---@field rotation? Vec3
	---@field in_hyperspace? 0|1
	---@field group_name? string
	---@field no_squad? bool

	--- Called in the .level to place squads and assign them to groups
	--- Called in the .lua gametime to register Ship objects for these defined ships
	---@param level_path? string The full path to the .level of the mission (only for call during .lua, not for .level)
	function registerShips(level_path)
		if (MISSION_SHIPS == nil) then -- if in .lua context
			---@cast level_path string
			print("register ships from path: " .. level_path);
			dofilepath(level_path);
		end

		for _, ship in MISSION_SHIPS do
			local count = ship.count or 1;
			for _ = 1, count, 1 do
				registerShip(
					ship.type,
					ship.player,
					ship.position,
					ship.rotation,
					ship.in_hyperspace,
					ship.id,
					ship.group_name
				);
			end
		end
	end

	H_SP_HELPERS = 1;
end

--- Returns a 'ship factory', which is just a tool for constructing ship definitions for creation on the `.level`.
---
--- ---
--- 
--- ```lua
--- local sf = makeShipFactory();
--- sf:type('kus_scout'):create(); -- can just immediately `:create` after defining
--- -- or we can define some config like 'assault frigs with a given rotation for player 0'
--- local p0_rotated_assaultfrig = sf:rotation({ 100, 0, 200 }):type('tai_assaultfrigate'):player(0);
--- -- this lets us re-use a definition or extend it extremely easily before calling `:create`
--- for i = 0, 10, 1 do
---   p0_rotated_assaultfrig:position({ i * 100, 0, 0}):create();
--- end
--- ```
---
---@return ShipFactory
function makeShipFactory()
	---@class FactoryState
	---@field type string
	---@field player integer
	---@field position Vec3
	---@field rotation Vec3
	---@field in_hyperspace 0|1
	---@field id? integer
	---@field group? string

	---@type FactoryState
	local _state = {
		 type = 'tai_probe',
		 player = 0,
		 position = { 1000, 10000, -200 },
		 rotation = { 0, -90, 0 },
		 in_hyperspace = 0,
		 id = nil,
		 group = nil,
	};

	---@class ShipFactory
	---@field _state FactoryState
	---@field create fun(self: ShipFactory, count?: integer): FactoryState
	---@field type fun(self: ShipFactory, type: string): ShipFactory
	---@field player fun(self: ShipFactory, player: integer): ShipFactory
	---@field position fun(self: ShipFactory, position: Vec3): ShipFactory
	---@field rotation fun(self: ShipFactory, rotation: Vec3): ShipFactory
	---@field in_hyperspace fun(self: ShipFactory, in_hyperspace: 0|1): ShipFactory
	---@field id fun(self: ShipFactory, id_override: integer): ShipFactory
	---@field group fun(self: ShipFactory, group_name: string): ShipFactory
	local factory = {
		 _state = _state,
	};

	for k, _ in _state do
		 -- i.e factory['player'] = function (self, value) self._state['player'] = value; end
		 factory[k] = function(self, value)
			  self._state[%k] = value;
			  return self;
		 end
	end

	function factory:create(count)
		count = count or 1;
		 for _ = 1, count do
			registerShip(
				self._state.type,
				self._state.player,
				self._state.position,
				self._state.rotation,
				self._state.in_hyperspace,
				self._state.id,
				self._state.group
			);
		 end
		 return self._state;
	end

	return factory;
end

---@see makeShipFactory
shipFactory = makeShipFactory();
