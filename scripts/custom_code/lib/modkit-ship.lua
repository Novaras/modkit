---@alias CapturableModifier
---| '0' # Ship cannot be captured
---| '1' # Ship can be captured
---| '2' # Ship can be captured (used by stock code)

---@class ShipAttribs : Attribs
---@field _stunned number
---@field _ab_targets table
---@field _current_dmg_mult number
---@field _current_tumble Vec3
---@field _despawned_at_volume string
---@field _reposition_volume string
---@field _default_vol string
---@field _auto_launch '0'|'1'
---@field _visibility table<Player, Visibility>
---@field _capturable_mod CapturableModifier
---@field _ghosted bool
---@field _invulnerable bool

---@class Ship : Base, ShipAttribs
modkit_ship = {
	---@param g string
	---@param p integer
	---@param s integer
	---@return ShipAttribs
	attribs = function (g, p, s)
		return {
			_stunned = 0,
			_ab_targets = {},
			_current_dmg_mult = 1,
			_current_tumble = { 0, 0, 0 },
			_despawned_at_volume = "despawn-vol-" .. s,
			_reposition_volume = "reposition-vol-" .. s,
			_default_vol = "vol-default-" .. s,
			_auto_launch = 1,
			_visibility = {
				default = VisNone
			},
			_capturable_mod = 1
		};
	end,
};
-- === Util ===

function modkit_ship:age()
	return (Universe_GameTime() - self.created_at);
end

--- Sets the HP of this ship to the given `hp` fraction (between 0 and 1)
---
---@param hp number
---@return number
function modkit_ship:HP(hp)
	if (hp) then
		SobGroup_SetHealth(self.own_group, hp);
	end
	return SobGroup_GetHealth(self.own_group);
end

---@return bool
function modkit_ship:alive()
	return self:count() > 0 and self:HP() > 0;
end

function modkit_ship:die()
	self:HP(0);
end

--- Gets or optionally sets the ship's current speed (as a proportion, `0` being `0` and `1` being default max speed).
---
--- Values exceeding `1` may be passed.
---
---@param speed number
---@return number
function modkit_ship:speed(speed)
	if (speed) then
		SobGroup_SetSpeed(self.own_group, speed);
	end
	return SobGroup_GetSpeed(self.own_group);
end

--- Returns the ship's 'actual' speed, which is its current speed in this moment _squared_.
--- Note that formations, stances, and other effects may hinder or help ships fly at their max speeds as per their ship files.
---
---@return number
function modkit_ship:actualSpeedSq()
	return SobGroup_GetActualSpeed(self.own_group);
end

--- Returns the ship's current position (or the center position of the ship's batch squad).
--- If `pos` is supplied, it will set the position of the ship instantly.
---
---@param pos Position
---@return Position
function modkit_ship:position(pos)
	if (pos) then
		SobGroup_SetPosition(self.own_group, pos);
	end
	return SobGroup_GetPosition(self.own_group);
end

--- Gets or optionally sets / clears the ship's tumble. In modkit, this vector is tracked.
---
--- Pass `0` to clear the current tumble.
---
---@param tumble Vec3
---@return Vec3
function modkit_ship:tumble(tumble)
	if (tumble) then
		if (type(tumble) == "table") then
			SobGroup_Tumble(self.own_group, tumble);
			for k, v in tumble do
				self._current_tumble[k] = v;
			end
		elseif (tumble == 0) then -- pass 0 to call _ClearTumble
			SobGroup_ClearTumble(self.own_group);
			for k, _ in self._current_tumble do
				self._current_tumble[k] = 0;
			end
		end
	end
	return self._current_tumble;
end

--- Sets the damage multiplier for this ship.
---
--- The multiplier is always relative to 1 (its reset every time you call this fn), unless `relative` is non-nil.
---
---@param mult number
---@param relative bool
---@return number # the current dmg mult after being set
function modkit_ship:damageMult(mult, relative)
	if (mult) then
		if (relative == nil) then
			local restore_mult = (-1 * self._current_dmg_mult) + 2;
			SobGroup_SetDamageMultiplier(self.own_group, restore_mult); -- clear previous
		end
		self._current_dmg_mult = mult;
		SobGroup_SetDamageMultiplier(self.own_group, self._current_dmg_mult);
	end
	return self._current_dmg_mult;
