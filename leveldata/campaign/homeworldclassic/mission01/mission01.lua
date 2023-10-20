print("=== beginning mission01.lua ===");

dofilepath("data:scripts/SCAR/KASUtil.lua")

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
	main = function (exit, state)
		modkit.table.printTbl(state, "state");
		if (state.tick == 5) then
			return 1;
		end
	end
};

-- rules have it PARENT =[exit & call]=> [...CHILDREN]
-- nodes have it [...CHILDREN] <=[wait for exit]= PARENT

local sub_flow = CAMPAIGN.createMissionFlow({
	d1 = {
		action = wait_5,
	},
	d2 = {
		await = { 'd1' },
		action = wait_5
	},
	d3 = {
		await = { 'd2' },
	},
	d4 = {
		await = { 'd3' },
		revives = { 'd1', 'd2', 'd3', 'd4' },
		action = {
			main = function (exit, state)
				if (state.tick >= 5) then
					consoleLog("d4 out, exit...");
					return exit();
				end
			end
		}
	},
});

m.flow:set({
	a1 = {
		main = function (exit, state)
			print("ya boss im in " .. state.node_id);
			if (state.tick >= 5) then
				return 1;
			end
		end
	},
	a2 = {
		await = { 'a1' },
		action = wait_5,
	},
	a3 = {
		state = { 'hello' },
		await = { 'a2' },
		action = {
			main = function (exit, state)
				modkit.table.printTbl(state, "a3 state");
				consoleLog("death from a3!");
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
		await = { 'a3', 'b1' },
		action = {
			main = function (exit, state)
				print("c1 run... tick is " .. state.tick);
				if (1) then
					print("DONE WITH THIS");
					return exit();
				end
			end
		}
	},
	sub = {
		init = function ()
			print("starting sub flow");
			%sub_flow:start();
		end,
		main = function (exit, state)
			print("subflow action main call...");
			print("status of subflow?: " .. tostring(%sub_flow._status));
		end
	}
});

modkit.table.printTbl(m.flow._nodes, "flow nodes");

m.flow:start();

print("== end of mission script ==");
