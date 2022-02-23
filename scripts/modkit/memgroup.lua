-- Group management --
-- By: Fear
-- 
-- Use this object to persist memory across script calls.
--
-- This is just a global table of tables with a small api.
-- MemGroups represents an associative array of ship groups.
-- The groups themselves also come with a default set of accessors,
-- which can be extended via custom_attribs when creating the group.
--
-- Accessing the groups themselves is not recommended, but obviously
-- entirely possible.

if (modkit == nil) then modkit = {}; end

if (modkit.table == nil) then
	dofilepath("data:scripts/modkit/table_util.lua");
end

if (modkit.MemGroup == nil) then
	---@class MemGroup
	modkit.MemGroup = {
		_groups = {},
		-- _new
		-- 1: group_name: string
		-- 2: custom_attribs: table<any, any>
		--
		-- return: MemGroup
		--
		-- Internal function. Creates a new MemGroup on the _groups
		-- table. MemGroups are tables of Entities. Entities are tables
		-- with the following attributes:
		-- [entity]:
		--   _tick: string
		--   GetTick: function() => number
		--   NextTick: function() => number
		-- In addition, the entities will also host the attributes defined
		-- in custom_attributes.
		---@class MemGroupInst
		---@field group_name string
		---@field _entities table
		---@field get fun(entity_name: string): any
		---@field set fun(id, entity): any
		---@field delete fun(id): nil
		---@field all fun(): table
		---@field find fun(): any
		---@field filter fun(): table
		---@field shallowCopy fun(): table
		---@field length fun(): integer

		---@return MemGroupInst
		_new = function(group_name, custom_attribs)
			---@type MemGroupInst
			local new_group = {
				_entities = {},
				group_name = group_name,
			}
			for i, v in custom_attribs do
				new_group[i] = v;
			end
			function new_group:get(entityID)
				return self._entities[entityID];
			end
			function new_group:set(entityID, entity)
				if (entity == nil) then
					entity = {};
				end
				self._entities[entityID] = entity;
				local e = self._entities[entityID];
				if (e.id == nil) then
					e.id = entityID;
				end
				return e;
			end
			function new_group:delete(entityID)
				self._entities[entityID] = nil;
			end
			--- Returns all ships in this MemGroup.
			function new_group:all()
				return self._entities;
			end
			function new_group:find(predicate)
				return modkit.table.find(self._entities, predicate);
			end
			---@return table
			function new_group:filter(predicate)
				return modkit.table.filter(self._entities, predicate);
			end
			function new_group:shallowCopy(new_entities)
				new_entities = new_entities or self._entities;
				-- local new_group = modkit.table.clone(self, { override = { _entities = new_entities }});
				return modkit.table.clone(self, { override = { _entities = new_entities }});
			end
			---@return integer
			function new_group:length()
				return modkit.table.length(self._entities);
			end
			return new_group;
		end,
		-- Create
		-- 1: group_name: string
		-- 2: custom_attribs: table<any: any>
		--
		-- return: MemGroup
		--
		-- 'Soft' creation of group. If the group already exists, the already
		-- present group is returned instead.
		Create = function (group_name, custom_attribs)
			if (modkit.MemGroup._groups[group_name] == nil) then
				return modkit.MemGroup.ForceCreate(group_name, custom_attribs);
			end
			return modkit.MemGroup._groups[group_name];
		end,

		-- ForceCreate
		-- 1: group_name: string
		-- 2: custom_attribs: table<any: any>
		--
		-- return: MemGroup
		--
		-- 'Hard' creation of group. If a group with this name already exists,
		-- it will be silently overwritten. Internally calls _new.
		ForceCreate = function (group_name, custom_attribs)
			if custom_attribs == nil then
				custom_attribs = {};
			end
			modkit.MemGroup._groups[group_name] = modkit.MemGroup._new(group_name, custom_attribs);
			return modkit.MemGroup._groups[group_name];
		end,

		-- Get
		-- 1: group_name: string
		--
		-- return: MemGroup
		--
		-- Returns the group indexed by group_name.
		Get = function (group_name)
			return modkit.MemGroup._groups[group_name];
		end,

		-- Exists
		-- 1: group_name
		--
		-- return: boolean
		--
		-- Checks the existence of the group indexed by group_name
		Exists = function (group_name)
			return modkit.MemGroup._groups[group_name] ~= nil;
		end
	}

	print("memgroup init");
end