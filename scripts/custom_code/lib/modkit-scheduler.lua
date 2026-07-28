-- =====[[ modkit_scheduler ship update, which runs the whole system for modkit.scheduler's api ]]=====

if (not modkit or not modkit.scheduler or not hyperTableHandle) then
	dofilepath("data:scripts/modkit/modkit_scheduler.lua");
	dofilepath("data:scripts/modkit/hypertable.lua");
end


---@class MKScheduler: Ship
scheduler = {};

function scheduler:pruneOthers()
	for _, ship in GLOBAL_SHIPS:all() do
		---@cast ship Ship
		if (ship.ship_type == "modkit_scheduler" and ship.id > self.id) then
			ship:die();
		end
	end
end

function scheduler:update()
	-- print("scheduler tick " .. self:tick());
	if (self:tick() == 1) then
		GLOBAL_SCHEDULE_EVENTS._entities = {};
		GLOBAL_SCHEDULE_EVENTS._listeners = {};

		self:spawn(0);
	end

	if (mod(self:tick(), 10)) then
		self:pruneOthers();
	end

	local running_events = modkit.scheduler:filter(function (event)
		---@cast event Event
		-- print("ev " .. event.name .. " interval = " .. event.interval .. ", mod(tick, interval) = " .. mod(%self:tick(), event.interval));
		return event.status == EVENT_STATUS.RUNNING and mod(%self:tick(), event.interval) == 0;
	end);


	-- for each running event
	-- 1. set up the core state and merge it with the previous state
	-- 2. run the callback, set 'previous' as the return value
	-- 3. if the callback invoked one of the resolver functions, we update the status of the event
	for _, event in running_events do
		---@cast event Event

		-- update prev to the callback return
		local fn_ret = event.fn(_schedulerResolver(event), _schedulerRejecter(event), event.state);
		event.state._value = fn_ret;

		local status = event.status; -- if resolver or rejecter were invoked, we'll have that status, otherwise `RUNNING`
		if (status == EVENT_STATUS.RUNNING) then -- do bookkeeping like tick update if running
			event.state._tick = event.state._tick + 1;
			if (event.remaining_iterations) then
				event.remaining_iterations = event.remaining_iterations - 1;
			end
		end

		if (event.remaining_iterations == 0) then
			-- print("event " .. event.name .. " remaining_iterations is 0: " .. event.remaining_iterations);
			event.status = EVENT_STATUS.RESOLVED;
			event.result = event.state._value;
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
			-- print(listener.pattern .." passed conditions!");
			local previous_result = nil;
			if (listener.options.computePreviousResolve) then
				previous_result = listener.options.computePreviousResolve();
			end
			-- print("previous result for event " .. listener.event_to_trigger.name .. " set as " .. tostring(previous_result));
			listener.event_to_trigger.state._previous_result = previous_result;
			modkit.scheduler:begin(listener.event_to_trigger);

			GLOBAL_SCHEDULE_EVENTS._listeners[pattern] = nil; -- remove this listener
		end
	end
end

modkit.compose:addShipProto("modkit_scheduler", scheduler);