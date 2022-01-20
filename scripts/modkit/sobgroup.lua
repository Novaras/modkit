-- sobgroup.lua: populates the global scope with extra custom SobGroup_ functions.
-- By: Fear (Novaras)

if (H_SOBGROUP ~= 1) then
	--- Creates a new sobgroup if one doesn't exist, then clears the group to ensure the group referenced by the return string is clear.
	---@param name string The name of the SobGroup to create/clear.
	---@return string
	function SobGroup_Fresh(name)
		SobGroup_CreateIfNotExist(name);
		SobGroup_Clear(name);
		return name;
	end

	--- Overwrites `target_group` with the content of `incoming_group`.
	---@param target_group string The name of the group to overwrite
	---@param incoming_group string The name of the group which will overwrite `target_group`
	---@return string
	function SobGroup_Overwrite(target_group, incoming_group)
		SobGroup_Clear(target_group)
		SobGroup_SobGroupAdd(target_group, incoming_group)
		return target_group;
	end

	--- Creates a new SobGroup, named with `new_name`, or '<original-name>-clone', if a new name is not provided for the group.
	---@param original string The original group
	---@param new_name string The name of the new SobGroup created
	---@return string
	function SobGroup_Clone(original, new_name)
		new_name = new_name or (original .. "-clone");
		SobGroup_Fresh(new_name);
		SobGroup_SobGroupAdd(new_name, original);
		return new_name;
	end

	--- Disable scuttle while a captured unit is being dropped off by salvage corvettes.
	-- Actually polls whether the group is performing AB_Dock to perform this check.
	---@param group string The group which will have its AB_Scuttle ability disabled
	function SobGroup_NoSalvageScuttle(group)
		SobGroup_AbilityActivate(group, AB_Scuttle, 1 - SobGroup_IsDoingAbility(group, AB_Dock));
		return group;
	end

	--- When a docking squadron is under attack, they sometimes glitch and stop. This issues another dock order to dock with the closest ship.
	---@param group string The group which will be polled, and then issued a new dock command under certain conditions
	---@return string
	function SobGroup_UnderAttackReissueDock(group)
		if (SobGroup_GetCurrentOrder(group) == COMMAND_Dock) then -- en route to dock
			if (SobGroup_UnderAttack(group)) then -- under attack
				if (SobGroup_Count(group) < SobGroup_GetStaticF(group, "buildBatch")) then -- lost one or more members
					if (SobGroup_IsDocked(group) == 0) then -- no member of this squad is docked
						if (SobGroup_GetActualSpeed(group) < 50) then -- probably bugged into stopping - could get unlucky here and catch a pivoting squad
							SobGroup_DockSobGroupWithAny(group)
						end
					end
				end
			end
		end
		return group;
	end

	--- Checks to see if any ship in `group` is being captured.
	---@param group string The group to check
	---@return string
	function SobGroup_AnyBeingCaptured(group)
		local group_being_captured = group .. "_being_captured"
		SobGroup_Fresh(group_being_captured)
		SobGroup_GetSobGroupBeingCapturedGroup(group, group_being_captured)
		if (SobGroup_Count(group_being_captured) > 0) then
			return 1
		end
		return 0
	end

	--- Checks to see if any ship in `group` has attack targets.
	---@param group string The group to check
	---@return string
	function SobGroup_AnyAreAttacking(group)
		local group_attacking = group .. "_attacking"
		SobGroup_Fresh(group_attacking)
		SobGroup_GetCommandTargets(group_attacking, group, COMMAND_Attack)
		if (SobGroup_Count(group_attacking) > 0) then
			return 1
		end
		return 0
	end

	--- Returns a group of all active ships for all players.
	---@param target_group string | nil A group which will be filled with all the Universe ships. If not provided, is ignored and a new group is used.
	---@return string
	function Universe_GetAllActiveShips(target_group)
		local all_ships = SobGroup_Fresh("all-ships");
		for i = 0, Universe_PlayerCount() - 1 do
			if (Player_IsAlive(i)) then
				SobGroup_SobGroupAdd(all_ships, "Player_Ships" .. i);
			end
		end
		if (target_group ~= nil) then
			SobGroup_CreateIfNotExist(target_group);
			SobGroup_Clear(target_group);
			SobGroup_SobGroupAdd(target_group, all_ships);
			return target_group;
		end
		return all_ships;
	end

	--- Multiplies the group's max-speed multiplier by 'mult'.
	---@param target_group string The group to modify
	---@param mult number A factor which is multiplied with the *current* speed multiplier, then applied with `SobGroup_SetSpeed`.
	---@return string
	function SobGroup_AlterSpeedMult(target_group, mult)
		if (mult == nil) then
			mult = 1/2
		end
		local speed_mult = SobGroup_GetSpeed(target_group) * mult
		if (speed_mult < 0.05) then
			speed_mult = 0
		end
		SobGroup_SetSpeed(target_group, speed_mult)

		return target_group
	end

	STUN_EFFECT_ABILITIES = {
		AB_Cloak,
		-- AB_AcceptDocking,
		-- AB_Builder,
		AB_Hyperspace,
		AB_FormHyperspaceGate,
		AB_HyperspaceViaGate,
		AB_SpecialAttack,
		AB_DefenseField,
		AB_DefenseFieldShield,
		AB_Steering,
		AB_Targeting,
		AB_Lights,
		AB_Move,
		AB_Mine,
		AB_Custom,
		AB_Dock,
		AB_Parade,
		AB_Retire,
		AB_Repair
	}
	STUN_EFFECT_EVENT = "PowerOff"

	--- Sets whether the given group should be 'stunned' or not (AB_Move/AB_Steering/AB_Attack/AB_Targeting).
	-- See globals `STUN_EFFECT_ABILITIES` and `STUN_EFFECT_EVENT`.
	---@param target_group string The group to stun/unstun
	---@param stunned number Whether or not to stun the group (1 = stun, 0 = free)
	---@return string
	function SobGroup_SetGroupStunned(target_group, stunned)
		if (SobGroup_Count(target_group) > 0) then
			if (stunned == 1) then
				FX_StartEvent(target_group, STUN_EFFECT_EVENT)
				SobGroup_Disable(target_group, 1)
			else
				FX_StopEvent(target_group, STUN_EFFECT_EVENT)
				SobGroup_Disable(target_group, 0)
			end
			local ability_status = mod(stunned + 1, 2) -- 0 -> 1, 1 -> 0, 2 -> 1, ...
			for _, ability in STUN_EFFECT_ABILITIES do
				SobGroup_AbilityActivate(target_group, ability, ability_status)
			end
		end
		return target_group
	end

	--- Gets the distance (as an integer) between two SobGroups.
	-- (Presumable) Credits to SunTzu: https://github.com/HWRM/KarosGraveyard/wiki/UserFunction;-SobGroup_GetDistanceToSobGroup
	---@param group_a string A SobGroup in real space
	---@param group_b string A SobGroup in real space
	---@return number
	function SobGroup_GetDistanceToSobGroup(group_a, group_b)
		if SobGroup_Empty(group_a) == 0 and SobGroup_Empty(group_b) == 0 then
			local t_position1 = SobGroup_GetPosition(group_a)
			local t_position2 = SobGroup_GetPosition(group_b)
			local li_distance = floor(sqrt((t_position1[1] - t_position2[1])*(t_position1[1] - t_position2[1]) + (t_position1[2] - t_position2[2])*(t_position1[2] - t_position2[2]) + (t_position1[3] - t_position2[3])*(t_position1[3] - t_position2[3])))
			return li_distance
		else
			return nil
		end
	end

	--- Gets the current HP of the group (as a fraction, ala SobGroup_SetHealth).
	---@param group string The SobGroup who's health to check
	---@return number
	function SobGroup_GetHealth(group)
		local max_health = SobGroup_MaxHealthTotal(group);
		local current_health = SobGroup_CurrentHealthTotal(group);
		return (current_health / max_health);
	end

	--- Creates a new volume of type `vol_type` ("sphere", "cube") named `name` with radius `radius` at position `position`.
	--- Only a `name` is required. By default, `position` is `{ 0, 0, 0 }`, `radius` is `10` and `vol_type` is `"sphere"`.
	--- Returns the supplied `name`.
	---
	---@param name any
	---@param position table
	---@param radius integer
	---@param vol_type string
	---@return string
	function Volume_Fresh(name, position, radius, vol_type)
		position = position or { 0, 0, 0 };
		radius = radius or 10;
		vol_type = vol_type or "sphere";
		Volume_Delete(name);
		local vol_type_calls = {
			sphere = function() return Volume_AddSphere(%name, %position, %radius); end,
			cube = function () return Volume_AddCube(%name, %position, %radius); end
		};
		vol_type_calls[vol_type]();
		return name;
	end

	DEFAULT_SOBGROUP = SobGroup_Fresh("__")

	print("executed: sobgroup.lua")
	H_SOBGROUP = 1
end