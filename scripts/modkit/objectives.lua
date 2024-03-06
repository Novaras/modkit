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
	---@field description fun(self, description?: string|userdata): string|userdata
	---@field visible fun(self, visible?: 0|1): bool
	---@field completed fun(self, completed?: 0|1): bool
	---@field type fun(self, type?: ObjectiveType): ObjectiveType
	---@field select fun(self): nil

	---@class GlobalObjectives: MemGroupInst
	---@field _entities table<integer, ObjectiveDef>
	---@field _saved_states table<integer, ObjectiveState>
	---@field all fun(self): table<integer, ObjectiveDef>
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
				if (completed == 1) then
					state = OBJECTIVE_STATE.OS_Complete;
				elseif (completed == 0) then
					state = OBJECTIVE_STATE.OS_Incomplete;
				end

				if (state) then
					Objective_SetState(%def.id, state);
				end

				%def.state = Objective_GetState(%def.id); -- update the def

				return %def.state == OBJECTIVE_STATE.OS_Complete;
			end,
			description = function (_, description)
				consoleLog("\tcall to description!");
				if (description) then
					consoleLog("\tsetting to " .. tostring(description or "nil"));
					%def.description = description;
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

		---@type integer
		local o = fields.id;
		Objective_AddPresetID(fields.id, fields.name, fields.type);

		self._entities[o] = fields;

		return objectiveDefToObjective(self._entities[o]);
	end

	-- add it also to the modkit table
	modkit.objectives = GLOBAL_OBJECTIVES;

	MODKIT_OBJECTIVES = 1;
end