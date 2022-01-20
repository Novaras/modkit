if (modkit == nil) then
	modkit = {};
	dofilepath("data:scripts/modkit/table_util.lua");
end

if (H_SCHEDULER == nil) then
	--- The scheduler keeps a register of 'events', which are functions bound to a scheduler tick interval.
	--- These ticks happenen every `seconds_per_tick` seconds. Every time the interval amount of ticks pass,
	--- functions which are bound to that interval are fired. This allows ship `update` hooks to bypass their own
	--- minimum tick rate (which is limited by whatever is set in their .ship file). It also allows these scripts
	--- to time different functions to different intervals as they desire, without needing to keep track of timers.
	scheduler = {
		tick = 1,
		seconds_per_tick = 0.1, -- lowest is 0.05, presumably
		scheduled_events = {}, -- table with signature: { fn: function, data: integer }
		one_off_events = {},
		max_tick = 1, -- to stop `tick` overflowing we wrap when it reaches the most infrequent events tick interval
		new_event_index = 1 -- used to provide new events with an index (increment)
	};

	--- Called every `self.seconds_per_tick` seconds by the `modkit_scheduler` ship (which is spawned by `deathmatch/deathmatch.lua`)
	---
	---@return nil
	function scheduler:update()
		-- one-off events scheduled for this tick:
		local this_tick_one_off_events = self.one_off_events[self.tick] or {};
		for _, event in this_tick_one_off_events do
			event:fn();
		end
		for interval, events in self.scheduled_events do
			if (mod(self.tick, interval) == 0) then -- if interval is a factor of the current tick
				for _, event in events do -- fire the events bound to that index
					event:fn(); -- event's callback has the event passed
				end
			end
		end
		self.tick = max(1, mod(self.tick + 1, self.max_tick)); -- wrap if > than `self.max_tick` (start at 1)
	end


	function scheduler:calcInterval()
		return modkit.table.reduce(self.scheduled_events, function (product, _, interval)
			return product * interval;
		end, 1);
	end

	--- Calls the supplied function `fn` every `interval` scheduler ticks. Useful to bypass a ships update rate.
	--- Anything passed into the optional third table parameter `data` will be added to the first and only argument of the callback `fn`.
	--- **Note: You can convert seconds to scheduler ticks by dividing the number of seconds by `modkit.scheduler.seconds_per_tick`.**
	--- Returns the new event's id (so it can be cleared using `modkit.scheduler.clear`)
	---
	---@param interval integer
	---@param fn function
	---@param offset integer
	---@param data table
	---@return integer
	function scheduler:every(interval, fn, offset, data)
		if (interval == nil or fn == nil) then
			return nil;
		end
		
		-- make a new event:
		local new_event = {
			id = self.new_event_index, -- id = position in array (once we push it in)
			data = data,
		};
		self.new_event_index = self.new_event_index + 1;
		local outer_self = self;
		function new_event:fn() -- passed fn will have this event table passed to it
			if (%offset) then
				local outer_event = self;
				local outer_callback = %fn;
				%outer_self:once(function ()
					%outer_callback({
						id = %outer_event.id,
						data = %outer_event.data
					}); -- avoid passing `fn`
				end, %offset);
			else
				%fn({
					id = %new_event.id,
					data = %new_event.data
				}); -- avoid passing `fn`
			end
		end
		-- add it to the array
		if (self.scheduled_events[interval] == nil) then
			self.scheduled_events[interval] = {};
		end
		self.scheduled_events[interval][new_event.id] = new_event;

		self.max_tick = self:calcInterval();

		return new_event.id;
	end

	--- Clears the event with id `event_id`. The event is permanently removed from the scheduler.
	---
	---@param event_id integer
	---@return nil
	function scheduler:clear(event_id)
		for interval, events in self.scheduled_events do
			for _, event in events do
				if (event.id == event_id) then
					self.scheduled_events[interval][event.id] = nil;
					if (modkit.table.length(self.scheduled_events[interval]) == 0) then
						self.scheduled_events[interval] = nil;
					end
				end
			end
		end

		self.max_tick = self:calcInterval();
	end

	---WIP
	---@param delay integer
	---@param fn fun()
	---@param data any
	function scheduler:once(delay, fn, data)
		local fire_at = self.tick + delay;

		local wrapper = function (event)
			%fn();
			%self.scheduled_events[%fire_at][event.id] = nil; -- clear self
		end
		
		self:every(fire_at, wrapper, nil, data);
	end

	modkit.scheduler = scheduler;

	H_SCHEDULER = 1;
end