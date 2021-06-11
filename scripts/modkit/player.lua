-- memgroup for players
-- Also a prototype for player entities. This is how modkit provides the Player_ API.

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end

if (modkit_player_proto == nil) then

	-- global memgroup for players
	GLOBAL_PLAYERS = modkit.MemGroup.Create("mg-players-global");

	modkit_player_proto = {};

	--- Gets the player's ships (alive ships)
	function modkit_player_proto:ships()
		return GLOBAL_SHIPS:find(function (ship)
			return ship.player.id == %self.id;
		end);
	end

	--- Gets the difficulty of the player (if human, will be 0)
	function modkit_player_proto:difficulty()
		return Player_GetLevelOfDifficulty(self.id);
	end

	-- Whether or not the player is human
	function modkit_player_proto:isHuman()
		return self:difficulty() == 0;
	end

	-- Gets or sets the amount of RUs the player has
	function modkit_player_proto:RU(amount)
		if (amount) then
			Player_SetRU(self.id, amount);
		end
		return Player_GetRU(self.id);		
	end

	-- Gets the total RUs gathered by this player
	function modkit_player_proto:gatheredRUs()
		return Player_GatheredRUs(self.id);
	end

	-- === research stuff ===

	function modkit_player_proto:canResearch(item)
		local name = modkit.research:resolveName(item); -- item or item.name if table
		return Player_CanResearch(self.id, name);
	end

	function modkit_player_proto:grantAllResearch()
		return Player_GrantAllResearch(self.id);
	end

	function modkit_player_proto:grantResearchOption(item)
		local name = modkit.research:resolveName(item);
		return Player_GrantResearchOption(self.id, name);
	end

	function modkit_player_proto:hasQueuedResearch(item)
		local name = modkit.research:resolveName(item);
		return Player_HasQueuedResearch(self.id, name);
	end

	function modkit_player_proto:hasResearch(item)
		local name = modkit.research:resolveName(item);
		return Player_HasResearch(self.id, name);
	end

	function modkit_player_proto:doResearch(item)
		local name = modkit.research:resolveName(item);
		return Player_Research(self.id, name);
	end

	function modkit_player_proto:isResearching(item)
		local name = modkit.research:resolveName(item);
		return Player_IsResearching(name);
	end

	function modkit_player_proto:cancelResearch(item)
		local name = modkit.research:resolveName(item);
		return Player_CancelResearch(self.id, name);
	end

	function modkit_player_proto:restrictResearchOption(item, restrict)
		local name = modkit.research:resolveName(item);
		if (restrict) then
			if (restrict == 1) then
				return Player_RestrictResearchOption(self.id, name);
			else
				return Player_UnRestrictResearchOption(self.id, name);
			end
		end
	end

	function modkit_player_proto:researchCost(item, amount)
		local name = modkit.research:resolveName(item);
		if (amount) then
			Player_SetResearchCost(self.id, name, amount);
		end
		return Player_GetResearchCost(self.id, name);
	end

	function modkit_player_proto:hasResearchFor(ship_type)
		return Player_HasResearchPrequisitesToBuild(self.id, ship_type);
	end

	-- === end of research stuff ===

	-- Returns this player's team.
	-- Note: the team numbers we record internally may not match those chosen in lobby.
	-- Functionally, this won't matter.
	function modkit_player_proto:team()
		local team = GLOBAL_PLAYERS:filter(function (player)
			return AreAllied(player.id, %self.id);
		end);
	end

	--- Kills this player.
	function modkit_player_proto:kill()
		return Player_Kill(self.id);
	end

	--- Whether or not the player is alive.
	function modkit_player_proto:isAlive()
		return Player_IsAlive(self.id);
	end

	--- Returns whether or not the player has this subsystem.
	-- Kinda weird that this exists
	function modkit_player_proto:hasSubsystem(subsystem)
		return Player_HasSubsystem(self.id, subsystem);
	end

	-- === build stuff ===

	function modkit_player_proto:hasProductionShips()
		return Player_HasShipWithBuildQueue(self.id);
	end

	function modkit_player_proto:restrictBuildOption(option, restrict)
		if (restrict) then
			if (restrict == 1) then
				Player_RestrictBuildOption(self.id, option);
			else
				Player_UnrestrictBuildOption(self.id, option);
			end
		end
		return Player_BuildOptionIsRestricted(self.id, option);
	end
end