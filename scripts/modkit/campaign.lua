-- campaign.lua: utils for writing campaign scripts.
-- By: Fear (Novaras)

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (H_CAMPAIGN == nil) then
	local campaign = {};
	modkit.campaign = {};

	if (GLOBAL_RULES == nil) then

		---@class RuleCoreState
		---@field _rule_name string
		---@field _interval integer
		---@field _started_gametime number
		---@field _tick integer

		---@class RuleState : RuleCoreState, table

		---@alias RuleFn fun(state: RuleState, rules: Rules)

		---@class Rule
		---@field fn RuleFn
		---@field id string
		---@field interval integer
		---@field status "init"|"running"|"returned"
		---@field api_name string
		---@field value any|nil
		---@field fn_state RuleState
		---@field core_state RuleCoreState

		---@class GLOBAL_RULES : MemGroup
		---@field _entities Rule[]
		---@field __runner function|nil
		---@field __listeners table
		---@field __level_path string
		GLOBAL_RULES = modkit.MemGroup.Create("mg-rules-global", {
			__runner = nil,
			__rule_pattern = nil,
			__listeners = {},
			__level_path = nil
		});

		function GLOBAL_RULES:add(id, rule_fn, interval, state)
			---@type Rule
			local rule = {
				id = id,
				interval = interval,
				status = "init",
				api_name = "modkit_rule_fn__" .. id,
				fn = rule_fn,
				core_state = {
					_rule_name = id,
					_interval = interval
				}
			};

			rule.fn_state = modkit.table:merge(
				rule.core_state,
				{
					_tick = 0,
					_started_gametime = -1
				},
				state
			);

			function rule:finish()
				print("kill rule " .. self.api_name);
				Rule_Remove(self.api_name);
				self.status = "returned";
			end

			function rule:run()
				-- unset any modification to core state and update tick
				self.fn_state = modkit.table:merge(
					self.fn_state,
					self.core_state
				);
				self.fn_state._tick = self.fn_state._tick + 1;
				local result = self.fn(self.fn_state, modkit.campaign.rules);
				if (result) then
					self:finish();
				end
				self.value = result; -- store in state!
				return result;
			end

			function rule:begin()
				if (self.status ~= "init") then
					self:finish();
				end
				self.fn_state._started_gametime = Universe_GameTime();
				print("begin rule " .. self.api_name);
				GLOBAL_RULES.__runner = function ()
					%self:run();
				end;
				dostring(self.api_name .. " = GLOBAL_RULES.__runner"); -- my word...
				print(globals()[self.api_name]);
				Rule_AddInterval(self.api_name, self.interval);
				self.status = "running";
			end

			return self:set(id, rule);
		end

	end

	-- rule creation, management...

	---@class Rules
	local rules = {
		min_poll_interval = 0.1,
	};

	---@param name string
	---@return Rule
	function rules:get(name)
		return GLOBAL_RULES:get(name);
	end

	---@param name string
	---@param rule_fn RuleFn
	---@param interval integer
	---@return Rule
	function rules:make(name, rule_fn, interval, state)
		interval = interval or self.min_poll_interval;
		local already_exists = GLOBAL_RULES:find(function (rule)
			return rule.name == %name;
		end);
		if (already_exists) then
			print("overriding already existing rule: " .. name);
		end

		return GLOBAL_RULES:add(name, rule_fn, interval, state);
	end

	---@param rule Rule
	---@return nil
	function rules:begin(rule)
		rule:begin();
	end

	--- Takes a 'rule pattern', which is lua-style 'and' and 'or' with rule names, firing `callback` if the patten
	-- is satisfied.
	---
	--- This pattern would trigger `callback` if rules `'A'` AND `'rule_b'` AND `'myC0OlRule'` were finished, OR if rule `'D'` finished:
	--- ```lua
	--- 	'(A and rule_b and myC0OlRule) or D'
	--- ```
	--- Returns a LUA string to execute (we just leverage LUA's inbuilt language parsing).
	---
	---@param pattern string
	---@param callback fun(rules: Rules): any
	---@return nil
	function rules:on(pattern, callback)
		-- 'A and (B or C)'
		-- -> 'A&(B or C)'
		-- -> 'A&(B|C)'
		local exec = function ()
			local rules = %self;
			pattern_exec = "" .. %pattern;
			pattern_exec = gsub(pattern_exec, " and ", " & ");
			pattern_exec = gsub(pattern_exec, " or ", " | ");
			-- here we are constructing a LUA logic expression which will tell us the truthiness of the supplied pattern
			-- if a rule is running, we insert true (1), else false (nil)
			-- (we construct something like: "return 1 and nil and nil or (1 and 1)")
			pattern_exec = gsub(pattern_exec, "([%w_]+)", function(matches)
				if(%rules:get(matches).status == "returned") then
					return "1";
				end
				return "nil";
			end);
			pattern_exec = gsub(pattern_exec, " & ", " and ");
			pattern_exec = gsub(pattern_exec, " | ", " or ");
			pattern_exec = gsub(pattern_exec, "^%s*(.-)%s*$", "%1");
			pattern_exec = "return " .. pattern_exec;
			return pattern_exec;
		end;

		if (GLOBAL_RULES.__listeners[pattern]) then
			print("overrriding already existing listener for [ " .. pattern .. " ]");
		end

		GLOBAL_RULES.__listeners[pattern] = {
			pattern = pattern,
			exec = exec,
			callback = callback
		};
	end

	function rules:init(level_path)
		GLOBAL_RULES.__level_path = level_path;

		if (GLOBAL_MISSION_SHIPS == nil) then
			-- dofilepath(level_path);
			RegisterShips(level_path);
			print("INIT MISSION SOBGROUPS");
		end
	end

	-- == map getters

	local map = {};

	--- Returns a MemGroup of all the ships in the level file
	---@return GLOBAL_MISSION_SHIPS
	function map:ships()
		return GLOBAL_MISSION_SHIPS; -- defined in sp_helpers.lua (called from the .level file)
	end

	-- automatic rule, which checks for listener completion
	function modkit_campaign_driver()
		for _, listener in GLOBAL_RULES.__listeners do
			if (dostring(listener.exec())) then
				print(listener.pattern .." passed conditions!");
				listener.callback(%rules);
				GLOBAL_RULES.__listeners[listener.pattern] = nil; -- unsubscribe
			end
		end

		
		-- local new_universe_ships_group = Universe_GetAllActiveShips(SobGroup_Fresh("__mk_univese_ships"));
		-- if (modkit.campaign.universe_ships_group) then
		-- 	local diff_group = SobGroup_Fresh("__mk_universe_ships_diff");
		-- 	-- sub the old run ships from the current run ships to find newbies
		-- 	SobGroup_Substract(diff_group, new_universe_ships_group, modkit.campaign.universe_ships_group);
			
		-- 	-- now we make the assumption that new ships are probably spaced apart
		-- else
		-- 	modkit.campaign.universe_ships_group = new_universe_ships_group;
		-- end
	end

	if (OnInit == nil) then
		OnInit = function ()
			Rule_AddInterval("modkit_campaign_driver", %rules.min_poll_interval);
		end;
	end

	campaign.map = map;
	campaign.rules = rules;
	modkit.campaign = campaign;

	H_CAMPAIGN = 1;
end