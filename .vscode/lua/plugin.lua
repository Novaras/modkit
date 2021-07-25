function OnSetText(_, text)
	local diffs = {};

	for s, e in text:gmatch('()%%()') do
		diffs[#diffs + 1] = {
			start = s,
			finish = e - 1,
			text = ''
		};
	end

	return diffs;
end