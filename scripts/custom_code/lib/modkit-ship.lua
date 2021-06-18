modkit_ship = {
	attribs = function (c, p, s)
		return {
			_stunned = 0,
			_ab_targets = {},
			_current_dmg_mult = 1,
			_current_tumble = { 0, 0, 0 },
			_despawned_at_volume = "despawn-vol-" .. s,
			_reposition_volume = "reposition-vol-" .. s,
			_default_vol = "vol-default-" .. s,
		};
	end
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

function modkit_ship:position(pos)
	if (pos) then
		SobGroup_SetPosition(self.own_group, pos);
	end
	return SobGroup_GetPosition(self.own_group);
end

function modkit_ship:tumble(tumble)
	if (tumble) then
		if (type(tumble) == "table") then
			SobGroup_Tumble(self.own_group, tumble);
			for k, v in tumble do
				self._current_tumble[k] = v;
			end
		elseif (tumble == 0) then -- pass 0 to call _ClearTumble
			SobGroup_ClearTumble(self.own_group);
		end
	end
	return self._current_tumble;
end

function modkit_ship:damageMult(mult)
	if (mult) then
		local restore_mult = (-1 * self._current_dmg_mult) + 2;
		SobGroup_SetDamageMultiplier(self.own_group, restore_mult); -- clear previous
		self._current_dmg_mult = mult;
		SobGroup_SetDamageMultiplier(self.own_group, self._current_dmg_mult);
	end
	return self._current_dmg_mult;
end

function modkit_ship:maxActualHP()
	return SobGroup_MaxHealthTotal(self.own_group);
end

function modkit_ship:currentActualHP()
	return SobGroup_CurrentHealthTotal(self.own_group);
end

function modkit_ship:subsHP(subs_name, HP)
	if (HP) then
		SobGroup_SetHardPointHealth(self.own_group, subs_name, HP);
	end
	return SobGroup_GetHardPointHealth(self.own_group, subs_name);
end


function modkit_ship:distanceTo(other)
	if (type(other.own_group) == "string") then -- assume ship
		return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group);
	else -- a position
		local a = self:position();
		local b = other;
		return sqrt(
			(b[1] - a[1]) ^ 2 +
			(b[2] - a[2]) ^ 2 +
			(b[3] - a[3]) ^ 2
		);
	end
end

function modkit_ship:attack(other)
	return SobGroup_Attack(self.player().id, self.own_group, other.own_group);
end

function modkit_ship:attackPlayer(player)
	return SobGroup_AttackPlayer(self.own_group, player.id);
end

function modkit_ship:move(where)
	if (type(where) == "string") then -- a volume
		SobGroup_Move(self.player().id, self.own_group, where);
	else -- a position
		Volume_AddSphere(self._default_vol, where, 1);
		SobGroup_Move(self.player().id, self.own_group, self._default_vol);
		Volume_Delete(self._default_vol);
	end
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
			return ship.player().id == %self.player().id and ship:canDoAbility(AB_AcceptDocking);
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

function modkit_ship:isProbe()
	return self:isAnyTypeOf({
		"hgn_probe",
		"hgn_ecmprobe",
		"hgn_proximitysensor",
		"vgr_probe",
		"vgr_probe_ecm",
		"kus_probe",
		"kus_proximitysensor",
		"tai_probe",
		"tai_proximitysensor"
	});
end

-- need to do this for above fns also...
modkit.ship_types = {};

-- res ship types
local res_ship_types = {};
for _, race in { "kus", "tai" } do
	res_ship_types[getn(res_ship_types) + 1] = race .. "_researchship";
	for i = 1, 5 do
		res_ship_types[getn(res_ship_types) + 1] = race .. "_researchship_" .. i;
	end
end
modkit.ship_types.research_ships = res_ship_types;

function modkit_ship:isResearchShip()
	return self:isAnyTypeOf(self.ship_types.research_ships);
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
		return SobGroup_IsDockedSobGroup(self.own_group, with.own_group);
	end
	return SobGroup_IsDocked(self.own_group);
end

function modkit_ship:attacking(target)
	local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. COMMAND_Attack);
	SobGroup_GetCommandTargets(targets_group, self.own_group, COMMAND_Attack);
	if (target) then
		return SobGroup_GroupInGroup(target.own_group, targets_group) == 1;
	else
		return SobGroup_Count(targets_group) > 0;
	end
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

function modkit_ship:playEffect(name)
	FX_PlayEffect(name, self.own_group, 1);
end

-- === Spawning ===

function modkit_ship:spawn(spawn, volume)
	if (spawn == 1) then
		SobGroup_Spawn(self.own_group, self._despawned_at_volume);
		Volume_Delete(self._despawned_at_volume);
	elseif (spawn == 0) then
		Volume_AddSphere(self._despawned_at_volume, self:position(), 1);
		SobGroup_Despawn(self.own_group);
	end
end

function modkit_ship:spawnShip(type, position, spawn_group)
	position = position or self:position();
	local volume_name = "spawner-vol-" .. self.id;
	local spawn_group = spawn_group or SobGroup_Fresh("spawner-group-" .. self.id);
	Volume_AddSphere(volume_name, position, 0);
	SobGroup_SpawnNewShipInSobGroup(self.player().id, type, "-", spawn_group, volume_name);
	Volume_Delete(volume_name);
	return spawn_group;
end

modkit.compose:addBaseProto(modkit_ship);

print("go fancy");