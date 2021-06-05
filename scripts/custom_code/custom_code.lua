-- custom_code.lua
-- Imports all the custom attrib code from the race files.
-- Do not edit unless you know what you're doing.

if (H_CUSTOM_CODE == nil) then
	CUSTOM_CODE = {};

	doscanpath("data:scripts/custom_code/hgn", "*.lua");
	doscanpath("data:scripts/custom_code/vgr", "*.lua");
	doscanpath("data:scripts/custom_code/kus", "*.lua");
	doscanpath("data:scripts/custom_code/tai", "*.lua");

	print("custom_code init");
	H_CUSTOM_CODE = 1;
end