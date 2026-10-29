if (MODKIT_OBJECTIVES == nil) then
	if (modkit == nil) then modkit = {}; end
	if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

	---@class ObjectiveDef
	---@field id integer
	---@field name string|userdata
	---@field description string|userdata
	---@field state ObjectiveState
	---@field type ObjectiveType

	---@class ObjectiveDefPartial
	---@field id? integer
	---@field name? string|userdata
	---@field description? string|userdata
	---@field state? ObjectiveState
	---@field type? ObjectiveType

	---@class Objective
	---@field id fun(self): integer
	---@field name fun(self, name?: string|userdata): string|userdata
	---@field description fun(self, description?: string|userdata, append?: bool): string|userdata Sets the description (or appends to it, with `append`); no argument just reads it
	---@field visible fun(self, visible?: 0|1): bool Hides (`0`) the objective, or reads whether it's shown (no argument). **Hiding is permanent**: the engine won't show it again, so `1` only works on an objective that isn't hidden
	---@field completed fun(self, completed?: 0|1): bool
	---@field failed fun(self): bool
	---@field off fun(self): bool Hides the objective, permanently (like `visible(0)`)
	---@field type fun(self, type?: ObjectiveType): ObjectiveType
	---@field select fun(self): nil

	---@class GlobalObjectives: MemGroupInst
	---@field _entities table<integer, ObjectiveDef>
	---@field all fun(self): table<integer, Objective>
	GLOBAL_OBJECTIVES = modkit.MemGroup.Create("mg-objectives-global");

	-- one tag shared by every objective object (Lua 4 tags are never freed, so a tag per object leaked one each time
	-- an objective was wrapped, which `:all`/`:find`/`:filter` do for every objective on every call)
	--
	-- prints a warning if the objective object is being used to access an objective def which no longer exists
	-- (so the log is more understandable, reference errors can be confusing)
	-- doesn't take any action to prevent an error occuring; this is probably the desired behavior
	GLOBAL_OBJECTIVES._objective_tag = newtag();
	settagmethod(GLOBAL_OBJECTIVES._objective_tag, "gettable", function (ref, key)
		-- looked up by id (rather than an upvalue of the def, which Lua 4 copies at closure creation, so it never became nil)
		if (GLOBAL_OBJECTIVES._entities[rawget(ref, "__def_id")] == nil) then
			local output = consoleError or print;

			output("Warning: attempted to use an Objective who's underlying data was deleted!");
			output("\tA call to `GLOBAL_OBJECTIVES:delete` was probably called on the target objective's ID previously.");
			return nil;
		end

		return rawget(ref, key);
	end);

	--- Converts an `ObjectiveDef` (data object) to an `Objective` (api wrapper).
	---@param def ObjectiveDef
	---@return Objective
	function objectiveDefToObjective(def)

		---@type Objective
		local objective = {
			__def_id = def.id, -- read (raw) by the shared tag's hook, to check the def still exists
			id = function (_)
				return %def.id;
			end,
			name = function (_, name)
				if (name) then
					%def.name = name;
				end

				return %def.name;
			end,
			visible = function (_, visible)
				-- hiding is permanent: the engine won't take an objective out of `OS_Off` once it's there (tested 2026-10-28, and
				-- vanilla treats `OS_Off` as removal, see `KASObjective_Destroy`), so `visible(1)` can't show a hidden objective
				if (visible == 0 and %def.state ~= OBJECTIVE_STATE.OS_Off) then
					Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Off);
				elseif (visible == 1 and %def.state == OBJECTIVE_STATE.OS_Off) then
					local output = consoleError or print;
					output("objective " .. %def.id .. " (" .. tostring(%def.name) .. ") can't be shown again: hiding an objective is permanent");
				end

				%def.state = Objective_GetState(%def.id); -- update the def

				return %def.state ~= OBJECTIVE_STATE.OS_Off;
			end,
			completed = function (_, completed)
				-- (no argument just reads the state)
				if (completed == 0) then
					Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Incomplete);
				elseif (completed) then
					Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Complete);
				end

				%def.state = Objective_GetState(%def.id); -- update the def

				return %def.state == OBJECTIVE_STATE.OS_Complete;
			end,
			failed = function(_)
				Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Failed);

				%def.state = Objective_GetState(%def.id);

				return %def.state == OBJECTIVE_STATE.OS_Failed;
			end,
			off = function(_)
				Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Off);

				%def.state = Objective_GetState(%def.id);

				return %def.state == OBJECTIVE_STATE.OS_Off;
			end,
			description = function (_, description, append)
				-- (no argument just reads it; pass `""` to clear it)
				if (description == nil) then
					return %def.description;
				end

				if (type(description) == "string") then
					if (append) then
						Objective_AddDescription(%def.id, description);
					else
						Objective_SetDescription(%def.id, description);
					end
				else
					if (append) then
						Objective_AddDescriptionw(%def.id, description);
					else
						Objective_SetDescriptionw(%def.id, description);
					end
				end

				if (append and type(description) == "string" and type(%def.description) == "string") then
					%def.description = %def.description .. description;
				else
					%def.description = description; -- (a wide string can't be concatenated, so only the latest part is kept)
				end

				return %def.description;
			end,
			type = function (_, type)
				if (type) then
					%def.type = type;
				end

				return %def.type;
			end,
			select = function (_)
				return Objective_Select(%def.id);
			end
		};

		settag(objective, GLOBAL_OBJECTIVES._objective_tag); -- see `_objective_tag`

		return objective;
	end

	--- Sets a new objective.
	---
	--- The engine numbers objectives either sequentially (`Objective_Add`, which picks the ID) or by preset IDs
	--- (`Objective_AddPresetID`), and **mixing the two in one game is a FATAL EXIT**. Without an `id`, this adds the objective
	--- sequentially (like vanilla, including the multiplayer rules' own "destroy enemy motherships" objective), and uses the
	--- engine's ID; with an `id`, it uses that preset ID. Mixing the two through this function prints an error and returns `nil`
	--- instead of crashing (calls made outside modkit can't be checked).
	---
	---@param fields ObjectiveDefPartial
	---@return Objective|nil
	function GLOBAL_OBJECTIVES:set(fields)
		fields = modkit.table:merge({
			name = "mk-objective-" .. modkit.table.length(self._entities),
			description = "",
			state = OBJECTIVE_STATE.OS_Incomplete, -- (shown, like the engine's own default; hiding with `OS_Off` is permanent, see `visible`)
			type = OBJECTIVE_TYPE.OT_Primary,
		}, (fields or {}));

		local id_mode = "sequential";
		if (fields.id) then
			id_mode = "preset";
		end
		if (self._id_mode and self._id_mode ~= id_mode) then
			local output = consoleError or print;
			output("modkit.objectives:set: can't add objective '" .. tostring(fields.name) .. "' with a " .. id_mode .. " ID, since " .. self._id_mode .. " IDs are already in use (mixing them is a FATAL EXIT)");
			return nil;
		end
		self._id_mode = id_mode;

		if (fields.id) then
			Objective_AddPresetID(fields.id, fields.name, fields.type);
		else
			fields.id = Objective_Add(fields.name, fields.type);
		end

		-- apply the rest, so the engine matches the def (the accessors read the def)
		Objective_SetState(fields.id, fields.state);
		if (fields.description ~= "") then
			if (type(fields.description) == "string") then
				Objective_SetDescription(fields.id, fields.description);
			else
				Objective_SetDescriptionw(fields.id, fields.description);
			end
		end

		self._entities[fields.id] = fields;

		return objectiveDefToObjective(self._entities[fields.id]);
	end

	function GLOBAL_OBJECTIVES:get(id)
		local found = self._entities[id];

		if (found) then
			return objectiveDefToObjective(found);
		end
	end

	function GLOBAL_OBJECTIVES:all()
		return modkit.table.map(self._entities, function (def)
			return objectiveDefToObjective(def);
		end);
	end

	function GLOBAL_OBJECTIVES:find(predicate)
		return modkit.table.findVal(self:all(), predicate);
	end

	function GLOBAL_OBJECTIVES:filter(predicate)
		return modkit.table.filter(self:all(), predicate);
	end

	-- add it also to the modkit table
	modkit.objectives = GLOBAL_OBJECTIVES;

	MODKIT_OBJECTIVES = 1;
end