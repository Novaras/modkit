-- campaign.lua: utils for writing campaign scripts.
-- By: Fear (Novaras)

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (H_CAMPAIGN == nil) then
	local campaign = {};

	if (GLOBAL_RULES == nil) then
		---@class Rule
		---@field fn function
		---@field id string
		---@field interval integer
		---@field status "init"|"running"|"returned"
		---@field api_name string
		---@field value any|nil
		---@field fn_state table

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
				fn_state = modkit.table:merge(
					{
						_rule_name = id
					},
					state
				)
			};

			function rule:finish()
				Rule_Remove(self.api_name);
				self.status = "returned";
			end

			function rule:run()
				local result = self.fn(self.fn_state);
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

	local rules = {
		min_poll_interval = 0.1,
	};

	---@param name string
	---@return Rule
	function rules:get(name)
		return GLOBAL_RULES:get(name);
	end

	---@param name string
	---@param rule_fn function
	---@param interval integer
	---@return Rule
	function rules:make(name, rule_fn, interval, state)
		interval = interval or self.min_poll_interval;
		local already_exists = GLOBAL_RULES:find(function (rule)
			return rule.name == %name;
		end);
		if (already_exists) then
			print("overrriding already existing rule: " .. name);
		end

		return GLOBAL_RULES:add(name, rule_fn, interval, state);
	end

	---@param rule Rule
	---@return nil
	function rules:begin(rule)
		rule:begin();
	end

	function rules:on(pattern, callback)
		-- 'A and (B or C)'
		-- -> 'A&(B or C)'
		-- -> 'A&(B|C)'

		local exec = function ()
			local rules = %self;
			pattern_exec = "" .. %pattern;
			pattern_exec = gsub(pattern_exec, " and ", " & ");
			pattern_exec = gsub(pattern_exec, " or ", " | ");
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

		if (MISSION_SHIPS == nil) then
			RegisterShips(level_path);
			print("INIT MISSION SOBGROUPS");
		end
	end

	function modkit_campaign_driver()
		for _, listener in GLOBAL_RULES.__listeners do
			print("listening for " .. listener.pattern .. "(" .. listener.exec() .. ")...");
			if (dostring(listener.exec())) then
				print("\tpassed conditions!");
				listener.callback(modkit.table.map(GLOBAL_RULES._entities, function (rule)
					return {
						id = rule.id,
						status = rule.status,
						value = rule.value,
						state = rule.state
					};
				end));
				GLOBAL_RULES.__listeners[listener.pattern] = nil; -- unsubscribe
			end
		end
	end

	if (OnInit == nil) then
		OnInit = function ()
			Rule_AddInterval("modkit_campaign_driver", %rules.min_poll_interval);
		end;
	end

	campaign.rules = rules;
	modkit.campaign = campaign;

	H_CAMPAIGN = 1;
end