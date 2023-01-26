
if (modkit == nil) then modkit = {}; end

if (modkit.campaign == nil or modkit.campaign.createMissionFlow == nil) then
	dofilepath("data:scripts/modkit/campaign/missionflow.lua");
end

modkit.campaign.makeMission = function (level_dir_path)
	---@class Mission
	---@field flow MissionFlow
	---@field tick integer
	local mission = {
		flow = modkit.campaign.createMissionFlow(),
		tick = 0,
		root = level_dir_path
	};

	function mission:start()
		ensureMissionHooks(self);

		self.flow:start();
	end

	--- Ensure `init` and `startOrLoad` are set at least to the default `_init` and `_startOrLoad`.
	---
	---@param mission Mission
	ensureMissionHooks = ensureMissionHooks or function (mission)
		for _, hook in { 'init', 'startOrLoad' } do
			mission[hook] = mission[hook] or globals()["_" .. hook];
		end
	end

	function _startOrLoad(mission)
		print("OSOL RUN");
	end;
	function _init(mission)
		print("INIT RUN");
		dofilepath("data:scripts/modkit.lua");
		loadModkit();

		-- these are not redefinitions; the mission context and customcode context both need these defined
		initPlayers();
		initShips();

		dofilepath("data:leveldata/multiplayer/lib/modkit-scheduler.lua");
		modkit_scheduler_spawn();

		dofilepath("data:scripts/modkit/keybinds.lua");
		modkitBindKeys();

		local path_parts = strsplit(%level_dir_path, "/", 1);
		local last = path_parts[modkit.table.length(path_parts)];
		local full_path = %level_dir_path .. "/" .. last .. ".level";
		dofilepath("data:scripts/modkit/sp_helpers.lua");
		registerShips(full_path);

		local waitForFlowEnd = function ()
			 --print("main flow status:\t" .. %mission.flow._status);
			if (%mission.flow._status == FLOW_STATUS.exited) then
				print("-===<<[ MAIN FLOW EXITED!! PASS TO NEXT MISSION, ADIOS FROM " .. %mission.root .. "! ]>>===-");
				setGameOver(); -- actually ends the mission
			end
		end
		rawset(globals(), "waitForFlowEnd", waitForFlowEnd);
		Rule_AddInterval("waitForFlowEnd", 1);
	end;

	-- ===============
	-- Here we set a tag on the mission object with a tag method (hook) on 'settable'.
	-- This hook checks if they key is one of 'init' or 'startOrLoad', and if so, assigns the
	-- associated global function i.e setting 'init' on 'mission' causes 'OnInit' to be set on
	-- 'globals()'.
	-- These always-fired functions are called 'lifetime hooks/methods/functions'
	-- ===============

	local mission_tag = newtag();
	local mission_settable_lifetime_hook = function (mission, key, value)
		local keymap = {
			init = 'OnInit',
			startOrLoad = 'OnStartOrLoad'
		};

		if (key and keymap[key]) then
			rawset(globals(), keymap[key], function ()
				%value(%mission); -- here we pass mission as 'self'
				globals()["_" .. %key](%mission); -- here we call _init or _startOrLoad
			end);
		end

		rawset(mission, key, value);
	end
	settagmethod(mission_tag, "settable", mission_settable_lifetime_hook);
	settag(mission, mission_tag);

	return mission;
end
