-- campaign.lua: utils for writing campaign scripts.
-- By: Fear (Novaras)

if (H_CAMPAIGN == nil) then
	if (modkit == nil) then modkit = {}; end

	print("[modkit] campaign init...");
	modkit.campaign = {};
	doscanpath("data:scripts/modkit/campaign", "*.lua");
	print("[modkit] campaign init complete");

	H_CAMPAIGN = 1;
end