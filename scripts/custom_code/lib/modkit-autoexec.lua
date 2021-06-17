modkit_autoexec = {
	_move_action = { -- state used by move-action functions (moveActionQueue), also see below for methods attached on _ma
		index = 1,
		move_actions = {},
		acceptable_distance = 100,
		arrived_tick = -1,
		wait_duration = 4,
		waiting = 0
	}
};

-- lua though
local _ma = modkit_autoexec._move_action;

--- Returns the next moveaction (the current destination).
-- This will always be a table with 'position' and 'actionFn' properties - if you
-- passed in a raw position table it will be packed into the 'position' property.
function _ma:next()
	local next = self.move_actions[self.index];
	if (next == nil) then
		return next;
	end
	if (next.position == nil) then -- 'next' is just a position, create a moveaction out of it
		return {
			position = next,
			actionFn = function () end
		};
	end
	return next;
end

--- Returns whether or not this current wait period should end.
function _ma:finished(tick)
	return self.waiting == 1 and self.arrived_tick + (self:next().wait_duration or self.wait_duration) <= tick;
end

--- Takes a list of 'move actions', and executes them one by one until completion (using driver's auto-exec feature).
-- The next move-action is not started until the current one has been completed. On arrival to a position
-- (which is an xyz position table or a valid volume name), the ship will enter a 'waiting' phase where it has time
-- to perform any actions contained in the supplied callback, if given.
-- @param move_actions [table] The table of move-actions. See above for the definition of a 'move-action'.
-- @param wait_duration [number] The global wait duration for any move-action without its own custom wait duration.
-- @param acceptable_distance [number] The distance the ship must get within relative to its destination before it enters its waiting phase
-- @return nil
function modkit_autoexec:moveActionQueue(move_actions, wait_duration, acceptable_distance)
	local MA = self._move_action;

	if (move_actions) then
		MA.move_actions = move_actions;
		MA.waiting = 0;
		MA.index = 1;
		MA.arrived_tick = -1;
	end

	-- defaults
	MA.wait_duration = wait_duration or MA.wait_duration;
	MA.acceptable_distance = acceptable_distance or MA.acceptable_distance;

	-- attach this fn to the auto exec list (so the base update fn doesn't need to call anything)
	local runner = function (caller)
		local next = %MA:next();
		if (next) then
			if (%MA.waiting == 0 and %self:distanceTo(next.position) <= %MA.acceptable_distance) then -- if not waiting and out of range
				%MA.arrived_tick = %self:tick();
				%MA.waiting = 1;
				next.actionFn(%self);
			elseif (%MA:finished(%self:tick()) and modkit.table.length(%MA.move_actions) > %MA.index) then -- finished wait and not final move-action
				%MA.index = %MA.index + 1;
				%MA.waiting = 0;
				%self:move(%MA:next().position);
			elseif (%MA.index == 1) then -- first move-action, just go
				%self:move(%MA:next().position);
			end
		end
	end

	modkit.table.push(self.auto_exec, runner); -- hook to autoexec

end

modkit.compose:addBaseProto(modkit_autoexec);

print("go auto :[]");