---@alias CapturableModifier
---| '0' # Ship cannot be captured
---| '1' # Ship can be captured
---| '2' # Ship can be captured (used by stock code)

---@class ShipAttribs : Attribs
---@field _stunned number
---@field _ab_targets table
---@field _current_dmg_mult number
---@field _current_tumble Arr3
---@field _despawned_at_volume string
---@field _move_volume string Used by `:move` and related methods
---@field _default_vol string
---@field _auto_launch 0|1
---@field _visibility table<Player, Visibility>
---@field _capturable_mod CapturableModifier
---@field _ghosted bool
---@field _invulnerable bool
---@field _hidden bool
---@field _reposition_event? Event
---@field _resposition_target? Position

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
			_despawned_at_volume = Volume_Fresh(),
			_move_volume = "move-vol-" .. s,
			_default_vol = "vol-default-" .. s,
			_auto_launch = 1,
			_visibility = {
				default = VisNone
			},
			_capturable_mod = 1,
			_hidden = nil,
			_reposition_event = nil,
			_reposition_target = nil
		};
	end,
};
-- === Util ===

--- Converts the given value to a volume (`string` name).
---
---@param val string | Ship | Position | Arr3
function asVol(val)
	if (type(val) ~= "string") then
		if (val.own_group) then
			---@cast val Ship
			val = val:position();
		end
		---@cast val Position | Arr3

		val = Volume_Fresh(nil, val);
	end
	---@cast val string
	
	return val;
end

function modkit_ship:age()
	return (Universe_GameTime() - self.created_at);
end

--- Sets the HP of this ship to the given `hp` fraction (between 0 and 1)
---
---@param hp? number
---@return number
function modkit_ship:HP(hp)
	if (type(hp) == "string" or type(hp) == "number") then
		local hp_num = tonumber(hp);

		if (type(hp_num) == "number") then
			-- print(self.own_group .. " set hp to " .. hp_num);
			SobGroup_SetHealth(self.own_group, hp_num);
		else
			local printErr = (consoleError or print);
			printErr(self.own_group .. ": ERROR while trying to set HP; value `" .. tostring(hp) .. "` not convertable to a number");
		end
	end

	return SobGroup_GetHealth(self.own_group);
end

--- Causes this ship to take `amount` damage as a fraction of total HP (between 0 and 1).
---
--- If `absolute` is true, instead takes an absolute about of damage, i.e `1234`
---
--- Returns the new HP fraction, or the current absolute if `absolute` is passed.
---
---@param amount number
---@param options? { absolute?: bool }
function modkit_ship:takeDamage(amount, options)
	options = options or {};
	local absolute = options.absolute;

	if (not absolute) then
		return self:HP(self:HP() - amount);
	end

	local max_hp = self:maxActualHP();
	local current = self:currentActualHP();

	if (amount > current) then
		self:HP(0);

		return self:currentActualHP();
	end

	local new_fraction = (current - amount) / max_hp;
	self:HP(new_fraction);

	return self:currentActualHP();
end

---@return bool
function modkit_ship:alive()
	return self:HP() > 0;
end

--- Causes this ship to die (HP is set to 0).
--- 
--- If `quiet` is passed, the ship despawns first, avoiding death animations and explosions etc.
---
---@param quiet bool
function modkit_ship:die(quiet)
	if (quiet) then
		self:spawn(0);
	end
	self:HP(0);
end

--- Gets or optionally sets the ship's current speed (as a proportion, `0` being `0` and `1` being default max speed).
---
--- Values exceeding `1` may be passed.
---
---@param speed? number
---@return number
function modkit_ship:speed(speed)
	if (speed) then
		SobGroup_SetSpeed(self.own_group, speed);
	end
	return abs(SobGroup_GetSpeed(self.own_group));
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
---@param pos? Position|Vec3Like
---@return Position
function modkit_ship:position(pos)
	if (pos) then
		-- print("setting position for ship " .. self.own_group .. " as {" .. pos[1] .. ", " .. pos[2] .. ", " .. pos[3] .. " }");
		SobGroup_SetPosition(self.own_group, pos);
	end
	return Vec3(SobGroup_GetPosition(self.own_group));
