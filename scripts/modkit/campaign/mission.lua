
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
		local keyname = '__MK_MISSION_ENGINE_WRAPPER';
		if (Rule_Exists(keyname) ~= 1) then
			local wrapper = function ()
				for id, _ in %self.flow:nodes() do
					%self.flow:doNode(id);
				end
				%self.tick = %self.tick + 1;
			end;
			rawset(globals(), keyname, wrapper);
			Rule_AddInterval(keyname, 1);
		end

		dofilepath("data:leveldata/multiplayer/lib/modkit-scheduler.lua");
		modkit_scheduler_spawn();

		dofilepath("data:scripts/modkit/sp_helpers.lua");
		Rule_AddInterval("syncGlobalShips", 2);
	end

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
			rawset(globals(), keymap[key], value);
		end

		rawset(mission, key, value);
	end
	settagmethod(mission_tag, "settable", mission_settable_lifetime_hook);
	settag(mission, mission_tag);

	mission.startOrLoad = function ()
		print("OSOL RUN");
	end;
	mission.init = function ()
		print("INIT RUN");
		dofilepath("data:scripts/modkit.lua");
		loadModkit();

		-- these are not redefinitions; the mission context and customcode context both need these defined
		initPlayers();
		initShips();

		dofilepath("data:scripts/modkit/keybinds.lua");
		modkitBindKeys();

		local path_parts = strsplit(%level_dir_path, "/", 1);
		local last = path_parts[modkit.table.length(path_parts)];
		local full_path = %level_dir_path .. "/" .. last .. ".level";
		dofilepath("data:scripts/modkit/sp_helpers.lua");
		registerShips(full_path);

		-- GLOBAL_SHIPS._entities = modkit.table:merge(
		-- 	GLOBAL_SHIPS._entities,
		-- 	GLOBAL_MISSION_SHIPS._entities
		-- );

		-- print("just merged into GS (id: " .. tostring(GLOBAL_SHIPS));
		-- print("entities count?: " .. tostring(modkit.table.length(GLOBAL_SHIPS._entities)));

		-- local stateHnd = makeStateHandle();
		-- local superglobal_ships = stateHnd().GLOBAL_SHIPS or {};
		-- for id, ship in GLOBAL_SHIPS:all() do
		-- 	print("now adding " .. ship.own_group .. " to the superglobal state");
		-- 	superglobal_ships[id] = superglobal_ships[id] or ship.own_group;
		-- end
		-- stateHnd({
		-- 	GLOBAL_SHIPS = superglobal_ships
		-- });

		-- modkit.table.printTbl(stateHnd().GLOBAL_SHIPS, "SUPERGLOBAL SHIPS");
	end;

	return mission;
end
