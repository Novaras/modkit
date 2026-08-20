if (modkit == nil) then
	modkit = {};
	dofilepath("data:scripts/modkit/table_util.lua");
	dofilepath("data:scripts/modkit/scopes.lua");
end

-- events repeat by default, optionally can specify the amount with `iterations`

---@class EventCoreState: table
---@field _tick integer
---@field _started_gametime number
---@field _value? any -- running value, set by the callback's return each execution
---@field _previous_result? any -- resolve value of the previous event, if any
---@field _remaining_iterations? integer
---@field _event Event

---@class EventState: table, EventCoreState

---@enum EventStatus
EVENT_STATUS = {
	INIT = "init",
	RUNNING = "running",
	RESOLVED = "resolved",
	REJECTED = "rejected"
};

---@class EventConfig
---@field fn EventFn
---@field name? string
---@field state? table
---@field interval? number
---@field iterations? integer

---@class Event
---@field id integer
---@field name string
---@field state EventState
---@field status EventStatus
---@field result? any[]
---@field fn EventFn
---@field interval integer
---@field remaining_iterations? integer
---@field error? string -- only exists after rejecting
---@field begin fun(self: Event, initial_value?: any): EventChain
---@field stop fun(self: Event)
---@field finish fun(self: Event, state: EventStatus, args: any): nil
---@field __is_event bool

---@alias EventLike Event|EventConfig|EventFn

---@class EventChain
---@field next fun(self: EventChain, event: EventLike): EventChain
---@field catch fun(self: EventChain, handler: fun(message: string))


---@class EventListenerOptions
---@field pass_statuses? EventStatus[]
---@field computePreviousResolve? fun(): any We might want to produce a 'previous' result for an event which is not part of a chain; for that we just invoke a given callback

---@class EventListener
---@field pattern string
---@field options EventListenerOptions
---@field event_to_trigger Event

---@alias EventResolve fun(...: any): nil
---@alias EventReject fun(message?: string): nil
---@alias EventFn fun(resolveCallback: EventResolve, rejectCallback: EventReject, state: EventState): any

