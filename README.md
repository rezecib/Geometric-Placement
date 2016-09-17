# Geometric-Placement
Mod for Don't Starve and Don't Starve Together.

This should work with all versions of the game (vanilla, Reign of Giants, Shipwrecked, and Don't Starve Together). Also available on the Steam Workshop (<a href="http://steamcommunity.com/sharedfiles/filedetails/?id=356043883">single-player</a>, <a href="http://steamcommunity.com/sharedfiles/filedetails/?id=351325790">DST</a>) and the <a href="http://forums.kleientertainment.com/files/file/1108-geometric-placement/">Klei Forums</a>.

Snaps objects to a grid when placing and displays a build grid around it (unless you hold ctrl).

Credits to zkm2erjfdb and Levorto for writing the original single-player versions (Architectural Geometry and Assisted Geometry). This mod is a replacement for those mods; if you have one of them enabled as well, unpredictable things will happen.

# Installation

If you have the game on Steam, it's easiest to subscribe to the mod there. Otherwise, download this and put the folder in the game's mods folder. Then you can enable and configure it on the in-game mods menu.

# Configuration options

<table>
<tr><th>Option</th><th>Description</th>
<tr><th>CTRL Turns Mod</th><td>"On" makes it so that the mod is off by default, but turns on while holding CTRL. "Off" does the opposite, temporarily disabling the mod while holding CTRL.</td></tr>
<tr><th>Options Button</th><td>By default, "B" (for controllers, right-stick click in single-player and left-stick click from the scoreboard in DST). Brings up a menu for changing these options. Note that it cannot save these options in-game like it can on the configuration menu, so if you find new favorite settings with this, you should make those changes in the configuration menu too.</td></tr>
<tr><th>Toggle Button</th><td>By default, "V" (no binding for controllers). Toggles between the most recently used geometries (it will guess if it doesn't know, which should only happen if you just transferred between the caves and the surface or joined the game).</td></tr>
<tr><th>In-Game Menu</th><td>If set to "On" (default), the options button will bring up the menu. If set to "Off", the button will simply toggle the mod on and off (like it did before the menu was added).</td></tr>
<tr><th>Show Build Grid</th><td>Determines whether it shows the grid at all.</td></tr>
<tr><th>Grid Geometry</th><td>The shape and layout of the grid. Square is the normal one, aligned with the game's X-Z coordinate system. The hexagonal geometries allow you to do the tightest possible plots. Walls and turf always use the square geometry.</td></tr>
<tr><th>Refresh Speed</th><td>How much of the available time to use for refreshing the grid. Turning this up will make the grid update faster, but may cause lag.</td></tr>
<tr><th>Hide Placer</th><td>If set to on, the ghost-version of the thing you're about to place is hidden, and instead the point where you'll place it is marked.</td></tr>
<tr><th>Hide Cursor</th><td>If set to on, the item you're placing won't show up on the cursor while you're placing it (sometimes it gets in the way of being able to see where you'll put it).</td></tr>
<tr><th>Fine Grid Size</th><td>The number of points in each direction that it uses for things with a fine grid (most things).</td></tr>
<tr><th>Wall Grid Size</th><td>The number of points in each direction that it uses for walls.</td></tr>
<tr><th>Sandbag Grid Size</th><td>The number of points in each direction that it uses for sandbags.</td></tr>
<tr><th>Turf Grid Size</th><td>The number of points in each direction that it uses for turf/pitchfork.</td></tr>
<tr><th>Colors</th><td>Red/Green is the game's normal color scheme. Red/Blue should be more readable to players with red-green colorblindness. Black/White is there for fully colorblind players, or players who want the grid to be more readable at night. Outlined uses black and white with outlines to give the best visibility in all situations.</td></tr>
<tr><th>Tighter Chests</th><td>Allows chests to be placed more closely together. This doesn't always work in DST. I keep this only as a legacy setting because the other geometry mods override a special case the game makes for chests.</td></tr>
<tr><th>Controller Offset</th><td>Allows you to disable the usual offset that rotates around the player when placing objects. Defaults to off.</td></tr>
<tr><th>Hide Blocked Points</th><td>Instead of showing red/black points where you can't place things, this can set it to hide those points instead.</td></tr>
<tr><th>Show Nearest Tile</th><td>In addition to showing each of the points, this can set it to show the outline of the nearest tile, making it easier to align placement with the turf.</td></tr>
</table>
