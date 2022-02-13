-- Custom definitions file to allow sumneko.lua to provide completion/hover/etc. for HWRM globals.

-- Notice we never run this code, these defines are just used for IDE assistance.

if (nil) then

	---@alias bool '1'|'nil'

	AB_None = 0;
	AB_Move = 1;
	AB_Attack = 2;
	AB_Guard = 3;
	AB_Repair = 4;
	AB_Cloak = 5;
	AB_Harvest = 6;
	AB_Mine = 7;
	AB_Capture = 8;
	AB_Dock = 9;
	AB_AcceptDocking = 10;
	AB_Builder = 11;
	AB_Stop = 12;
	AB_Hyperspace = 13;
	AB_Parade = 14;
	AB_FormHyperspaceGate = 15;
	AB_HyperspaceViaGate = 16;
	AB_SensorPing = 17;
	AB_SpecialAttack = 18;
	AB_Retire = 19;
	AB_DefenseField = 20;
	AB_DefenseFieldShield = 21;
	AB_HyperspaceInhibitor = 22;
	AB_Salvage = 23;
	AB_Scuttle = 24;
	AB_UseSpecialWeaponsInNormalAttack = 25;
	AB_Steering = 26;
	AB_Targeting = 27;
	AB_Sensors = 28;
	AB_Lights = 29;
	AB_Custom = 31;

	COMMAND_Idle = 0;
	COMMAND_Move = 1;
	COMMAND_Attack = 2;
	COMMAND_Build = 3;
	COMMAND_Dock = 4;
	COMMAND_Resource = 5;
	COMMAND_Launch = 6;
	COMMAND_WaypointMove = 7;
	COMMAND_Parade = 8;
	COMMAND_Guard = 9;
	COMMAND_Capture = 10;
	COMMAND_Hyperspace = 11;
	COMMAND_MoveToSob = 12;
	COMMAND_FormHyperspaceGate = 13;
	COMMAND_HyperspaceViaGate = 14;
	COMMAND_Repair = 15;
	COMMAND_Retire = 16;
	-- ...todo

	-- used by UI_ShowScreen
	ePopup = 0;
	eTransition = 1;

	---@alias ScreenTransition '0' | '1' | 'ePopup' | 'eTransition'

	VisNone = 0;
	VisSecondary = 1;
	VisFull = 2;

	---@alias Visibility 'VisNone'|'VisSecondary'|'VisFull'

	OffensiveROE = 0;
	DefensiveROE = 1;
	PassiveROE = 2;

	---@alias ROE 'OffensiveROE'|'DefensiveROE'|'PassiveROE'

	AggressiveStance = 0;
	NeutralStance = 1;
	EvasiveStance = 2;

	---@alias Stance 'AggressiveStance'|'NeutralStance'|'EvasiveStance'

	ShipHoldLaunch = 0;
	ShipHoldStayDockedUpToLimit = 1;
	ShipHoldStayDockedAlways = 2;

	---@alias AutoLaunchStatus 'ShipHoldLaunch'|'ShipHoldStayDockedUpToLimit'|'ShipHoldStayDockedAlways'

	--- probably needs updating, see https://github.com/HWRM/KarosGraveyard/wiki/Modifiable-Values
	---@alias ShipMultiplier
	---| '"BuildSpeed"'
	---| '"Capture"'
	---| '"CloakDetection"'
	---| '"CloakingStrength"'
	---| '"CloakingTime"'
	---| '"DefenseFieldTime"'
	---| '"DustCloudSensitivity"'
	---| '"HealthRegenerationRate"'
	---| '"HyperSpaceAbortDamage"'
	---| '"HyperSpaceCost"'
	---| '"HyperSpaceTime"'
	---| '"HyperSpaceRecoveryTime"'
	---| '"MaxHealth"'
	---| '"MaxShield"'
	---| '"MaxSpeed"'
	---| '"NebulaSensitivity"'
	---| '"PrimarySensorsRange"'
	---| '"ResourceCapacity"'
	---| '"ResourceCollectionRate"'
	---| '"ResourceCapacity"'
	---| '"ResourceCollectionRate"'
	---| '"SecondarySensorsRange"'
	---| '"SensorDistortion"'
	---| '"VisualRange"'
	---| '"Speed"'
	---| '"WeaponDamage"'
	---| '"WeaponAccuracy"'

	--- Just the values which can be modified via `SobGroup_` calls
	---@alias RuntimeShipMultiplier
	---| '"BuildSpeed"' # `SobGroup_SetBuildSpeedMultiplier`
	---| '"WeaponDamage"' # `SobGroup_SetDamageMultiplier`
	---| '"MaxSpeed"' # `SobGroup_SetMaxSpeedMultiplier`

	---@param str string
	---@param start number
	---@param finish number
	---@return string
	function strsub(str, start, finish)
	end

	---@param str string
	---@return string
	function strlower(str)
	end

	--- Executes the given string as a Lua chunk.
	---
	---@param str string
	---@return any
	function dostring(str)
	end

	--- Loads and executes the contents of another lua script at the position this function was invoked.
	--- This function accepts certain path aliases to make importing files easier: `data`, `bin`, `player`, `locale`, `builtin`, `gamerules`.
	--- Example: `dofilepath("data:ship/hgn_interceptor/hgn_interceptor.ship");`
	--- The return value is the return value of the loaded chunk, or non-nil if the chunk has no exports. If an error occurs, returns `nil`.
	---
	---@param path string
	---@return any
	function dofilepath(path)
	end

	--- Similar to `dofilepath`, but instead takes a `directory` as its first argument and a `pattern` to match against the files within that directory.
	--- Files matching the `pattern` are executed similar to `dofilepath`.
	--- Example: `doscanpath("data:scripts/races/hiigaran/scripts/research", "*.lua");` Will load all the lua files in the `research` directory.
	--- Note that this function is _not_ recursive, and the exact pattern language is not known (maybe regex? Definitely not lua patterns).
	---
	---@param directory string
	---@param pattern string
	---@return any
	function doscanpath(directory, pattern)
	end

	--- Receives any number of arguments and prints their values to stdout, converting each argument to a string following the same rules of `tostring`.
	---
	--- **The location of `stdout` is `HomeworldRM\Bin\Release\HwRM.log`**.
	---
	---@vararg any
	---@return nil
	function print(...)
	end


	--- When called without arguments, returns a pseudo-random real number in the range [`0`,`1`].
	---
	--- When called with a number `a`, returns a pseudo-random integer in the range [`1`, `a`].
	---
	--- When called with _two_ arguments, `a` and `b`, returns a pseudo-random integer in the range [`a`, `b`].
	---
	---@overload fun(a: number): integer
	---@overload fun(a: number, b: number): integer
	---@return number
	function random()
	end

	--- Rounds `num` rounded _up_ to the nearest integer.
	---
	---@param num number
	---@return integer
	function ceil(num)
	end

	--- Rounds `num` rounded _down_ to the nearest integer.
	---
	---@param num number
	---@return integer
	function floor(num)
	end

	---Returns the cosine of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function cos(num)
	end

	---Returns the arccosine of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function acos(num)
	end

	---Returns the sine of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function sin(num)
	end

	---Returns the arcsine of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function asin(num)
	end

	---Returns the tangent of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function tan(num)
	end

	---Returns the arctangent of `num` (which is in degrees).
	---
	---@param num number
	---@return number
	function atan(num)
	end

	---Returns the angle between the X axis of a graph and a line drawn to a point (`x`, `y`) on that graph.
	---
	---@param x number
	---@param y number
	---@return number
	function atan2(x, y)
	end

	--- ==== PLAYER STUFF! ====

	--- Returns the current RU amount owned by the given player.
	---@param player_index integer
	function Player_GetRU(player_index)
	end

	--- Sets the RU _total_ for the given player.
	---
	---@param player_index integer
	---@param amount integer
	function Player_SetRU(player_index, amount)
	end

	--- ==== SOBGROUP STUFF! ====

	--- Activates the ability indicated by `ability_code` (see [the full list](https://github.com/HWRM/KarosGraveyard/wiki/Variable;-Abilities))
	---
	---@param group_name string
	---@param ability_code integer
	---@param activate integer
	---@return nil
	function SobGroup_AbilityActivate(group_name, ability_code, activate)
	end

	--- Fills `group_to_fill` with all the ships from `source_group` where the ship's `filter_key` property **does _not_ match** `filter_val`.
	--- The return value is the number of ships in `group_to_fill` after performing the filtration.
	--- This function is essentially identical to `SobGroup_FilterExclude`, but doesn't overwrite the contents of `group_to_fill`, and adds to this group instead.
	---
	---@param group_to_fill string
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_AddFilterExclude(group_to_fill, source_group, filter_key, filter_val)
	end

	--- Fills `group_to_fill` with all the ships from `source_group` where the ship's `filter_key` property **does _not_ match** `filter_val`.
	--- The return value is the number of ships in `group_to_fill` after performing the filtration.
	---
	---@param group_to_fill string
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_FilterExclude(group_to_fill, source_group, filter_key, filter_val)
	end

	--- Returns the number of squadrons (usually 1-1 with number of ships) within group `source_group`.
	---
	---@param source_group string
	---@return integer
	function SobGroup_Count(source_group)
	end

	--- Returns the number of squadrons (usually 1-1 with the number of ships) within group `source_group` belonging to `player_index`.
	---
	---@param source_group string
	---@param player_index integer
	---@return integer
	function SobGroup_CountByPlayer(source_group, player_index)
	end

	--- Useful as a shortcut for `SobGroup_FilterExclude`, where we don't want to create a new group and count it, but just want the count directly.
	---
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_CountByFilterExclude(source_group, filter_key, filter_val)
	end

	--- Fills `group_to_fill` with all the ships from `source_group` where the ship's `filter_key` property matches `filter_val`.
	--- The return value is the number of ships in `group_to_fill` after performing the filtration.
	--- This function is essentially identical to `SobGroup_FilterInclude`, but doesn't overwrite the contents of `group_to_fill`, and adds to this group instead.
	---
	---@param group_to_fill string
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_AddFilterInclude(group_to_fill, source_group, filter_key, filter_val)
	end

	--- Fills `group_to_fill` with all the ships from `source_group` where the ship's `filter_key` property matches `filter_val`.
	--- The return value is the number of ships in `group_to_fill` after performing the filtration.
	---
	---@param group_to_fill string
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_FilterInclude(group_to_fill, source_group, filter_key, filter_val)
	end

	--- Useful as a shortcut for `SobGroup_FilterInclude`, where we don't want to create a new group and count it, but just want the count directly.
	---
	---@param source_group string
	---@param filter_key string
	---@param filter_val string
	---@return integer
	function SobGroup_CountByFilterInclude(source_group, filter_key, filter_val)
	end

	--- Enables or disables 'passive actions' for the specified `group_name`, regardless of whether ships in this group are in special states such as hyperspace.
	---'Passive actions' appears to mean any non-combat action such as docking, launching, building. Note that this doesn't not enable or add new abilities to ships.
	---
	---@param group_name string
	---@param allowed integer
	---@return nil
	function SobGroup_AllowPassiveActionsAlways(group_name, allowed)
	end


	--- Returns `1` if all ships in `group_name` are in hyperspace, `0` otherwise.
	---
	---@param group_name any
	---@return integer
	function SobGroup_AreAllInHyperspace(group_name)
	end

	--- Returns `1` if all ships in `group_name` are in real space (not in hyperspace or despawned, but docking etc. is fine), `0` otherwise.
	---
	---@param group_name string
	---@return integer
	function SobGroup_AreAllInRealSpace(group_name)
	end

	--- Returns `1` if any ships in `group_name` have an attack family included in the supplied list of `family_list`, which is a comma-seperated string list of attack families.
	--- See `familylist.lua` for the full list of attack families. This list is case-insensitive.
	---
	---@param group_name string
	---@param family_list string
	---@return any
	function SobGroup_AreAnyFromTheseAttackFamilies(group_name, family_list)
	end

	--- Returns `1` if any ships in `group_name` have a type included in the supplied list of `type_list`, which is a comma-seperated string list of ship types (i.e `"hgn_interceptor, hgn_attackbomber"`).
	--- Any ship name which is properly defined in `ship/` is a valid ship type. This list is case-insensitive.
	---
	---@param group_name string
	---@param type_list string
	---@return integer
	function SobGroup_AreAnyOfTheseTypes(group_name, type_list)
	end

	--- TODO: construction and behavior of `cloud_list` is not tested. Valid cloud names are _probably_ any valid clouds in `resources/dustclouds/`.
	--- Returns `1` if any ships in `group_name` are inside any cloud found in `cloud_list`, else `0`.
	---
	---@param group_name string
	---@param cloud_list string
	---@return integer
	function SobGroup_AreAnySquadronsInsideDustCloud(group_name, cloud_list)
	end

	--- TODO: construction and behavior of `cloud_list` is not tested. Valid nebula names are _probably_ any valid nebula in `resources/dusclouds/`.
	--- Returns `1` if any ships in `group_name` are outside any cloud found in `cloud_list`, else `0`.
	---
	---@param group_name string
	---@param cloud_list string
	---@return integer
	function SobGroup_AreAnySquadronsOutsideDustCloud(group_name, cloud_list)
	end

	--- TODO: construction and behavior of `nebula_list` is not tested. Valid nebula names are _probably_ any valid nebula in `resources/nebula`.
	--- Returns `1` if any ships in `group_name` are inside any nebula found in `nebula_list`, else `0`.
	---
	---@param group_name string
	---@param nebula_list string
	---@return integer
	function SobGroup_AreAnySquadronsInsideNebula(group_name, nebula_list)
	end

	--- TODO: construction and behavior of `nebula_list` is not tested. Valid nebula names are _probably_ any valid nebula in `resources/nebula`.
	--- Returns `1` if any ships in `group_name` are outside any nebula found in `nebula_list`, else `0`.
	---
	---@param group_name string
	---@param nebula_list string
	---@return integer
	function SobGroup_AreAnySquadronsOutsideNebula(group_name, nebula_list)
	end

	--- Returns `1` if any ships in `group_name` are assigned to the control group specified by `control_group_index`.
	---
	---@param group_name string
	---@param control_group_index integer
	---@return integer
	function SobGroup_AssignedToGroup(group_name, control_group_index)
	end

	--- Makes all ships in `group_name` _which belong to the player `player_index`_ attack ships in `target_group`.
	---
	---@param player_index integer
	---@param group_name string
	---@param target_group string
	---@return nil
	function SobGroup_Attack(player_index, group_name, target_group)
	end

	--- Causes all ships in `group_name` to attack ships belonging to player `player_index`.
	---
	---@param group_name string
	---@param player_index integer
	---@return nil
	function SobGroup_AttackPlayer(group_name, player_index)
	end

	--- in progress...
	---@param player_index integer
	---@param group_name string
	---@param target_selection string
	---@param attack '0'|'1'
	function SobGroup_AttackSelection(player_index, group_name, target_selection, attack)
	end

	--- Makes ships with capture ability in `group_name` begin capturing viable ships in `target_group`.
	---
	---@param group_name string
	---@param target_group string
	function SobGroup_CaptureSobGroup(group_name, target_group)
	end

	--- Causes the first valid ship in `group_name` to instantly build the given subsystem.
	---
	--- The second param can also be the _type_ of subs, i.e `FighterProduction`, `AdvancedResearch`, etc.
	---
	---@param group_name string
	---@param subs_name_or_type string
	function SobGroup_CreateSubSystem(group_name, subs_name_or_type)
	end

	--- Makes ships with salvage ability in `group_name` begin salvaging viabel ships in `target_group`.
	---
	---@param group_name string
	---@param target_group string
	function SobGroup_SalvageSobGroup(group_name, target_group)
	end

	--- Fills `target_group` with the remainder after subtracting ships in `subtract_group` from `source_group`.
	---
	---@param target_group string
	---@param source_group string
	---@param subtract_group string
	function SobGroup_Substract(target_group, source_group, subtract_group)
	end

	--- Returns the average health of all ships in `target_group` (as a fraction between 0 and 1).
	---
	---@param target_group string
	---@return number
	function SobGroup_GetHealth(target_group)
	end

	--- Returns either the build cost or build time of `ship_type`.
	---
	--- **Ships in squads with a squadsize > 1 will report the cost of their whole squad.** Divide this value by
	--- `SobGroup_Count` to get the value of just ONE of this ship type.
	---
	---@param ship_type string
	---@param attribute "\"buildCost\"" | "\"buildTime\""
	---@return integer
	function SobGroup_GetStaticF(ship_type, attribute)
	end

	--- Returns `1` if any member of `group` hosts the given subsystem, else `0`.
	---
	---@param group string
	---@param subs_name string
	---@return '0' | '1'
	function SobGroup_HasSubsystem(group, subs_name)
	end

	--- Causes ships in `group` to hyperspace to the given position.
	---
	---@param group string
	---@param position Position
	function SobGroup_HyperSpaceTo(group, position)
	end

	---comment
	---@param group_name any
	function SobGroup_GetTechHarvestedAmount(group_name)
	end

	--- Clears the target `group_name` of any ships, if it exists.
	---
	---@param group_name string
	---@return nil
	function SobGroup_Clear(group_name)
	end

	--- Causes all ships in `group_name` to attack any subsystems mounted to `hardpoint_name` in `target_group`.
	---
	---@param group_name string
	---@param target_group string
	---@param hardpoint_name string
	---@return nil
	function SobGroup_AttackSobGroupHardPoint(group_name, target_group, hardpoint_name)
	end

	--- Removes any manual overrides set for the group's engine glow. See `SobGroup_ManualEngineGlow`.
	---
	---@param group_name string
	---@return nil
	function SobGroup_AutoEngineGlow(group_name)
	end

	--- Causes the engines for `group_name` to glow _as if_ the ships were moving at the `thrust_value` proportion of their total max thruster usage (`0` to `1`).
	--- Reset this with `SobGroup_AutoEngineGlow`.
	---
	---@param group_name string
	---@param thrust_value number
	---@return nil
	function SobGroup_ManualEngineGlow(group_name, thrust_value)
	end

	--- Spawn stuff

	--- Spawns a `ship_type` squadron named `new_squad_name`, and adds it to `target_group`. The squad is spawned at `volume_name`.
	---
	--- Note: A 'squad' can contain one ship; this function is not limited to HW2 strikecraft squadrons.
	---
	---@param player_index integer
	---@param ship_type string
	---@param new_squad_name string
	---@param target_group string
	---@param volume_name string
	---@return nil
	function SobGroup_SpawnNewShipInSobGroup(player_index, ship_type, new_squad_name, target_group, volume_name)
	end

	--- Causes ships in target_group to become 'ghosted', which is pretty much akin to a 'no-clip' mode whereby the affected ships ignore collision with other objects.
	---@param target_group string
	---@param enable '0'|'1'
	---@return nil
	function SobGroup_SetGhost(target_group, enable)
	end

	--- Sets the health of all ships in `target_group` to the `fraction` (between 0 and 1).
	---
	---@param target_group string
	---@param fraction number
	function SobGroup_SetHealth(target_group, fraction)
	end

	--- Sets the _inherent_ visibility of the `target_group` for player `target_player`.
	---
	--- Note: there is no corresponding getter for this value, so you should store it yourself if you need to get it later.
	---
	---@param target_group string
	---@param target_player integer
	---@param visibility Visibility
	---@return nil
	function SobGroup_SetInherentVisibility(target_group, target_player, visibility)
	end

	--- Adds all the ships in source_group to target_group. Both groups must exist before being passed to this function.
	---
	---@param source_group string
	---@param target_group string
	---@return nil
	function SobGroup_SobGroupAdd(source_group, target_group)
	end

	--- Selection stuff (NEEDS TESTING, USED ONLY BY DEFENSE FIGHTER CUSTOM CODE):

	--- Creates a new selection `selection_name` (returns nothing).
	---@param selection_name string
	function Selection_Create(selection_name)
	end

	--- Fills the given selection with all universe missiles.
	--- Returns the number of missiles selected.
	---
	---@param selection_name string
	---@return integer
	function Selection_GetMissiles(selection_name)
	end

	--- Fills `target_selection` with all entities in `source_selection` which satisfy `filter_type` for `value_1`, and optionally `value_2`.
	--- Returns the number of entities left after filtering.
	---
	--- Note: `value_2` is not optional, you should pass an empty string for nil.
	---
	---@param target_selection string
	---@param source_selection string
	---@param filter_type string
	---@param value_1 any
	---@param value_2 any
	---@return integer
	function Selection_FilterInclude(target_selection, source_selection, filter_type, value_1, value_2)
	end

	--- Fills `target_selection` with all values in `source_selection` which do NOT satisfy `filter_type` for `value_1`, and optionally `value_2`
	---
	--- Note: `value_2` is not optional, you should pass an empty string for nil.
	---
	---@param target_selection string
	---@param source_selection string
	---@param filter_type string
	---@param value_1 any
	---@param value_2 any
	---@return integer
	function Selection_FilterExclude(target_selection, source_selection, filter_type, value_1, value_2)
	end

	-- Subtitle stuff

	--- Displays the given `message` in the top center of the screen for `duration` seconds.
	---
	---@param message string
	---@param duration integer
	function Subtitle_Message(message, duration)
	end

	-- UI stuff

	--- Shows the named screen, with the given transition type.
	---
	---@param screen_name string
	---@param transition_type ScreenTransition
	function UI_ShowScreen(screen_name, transition_type)
	end

	--- Enables or disables the named UI element belonging to the named stylesheet.
	---
	--- Note: A 'screen' is just an entity which hosts UI elements (not necessarily a 'screen' as such).
	---
	--- The named screen should be defined in `ui/newui/` (see newmainmenu as an example).
	---
	---@param screen_name string
	---@param element_name string
	---@param enabled '0' | '1'
	function UI_SetElementEnabled(screen_name, element_name, enabled)
	end

	--- Sets the visibility of the named UI element for the named screen.
	---
	--- Note: A 'screen' is just an entity which hosts UI elements (not necessarily a 'screen' as such).
	---
	--- The named screen should be defined in `ui/newui/` (see newmainmenu as an example).
	---
	---@param screen_name string
	---@param element_name string
	---@param visible '0' | '1'
	function UI_SetElementVisible(screen_name, element_name, visible)
	end

	--- Enables or disables the given screen.
	---
	--- Note: A 'screen' is just an entity which hosts UI elements (not necessarily a 'screen' as such).
	---
	---@param screen_name string
	---@param enabled '0' | '1'
	function UI_SetScreenEnabled(screen_name, enabled)
	end

	--- Sets the visibility of the given screen.
	---
	--- Note: A 'screen' is just an entity which hosts UI elements (not necessarily a 'screen' as such).
	---
	---@param screen_name string
	---@param visible '0' | '1'
	function UI_SetScreenVisible(screen_name, visible)
	end

	--- Returns whether or not the given screen is 'active' (enabled and visible?)
	---
	---@param screen_name string
	---@return '0' | '1'
	function UI_IsScreenActive(screen_name)
	end

	--- ==== UNIVERSE STUFF ====

	--- Returns the current gametime.
	---@return number
	function Universe_GameTime()
	end
end