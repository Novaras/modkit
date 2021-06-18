modkit_autoexec = {
	_move_action = { -- state used by move-action functions (moveActionQueue), also see below for methods attached on _ma
		index = 1,
		move_actions = {},
		distance_threshold = 100,
		arrived_tick = -1,
		actioning = 0,
	}
};

-- lua though
local _ma = modkit_autoexec._move_action;

function _ma.defaultPredicate(caller)
	return caller:tick() >= modkit_autoexec._move_action.arrived_tick + 4;
end

--- Returns the next moveaction (the current destination).
-- This will always be a table with 'position' and 'action' properties - if you
-- passed in a raw position table it will be packed into the 'position' property.
function _ma:next(caller)
	local next = self.move_actions[self.index];
	if (next == nil) then
		return next;
	end
	if (next.position == nil and next.action == nil) then -- 'next' is just a position, create a moveaction out of it
		next = {
			position = next
		};
	end
	next.position = next.position or caller:position();
	next.action = next.action or function () end
	-- default finish predicate just checks to see if the ship arrived at least 4 ticks ago
	next.finished = next.finished or self.defaultPredicate;
	return next;
end

--- Returns whether or not this current move-action is over
function _ma:finished(caller)
	return self.actioning == 1 and self:next().finished(caller, self);
end

--- Takes a list of 'move actions', and executes them one by one until completion (using driver's auto-exec feature).
-- The next move-action is not started until the current one has been completed. On arrival to a position
-- (which is an xyz position table or a valid volume name), the ship will enter a 'actioning' phase where it has time
-- to perform any actions contained in the supplied callback, if given.
-- @param move_actions [table] The table of move-actions. See above for the definition of a 'move-action'.
-- @param wait_duration [number] The global wait duration for any move-action without its own custom wait duration.
-- @param distance_threshold [number] The distance the ship must get within relative to its destination before it enters its actioning phase
-- @return nil
function modkit_autoexec:moveActionQueue(move_actions, distance_threshold, defaultPredicate)
	local MA = self._move_action;

	if (move_actions) then -- new set
		MA.move_actions = move_actions;
		MA.actioning = 0;
		MA.index = 1;
	end

	-- defaults
	MA.distance_threshold = distance_threshold or MA.distance_threshold;
	MA.defaultPredicate = defaultPredicate or MA.defaultPredicate;

	-- attach this fn to the auto exec list (so the base update fn doesn't need to call anything)
	local runner = function (caller)
		local next = %MA:next(caller);
		if (next) then
			if (%MA.actioning == 0 and caller:distanceTo(next.position) <= %MA.distance_threshold) then -- if not actioning and out of range
				%MA.actioning = 1;
				%MA.arrived_tick = caller:tick();
				next.action(caller);
			elseif (%MA:finished(caller) and modkit.table.length(%MA.move_actions) > %MA.index) then -- finished action and not final move-action
				%MA.index = %MA.index + 1;
				%MA.actioning = 0;
				caller:move(%MA:next(caller).position);
			elseif (%MA.index == 1) then -- first move-action, just go
				caller:move(%MA:next(caller).position);
			end
		end
	end

	self.auto_exec["move-actions" .. self.id] = runner; -- hook to autoexec

	return self._move_action;
end

modkit.compose:addBaseProto(modkit_autoexec);

print("go auto :[]");