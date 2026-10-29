-- mostly useful events for campaigns

if (not modkit or not modkit.events) then
	dofilepath("data:scripts/modkit/events.lua");
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

		return modkit.events:make({
			fn = function (res, rej, state)
				---@class GPEventState : { gametime_set?: 1, message_shown?: 1 }, EventState
				---@cast state GPEventState

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
					return res(state._previous_result);
				end
			end,
			interval = 2,
		});
	end

	---@class DisplayMessageOptions
	---@field message? string Subtitle shown for `duration` seconds; without one, the event is just a pause (i.e between chained events)
	---@field duration? number Seconds before the event resolves; default 5
	---@field value? any Resolve value; by default, the previous event's result is passed through

	--- Returns a new `Event`, which shows `options.message` as a subtitle and resolves once `options.duration` seconds have passed.
	---
	--- ```lua
	--- displayMessage({ message = "Wave incoming!", duration = 3 })()
	--- 	:next(spawn_wave);
	--- ```
	---
	---@param options? DisplayMessageOptions
	---@return Event
	function displayMessage(options)
		options = modkit.table:merge({
			duration = 5,
		}, options or {});

		return modkit.events:make({
			fn = function (res, rej, state)
				---@class DisplayMessageEventState : { message_shown?: 1 }, EventState
				---@cast state DisplayMessageEventState

				if (%options.message and not state.message_shown) then
					Subtitle_Message(%options.message, %options.duration);
					state.message_shown = 1;
				end

				if (Universe_GameTime() >= state._started_gametime + %options.duration) then
					if (%options.value ~= nil) then
						return res(%options.value);
					end
					return res(state._previous_result);
				end
			end,
			interval = 0.25,
		});
	end

	MK_CAMPAIGN_UTIL = 1;
end
