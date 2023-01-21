if (H_CAMPAIGN_MISSION_FLOW == nil) then
	-- aggressive load
	if (modkit == nil) then
		modkit = {};
	end

	NOOP = NOOP or function() end;

	LIFETIME_HOOK_KEYS = {
		init = 'init',
		main = 'main',
		exit = 'exit'
	};
	---@alias LifetimeHook 'init'|'main'|'exit'

	FLOW_NODE_STATUS = {
		ready = 'ready',
		running = 'running',
		exited = 'exited'
	};
	---@alias FlowNodeStatus 'ready'|'running'|'exited'

	---@class Action
	---@field init fun(state?: any)
	---@field main fun(state?: any): bool
	---@field exit fun(state?: any)

	---@class MissionNode
	---@field action Action
	---@field dependencies? string[]

	---@class FlowNode : MissionNode
	---@field status FlowNodeStatus
	---@field state table


	local createMissionFlow = function ()

		---comment
		---@param config table|Action
		---@return Action
		parseToAction = parseToAction or function (config)
			config = config or {};

			flow_action = modkit.table.clone(config); -- make sure its a clone instead of the original table (subreferences notwithstanding)

			-- set up the lifetime hooks i.e 'init', 'main', 'exit'
			for key, _ in LIFETIME_HOOK_KEYS do
				flow_action[key] = config[key] or function ()
					print("(no hook set for '" .. %key .. "' on action " .. tostring(%id));
				end
			end

			return flow_action;
		end

		---comment
		---@param id string
		---@param action Action
		---@param dependencies? string[]
		---@param state? any[]
		---@return FlowNode
		makeFlowNode = makeFlowNode or function (id, action, dependencies, state)
			local node = {
				id = id,
				action = action,
				status = FLOW_NODE_STATUS.ready,
				dependencies = dependencies,
				state = modkit.table:merge(
					state or {},
					{
						tick = 0,
					}
				),
			};

			return node;
		end

		---@class MissionFlow
		---@field _nodes FlowNode[]
		local flow = {
			_nodes = {}
		};

		--- Register an action into the flow. Actions are fired when all their dependencies are cleared.
		---
		---@param id string The unique ID (name) of the action.
		---@param action Action
		---@param dependencies? string[] IDs of other FlowNodes
		---@return FlowNode
		function flow:add(id, action, dependencies)
			if (dependencies == nil) then dependencies = {}; end

			self._nodes[id] = makeFlowNode(id, action, dependencies);

			return self._nodes[id];
		end

		---comment
		---@param nodes (Action|MissionNode|FlowNode)[]
		function flow:set(nodes)
			nodes = modkit.table.map(nodes, function (def, idx)
				local id = def.id or tostring(idx);
				local action = {};
				if (def.main) then
					action = def;
				else
					action = def.action or {};
				end

				for _, hook in LIFETIME_HOOK_KEYS do
					action[hook] = action[hook] or NOOP;
				end

				return makeFlowNode(id, action, def.dependencies, def.state);
			end);

			self._nodes = {};
			for _, node in nodes do
				self._nodes[node.id] = node;
			end
		end

		---@param id string
		---@return FlowNode
		function flow:get(id)
			return self._nodes[id];
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


		function flow:doNode(node_id)
			local node = self._nodes[node_id];

			local state_clone = modkit.table.clone(node.state); -- clone for safety

			if (node.status == FLOW_NODE_STATUS.exited) then -- return early for exited nodes
				node.action.exit(state_clone);
				return nil;
			elseif (node.status == FLOW_NODE_STATUS.ready) then -- if 'ready', we need to check its deps., if it has no outstanding, then run this node
				local all_deps_finished = node.dependencies == nil or modkit.table.all(node.dependencies, function (dep)
					local dep_node = %self._nodes[dep];
					return dep_node.status == FLOW_NODE_STATUS.exited;
				end);
				print("all deps ready for " .. node_id .. "?:\t" .. tostring(all_deps_finished));

				if (node.dependencies == nil or all_deps_finished) then
					if (node.status == FLOW_NODE_STATUS.running) then
						return nil;
					end

					node.action.init(state_clone);
					node.status = FLOW_NODE_STATUS.running;
				end
			else -- if 'running', we need to execute the 'main' function of the node's action, if it returns non-nil, then we need to exit the node
				local exit_code = node.action.main(state_clone);
				node.state.tick = node.state.tick + 1;
				if (exit_code) then
					node.status = 'exited';
				end
			end

			if (state_clone and type(state_clone) == "table") then
				node.state = modkit.table:merge(
					node.state,
					modkit.table:merge( -- kinda lame you cant pass N tables to merge...
						state_clone,
						-- here we ensure the client code doesn't time travel by overwriting with increment from last known
						{
							tick = node.state.tick
						}
					)
				);
			end
		end

		return flow;
	end

	modkit.campaign.createMissionFlow = createMissionFlow;
	H_CAMPAIGN_MISSION_FLOW = 1;
end
