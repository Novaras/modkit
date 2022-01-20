if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (GLOBAL_TEAMS == nil) then
	GLOBAL_TEAMS = modkit.MemGroup.Create("mg-global-teams");

	modkit_teams_proto = {
		players = {}
	};
end