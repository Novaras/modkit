COMMANDS = COMMANDS or {};

---@class TestRun
---@field name string
---@field events Event[] Every event the run has begun, so `--force` can reject them

COMMANDS.test = COMMANDS.test or {
    description = "Runs a test file. Test files should exist in 'data:scripts/modkit/tests'. Only one test can run at a time; " ..
        "if '--force' is set, the running test is stopped (rejected) and this one begins straight away.",
    syntax = "test [filename] ?--force",
    example = "test objectives --force",
    flags = {
        'force'
    },
    ---@type TestRun|nil
    current = nil, -- the running test (one at a time, since the test file sets the global `_TESTS`)
    fn = function (_, words, flags)
		local name = nil; -- (the first word after `test` that isn't a flag)
		for i = 2, getn(words) do
			if (strsub(words[i], 1, 2) ~= "--") then
				name = words[i];
				break;
			end
		end

        if (name) then
			local printErr = consoleError or consoleLog;

			local previous = COMMANDS.test.current;
			if (previous and not flags.force) then
				-- (kept short: the console doesn't wrap long lines yet, see TODO.md)
				printErr("test '" .. previous.name .. "' is still running; close the console to let it finish, or use --force");
				return nil;
			end

			-- cleared first: `dofilepath` silently does nothing for a missing file, which would re-run the previous test's `_TESTS`
			local previous_tests = _TESTS;
			_TESTS = nil;
			dofilepath("data:scripts/modkit/tests/" .. name .. ".lua");

			if (_TESTS == nil) then
				_TESTS = previous_tests; -- (put back, so a running test carries on)
				printErr("no tests in 'data:scripts/modkit/tests/" .. name .. ".lua' (missing, or doesn't set `_TESTS`)");
				return nil;
			end

			if (previous) then
				-- reject whatever is running; events still waiting in its chain are rejected in turn (on a later tick), which its
				-- `:catch` ignores, since it's no longer the current run
				for i = 1, getn(previous.events) do
					local event = previous.events[i];
					if (event.status == EVENT_STATUS.RUNNING) then
						event:finish(EVENT_STATUS.REJECTED, "stopped by 'test " .. name .. " --force'");
					end
				end
				COMMANDS.test.current = nil;
				consoleLog("stopped test '" .. previous.name .. "'");
			end

			---@type TestRun
			local run = { name = name, events = {} };
			COMMANDS.test.current = run;

			consoleLog("<b>== Attempt unit tests... ==</b>");

			consoleLog("Rules_?: " .. tostring(Rule_AddInterval or 'nil'));

			local units = modkit.events:make(function (res)
				consoleLog("<b><c=2266AA>Unit Tests:</c></b>");
				for field, _ in _TESTS.unit do
					local result_line = "<c=AA6622>" .. tostring(field) .. "</c>";
					local result = _TESTS.unit[field]();
					if (result) then
						consoleLog(result_line .. " <b><c=ff5555>FAIL</c></b>");
						for _, v in result do
							consoleLog("\t- " .. v);
						end
					else
						consoleLog(result_line .. " <b><c=2222FF>PASS</c></b>");
					end
				end

				if (_TESTS.cleanup) then
					_TESTS.cleanup();
				end

				res();
			end);

			-- begins the feature test, then waits for it to finish (so the test counts as running until then)
			local features = modkit.events:make(function (res, rej, state)
				---@class TestFeatureWaitState: EventState
				---@field feature? Event
				---@cast state TestFeatureWaitState

				if (_TESTS.feature == nil or _TESTS.feature.main_operations == nil) then
					res();
				elseif (state.feature == nil) then
					consoleLog("<b><c=2266AA>Feature Tests:</c></b>");

					state.feature = _TESTS.feature.main_operations;
					%run.events[getn(%run.events) + 1] = state.feature;
					state.feature:begin();
				elseif (state.feature.status == EVENT_STATUS.RESOLVED) then
					res();
				elseif (state.feature.status == EVENT_STATUS.REJECTED) then
					rej(state.feature.error);
				end
			end);

			local finished = modkit.events:make(function (res)
				if (COMMANDS.test.current == %run) then
					consoleLog("<b>test '" .. %run.name .. "' finished</b>");
					COMMANDS.test.current = nil;
				end
				res();
			end);

			run.events = { units, features, finished };

			units:begin()
				:next(features)
				:next(finished)
				:catch(function (message)
					if (COMMANDS.test.current == %run) then -- (otherwise it was stopped by `--force`, which already said so)
						%printErr("test '" .. %run.name .. "' failed: " .. tostring(message));
						COMMANDS.test.current = nil;
					end
				end);
        end
    end,
};
