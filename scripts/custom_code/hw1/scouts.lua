---@class ScoutProto: Ship
---@field speed_penalty_max number
--- For all scouts
scouts_proto = {
	speed_penalty_max = 0.9
};

--- Returns the increment/decrement step size for mounting speed penalties.
--- Relies on the squad size of the ship's group.
---@return number
function scouts_proto:penaltyStep()
	return 0.1 / self:squadSize(); -- squad size since every member calls this
end

function scouts_proto:recoveryStep()
	return 0.05 / self:squadSize();
end

--- Update for **all** scouts
function scouts_proto:update()
	if (self.last_hp and self.last_hp > self:HP()) then
		self:speed(max(scouts_proto.speed_penalty_max, modkit.math.round(self:speed() - self:penaltyStep(), 2)));
	else
		if (self:speed() < 1) then -- avoid messing with hw1 scout script
			self:speed(min(1, modkit.math.round(self:speed() + self:recoveryStep(), 2)));
		end
	end
	self.last_hp = self:HP();
end

modkit.compose:addShipProto("hgn_scout", scouts_proto);
modkit.compose:addShipProto("vgr_scout", scouts_proto);

--- === Custom ability for hw1 scouts (speed burst) ===

---@class ScoutAttribs
---@field current_speed number
---@field decay_event_id integer
---@field last_hp number

---@class scouts_proto : Ship, ScoutProto, ScoutAttribs
--- Specifically for hw1 scouts
hw1_scouts_proto = {
	boost_range = {
		min = 1.1,
		max = 3.7
	},
	attribs = function ()
		return {
			current_speed = 1,
			decay_event_id = nil,
			last_hp = 1
		}
	end
};

for k, v in scouts_proto do
	hw1_scouts_proto[k] = hw1_scouts_proto[k] or v;
end

function hw1_scouts_proto:start()
	self.current_speed = self:speed(4);
	-- FX_PlayEffect("speed_burst_flash", CustomGroup, 1.5)
	self:playEffect("speed_burst_flash", 1.5);
end

function hw1_scouts_proto:go()
	if (mod(self:tick(), 1) == 0) then
		if (self.current_speed > self.boost_range.min) then
			self.current_speed = self:speed(max(self.current_speed - 0.5, self.boost_range.min));
		end
	end
end

function hw1_scouts_proto:finish()
	self.current_speed = self:speed(1);
end

modkit.compose:addShipProto("kus_scout", hw1_scouts_proto);
modkit.compose:addShipProto("tai_scout", hw1_scouts_proto);