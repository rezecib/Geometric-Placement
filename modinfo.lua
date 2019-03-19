name = "Geometric Placement"
description = "Snaps objects to a grid when placing and displays a build grid around it (unless you hold ctrl)."
author = "rezecib"
version = "2.4.8"

forumthread = "/files/file/1108-geometric-placement/"

api_version = 6
api_version_dst = 10

priority = -10

-- Compatible with the base game, RoG, SW, and DST
dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
dst_compatible = true

icon_atlas = "geometricplacement.xml"
icon = "geometricplacement.tex"

--These let clients know if they need to get the mod from the Steam Workshop to join the game
all_clients_require_mod = false

--This determines whether it causes a server to be marked as modded (and shows in the mod list)
client_only_mod = true

--This lets people search for servers with this mod by these tags
server_filter_tags = {}

local smallgridsizeoptions = {}
for i=0,10 do smallgridsizeoptions[i+1] = {description=""..(i*2).."", data=i*2} end
local medgridsizeoptions = {}
for i=0,10 do medgridsizeoptions[i+1] = {description=""..(i).."", data=i} end
local floodgridsizeoptions = {}
for i=0,10 do floodgridsizeoptions[i+1] = {description=""..(i).."", data=i} end
local biggridsizeoptions = {}
for i=0,5 do biggridsizeoptions[i+1] = {description=""..(i).."", data=i} end

local KEY_A = 65
local keyslist = {}
local string = "" -- can't believe I have to do this... -____-
for i = 1, 26 do
	local ch = string.char(KEY_A + i - 1)
	keyslist[i] = {description = ch, data = ch}
end

local percent_options = {}
for i = 1, 10 do
	percent_options[i] = {description = i.."0%", data = i/10}
end
percent_options[11] = {description = "Unlimited", data = false}

local placer_color_options = {
	{description = "Green", data = "green", hover = "The normal green  the game uses."},
	{description = "Blue", data = "blue", hover = "Blue, helpful if you're red/green colorblind."},
	{description = "Red", data = "red", hover = "The normal red the game uses."},
	{description = "White", data = "white", hover = "A bright white, for better visibility."},
	{description = "Black", data = "black", hover = "Black, to contrast with the brighter colors."},
}
local color_options = {}
for i = 1, #placer_color_options do
	color_options[i] = placer_color_options[i]
