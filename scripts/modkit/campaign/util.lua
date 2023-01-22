if (H_CAMPAIGN_MISSION_UTIL == nil) then
	local util = {};

	function util:assignPlayerColours()
		local base_colour = {};
		local stripe_colour = {};
		local badge_name = "";
		base_colour = Profile_GetTeamColourBase();
		stripe_colour = Profile_GetTeamColourStripe();
		badge_name = Profile_GetTeamColourBadge();
		if (badge_name ~= "") then
			print("singlePlayerLevelLoaded: found profile team colours - setting now");
			print("WARNING: badge: "..badge_name);
			Player_SetTeamColourTheme(0, base_colour, stripe_colour, badge_name, base_colour, "");
		end
	end

	modkit.campaign.util = util;
	H_CAMPAIGN_MISSION_UTIL = 1;
end