-- mostly useful `Rule`s

if (not modkit or not modkit.campaign) then
	dofilepath("data:scripts/modkit/campaign.lua");
end

if (not MK_CAMPAIGN_UTIL) then

	---@class GracePeriodOptions
---@field duration? number
---@field message? string
---@field message_duration? number
---@field message_time_offset? number
---@field gametime_set? number
---@field value? any

---@param options? GracePeriodOptions
	function makeGracePeriodRule(options)
		---@type GracePeriodOptions
		options = modkit.table:merge({
			duration = 10,
			message_duration = 5,
			message_time_offset = 1,
		}, options or {});

		return rules:make(function (res, rej, state)
			---@class GPRuleState : { gametime_set?: 1, message_shown?: 1 }, RuleState
			---@cast state GPRuleState

			if (not state._value) then
				state._value = %options.value;
			end

			if (%options.gametime_set and not state.gametime_set) then
				UI_TimerReset("NewTaskbar", "GameTimer");
				UI_SetTimerOffset("NewTaskbar", "GameTimer", %options.gametime_set);
				state.gametime_set = 1;
			end

			if (%options.message and not state.message_shown and Universe_GameTime() - state._started_gametime >= %options.message_time_offset) then
				Subtitle_Message(%options.message, %options.message_duration);
				state.message_shown = 1;
			end

			if (Universe_GameTime() >= state._started_gametime + %options.duration) then
				print("EXIT GRACE PERIOD");
				return res(state._value);
			end
		end, { interval = 2 });
	end

	MK_CAMPAIGN_UTIL = 1;
end
