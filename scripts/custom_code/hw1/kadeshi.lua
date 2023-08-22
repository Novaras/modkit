---@class MultiBeamProto : Ship
local multibeam_frigate_proto = {};

function multibeam_frigate_proto:update()
	if (self.player.id ~= 0) then
		-- Updated mission 8 uses the tactics to control attack.  If is in OffensiveROE (0) then attack.
		if (self:ROE() == OffensiveROE) then
			self:attackPlayer(0);
		end
	end
end

modkit.compose:addShipProto("kad_multibeamfrigate", multibeam_frigate_proto);

-- === swarmers ===

-- just call the stock functions for now
dofilepath("data:ship/kad_swarmer/kad_swarmer.lua");

---@class SwarmerProto : Ship
local swarmer_proto = {};

function swarmer_proto:create()
	createSwarmerFuel(self.own_group, self.player.id, self.id);
end

function swarmer_proto:update()
	updateSwarmerFuel(self.own_group, self.player.id, self.id);
end

function swarmer_proto:destroy()
	destroySwarmerFuel(self.own_group, self.player.id, self.id);
end

modkit.compose:addShipProto("kad_swarmer", swarmer_proto);
modkit.compose:addShipProto("kad_advancedswarmer", swarmer_proto);