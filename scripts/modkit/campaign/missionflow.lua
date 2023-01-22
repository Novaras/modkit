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
	---@field main fun(exitFlow: function, state?: any): bool
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
	---@param nodelike NodeLike
	---@param index integer
	nodelikeToString = nodelikeToString or function(nodelike, index)
		if (type(nodelike) == "string") then
			return nodelike;
		end

		---@diagnostic disable-next-line: undefined-field
		return nodelike.id or index;
	end


	---@param mission_flow? NodeLike[]
	local createMissionFlow = function (mission_flow)

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
		FLOW_INDEX = FLOW_INDEX + 1;

		---@param node_id string
		function flow:reviveNode(node_id)
			if (self._nodes[node_id] == nil) then return nil; end

			local node = self._nodes[node_id];
			self._nodes[node_id] = makeFlowNode(node.id, node.action, node.await, node.revives, node.state);
			print("just reset node " .. node_id);
		end

		---comment
		---@param nodes NodeLike[]
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
					action[hook] = action[hook] or function ()
						return 1;
					end;
				end

				return makeFlowNode(id, action, def.await, def.revives, def.state);
			end);

			self._nodes = {};
			for _, node in nodes do
				---@cast node FlowNode

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

			--- probably needs refactor
			--- 
			--- given dependencies, starts the node if possible
			---@param dependencies string[]
			local startOn = function (dependencies)
				local self = %self;
				local node = %node;
				dependencies = dependencies or {};
				local all_deps_finished = modkit.table.all(dependencies, function (dep)
					local dep_node = %self._nodes[dep];
					return dep_node.status == FLOW_NODE_STATUS.exited;
				end);
				print("all deps ready for " .. %node_id .. "?:\t" .. tostring(all_deps_finished));

				if (all_deps_finished) then
					if (node.status == FLOW_NODE_STATUS.running) then
						return nil;
					end

					node.action.init(state_clone);
					node.status = FLOW_NODE_STATUS.running;
				end
			end
			local state_clone = modkit.table.clone(node.state); -- clone for safety

			if (node.status == FLOW_NODE_STATUS.exited) then -- =
				return nil;
			elseif (node.status == FLOW_NODE_STATUS.exiting) then -- exiting calls the exit hook and sets exited
				print("exiting node " .. node.id);
				modkit.table.printTbl(node.revives or {}, "try to revive ");
				node.action.exit(state_clone);
				for _, node_to_revive in node.revives do
					self:reviveNode(node_to_revive);
				end
				modkit.table.printTbl(self._nodes);
				node.status = FLOW_NODE_STATUS.exited;
			elseif (node.status == FLOW_NODE_STATUS.ready) then -- if 'ready', we need to check its deps., if it has no outstanding, then run this node
				startOn(node.await);
			else -- if 'running', we need to execute the 'main' function of the node's action, if it returns non-nil, then we need to begin exiting the node
				print("&& self at declr: " .. tostring(self) .. " (id: " .. self._id .. ")");
				rawset(globals(), "exitCallback", function ()
					print("&& self after? " .. tostring(%self));
					return %self;
				end);
				local exit_code = node.action.main(self.stop, state_clone);
				node.state.tick = node.state.tick + 1;
				if (exit_code) then
					node.status = FLOW_NODE_STATUS.exiting;
					if (exit_code == self) then -- they're exiting the mission itself, (`return exit()`)
						self:stop();
					end
				end
			end

			if (state_clone and type(state_clone) == "table") then
				node.state = modkit.table:merge(
					node.state,
					modkit.table:merge( -- kinda lame you cant pass N tables to merge...
						state_clone,
						-- here we ensure the client code doesn't mess with key values
						{
							tick = node.state.tick,
							node_id = node.state.node_id,
						}
					)
				);
			end
		end

		function flow:start()
			print("===<[[ STARTING FLOW " .. tostring(self._id) .. " ]]>===");
			local keyname = self._global_rule_name;
			print("rule is " .. self._global_rule_name);
			if (Rule_Exists(keyname) ~= 1) then
				local wrapper = function ()
					print("doing nodes on " .. %self._id);
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
			flow:set(mission_flow);
		end

		return flow;
	end

	modkit.campaign.createMissionFlow = createMissionFlow;
	H_CAMPAIGN_MISSION_FLOW = 1;
end