end

--- 'Repositions' this ship to the given `target` position, in increments from its current location to the target.
---
---@param target Ship|Vec3Like
---@param options? { increment?: number, success_threshold?: number, others_to_drag?: Ship[], increment?: number, interval?: integer, stubborn?: bool }
function modkit_ship:respositionTo(target, options)
	options = options or {};

	local others_to_drag = options.others_to_drag;
	local increment = options.increment or self:distanceTo(target) / 32;
	local success_threshold = options.success_threshold or increment;
	local stubborn = options.stubborn;

	self._resposition_target = target;

	local new_ev = modkit.scheduler:make({
		fn = function (resolveReposition, rejectReposition, resposition_state)
			print("reposition event for " .. %self);

			-- print("do I already have a reposition event?: " .. tostring(%self._reposition_event));
			-- print("can see new event from here? " .. tostring(resposition_state._event));

			-- here we cancel any other possibly running resposition event for this ship, unless its stubborn, in which case this event is cancelled instead
			if (not resposition_state.init and %self._reposition_event) then
				local err_msg = %self .. " already doing a reposition, exiting old event...";
				consoleError(err_msg);
				%self._reposition_event:finish(EVENT_STATUS.REJECTED, err_msg);
			end
			%self._reposition_event = resposition_state._event;
			---@diagnostic disable-next-line: inject-field
			resposition_state.init = 1;

			if (not resposition_state.target) then
				-- print(%self .. " currently at " .. %self:position());

				local resolved_target = nil;
				if (%target.own_group) then
					---@cast %target Ship
					resolved_target = %target:position();
				else
					resolved_target = Vec3(%target);
				end
				---@cast resolved_target Position

				---@diagnostic disable-next-line: inject-field
				resposition_state.target = resolved_target;
				print("target is " .. resposition_state.target);

				---@diagnostic disable-next-line: inject-field
				resposition_state.increment_vec = Vec3:unit(resposition_state.target - %self:position()) * %increment;
			end

			local ds = %self:distanceTo(resposition_state.target);

			if (not %stubborn and resposition_state.distance_left and ds > resposition_state.distance_left) then -- consider an error
				return rejectReposition("Error: " .. %self .. " was found to be moving away from it's target during reposition event! Exiting!");
			end

			if (ds <= %success_threshold) then
				print(%self .. " DONE MOVING!!");

				return resolveReposition(%self);
			end

			local increment_vec = resposition_state.increment_vec;

			if (ds < Vec3:mag(increment_vec)) then
				increment_vec = Vec3:unit(increment_vec) * ds;
			end

			-- print(%self .. " currently at " .. %self:position());
			-- print("\tincrement :" .. increment);
			-- print("\ttarget is " .. state.target);
			%self:position(%self:position() + increment_vec);

			if (%others_to_drag) then
				for _, ship in %others_to_drag do
					ship:position(ship:position() + increment_vec);
				end
			end

			-- print("distance to target: " .. tostring(ds));
			---@diagnostic disable-next-line: inject-field
			resposition_state.distance_left = ds;

			if (ds <= %success_threshold) then
				print(%self .. " DONE MOVING!!");

				return resolveReposition(%self);
			end
		end,
		interval = options.interval or 1,
	});

	return new_ev;
end

--- Gets or optionally sets / clears the ship's tumble. In modkit, this vector is tracked.
---
--- Pass `0` to clear the current tumble.
---
---@param tumble? Arr3|number
---@return Arr3
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
--- The multiplier is always relative to 1 (its reset every time you call this fn), unless `relative` is non-nil,
--- meaning the function is being called _relative_ to its last value (instead of 1).
---
---@param mult? number
---@param relative? bool
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
		HP = max(0, min(1, HP));
		SobGroup_SetHardPointHealth(self.own_group, subs_name, HP);
	end
	return SobGroup_GetHardPointHealth(self.own_group, subs_name);
