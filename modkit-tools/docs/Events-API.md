# Modkit Events API

As `modkit.events`.

An event is a callback which runs every `interval` seconds until it _resolves_ (succeeds) or _rejects_ (fails). Events can be chained together, or listened for. It's the same API in every scope: in ship custom code, in level/campaign scripts (the rules scope), or anywhere else modkit is loaded.

Modelled after [JS Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise), the intent is to make code which plays out over time much more expressive and readable (and easier to think about) than juggling `Rule_AddInterval` calls or update counters.

> **Note:** this replaces `modkit.campaign.rules` (rules) and `modkit.scheduler` (the scheduler), which were two copies of the same idea for the two scopes. Both names still work as aliases of `modkit.events`, but `interval` is now always in **seconds** (the scheduler's was in ticks, 20 per second), and the callback's errors now reject the event instead of stopping every other event.

All the following examples use an alias like this:

```lua
local events = modkit.events;
```

It provides a chaining syntax:

```lua
event_a() -- store an event and begin it by invoking it just like a function
	:next(event_b) -- events can be chained together with `:next()`
	:next(event_c)
	:catch(function (err) print("error occured!: " .. err) end); -- errors anywhere in a chain skip the rest of it and end up in `:catch`
```

And a more traditional event listener API:

```lua
-- begin another event
events:on(event_a, event_b);

-- invoke a function once
events:on(event_b, function ()
	event_c();
	event_d:begin(); -- you can also call `:begin` explicitly instead of calling the event itself (`event_d()`)
end);
```

### Defining Events

An event is a `table` type. Construct events using `modkit.events:make`:

```lua
-- pass a function directly (will provide defaults)
event_a = events:make(function () end);
-- or define it more thoroughly
event_b = events:make({
	name = "my-event", -- for listeners; must be unique among existing events (default "event_<id>")
	interval = 2, -- seconds between runs (default 0.5)
	iterations = 5, -- optional: resolve by itself after this many runs, with the callback's last return value
	state = { foo = 1 }, -- optional: initial state
	fn = function (resolve, reject, state) end,
});
```

`modkit.events:parse` makes a whole table of events at once; entries with an `awaits` [listener pattern](#listening-for-events) begin when it passes, and the rest begin straight away:

```lua
local mission = events:parse({
	intro = function (resolve) ... end,
	first_wave = { awaits = "intro", fn = function (resolve) ... end },
});
```

### Beginning Events

Begin an event by calling it like a function, or via its `:begin()` method. It first runs on the next tick:

```lua
my_event = events:make(...);

my_event(); -- like a function
my_event:begin(); -- or via `:begin()`
events:begin(function (resolve) ... end); -- or make and begin in one go
```

`my_event:stop()` pauses an event (it can be begun again), and `events:remove(my_event)` stops and removes it. Finished events are cleaned up automatically, once nothing is listening for them.

### Listening for Events

When an event finishes, any _listeners_ for it are invoked. Listen for events using `:on()`:

```lua
local event_a = events:make({
	name = "weird-name",
	fn = function () end,
});
local event_b = events:make(...);

events:on(event_a, event_b); -- listen via the event (event_b begins with event_a's result as `_previous_result`)
events:on("weird-name", event_b); -- or just its name
events:on(event_a, function (a) end); -- if the listener is a plain function, it's just invoked once, with the event(s) it waited for
```

You may listen to multiple events with logical expressions (`and`, `or`, `not`, and brackets):

```lua
-- if all of the first three OR just D finish:
events:on("(A and event_b and my-c00l-event) or D", function (a, b, c, d)
	-- the named events (or `nil` for any which don't exist), in the order they appear in the pattern
end);
```

A name counts as true once its event has finished, whether it resolved or rejected (pass `{ pass_statuses = { EVENT_STATUS.RESOLVED } }` as the third argument to change that). `events:off(listener)` removes a listener returned by `on`.

### Exiting Events

Events exit with a success or error state, known as 'resolving' and 'rejecting'. They also carry a state table which keeps state between calls.

```lua
event_a = events:make(function (resolve, reject, state)
	if (state._tick == 5) then -- the special field `_tick` counts the previous runs
		state.foo = "bar"; -- we can add arbitary data to the state on each run
	end

	if (state.foo == "bar") then
		resolve(10);
	end

	if (some_error_occurred) then
		reject("error!");
	end
end);
```

The special state fields all start with `_`: `_tick`, `_started_gametime`, `_value` (the callback's previous return value), `_previous_result` and `_event` (the event itself).

#### Resolving

The `resolve` callback accepts a value (use a table for several), which is stored as the event's `result`. If another event is chained with `:next`, that event can find the result on its state object, under `_previous_result`.

```lua
-- chain syntax
event_a():next(function (_, _, state)
	print(state._previous_result); -- 10
end);

-- or a plain listener
events:on(event_a, function (a)
	print(a.result); -- 10
end);
```

#### Rejecting

The `reject` callback accepts a `string`, which is considered an 'error message'. You should only call `reject` if an _error state_ occurs in your event; a file couldn't be loaded, some important variable is missing, etc. An error in the callback itself (a Lua error) rejects the event too, with the error's message.

If something 'bad' can happen during an event, like a player failing an objective, that is not considered an _error_, so we would still want to use `resolve` in that case.

```lua
events:on(event_a, function (a)
	print("event_a err: " .. a.error);
end);
```

If an event rejects anywhere in a chain, the rest of the chain is skipped. If an error handler is supplied using `:catch`, then the error message is sent there:

```lua
event_a()
	:next(event_b)
	:next(event_c)
	:next(event_d)
	:catch(function (err)
		print("error occurred! " .. err);
	end);
```

If `event_b` called its `reject` function, `event_c` and `event_d` would be _skipped_.

### How events run

Each scope has its own events (functions can't be shared between scopes), and something in that scope calls `modkit.events:tick()` to run them:

- In the rules scope, the `modkit_events_driver` rule, every 0.1s. It starts automatically the first time an event begins.
- In ship custom code, the hidden `modkit_scheduler` ship's update, every 0.05s.

So an event's `interval` can't be shorter than its scope's tick.
