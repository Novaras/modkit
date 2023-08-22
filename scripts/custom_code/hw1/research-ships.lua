---@class ResShipAttribs
---@field next_to_build_index integer
---@field spinning 0|1
---@field spin_start_event_id 'nil'|integer

--- Proto for res ships for both tai and kus (only for res ship 0, which drives the others).
---@class ResShipProto : Ship, AIParader
res_ships_proto = {
	attribs = function ()
		return {
			next_to_build_index = 0,
			spinning = 0,
			spin_start_event_id = nil,
		};
	end
};

-- ==== hooks ====

function res_ships_proto:load(ship_type, player)
	-- restrict build opt for all ships except the first one
	%res_ships_proto:setNextToBuild(ship_type, player);
end

function res_ships_proto:update()
	self:setNextToBuild(); -- set all restricted except the next to build
	self:dockAnyUndocked();
	self:manageSubsHP();
	self:manageEngineGlow();
	-- self:spinIfComplete(); -- looks bad
end

function res_ships_proto:destroy()
	for _, res_ship in self:getOurResShips() do -- kill all other res ship also
		if (res_ship:HP() > 0) then
			res_ship:HP(0);
		end
	end
	self:setNextToBuild();
end

-- ==== custom methods ====

function res_ships_proto:manageEngineGlow()
	local docked = self:dockedAuxHubCount();
	if (docked > 0) then
		SobGroup_ManualEngineGlow(self.own_group, 0);
	else
		SobGroup_AutoEngineGlow(self.own_group);
	end
end

function res_ships_proto:manageSubsHP()
	local alive_ships = modkit.table.length(self:getOurResShips());
	local hp_to_add = max(0.1 * (alive_ships - 1), 0); -- `0.1 * (N - 1)` or `0`
	self:subsHP("Research Module", 0.5 + hp_to_add);
end

function res_ships_proto:getOurResShips()
	return GLOBAL_SHIPS:filter(function (ship)
		return (ship.player.id == %self.player.id) and ship:isResearchShip() and ship:HP() > 0;
	end);
end

function res_ships_proto:restrictAll(ship_type, player)
	local race_prefix;
	if (ship_type) then -- still in load phase
		race_prefix = strsub(ship_type, 0, 3);
	else
		race_prefix = self:race();
	end
	player = player or self.player;
	player:restrictBuildOption({
		race_prefix .. "_researchship",
		race_prefix .. "_researchship_1",
		race_prefix .. "_researchship_2",
		race_prefix .. "_researchship_3",
		race_prefix .. "_researchship_4",
		race_prefix .. "_researchship_5"
	}, 1);
end

function res_ships_proto:setNextToBuild(ship_type, player)
	-- next to build index is number alive (since they are 0-indexed)
	if (player) then -- unless we got a direct player, meaning we are in load time, so next = 0
		self.next_to_build_index = 0;
	else
		self.next_to_build_index = modkit.table.length(self:getOurResShips());
	end
	self:restrictAll(ship_type, player);
	if (self.next_to_build_index == 6) then
		return nil;
	end
	local suffix = "";
	if (self.next_to_build_index > 0) then
		suffix = "_" .. self.next_to_build_index;
	end
	ship_to_unrestrict = (ship_type or self.type_group) .. suffix;
	player = player or self.player;
	player:restrictBuildOption({ship_to_unrestrict}, 0);
end

function res_ships_proto:dockAnyUndocked()
	for _, res_ship in self:getOurResShips() do
		if (res_ship.own_group ~= self.own_group and res_ship:docked() ~= 1) then -- if not docked, dock it and stay docked
			res_ship:dock(self, 1);
		end
	end
end

function res_ships_proto:dockedAuxHubCount()
	return modkit.table.length(			-- return length of...
		modkit.table.filter(			-- ... the list of our res ships, filtered for only those which are docked
			self:getOurResShips(),
			function (res_ship)
				return res_ship:docked() == 1;
			end
		)
	);
end

-- function res_ships_proto:paradeIfAI()
-- 	if (self.player:isHuman() == nil) then
-- 		local target = GLOBAL_SHIPS:find( -- find a mothership, if that fails, find a carrier
-- 			function (ship)
-- 				return ship.player.id == %self.player.id and ship:isMothership();
-- 			end
-- 		) or GLOBAL_SHIPS:find(
-- 			function (ship)
-- 				return ship.player.id == %self.player.id and ship:isCarrier();
-- 			end
-- 		);
-- 		if (target) then
-- 			self:parade(target);
-- 		end
-- 	end
-- end

---@deprecated MAD animation looks ass from far away
--- Spins kushan research ships when they form a complete ring.
function res_ships_proto:spinIfComplete()
	-- if we have all the ships, aren't already spinning, are kushan, and aren't moving:
	if (self:race() == "kus" and self.spinning == 0 and self:dockedAuxHubCount() == 5 and self:actualSpeedSq() == 0) then
		local res_ships = self:getOurResShips(); -- poll this on our normal tick rate, it won't change much nor does it need precision
		-- schedule every 60 seconds, call `SobGroup_SetMadState()` on all ships with "NIS00":
		self.spin_start_event_id = modkit.scheduler:every(60 / modkit.scheduler.seconds_per_tick, function ()
			for _, res_ship in %res_ships do
				res_ship:madState("NIS00");
			end
		end);
		self.spinning = 1;
	elseif (self.spin_start_event_id ~= nil) then -- otherwise if we have a spin event scheduled, clear it
		modkit.scheduler:clear(self.spin_start_event_id);
		self.spin_start_event_id = nil;
		self.spinning = 0;
	end
end

modkit.compose:addShipProto("kus_researchship", res_ships_proto);
modkit.compose:addShipProto("tai_researchship", res_ships_proto);