if (modkit.research == nil) then
	print("research init...");

	if (modkit == nil) then
		modkit = {};
	end

	if (modkit.table == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end

	---@class ResearchItem
	---@field name string
	---@field displayedname string
	---@field description string
	---@field displaypriority integer
	---@field requiredresearch string
	---@field requiredsubsystems string
	---@field cost integer
	---@field time integer
	---@field upgradetype? 'Ability'|'Modifier'
	---@field upgradename? string
	---@field upgradevalue? number
	---@field targettype? 'AllShips'|'Family'|'Ship'
	---@field targetname string

	research_proto = {
		---@type table<RaceName, ResearchItem[]>
		items = {},
	};

	dofilepath("data:scripts/modkit/races.lua");

	for _, race in modkit.races:names() do
		local def_research_path = "data:scripts/races/" .. race .. "/scripts/def_research.lua";
		research = nil; -- make sure unset before import
		dofilepath(def_research_path); -- sets 'research'

		if (research) then
			research_proto.items[race] = {};

			research_proto.items[race] = modkit.table.map(
				research,
				function (research_item)
					local lc = {};
					for k, v in research_item do
						lc[strlower(k)] = v;
					end
					return lc;
				end
			);
		end
	end

	--- Gets the research items for the given race.
	---
	---@param race RaceName|RaceConfig
	---@return ResearchItem[]
	function research_proto:getRaceItems(race)
		---@type string
		local name = race;
		if (type(race) == "table") then
			name = race.name;
		end
		name = strlower(name);
		-- print("finding race " .. name);
		local cfg = modkit.races:find(name);
		if (cfg) then
			modkit.table.printTbl(cfg, "cfg");
			return self.items[cfg.name] or {};
		end

		return {};
	end

	--- Gets all research items, optionally as one merged array.
	---
	---@param merge bool
	---@return table<RaceName, ResearchItem[]>|ResearchItem[]
	function research_proto:getItems(merge)
		if (merge) then
			local all = {};
			for _, items in self.items do
				all = modkit.table:merge(all, items);
			end
			return all;
		end

		return self.items;
	end

	--- Gets the name of the given `item`, or just returns if given a string.
	---
	---@param item ResearchItem|string
	---@return string?
	function research_proto:resolveName(item)
		if (type(item) == "string") then
			return item;
		elseif (type(item) == "table") then
			return item.name;
		end
	end

	--- Finds a research item. May accept either a filter predicate or a string name.
	---
	--- String names are matched case-insensitive.
	---
	---@param name_or_pred string|fun(item: ResearchItem): ResearchItem|nil
	---@param race RacePrefix|RaceName
	---@return any
	function research_proto:find(name_or_pred, race)
		local src = {};
		race_cfg = modkit.races:find(race);
		if (race_cfg) then
			-- print("race: " .. race_cfg.name);
			src = self:getRaceItems(race_cfg.name);

			if (type(name_or_pred) == "string") then
				return modkit.table.find(src, function (item)
					-- print("is " .. strlower(item.name) .. " == " .. strlower(%name_or_pred) .. "?");
					return strlower(item.name) == strlower(%name_or_pred);
				end);
			else
				return modkit.table.find(src, name_or_pred);
			end
		else
			local item = nil;
			for _, race_name in modkit.races:names() do
				item = self:find(name_or_pred, race_name);
				if (item) then
					return item;
				end
			end
		end
	end

	modkit.research = research_proto;
end