end

---
---@param mult_type RuntimeShipMultiplier
---@param mult number
function modkit_ship:multiplier(mult_type, mult)
	if (mult_type == "BuildSpeed") then
		return SobGroup_SetBuildSpeedMultiplier(self.own_group, mult);
	elseif (mult_type == "MaxSpeed") then
		return self:speed(mult);
	elseif (mult_type == "WeaponDamage") then
		return self:damageMult(mult);
	end
end

function modkit_ship:maxActualHP()
	return SobGroup_MaxHealthTotal(self.own_group);
end

function modkit_ship:currentActualHP()
	return SobGroup_CurrentHealthTotal(self.own_group);
end

--- Gets and optionally sets the HP of the named subsystem on this ship.
---
---@param subs_name string
---@param HP number
---@return number
function modkit_ship:subsHP(subs_name, HP)
	if (HP) then
		SobGroup_SetHardPointHealth(self.own_group, subs_name, HP);
	end
	return SobGroup_GetHardPointHealth(self.own_group, subs_name);
end

--- Returns whether or not this ship host's the named subsystem.
---
---@param subs_name string
---@return '0'|'1'
function modkit_ship:hasSubsystem(subs_name)
	return SobGroup_HasSubsystem(self.own_group, subs_name);
end

--- Returns the distance between this ship and the given other ship, or the average position if given multiple others.
---
---@param other Ship | Ship[]
---@return number
function modkit_ship:distanceTo(other)
	if (type(other.own_group) == "string") then -- assume ship
		return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group);
	else -- ship group
		local a = self:position();
		local b = SobGroup_GetPosition(SobGroup_FromShips(SobGroup_Fresh("__"), other));
		return sqrt(
			(b[1] - a[1]) ^ 2 +
			(b[2] - a[2]) ^ 2 +
			(b[3] - a[3]) ^ 2
		);
	end
end

--- Returns the squad (batch) size of the ship, which may be a squadron.
---
---@return integer
function modkit_ship:squadSize()
	return SobGroup_Count(self.own_group);
end

function modkit_ship:buildCost()
	return SobGroup_GetStaticF(self.ship_type, "buildCost") / self:squadSize();
end

function modkit_ship:buildTime()
	return SobGroup_GetStaticF(self.ship_type, "buildTime");
end

-- === Commands ===

function modkit_ship:customCommand(target)
	if (target) then
		return SobGroup_CustomCommandTargets(self.own_group);
	else
		return SobGroup_CustomCommand(self.own_group);
	end
end

function modkit_ship:attack(targets)
	if (type(targets) == "string") then
		SobGroup_Attack(self.player.id, self.own_group, targets);
	elseif (targets.own_group) then
		return SobGroup_Attack(self.player.id, self.own_group, targets.own_group);
	else
		local temp_group = SobGroup_FromShips(self.own_group .. "-temp-attack-group", targets);
		SobGroup_Attack(self.player.id, self.own_group, temp_group);
	end
end

function modkit_ship:attackPlayer(player)
	return SobGroup_AttackPlayer(self.own_group, player.id);
end

--- Causes this ship to begin capturing `targets`, which can be a single ship or a table of ships.
---
---@param targets Ship | Ship[]
function modkit_ship:capture(targets)
	if (targets.own_group) then
		SobGroup_CaptureSobGroup(self.own_group, targets.own_group);
	else
		local temp_group = SobGroup_FromShips(self.own_group .. "-temp-capture-group", targets);
		SobGroup_CaptureSobGroup(self.own_group, temp_group);
	end
end

--- Causes this ship to begin salvaging `targets`, which can be a single ship or a table of ships.
---
---@param targets Ship | Ship[]
function modkit_ship:salvage(targets)
	if (targets.own_group) then
		SobGroup_SalvageSobGroup(self.own_group, targets.own_group);
	else
		local temp_group = SobGroup_FromShips(self.own_group .. "-temp-salvage-group", targets);
		SobGroup_SalvageSobGroup(self.own_group, temp_group);
	end
end

--- Makes the ship stop (issues a stop command).
---
function modkit_ship:stop()
	SobGroup_Stop(self.player.id, self.own_group);
end

