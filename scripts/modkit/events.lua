-- events.lua: promise-like events, which run a callback repeatedly until it resolves or rejects, and can be chained or listened for.
-- By: Fear (Novaras)
--
-- One API for every scope. Each scope keeps its own events (functions can't cross scopes), and something in that scope has to call
-- `modkit.events:tick()` to run them:
-- - in the rules scope (`Rule_AddInterval` exists), the `modkit_events_driver` rule, started automatically by the first `begin`
-- - in the ship custom code scope, the `modkit_scheduler` ship's `update` (see `custom_code/lib/modkit-scheduler.lua`)

if (modkit == nil) then modkit = {}; end
if (modkit.table == nil) then dofilepath("data:scripts/modkit/table_util.lua"); end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

---@enum EventStatus
EVENT_STATUS = {
	INIT = "init",
	RUNNING = "running",
	RESOLVED = "resolved",
	REJECTED = "rejected"
};

---@class EventState: table
---@field _tick integer How many times the callback has already run (`0` during the first run)
---@field _started_gametime number Game time when the event began
---@field _value? any The callback's return value from its previous run
---@field _previous_result? any The result of the event before this one in a chain (or passed to `begin`)
---@field _remaining_iterations? integer Runs left before the event resolves by itself, if it was made with `iterations`
---@field _event Event The event itself

---@alias EventResolve fun(result?: any): nil
---@alias EventReject fun(message?: string): nil
---@alias EventFn fun(resolve: EventResolve, reject: EventReject, state: EventState): any

---@class EventConfig
---@field fn EventFn Called every `interval` seconds until it calls `resolve` or `reject`
---@field name? string Must be unique among events that exist at the same time; defaults to `"event_<id>"`
---@field interval? number Seconds between runs; defaults to `modkit.events.default_interval`
---@field iterations? integer If set, the event resolves with the callback's last return value after this many runs
---@field state? table Initial state, passed to the callback (alongside the `_` fields of `EventState`)
---@field awaits? string For `parse`: a listener pattern, so the event begins when it passes
---@field immediate? bool For `parse`: begin the event straight away

---@class Event
---@overload fun(previous_result?: any): EventChain
---@field id integer
---@field name string
---@field fn EventFn
---@field interval number
---@field iterations? integer
---@field state EventState
---@field status EventStatus
---@field result? any The value passed to `resolve`
---@field error? string The message passed to `reject`
---@field _next_run number Game time of the next run
---@field __is_event 1
--- Begins (or restarts) this event; it first runs on the next tick. Returns a chain, for `:next` and `:catch`.
---
--- `previous_result` is available to the callback as `state._previous_result`.
---@field begin fun(self: Event, previous_result?: any): EventChain
--- Pauses this event (it can be begun again later).
---@field stop fun(self: Event)
--- Ends this event as resolved (with `value` as its result) or rejected (with `value` as its error message).
---@field finish fun(self: Event, status: EventStatus, value?: any)

---@class EventChain
---@field event Event The event this chain continues from
--- Begins `next_event` when this chain's event resolves, with its result as `state._previous_result`.
--- If this chain's event rejects, `next_event` is rejected with the same error instead (so it reaches the chain's `:catch`).
---@field next fun(self: EventChain, next_event: EventLike): EventChain
--- Calls `handler` with the error message (and the event) if this chain's event rejects, including rejections passed
--- along the chain from earlier events.
---@field catch fun(self: EventChain, handler: fun(message: string, event: Event)): EventChain

---@alias EventLike Event|EventConfig|EventFn|string

---@class EventListenerOptions
---@field pass_statuses? EventStatus[] Statuses which count as 'finished' for the pattern; defaults to resolved and rejected
---@field computePreviousResolve? fun(): any Produces the `_previous_result` for a target event (otherwise it's the result of the pattern's event, if the pattern names just one)

---@class EventListener
---@field pattern string
---@field names string[] The event names in `pattern`
---@field target Event|function
---@field options EventListenerOptions

