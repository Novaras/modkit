if (not modkit) then modkit = {} end

if (not modkit.events) then dofilepath("data:scripts/modkit/events.lua"); end
if (not modkit.objectives) then dofilepath("data:scripts/modkit/objectives.lua"); end
if (not displayMessage) then dofilepath("data:scripts/modkit/campaign-util.lua"); end


---@alias DataType "number"|"string"|"nil"|"function"|"table"|"userdata"

--- For an 'accessor', meaning a method which is a getter AND a setter, this function will check it performs as expected.
---
--- On success, returns `nil`. Any errors are accumulated in an array and returned instead, if any occur.
---
---@param objective Objective
---@param accessor_field string
---@param options { set_to?: any, expected_value?: any, data_types: DataType|DataType[], data_field?: string, objective_def?: ObjectiveDef|ObjectiveDefPartial }
---@return string[]|nil
function checkAccessor(objective, accessor_field, options)
	local set_to = options.set_to;
	local expected_value = options.expected_value;
	local data_types = options.data_types;
	local data_field = options.data_field;
	local objective_def = options.objective_def;

	if (type(data_types) ~= "table") then
		data_types = { data_types };
	end

	local errors = {};

	local allowed_types_str = modkit.table.reduce(data_types, function (accumulated, val)
		return accumulated .. ", " .. val;
	end, "");

	local accessor = function (val)
		if (val) then
			return %objective[%accessor_field](%objective, val);
		end

		return %objective[%accessor_field](%objective);
	end

	-- get
	local getter_type = modkit.table.includesValue(data_types, type(accessor()));
	if (not getter_type) then
		modkit.table.push(errors, "Type returned from accessor (no set) is not one of " .. allowed_types_str);
	end

	local matches_underlying_data = nil;
	if (data_field and objective_def) then
		matches_underlying_data = (getter_type and accessor() == objective_def[data_field]);

		if (not matches_underlying_data) then
			modkit.table.push(errors, "Accessor return does not match value on underlying data: " .. tostring(accessor() or 'nil') .. " vs " .. objective_def[data_field])
		end
	end

	-- if not checking setting, just return the info about the get
	if (not set_to) then
		if (modkit.table.length(errors) > 0) then
			return errors;
		end
		return nil;
	end

	-- set
	local old_val = accessor();
	local val = set_to;
	accessor(val);
	local setter_type = modkit.table.includesValue(data_types, type(accessor()));
	local setter_value_is_set = accessor() == expected_value and accessor() ~= old_val;

	if (not setter_type) then 
		modkit.table.push(errors, "Type returned from accessor after set is not one of " .. allowed_types_str);
	end

	if (not setter_value_is_set) then
		modkit.table.push(errors, "Accessor set did not set the value from " .. tostring(old_val or 'nil') .. " to " .. tostring(expected_value or 'nil') .. ", instead got " .. tostring(accessor() or 'nil'));
	end

	if (modkit.table.length(errors) > 0) then
		return errors;
	end
	return nil;
end

--- Logs a feature test step's result, like the unit tests' PASS/FAIL lines.
---
---@param step string
---@param passed any
---@param detail? string
function featureResult(step, passed, detail)
	local result = "<b><c=2222FF>PASS</c></b>";
	if (not passed) then
		result = "<b><c=ff5555>FAIL</c></b>";
	end
	local line = "<c=AA6622>" .. step .. "</c> " .. result;
	if (detail) then
		line = line .. " " .. detail;
	end
	consoleLog(line);
end

