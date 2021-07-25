-- Custom definitions file to allow sumneko.lua to provide completion/hover/etc. for HWRM globals.

-- We can 'redefine' globals by first cloning the global table, then redefining actual globals as annotated wrappers around their originals.

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
---@param player_index any
---@param group_name any
---@param target_selection any
---@param attack any
function SobGroup_AttackSelection(player_index, group_name, target_selection, attack)
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

--- Selection stuff (NEEDS TESTING, USED ONLY BY DEFENSE FIGHTER CUSTOM CODE):

--- Creates a new selection `selection_name`.
---@param selection_name string
function SobGroup_CreateSelection(selection_name)
end

--- Spawn stuff

--- Spawns a `ship_type` squadron named `new_squad_name`, and adds it to `target_group`. The squad is spawned at `volume_name`.
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