if (modkit.events == nil) then
	---@class EventStore: MemGroupInst
	---@field _entities Event[]
	---@field _ids_by_name table<string, integer>
	---@field _listeners EventListener[]
	---@field _next_id integer
	---@field _driver_started? bool
	local store = modkit.MemGroup.Create("mg-events", {
		_ids_by_name = {},
		_listeners = {},
		_next_id = 0,
	});

	--- API for making and running `Event`s: callbacks which run every `interval` seconds until they resolve or reject.
	---
	--- ```lua
	--- local events = modkit.events;
	---
	--- events:make(function (resolve, reject, state)
	--- 	if (state._tick == 5) then
	--- 		resolve("done");
	--- 	end
	--- end)()
	--- 	:next(function (resolve, reject, state)
	--- 		print(state._previous_result); -- "done"
	--- 		resolve();
	--- 	end)
	--- 	:catch(function (message) print("error: " .. message); end);
	--- ```
	---
	---@class Events
	local events = {
		--- Seconds between an event's runs, unless it's made with an `interval`.
		default_interval = 0.5,
		--- Seconds between the rules scope driver's ticks (also the shortest interval an event can have there).
		rules_driver_interval = 0.1,
		_store = store,
	};

	-- one tag shared by every event (Lua 4 tags are never freed), letting an event be begun by calling it: `my_event()`
	events._event_tag = newtag();
	settagmethod(events._event_tag, "function", function (event, previous_result)
		return event:begin(previous_result);
	end);

	-- words in a listener pattern which aren't event names
	events._listener_keywords = { ["and"] = 1, ["or"] = 1, ["not"] = 1 };

	-- ===[ Lookup ]===

	--- Returns whether `value` is an `Event`.
	---
	---@param value any
	---@return bool
	function events:isEvent(value)
		return type(value) == "table" and value.__is_event;
	end

	--- Returns the event with the given id or name, if it exists.
	---
	---@param id_or_name integer|string
	---@return Event|nil
	function events:get(id_or_name)
		if (type(id_or_name) == "string") then
			local id = %store._ids_by_name[id_or_name];
			if (id == nil) then
				return nil;
			end
			id_or_name = id;
		end
		return %store:get(id_or_name);
	end

	---@return Event[]
	function events:all()
		return %store:all();
	end

	---@param predicate fun(event: Event): bool
	---@return Event|nil
	function events:find(predicate)
		return %store:find(predicate);
	end

	---@param predicate fun(event: Event): bool
	---@return Event[]
	function events:filter(predicate)
		return %store:filter(predicate);
	end

	--- Returns `value` as an `Event`: events are returned as-is, names are looked up, and callbacks or configs are made into new events.
	---
	--- (An unknown name prints a warning and returns `nil`.)
	---
	---@param value EventLike
	---@return Event
	function events:toEvent(value)
		if (type(value) == "string") then
			local event = modkit.events:get(value);
			if (event == nil) then
				print("[modkit.events] no event named '" .. value .. "'");
			end
			---@cast event -nil
			return event;
		end
		if (modkit.events:isEvent(value)) then
			---@cast value Event
			return value;
		end
		---@cast value EventConfig|EventFn
		return modkit.events:make(value);
	end

	-- ===[ Events ]===

	---@param event Event
	---@return EventResolve
	local makeResolver = function (event)
		return function (result)
			%event:finish(EVENT_STATUS.RESOLVED, result);
		end
	end

	---@param event Event
	---@return EventReject
	local makeRejecter = function (event)
		return function (message)
			%event:finish(EVENT_STATUS.REJECTED, message);
		end
	end

	--- Makes a new event, which doesn't run until it's begun (`my_event:begin()`, or just `my_event()`).
	---
	---@param config EventConfig|EventFn
	---@return Event
	function events:make(config)
		if (type(config) == "function") then
			config = { fn = config };
		end

		%store._next_id = %store._next_id + 1;
		local id = %store._next_id;

		local event = {
			__is_event = 1,
			id = id,
			name = config.name or ("event_" .. id),
			fn = config.fn,
			interval = config.interval or modkit.events.default_interval,
			iterations = config.iterations,
			state = config.state or {},
			status = EVENT_STATUS.INIT,
		};
		---@cast event Event

		-- (methods documented on the `Event` class)

		function event:begin(previous_result)
			return modkit.events:begin(self, previous_result);
		end

		function event:stop()
			self.status = EVENT_STATUS.INIT;
		end

		function event:finish(status, value)
			self.status = status;
			if (status == EVENT_STATUS.REJECTED) then
				self.error = "[" .. self.name .. "]: " .. tostring(value or "rejected");
			else
				self.result = value;
			end
		end

		settag(event, modkit.events._event_tag);

		if (%store._ids_by_name[event.name]) then
			print("[modkit.events] warning: event name '" .. event.name .. "' is already in use; listeners will now find the new one");
		end
		%store._ids_by_name[event.name] = id;

		return %store:set(id, event);
	end

	--- Begins (or restarts) `event`, making it first if it's a callback or config. Returns a chain, for `:next` and `:catch`.
	---
	---@param event EventLike
	---@param previous_result? any Available to the callback as `state._previous_result`
	---@return EventChain
	function events:begin(event, previous_result)
		event = modkit.events:toEvent(event);

		if (event.status ~= EVENT_STATUS.RUNNING) then
			local state = event.state;
			state._tick = 0;
			state._started_gametime = Universe_GameTime();
			state._value = nil;
			state._previous_result = previous_result;
			state._remaining_iterations = event.iterations;
			state._event = event;

			event.result = nil;
			event.error = nil;
			event._next_run = state._started_gametime;
			event.status = EVENT_STATUS.RUNNING;

			-- finished events are cleaned up, so restarting one has to put it back
			%store:set(event.id, event);
			%store._ids_by_name[event.name] = event.id;
		end

		modkit.events:startDriver();

		return modkit.events:chain(event);
	end

	--- In the rules scope, starts the `modkit_events_driver` rule which runs events, unless it's already started.
	--- `begin` calls this, so there's normally no need to.
	function events:startDriver()
		if (Rule_AddInterval and not %store._driver_started) then
			Rule_AddInterval("modkit_events_driver", modkit.events.rules_driver_interval);
			%store._driver_started = 1;
		end
	end

	--- Removes `event` from the store, leaving it as it is.
	---
	---@param event Event
	local forget = function (event)
		%store:delete(event.id);
		if (%store._ids_by_name[event.name] == event.id) then
			%store._ids_by_name[event.name] = nil;
		end
	end

	--- Stops and removes `event`.
	---
	---@param event Event|integer|string
	function events:remove(event)
		---@type Event|nil
		local found = nil;
		if (type(event) == "table") then
			found = event;
		else
			---@cast event string|integer
			found = modkit.events:get(event);
		end
		if (found) then
			found:stop();
			%forget(found);
		end
	end

	--- Makes and begins an event for each entry of `definitions`, named after its key (unless it has a `name`), so the
	--- entries can await each other. Entries with `awaits` (a listener pattern) begin when it passes; the rest begin straight away.
	---
	---@param definitions table<any, EventConfig|EventFn>
	---@return table<any, Event> # the events, under the same keys
	function events:parse(definitions)
		local made = {};
		for key, definition in definitions do
			local config = {};
			if (type(definition) == "function") then
				config.fn = definition;
			else
				for field, value in definition do
					config[field] = value;
				end
			end
			if (config.name == nil and type(key) == "string") then
				config.name = key;
			end
			definition = config;
			made[key] = modkit.events:make(definition);
			if (definition.awaits) then
				modkit.events:on(definition.awaits, made[key]);
			else
				made[key]:begin();
			end
		end
		return made;
	end

	-- ===[ Chains ]===

	--- Returns a chain for `event`, so `:next` and `:catch` can be attached to it.
	---
	---@param event Event
	---@return EventChain
	function events:chain(event)
		local chain = { event = event };
		---@cast chain EventChain

		-- (methods documented on the `EventChain` class)

		function chain:next(next_event)
			next_event = modkit.events:toEvent(next_event);

			---@param awaited Event
			modkit.events:on(self.event, function (awaited)
				if (awaited.status == EVENT_STATUS.REJECTED) then
					%next_event.status = EVENT_STATUS.REJECTED;
					%next_event.error = awaited.error;
				else
					%next_event:begin(awaited.result);
				end
			end);

			return modkit.events:chain(next_event);
		end

		function chain:catch(handler)
			---@param awaited Event
			modkit.events:on(self.event, function (awaited)
				if (awaited.status == EVENT_STATUS.REJECTED) then
					%handler(awaited.error, awaited);
				end
			end);

			return self;
		end

		return chain;
	end

	-- ===[ Listeners ]===

	--- Calls or begins `target` once `pattern` passes. `pattern` is an event (or its name), or event names combined with `and`, `or`,
	--- `not` and brackets, where a name counts as true once its event has finished (resolved or rejected, see `options.pass_statuses`):
	---
	--- ```lua
	--- -- when A, rule_b and my-event have all finished, or D has:
	--- modkit.events:on("(A and rule_b and my-event) or D", function (a, b, my_event, d)
	--- 	-- the named events (or `nil`, for any which don't exist), in the order they appear in the pattern
	--- end);
	---
	--- modkit.events:on(event_a, event_b); -- begin event_b when event_a finishes (with event_a's result)
	--- ```
	---
	--- Plain functions are called with the pattern's events; anything else is made into an event (if needed) and begun.
	---
	---@param pattern string|Event
	---@param target EventLike|fun(...: Event)
	---@param options? EventListenerOptions
	---@return EventListener
	function events:on(pattern, target, options)
		if (modkit.events:isEvent(pattern)) then
			pattern = pattern.name;
		end
		---@cast pattern string

		options = options or {};
		if (options.pass_statuses == nil) then
			options.pass_statuses = { EVENT_STATUS.RESOLVED, EVENT_STATUS.REJECTED };
		end

		if (type(target) ~= "function") then
			target = modkit.events:toEvent(target);
		end

		local names = {};
		gsub(pattern, "([^%s%(%)]+)", function (name)
			if (modkit.events._listener_keywords[name] == nil) then
				%names[getn(%names) + 1] = name;
			end
		end);

		local listener = {
			pattern = pattern,
			names = names,
			target = target,
			options = options,
		};
		%store._listeners[getn(%store._listeners) + 1] = listener;

		return listener;
	end

	--- Removes a listener returned by `on`.
	---
	---@param listener EventListener
	function events:off(listener)
		local remaining = {};
		for i = 1, getn(%store._listeners) do
			if (%store._listeners[i] ~= listener) then
				remaining[getn(remaining) + 1] = %store._listeners[i];
			end
		end
		%store._listeners = remaining;
	end

	---@param event? Event
	---@param listener EventListener
	---@return bool
	local hasPassStatus = function (event, listener)
		return event and modkit.table.includesValue(listener.options.pass_statuses, event.status);
	end

	--- Returns whether `listener`'s pattern passes.
	---
	---@param listener EventListener
	---@return bool
	local listenerPasses = function (listener)
		-- a single name (i.e from a chain) needs no parsing
		if (getn(listener.names) == 1 and listener.names[1] == listener.pattern) then
			return %hasPassStatus(modkit.events:get(listener.pattern), listener);
		end

		-- otherwise build a Lua expression from the pattern ('A and (B or C)' -> 'return 1 and (nil or 1)'), and evaluate it
		local passes = %hasPassStatus; -- (re-localised, since upvalues only reach the immediately enclosing function)
		local expression = gsub(listener.pattern, "([^%s%(%)]+)", function (name)
			if (modkit.events._listener_keywords[name]) then
				return name;
			end
			if (%passes(modkit.events:get(name), %listener)) then
				return "1";
			end
			return "nil";
		end);
		return dostring("return " .. expression);
	end

	--- Calls or begins a passed listener's target.
	---
	---@param listener EventListener
	local fireListener = function (listener)
		local awaited = {};
		for i = 1, getn(listener.names) do
			awaited[i] = modkit.events:get(listener.names[i]) or 0; -- (0 for missing events, since a `nil` would end the list)
		end

		if (type(listener.target) == "function") then
			local args = {};
			for i = 1, getn(awaited) do
				if (awaited[i] ~= 0) then
					args[i] = awaited[i];
				end
			end
			args.n = getn(awaited);
			call(listener.target, args, "x", function (message)
				print("[modkit.events] error in listener for '" .. %listener.pattern .. "': " .. tostring(message));
			end);
		else
			local previous_result = nil;
			if (listener.options.computePreviousResolve) then
				previous_result = listener.options.computePreviousResolve();
			elseif (getn(awaited) == 1 and awaited[1] ~= 0) then
				previous_result = awaited[1].result;
			end
			listener.target:begin(previous_result);
		end
	end

	-- ===[ Running ]===

	--- Runs `event`'s callback once. Errors in the callback reject the event (and are printed), rather than stopping every other event.
	---
	---@param event Event
	local runEvent = function (event)
		local state = event.state;
		local caught = {}; -- (a table, since upvalues can't be assigned to)
		-- the wrapper's leading `1` tells success apart from an error (`call` returns `nil`); the error handler can't be relied on,
		-- since the game refuses to overwrite global functions ("Cannot overwrite function _ERRORMESSAGE"), so `call` can't install it
		local succeeded, value = call(
			function (fn, resolve, reject, fn_state)
				return 1, fn(resolve, reject, fn_state);
			end,
			{ event.fn, %makeResolver(event), %makeRejecter(event), state },
			"x",
			function (message)
				%caught.message = message;
			end
		);

		if (not succeeded) then
			local message = caught.message or "Lua error (see the traceback above)";
			print("[modkit.events] error in event '" .. event.name .. "': " .. tostring(message));
			event:finish(EVENT_STATUS.REJECTED, message);
			return nil;
		end

		state._value = value;
		state._tick = state._tick + 1;

		if (event.status == EVENT_STATUS.RUNNING and state._remaining_iterations) then
			state._remaining_iterations = state._remaining_iterations - 1;
			if (state._remaining_iterations <= 0) then
				event:finish(EVENT_STATUS.RESOLVED, value);
			end
		end
	end

	--- Runs every due event, then any listeners whose patterns pass, then cleans up finished events. Called by the scope's driver.
	function events:tick()
		local now = Universe_GameTime();
		local due_by = now + 0.001; -- (tolerance for floating point drift, so a 1s interval doesn't sometimes take an extra tick)

		-- 1. run due events (collected first, since events made during this tick shouldn't be traversed)
		local due = {};
		for _, event in %store._entities do
			if (event.status == EVENT_STATUS.RUNNING and event._next_run <= due_by) then
				due[getn(due) + 1] = event;
			end
		end
		for i = 1, getn(due) do
			local event = due[i];
			if (event.status == EVENT_STATUS.RUNNING) then -- (an earlier event may have finished it)
				event._next_run = now + event.interval;
				%runEvent(event);
			end
		end

		-- 2. fire passing listeners (listeners added while firing are kept for the next tick)
		local listeners = %store._listeners;
		%store._listeners = {};
		local waiting = {};
		for i = 1, getn(listeners) do
			local listener = listeners[i];
			if (%listenerPasses(listener)) then
				%fireListener(listener);
			else
				waiting[getn(waiting) + 1] = listener;
			end
		end
		for i = 1, getn(%store._listeners) do
			waiting[getn(waiting) + 1] = %store._listeners[i];
		end
		%store._listeners = waiting;

		-- 3. clean up finished events, unless a waiting listener names them
		local awaited_names = {};
		for i = 1, getn(waiting) do
			for j = 1, getn(waiting[i].names) do
				awaited_names[waiting[i].names[j]] = 1;
			end
		end
		local finished = {};
		for _, event in %store._entities do
			if ((event.status == EVENT_STATUS.RESOLVED or event.status == EVENT_STATUS.REJECTED) and awaited_names[event.name] == nil) then
				finished[getn(finished) + 1] = event;
			end
		end
		for i = 1, getn(finished) do
			%forget(finished[i]);
		end
	end

	--- Removes every event and listener.
	function events:reset()
		%store._entities = {};
		%store._ids_by_name = {};
		%store._listeners = {};
	end

	modkit.events = events;

	--- **Deprecated:** use `modkit.events` (note `interval` is now in seconds; it was in scheduler ticks, 20 per second).
	---@deprecated
	modkit.scheduler = events;
end

-- the rules scope's driver (started by the first `begin` there)
function modkit_events_driver()
	modkit.events:tick();
end