end

--- Returns whether or not this ship hosts the named subsystem.
---
---@param subs_name string
---@return bool
function modkit_ship:hasSubsystem(subs_name)
	return SobGroup_HasSubsystem(self.own_group, subs_name) == 1;
end

function modkit_ship:createSubsystem(subs_name)
	return SobGroup_CreateSubSystem(self.own_group, subs_name);
end

--- Returns whether or not this ship hosts a research module of any kind.
---
---@return bool
function modkit_ship:hasResearchModule()
	for _, name in {
		'hgn_c_module_research',
		'hgn_c_module_researchadvanced',
		'hgn_ms_module_research',
		'hgn_ms_module_researchadvanced',
		'vgr_c_module_research',
		'vgr_ms_module_research',
		'hw1_researchmodule'
	} do
		if (self:hasSubsystem(name)) then
			return 1;
		end

		if (name == 'hw1_researchmodule') then
			for i = 1, 5 do
				if (self:hasSubsystem(name .. i)) then
					return 1;
				end
			end
		end
	end
	return nil;
end

--- Returns the distance between this ship and the given other ship, or the average position if given multiple others.
---
---@param other Ship | Ship[] | Position
---@return number
function modkit_ship:distanceTo(other)
	local a = self:position();

	if (other.own_group) then -- ship
		return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group) or -1;
	end

	---@type Position|Ship
	local b = a;
	if (Vec3:isVec3Like(other)) then
		---@cast other Position
		b = other;
	else
		b = Vec3(SobGroup_GetPosition(SobGroup_FromShips(other)));
	end

	return sqrt(
		(b[1] - a[1]) ^ 2 +
		(b[2] - a[2]) ^ 2 +
		(b[3] - a[3]) ^ 2
	);
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
		local temp_group = SobGroup_FromShips(targets, self.own_group .. "-temp-attack-group");
		SobGroup_Attack(self.player.id, self.own_group, temp_group);
	end
end

--- Causes this ship to attack all the ships belonging to the given player.
---
---@param player integer|Player
function modkit_ship:attackPlayer(player)
	local id = player;
	if (type(player) == "table") then
		id = player.id;
	end
	---@cast id integer

	return SobGroup_AttackPlayer(self.own_group, id);
end

--- Causes this ship to kamikazi into `targets`, which can be one or more ships.
---
---@param targets Ship | Ship[]
function modkit_ship:kamikazi(targets)
	if (targets.own_group) then
		return SobGroup_Kamikaze(self.own_group, targets.own_group);
	end

	return SobGroup_Kamikaze(self.own_group, SobGroup_FromShips(targets));
end

--- Returns the cloak state of this ship, optionally setting it.
---
---@param set? 0|1 -- if `nil`, the cloak is toggled, if 0, its turned off, if 1, turned on
---@return bool
function modkit_ship:cloak(set)
	local current_status = self:isCloaked();
	set = set or mod(current_status + 1, 2);

	if (set ~= current_status) then
		SobGroup_CloakToggle(self.own_group);
	end
	return self:isCloaked();
end

--- Returns whether or not this ship is cloaked
---@return bool
function modkit_ship:isCloaked()
	return SobGroup_IsCloaked(self.own_group) == 1;
end

--- Causes this ship to begin capturing `targets`, which can be a single ship or a table of ships.
---
---@param targets Ship | Ship[]
function modkit_ship:capture(targets)
	if (targets.own_group) then
		SobGroup_CaptureSobGroup(self.own_group, targets.own_group);
	else
		local temp_group = SobGroup_FromShips(targets, self.own_group .. "-temp-capture-group");
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
		local temp_group = SobGroup_FromShips(targets, self.own_group .. "-temp-salvage-group");
		SobGroup_SalvageSobGroup(self.own_group, temp_group);
	end
