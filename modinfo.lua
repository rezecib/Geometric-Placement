name = "Geometric Placement"
description = "Snaps objects to a grid when placing and displays a build grid around it (unless you hold ctrl)."
author = "rezecib"
version = "2.2.4"

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
		name = "COLORS",
		label = "Grid Colors",
		options =	{
						{description = "Red/Green", data = "redgreen", hover = "The standard red and green that the normal game uses."},
						{description = "Red/Blue", data = "redblue", hover = "Substitutes blue in place of the green,\nhelpful for the red/green colorblind."},
						{description = "Black/White", data = "blackwhite", hover = "Black for blocked and white for placeable,\nusually more visible."},
						{description = "Outlined", data = "blackwhiteoutline", hover = "Black and white, but with outlines for improved visibility."},
					},
		default = "blackwhiteoutline",	
		hover = "Alternate color schemes for the grid and placer, for improved visibility.",
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
	{
		name = "HIDEBLOCKED",
		label = "Hide Blocked Points",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = false,	
		hover = "Instead of showing red/black points for blocked locations, simply hides the points instead.",
	},
	{
		name = "SHOWTILE",
		label = "Show Nearest Tile",
		options =	{
						{description = "On", data = true},
						{description = "Off", data = false},
					},
		default = false,	
		hover = "When placing anything, shows the outline of the nearest tile.",
	},
}