function modkit_ship:move(where)
	if (type(where) == "string") then -- a volume
		SobGroup_Move(self.player.id, self.own_group, where);
	else -- a position
		Volume_AddSphere(self._default_vol, where, 1);
		SobGroup_MoveToPoint(self.player.id, self.own_group, where);
		Volume_Delete(self._default_vol);
	end
end

--- Makes this ship guard `target`, which may be one or multiple other ships.
---
---@param target Ship | Ship[]
function modkit_ship:guard(target)
	if (target.own_group) then
		self._guard_group = target.own_group;
	else -- collection of ships
		self._guard_group = SobGroup_FromShips(self.own_group .. "_guard_group", target);
	end
	return SobGroup_GuardSobGroup(self.own_group, self._guard_group);
end

function modkit_ship:parade(other, mode)
	mode = mode or 0;
	return SobGroup_ParadeSobGroup(self.own_group, other.own_group, mode);
end

--- Causes the ship to dock with `target`. If stay docked is not `nil`, the ship will stay docked.
---
--- If `target` is `nil`, the ship will dock with any valid target.
---
---@param target nil|Ship
---@param stay_docked bool
function modkit_ship:dock(target, stay_docked)
	if (target == nil) then -- if no target, target = closest ship
		SobGroup_DockSobGroupWithAny(self.own_group);
	else
		if (stay_docked) then
			SobGroup_DockSobGroupAndStayDocked(self.own_group, target.own_group);
		else
			SobGroup_DockSobGroup(self.own_group, target.own_group);
		end
	end
end

--- Causes this ship to hyperspace to the given point.
---
---@param to Position
function modkit_ship:hyperspace(to)
	SobGroup_HyperspaceTo(to);
end

--- Gets or optionally sets the ship's auto-launch behavior. `1` for auto-launch, `0` for stay-docked manual launching.
---
---@param auto_launch AutoLaunchStatus
---@return AutoLaunchStatus
function modkit_ship:autoLaunch(auto_launch)
	if (auto_launch) then
		SobGroup_SetAutoLaunch(self.own_group, auto_launch);
		self._auto_launch = auto_launch;
	end
	return self._auto_launch;
end

--- Gets and optionally sets the ship's [Rules Of Engagement](https://github.com/HWRM/KarosGraveyard/wiki/Variable;-ROE).
---
---@param new_ROE ROE
---@return ROE
function modkit_ship:ROE(new_ROE)
	if (new_ROE) then
		SobGroup_SetROE(self.own_group, new_ROE);
	end
	return SobGroup_GetROE(self.own_group);
end

--- Gets and optionally sets the ship's [Stance](https://github.com/HWRM/KarosGraveyard/wiki/Variable;-Stance).
---
---@param new_stance Stance
---@return Stance
function modkit_ship:stance(new_stance)
	if (new_stance) then
		SobGroup_SetStance(self.own_group, new_stance);
	end
	return SobGroup_GetStance(self.own_group);
end

--- Causes this ship to be 'ghosted', which is pretty much akin to no-clip (no collisions will affect this ship).
---
---@param enabled '0'|'1'
---@return bool
function modkit_ship:ghost(enabled)
	if (enabled == 0) then
		self._ghosted = nil;
	else
		self._ghosted = 1;
	end
	SobGroup_SetGhost(self.own_group, enabled);
	return self._ghosted;
end

--- Launches `docked` from this ship, if `docked` is currently docked with this ship.
---
---@param docked? Ship
---@return nil
function modkit_ship:launch(docked)
	return SobGroup_Launch(docked.own_group, self.own_group);
end

--- Returns the 3-character race string of the ship.
--- **Note: This is the host race of the _ship type_, as opposed to the player's race.**
---
---@return string
function modkit_ship:race()
	return strsub(self.ship_type, 0, 3);
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

---@return bool
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

---@param ship_types string[]
---@return bool
function modkit_ship:isAnyTypeOf(ship_types)
	for k, v in ship_types do
		if (self.ship_type == v) then
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
		"tai_carrier",
		"tur_p1mothership"
	});
end

function modkit_ship:isCapturer()
	return self:isCaptureFrigate() or self:isSalvager();
end

