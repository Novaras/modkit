-- Entry point - bootstraps the other files
-- This is the file you want to load in your scripts with dofilepath, as it will load
-- the package in order, providing the modkit table and a collection of custom sobgroup functions

if (modkit == nil) then -- header guard
	print("\n\nmodkit.lua init...");

	modkit = {};
	
	doscanpath("data:scripts/modkit", "*.lua");

	print("modkit.lua loaded successfully!\n\n");
end
