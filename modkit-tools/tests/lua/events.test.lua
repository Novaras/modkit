-- Offline unit tests for `scripts/modkit/events.lua` (`modkit.events`). Run with `npm test` in `modkit-tools`.
--
-- The game clock is faked (`NOW`), and `run(seconds)` drives events the way the rules scope does: a driver tick every 0.1s.
-- Callbacks record what happened in the global `RECORD` (globals avoid Lua 4's upvalue limits in nested callbacks).

dofile("modkit-tools/tests/lua/harness.lua");

-- engine stubs
NOW = 0;
function Universe_GameTime() return NOW; end
RULES_ADDED = {};
function Rule_AddInterval(name, interval) RULES_ADDED[getn(RULES_ADDED) + 1] = { name, interval }; end

loadQuietly("scripts/modkit/events.lua"); -- (also loads table_util, memgroup and protected_call)

E = modkit.events;

--- Advances the clock `seconds` (in 0.1s steps), ticking the driver each step.
function run(seconds)
	for _ = 1, floor(seconds * 10 + 0.5) do
		NOW = NOW + 0.1;
		modkit_events_driver();
	end
end

--- Clears every event and listener, the clock, and `RECORD`.
function fresh()
	E:reset();
	NOW = 0;
	RECORD = {};
end

function record(value)
	RECORD[getn(RECORD) + 1] = value;
end

--- Runs `fn` with `print` silenced (for code which prints warnings or errors on purpose).
function quietly(fn)
	print = function () end;
	fn();
	print = HARNESS_PRINT;
end

describe("make", function ()
	it("makes an event which doesn't run until begun", function ()
		fresh();
		local event = E:make(function () record("ran"); end);
		run(1);
		expectEq(RECORD, {});
		expectEq(event.status, EVENT_STATUS.INIT);
	end);
	it("names events event_<id> by default, or uses a given name", function ()
		fresh();
		local unnamed = E:make(function () end);
		local named = E:make({ name = "my-event", fn = function () end });
		expectEq(unnamed.name, "event_" .. unnamed.id);
		expectEq(named.name, "my-event");
	end);
	it("uses default_interval unless given one", function ()
		fresh();
		expectEq(E:make(function () end).interval, E.default_interval);
		expectEq(E:make({ interval = 2, fn = function () end }).interval, 2);
	end);
	it("can be found by id or name", function ()
		fresh();
		local event = E:make({ name = "findable", fn = function () end });
		expectTruthy(E:get(event.id) == event, "by id");
		expectTruthy(E:get("findable") == event, "by name");
		expectNil(E:get("missing"));
	end);
	it("warns about a name in use, and the name then finds the newer event", function ()
		fresh();
		local first = E:make({ name = "dupe", fn = function () end });
		quietly(function () SECOND = E:make({ name = "dupe", fn = function () end }); end); -- (prints the warning)
		expectTruthy(first ~= SECOND);
		expectTruthy(E:get("dupe") == SECOND);
	end);
end);

describe("begin", function ()
	it("runs the callback from the next tick, every interval", function ()
		fresh();
		E:make({ interval = 1, fn = function (_, _, state) record(state._tick); end }):begin();
		expectEq(RECORD, {}, "not run by begin itself");
		run(0.1);
		expectEq(RECORD, { 0 }, "first run");
		run(0.8);
		expectEq(RECORD, { 0 }, "not again before the interval");
		run(0.2);
		expectEq(RECORD, { 0, 1 }, "again after the interval");
	end);
	it("begins when the event is called", function ()
		fresh();
		local event = E:make(function () record("ran"); end);
		event();
		run(0.1);
		expectEq(RECORD, { "ran" });
	end);
	it("passes previous_result, and the start time, in the state", function ()
		fresh();
		NOW = 5;
		E:make(function (resolve, _, state)
			record(state._previous_result);
			record(state._started_gametime);
			resolve();
		end):begin("from before");
		run(0.1);
		expectEq(RECORD, { "from before", 5 });
	end);
	it("keeps the callback's previous return value in state._value", function ()
		fresh();
		E:make({ interval = 0.1, fn = function (resolve, _, state)
			record(state._value or "none");
			if (state._tick == 2) then
				resolve();
			end
			return "tick " .. state._tick;
		end }):begin();
		run(0.5);
		expectEq(RECORD, { "none", "tick 0", "tick 1" });
	end);
	it("doesn't restart an event that's already running", function ()
		fresh();
		local event = E:make({ interval = 0.1, fn = function (_, _, state) record(state._tick); end });
		event:begin();
		run(0.2);
		event:begin();
		run(0.1);
		expectEq(RECORD, { 0, 1, 2 });
	end);
	it("makes the event first, when given a callback", function ()
		fresh();
		E:begin(function (resolve) record("ran"); resolve(); end);
		run(0.1);
		expectEq(RECORD, { "ran" });
	end);
end);

describe("resolve / reject", function ()
	it("resolve finishes the event with a result, and it stops running", function ()
		fresh();
		local event = E:make({ interval = 0.1, fn = function (resolve) record("ran"); resolve("done"); end });
		event:begin();
		run(0.1);
		expectEq(event.status, EVENT_STATUS.RESOLVED);
		expectEq(event.result, "done");
		run(0.5);
		expectEq(RECORD, { "ran" }, "ran once");
	end);
	it("reject finishes the event with an error naming it", function ()
		fresh();
		local event = E:make({ name = "failing", fn = function (_, reject) reject("bad"); end });
		event:begin();
		run(0.1);
		expectEq(event.status, EVENT_STATUS.REJECTED);
		expectEq(event.error, "[failing]: bad");
	end);
	it("an error in the callback rejects the event with its message, and other events carry on", function ()
		fresh();
		---@diagnostic disable-next-line: need-check-nil, undefined-field
		local broken = E:make({ name = "broken", interval = 0.1, fn = function () local missing = nil; return missing.field; end }); -- (an error, on purpose)
		local fine = E:make({ interval = 0.1, fn = function () record("fine"); end });
		quietly(function ()
			%broken:begin();
			%fine:begin();
			run(0.3);
		end);
		expectEq(broken.status, EVENT_STATUS.REJECTED);
		expectTruthy(strfind(broken.error, "attempt to index", 1, 1), "the error message: " .. tostring(broken.error));
		expectEq(RECORD, { "fine", "fine", "fine" });
	end);
end);

describe("iterations", function ()
	it("resolves after that many runs, with the last return value", function ()
		fresh();
		local event = E:make({ interval = 0.1, iterations = 3, fn = function (_, _, state) record(state._tick); return "last " .. state._tick; end });
		event:begin();
		run(1);
		expectEq(RECORD, { 0, 1, 2 });
		expectEq(event.status, EVENT_STATUS.RESOLVED);
		expectEq(event.result, "last 2");
	end);
end);

describe("stop / remove", function ()
	it("stop pauses an event, and begin restarts it from tick 0", function ()
		fresh();
		local event = E:make({ interval = 0.1, fn = function (_, _, state) record(state._tick); end });
		event:begin();
		run(0.2);
		event:stop();
		run(0.5);
		expectEq(RECORD, { 0, 1 }, "paused");
		event:begin();
		run(0.1);
		expectEq(RECORD, { 0, 1, 0 }, "restarted");
	end);
	it("remove stops an event and forgets it, by event, name or id", function ()
		fresh();
		local by_event = E:make({ name = "rm-1", interval = 0.1, fn = function () record(1); end });
		local by_name = E:make({ name = "rm-2", interval = 0.1, fn = function () record(2); end });
		local by_id = E:make({ name = "rm-3", interval = 0.1, fn = function () record(3); end });
		by_event:begin();
		by_name:begin();
		by_id:begin();
		E:remove(by_event);
		E:remove("rm-2");
		E:remove(by_id.id);
		run(0.3);
		expectEq(RECORD, {});
		expectNil(E:get("rm-1"));
		expectNil(E:get("rm-2"));
		expectNil(E:get("rm-3"));
	end);
end);

describe("cleanup", function ()
	it("forgets finished events after the tick they finish in", function ()
		fresh();
		E:make({ name = "short", fn = function (resolve) resolve(); end }):begin();
		run(0.1);
		expectNil(E:get("short"));
	end);
	it("keeps a finished event while a listener is waiting on its name", function ()
		fresh();
		E:make({ name = "done-early", fn = function (resolve) resolve("kept"); end }):begin();
		E:on("done-early and later", function (early) ---@cast early Event
			record(early.result);
		end);
		run(0.3);
		expectTruthy(E:get("done-early"), "still there");
		E:make({ name = "later", fn = function (resolve) resolve(); end }):begin();
		run(0.2);
		expectEq(RECORD, { "kept" });
	end);
end);

describe("chains", function ()
	it("next begins with the previous event's result", function ()
		fresh();
		E:make(function (resolve) resolve(1); end):begin()
			:next(function (resolve, _, state) record(state._previous_result); resolve(state._previous_result + 1); end)
			:next(function (resolve, _, state) record(state._previous_result); resolve(); end);
		run(1);
		expectEq(RECORD, { 1, 2 });
	end);
	it("a rejection skips the rest of the chain and reaches catch", function ()
		fresh();
		E:make({ name = "first", fn = function (_, reject) reject("broke"); end }):begin()
			:next(function (resolve) record("skipped"); resolve(); end)
			:next(function (resolve) record("skipped too"); resolve(); end)
			:catch(function (message) record(message); end);
		run(1);
		expectEq(RECORD, { "[first]: broke" });
	end);
	it("catch isn't called when the chain resolves", function ()
		fresh();
		E:make(function (resolve) resolve(); end):begin()
			:next(function (resolve) record("next"); resolve(); end)
			:catch(function (message) record("caught " .. message); end);
		run(1);
		expectEq(RECORD, { "next" });
	end);
	it("next accepts an event's name, or a config", function ()
		fresh();
		E:make({ name = "named-next", fn = function (resolve) record("named"); resolve(); end });
		E:make(function (resolve) resolve(); end):begin()
			:next("named-next")
			:next({ interval = 0.1, fn = function (resolve) record("config"); resolve(); end });
		run(1);
		expectEq(RECORD, { "named", "config" });
	end);
end);

describe("on (listeners)", function ()
	it("calls a function once the event finishes, with the event", function ()
		fresh();
		local event = E:make({ name = "watched", fn = function (resolve) resolve("result"); end });
		E:on(event, function (finished) ---@cast finished Event
			record(finished.result);
		end);
		event:begin();
		run(0.5);
		expectEq(RECORD, { "result" }, "called once");
	end);
	it("'and' waits for every named event", function ()
		fresh();
		E:on("a and b", function () record("both"); end);
		E:make({ name = "a", fn = function (resolve) resolve(); end }):begin();
		E:make({ name = "b", interval = 0.1, fn = function (resolve, _, state) if (state._tick == 3) then resolve(); end end }):begin();
		run(0.3);
		expectEq(RECORD, {}, "b not finished yet");
		run(0.3);
		expectEq(RECORD, { "both" });
	end);
	it("'or' waits for any, 'not' passes while an event hasn't finished, and brackets group", function ()
		fresh();
		E:on("x or y", function () record("or"); end);
		E:on("not never-made", function () record("not"); end);
		E:on("(x and never-made) or (y and x)", function () record("brackets"); end);
		E:make({ name = "x", fn = function (resolve) resolve(); end }):begin();
		run(0.2);
		expectSameItems(RECORD, { "or", "not" });
		E:make({ name = "y", fn = function (resolve) resolve(); end }):begin();
		run(0.2);
		expectSameItems(RECORD, { "or", "not", "brackets" });
	end);
	it("gives a function the pattern's events in order, with nil for missing ones", function ()
		fresh();
		E:make({ name = "p", fn = function (resolve) resolve("P"); end }):begin();
		E:make({ name = "q", fn = function (resolve) resolve("Q"); end }):begin();
		E:on("q and p or not-there", function (q, p, missing)
			---@cast q Event
			---@cast p Event
			record(q.result);
			record(p.result);
			record(missing or "nil");
		end);
		run(0.2);
		expectEq(RECORD, { "Q", "P", "nil" });
	end);
	it("begins a target event with the event's result", function ()
		fresh();
		local source = E:make({ name = "source", fn = function (resolve) resolve("payload"); end });
		E:on(source, { fn = function (resolve, _, state) record(state._previous_result); resolve(); end });
		source:begin();
		run(0.5);
		expectEq(RECORD, { "payload" });
	end);
	it("uses computePreviousResolve for a target event's previous result", function ()
		fresh();
		E:on("m and n", { fn = function (resolve, _, state) record(state._previous_result); resolve(); end }, {
			computePreviousResolve = function () return "computed"; end
		});
		E:make({ name = "m", fn = function (resolve) resolve("from m"); end }):begin();
		E:make({ name = "n", fn = function (resolve) resolve("from n"); end }):begin();
		run(0.5);
		expectEq(RECORD, { "computed" });
	end);
	it("gives a target event no previous result when the pattern names several events", function ()
		fresh();
		E:on("j and k", { fn = function (resolve, _, state) record(state._previous_result or "none"); resolve(); end });
		E:make({ name = "j", fn = function (resolve) resolve("from j"); end }):begin();
		E:make({ name = "k", fn = function (resolve) resolve("from k"); end }):begin();
		run(0.5);
		expectEq(RECORD, { "none" });
	end);
	it("only counts the pass_statuses given", function ()
		fresh();
		E:on("will-reject", function () record("fired"); end, { pass_statuses = { EVENT_STATUS.RESOLVED } });
		E:make({ name = "will-reject", fn = function (_, reject) reject(); end }):begin();
		run(0.3);
		expectEq(RECORD, {});
	end);
	it("off removes a listener", function ()
		fresh();
		local listener = E:on("removed-later", function () record("fired"); end);
		E:off(listener);
		E:make({ name = "removed-later", fn = function (resolve) resolve(); end }):begin();
		run(0.3);
		expectEq(RECORD, {});
	end);
	it("catches an error in a listener function, and other listeners still fire", function ()
		fresh();
		---@diagnostic disable-next-line: need-check-nil, undefined-field
		E:on("trigger", function () local missing = nil; return missing.field; end); -- (an error, on purpose)
		E:on("trigger", function () record("second"); end);
		quietly(function ()
			E:make({ name = "trigger", fn = function (resolve) resolve(); end }):begin();
			run(0.2);
		end);
		expectEq(RECORD, { "second" });
	end);
end);

describe("parse", function ()
	it("makes and begins an event per entry, named by key, with awaits deferring an entry", function ()
		fresh();
		local made = E:parse({
			first = function (resolve) record("first"); resolve(); end,
			second = { awaits = "first", fn = function (resolve) record("second"); resolve(); end },
		});
		expectEq(made.first.name, "first");
		expectEq(made.second.name, "second");
		run(0.5);
		expectEq(RECORD, { "first", "second" });
	end);
end);

describe("lookups", function ()
	it("isEvent tells events apart from other values", function ()
		fresh();
		expectTruthy(E:isEvent(E:make(function () end)));
		expectNil(E:isEvent({}));
		expectNil(E:isEvent("event_1"));
	end);
	it("toEvent returns events as-is, finds names, and makes callbacks and configs into events", function ()
		fresh();
		local event = E:make({ name = "existing", fn = function () end });
		expectTruthy(E:toEvent(event) == event, "an event");
		expectTruthy(E:toEvent("existing") == event, "a name");
		expectTruthy(E:isEvent(E:toEvent(function () end)), "a callback");
		expectTruthy(E:isEvent(E:toEvent({ fn = function () end })), "a config");
	end);
	it("toEvent warns about, and returns nil for, an unknown name", function ()
		fresh();
		quietly(function () UNKNOWN = E:toEvent("nope"); end);
		expectNil(UNKNOWN);
	end);
	it("find, filter and all search the events", function ()
		fresh();
		E:make({ name = "f1", fn = function () end });
		E:make({ name = "f2", fn = function () end }):begin();
		expectEq(E:find(function (event) return event.status == EVENT_STATUS.RUNNING; end).name, "f2");
		expectEq(modkit.table.length(E:filter(function (event) return event.status == EVENT_STATUS.INIT; end)), 1);
		expectEq(modkit.table.length(E:all()), 2);
	end);
end);

describe("driver", function ()
	it("begin starts the rules scope driver once, at rules_driver_interval", function ()
		fresh();
		E._store._driver_started = nil;
		RULES_ADDED = {};
		E:begin(function () end);
		E:begin(function () end);
		expectEq(RULES_ADDED, { { "modkit_events_driver", E.rules_driver_interval } });
	end);
	it("doesn't start a driver outside the rules scope (no Rule_AddInterval)", function ()
		fresh();
		E._store._driver_started = nil;
		RULES_ADDED = {};
		local real = Rule_AddInterval;
		Rule_AddInterval = nil;
		E:startDriver();
		Rule_AddInterval = real;
		expectNil(E._store._driver_started);
	end);
	it("doesn't run events made during a tick until the next one", function ()
		fresh();
		E:make({ name = "maker", fn = function (resolve)
			E:begin({ name = "made", fn = function (resolve_made) record("made ran"); resolve_made(); end });
			resolve();
		end }):begin();
		run(0.1);
		expectEq(RECORD, {}, "not in the tick it was made");
		run(0.1);
		expectEq(RECORD, { "made ran" });
	end);
end);

describe("reset", function ()
	it("removes every event and listener", function ()
		fresh();
		E:make({ name = "gone", fn = function () end }):begin();
		E:on("gone", function () record("fired"); end);
		E:reset();
		run(0.5);
		expectNil(E:get("gone"));
		expectEq(RECORD, {});
	end);
end);

describe("aliases", function ()
	it("modkit.scheduler is the same API (deprecated)", function ()
		---@diagnostic disable-next-line: deprecated
		expectTruthy(modkit.scheduler == modkit.events);
	end);
end);

finish();
