base_research = nil 
base_research = {
	-- this tech is used so we can tell which race a player is during gametime
	{
		Name = "RaceKushan",
		RequiredResearch = "",
		RequiredSubSystems = "",
		Cost = 0,
		Time = 0,
		DisplayedName = "RaceKushan",
		ShortDisplayedName = "RaceIndicator",
		DisplayPriority = 999,
		Description = "Used to indicate race via research",
		Icon = Icon_Tech,
	}
}

-- Add these items to the research tree!
for _, e in base_research do
	print("adding " .. e.Name .. " index is " .. 9999);
	research[9999] = e;
	res_index = res_index + 1;
end

print("MODKIT INDICATOR TECH DONE FOR KUSHAN");

base_research = nil;
