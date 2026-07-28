-- campaign.lua: utils for writing campaign scripts.
-- By: Fear (Novaras)

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (H_CAMPAIGN == nil or (modkit ~= nil and modkit.campaign == nil)) then
	local campaign = {};
	modkit.campaign = {};

	--- Cast a `RuleFn` to a `Rule` (filling with defaults). Does nothing if `rule` is not a `function` type.
	---
	---@param rule Rule|RuleFn|RuleInitConfig
	---@return Rule
	function toRule(rule)
		if (type(rule) == "function" or not rule.api_name) then
			---@cast rule RuleFn|RuleInitConfig
			return modkit.campaign.rules:make(rule);
		end
		---@cast rule Rule

		return rule;
	end

	---comment
	---@param rule Rule|RuleFn
	---@return RuleFn
	function toRuleFn(rule)
		if (type(rule) == "table" and rule.api_name) then
			return rule.fn;
		end
		---@cast rule RuleFn

		return rule;
	end

	if (GLOBAL_RULES == nil) then

		---@class RuleCoreState
		---@field _interval integer
		---@field _started_gametime number
		---@field _tick integer
		---@field _value any The return of the supplied callbacks previous run
		---@field _previous_result any The resolve value from the previous rule, if any

		---@class RuleState : RuleCoreState, table

		--- Call to end the rule executing this `RuleFn`. Args are included as the initial `_value` of the next chained rule, if any.
		---@alias RuleResolver fun(...: any): nil

		---@alias RuleRejector fun(message: string): nil

		---@alias RuleFn fun(resolveCallback: RuleResolver, rejectCallback: RuleRejector, state: RuleState): any

		---@alias RuleStatus "init"|"running"|"resolved"|"rejected"

		---@class RuleInitConfig
		---@field name? string
		---@field fn RuleFn
		---@field interval? number
		---@field initial_state? table
		---@field awaits_rules? string
		---@field immediate? bool In case the user wants to pass a whole bunch of rules from a big table etc.

		---@class Rule
		---@overload fun(): RuleChain
		---@field fn RuleFn
		---@field id string
		---@field interval integer
		---@field status RuleStatus
		---@field name string
		---@field api_name string
		---@field fn_state RuleState
		---@field core_state RuleCoreState
		---@field result any Resolved value after this rule ends via a `resolve` call
		---@field error? string Error message passed to a `RuleError` call in the chain
		--- Begins the rule, by calling `Rule_AddInterval` under the hood
		---@field begin fun(self: Rule, previous_result: any): RuleChain
		--- Wrapper callback for the user defined callback; forces the params into (resolver, rejecter, state, rules_handle)
		---@field run function
		--- Exits the rule, callng `Rule_Remove`. This rule object is presisted, and can be restarted later for example.
		---@field finish function

		---@class RuleChain
		--- Accepts a `Rule`, a callback, or a `Rule` id; invokes whatever was given as soon as the previous rule resolves.
		---@field next fun(self: RuleChain, action: Rule|RuleFn|string): RuleChain
		---@field catch fun(self: RuleChain, handler: function): nil If the previous rule exits via a reject, the error and rule object are passed to the supplied handler

		---@class Listener
		---@field pattern string
		---@field exec function
		---@field callback function|RuleInitConfig|Rule

		---@class GLOBAL_RULES : MemGroupInst
		---@field find fun(self: GLOBAL_RULES, predicate: fun(rule: Rule): bool): Rule|nil
		---@field _entities Rule[]
		---@field __runner function|nil
		---@field __listeners Listener[]
		---@field __level_path string
		---@field __tick integer
		---@field __default_interval integer
		GLOBAL_RULES = modkit.MemGroup.Create("mg-rules-global", {
			__runner = nil,
			__rule_pattern = nil,
			__listeners = {},
			__level_path = nil,
			__tick = 0,
			__default_interval = 1,
		});

		---
		---@param id string
		---@param rule_init_conf RuleInitConfig|RuleFn
		---@return Rule
		function GLOBAL_RULES:add(id, rule_init_conf)
			if (type(rule_init_conf) == "function") then
				rule_init_conf = {
					fn = rule_init_conf,
				};
			end
			---@cast rule_init_conf RuleInitConfig

			local rule = {
				id = id,
				interval = rule_init_conf.interval or self.__default_interval,
				status = "init",
				name = name,
				api_name = rule_init_conf.name or ("modkit_rule_fn__" .. id),
				fn = rule_init_conf.fn,
			};

			rule.core_state = {
				_tick = 0,
				_started_gametime = -1,
				_interval = rule_init_conf.interval or 1
			};

			rule.fn_state = modkit.table:merge(
				rule_init_conf.initial_state,
				rule.core_state
			);

			---
			---@param status RuleStatus
			---@param result any|any[]
			function rule:finish(status, result)
				print("kill rule " .. self.api_name);

				Rule_Remove(self.api_name);

				self.status = status;
				self.result = result;

				-- modkit.table.printTbl(GLOBAL_RULES, "GLOBAL_RULES");
			end

			function rule:run()
				self.fn_state = modkit.table:merge(
					self.fn_state,
					self.core_state
				);

				-- unset any modification to core state and update tick
				self.core_state._tick = self.core_state._tick + 1;

				local resolve = function (result)
					%self:finish("resolved", result);
				end

				local reject = function (message)
					%self.error = message;
					%self:finish("rejected", {});
				end

				self.core_state._value = self.fn(resolve, reject, self.fn_state);
				return self.core_state._value;
			end

			--- Begins this rule. This sets the status to `"running"` and calls `Rule_AddInterval` with the rule's `fn`.
			---
			---@param initial_value any
			---@return RuleChain|nil
			function rule:begin(initial_value)
				if (self.status ~= "init") then
					return nil;
				end
				self.core_state._started_gametime = Universe_GameTime();
				print("begin rule " .. self.api_name);
				-- we create a global function which runs the rule's 'run' callback
				GLOBAL_RULES.__runner = function ()
					%self:run();
				end;
				-- here we bind this function to a key on `globals()`
				dostring(self.api_name .. " = GLOBAL_RULES.__runner"); -- my word...
				print(globals()[self.api_name]);
				-- set the initial value (important for chaining)
				self.core_state._previous_result = initial_value;
				-- and we then invoke it every `self.interval` ticks
				Rule_AddInterval(self.api_name, self.interval);
				self.status = "running";

				---@param rule Rule|RuleFn|string
				---@return RuleChain
				_makeRuleChain = function (rule)
					if (type(rule) ~= "string" and type(rule.api_name) ~= "string") then
						---@cast rule RuleFn
						rule = toRule(rule);
					end
					---@cast rule Rule
					---@diagnostic disable-next-line: cast-local-type
					rule = modkit.campaign.rules:get(rule);
					---@cast rule Rule

					--- @class RuleChain
					local chainable = {};

					function chainable:next(action)
						if (type(action) == "function") then
							---@cast action RuleFn
							action = toRule(action);
						end
						---@diagnostic disable-next-line: cast-local-type
						action = modkit.campaign.rules:get(action);
						---@cast action Rule

						local rule = %rule;
						modkit.campaign.rules:on(rule.api_name, function ()
							print("next listener for " .. %rule.api_name);
							modkit.table.printTbl(%rule);
							if (%rule.status == "rejected") then -- on a previous reject, we need to propagate it
								%action.error = %rule.error;
								%action:finish("rejected", {});
							else
								%action:begin(%rule.result);
							end
						end); -- when current rule is done, call `action:begin()`

						return _makeRuleChain(action); -- another action can be appended
					end

					function chainable:catch(handler)
						local rule = %rule;
						modkit.campaign.rules:on(rule.api_name, function ()
							print("catch listener for " .. %rule.api_name);
							%handler(%rule.error, %rule);
						end);
					end

					return chainable;
				end

				return _makeRuleChain(self);
			end

			-- here we add a tag on the rule which lets you call the rule like a function: `myrule:begin();` equivalent to `myrule();`
			local rule_callable_tag = newtag();
			settagmethod(rule_callable_tag, "function", function ()
				return %rule:begin();
			end);
			settag(rule, rule_callable_tag);

			if (rule.awaits_rules) then
				modkit.campaign.rules:on(new_rule.awaits_rules, created);
			end

			---@cast rule Rule

			-- modkit.table.printTbl(rule, "new rule " .. rule.id);

			return self:set(id, rule);
		end

	end

	-- rule creation, management...

	---@class Rules
	local rules = {
		min_poll_interval = 0.1,
	};

	---@param name string|Rule The given name or API name
	---@return Rule|nil
	function rules:get(name)
		if (name and type(name) ~= "string") then
			return name;
		end
		---@cast name Rule

		-- print("hi");
		-- modkit.table.printTbl(name, "rule to access");
		-- modkit.table.printTbl(GLOBAL_RULES._entities, "GR _entities:")

		---@cast name string
		return GLOBAL_RULES:get(name) or GLOBAL_RULES:find(function (rule)
			return rule.id == %name or rule.api_name == %name;
		end);
	end

	---@param new_rule RuleInitConfig|RuleFn
	---@return Rule
	function rules:make(new_rule)
		local id = ("mk_rule__" .. tostring(GLOBAL_RULES.__tick) .. "_" .. tostring(modkit.table.length(GLOBAL_RULES._entities)));
		if (type(new_rule) == "table" and new_rule.name) then
			id = id .. "__" .. new_rule.name;
		end

		return GLOBAL_RULES:add(id, new_rule);
	end

	---@param rule Rule|string
	---@return nil
	function rules:begin(rule)
		if (type(rule) == "string") then
			---@diagnostic disable-next-line: cast-local-type
			rule = modkit.campaign.rules:get(rule);
			---@cast rule Rule
		end

		rule:begin();
		return rule;
	end

	--- Takes a 'rule pattern', which is lua-style 'and' and 'or' with rule names, firing `event` if the patten is satisfied.
	--- 
	--- If `event` is a rule or a rule definition, that rule will be started. If `event` is just a function, is is simply invoked.
	---
	--- This pattern would trigger `callback` if rules `'A'` AND `'rule_b'` AND `'myC0OlRule'` were finished, OR if rule `'D'` finished:
	--- ```lua
	--- 	'(A and rule_b and myC0OlRule) or D'
	--- ```
	--- Returns a LUA string to execute (we just leverage LUA's inbuilt language parsing).
	---
	---@param pattern string
	---@param event function|RuleInitConfig|Rule
	---@return nil
	function rules:on(pattern, event)
		-- 'A and (B or C)'
		-- -> 'A&(B or C)'
		-- -> 'A&(B|C)'
		local exec = function ()
			local rules = %self;
			pattern_exec = "" .. %pattern;
			-- temporarily replace these keywords with C-style tokens (to protect them from being included by other patterns)
			pattern_exec = gsub(pattern_exec, " and ", " & ");
			pattern_exec = gsub(pattern_exec, " or ", " | ");
			-- here we are constructing a LUA logic expression which will tell us the truthiness of the supplied pattern
			-- if a rule is running, we insert true (1), else false (nil)
			-- (we construct something like: "return 1 and nil and nil or (1 and 1)")
			pattern_exec = gsub(pattern_exec, "([%w_]+)", function(matches)
				local r = %rules:get(matches);
				-- modkit.table.printTbl({
				-- 	r = r or "nil",
				-- 	pattern = %p,
				-- 	pattern_exec = %pattern_exec,
				-- 	matches = matches
				-- }, matches);
				if(r and (r.status == "resolved" or r.status == "rejected")) then
					return "1";
				end
				return "nil";
			end);
			-- now replace the tokens with the lua keywords again
			pattern_exec = gsub(pattern_exec, " & ", " and ");
			pattern_exec = gsub(pattern_exec, " | ", " or ");
			pattern_exec = gsub(pattern_exec, "^%s*(.-)%s*$", "%1");
			pattern_exec = "return " .. pattern_exec;
			return pattern_exec;
		end;

		if (GLOBAL_RULES.__listeners[pattern]) then
			print("overrriding already existing listener for [ " .. pattern .. " ]");
		end

		local callback = event;

		if (type(event) ~= "function" and not event.api_name) then -- no need to convert if already a `Rule`, as they are callable via the tag method
			local as_rule = toRule(event);

			callback = function ()
				%as_rule:begin();
			end
		end

		GLOBAL_RULES.__listeners[pattern] = {
			pattern = pattern,
			exec = exec,
			callback = callback
		};
	end


	--- Parses a table of rule definitions. The rules are registered, then, if they have no `listener_pattern` to wait for, they're fired.
	--- Otherwise the rule is fired when the pattern is satisfied using `rules:on`.
	---@param rules_table table<string, RuleInitConfig>
	function rules:parse(rules_table)
		modkit.table.forEach(rules_table, function (def, name)
			---@cast def RuleInitConfig

			if (type(def) == "function") then
				def = {
					fn = def,
				};
			end

			local r = modkit.campaign.rules:make(def);
			if (def.awaits_rules) then
				modkit.campaign.rules:on(def.awaits_rules, function ()
					%r:begin();
				end);
			end

			if (def.immediate) then
				r:begin();
			end
		end, 1);
	end

	--- Sets `GLOBAL_RULES.__level_path`, and also populates `GLOBAL_MISSION_SHIPS`.
	---
	---@param level_path string
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
			---@cast listener Listener
			-- print(listener.pattern .. ": " .. listener.exec());
			if (dostring(listener.exec())) then
				-- modkit.table.printTbl(listener);
				print(listener.pattern .." passed conditions!");
				listener.callback();
				GLOBAL_RULES.__listeners[listener.pattern] = nil; -- unsubscribe
			end
		end

		GLOBAL_RULES.__tick = GLOBAL_RULES.__tick + 1;


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