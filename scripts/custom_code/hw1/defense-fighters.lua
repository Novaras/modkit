--- Returns a new fresh selection with the name `name`.
---
---@param name string
---@return string
function Selection_Fresh(name)
	Selection_Create(name);
	return name;
end


-- fairly annoying, missiles don't seem selectable aside from through `Select_` functions, one of which
-- seems to be custom made for this script: `Selection_GetMissiles`
-- this means we can't really rely on modkit

---@class DefenseFighterProto : Ship
defense_fighter_proto = {
	nearby_radius = 4500,
	-- guard_sphere_positions = modkit.shapes:icosahedron(),
	guard_pos_index = 1
};

function defense_fighter_proto:nextGuardPos()
	local pos_offset = modkit.shapes:icosahedron()[self.guard_pos_index];
	self.guard_pos_index = self.guard_pos_index + 1;
	if (self.guard_pos_index > modkit.table.length(modkit.shapes:icosahedron())) then
		self.guard_pos_index = 1;
	end
	return pos_offset;
end

function defense_fighter_proto:posStr()
	local p = self:position();
	return p[1] .. "," .. p[2] .. "," .. p[3];
end

function defense_fighter_proto:nearbyEnemyMissileSelection()
	-- selection functions not well understood, mostly referencing stock code:

	local all_missiles = Selection_Fresh("all-missiles-" .. self.own_group);

	-- select universe missiles
	if (Selection_GetMissiles(all_missiles) == 0) then
		return nil;
	end

	--- filter only within `nearby_radius`
	if (Selection_FilterInclude(all_missiles, all_missiles, "NearPoint", self:posStr(), tostring(defense_fighter_proto.nearby_radius)) == 0) then
		return nil;
	end

	-- now filter out allied missiles
	for _, player in GLOBAL_PLAYERS:all() do
		if (player:alliedWith(self.player)) then
			Selection_FilterExclude(all_missiles, all_missiles, "PlayerOwner", player.id, "");
		end
	end
	return all_missiles;
end

function defense_fighter_proto:guardTargets()
	local targets = {};
	for _, ship in GLOBAL_SHIPS:all() do
		 if (self:guarding(ship)) then
			 modkit.table.push(targets, ship);
		 end
	end
	return targets;
end

function defense_fighter_proto:attackNearbyEnemyMissiles()
	local enemy_missiles = self:nearbyEnemyMissileSelection();
	if (enemy_missiles and self:ROE() ~= PassiveROE) then
		SobGroup_AttackSelection(self.player.id, self.own_group, enemy_missiles, 1);
	end
end

function defense_fighter_proto:strictGuardDistance()
	if (modkit.table.length(self:guardTargets()) > 0) then -- means we are in an attack phase
		if (self:distanceTo(self:guardTargets()[1]) > 1000) then
			self:move(self:nextGuardPos()); -- script tick is 1s, should be fine
		end
	end
end

function defense_fighter_proto:update()
	if (self:attacking() or self:guarding()) then
		self:attackNearbyEnemyMissiles();
		if (self:guarding()) then
			self:strictGuardDistance();
		end
	end
end

modkit.compose:addShipProto("tai_defensefighter", defense_fighter_proto);