-- By: Fear
-- Readable stock code!
-- Also plays glow effect on trapped ships.
-- Flow begins at `go()`.

---@class GravwellAttribs
---@field active 0|1
---@field tumble_index integer
---@field all_unique_trapped Ship[]
---@field previous_tick_trapped Ship[]

--- Stuff for gw generators (hw1)
---@class GravwellProto : Ship, GravwellAttribs
gravwell_proto = {
	effect_range = 2900,
	own_effect = "PowerUp",
	stun_effect = "PowerOff",
	damage_per_cycle = 0.02,
	random_tumbles = { -- .3 - .8, random signs
		{-0.37, 0.60, 0.60},
		{-0.64, -0.71, -0.60},
		{-0.58, 0.79, 0.36},
		{-0.63, -0.39, -0.45},
		{0.54, 0.75, 0.49},
		{-0.45, 0.79, -0.36},
		{-0.51, -0.66, -0.34},
		{-0.41, -0.60, -0.30},
		{-0.31, 0.55, 0.62},
		{0.34, -0.72, -0.76},
		{-0.51, 0.56, -0.32},
		{-0.67, -0.47, -0.39},
		{-0.60, -0.69, 0.45},
		{-0.54, 0.76, -0.58},
		{0.44, -0.33, -0.72},
		{-0.31, 0.55, -0.38},
	},
	attribs = function ()
		return {
			active = 0,
			tumble_index = 0,
			all_unique_trapped = {},
			previous_tick_trapped = {},
		};
	end
};

--- Returns whether this `ship` is a valid stun target.
---
---@param ship Ship
---@return bool
function gravwell_proto:shipIsStunnable(ship)
	return
		ship:alive() 							-- alive, and:
		and (
			ship:isFighter() == 1 				-- either a fighter or
			or (								-- a corvette that isn't a salvager
				ship:isCorvette() == 1
				and ship:isSalvager() == nil
			)
		)
		and ship:distanceTo(self) < gravwell_proto.effect_range; -- and in range
end

function gravwell_proto:nextTumble()
	local tumble = self.random_tumbles[self.tumble_index];
	self.tumble_index = self.tumble_index + 1;
	if (self.tumble_index > modkit.table.length(self.random_tumbles)) then
		self.tumble_index = 1;
	end
	return tumble;
end

--- Calculates the group of ships which are stunnable (strikecraft and in range).
---
---@return Ship[]
function gravwell_proto:calculateNewTrappables()
	return GLOBAL_SHIPS:enemies(self, function (ship)
		return %self:shipIsStunnable(ship);
	end);
end

---@param ships Ship[]
---@param trapped 0|1
function gravwell_proto:setTrapped(ships, trapped)
	for _, ship in ships do
		ship:stunned(trapped);
		if (trapped == 1) then
			if (ship:tumble()[1] == 0) then -- isn't tumbling (we only want to tumble a ship once)
				ship:tumble(self:nextTumble());
			end
			ship:speed(0);
		else
			ship:tumble(0);
			ship:speed(1);
		end
	end
end

--- Records any ships in the newly trapped group which have not been seen before.
---
---@param newly_trapped Ship[]
function gravwell_proto:rememberUniqueTrapped(newly_trapped)
	for _, trapped_ship in newly_trapped do
		self.all_unique_trapped[trapped_ship.id] = self.all_unique_trapped[trapped_ship.id] or trapped_ship;
	end
end

--- Applies self damage, disables hyperspace, and plays the blue glow.
---
--- `1` -> effects applied, `0` -> effects cleared
---
---@param apply 0|1
function gravwell_proto:ownEffects(apply)
	local ab_enabled = max(apply + 1, 2);
	self:canHyperspace(ab_enabled);
	self:canHyperspaceViaGate(ab_enabled);
	if (apply == 1) then
		self:HP(self:HP() - self.damage_per_cycle);
		self:startEvent(self.own_effect);
	else
		self:stopEvent(self.own_effect);
	end
end

function gravwell_proto:cleanUp()
	self.active = 0; -- for ai
	self:setTrapped(self.all_unique_trapped, 0); -- all previously interacted ships are freed
	self.all_unique_trapped = {}; -- clear for next time
	self:ownEffects(0); -- re-enable our hs etc
end

--- Stuff that only AI-controlled gravwells should do.
--- Causes the gravwell to automatically activate under certain conditions.
function gravwell_proto:AIOnly()
	if (self.player:isHuman() == nil and mod(self:tick(), 3) == 0) then
		local friendlies_value = 0;
		local enemies_value = 0;
		for _, ship in GLOBAL_SHIPS:all() do
			if (self:shipIsStunnable(ship)) then
				if (ship:alliedWith(self)) then
					friendlies_value = friendlies_value + ship:buildCost();
				else
					enemies_value = enemies_value + ship:buildCost();
				end
			end
		end

		if (enemies_value > 0) then
			-- if any condition here passes, ability will activate
			local activation_conditions = {
				-- trappable enemies value >= 20% more than friendlies value
				good_value = function ()
					return %enemies_value >= 1.2 * %friendlies_value;
				end
			};

			local none_passed = 1;
			for name, condition in activation_conditions do
				if (condition() ~= nil) then -- passed
					none_passed = nil;
					if (self.active == 0) then
						self:customCommand();
						break;
					end
				end
			end
			if (none_passed and self.active == 1) then
				self:customCommand();
			end
		end
	end
end

-- === hooks ===

function gravwell_proto:update()
	self:AIOnly();
end

function gravwell_proto:destroy()
	self:cleanUp();
end

function gravwell_proto:start()
	self.active = 1;
end

function gravwell_proto:go()
	local new_trappables = self:calculateNewTrappables(); -- calculate which ships to stun this pass
	self:setTrapped(new_trappables, 1); -- stun them
	local difference_from_last = modkit.table.difference(self.previous_tick_trapped, new_trappables); -- any from last who didnt pass this time = diff to unstun
	self:setTrapped(difference_from_last, 0); -- unstun ships from last time which are not in our current batch to stun
	self:ownEffects(1);
	self:rememberUniqueTrapped(new_trappables); -- record any new ships we havent recorded interacting with yet (used for cleanup)
	self.previous_tick_trapped = new_trappables; -- save last run ships to compare with next run
end

function gravwell_proto:finish()
	self:cleanUp();
end

modkit.compose:addShipProto("kus_gravwellgenerator", gravwell_proto);
modkit.compose:addShipProto("tai_gravwellgenerator", gravwell_proto);