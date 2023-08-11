if (MK_RACES == nil or (modkit ~= nil and modkit.races == nil)) then
	if (modkit == nil) then
		modkit = {};
		dofilepath("data:scripts/modkit/table_util.lua");
	end

	---@alias RacePrefix 'hgn'|'vgr'|'kus'|'tai'|'kad'|'tur'|'ben'|'kpr'|'horde'|'UNKNOWN'

	---@alias RaceName 'hiigaran'|'vaygr'|'kushan'|'taiidan'|'kadeshi'|'turanic raiders'|'bentusi'|'keeper'|'horde'|'UNKNOWN'

	---@class RaceConfig
	---@field prefix RacePrefix
	---@field name RaceName

	local races = {
		---@type RaceConfig[]
		racelist = {
			{
				prefix = "hgn",
				name = "hiigaran"
			},
			{
				prefix = "vgr",
				name = "vaygr"
			},
			{
				prefix = "kus",
				name = "kushan"
			},
			{
				prefix = "tai",
				name = "taiidan"
			},
			{
				prefix = "tur",
				name = "turanic raiders"
			},
			{
				prefix = "kad",
				name = "kadeshi"
			},
			{
				prefix = "ben",
				name = "bentusi"
			},
			{
				prefix = "kpr",
				name = "keeper"
			},
			{
				prefix = "horde",
				name = "horde"
			},
			{
				prefix = "UNKNOWN",
				name = "UNKNOWN"
			},
		}
	};

	--- Returns a table of the race prefixes.
	---
	---@return RacePrefix[]
	function races:prefixes()
		return modkit.table.map(self.racelist, function (race_config)
			return race_config.prefix;
		end);
	end

	--- Returns a table of the race names.
	---
	---@return RaceName[]
	function races:names()
		return modkit.table.map(self.racelist, function (race_config)
			return race_config.name;
		end);
	end

	---@param name_or_prefix string
	---@return RaceConfig
	function races:find(name_or_prefix)
		return modkit.table.find(self.racelist, function (race_config)
			return (
				race_config.name == %name_or_prefix or
				race_config.prefix == %name_or_prefix
			);
		end)
	end

	modkit.races = races;

	print("modkit races init");

	MK_RACES = 1;
end