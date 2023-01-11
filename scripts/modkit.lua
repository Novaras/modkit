-- Entry point - bootstraps the other files
-- This is the file you want to load in your scripts with dofilepath, as it will load
-- the package in order, providing the modkit table and a collection of custom sobgroup functions

--- Loads all modkit files, order is not guaranteed.
---
--- This function should only be invoked at the beginning of game time (`deathmatch.lua` or `singleplayerflow.lua` are good targets).
loadModkit = loadModkit or function ()
	modkit = {};
	doscanpath("data:scripts/modkit", "*.lua");
end

if (modkit == nil) then -- header guard
	print("\n\nmodkit.lua init...");
	loadModkit();
	print("modkit.lua loaded successfully!\n\n");
end
