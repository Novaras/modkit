function modkit_scheduler_spawn()
	if (H_SOBGROUP == nil) then
		dofilepath("data:scripts/modkit/sobgroup.lua");
	end
	print("spawning modkit_scheduler...");
	local group = SobGroup_Fresh("modkit__scheduler_controller");
	local volume = Volume_Fresh("modkit__scheduler_controller_vol");
	SobGroup_SpawnNewShipInSobGroup(-1, "modkit_scheduler", group, group, volume);
	print("modkit_scheduler spawn finished, check: (c: " .. SobGroup_Count(group) .. ", g: '" .. group .. "', pid: " .. -1 .. ")");
	Rule_Remove("modkit_scheduler_spawn");
end