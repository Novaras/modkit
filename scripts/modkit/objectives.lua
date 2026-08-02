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
	---@field description fun(self, description?: string|userdata, overwrite: bool): string|userdata
	---@field visible fun(self, visible?: 0|1): bool
	---@field completed fun(self, completed?: 0|1): bool
	---@field failed fun(self): bool
	---@field off fun(self): bool
	---@field type fun(self, type?: ObjectiveType): ObjectiveType
	---@field select fun(self): nil

	---@class GlobalObjectives: MemGroupInst
	---@field _entities table<integer, ObjectiveDef>
	---@field _saved_states table<integer, ObjectiveState>
	---@field all fun(self): table<integer, Objective>
	GLOBAL_OBJECTIVES = modkit.MemGroup.Create("mg-objectives-global");
	GLOBAL_OBJECTIVES._saved_states = {};

	--- Converts an `ObjectiveDef` (data object) to an `Objective` (api wrapper).
	---@param def ObjectiveDef
	---@return Objective
	function objectiveDefToObjective(def)

		---@type Objective
		local objective = {
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
				-- when hiding an objective, we save whatever state it was previously in so we can reset to that state when unhiding
				if (visible == 1 and %def.state == OBJECTIVE_STATE.OS_Off) then -- if making visible, and currently hidden
					local previous_state = GLOBAL_OBJECTIVES._saved_states[%def.id]; -- load the previous state before we were hidden, if any
					Objective_SetState(%def.id, previous_state or OBJECTIVE_STATE.OS_Incomplete);
				elseif (visible == 0 and %def.state ~= OBJECTIVE_STATE.OS_Off) then -- if making invisible, and currently NOT hidden
					GLOBAL_OBJECTIVES._saved_states[%def.id] = Objective_GetState(%def.id); -- save the current state against the id
					Objective_SetState(%def.id, OBJECTIVE_STATE.OS_Off); -- set the state to off (hidden)
				end

				%def.state = Objective_GetState(%def.id); -- update the def

				return %def.state ~= OBJECTIVE_STATE.OS_Off;
			end,
			completed = function (_, completed)
				local state = nil;
				if (completed == 0) then
					state = OBJECTIVE_STATE.OS_Incomplete;
				else
					state = OBJECTIVE_STATE.OS_Complete;
				end

				if (state) then
					Objective_SetState(%def.id, state);
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
			description = function (_, description, overwrite)
				if (not description) then
					Objective_SetDescription(%def.id, '');
				elseif (type(description) == "string") then
					if (overwrite) then
						Objective_SetDescription(%def.id, description);
					else
						Objective_AddDescription(%def.id, description);
					end
				else
					if (overwrite) then
						Objective_SetDescriptionw(%def.id, description);
					else
						Objective_AddDescriptionw(%def.id, description);
					end
				end

				%def.description = description;

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

		-- tag method which prints a warning if the objective object is being used to access an objective def which is no longer existing
		-- (so the log is more understandable, reference errors can be confusing)
		-- doesn't take any action to prevent an error occuring; this is probably the desired behavior

		local reference_checker_tag = newtag();
		local referenceCheckerHook = function (ref, key)
			if (not %def) then
				local output = consoleError or print;

				output("Warning: attempted to use an Objective who's underlying data was deleted!");
				output("\tA call to `GLOBAL_OBJECTIVES:delete` was probably called on the target objective's ID previously.");
				return nil;
			end

			return rawget(ref, key);
		end
		settagmethod(reference_checker_tag, "gettable", referenceCheckerHook);
		settag(objective, reference_checker_tag);

		return objective;
	end

	--- Sets a new objective.
	---
	---@param fields ObjectiveDefPartial
	---@return Objective
	function GLOBAL_OBJECTIVES:set(fields)
		fields = modkit.table:merge({
			id = modkit.table.length(self._entities),
			name = "mk-objective-" .. modkit.table.length(self._entities),
			description = "",
			state = OBJECTIVE_STATE.OS_Off,
			type = OBJECTIVE_TYPE.OT_Primary,
		}, (fields or {}));

		-- avoid using `Objective_Add`; if we used `_AddPresetID` in-between those calls, it throws an error
		-- complaining about non-sequential objective IDs (dumbest possible behavior)

		Objective_AddPresetID(fields.id, fields.name, fields.type);

		self._entities[fields.id] = fields;

		return objectiveDefToObjective(self._entities[fields.id]);
	end

	function GLOBAL_OBJECTIVES:get(id)
		local found = this._entities[id];

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