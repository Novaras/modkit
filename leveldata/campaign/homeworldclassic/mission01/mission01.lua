print("=== beginning mission01.lua ===");

dofilepath("data:scripts/modkit/campaign.lua");
local CAMPAIGN = modkit.campaign;

local m = CAMPAIGN.makeMission('data:leveldata/campaign/homeworldclassic/mission01');

-- actions:
-- a1:
--  spawn(?) a carrier, try doing a hs in and a cinematic wait, should come with 2 int squads
-- a2(a1):
--  

-- scenario:
-- path 1:
--  do a1, a2(a1), a3(a2), a4(a1)
-- path 2:
--  do b1
-- path 3:
--  do c1(a3, b1)
-- path 4:
--  do d1, d2(d1), d3(d2){d1}

-- key:
-- <name>(dependencies){resets}

local wait_5 = {
	main = function (state)
		modkit.table.printTbl(state, "state");
		if (state.tick == 5) then
			return 1;
		end
	end
};

-- rules have it PARENT =[exit & call]=> [...CHILDREN]
-- nodes have it [...CHILDREN] <=[wait for exit]= PARENT

m.flow:set({
	a1 = wait_5,
	a2 = {
		dependencies = { 'a1' },
		action = wait_5,
	},
	a3 = {
		state = { 'hello' },
		dependencies = { 'a2' },
		action = {
			main = function (state)
				consoleLog("death!");
				for _, ship in GLOBAL_SHIPS:all() do
					ship:die();
				end
				return 1;
			end
		},
	},
	b1 = {
		main = function ()
			consoleLog("call from b1");
			if (random() < 0.1) then
				consoleLog("entropy claims b1...");
				return 1;
			end
		end,
	},
	c1 = {

	},
});

modkit.table.printTbl(m.flow._nodes, "flow nodes");

m:start();

print("== end of mission script ==");
