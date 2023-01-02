base_research = nil 
base_research = {
	-- this tech is used so we can tell which race a player is during gametime
	{
		Name = "RaceTaiidan",
		RequiredResearch = "",
		RequiredSubSystems = "",
		Cost = 0,
		Time = 0,
		DisplayedName = "RaceTaiidan",
		ShortDisplayedName = "RaceIndicator",
		DisplayPriority = 99,
		Description = "Used to indicate race via research",
		Icon = Icon_Tech,
	}
}

-- Add these items to the research tree!
for _, e in base_research do
	research[res_index] = e;
	res_index = res_index + 1;
end

print("MODKIT INDICATOR TECH DONE FOR TAIIDAN");

base_research = nil;
