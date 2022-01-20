if (modkit == nil) then modkit = {}; end

if (H_SHAPES == nil) then

	local shapes = {};

	--- Returns the vertices of a regular unit icosahedron.
	---
	---@return table<integer, Vec3>
	function shapes:icosahedron()
		return { -- an icosahedron
			{
				0,
				0,
				1.175571
			},
			{
				1.051462,
				0,
				0.5257311
			},
			{
				0.3249197,
				1,
				0.5257311
			},
			{
				-0.8506508,
				0.618034,
				0.5257311
			},
			{
				-0.8506508,
				-0.618034,
				0.5257311
			},
			{
				0.3249197,
				-1,
				0.5257311
			},
			{
				0.8506508,
				0.618034,
				-0.5257311
			},
			{
				0.8506508,
				-0.618034,
				-0.5257311
			},
			{
				-0.3249197,
				1,
				-0.5257311
			},
			{
				-1.051462,
				0,
				-0.5257311
			},
			{
				-0.3249197,
				-1,
				-0.5257311
			},
			{
				0,
				0,
				-1.175571
			}
		};
	end

	modkit.shapes = shapes;

	H_SHAPES = 1;
end