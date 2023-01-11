-- memgroup for players
-- Also a prototype for player entities. This is how modkit provides the Player_ API.

if (modkit == nil) then modkit = {}; end
if (modkit.MemGroup == nil) then dofilepath("data:scripts/modkit/memgroup.lua"); end
if (GLOBAL_TEAMS == nil) then dofilepath("data:scripts/modkit/team.lua"); end

if (modkit_player_proto == nil) then

	-- global memgroup for players

	function initPlayers()
		if (GLOBAL_PLAYERS == nil) then
			---@class GLOBAL_PLAYERS : MemGroupInst
			---@field _entities Player[]
			---@field get fun(self: GLOBAL_PLAYERS, id: integer): Player
			GLOBAL_PLAYERS = modkit.MemGroup.Create("mg-players-global");

			---comment
			---@param player Player
			local ensureIndicatorTech = function (player)
				local granted = nil;
				for _, racename in modkit.races:names() do
					local res_name = "race" .. racename;

					if (player:canResearch(res_name)) then
						player:grantResearchOption(res_name);
					end
				end
			end

			for i = 0, Universe_PlayerCount() - 1 do
				local player = GLOBAL_PLAYERS:set(i, modkit.table:merge(
					modkit_player_proto,
					{
						id = i
					}
				));
				ensureIndicatorTech(player);
			end

			-- map/ambient units
			GLOBAL_PLAYERS:set(-1, modkit.table:merge(
				modkit_player_proto,
				{
					id = -1,
					race = modkit.table.find(modkit.races.racelist, function (race_conf)
						return race_conf.name == 'hiigaran';
					end);
				}
			));

			function GLOBAL_PLAYERS:all()
				local out = {};
				for i, player in self._entities do
					if (i >= 0) then
						out[i] = player;
					end
				end
				return out;
			end

			function GLOBAL_PLAYERS:alive()
				return modkit.table.filter(self:all(), function (player)
					return player:isAlive();
				end);
			end

			function GLOBAL_PLAYERS:human()
				return modkit.table.filter(self:all(), function (player)
					return player:isHuman();
				end);
			end
		end
	end

	-- Note that the `id` field is only set later when the player is actually constructed later

	---@class Player
	---@field id integer
	---@field _race? RaceConfig Index of `modkit.races.racelist`
	modkit_player_proto = {};

	function modkit_player_proto:shipsGroup()
		return "Player_Ships" .. self.id;
	end

	--- Gets the player's ships (alive ships)
	---
	---@return Ship[]
	function modkit_player_proto:ships()
		return GLOBAL_SHIPS:allied(self, function (ship)
			return ship.player.id == %self.id;
		end);
	end

	--- Gets the difficulty of the player (if human, will be 0)
	function modkit_player_proto:difficulty()
		return Player_GetLevelOfDifficulty(self.id);
	end

	-- Whether or not the player is human
	---@return bool
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

	--- Returns whether or not this player is capable of researching `item`.
	---
	---@param item string | table
	---@return bool
	function modkit_player_proto:canResearch(item)
		local name = modkit.research:resolveName(item); -- item or item.name if table
		if (name) then
			-- print("can " .. self.id  .. " res " .. name .. "?: " .. (Player_CanResearch(self.id, name) or 'nil'));
			return Player_CanResearch(self.id, name) == 1;
		end
	end

	--- Grants all research items to this player.
	function modkit_player_proto:grantAllResearch()
		return Player_GrantAllResearch(self.id);
	end

	--- Grants the named research _option_ to this player (they still need to research it).
	---
	---@param item string | ResearchItem
	---@param recursive? bool
	function modkit_player_proto:grantResearchOption(item, recursive)
		print("TG: " .. tostring(item));
		if (type(item) == "string") then
			item = modkit.research:find(strlower(item));
		end

		if (self:canResearch(item) == 1) then
			local name = modkit.research:resolveName(item);
			consoleLog("granting " .. name);
			return Player_GrantResearchOption(self.id, name);
		elseif (recursive and strlen(item.requiredresearch) > 0) then
			-- SuperHeavyChassis & SuperCapitalShipDrive | IonCannons
			-- f('SuperHeavyChassis')

			local requirementStrToLuaCalls = function (str, fn_name, fn_args)
				local args_str = strimplode(fn_args, ', ');
				local exec = gsub(str, '(%w+)', fn_name .. '(' .. args_str .. ')');
				exec = gsub(exec, '[&]', 'and')
				exec = gsub(exec, '[|]', 'or');
				exec = "dofilepath('data:scripts/modkit/player.lua'); player = GLOBAL_PLAYERS:get(" .. %self.id .. "); " .. exec;
				-- print("REQS: " .. exec);
				return exec;
			end

			local res_reqs_exec = requirementStrToLuaCalls(item.requiredresearch, 'player:grantResearchOption', { '"%1"', 1 });
			print(res_reqs_exec);
			dostring(res_reqs_exec);

			self:grantResearchOption(item);
		end
	end

	function modkit_player_proto:hasQueuedResearch(item)
		local name = modkit.research:resolveName(item);
		return Player_HasQueuedResearch(self.id, name);
	end

	--- Returns where or not this player has _researched_ the given item (or it was granted).
	---
	---@param item string | table
	---@return bool
	function modkit_player_proto:hasResearch(item)
		local name = modkit.research:resolveName(item);
		if (name) then
			-- print("does " .. self.id  .. " have res " .. name .. "?: " .. (Player_HasResearch(self.id, name) or 'nil'));
			return Player_HasResearch(self.id, name) == 1;
		end
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
				return Player_UnrestrictResearchOption(self.id, name);
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
		return Player_HasResearchPrequisitesToBuild(self.id, ship_type) == 1;
	end

	--- Checks if the player has any ship with a research module. Includes hw1 research ships.
	---
	---@return bool
	function modkit_player_proto:hasResearchCapableShip()
		-- for _, name in {
		-- 	'hgn_c_module_research',
		-- 	'hgn_c_module_researchadvanced',
		-- 	'hgn_ms_module_research',
		-- 	'hgn_ms_module_researchadvanced',
		-- 	'vgr_c_module_research',
		-- 	'vgr_ms_module_research',
		-- 	'hw1_researchmodule'
		-- } do
		-- 	if (self:hasSubsystem(name)) then
		-- 		return 1;
		-- 	end
		-- end
		return modkit.table.find(self:ships(), function (ship)
			return ship:hasResearchModule();
		end);
	end

	-- === end of research stuff ===

	--- Return `1` if this player is allied with the `other`. `0` otherwise.
	---@param other Player
	---@return bool
	function modkit_player_proto:alliedWith(other)
		if (self.id == -1 or other.id == -1) then
			return nil;
		end
		return self.id == other.id or AreAllied(self.id, other.id) == 1;
	end

	--- Returns the players team, which is a high level type just like players and ships.
	--- When this function is called, if there is team containing this player or an ally of this player,
	--- then a new team is created for it. If there is a team with only allies, this player is added to the team.
	---@return table
	---@deprecated
	function modkit_player_proto:team()
		local team = GLOBAL_TEAMS:find(function (team)
			local only_allies = 1;
			local belongs_to_team = nil;
			for _, player in team.players do
				if (%self.id == player().id) then
					only_allies = 0;
					belongs_to_team = 1;
					break;
				elseif (%self:alliedWith(player())) then
					belongs_to_team = 1; -- any non-nil return will pass
				end
			end
			if (only_allies) then -- we need to add this player to this team
				local outer_self = %self; -- lua :)
				team.players = modkit.table:merge(
					team.players,
					{
						[%self.id] = function ()
							return %outer_self;
						end
					}
				)
			end
			return belongs_to_team;
		end);

		-- undiscovered team, add it
		if (team == nil) then
			team = GLOBAL_TEAMS:set(GLOBAL_TEAMS:length() + 1, modkit.table:merge(
				modkit_teams_proto,
				{
					players = {
						[self.id] = function ()
							return %self;
						end
					}
				}
			))
		end

		return team;
	end

	--- Returns the player's race info, initialising it if its not already set.
	---
	---@return RaceConfig|nil
	function modkit_player_proto:race()
		self._race = self._race or modkit.table.find(modkit.races.racelist, function (race_cfg)
			print("ATTEMPT TO FIND " .. 'race' .. race_cfg.name);
			local tech = modkit.research:find('race' .. race_cfg.name, race_cfg.name);
			print("(check for " .. tostring(tech) .. ")");
			return %self:hasResearch(tech);
		end);

		return self._race;
	end

	--- Kills this player.
	function modkit_player_proto:kill()
		return Player_Kill(self.id);
	end

	--- Causes all ships of this player to attack all ships of another player.
	---
	---@param other Player
	function modkit_player_proto:attack(other)
		for _, ship in self:ships() do
			ship:attack(other:ships());
		end
	end

	--- Whether or not the player is alive.
	---@return bool
	function modkit_player_proto:isAlive()
		return Player_IsAlive(self.id) == 1;
	end

	--- Returns whether or not the player has this subsystem on any ship.
	---
	---@param subsystem_type string
	---@return bool
	function modkit_player_proto:hasSubsystem(subsystem_type)
		return Player_HasSubsystem(self.id, subsystem_type) == 1;
	end

	-- === build stuff ===

	function modkit_player_proto:hasProductionShips()
		return Player_HasShipWithBuildQueue(self.id);
	end

	function modkit_player_proto:restrictBuildOption(option, restrict)
		if (type(option) ~= "table") then
			option = { option };
		end
		local after = {};
		for _, opt in option do
			if (restrict) then
				if (restrict == 0) then
					Player_UnrestrictBuildOption(self.id, opt);
					after[opt] = 0;
				else
					Player_RestrictBuildOption(self.id, opt);
					after[opt] = 1;
				end
			end
		end

		return after;
	end

	-- === stats getters (more to come pls)

	function modkit_player_proto:fleetValue()
		return modkit.table.reduce(
			self:ships(),
			function (total, ship)
				return total + ship:buildCost();
			end,
			0
		);
	end
end