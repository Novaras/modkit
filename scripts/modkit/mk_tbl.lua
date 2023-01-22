if (H_MK_TBL == nil) then
	
	if (modkit == nil) then modkit = {}; end

	local mktbl = {
		_state = {},
	};

	function mktbl:create(initial)
		initial = initial or {};
		if (type and type(initial) ~= "table") then
			initial = { initial };
		end

		self._state = initial;
	end

	function mktbl:clone()
		
	end

	H_MK_TBL = 1;
end