-- memgroup for players

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end
if (modkit_team_proto == nil) then dofilepath("data:scripts/modkit/team.lua"); end

if (modkit_player_proto == nil) then

	-- global memgroup for players
	GLOBAL_PLAYERS = modkit.MemGroup.Create("mg-players-global");

	modkit_player_proto = {};

	function modkit_player_proto:difficulty()
		return Player_GetLevelOfDifficulty(self.id);
	end

	function modkit_player_proto:isHuman()
		return self:difficulty() > 0;
	end

	function modkit_player_proto:RU(amount)
		if (amount) then
			Player_SetRU(self.id, amount);
		end
		return Player_GetRU(self.id);		
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

	function modkit_player_proto:restrictResearchOption(item, restrict)
		local name = modkit.research:resolveName(item);
		if (restrict) then
			return Player_RestrictResearchOption(self.id, name);
		else
			return Player_UnRestrictResearchOption(self.id, name);
		end
	end

	-- === end of research stuff ===

	function modkit_player_proto:team()
		local team = GLOBAL_PLAYERS:filter(function (player)
			return AreAllied(player.id, %self.id);
		end);
	end

	function modkit_player_proto:kill()
		return Player_Kill(self.id);
	end
end