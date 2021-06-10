modkit_ship = {
	attribs = {
		_stunned = 0,
		_ab_targets = {}
	}
};

-- === Util ===

function modkit_ship:age()
	return (Universe_GameTime() - self.created_at);
end

function modkit_ship:HP(hp)
	if (hp) then
		SobGroup_SetHealth(self.own_group, hp);
	end
	return SobGroup_GetHealth(self.own_group);
end

function modkit_ship:speed(speed)
	if (speed) then
		SobGroup_SetSpeed(self.own_group, speed);
	end
	return SobGroup_GetSpeed(self.own_group);
end

function modkit_ship:maxActualHP()
	return SobGroup_MaxHealthTotal(self.own_group);
end

function modkit_ship:currentActualHP()
	return SobGroup_CurrentHealthTotal(self.own_group);
end

function modkit_ship:subsHP(subs_name)
	if (subs_name) then
		SobGroup_SetHardPointHealth(self.own_group, subs_name);
	end
	return SobGroup_GetHardPointHealth(self.own_group, subs_name);
end


function modkit_ship:distanceTo(other)
	return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group);
end

function modkit_ship:attack(other)
	return SobGroup_Attack(self.own_group, other.own_group);
end

function modkit_ship:attackPlayer(player)
	return SobGroup_AttackPlayer(self.own_group, player.id);
end

function modkit_ship:guard(other)
	return SobGroup_GuardSobGroup(self.own_group, other.own_group);
end

function modkit_ship:parade(other, mode)
	mode = mode or 0;
	return SobGroup_ParadeSobGroup(self.own_group, other.own_group, mode);
end

function modkit_ship:dock(target, stay_docked)
	if (target == nil) then -- if no target, target = closest ship
		local all_our_production_ships = GLOBAL_SHIPS:filter(function (ship)
			return ship.player.id == %self.player.id and ship:canDoAbility(AB_AcceptDocking);
		end);
		sort(all_our_production_ships, function (ship_a, ship_b)
			return %self:distanceTo(ship_a) < %self:distanceTo(ship_b);
		end);
		target = all_our_production_ships[1];
	end
	if (stay_docked) then
		SobGroup_DockSobGroupAndStayDocked(self.own_group, target.own_group);
	else
		SobGroup_DockSobGroup(self.own_group, target.own_group);
	end
end

-- === Attack family queries ===

function modkit_ship:attackFamily()
	if (attackFamily == nil) then
		dofilepath("data:scripts/familylist.lua");
	end
	for i, family in attackFamily do
		if (SobGroup_AreAnyFromTheseAttackFamilies(self.own_group, family.name) == 1) then
			return strlower(family.name);
		end
	end
end

function modkit_ship:isAnyFamilyOf(families)
	for k, v in families do
		if (self:attackFamily() == v) then
			return 1;
		end
	end
end

function modkit_ship:isFighter()
	return self:isAnyFamilyOf({
		"fighter",
		"fighter_hw1"
	});
end

function modkit_ship:isCorvette()
	return self:isAnyFamilyOf({
		"corvette",
		"corvette_hw1"
	});
end

function modkit_ship:isFrigate()
	return self:isAnyFamilyOf({
		"frigate"
	});
end

function modkit_ship:isCapital()
	return self:isAnyFamilyOf({
		"smallcapitalship",
		"bigcapitalship",
		"mothership"
	});
end

-- === Ship type queries ===

function modkit_ship:isAnyTypeOf(ship_types)
	for k, v in ship_types do
		if (self.type_group == v) then
			return v;
		end
	end
end

function modkit_ship:isSalvager()
	return self:isAnyTypeOf({
		"tai_salvagecorvette",
		"kus_salvagecorvette"
	});
end

function modkit_ship:isDestroyer()
	return self:isAnyTypeOf({
		"hgn_destroyer",
		"vgr_destroyer",
		"kus_destroyer",
		"tai_destroyer"
	});
end

function modkit_ship:isCruiser()
	return self:isAnyTypeOf({
		"hgn_battlecruiser",
		"vgr_battlecruiser",
		"kus_heavycruiser",
		"tai_heavycruiser"
	});
end

function modkit_ship:isCarrier()
	return self:isAnyTypeOf({
		"hgn_carrier",
		"vgr_carrier",
		"kus_carrier",
		"tai_carrier"
	});
end

function modkit_ship:isMothership()
	return self:isAnyTypeOf({
		"hgn_mothership",
		"vgr_mothership",
		"kus_mothership",
		"tai_mothership"
	});
end

function modkit_ship:isResearchShip()
	local types = {};
	for _, race in { "kus", "tai" } do
		for i = 1, 5 do
			types[getn(types) + 1] = race .. "_researchship_" .. i;
		end
	end
	return self:isAnyTypeOf(types);
end

-- === State queries ===

--- Get or set the stunned status of the ship.
-- Returns whether or not the ship should currently be stunned (if stunned previously via :stunned)
function modkit_ship:stunned(stunned)
	if (stunned ~= nil) then
		self._stunned = stunned;
	end
	SobGroup_SetGroupStunned(self.own_group, stunned);
	return self._stunned;
end

function modkit_ship:docked(with)
	if (with) then
		return SobGroup_SobGroupDocked(self.own_group, with.own_group);
	end
	return SobGroup_Docked(self.own_group);
end

-- === Ability stuff ===

function modkit_ship:canDoAbility(ability, enable)
	enable = enable or SobGroup_CanDoAbility(self.own_group, ability);
	SobGroup_AbilityActivate(self.own_group, ability, enable);
	return SobGroup_CanDoAbility(self.own_group, ability);
end

function modkit_ship:canHyperspace(enable)
	return self:canDoAbility(AB_Hyperspace, enable);
end

function modkit_ship:canHyperspaceViaGate(enable)
	return self:canDoAbility(AB_HyperspaceViaGate, enable);
end

function modkit_ship:isDoingAbility(ability)
	return SobGroup_IsDoingAbility(self.own_group, ability);
end

function modkit_ship:isDocking()
	return self:isDoingAbility(AB_Dock);
end

-- === FX stuff ===

function modkit_ship:startEvent(which)
	FX_StartEvent(self.own_group, which);
end

function modkit_ship:stopEvent(which)
	FX_StopEvent(self.own_group, which);
end

modkit.compose:addBaseProto(modkit_ship);

print("go fancy");