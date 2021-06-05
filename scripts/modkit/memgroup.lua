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

if (modkit.memgroup == nil) then
	modkit.memgroup = {
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
		_new = function(group_name, custom_attribs)
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
				e.id = entityID;
				if (e._tick == nil) then
					e._tick = 0;
				end
				function e:NextTick()
					self._tick = self._tick + 1;
					if (self._tick >= 127) then
						self._tick = 0;
					end
					return self._tick;
				end
				function e:GetTick()
					return self._tick;
				end
				return e;
			end
			function new_group:delete(entityID)
				self._entities[entityID] = nil;
			end
			function new_group:find(predicate)
				return modkit.table.find(self._entities, predicate);
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
			if (modkit.memgroup._groups[group_name] == nil) then
				return modkit.memgroup.ForceCreate(group_name, custom_attribs);
			end
			return modkit.memgroup._groups[group_name];
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
			modkit.memgroup._groups[group_name] = modkit.memgroup._new(group_name, custom_attribs);
			return modkit.memgroup._groups[group_name];
		end,

		-- Get
		-- 1: group_name: string
		--
		-- return: MemGroup
		--
		-- Returns the group indexed by group_name.
		Get = function (group_name)
			return modkit.memgroup._groups[group_name];
		end,

		-- Exists
		-- 1: group_name
		--
		-- return: boolean
		--
		-- Checks the existence of the group indexed by group_name
		Exists = function (group_name)
			return modkit.memgroup._groups[group_name] ~= nil;
		end
	}

	print("memgroup init");
end