function modkit_ship:isCaptureFrigate()
	return self:isAnyTypeOf({
		"hgn_marinefrigate",
		"vgr_infiltratorfrigate"
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

function modkit_ship:isResearchShip()
	return self:isAnyTypeOf({
		"kus_researchship",
		"kus_researchship_1",
		"kus_researchship_2",
		"kus_researchship_3",
		"kus_researchship_4",
		"kus_researchship_5",
		"tai_researchship",
		"tai_researchship_1",
		"tai_researchship_2",
		"tai_researchship_3",
		"tai_researchship_4",
		"tai_researchship_5"
	});
end

function modkit_ship:isResourceCollector()
	return self:isAnyTypeOf({
		"hgn_resourcecollector",
		"vgr_resourcecollector",
		"kus_resourcecollector",
		"tai_resourcecollector"
	});
end

function modkit_ship:isDrone()
	if (self.drone_types == nil) then
		local drone_types = {};
		for i = 0, 13 do
			drone_types[modkit.table.length(drone_types)] = "kus_drone" .. i;
		end
		self.drone_types = drone_types;
	end
	return self:isAnyTypeOf(self.drone_types);
end

-- === State queries ===

---
---@param invulnerable '0'|'1'
---@return bool
function modkit_ship:invulnerable(invulnerable)
	if (invulnerable) then
		if (invulnerable ~= 0) then
			self._invulnerable = invulnerable;
		else
			self._invulnerable = nil;
		end
		SobGroup_SetInvulnerability(self.own_group, self._invulnerable or 0);
	end
	return self._invulnerable;
end

--- Get or set the stunned status of the ship.
-- Returns whether or not the ship should currently be stunned (if stunned previously via :stunned)
function modkit_ship:stunned(stunned)
	if (stunned ~= nil) then
		self._stunned = stunned;
	end
	SobGroup_SetGroupStunned(self.own_group, stunned);
	return self._stunned;
end

--- Returns whether or not this ship is docked with anything. Optionally, checks if this ship is docked with a specific ship.
---@param with Ship
---@return '1'|'nil'
function modkit_ship:docked(with)
	if (with) then
		return SobGroup_IsDockedSobGroup(self.own_group, with.own_group) == 1;
	end
	return SobGroup_IsDocked(self.own_group) == 1;
end

--- Returns `1` if this ship is attacking anything, else `nil`. If `target` is provided, check instead if
-- this ship is attacking that target (instead of anything).
---@param target Ship | 'nil'
---@return bool
function modkit_ship:attacking(target)
	if (target) then
		local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. COMMAND_Attack);
		SobGroup_GetCommandTargets(targets_group, self.own_group, COMMAND_Attack);
		return SobGroup_GroupInGroup(target.own_group, targets_group) == 1;
	else
		return SobGroup_AnyAreAttacking(self.own_group) == 1;
	end
end

--- Returns whether or not this ship is currently capturing anything, or just the specified `target` if supplied.
---@param target Ship | 'nil'
---@return bool
function modkit_ship:capturing(target)
	if (target) then
		local capturing_group = SobGroup_Fresh("capturing-group-" .. self.id);
		SobGroup_GetSobGroupCapturingGroup(target.own_group, capturing_group);
		return SobGroup_GroupInGroup(capturing_group, self.own_group) == 1;
	end
	return self:isDoingAbility(AB_Capture);
end

--- Returns all guard targets for this ship (or nil). If `target` is provided, returns whether or not this ship is guarding the `target`.
---
---@param target? Ship
---@return 'Ship[]'|bool
function modkit_ship:guarding(target)
	if (target) then
		local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. COMMAND_Guard);
		SobGroup_GetCommandTargets(targets_group, self.own_group, COMMAND_Guard);
		return SobGroup_GroupInGroup(target.own_group, targets_group) == 1;
	else
		return self:currentCommand() == COMMAND_Guard;
	end
end

--- Returns whether the players owning this ship and the `other` ship are allied.
---
---@param other Ship | Player
---@return bool
function modkit_ship:alliedWith(other)
	if (other.HP) then -- caller is a ship
		return self.player:alliedWith(other.player);
	else
		return self.player:alliedWith(other);
	end
end

--- Returns `1` if this ship is under attack from any source, else `nil`. If `attacker` is provided, check instead if
--- this ship is under attack by that attacker (instead of anything).
---
---@param attacker Ship
---@return bool
function modkit_ship:underAttack(attacker)
	if (attacker) then
		return attacker:attacking(self);
	end
	return SobGroup_UnderAttack(self.own_group) == 1;