end

--- Makes the ship stop (issues a stop command).
---
function modkit_ship:stop()
	SobGroup_Stop(self.player.id, self.own_group);
end

--- Moves this ship to `target`.
--- 
--- The fields for the `options` param behave as follows:
--- - `distance_threshold`: allow the move to mark as 'complete' so long as within this proximity of target
--- - `no_event`: don't fire an event; return `nil` instead
--- 
--- Returns an `EventChain` or a `RuleChain` if `options.no_event` is `nil` (default):
--- - Use `:next(...)` to execute code _after_ the move finishes successfully.
--- - Use `:catch(...)` to execute code _after_ the move is interrupted or fails.
---
---@param target string | Ship | Position | Arr3
---@param options? { distance_threshold?: number, no_event: bool }
---@return EventChain|RuleChain|nil
function modkit_ship:move(target, options)
	options = modkit.table:merge(
		{
			distance_threshold = 1500,
			no_event = nil,
		},
		options
	);


	local distance_threshold = options.distance_threshold;
	local no_event = options.no_event;

	if (type(target) == "string") then -- a volume
		SobGroup_Move(self.player.id, self.own_group, target);
	else -- a position
		if (target.own_group) then
			---@cast target Ship
			target = target:position();
		end
		---@cast target Position | Arr3

		-- print("move issued for " .. self.own_group);
		-- modkit.table.printTbl(options, "options");

		-- print("SobGroup_MoveToPoint(" .. self.player.id .. ", " .. self.own_group .. ", " .. Vec3(target) .. ");");
		SobGroup_MoveToPoint(self.player.id, self.own_group, target);
	end

	if (no_event) then
		return nil;
	end

	local api = nil;
	-- return a promise which resolves if we moved successfully, or rejects if the move was interrupted, or we were moved out of normal space, or we died
	if (Rule_AddInterval) then
		api = modkit.campaign.rules;
	else
		api = modkit.scheduler;
	end

	-- also we need to clear this if its already running
	return api:make({
		name = self.type_group .. "_" .. self.id ..  "_move_command_listener",
		fn = function (resolve, reject)
			if (%self:isNear(%target, %distance_threshold)) then
				return resolve(%self);
			end

			if (not %self:moving())then
				return reject("move promise for ship " .. %self.own_group .. " rejected: move order was interrupted before completion (current command: " .. %self:currentCommand() .. ")");
			end
		end
	}):begin();
end

--- Returns `1` if this ship is currently moving (`AB_Move` + alive + in real space).
--- 
--- @return bool
--- 
function modkit_ship:moving()
	return self:alive() and self:isDoingAbility(AB_Move) and self:allInRealSpace();
end

--- Returns `1` if this ship is within `threshold` units of `where`.
--- 
---@param where string | Ship | Position | Arr3
---@param threshold? number 2000
---@return bool
function modkit_ship:isNear(where, threshold)
	threshold = threshold or 2000;

	return SobGroup_IsShipNearPoint(self.own_group, asVol(where), threshold) == 1;
end

--- Makes this ship guard `target`, which may be one or multiple other ships.
---
---@param target Ship | Ship[]
function modkit_ship:guard(target)
	if (target.own_group) then
		self._guard_group = target.own_group;
	else -- collection of ships
		self._guard_group = SobGroup_FromShips({ target }, self.own_group .. "_guard_group");
	end
	return SobGroup_GuardSobGroup(self.own_group, self._guard_group);
end

function modkit_ship:parade(other, mode)
	mode = mode or 0;
	return SobGroup_ParadeSobGroup(self.own_group, other.own_group, mode);
end