end
color_options[#color_options+1] = {description = "Outlined White", data = "whiteoutline", hover = "White with a black outline, for the best visibility."}
color_options[#color_options+1] = {description = "Outlined Black", data = "blackoutline", hover = "Black with a white outline, for the best visibility."}
local hidden_option = {description = "Hidden", data = "hidden", hover = "Hide it entirely, because you didn't need to see it anyway, right?"}
placer_color_options[#placer_color_options+1] = hidden_option
color_options[#color_options+1] = hidden_option

configuration_options =
{
	{
		name = "CTRL",
		label = "CTRL Turns Mod",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = false,
		hover = "Whether holding CTRL enables or disables the mod.",
	},
    {
        name = "KEYBOARDTOGGLEKEY",
        label = "Options Button",
        options = keyslist,
        default = "B",
		-- hover = "A key to open the mod's options. On controllers, open\nthe scoreboard and then use Menu Misc 3 (left stick click).\nI recommend setting this with the Settings menu in DST.",
		hover = "A key to open the mod's options. On controllers, open\nthe scoreboard and then use Menu Misc 3 (left stick click).",
    },    
    {
        name = "GEOMETRYTOGGLEKEY",
        label = "Toggle Button",
        options = keyslist,
        default = "V",
		-- hover = "A key to toggle to the most recently used geometry\n(for example, switching between Square and X-Hexagon)\nI recommend setting this with the Settings menu in DST.",
		hover = "A key to toggle to the most recently used geometry\n(for example, switching between Square and X-Hexagon)",
    },    
    {
        name = "SHOWMENU",
        label = "In-Game Menu",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
        default = true,
		hover = "If on, the button opens the menu.\nIf off, it just toggles the mod on and off.",
    },    
	{
		name = "BUILDGRID",
		label = "Show Build Grid",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = true,	
		hover = "Whether to show the build grid.",
	},
	{
		name = "GEOMETRY",
		label = "Grid Geometry",
		options =	{
						{description = "Square", data = "SQUARE"},
						{description = "Diamond", data = "DIAMOND"},
						{description = "X Hexagon", data = "X_HEXAGON"},
						{description = "Z Hexagon", data = "Z_HEXAGON"},
						{description = "Flat Hexagon", data = "FLAT_HEXAGON"},
						{description = "Pointy Hexagon", data = "POINTY_HEXAGON"},
					},
		default = "SQUARE",	
		hover = "What build grid geometry to use.",
	},
	{
		name = "TIMEBUDGET",
		label = "Refresh Speed",
		options = percent_options,
		default = 0.1,	
		hover = "How much of the available time to use for refreshing the grid.\nDisabling or setting too high will likely cause lag.",
	},
	{
		name = "HIDEPLACER",
		label = "Hide Placer",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = false,	
		hover = "Whether to hide the placer (the ghost version of the item you're placing).\nHiding it can help you see the grid better.",
	},
	{
		name = "HIDECURSOR",
		label = "Hide Cursor Item",
		options =	{
						{description = "Hide All", data = 1},
						{description = "Show Number", data = true},
						{description = "Show All", data = false},
					},
		default = false,	
		hover = "Whether to hide the cursor item, to better see the grid.",
	},
	{
		name = "SMALLGRIDSIZE",
		label = "Fine Grid Size",
		options = smallgridsizeoptions,
		default = 10,	
		hover = "How big to make the grid for things that use a fine grid (structures, plants, etc).",
	},
	{
		name = "MEDGRIDSIZE",
		label = "Wall Grid Size",
		options = medgridsizeoptions,
		default = 6,	
		hover = "How big to make the grid for walls.",
	},
	{
		name = "FLOODGRIDSIZE",
		label = "Sandbag Grid Size",
		options = floodgridsizeoptions,
		default = 5,	
		hover = "How big to make the grid for sandbags.",
	},
	{
		name = "BIGGRIDSIZE",
		label = "Turf Grid Size",
		options = biggridsizeoptions,
		default = 2,	
		hover = "How big to make the grid for turf/pitchfork.",
	},
	{
		name = "GOODCOLOR",
		label = "Unblocked Color",
		options = color_options,
		default = "whiteoutline",	
		hover = "The color to use for unblocked points, where you can place things.",
	},
	{
		name = "BADCOLOR",
		label = "Blocked Color",
		options = color_options,
		default = "blackoutline",	
		hover = "The color to use for blocked points, where you cannot place things.",
	},
	{
		name = "NEARTILECOLOR",
		label = "Nearest Tile Color",
		options = color_options,
		default = "white",	
		hover = "The color to use for the nearest tile outline.",
	},
	{
		name = "GOODTILECOLOR",
		label = "Unblocked Tile Color",
		options = color_options,
		default = "whiteoutline",	
		hover = "The color to use for the turf tile grid, where you can place turf.",
	},
	{
		name = "BADTILECOLOR",
		label = "Blocked Tile Color",
		options = color_options,
		default = "blackoutline",	
		hover = "The color to use for the turf tile grid, where you can't place turf.",
	},
	{
		name = "GOODPLACERCOLOR",
		label = "Unblocked Placer Color",
		options = placer_color_options,
		default = "white",	
		hover = "The color to use for an unblocked placer\n(the \"shadow copy\" of the thing you're placing).",
	},
	{
		name = "BADPLACERCOLOR",
		label = "Blocked Placer Color",
		options = placer_color_options,
		default = "black",	
		hover = "The color to use for a blocked placer\n(the \"shadow copy\" of the thing you're placing).",
	},
	{
		name = "REDUCECHESTSPACING",
		label = "Tighter Chests",
		options =	{
						{description = "Yes", data = true},
						{description = "No", data = false},
					},
		default = true,	
		hover = "Whether to allow chests to be placed closer together than normal.\nThis may not work in DST.",
	},
	{
		name = "CONTROLLEROFFSET",
		label = "Controller Offset",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = false,	
		hover = "With a controller, whether objects get placed\nright at your feet (\"off\") or at an offset (\"on\").",
	},
}