end

--- Returns the command targets of the
---@param command integer
---@param source table
---@return Ship[]
function modkit_ship:commandTargets(command, source)
	local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. command);
	SobGroup_GetCommandTargets(targets_group, self.own_group, command);
	local targets = {};
	for _, ship in source or GLOBAL_SHIPS:all() do
		if (SobGroup_GroupInGroup(ship.own_group, targets_group) == 1) then
			targets[ship.id] = ship;
		end
	end
	return targets;
end

function modkit_ship:beingCaptured()
	return SobGroup_AnyBeingCaptured(self.own_group);
end

function modkit_ship:allInRealSpace()
	return SobGroup_AreAllInRealSpace(self.own_group);
end

function modkit_ship:allInHyperSpace()
	return SobGroup_AreAllInHyperspace(self.own_group);
end

-- === Flags (need better name) ===

--- Sets the 'capturable' modifier flag on this ship. This flag only effects ships with the `"CanBeCaptured"` ability.
---
--- **Note: There is no way to check whether a ship is capturable or not, so this function is not a getter for that, only for this modifier.**
---
---@param capturable CapturableModifier
---@return CapturableModifier
function modkit_ship:capturableModifier(capturable)
	if (capturable) then
		self._capturable_mod = capturable;
		SobGroup_SetCaptureState(self.own_group, capturable);
	end
	return self._capturable_mod;
end

-- === Ability stuff ===

--- Returns whether or not this ship can perform the given ability (an `AB_` value).
---
---@param ability integer
---@param enable '0'|'1'|'nil'
---@return '0'|'1'
function modkit_ship:canDoAbility(ability, enable)
	enable = enable or SobGroup_CanDoAbility(self.own_group, ability);
	SobGroup_AbilityActivate(self.own_group, ability, enable);
	return SobGroup_CanDoAbility(self.own_group, ability);
end

---comment
---@param enable '0'|'1'|'nil'
function modkit_ship:canHyperspace(enable)
	return self:canDoAbility(AB_Hyperspace, enable);
end

function modkit_ship:canHyperspaceViaGate(enable)
	return self:canDoAbility(AB_HyperspaceViaGate, enable);
end

function modkit_ship:canBuild(enable)
	return self:canDoAbility(AB_Builder, enable);
end

--- Returns `1` is this ship is performing `ability` (one of the `AB_` global ability codes).
---
---@param ability integer
---@return '0'|'1'
function modkit_ship:isDoingAbility(ability)
	return SobGroup_IsDoingAbility(self.own_group, ability);
end

--- Returns `1` if this ship is performing any ability in `abilities`, else `0`.
---
---@param abilities table
---@return '0'|'1'
function modkit_ship:isDoingAnyAbilities(abilities)
	return modkit.table.any(abilities, function (ability)
		return %self:isDoingAbility(ability) == 1;
	end) or 0;
end

function modkit_ship:isDocking()
	return self:isDoingAbility(AB_Dock);
end

function modkit_ship:isBuilding(ship_type)
	return SobGroup_IsBuilding(self.own_group, ship_type);
end

--- Returns `1` if this ship is being captured.
---
---@return bool
function modkit_ship:isBeingCaptured()
	local temp = SobGroup_GetSobGroupBeingCapturedGroup(self.own_group, DEFAULT_SOBGROUP);
	return SobGroup_Count(temp) > 0;
end

-- === Command stuff ===

--- Returns the current command (order) of this ship. Returns any valid `COMMAND_` value.
---
---@return integer
function modkit_ship:currentCommand()
	return SobGroup_GetCurrentOrder(self.own_group);
end

-- === FX stuff ===

function modkit_ship:startEvent(which)
	FX_StartEvent(self.own_group, which);
end

function modkit_ship:stopEvent(which)
	FX_StopEvent(self.own_group, which);
end

--- Causes the FX `name` to play at the ship's location.
---
---@param name string
---@param scale number
function modkit_ship:playEffect(name, scale)
	FX_PlayEffect(name, self.own_group, scale or 1);
end

function modkit_ship:madState(animation_name)
	SobGroup_SetMadState(self.own_group, animation_name);
end

-- === Visibility ===

