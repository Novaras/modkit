if (H_CAMPAIGN_MISSION_FLOW == nil) then
	-- aggressive load
	if (modkit == nil) then
		modkit = {};
	end

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
	---@field init fun()
	---@field main fun(): bool
	---@field exit fun()

	---@class FlowNode
	---@field action Action
	---@field dependencies? FlowNode[]
	---@field status FlowNodeStatus


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
		---@param dependencies? FlowNode[]
		---@return FlowNode
		makeFlowNode = makeFlowNode or function (id, action, dependencies)
			local node = {
				id = id,
				action = action,
				status = FLOW_NODE_STATUS.ready,
				dependencies = dependencies,
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
		function flow:register(id, action, dependencies)
			if (dependencies == nil) then dependencies = {}; end
			dependencies = modkit.table.map(dependencies, function (str_or_flow_action)
				if (type(str_or_flow_action) == 'string') then
					return %self:get(str_or_flow_action);
				end
				return str_or_flow_action;
			end);

			self._nodes[id] = makeFlowNode(id, action, dependencies);

			return self._nodes[id];
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

			if (node.status == FLOW_NODE_STATUS.exited) then -- return early for exited nodes
				return nil;
			elseif (node.status == FLOW_NODE_STATUS.ready) then -- if 'ready', we need to check its deps., if it has no outstanding, then run this node
				local all_deps_finished = node.dependencies == nil or modkit.table.all(node.dependencies, function (dep)
					return dep.status == FLOW_NODE_STATUS.exited;
				end);
				print("all deps ready for " .. node_id .. "?:\t" .. tostring(all_deps_finished));

				if (node.dependencies == nil or all_deps_finished) then
					if (node.status == FLOW_NODE_STATUS.running) then
						return nil;
					end

					node.action.init();
					node.status = FLOW_NODE_STATUS.running;
				end
			else -- if 'running', we need to execute the 'main' function of the node's action, if it returns non-nil, then we need to exit the node
				local exit_code = node.action.main();
				if (exit_code) then
					node.status = 'exited';
				end
			end
		end

		return flow;
	end

	modkit.campaign.createMissionFlow = createMissionFlow;
	H_CAMPAIGN_MISSION_FLOW = 1;
end