_TESTS = {
	seed = function ()
		local def = {
			name = "test " .. modkit.table.length(GLOBAL_OBJECTIVES._entities),
			description = "test descr.",
			state = OBJECTIVE_STATE.OS_Incomplete,
			type = OBJECTIVE_TYPE.OT_Primary
		};

		-- no `id`, so the engine picks it (preset IDs are a FATAL EXIT in skirmish, whose rules add an objective sequentially)
		local objective = modkit.objectives:set(def);
		def.id = objective:id();
		modkit.table.push(_TESTS.seeded, objective);

		return {
			objective_def = def,
			objective = objective
		};
	end,
	-- the objectives made by `seed`, switched off by `cleanup` so they don't stay in the objectives list
	seeded = {},
	cleanup = function ()
		for i = 1, getn(_TESTS.seeded) do
			_TESTS.seeded[i]:off();
		end
		_TESTS.seeded = {};
	end,
	unit = {
		-- tests follow
		id = function (data)
			local objective = data.objective;
			local def = data.objective_def;

			local id_getter_works = type(objective:id()) == "number" and objective:id() == def.id;

			return id_getter_works == nil;
		end,
		name = function (data)
			local name = "updated name " .. data.objective:id();

			return checkAccessor(data.objective, "name", { set_to = name, expected_value = name, data_types = "string", data_field = "name" });
		end,
		description = function (data)
			local desc = "updated desc. " .. data.objective:id();

			return checkAccessor(data.objective, "description", { set_to = desc, expected_value = desc, data_types = "string", data_field = "description" });
		end,
		visible = function (data)
			local visibility = 0; -- should be 1 by default since the seed data begins as `OS_Incomplete`

			return checkAccessor(data.objective, "visible", { set_to = visibility, expected_value = nil, data_types = { "number", "nil" } });
		end,
		completed = function (data)
			local completed = 1; -- should be 0 by default since the seed data begins as `OS_Incomplete`

			return checkAccessor(data.objective, "completed", { set_to = completed, expected_value = 1, data_types = { "number", "nil" } });
		end,
		type = function (data)
			local type = OBJECTIVE_TYPE.OT_Secondary; -- should be `OT_Primary` by from the seed data

			return checkAccessor(data.objective, "type", { set_to = type, expected_value = type, data_types = "number" });
		end,
		refError = function (data)
			local objective = data.objective;
			local def = data.def;

			local ref_exists_prior = def and objective:id() ~= nil;
			def = nil;
			local ref_is_deleted = not def and objective:id() == nil;

			return ref_exists_prior and ref_is_deleted;
		end
	},
	feature = {
		main_operations = modkit.events:make(function (res, _, state)
			-- 1. make N objectives (shown, the default)
			-- 2. after Xs, hide every other one
			--    (hiding is permanent, so there's no step showing them again: the engine keeps an objective in `OS_Off`)
			-- 3. after Xs, mark one shown objective as complete, and one as failed, and select the completed one
			-- 4. hide them all

			---@class ObjectivesFeatureTestState : { started?: 1, finished?: 1 }, EventState
			---@cast state ObjectivesFeatureTestState

			-- (own fields, rather than `_value`, which is overwritten with the callback's return value every run)
			if (not state.started) then
				state.started = 1;

				local N = 12;
				---@type Objective[]
				local objectives = {};
				for i = 1, N do
					local def = {
						type = modkit.table.randomEntry({ OT_Primary, OT_Secondary })[2],
						name = "Feature Test Objective " .. tostring(i),
						description = "Desc. for FT Objective " .. tostring(i),
					};
					modkit.table.push(objectives, modkit.objectives:set(def));
				end

				consoleLog("<b>These tests require game time to pass; close the console to allow tests to run.</b>");

				local wait_time = 5;

				-- this event's state is passed down the chain, so the last link can mark the test finished
				displayMessage({ duration = wait_time, message = "== BEGINNING OBJECTIVES FEATURE TESTS ==", value = state })
					:begin()
					:next(function (res, _, state)
						for i = 1, getn(%objectives) do
							if (mod(i, 2) == 1) then
								%objectives[i]:visible(0);
							end
						end

						local shown = {}; -- (a list, in order; `modkit.table.filter` keeps the original keys)
						for i = 1, getn(%objectives) do
							if (%objectives[i]:visible()) then
								shown[getn(shown) + 1] = %objectives[i];
							end
						end
						featureResult("hide every other one", getn(shown) == getn(%objectives) / 2, getn(shown) .. " of " .. getn(%objectives) .. " shown");

						res({ shown = shown, outer_state = state._previous_result });
					end)
					:next(displayMessage({ duration = wait_time }))
					:next(function (res, _, state)
						local shown = state._previous_result.shown;
						local completed = shown[1];
						local failed = shown[2];

						completed:completed(1);
						failed:failed();
						completed:select();
						featureResult("complete one", completed:completed(), completed:name());
						featureResult("fail one", Objective_GetState(failed:id()) == OBJECTIVE_STATE.OS_Failed, failed:name());

						res(state._previous_result);
					end)
					:next(displayMessage({ duration = wait_time }))
					:next(function (res, _, state)
						for i = 1, getn(%objectives) do
							%objectives[i]:off();
						end
						featureResult("hide all", modkit.table.length(modkit.table.filter(%objectives, function (objective)
							return objective:visible();
						end)) == 0);

						consoleLog("<b>Feature tests finished.</b>");
						state._previous_result.outer_state.finished = 1;
						res();
					end);
			end

			if (state.finished) then
				res();
			end
		end);
	},
};

-- here we set a function call proxy so we can magically provide the seed data for the tests
local seeder_tag = newtag();
local seedDataHook = function (tbl, key)
	print("ACCESS ON UNIT TESTS TABLE!");
	local v = rawget(tbl, key);

	print("k = " .. key .. ", v = " .. tostring(rawget(tbl, key) or "nil"));

	if (type(v) == "function") then
		return function ()
			return %v(_TESTS.seed());
		end;
	end

	return v;
end
settagmethod(seeder_tag, "gettable", seedDataHook);
settag(_TESTS.unit, seeder_tag);