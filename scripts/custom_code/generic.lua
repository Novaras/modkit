-- Ships utility functions

---@class generic_proto : Ship
local generic_proto = {};

-- === helpers ===

-- Disable scuttle while a captured unit is being dropped off by salvage corvettes
function generic_proto:noSalvageScuttle()
	if ((self:isFighter() or self:isCorvette()) == nil) then
		self:canDoAbility(AB_Scuttle, 1 - self:isDocking());
	end
end

--- If this ship is a strikecraft unit (in a formation i.e hw2 strike), and is trying to dock but is bugged out, then re-issue the dock command to get it moving again.
function generic_proto:underAttackReissueDock()
	if (self:batchSize() > 1 and (self:isFighter() or self:isCorvette())) then
		if (self:count() < self:batchSize()) then
			if (self:underAttack()) then
				if (self:actualSpeedSq() <= 100 ^ 2) then
					if (self:isDocking() == 1 and self:docked() == nil) then
						self:dock(); -- dock with any
					end
				end
			end
		end
	end
end

-- === hooks ===

function generic_proto:afterUpdate()
	self:noSalvageScuttle();
	self:underAttackReissueDock();
end

-- === link ===

modkit.compose:addBaseProto(generic_proto);
