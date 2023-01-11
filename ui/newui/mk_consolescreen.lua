dofilepath("data:ui/newui/Styles/HWRM_Style/HWRMDefines.lua");
dofilepath("data:ui/newui/Styles/HWRM_Style/ControlConstructors.lua");

dofilepath("data:scripts/modkit/table_util.lua");

UI_LoadUILibrary("data:ui/newui/mk_consolescreencode.lua");

local makeLineBox = function (index, pt, color, name, pos, offset)
	pt = pt or 0;
	name = name or ("line" .. index);
	return {
		type = "TextLabel",
		name = name,
		wrapping = 0,
		Layout = {
			margin_RB = { r = 0, b = 0, rr = "px", br = "px" },
			size_WH = { w = 1, h = 22, wr = "par", hr = "px" },
			pad_LT = { l = 0, t = pt, lr = "px", pt = "px" },
			pos = pos,
		},
		Text = {
			text = "",
			textStyle = "FEHelpTipTextStyle",
			vAlign = "Top",
			color = color or { 210, 210, 210, 255 },
			offset = offset or { 0, 0 }
		},
		giveParentMouseInput = 1,
		-- backgroundColor = {0,255,255,255},
	};
end

MK_ConsoleScreen = {
	stylesheet = "HW2StyleSheet",
	pixelUVCoords = 1, 

	Layout = {	
		size_WH = {w = 1, h = 1, wr = "scr", hr = "scr",},
	},

	RootElementSettings = {
		giveParentMouseInput = 1,
		eventOpaque = 0,
	},

	onShow = "onShow()",
	onHide = "onHide()"
	;

	{
		type = "RmWindow",
		WindowTemplate = PANEL_WINDOWSTYLE,
		giveParentMouseInput = 1,
		AllowDrag = 1,
		HasCloseButton = 1,
		TitleText =	"Modkit Console",
		name = "mk_consolescreen_root",
		Layout = {
			size_WH = { w = 0.6, h = 650, wr = "scr", hr = "px", },
			pos_XY = {	x = 0.2, y = 0.15, xr = "scr", yr = "scr", },
		},
		arrangetype = "vert",
		customDataString = "",
		;

		{
			type = "Frame",
			BackgroundGraphic = {
				texture = "DATA:\\UI\\NewUI\\Default.tga",
				textureUV = {0,0,256,256},
				color = OUTLINECOLOR,
			},
			Layout = {
				size_WH = {w = 1, h = 1, wr = "par", hr = "par",},
				pad_LT = { l = 12, t = 12, lr = "px", tr = "px" }
			},
			arrangetype = "vert",
			;
			makeLineBox(1),
			makeLineBox(2),
			makeLineBox(3),
			makeLineBox(4),
			makeLineBox(5),
			makeLineBox(6),
			makeLineBox(7),
			makeLineBox(8),
			makeLineBox(9),
			makeLineBox(10),
			makeLineBox(11),
			makeLineBox(12),
			makeLineBox(13),
			makeLineBox(14),
			makeLineBox(15),
			makeLineBox(16),
			makeLineBox(17),
			makeLineBox(18),
			makeLineBox(19),
			makeLineBox(20),
			makeLineBox(21),
			makeLineBox(22),
			makeLineBox(23),
			makeLineBox(24, 0, { 255, 255, 255, 255 }),
			{ -- seperator
				type = "Frame",
				Layout = {
					size_WH = {w = 1, h = 18, wr = "par", hr = "px",},
				},
				-- backgroundColor = {0,255,255,255},
			},
			makeLineBox(25, 0, { 50, 255, 255, 255 }, 'input_target', {	x = 0, y = 1, xr = "par", yr = "par", }),
			{ -- need a horizontal frame for the growing cursor offset / cursor
				type = "Frame",
				Layout = {
					size_WH = { w = 1, h = 21, wr = 'par', hr = 'px', },
				},
				arrangetype = 'horiz',
				;
				{
					type = "TextLabel",
					name = 'cursor_offset',
					wrapping = 0,
					autosize = 1,
					Layout = {
						margin_RB = { r = 0, b = 0, rr = "px", br = "px" },
						size_WH = { w = 100, h = 20, wr = "px", hr = "px" },
						pad_LT = { l = 0, t = 0, lr = "px", pt = "px" },
						pos = {	x = 0, y = 1, xr = "par", yr = "par", },
					},
					Text = {
						text = "",
						textStyle = "FEHelpTipTextStyle",
						vAlign = "Top",
						color = { 0, 255, 0, 0 },
						offset = { -6, -15 }
					},
					giveParentMouseInput = 1,
					--backgroundColor = {0,255,255,255},
				},
				{
					type = "TextLabel",
					name = 'cursor',
					wrapping = 0,
					Layout = {
						margin_RB = { r = 0, b = 0, rr = "px", br = "px" },
						size_WH = { w = 24, h = 20, wr = "px", hr = "px" },
						pad_LT = { l = 0, t = 0, lr = "px", pt = "px" },
						pos = {	x = 0, y = 1, xr = "par", yr = "par", },
					},
					Text = {
						text = "<b>_</b><c=000000>0</c>",
						textStyle = "FEHelpTipTextStyle",
						vAlign = "Top",
						color = { 255, 0, 0, 255 },
						offset = { -6, -15 }
					},
					giveParentMouseInput = 1,
					--backgroundColor = {0,255,255,255},
				}
			}
		},
	},
};
