-- =====[[ modkit_scheduler ship update, which runs the whole system for modkit.scheduler's api ]]=====

if (not modkit or not modkit.scheduler or not makeStateHandle) then
	dofilepath("data:scripts/modkit/modkit_scheduler.lua");
	dofilepath("data:scripts/modkit/scope_state.lua");
end


---@class MKScheduler: Ship
scheduler = {};

function scheduler:update()

	local running_events = modkit.scheduler:filter(function (event)
		return event.status == EVENT_STATUS.RUNNING;
	end);

	-- if (mod(self:tick(), 20) == 0) then
	-- 	modkit.table.printTbl(modkit.scheduler:all(), "scheduler events");
	-- end


	-- for each running event
	-- 1. set up the core state and merge it with the previous state
	-- 2. run the callback, set 'previous' as the return value
	-- 3. if the callback invoked one of the resolver functions, we update the status of the event
	for _, event in running_events do
		---@cast event Event

		---@type EventCoreState
		local core_state = {
			_tick = event.tick,
			_remaining_iterations = event.remaining_iterations,
			_started_gametime = event.started_gametime
		};

		-- if there is a previous value, we copy it to the core state
		-- in the case of a table, we should do a clone
		if (event.previous_return) then
			local prev = event.previous_return;
			if (type(prev) == "table") then
				core_state._previous = modkit.table.clone(prev);
			else
				core_state._previous = prev;
			end
		end

		--- incoming `state` is overwritten on the core keys
		---@type EventState
		local parsed_state = modkit.table:merge(
			event.state,
			core_state
		);

		-- update prev to the callback return
		local fn_ret = event.fn(_schedulerResolver(event), _schedulerResolver(event), parsed_state);
		event.previous_return = fn_ret;

		local status = event.status; -- if resolver or rejecter were invoked, we'll have that status, otherwise `RUNNING`
		if (status == EVENT_STATUS.RUNNING) then -- do bookkeeping like tick update if running
			event.tick = event.tick + 1;
			if (event.remaining_iterations) then
				event.remaining_iterations = event.remaining_iterations - 1;
			end
		end

		if (event.remaining_iterations == 0) then
			print("event " .. event.name .. " remaining_iterations is 0: " .. event.remaining_iterations);
			event.status = EVENT_STATUS.RESOLVED;
			event.value = event.previous_return;
		end
	end

	--- for each listener
	--- 1. if the listener's awaited events all have the 'pass' statuses ('passed' returns non-nil), fire the listener's event
	--- 2. clear the listener
	for pattern, listener in GLOBAL_SCHEDULE_EVENTS._listeners do
		---@cast listener EventListener
		-- print(listener.pattern .. ": " .. listener.exec());
		if (_schedulerListenerPasses(listener)) then
			-- modkit.table.printTbl(listener);
			print(listener.pattern .." passed conditions!");
			if (listener.options.computeNextChainEventsInitialPreviousValue) then
				listener.event_to_trigger.previous_return = listener.options.computeNextChainEventsInitialPreviousValue();
				print("first previous val for event " .. listener.event_to_trigger.name .. " set as " .. tostring(listener.event_to_trigger.previous_return));
			end
			modkit.scheduler:begin(listener.event_to_trigger);

			GLOBAL_SCHEDULE_EVENTS._listeners[pattern] = nil; -- remove this listener
		end
	end
end

modkit.compose:addShipProto("modkit_scheduler", scheduler);