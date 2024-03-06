COMMANDS = COMMANDS or {};

COMMANDS.test = COMMANDS.test or {
    description = "Runs a test file. Test files should exist in 'data:scripts/modkit/tests'",
    syntax = "test [filename]",
    example = "test objectives",
    fn = function (_, words, _, line)
        if (words[2]) then
			dofilepath("data:scripts/modkit/tests/" .. words[2] .. ".lua");

			consoleLog("<b>== Attempt unit tests... ==</b>");

			consoleLog("Rules_?: " .. tostring(Rule_AddInterval or 'nil'));

			modkit.campaign.rules:make(function (res)
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

				res();
			end):begin()
				:next(function (resolveCallback)
					consoleLog("<b><c=2266AA>Feature Tests:</c></b>");

					_TESTS.feature.main_operations();

					resolveCallback();
				end)
        end
    end,
};
