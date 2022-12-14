dofilepath("data:ui/newui/Styles/HWRM_Style/HWRMDefines.lua");
dofilepath("data:ui/newui/Styles/HWRM_Style/ControlConstructors.lua");

UI_LoadUILibrary("data:ui/newui/mk_consolescreencode.lua");

local makeLineBox = function (index, pt, color, name)
	pt = pt or 0;
	name = name or ("line" .. index);
	return {
		type = "TextLabel",
		name = name,
		wrapping = 0,
		Layout = {
			margin_RB = { r = 0, b = 0, rr = "px", br = "px" },
			size_WH = { w = 1, h = 20, wr = "par", hr = "px" },
			pad_LT = { l = 0, t = pt, lr = "px", pt = "px" },
		},
		Text = {
			text = "",
			textStyle = "FEHelpTipTextStyle",
			vAlign = "Top",
			color = color or { 210, 210, 210, 255 },
		},
		giveParentMouseInput = 1,
		--backgroundColor = {0,255,255,255},
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
			size_WH = {w = 0.6, h = 600, wr = "scr", hr = "px",},
			pos_XY = {	x = 0.2, y = 0.2, xr = "scr", yr = "scr", },
		},
		arrangetype = "vert",
		customData = 10,
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
					size_WH = {w = 1, h = 10, wr = "par", hr = "px",},
				},
			},
			makeLineBox(25, 0, { 50, 255, 255, 255 }, 'input_target'),
		},
	},
};
