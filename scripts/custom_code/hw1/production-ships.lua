--- Production ships generic stuff for both ms and carriers
---@class ProductionBaseProto : Ship
---@field single_ship_queue_event_id nil|integer
local hw1_prodship = {
	single_ship_queue_event_id = nil,
};

--- Ensures that only one production ship is building the next research ship.
function hw1_prodship:ensureSingleResShipQueued()
	if (self.single_ship_queue_event_id == nil) then
		-- predicate function
		local isOurBuilder = function (ship)
			return (ship.player.id == %self.player.id) and ship:canBuild() and ship.id ~= %self.id;
		end
		local our_builders = GLOBAL_SHIPS:filter(isOurBuilder); -- all our build capable ships
		for i = 0, 5, 1 do
			res_ship_name = self:racePrefix() .. "_researchship"; -- kus_researchship, tai_researchship
			if (i > 0) then
				res_ship_name = res_ship_name .. "_" .. i;
			end
			-- if we are building this res ship, other ships should be restricted from building it:
			local self_is_building = self:isBuilding(res_ship_name);
			for _, ship in our_builders do
				if (ship.id ~= self.id) then
					if (self_is_building == 1) then
						SobGroup_RestrictBuildOption(ship.own_group, res_ship_name);
					else
						SobGroup_UnRestrictBuildOption(ship.own_group, res_ship_name);
					end
				end
			end
		end
	end
end

--- Does SP restrictions on Kus mothership i.e no hyperspace, no moving
---
---@param restrict 0|1
function hw1_prodship:spRestrict(restrict)
	if (self:racePrefix() == 'kus') then -- preemptively disable fleet HS
		local setting = 1;
		if (restrict == 1) then
			setting = 0;
		end

		-- print("ok, restricting to " .. setting);
		self:canDoAbility(AB_Dock, setting);
		self:canDoAbility(AB_Move, setting);
		SobGroup_AbilityActivate(self.player:shipsGroup(), AB_Hyperspace, setting);
	end
end

function hw1_prodship:tidyBuildMenu()
	if self.player.id == Universe_CurrentPlayer() then
		UI_SetElementVisible("NewResearchMenu", "Platform", 0);
		UI_SetElementVisible("NewResearchMenu", "Utility", 0);
	end
end

function hw1_prodship:create()
	self:tidyBuildMenu();
end

function hw1_prodship:update()
	self:ensureSingleResShipQueued();
	if (self:currentCommand() == COMMAND_Idle and Universe_IsCampaign()) then
		self:spRestrict(1);
	end
end

for _, v in {
	'kus_mothership',
	'kus_carrier',
	'tai_mothership',
	'tai_carrier'
} do
	modkit.compose:addShipProto("kus_mothership", hw1_prodship);
end