--- Returns (and optionally sets) the inherant visibility of this ship. If no player is specified, then this function sets the 'default' visibility of
--- this ship for _all_ players. If a player _is_ specified, then this 'specific' value for this player overrides any defaults.
---
--- - `specific_player` is either a player index or `"default"` (if `nil`, becomes `"default"`), which is applied as a base value which can be overridden by specific indexed values.
--- - `visibility` is an integer in the range `0 - 2`, aliased by the global varaibels `VisNone`, `VisSecondary`, and `VisFull`.
---
---@param visibility Visibility
---@param specific_player string|integer
---@return Visibility
function modkit_ship:visibility(visibility, specific_player)
	specific_player = specific_player or "default";
	-- here we set player <-> visibility:
	if (visibility) then
		self._visibility[specific_player] = visibility;
	end

	-- for each player, allow them to see this ship according to their specific rules, or the 'default' rule if no specific rules have been specified:
	for _, player in GLOBAL_PLAYERS:all() do
		local visibility = self._visibility[player.id] or self._visibility["default"];
		SobGroup_SetInherentVisibility(self.own_group, player.id, visibility);
	end

	return self._visibility[specific_player];
end

-- === Spawning ===

--- Causes this previously despawned ship to respawn at the last place it despawned, unless a new volume is given.
--- You can pass a position instead of a volume, in which case a new volume is created at that position.
--- Returns the name of the despawn volume 
---
---@param spawn integer
---@param volume? string | table
---@return string
function modkit_ship:spawn(spawn, volume)
	volume = volume or self._despawned_at_volume;
	if (type(volume) == "table") then -- if 'volume' is a {x, y, z} position
		volume = Volume_Fresh(self._despawned_at_volume, volume); -- create a volume from it
	end
	if (spawn == 1) then
		SobGroup_Spawn(self.own_group, volume);
		Volume_Delete(self._despawned_at_volume);
	elseif (spawn == 0) then
		self._despawned_at_volume = Volume_Fresh(volume, self:position());
		SobGroup_Despawn(self.own_group);
	end
	return self._despawned_at_volume;
end

--- Spawns a new ship of `type` at `position` for `player_index`. This new ship is placed in `spawn_group`, or a fresh group if `spawn_group` is not supplied.
---
--- **Note: The temporary group returned should be functionally equivalent to `own_group` of a more typically
--- available ship, but is _not_ the same group (it should only contain the same ships).**
---
---@param ship_type any
---@param position? any
---@param player_index? integer
---@param spawn_group? string
---@return string
function modkit_ship:spawnShip(ship_type, position, player_index, spawn_group)
	position = position or self:position();
	spawn_group = spawn_group or SobGroup_Fresh("spawner-group-" .. self.id);
	player_index = player_index or self.player.id;
	local volume_name = Volume_Fresh("spawner-vol-" .. self.id, position);
	SobGroup_SpawnNewShipInSobGroup(player_index, ship_type, "-", spawn_group, volume_name);
	Volume_Delete(volume_name);
	return spawn_group;
end

--- Causes this ship to produce a new ship of the given `type`, if it can do so.
--- The created ship is available through a temporary group (`spawn_group`).
---
--- **Note: The temporary group returned should be functionally equivalent to `own_group` of a more typically
--- available ship, but is _not_ the same group (it should only contain the same ships).**
---
---@param type string
---@param spawn_group? string
---@return string
function modkit_ship:produceShip(type, spawn_group)
	spawn_group = spawn_group or SobGroup_Fresh("spawner-group-" .. self.id);
	local mixed = SobGroup_Clone(self.own_group, self.own_group .. "-temp-spawner-group");
	SobGroup_CreateShip(mixed, type);
	SobGroup_FillSubstract(spawn_group, mixed, self.own_group);
	return spawn_group;
end

-- ==== printing (debugging) ====

function modkit_ship:print(verbose)
	if (verbose) then
		modkit.table.printTbl(self, "ship: " .. self.id);
	else
		modkit.table.printTbl(
			{
				id = self.id,
				ship_type = self.ship_type,
				group = self.type_group,
				tick = self:age(),
				health = self:HP()
			},
			"ship: " .. self.id
		);
	end
end

modkit.compose:addBaseProto(modkit_ship);

print("go fancy");