if (modkit.scheduler == nil) then
	if (modkit.MemGroup == nil) then
		dofilepath("data:scripts/modkit/memgroup.lua");
	end

	---@class GlobalScheduleEvents: MemGroupInst
	---@field _entities Event[]
	---@field _listeners EventListener[]
	GLOBAL_SCHEDULE_EVENTS = modkit.MemGroup.Create("mg-schedule-events", {
		_listeners = {}
	});

	ID = {
		id = 0
	};
	function ID:new()
		local id = self.id;
		self.id = self.id + 1;
		return id;
	end

	-- these util functions should probably be placed somewhere else;
	-- -> maybe refactor scheduler lib into 'events api', which is a subtable of a higher 'scheduler api',
	-- then we can also put a listeners api

	---@return EventResolve
	_schedulerResolver = function (event)
		return function (result)
			-- print("RESOLVING EVENT " .. %event.name .. "!");
			-- print("resolve with result: " .. tostring(result));

			%event.status = EVENT_STATUS.RESOLVED;
			%event.result = result;
		end;
	end

	---@return EventReject
	_schedulerRejecter = function (event)
		return function (message)
			%event.status = EVENT_STATUS.REJECTED;
			%event.error = "[" .. %event.name .. "]: " .. message;
		end
	end

	--- Returns whether or not the given listener passes its conditions.
	---
	--- We can't attach this as a method to the listener itself since functions cant survive in the superscope.
	---
	---@param listener EventListener
	---@return bool
	_schedulerListenerPasses = function (listener)
		pattern_exec = "" .. listener.pattern;
		-- temporarily replace these keywords with C-style tokens (to protect them from being included by other patterns)
		-- `A and (B or C)`
		-- -> `A&(B or C)`
		-- -> `A&(B|C)`
		pattern_exec = gsub(pattern_exec, " and ", " & ");
		pattern_exec = gsub(pattern_exec, " or ", " | ");
		-- here we are constructing a LUA logic expression which will tell us the truthiness of the supplied pattern
		-- if a rule is running, we insert true (1), else false (nil)
		-- (we construct something like: "return 1 and nil and nil or (1 and 1)")
		pattern_exec = gsub(pattern_exec, "([%w_]+)", function(matches)
			local event = modkit.scheduler:get(matches);
			-- modkit.table.printTbl({
			-- 	r = r or "nil",
			-- 	pattern = %p,
			-- 	pattern_exec = %pattern_exec,
			-- 	matches = matches
			-- }, matches);
			if(event and modkit.table.includesValue(%listener.options.pass_statuses, event.status)) then
				return "1";
			end
			return "nil";
		end);
		-- now replace the tokens with the lua keywords again
		pattern_exec = gsub(pattern_exec, " & ", " and ");
		pattern_exec = gsub(pattern_exec, " | ", " or ");
		pattern_exec = gsub(pattern_exec, "^%s*(.-)%s*$", "%1");
		pattern_exec = "return " .. pattern_exec;
		return dostring(pattern_exec);
	end

	-- =====[[ Scheduler Lib: API on the modkit table for managing scheduled events. ]]=====

	--- API for managing `ScheduledEvent`s, scope-agnostic version of `Rule`s.
	---@class Scheduler
	---@field default_interval integer 20 intervals pass per second
	local scheduler_lib = {
		default_interval = 10,
	};

	---@param event EventLike
	---@return EventChain
	function _makeEventChain(event)
		local chain = {};
		---@cast chain EventChain
		
		if (type(event) == "function" or not event.__is_event) then
			---@cast event EventConfig
			event = modkit.scheduler:make(event);
		end
		---@cast event Event

		function chain:next(next_event)
			local event = %event;

			if (type(next_event) == "function") then
				---@cast next_event EventFn
				next_event = modkit.scheduler:make({
					name = event.name .. "_next",
					fn = next_event,
				});
			end
			if (not next_event.__is_event) then
				---@cast next_event EventConfig
				next_event = modkit.scheduler:make(next_event);
			end
			---@cast next_event Event

			if (type(next_event) == "function") then
				next_event = modkit.scheduler:make(next_event);
			end

			modkit.scheduler:on(event.name, function (res)
				if (%event.status == EVENT_STATUS.REJECTED) then
					%next_event:finish(%event.status, %event.error);
				else
					%next_event:begin(%event.result);
				end

				res();
			end);

			return _makeEventChain(next_event);
		end

		function chain:catch(handler)
			local event = %event;

			modkit.scheduler:on(event.name, function (res)
				if (%event.status == EVENT_STATUS.REJECTED) then
					%handler(%event.error);
				end
				res();
			end)
		end

		return chain;
	end

	-- ===[ Utils/echos ]===

	---@param id_or_name integer|string
	---@return Event|nil
	function scheduler_lib:get(id_or_name)
		if (type(id_or_name) == "number") then
			return GLOBAL_SCHEDULE_EVENTS:get(id_or_name);
		end

		return GLOBAL_SCHEDULE_EVENTS:find(function (event)
			return event.name == %id_or_name;
		end);
	end

	---@return Event[]
	function scheduler_lib:all()
		return GLOBAL_SCHEDULE_EVENTS:all();
	end

	---@return Event|nil
	function scheduler_lib:find(predicate)
		return GLOBAL_SCHEDULE_EVENTS:find(predicate);
	end

	---@return Event[]
	function scheduler_lib:filter(predicate)
		return GLOBAL_SCHEDULE_EVENTS:filter(predicate);
	end

	--- ===[ CORE METHODS ]===

	---@param new_event EventConfig|EventFn
	---@return Event
	function scheduler_lib:make(new_event)
		local id = ID:new();

		if (type(new_event) == "function") then
			new_event = {
				fn = new_event,
			};
		end

		-- modkit.table.printTbl(new_event, "new event request");

		local core_state = {
			_started_gametime = Universe_GameTime(),
			_tick = 0,
			_remaining_iterations = new_event.iterations,
			_event = nil
		};

		local new_event = {
			-- from def
			fn = new_event.fn,
			iterations = new_event.iterations,
			interval = new_event.interval or modkit.scheduler.default_interval,
			name = new_event.name or ("schedule_event_" .. id),
			state = modkit.table:merge(new_event.state or {}, core_state),
			-- construct the rest
			id = id,
			status = EVENT_STATUS.INIT
		};

		new_event.state._event = new_event;

		function new_event:begin(previous_result)
			return modkit.scheduler:begin(self, previous_result);
		end

		function new_event:stop()
			self.status = EVENT_STATUS.INIT;
		end

		---@param status EventStatus
		function new_event:finish(status, args)

			self.status = status;

			if (status == EVENT_STATUS.REJECTED) then
				return _schedulerRejecter(self)(args);
			end

			return _schedulerResolver(self)(args);
		end

		---@cast new_event Event

		-- set up a special key `__is_event`, which we can use to check if a table var is a `ScheduleEvent`.
		local identifier_tag = newtag();
		local identifier_hook = function (ev, key)
			if (key == "__is_event") then
				return 1;
			end
			return rawget(ev, key);
		end
		settagmethod(identifier_tag, "gettable", identifier_hook);
		settag(new_event, identifier_tag);

		return GLOBAL_SCHEDULE_EVENTS:set(new_event.id, new_event);
	end

	---@param event EventLike
	---@param previous_result? any
	---@return EventChain
	function scheduler_lib:begin(event, previous_result)
		if (type(event) == "function" or not event.__is_event) then
			---@cast event EventConfig
			event = modkit.scheduler:make(event);
		end
		---@cast event Event

		event.status = EVENT_STATUS.RUNNING;
		event.state._previous_result = previous_result;

		return _makeEventChain(event);
	end

	---@param pattern string
	---@param event_to_trigger EventLike
	---@param options? EventListenerOptions
	function scheduler_lib:on(pattern, event_to_trigger, options)
		options = modkit.table:merge(
			{
				pass_statuses = { EVENT_STATUS.REJECTED, EVENT_STATUS.RESOLVED }
			},
			(options or {})
		);
		---@cast options EventListenerOptions

		if (type(event_to_trigger) == "function" or not event_to_trigger.__is_event) then
			---@cast event_to_trigger EventConfig|EventFn
			event_to_trigger = modkit.scheduler:make(event_to_trigger);
		end
		---@cast event_to_trigger Event

		---@type EventListener
		local new_listener = {
			pattern = pattern,
			options = options,
			event_to_trigger = event_to_trigger
		};

		GLOBAL_SCHEDULE_EVENTS._listeners[pattern] = new_listener;

		return new_listener;
	end

	---@param event Event|integer|string
	function scheduler_lib:remove(event)
		if (type(event) ~= "table") then
			---@diagnostic disable-next-line
			event = modkit.scheduler:get(event);
		end
		---@cast event Event
		
		print("deleting event " .. tostring(event.name or event.id));

		GLOBAL_SCHEDULE_EVENTS:delete(event.id);
	end

	modkit.scheduler = scheduler_lib;
end