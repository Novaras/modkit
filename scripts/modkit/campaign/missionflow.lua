if (H_CAMPAIGN_MISSION_FLOW == nil) then
	-- aggressive load
	if (modkit == nil) then
		modkit = {};
	end

	NOOP = NOOP or function() end;

	FLOW_INDEX = 0;

	LIFETIME_HOOK_KEYS = {
		init = 'init',
		main = 'main',
		exit = 'exit'
	};
	---@alias LifetimeHook 'init'|'main'|'exit'

	FLOW_STATUS = {
		ready = 'ready',
		running = 'running',
		exited = 'exited'
	};
	---@alias FlowStatus 'ready'|'running'|'exited'

	FLOW_NODE_STATUS = {
		ready = 'ready',
		running = 'running',
		exiting = 'exiting',
		exited = 'exited'
	};
	---@alias FlowNodeStatus FlowStatus|'exiting'

	---@class Action
	---@field init fun(state?: any)
	---@field main fun(exitCallback: function, state?: any): bool
	---@field exit fun(state?: any)

	---@class FlowNode
	---@field id string
	---@field action Action
	---@field await? string[]
	---@field revives? string[]
	---@field status FlowNodeStatus
	---@field state table

	---@alias NodeLike (Action|FlowNode)

	--- Convert a nodelike to its string id
	---
	---@param nodelike NodeLike
	---@param index integer
	nodelikeToString = nodelikeToString or function(nodelike, index)
		if (type(nodelike) == "string") then
			return nodelike;
		end

		---@diagnostic disable-next-line: undefined-field
		return nodelike.id or index;
	end

	--- Creates an `Action` if given a partial definition.
	---
	---@param config table|Action
	---@return Action
	parseToAction = parseToAction or function (config)
		config = config or {};

		flow_action = modkit.table.clone(config); -- make sure its a clone instead of the original table (subreferences notwithstanding)

		-- set up the lifetime hooks i.e 'init', 'main', 'exit'
		for key, _ in LIFETIME_HOOK_KEYS do
			flow_action[key] = config[key] or function (exitCallback)
				print("(no hook set for '" .. %key .. "' on action " .. tostring(%id));
				if (%key == "main") then
					exitCallback();
				end
			end
		end

		return flow_action;
	end

	--- Creates a `FlowNode`.
	---
	---@param id string
	---@param action Action
	---@param await? (string|NodeLike)[]
	---@param revives? (string|NodeLike)[]
	---@param state? any[]
	---@return FlowNode
	makeFlowNode = makeFlowNode or function (id, action, await, revives, state)
		
		await = modkit.table.map(await or {}, nodelikeToString);
		---@cast await string[]

		revives = modkit.table.map(revives or {}, nodelikeToString);
		---@cast revives string[]

		---@type FlowNode
		local node = {
			id = id,
			action = action,
			status = FLOW_NODE_STATUS.ready,
			await = await,
			revives = revives,
			state = modkit.table:merge(
				state or {},
				{
					tick = 0,
					node_id = id,
				}
			),
		};

		return node;
	end

	---@param mission_flow? NodeLike[]
	local createMissionFlow = function (mission_flow)

		---@class MissionFlow
		---@field _nodes FlowNode[]
		---@field _status FlowStatus
		---@field _global_rule_name string
		local flow = {
			_nodes = {},
			_status = FLOW_STATUS.ready,
			_global_rule_name = '__MK_MISSION_FLOW' .. "-" .. FLOW_INDEX,
			_id = FLOW_INDEX
		};

		--- 'Revives' the given node, which re-creates the node and sets its status to `ready`.
		---
		---@param node string|FlowNode
		function flow:reviveNode(node)
			local node = self:get(node);
			if (node == nil) then return nil; end

			self._nodes[node.id] = makeFlowNode(node.id, node.action, node.await, node.revives, node.state);
			print("just reset node " .. node.id);
		end

		--- Sets the nodes for this flow. `Action`s or other partial definitions are parsed into full `FlowNode`s.
		---
		--- The node IDs are given as the definitions `id` field or whatever table key they were set to:
		---
		--- ```lua
		--- flow:setAll({ a1 = {} }); -- node id will be 'a1'
		--- flow:setAll( a1 = { id = "foo" }); -- node id will be 'foo'
		--- ```
		---
		---@param definitions table Should be a table of partial _or_ full `Action`s or `FlowNode`s
		function flow:setAll(definitions)
			definitions = modkit.table.map(definitions, function (def, idx)
				local id = def.id or tostring(idx);
				local action = {};
				if (def.main) then -- if def has main, it's an `Action`
					action = def;
				else -- otherwise, try to find the action (if its a `FlowNode`), or default to `{}`
					action = def.action or {};
				end

				-- ensure action definition is constructed correctly
				action = parseToAction(action);

				return makeFlowNode(id, action, def.await, def.revives, def.state);
			end);

			self._nodes = {};
			for _, node in definitions do
				---@cast node FlowNode

				self._nodes[node.id] = node;
			end
		end

		---@param node string|FlowNode
		---@return FlowNode?
		function flow:get(node)
			if (type(node) == "string") then
				return self._nodes[node];
			end

			return modkit.table.find(self._nodes, function (other_node)
				return other_node.id == %node.id;
			end);
		end

		--- Sets the node for `id`.
		---
		---@param id string
		---@param node FlowNode
		function flow:set(id, node)
			self._nodes[id] = node;
		end

		--- Returns a _**clone**_ of the `_nodes` member table, optionally filtered.
		---
		--- The filter can be a custom predicate; in the case it is a `string`, this string is assumed to be
		--- the status of the node (as a `FlowNodeStatus` match), and they will be filted by matching status.
		---
		---@param filter? FlowNodeStatus|fun(node: FlowNode): bool
		---@return FlowNode[]
		function flow:nodes(filter)
			if (filter == nil) then
				return modkit.table.clone(self._nodes);
			end

			if (type(filter) == 'string') then
				filter = function (node)
					return node.status == %filter;
				end
			end

			if (type(filter) ~= 'function') then
				print("bad argument to flow:nodes: 'filter' expected to be of type string or function, got " .. type(filter) .. ", val is " .. tostring(filter));
			end

			return modkit.table.filter(self:nodes(), filter);
		end

		--- Causes the given node to be started, if its `await` dependencies are cleared, and its status is:
		--- - `ready`, meaning the node has not been run yet (or was revived)
		--- - `exited`, meaning the node has stopped running and also moved out of its `exiting` phase
		---
		---@param node string|FlowNode
		---@param force? bool
		function flow:startNode(node, force)
			local node = self:get(node);

			if (node == nil) then return nil; end

			local correct_status = node.status == FLOW_NODE_STATUS.ready or node.status == FLOW_NODE_STATUS.exited;
			if (correct_status == nil and force == nil) then
				return nil;
			end

			---@type fun(): bool
			local checkDepsFinished = function () -- as a fn so we can defer calculating this in case `force` is set
				local self = %self;
				return modkit.table.all(%node.await, function (await_dep)
					local dep_node = %self._nodes[await_dep];
					return dep_node.status == FLOW_NODE_STATUS.exited;
				end);
			end

			print("all deps ready for " .. node.id .. "?:\t" .. tostring(checkDepsFinished()));
			print("force go?: " .. tostring(force));

			if (force or checkDepsFinished()) then
				local log = "STARTING FLOW NODE: <c=0099ff>" .. node.id .. "</c>";
				-- Subtitle_Message(log, 3);
				consoleLog(log);

				node.action.init(state_clone);
				node.status = FLOW_NODE_STATUS.running;
			end
		end

		--- Causes the given node to complete exit if its status is:
		--- - `running`, meaning its still executing its `main` action hook
		--- - `exiting`, meaning its `main` action hook returned non-nil and is awaiting cleanup
		---
		---@param node string|FlowNode
		---@param force? bool
		function flow:finishNode(node, force)
			local node = self:get(node);

			if (node == nil) then return nil; end

			local correct_status = node.status == FLOW_NODE_STATUS.running or node.status == FLOW_NODE_STATUS.exiting;
			if (correct_status == nil and force == nil) then
				return nil;
			end

			local state_clone = modkit.table.clone(node.state); -- clone for safety

			local log = "FINISH FLOW NODE: <c=0099ff>" .. node.id .. "</c>";
			-- Subtitle_Message(log, 3);
			consoleLog(log);
			modkit.table.printTbl(node.revives or {}, "try to revive ");

			node.action.exit(state_clone);
			for _, node_to_revive in node.revives do
				self:reviveNode(node_to_revive);
			end
			-- modkit.table.printTbl(self._nodes);
			node.status = FLOW_NODE_STATUS.exited;
		end

		--- Process the given node, based on it's status.
		--- - `ready` nodes are started according to `startNode`
		--- - `running` nodes have their action's `main` hook called and their tick is incremented
		--- - `exiting` nodes are exited according to `exitNode`
		--- - `exited` nodes do nothing
		---
		---@param node string|FlowNode
		function flow:doNode(node)
			local node = self:get(node);
			if (node == nil) then return nil; end

			---@type table<FlowNodeStatus, function>
			local lookup = {
				[FLOW_NODE_STATUS.ready] = function ()
					%self:startNode(%node);
				end,
				[FLOW_NODE_STATUS.running] = function ()
					local self = %self;
					local node = %node;
					local state_clone = modkit.table.clone(node.state); -- clone for safety

					local exitCallback = function ()
						%self:stop();
					end
					local exit_code = node.action.main(exitCallback, state_clone);
					node.state.tick = node.state.tick + 1;

					if (exit_code) then
						node.status = FLOW_NODE_STATUS.exiting;
					end
				end,
				[FLOW_NODE_STATUS.exiting] = function ()
					%self:finishNode(%node);
				end,
				[FLOW_NODE_STATUS.exited] = function ()
					return nil;
				end
			};

			-- execute the status callback
			lookup[node.status]();

			-- here we ensure the client code doesn't mess with key values `tick` or `node_id`
			node.state = modkit.table:merge(
				node.state,
				{
					tick = node.state.tick,
					node_id = node.state.node_id,
				}
			);
		end

		function flow:start()
			print("===<[[ STARTING FLOW " .. tostring(self._id) .. " ]]>===");
			local keyname = self._global_rule_name;
			print("rule is " .. self._global_rule_name);
			if (Rule_Exists(keyname) ~= 1) then
				local wrapper = function ()
					-- print("doing nodes on " .. %self._id);
					-- modkit.table.printTbl(modkit.table.map(%self:nodes(), function (node)
					-- 	return node.status;
					-- end), "nodes");

					for id, _ in %self:nodes() do
						%self:doNode(id);
					end
				end;
				rawset(globals(), keyname, wrapper);
				Rule_AddInterval(keyname, 1);
			end

			if (Rule_Exists("syncGlobalShips") ~= 1) then
				dofilepath("data:scripts/modkit/sp_helpers.lua");
				Rule_AddInterval("syncGlobalShips", 2);
			end
			self._status = FLOW_STATUS.running;
		end

		function flow:stop()
			print("stopping flow " .. tostring(self));
			print("exiting rule " .. self._global_rule_name);
			Rule_Remove(self._global_rule_name);
			self._status = FLOW_STATUS.exited;
		end

		if (mission_flow) then
			flow:setAll(mission_flow);
		end

		FLOW_INDEX = FLOW_INDEX + 1; -- each flow wants a unique id, so we need to incr. for the next guy

		return flow;
	end

	modkit.campaign.createMissionFlow = createMissionFlow;
	H_CAMPAIGN_MISSION_FLOW = 1;
end
