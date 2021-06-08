modkit_ship = {
	attribs = {
		_stunned = 0
	}
};

-- === Util ===

function modkit_ship:age()
	return (Universe_GameTime() - self.created_at);
end

function modkit_ship:distanceTo(other)
	return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group);
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

function modkit_ship:isFighter()
	for k, v in {
		"fighter",
		"fighter_hw1"
	} do
		if (self:attackFamily() == v) then
			return 1;
		end
	end
end

function modkit_ship:isCorvette()
	for k, v in {
		"corvette",
		"corvette_hw1"
	} do
		if (self:attackFamily() == v) then
			return 1;
		end
	end
end

-- === Ship type queries ===

function modkit_ship:isSalvager()
	for k, v in {
		"kus_salvagecorvette",
		"tai_salvagecorvette"
	} do
		if (self:attackFamily() == v) then
			return 1;
		end
	end
end

-- === State setters ===

--- Get or set the stunned status of the ship.
-- Returns whether or not the ship should currently be stunned (if stunned previously via :stunned)
function modkit_ship:stunned(stunned)
	if (stunned ~= nil) then
		self._stunned = stunned;
	end
	SobGroup_SetGroupStunned(self.own_group, stunned);
	return self._stunned;
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