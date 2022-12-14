if (MK_RACES == nil) then
	if (modkit == nil) then
		dofilepath("data:scripts/modkit/table_util.lua");
	end

	---@alias RacePrefix 'hgn'|'vgr'|'kus'|'tai'|'kad'|'tur'|'ben'|'kpr'

	---@alias RaceName 'hiigaran'|'vaygr'|'kushan'|'taiidan'|'kadeshi'|'turanic radiers'|'bentusi'|'keeper'

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