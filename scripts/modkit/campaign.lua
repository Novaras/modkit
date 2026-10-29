-- campaign.lua: utils for writing campaign scripts.
-- By: Fear (Novaras)

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (H_CAMPAIGN == nil or (modkit ~= nil and modkit.campaign == nil)) then
	if (modkit.events == nil) then dofilepath("data:scripts/modkit/events.lua"); end

	local campaign = {};

	--- Sets the level path, and also populates `GLOBAL_MISSION_SHIPS`.
	---
	---@param level_path string
	function campaign:init(level_path)
		self.level_path = level_path;

		if (GLOBAL_MISSION_SHIPS == nil) then
			RegisterShips(level_path);
			print("INIT MISSION SOBGROUPS");
		end
	end

	--- **Deprecated:** use `modkit.events` (rules are now events, which work in every scope).
	---
	--- Everything here falls through to `modkit.events`, plus `init` (`modkit.campaign:init`).
	---
	---@deprecated
	---@class Rules: Events
	campaign.rules = {
		init = function (_, level_path)
			modkit.campaign:init(level_path);
		end,
	};
	-- (a tag rather than copying the methods, so this stays in sync; the events API doesn't depend on `self`)
	campaign._rules_tag = newtag();
	settagmethod(campaign._rules_tag, "index", function (_, key)
		return modkit.events[key];
	end);

	---@diagnostic disable-next-line: deprecated
	settag(campaign.rules, campaign._rules_tag);

	-- == map getters

	local map = {};

	--- Returns a MemGroup of all the ships in the level file
	---@return GLOBAL_MISSION_SHIPS
	function map:ships()
		return GLOBAL_MISSION_SHIPS; -- defined in sp_helpers.lua (called from the .level file)
	end

	-- for missions without their own `OnInit`
	if (OnInit == nil) then
		OnInit = function ()
			modkit.events:startDriver();
		end;
	end

	campaign.map = map;
	modkit.campaign = campaign;

	H_CAMPAIGN = 1;
end
