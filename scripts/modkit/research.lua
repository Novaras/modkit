if (modkit == nil) then
	modkit = {};
end

if (modkit.research == nil) then

	if (modkit.table == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end
	
	research_proto = {};

	for k, race in {
		"hiigaran",
		"vaygr",
		"kushan",
		"taiidan"
	} do
		local def_research_path = "data:scripts/races/" .. race .. "/scripts/def_research.lua";
		research = nil; -- make sure unset before import
		dofilepath(def_research_path); -- sets 'research'
	
		modkit.table:merge(
			research_proto,
			modkit.table.map( -- merge it, but also cast all the keys of the research items to lowercase
				research,
				function (research_item)
					local lc = {};
					for k, v in research_item do
						lc[strlower(k)] = v;
					end
					return lc;
				end
			),
			{
				race = race -- also attach the race
			}
		);
	end

	function research_proto:resolveName(item)
		if (type(item) == "string") then
			return item;
		end
		return modkit.table.find(
			self,
			function (research_item) -- research item or a method like resolveName
				return type(research_item) == "table" and research_item.name == %item.name;
			end
		).name; -- we return the name
	end

	modkit.research = research_proto;
end