--- Causes the ship to dock with `target`.
---
--- Calls `SobGroup_DockSobGroupWithAny`, unless one of `options` is passed.
--- 
--- Options:
--- - `
--- - `instant`: Docks _instantly_
--- - `stay_docked`: Docks and stays docked unless manually launched
---
--- @class DockTargetOptions
--- @field instant? bool
--- @field stay_docked? bool 

---@param target? Ship
---@param options? DockTargetOptions
function modkit_ship:dock(target, options)
	options = options or {};
	local instant = options.instant
	local stay_docked = options.stay_docked;

	if (target == nil) then -- if no target, target = closest ship
		SobGroup_DockSobGroupWithAny(self.own_group);
	else
		if (instant) then
			SobGroup_DockSobGroupInstant(self.own_group, target.own_group);
		elseif (stay_docked) then
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
	SobGroup_HyperspaceTo(self.own_group, Volume_Fresh("-", to));
end

--- Causes this ship to use the specified `HyperspaceGate`, if possible.
---
---@param gate HyperspaceGate
function modkit_ship:useHyperspaceGate(gate)
	SobGroup_UseHyperspaceGate(self.own_group, gate.own_group);
end

--- Gets or optionally sets the ship's auto-launch behavior. `1` for auto-launch, `0` for stay-docked manual launching.
---
---@param auto_launch? AutoLaunchStatus
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
---@param new_ROE? ROE
---@return ROE
function modkit_ship:ROE(new_ROE)
	if (new_ROE) then
		SobGroup_SetROE(self.own_group, new_ROE);
	end
	return SobGroup_GetROE(self.own_group);
end

--- Gets and optionally sets the ship's [Stance](https://github.com/HWRM/KarosGraveyard/wiki/Variable;-Stance).
---
---@param new_stance? Stance
---@return Stance
function modkit_ship:stance(new_stance)
	if (new_stance ~= nil) then
		SobGroup_SetStance(self.own_group, new_stance);
	end
	return SobGroup_GetStance(self.own_group);
end

--- Causes this ship to be 'ghosted', which is pretty much akin to no-clip (no collisions will affect this ship).
---
---@param enabled? 0|1
---@return bool
function modkit_ship:ghost(enabled)
	enabled = enabled or 1;
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
	local group_to_launch = self.player:shipsGroup();
	if (docked) then
		group_to_launch = docked.own_group;
	end
	return SobGroup_Launch(group_to_launch, self.own_group);
end

--- Returns the 3-character race string of the ship.
--- **Note: This is the host race of the _ship type_, as opposed to the player's race.**
---
---@return RacePrefix
function modkit_ship:racePrefix()
	return strsub(self.ship_type, 0, 3);
end

--- Returns the actual race name of the ship (see `races.lua`)
---
---@return RaceName
function modkit_ship:raceName()
	return modkit.races:find(self:racePrefix()).name;
end

-- === Attack family queries ===

function modkit_ship:attackFamily()
	return SobGroup_GetFirstAttackFamily(self.own_group);
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
---@param invulnerable? 0|1
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
	return self._invulnerable == 1;
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
---@param with? Ship
---@return bool
function modkit_ship:docked(with)
	if (with) then
		return SobGroup_IsDockedSobGroup(self.own_group, with.own_group) == 1;
	end
	return SobGroup_IsDocked(self.own_group) == 1;
end

--- Returns `1` if this ship is attacking anything, else `nil`. If `target` is provided, check instead if
-- this ship is attacking that target (instead of anything).
---@param target? Ship
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
---@param target? Ship
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
---@return bool
function modkit_ship:guarding(target)
	if (target) then
		local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. COMMAND_Guard);
		SobGroup_GetCommandTargets(targets_group, self.own_group, COMMAND_Guard);
		return SobGroup_GroupInGroup(target.own_group, targets_group) == 1;
	else
		return modkit.table.any(GLOBAL_PLAYERS:alive(), function (player)
			---@cast player Player
			return SobGroup_IsGuardingSobGroup(%self.own_group, player:shipsGroup()) == 1;
		end);
	end
end

--- Returns whether the players owning this ship and the `other` ship are allied.
---
---@param other Ship | Player
---@return bool
function modkit_ship:alliedWith(other)
	local other_player = other;
	if (other.HP) then
		---@cast other Ship
		other_player = other.player;
	end
	---@cast other_player Player

	return self.player:alliedWith(other_player);
end

--- Switches the owner of this ship to the supplied player.
---
---@param player Player|integer
function modkit_ship:switchToPlayer(player)
	if (type(player) == "number") then
		player = GLOBAL_PLAYERS:get(player);
	end

	return SobGroup_SwitchOwner(self.own_group, player.id);
end

--- Returns `1` if this ship is under attack from any source, else `nil`. If `attacker` is provided, check instead if
--- this ship is under attack by that attacker (instead of anything).
---
---@param attacker? Ship
---@return bool
function modkit_ship:underAttack(attacker)
	if (attacker) then
		return attacker:attacking(self);
	end
	return SobGroup_UnderAttack(self.own_group) == 1;
end

--- Returns the command targets of the
---@param command integer
---@param source? table
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
	return SobGroup_AnyBeingCaptured(self.own_group) == 1;
end

---@return bool
function modkit_ship:allInRealSpace()
	return SobGroup_AreAllInRealSpace(self.own_group) == 1;
end

---@return bool
function modkit_ship:allInHyperSpace()
	return SobGroup_AreAllInHyperspace(self.own_group) == 1;
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
---@param enable? 0|1
---@return '0'|'1'
function modkit_ship:canDoAbility(ability, enable)
	enable = enable or SobGroup_CanDoAbility(self.own_group, ability);
	SobGroup_AbilityActivate(self.own_group, ability, enable);
	return SobGroup_CanDoAbility(self.own_group, ability);
end

--- Gets and optionally sets whether or not this ship can hyperspace.
---
---@param enable? 0|1
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
---@return bool
function modkit_ship:isDoingAbility(ability)
	return SobGroup_IsDoingAbility(self.own_group, ability) == 1;
end

--- Returns `1` if this ship is performing any ability in `abilities`, else `0`.
---
---@param abilities table
---@return bool
function modkit_ship:isDoingAnyAbilities(abilities)
	return modkit.table.any(abilities, function (ability)
		return %self:isDoingAbility(ability) == 1;
	end);
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
	local temp = SobGroup_Fresh();
	SobGroup_GetSobGroupBeingCapturedGroup(self.own_group, temp);
	return SobGroup_Count(temp) > 0;
end

-- === Selection stuff ===

--- Gets and optionally sets the 'selected' state of this ship. This is a real UI selection, not to be confused with a selection from `Section_` functions.
---
--- A further parameter, `add_to_current`, indicates whether or not to add this ship to a possible current selection or to set it as the only selected ship when setting.
---
---@param selected? 0|1
---@param add_to_current? bool
---@return bool
function modkit_ship:selected(selected, add_to_current)
	if (selected == 1) then
		local to_select_group = SobGroup_Fresh();
		SobGroup_SobGroupAdd(to_select_group, self.own_group);
		if (add_to_current) then
			local current = SobGroup_FromShips(GLOBAL_SHIPS:selected());
			-- modkit.table.printTbl(modkit.table.map(GLOBAL_SHIPS:selected(), function (ship)
			-- 	return { own_group = ship.own_group, selected = ship:selected() };
			-- end), "selected ships");
			-- print("current selected group count: " .. tostring(SobGroup_Count(current)));
			SobGroup_SobGroupAdd(to_select_group, current);
		end
		SobGroup_SelectSobGroup(to_select_group);
	elseif (selected == 0) then
		local current = SobGroup_FromShips(GLOBAL_SHIPS:selected());
		local after = SobGroup_Fresh();
		SobGroup_FillSubstract(after, current, self.own_group); -- save the selection sans this ship
		SobGroup_DeSelectAll();
		SobGroup_SelectSobGroup(after); -- now re-select (so we only end up deselecting this ship)
	end

	return SobGroup_Selected(self.own_group) == 1;
end

--- Gets or optionally sets the selectability of this ship.
---
---@param set_selectable? 0|1
---@return bool
function modkit_ship:selectable(set_selectable)
	if (set_selectable) then
		SobGroup_MakeSelectable(self.own_group, set_selectable);
	end

	return SobGroup_IsSelectable(self.own_group) == 1;
end

--- Returns whether or not the positions of this ship and `other` are the same.
---
--- For each axis, you can provie a 'leeway' to provide a range around the position of this ship for that axis. Otherwise,
--- checks the value of each axis being exactly equal.
---
---@param other Ship|Position
---@param leeways? { x: number?, y:  number?, z: number? } | number
function modkit_ship:positionEq(other, leeways)
	leeways = leeways or {};
	local p1 = self:position();
	local p2 = other;
	if (p2.position) then
		---@cast p2 Ship
		p2 = p2:position();
	end
	---@cast p2 Position

	return modkit.table.all(p1, function (val, axis)
		local leeway = %leeways;
		if (type(leeway) == "table") then
			leeway = %leeways[axis];
		end

		if (leeway and leeway > 0) then
			return abs(val - %p2[axis]) <= leeway;
		end

		return %p2[axis] == val;
	end);
end

--- Gets all ships within the radius of this ship, with possible filters:
---
--- - A `ship_types` list, only selecting ships of those types.
--- - A `players` list, only selecting for those players.
---
---@param radius number
---@param ship_types? ShipType[]
---@param players? Player[]
---@return Ship[]
function modkit_ship:getShipsInRadius(radius, ship_types, players)
	players = players or GLOBAL_PLAYERS:all();
	local in_radius_group = SobGroup_Fresh();
	for _, player in players do
		local player_in_radius_group = SobGroup_Fresh();
		-- `player_in_radius_group` is ALL ships in radius
		Player_FillProximitySobGroup(player_in_radius_group, player.id, self.own_group, radius);
		if (ship_types) then -- unless a types filter list is provided
			local correct_types_group = SobGroup_Fresh();
			for _, ship_type in ship_types do -- in that case, for each type, grab the ships of that type and add them to `correct_types_group`
				local type_group = SobGroup_Fresh();
				SobGroup_FillShipsByType(type_group, player_in_radius_group, ship_type);
				SobGroup_SobGroupAdd(correct_types_group, type_group);
			end

			SobGroup_SobGroupAdd(in_radius_group, correct_types_group); -- then add the filtered ships to the `player_in_radius_group`
		else
			SobGroup_SobGroupAdd(in_radius_group, player_in_radius_group); -- otherwise it's just the original fillproximity selection
		end
	end

	local in_radius_ships = SobGroup_ToShips(in_radius_group); -- split to `Ship`s, but they have no id or anything...
	-- we can get the actual entries by matching type & pos
	-- expensive in theory, but we will rarely call this function with a huge radius, so in_radius_ships is a small group usually
	in_radius_ships = GLOBAL_SHIPS:filter(function (ship)
		-- filter `GLOBAL_SHIPS` for any ship which can be found in `in_radius_ships` by type & pos:
		return modkit.table.findVal(%in_radius_ships, function (other)
			return %ship.type_group == other.type_group and %ship:positionEq(other);
		end) ~= nil;
	end);

	return in_radius_ships;
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
---@param scale? number
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
---@param specific_player? string|integer
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

--- Gets or optionally sets the 'hidden' status of this ship. As opposed to visibility rules, a 'hidden' ship is just
--- totally invisible.
---
---@param set_hidden 0|1|nil
---@return bool
function modkit_ship:hidden(set_hidden)
	if (set_hidden) then
		SobGroup_SetHidden(self.own_group, set_hidden);
		self._hidden = set_hidden == 1;
	end

	return self._hidden;
end

-- === Spawning ===

--- If this Ship was previously despawned, returns the name of the Volume where this occurred.
---
--- If `spawn` is given, causes this Ship to spawn/despawn. When spawning, may optionally accept a Volume or
--- a `Position` to spawn into.
---
---@param spawn? integer
---@param volume? string | Position
---@return string
function modkit_ship:spawn(spawn, volume)
	volume = asVol(volume or self._despawned_at_volume);

	if (spawn == 1) then
		SobGroup_Spawn(self.own_group, volume);
		Volume_Delete(self._despawned_at_volume);
	elseif (spawn == 0) then
		self._despawned_at_volume = Volume_Fresh(volume, self:position());
		SobGroup_Despawn(self.own_group);
	end
	return self._despawned_at_volume;
end

--- Spawns new ships, as specified by `spawn_args`.
---
--- Returns a `RuleChain|EventChain` which resolves with the newly spawned ships.
---
---@param spawn_args (SpawnArgs|string)|(SpawnArgs|string)[]
---@return EventChain|RuleChain
function modkit_ship:spawnShip(spawn_args)
	return modkit.ships():spawnShips(spawn_args);
end

--- Calls `SobGroup_CreateShip`, which attempts to _produce_ a new ship from this ship.
--- 
--- Ship production will use a ship hold and launch points normally, but can also work just through hyperspacing in the desired ship.
---
--- @class ProduceArgs
--- @field ship_type ShipType
--- @field count? integer
--- @field spawn_group? string

---@param produce_args (ProduceArgs|string)|(ProduceArgs|string)[]
function modkit_ship:produceShipsQuiet(produce_args)
	local all_spawn_group = SobGroup_Fresh();

	if (type(produce_args) == "table" and type(produce_args[1]) == "table") then

		for _, args in produce_args do
			if (type(args) == "string") then
				args = {
					ship_type = args
				};
			end
			---@cast args SpawnArgs

			SobGroup_SobGroupAdd(all_spawn_group, self:produceShipsQuiet(args));
		end

		return all_spawn_group;
	end

	local defaults = {
		ship_type = produce_args,
		count = 1,
		spawn_group = SobGroup_Fresh()
	};
	if (type(produce_args) == "string") then -- first coax string into a `ProduceArgs`
		produce_args = defaults;
	else
		produce_args = modkit.table:merge(defaults, produce_args);
	end

	for _ = 1, produce_args.count do
		local produced_group = SobGroup_CreateShip(self.own_group, produce_args.ship_type);
		
		-- SobGroup_DockSobGroupInstant(produced_group, self.own_group);

		SobGroup_SobGroupAdd(all_spawn_group, produced_group);
	end

	return all_spawn_group;
end

---@param produce_args (ProduceArgs|string)|(ProduceArgs|string)[]
---@param options? AwaitShipsOptions
function modkit_ship:produceShips(produce_args, options)
	return awaitShips(self:produceShipsQuiet(produce_args), options):begin();
end

-- ==== printing (debugging) ====

--- Calls `modkit.table.printTbl` for this 'Ship' (which is just a table).
---
--- By default, only outputs certain key details; for a full printing of this Ship table, `verbose` should be set.
---
---@param verbose? bool
function modkit_ship:print(verbose)
	if (verbose) then
		modkit.table.printTbl(self, "ship: " .. self.id);
	else
		modkit.table.printTbl(
			{
				id			= self.id,
				ship_type	= self.ship_type,
				group 		= self.type_group,
				tick		= self:age(),
				health		= self:HP()
			},
			"ship: " .. (self.id or ('temporary_' .. (self.own_group)))
		);
	end
end

modkit.compose:addBaseProto(modkit_ship);

print("go fancy");
