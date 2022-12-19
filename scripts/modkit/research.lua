if (modkit.research == nil) then
	print("research init...");

	if (modkit == nil) then
		modkit = {};
	end

	if (modkit.table == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end

	if (modkit.races == nil) then
		dofilepath("data:scripts/modkit/races.lua");
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
		---@type table<RacePrefix, ResearchItem[]>
		items = {},
	};

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
	---@param race RaceName
	---@return ResearchItem[]
	function research_proto:getRaceItems(race)
		return self.items[race];
	end

	--- Gets all research items, optionally as one merged array.
	---
	---@param merge bool
	---@return table<RacePrefix, ResearchItem[]>|ResearchItem[]
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
		else
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
		race = modkit.races:find(race);
		if (race) then
			print("race: " .. race.name);
			src = self:getRaceItems(race.name);
		else
			src = self:getItems(1);
		end

		if (type(name_or_pred) == "string") then
			return modkit.table.find(src, function (item)
				return strlower(item.name) == %name_or_pred;
			end);
		else
			return modkit.table.find(src, name_or_pred);
		end
	end

	modkit.research = research_proto;
end