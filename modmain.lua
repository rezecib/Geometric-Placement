PrefabFiles = {
	"actiongridplacer",
	"buildgridplacer",
}
Assets = {
	Asset("ANIM", "anim/geo_gridplacer.zip"),
	Asset("ANIM", "anim/buildgridplacer.zip"),
}
images_and_atlases = {
	"toggle_x_out",
	"grid_toggle_icon",
	"cursor_toggle_icon",
	"cursor_toggle_icon_num",
	"placer_toggle_icon",
	"smart_spacing_toggle_icon",
	"till_grid_toggle_icon",
}
for _,geometry in pairs({"diamond", "square", "flat_hexagon", "pointy_hexagon", "x_hexagon", "z_hexagon"}) do
	table.insert(images_and_atlases, geometry .. "_geometry")
end
for _,assetname in pairs(images_and_atlases) do
	table.insert(Assets, Asset("IMAGE", "images/" .. assetname .. ".tex"))
	table.insert(Assets, Asset("ATLAS", "images/" .. assetname .. ".xml"))
end

local DST = GLOBAL.TheSim:GetGameID() == "DST"

--If this somehow gets enabled on the dedicated server, it can still refer to ThePlayer
-- and screw up snapping by snapping to a different geometry
if DST and GLOBAL.TheNet:IsDedicated() then return end

local GetPlayer = DST and function() return GLOBAL.ThePlayer end or GLOBAL.GetPlayer

local KEY_CTRL = GLOBAL.KEY_CTRL
local Vector3 = GLOBAL.Vector3
local TheInput = GLOBAL.TheInput
local TheCamera = nil--GLOBAL.TheCamera --need to populate this later in the placer constructor
local require = GLOBAL.require
local unpack = GLOBAL.unpack
local os = GLOBAL.os
local string = GLOBAL.string
local rawget = GLOBAL.rawget
local kleifileexists = GLOBAL.kleifileexists
local SpawnPrefab = GLOBAL.SpawnPrefab
local GeometricOptionsScreen = DST and require("screens/geometricoptionsscreen")
									or require("screens/geometricoptionsscreen_singleplayer")

local CHECK_MODS = {
	["workshop-2302837868"] = "TILL",
}
local HAS_MOD = {}
--If the mod is a]ready loaded at this point
for mod_name, key in pairs(CHECK_MODS) do
	HAS_MOD[key] = HAS_MOD[key] or (GLOBAL.KnownModIndex:IsModEnabled(mod_name) and mod_name)
end
--If the mod hasn't loaded yet
for k,v in pairs(GLOBAL.KnownModIndex:GetModsToLoad()) do
	local mod_type = CHECK_MODS[v]
	if mod_type then
		HAS_MOD[mod_type] = v
	end
end


local function PrintCorruptedConfig(configname, badvalue)
	print("WARNING: mod config value \"" .. configname .. "\" for mod \"" .. modname
			.. "\" is corrupted; it had unexpected value:", badvalue)
end
										
local function GetConfig(configname, default, validator)
	if type(validator) == "string" then
		local validator_type = validator
		validator = function(value) return type(value) == validator_type end
	end
	local value = GetModConfigData(configname)
	if not validator(value) then
		PrintCorruptedConfig(configname, value)
		return default
	end
	return value
end

local function GetKeyConfig(configname, default)
	local value = GetModConfigData(configname)
	if type(value) == "string" then
		if value:len() == 0 then
			return -1
		end
		return value:lower():byte()
	end
	if type(value) ~= "number" then
		PrintCorruptedConfig(configname, value)
		return default:lower():byte()
	end
	return value
end

local CTRL = GetConfig("CTRL", false, "boolean")
local KEYBOARDTOGGLEKEY = GetKeyConfig("KEYBOARDTOGGLEKEY", "B")
local GEOMETRYTOGGLEKEY = GetKeyConfig("GEOMETRYTOGGLEKEY", "V")
local SNAPGRIDKEY = GetKeyConfig("SNAPGRIDKEY", "")
local SHOWMENU = GetConfig("SHOWMENU", true, "boolean")
local BUILDGRID = GetConfig("BUILDGRID", true, "boolean")
local HIDEPLACER = GetConfig("HIDEPLACER", false, "boolean")
local CONTROLLEROFFSET = GetConfig("CONTROLLEROFFSET", false, "boolean")
local SMARTSPACING = GetConfig("SMARTSPACING", true, "boolean")

local TIMEBUDGET = GetConfig("TIMEBUDGET", 0.1, function(value)
	return value == false or (
			type(value) == "number" and value > 0 and value <= 1
		)
end)
local timebudget_percent = TIMEBUDGET
local function SetTimeBudget(percent)
	timebudget_percent = percent
	if percent then
		TIMEBUDGET = percent * GLOBAL.FRAMES --convert from percentage of frame to seconds
	else
		TIMEBUDGET = false
	end
end
SetTimeBudget(TIMEBUDGET)

-- Tiles, walls, and flood tiles don't fall exactly as the lattice would predict
local ORIGIN_OFFSETS = {
	default = 0,
	wall = 0.5,
	-- These two might depend on map size, so they get acquired in PlacerPostInit
	flood = -1,
	tile = -2,
}
for grid_type,offset in pairs(ORIGIN_OFFSETS) do
	ORIGIN_OFFSETS[grid_type] = Vector3(offset, 0, offset)
end

local H = 1
local L = 1/8
local COLOR_OPTIONS = {
	green = Vector3(L, H, L),
	blue  = Vector3(L, L, H),
	red   = Vector3(H, L, L),
	white = Vector3(H, H, H),
	black = Vector3(0, 0, 0),
}
local COLOR_OPTION_LOOKUP = {}
for color_name, color_vector in pairs(COLOR_OPTIONS) do
	COLOR_OPTION_LOOKUP[color_vector] = color_name
end
local OUTLINED_OPTIONS = {
	whiteoutline = "on",
	blackoutline = "off",
}
for color_name, color_anim in pairs(OUTLINED_OPTIONS) do
	COLOR_OPTION_LOOKUP[color_anim] = color_name
end
local function check_color_fn(value)
	return COLOR_OPTIONS[value] ~= nil or OUTLINED_OPTIONS[value] ~= nil or value == "hidden"
end
local function check_placer_color_fn(value)
	return COLOR_OPTIONS[value] ~= nil or value == "hidden"
end
local COLORS = {
	GOOD       = GetConfig("GOODCOLOR",       "whiteoutline", check_color_fn),
	BAD        = GetConfig("BADCOLOR",        "blackoutline", check_color_fn),
	NEARTILE   = GetConfig("NEARTILECOLOR",   "white",        check_color_fn),
	GOODTILE   = GetConfig("GOODTILECOLOR",   "whiteoutline", check_color_fn),
	BADTILE    = GetConfig("BADTILECOLOR",    "whiteoutline", check_color_fn),
	-- We can't outline placers (or maybe science just hasn't caught up yet?)
	GOODPLACER = GetConfig("GOODPLACERCOLOR", "white", check_placer_color_fn),
	BADPLACER  = GetConfig("BADPLACERCOLOR",  "black", check_placer_color_fn),
}
local function ResolveColor(colortype, colorname)
	-- Placers can't be outlined, so downgrade this to the un-outlined version
	if colortype:match("PLACER$") and colorname:match("outline$") then
		colorname = colorname:sub(1, colorname:len() - string.len("outline"))
	end
	return colorname
end
local function SetColor(colortype, colorname)
	GRID_DIRTY = true
	colorname = ResolveColor(colortype, colorname)
	COLORS[colortype] = COLOR_OPTIONS[colorname] or OUTLINED_OPTIONS[colorname] or colorname
end
for colortype,colorname in pairs(COLORS) do
	SetColor(colortype, colorname)
end

local HIDECURSOR = GetConfig("HIDECURSOR", false, function(val) return type(val) == "boolean" or val == 1 end)
local HIDECURSORQUANTITY = HIDECURSOR == 1
local HIDECURSOR = HIDECURSOR ~= false
local REDUCECHESTSPACING = GetConfig("REDUCECHESTSPACING", true, "boolean")

local ModSettings = nil
if DST then
	ModSettings = require("tools/modsettings")
end

--[[ Coordinate Systems ]]--
-- The idea of the geometries is that there's an abstract "lattice space", which is a normal grid.
-- Other geometries are projections of this lattice space (defined by the row and col offsets),
-- with GetRowRange and GetColRangeForRow defining the start and end of each row in the lattice space.
local sqrt2_over_2 = math.sqrt(2)*0.5
local sqrt3_over_2 = math.sqrt(3)*0.5
local GEOMETRIES = {
	SQUARE = {
		GetRowRange = function(grid_size)
			return -grid_size, grid_size
		end,
		GetColRangeForRow = function(row, grid_size)
			return -grid_size, grid_size
		end,
		HasOverlap = function(dx, dz, grid_size)
			return not(math.abs(dx) > grid_size*2 or math.abs(dz) > grid_size*2)
		end,
		col_offset = Vector3(1, 0, 0),
		row_offset = Vector3(0, 0, 1),
		gridplacer_rotation = 0,
	},
	X_HEXAGON = {
		GetRowRange = function(grid_size)
			return -grid_size, grid_size
		end,
		GetColRangeForRow = function(row, grid_size)
			return -grid_size + (row > 0 and row or 0), grid_size + (row < 0 and row or 0)
		end,
		HasOverlap = function(dx, dz, grid_size)
			-- for hexagonal coordinates, we also need to worry about the corners that get chopped off
			-- we can handle that with a third dimension defined by y = x - z
			-- (this constraint matches the particular projection from square to hex space we used)
			return not(math.abs(dx) > grid_size*2 or math.abs(dz) > grid_size*2 or math.abs(dx-dz) > grid_size*2)
		end,
		col_offset = Vector3(1, 0, 0),
		row_offset = Vector3(-0.5, 0, sqrt3_over_2),
		gridplacer_rotation = 0,
	},
}
--[[ These rotations are calculated with a rotation matrix.
col_offset = <a, 0, c>, row_offset = <b, 0, d>, we can arrange this in a matrix like so:
(where bgx,bgz are coordinates in the lattice space and x,z are coordinates in the world space)
[ a b ] [ bgx ] = [ x ]
[ c d ] [ bgz ]   [ z ]

If we want to rotate the world space coordinates, we can simply left-multiply the first matrix by this:
[ cos(th) -sin(th) ] [ a b ] = [ a*cos(th) - c*sin(th), b*cos(th) - d*sin(th) ]
[ sin(th)  cos(th) ] [ c d ]   [ a*sin(th) + c*cos(th), b*sin(th) - d*cos(th) ]
]]
local rotations = {
	DIAMOND = { base = "SQUARE", angle = 45 },
	Z_HEXAGON = { base = "X_HEXAGON", angle = 90 },
	POINTY_HEXAGON = { base = "X_HEXAGON", angle = 45 },
	FLAT_HEXAGON = { base = "X_HEXAGON", angle = 135 },
}
for rotation_name,rotation in pairs(rotations) do
	local base = GEOMETRIES[rotation.base]
	local th = (rotation.angle/180)*math.pi
	GEOMETRIES[rotation_name] = {
		GetRowRange = base.GetRowRange,
		GetColRangeForRow = base.GetColRangeForRow,
		HasOverlap = base.HasOverlap,
		col_offset = Vector3(base.col_offset.x*math.cos(th) - base.col_offset.z*math.sin(th),
							 0,
							 base.col_offset.x*math.sin(th) + base.col_offset.z*math.cos(th)),
		row_offset = Vector3(base.row_offset.x*math.cos(th) - base.row_offset.z*math.sin(th),
							 0,
							 base.row_offset.x*math.sin(th) + base.row_offset.z*math.cos(th)),
		gridplacer_rotation = rotation.angle%90
	}
end

-- Stores the current and previous geometry
local SAVED_GEOMETRY_NAME = GetConfig("GEOMETRY", "SQUARE", function(value)
	return type(value) == "string" and GEOMETRIES[value:upper()] ~= nil
end):upper()
local inferred_last_geometries = {
	SQUARE = "X_HEXAGON",
	DIAMOND = "FLAT_HEXAGON",
	X_HEXAGON = "SQUARE",
	Z_HEXAGON = "SQUARE",
	FLAT_HEXAGON = "DIAMOND",
	POINTY_HEXAGON = "DIAMOND",
}
local SAVED_LAST_GEOMETRY_NAME = inferred_last_geometries[SAVED_GEOMETRY_NAME]
-- Local variables for the currently-active geometry for speedy lookup
local GEOMETRY_DIRTY = false
local GEOMETRY_NAME
local SPACING
local GRID_TYPE
local GRID_ACTION
local GRID_SIZE
local ROW_OFFSET
local COL_OFFSET
local ORIGIN_OFFSET
local ToLatticeCoords
local Snap

local SPACING_BY_TYPE = {
	wall = 1,
	flood = 2,
	tile = 4,
}

local GRID_DIRTY = false
local GRID_SIZES = {
	SMALL = GetConfig("SMALLGRIDSIZE", 10, "number"),
	MED = GetConfig("MEDGRIDSIZE", 6, "number"),
	BIG = GetConfig("BIGGRIDSIZE", 2, "number"),
}
local function ChooseGridSize(spacing)
	if spacing < 1 then
		return GRID_SIZES.SMALL
	elseif spacing < 4 then
		return GRID_SIZES.MED
	else
		return GRID_SIZES.BIG
	end
end
local function SetGridSize(grid_type, new_size)
	GRID_DIRTY = true
	GRID_SIZES[grid_type] = new_size or GRID_SIZES[grid_type]
	GRID_SIZE = ChooseGridSize(SPACING)
end

--[[
Floating point rounding error means that the weird grids don't behave as expected,
(e.g. blocking some points they shouldn't), so we expand them just a little to accommodate error.
To figure out how much inflation we need, we need a careful analysis of the floating point precision.
Don't Starve's Lua uses 64-bit floats, so precision is not an issue there. However, somewhere in the C,
32-bit floats get used, such that SetPosition() and GetPosition() have 32-bit accuracy.
32-bit floats have a precision of 2^(E-23), where E depends on the size of the number, X:
2^E <= |X| < 2^(E+1); we have coordinates that go up to 800, so that gives us an E of 9
and a precision of about 6.1e-5, which we'll call err. This error may compound in the C++ code,
so for a factor of safety we'll assume the error is actually 2*err, or 1.22e-4, and set
our grid inflation factor to 1.5e-4 so that it's above that.
]]
local EPSILON = 1.5e-4
-- Generate offsets and lattice conversion functions
local function SetGeometry(name, spacing, grid_type)
	name = name or "SQUARE"
	spacing = spacing or 0.5
	grid_type = grid_type or "default"
	if grid_type ~= "default" then
		name = "SQUARE"
		spacing = SPACING_BY_TYPE[grid_type] or spacing
	end
	-- Don't recompute if the last run had the same parameters
	if not GEOMETRY_DIRTY and GEOMETRY_NAME == name and SPACING == spacing and GRID_TYPE == grid_type then
		return
	else
		GEOMETRY_DIRTY = false
		GRID_DIRTY = true
		GEOMETRY_NAME = name
		SPACING = spacing
		GRID_TYPE = grid_type
	end
	GRID_SIZE = ChooseGridSize(SPACING)
	ORIGIN_OFFSET = ORIGIN_OFFSETS[grid_type]
	local grid_inflation = GEOMETRY_NAME == "SQUARE" and 1 or (1 + (GRID_ACTION == "TILL" and 0 or EPSILON))
	local geometry = GEOMETRIES[GEOMETRY_NAME]
	ROW_OFFSET = geometry.row_offset*SPACING*grid_inflation
	COL_OFFSET = geometry.col_offset*SPACING*grid_inflation
	--[[
	ToLatticeCoords gets generated by row_offset and col_offset; by calculating the matrix inversion
	 (col_offset*bgx + row_offset*bgz is lattice -> world, and ToLatticeCoords is world -> lattice)

	bgx, bgz are lattice coordinates, where x, z are world coordinates
	col_offset = <a, 0, c>, row_offset = <b, 0, d>

	Lattice coordinates -> World coordinates
	[ a b ] [ bgx ] = [ x ]
	[ c d ] [ bgz ]   [ z ]
	so, for world -> lattice:
	[ bgx ] = [ a b ]^-1 [ x ]
	[ bgz ]   [ c d ]    [ z ]

	/adjugate\,  /determinant\
	[ a b ]^-1 = [  d -b ]
	[ c d ]      [ -c  a ] / (ad - bc)
	]]
	local hexagonal = GEOMETRY_NAME:find("HEXAGON")
	local row = ROW_OFFSET
	local col = COL_OFFSET
	--precompute the inverse determinants
	local inv_determinant = 1/(col.x*row.z - col.z*row.x)
	if hexagonal then
		ToLatticeCoords = function(pt)
			--Don't need to account for grid_spacing or grid_inflation; they're already in the offsets
			pt = pt - ORIGIN_OFFSET
			
			--Borrowing notation from http://www.redblobgames.com/grids/hexagons/
			local x = (row.z*pt.x - row.x*pt.z)*inv_determinant  --q
			-- local z = -(col.x*pt.z - col.z*pt.x)*inv_determinant --converted to below
			local z = (col.z*pt.x - col.x*pt.z)*inv_determinant --r
			--convert from axial to rounded cube coordinates
			local y = -x-z
			local rx, ry, rz = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5)
			local dx, dy, dz = math.abs(rx-x), math.abs(ry-y), math.abs(rz-z)
			--Snap the cube coordinates to the hex plane
			if dx > dy and dx > dz then
				rx = -ry-rz
			elseif dy > dz then
				ry = -rx-rz
			-- don't need to do this because rz isn't used directly in the backwards conversion
			-- else
				-- rz = -rx-ry
			end
			--convert from cube coordinates to our lattice coordinates
			return rx, ry+rx
		end
	else
		ToLatticeCoords = function(pt)
			--Don't need to account for grid_spacing or grid_inflation; they're already in the offsets
			pt = pt - ORIGIN_OFFSET
			return math.floor((row.z*pt.x - row.x*pt.z)*inv_determinant + .5),
				   math.floor((col.x*pt.z - col.z*pt.x)*inv_determinant + .5)
		end
	end
	Snap = function(pt)
		local bgx, bgz = ToLatticeCoords(pt, grid_type)
		return COL_OFFSET*bgx + ROW_OFFSET*bgz + ORIGIN_OFFSET
	end
end
SetGeometry(SAVED_GEOMETRY_NAME)

--[[
Adjusts the origin offset of the grid to have a point directly under the hovered object or lattice point
Lattice point here refers to the standard 0.5 spacing square grid, which has nice properties with respect to tiles;
it has a point at the center of each tile, as well as a nice spread of points along the borders (center, corner, some between).
]]
local function SnapGrid()
	local pt = TheInput:GetWorldPosition()
	local target = TheInput:GetWorldEntityUnderMouse()
	if target == nil then
		if GRID_ACTION == "TILL" then
			local ents = GLOBAL.TheSim:GetEntitiesAtScreenPoint(GLOBAL.TheSim:GetPosition())
			for _,e in pairs(ents) do
				-- Copied from componentactions.farmplantable
				if e:HasTag("soil") and not e:HasTag("NOCLICK") then
					target = e
				end
			end
		else
			-- Look for boats and snap to the center of the boat; written with reference to Map:IsPassableAtPoint
			local ents = GLOBAL.TheSim:GetEntitiesAtScreenPoint(GLOBAL.TheSim:GetPosition())
			for _,e in pairs(ents) do
				if e.components.walkwableplatform then
					target = e
				end
			end
		end
	end
	if target ~= nil then
		pt = target:GetPosition()
	else
		pt.x = math.floor(pt.x + 0.5)
		pt.y = 0
		pt.z = math.floor(pt.z + 0.5)
	end
	ORIGIN_OFFSETS.default = pt
	if GRID_TYPE == "default" then
		GRID_DIRTY = true
		GEOMETRY_DIRTY = true
	end
end

local TILL_SPACING = 4/3
-- Old TILL_SPACING code; keeping as a reference on how to get this back if it turns out 4/3 is bad
-- local TILL_SPACING = rawget(GLOBAL, "GetFarmTillSpacing") and GLOBAL.GetFarmTillSpacing()
-- if type(TILL_SPACING) ~= "number" then
	-- TILL_SPACING = 1.25
-- end
-- TILL_SPACING = TILL_SPACING + EPSILON

local ACTION_ENABLED = {}
local RMB_ACTION_GRID_SPACING = {
	TILL = TILL_SPACING,
}
local function SetGridForRmbAction(action, value)
	if rawget(GLOBAL.ACTIONS, action) then
		ACTION_ENABLED[action] = value
		GLOBAL.ACTIONS[action].tile_placer = value and (action:lower() .. "_actiongridplacer") or nil
	end
end
for action,_ in pairs(RMB_ACTION_GRID_SPACING) do
	SetGridForRmbAction(action, not HAS_MOD[action] and GetConfig("ACTION_"..action, true, "boolean"))
end

--[[ Placer Component ]]--
-- Most of the modifications we can make to the Placer class directly, so it only runs once
-- if DST then require("components/deployhelper") end
Placer = require("components/placer")
function Placer:SetCursorVisibility(show)
	local ThePlayer = GetPlayer()
	if ThePlayer and ThePlayer.HUD and ThePlayer.HUD.controls
	and ThePlayer.HUD.controls.mousefollow and ThePlayer.HUD.controls.mousefollow.children then
		local cursor_object = nil
		for k,v in pairs(ThePlayer.HUD.controls.mousefollow.children) do
			if v then cursor_object = v end
		end
		if cursor_object then
			self.cursor_visible = show
			self.cursor_quantity_visible = not HIDECURSORQUANTITY
			if show then
				if cursor_object.image then cursor_object.image:Show() end
				if cursor_object.quantity then cursor_object.quantity:Show() end
				if cursor_object.percent then cursor_object.percent:Show() end
			else
				if cursor_object.image then cursor_object.image:Hide() end
				if cursor_object.quantity and HIDECURSORQUANTITY then cursor_object.quantity:Hide() end
				if cursor_object.percent then cursor_object.percent:Hide() end
			end
		end
	end
end

function Placer:MakeGridInst()	
	local gridinst = SpawnPrefab("buildgridplacer")
	gridinst.AnimState:PlayAnimation("on", true)
	gridinst.Transform:SetRotation(self.geometry.gridplacer_rotation+45)
	gridinst.Transform:SetScale(1.7,1.7,1.7)
	return gridinst
end

function Placer:TestPoint(pt)
	return (self.testfn == nil or self.testfn(pt, self._rot))
	   and (self.placeTestFn == nil or self.placeTestFn(self.inst, pt))
end

function Placer:RemoveBuildGrid()
	if self.build_grid then
		for bgx,row in pairs(self.build_grid) do
			for bgz,bgp in pairs(row) do
				bgp:Remove()
				self.build_grid[bgx][bgz] = nil
				self.build_grid_positions[bgx][bgz] = nil
			end
			self.build_grid[bgx] = nil
			self.build_grid_positions[bgx] = nil
		end
	end
	self.build_grid = nil
	self.build_grid_positions = nil
	self.refresh_queue = nil
end

function Placer:BuildGridPoint(bgx, bgz, bgpt, bgp)
	if bgp == nil then
		bgp = SpawnPrefab(self.placertype)
		bgp.Transform:SetRotation(self.geometry.gridplacer_rotation)
	end
	self.build_grid[bgx][bgz] = bgp
	self.build_grid_positions[bgx][bgz] = bgpt
	bgp.Transform:SetPosition(bgpt:Get())
	table.insert(self.refresh_queue, {bgx, bgz})
end

function Placer:RefreshBuildGrid(time_remaining) --if not time_remaining, then config was set to no limit
	if time_remaining then
		if time_remaining < 0 then return end --we were over time already (common on generation updates)
		-- we only have 1ms accuracy, so subtract off a ms
		time_remaining = time_remaining - 0.001
	end
	local refresh_start = os.clock()
	local refresh_queue_size = #self.refresh_queue
	for i = 1, refresh_queue_size do
		if time_remaining and i%20 == 0 then
			if os.clock() - refresh_start > time_remaining then
				return
			end
		end
		self:RefreshGridPoint(unpack(table.remove(self.refresh_queue)))
	end
end

function Placer:RefreshGridPoint(bgx, bgz)
	local row = self.build_grid[bgx]
	if row == nil then return end
	local bgp = row[bgz]
	if bgp == nil then return end
	local bgpt = self.build_grid_positions[bgx][bgz]
	local can_build = self:TestPoint(bgpt)
	local color = can_build and COLORS.GOOD or COLORS.BAD
	if self.snap_to_tile then
		color = can_build and COLORS.GOODTILE or COLORS.BADTILE
		bgp.AnimState:SetSortOrder(can_build and 1 or 0)
	end
	if color == "hidden" then
		bgp:Hide()
	else
		bgp:Show()
		if color == "on" or color == "off" then
			bgp.AnimState:PlayAnimation(color, true)
			bgp.AnimState:SetAddColour(0, 0, 0, 0)
		else
			bgp.AnimState:PlayAnimation("anim", true)
			bgp.AnimState:SetAddColour(color.x, color.y, color.z, 1)
		end
	end
end

function Placer:RemoveGridPoint(bgx, bgz, to_move_list)
	table.insert(to_move_list, self.build_grid[bgx][bgz])
	self.build_grid[bgx][bgz] = nil
	self.build_grid_positions[bgx][bgz] = nil
end

local OldSetBuilder = Placer.SetBuilder
function Placer:SetBuilder(...)
	local ret = OldSetBuilder(self, ...)
	if self.invobject and
	   self.invobject.components.deployable and
	   self.invobject.components.deployable.onlydeploybyplantkin and
	   self.builder and
	   not self.builder:HasTag("plantkin") then
		self.disabled = true
	end
	return ret
end

-- Placers here will run the placeTestFn for each point
-- Otherwise, placeTestFn makes it default to non-mod behavior (like holding ctrl)
local ALLOW_PLACE_TEST = {
	fish_farm_placer = true, -- adjusts animations and checks for nearby blocking structures
	sprinkler_placer = true, -- tests for nearby water, but is super inefficient, we'll replace in PostInit
	clawpalmtree_sapling_placer = true, -- tests for the correct ground; not sure this is even obtainable?
	slow_farmplot_placer = true, -- excludes interiors
	fast_farmplot_placer = true, -- excludes interiors
	
	-- These ones only really need to run on the actual placer, not the grid points
	-- but I haven't implemented separate logic for that yet (may not be worth it)
	fence_item_placer = true, -- just adjusts the orientation
	fence_gate_item_placer = true, -- just adjusts the orientation
	pighouse_city_placer = true, -- just hides some AnimState symbols
	playerhouse_city_placer = true, -- checks ground tile
	pig_guard_tower_placer = true, -- checks ground tile and hides some AnimState symbols
	
	-- tar extractor is left out so that it uses the normal placer logic
}
-- This section can be uncommented to run a validator to check for unaccounted-for placers that define placeTestFn
-- Placers defined in a file can be extracted with a script like so:
-- cat deco_placers.lua | grep -E "MakePlacer" | sed -E 's/^\s*(return)?\s*MakePlacer\(("[^"]*").*$/\2 = true,/' > deco_placers.txt
-- It would be nice to do this here in Lua but I gave up on trying to over-optimize
--[[
AddPrefabPostInit("world", function(world)
	world:DoTaskInTime(5, function()
		local disable_place_test_prefabs = {
			"tar_extractor_placer",
			
			"wood_door_placer",
			"stone_door_placer",
			"organic_door_placer",
			"iron_door_placer",
			"pillar_door_placer",
			"curtain_door_placer",
			"round_door_placer",
			"plate_door_placer",
					
			"deco_wood_cornerbeam_placer",
			"deco_millinery_cornerbeam_placer",
			"deco_round_cornerbeam_placer",
			"deco_marble_cornerbeam_placer",
			"chair_classic_placer",
			"chair_corner_placer",
			"chair_bench_placer",
			"chair_horned_placer",
			"chair_footrest_placer",
			"chair_lounge_placer",
			"chair_massager_placer",
			"chair_stuffed_placer",
			"chair_rocking_placer",
			"chair_ottoman_placer",
			"shelves_wood_placer",
			"shelves_basic_placer",
			"shelves_cinderblocks_placer",
			"shelves_marble_placer",
			"shelves_glass_placer",
			"shelves_ladder_placer",
			"shelves_hutch_placer",
			"shelves_industrial_placer",
			"shelves_adjustable_placer",
			"shelves_midcentury_placer",
			"shelves_wallmount_placer",
			"shelves_aframe_placer",
			"shelves_crates_placer",
			"shelves_fridge_placer",
			"shelves_floating_placer",
			"shelves_pipe_placer",
			"shelves_hattree_placer",
			"shelves_pallet_placer",
			"swinging_light_basic_bulb_placer",
			"swinging_light_floral_bloomer_placer",
			"swinging_light_basic_metal_placer",
			"swinging_light_chandalier_candles_placer",
			"swinging_light_rope_1_placer",
			"swinging_light_rope_2_placer",
			"swinging_light_floral_bulb_placer",
			"swinging_light_pendant_cherries_placer",
			"swinging_light_floral_scallop_placer",
			"swinging_light_floral_bloomer_placer",
			"swinging_light_tophat_placer",
			"swinging_light_derby_placer",
			"window_round_curtains_nails_placer",
			"window_round_burlap_placer",
			"window_small_peaked_curtain_placer",
			"window_small_peaked_placer",
			"window_large_square_placer",
			"window_tall_placer",
			"window_large_square_curtain_placer",
			"window_tall_curtain_placer",
			"window_greenhouse_placer",
			"deco_lamp_fringe_placer",
			"deco_lamp_stainglass_placer",
			"deco_lamp_downbridge_placer",
			"deco_lamp_2embroidered_placer",
			"deco_lamp_ceramic_placer",
			"deco_lamp_glass_placer",
			"deco_lamp_2fringes_placer",
			"deco_lamp_candelabra_placer",
			"deco_lamp_elizabethan_placer",
			"deco_lamp_gothic_placer",
			"deco_lamp_orb_placer",
			"deco_lamp_bellshade_placer",
			"deco_lamp_crystals_placer",
			"deco_lamp_upturn_placer",
			"deco_lamp_2upturns_placer",
			"deco_lamp_spool_placer",
			"deco_lamp_edison_placer",
			"deco_lamp_adjustable_placer",
			"deco_lamp_rightangles_placer",
			"deco_chaise_placer",
			"deco_lamp_hoofspa_placer",
			"deco_plantholder_marble_placer",
			"deco_table_banker_placer",
			"deco_table_round_placer",
			"deco_table_diy_placer",
			"deco_table_raw_placer",
			"deco_table_crate_placer",
			"deco_table_chess_placer",
			"rug_round_placer",
			"rug_square_placer",
			"rug_oval_placer",
			"rug_rectangle_placer",
			"rug_leather_placer",
			"rug_fur_placer",
			"rug_circle_placer",
			"rug_hedgehog_placer",
			"rug_porcupuss_placer",
			"rug_hoofprint_placer",
			"rug_octagon_placer",
			"rug_swirl_placer",
			"rug_catcoon_placer",
			"rug_rubbermat_placer",
			"rug_web_placer",
			"rug_metal_placer",
			"rug_wormhole_placer",
			"rug_braid_placer",
			"rug_beard_placer",
			"rug_nailbed_placer",
			"rug_crime_placer",
			"rug_tiles_placer",
			"deco_plantholder_basic_placer",
			"deco_plantholder_wip_placer",
			"deco_plantholder_fancy_placer",
			"deco_plantholder_bonsai_placer",
			"deco_plantholder_dishgarden_placer",
			"deco_plantholder_philodendron_placer",
			"deco_plantholder_orchid_placer",
			"deco_plantholder_draceana_placer",
			"deco_plantholder_xerographica_placer",
			"deco_plantholder_birdcage_placer",
			"deco_plantholder_palm_placer",
			"deco_plantholder_zz_placer",
			"deco_plantholder_fernstand_placer",
			"deco_plantholder_fern_placer",
			"deco_plantholder_terrarium_placer",
			"deco_plantholder_plantpet_placer",
			"deco_plantholder_traps_placer",
			"deco_plantholder_pitchers_placer",
			"deco_plantholder_winterfeasttreeofsadness_placer",
			"deco_plantholder_winterfeasttree_placer",
			"deco_antiquities_wallfish_placer",
			"deco_antiquities_beefalo_placer",
			"deco_wallornament_photo_placer",
			"deco_wallornament_fulllength_mirror_placer",
			"deco_wallornament_embroidery_hoop_placer",
			"deco_wallornament_mosaic_placer",
			"deco_wallornament_wreath_placer",
			"deco_wallornament_axe_placer",
			"deco_wallornament_hunt_placer",
			"deco_wallornament_periodic_table_placer",
			"deco_wallornament_gears_art_placer",
			"deco_wallornament_cape_placer",
			"deco_wallornament_no_smoking_placer",
			"deco_wallornament_black_cat_placer",
		}
		local disable_place_test = {}
		for _,v in pairs(disable_place_test_prefabs) do
			disable_place_test[v] = true
		end
		local had_unknown_placers = false
		for k,v in pairs(GLOBAL.Prefabs) do
			if k:find("_placer$") and not (ALLOW_PLACE_TEST[k] or disable_place_test[k]) then
				local fake_placer_inst = GLOBAL.SpawnPrefab(k)
				if fake_placer_inst.components.placer.placeTestFn then
					print("New placer with placeTestFn:", k)
					had_unknown_placers = true
				end
				fake_placer_inst:Remove()
			end
		end	
		if not had_unknown_placers then
			print("No unrecognized placers with placeTestFn, yay!")
		end
	end)
end)
-- ]]

-- We can figure out spacing for buildings from recipes and deployables that have deployspacing,
-- but some things have custom functions with the spacing buried in the logic.
local PLACER_SPACING_OVERRIDES = {
	seeds_placer = TILL_SPACING,
}

AddPrefabPostInit("world", function()
	-- This needs to be done in this post-init because the recipe loading code is not idempotent
	if REDUCECHESTSPACING then
	-- other geometry mods ignore the special case for chests that increases the spacing for them
	-- in Builder:CanBuildAtPoint; however, reducing the built-in spacing by just a little bit
	-- gives similar behavior in terms of which lattice points you can build the chest
		local treasurechestrecipe = DST
									and GLOBAL.GetValidRecipe('treasurechest')
									or  GLOBAL.GetRecipe('treasurechest')
		treasurechestrecipe.min_spacing = treasurechestrecipe.min_spacing - 0.1
	end
	
	local Prefabs = GLOBAL.Prefabs
	-- Veggie seeds for Wormwood, their test is just checking for natural turf
	for veggie,data in pairs(GLOBAL.VEGGIES) do
		local seed_placer = veggie.."_seeds_placer"
		if Prefabs[seed_placer] then
			ALLOW_PLACE_TEST[seed_placer] = true
			PLACER_SPACING_OVERRIDES[seed_placer] = TILL_SPACING
		end
	end
	-- Pig shops in Hamlet, their test just hides some AnimState symbols; could be put in placer-only logic when it exists
	for prefab, _ in pairs(Prefabs) do
		if type(prefab) == "string" and prefab:match("^pig_shop") and prefab:match("_placer$") then
			ALLOW_PLACE_TEST[prefab] = true
		end
	end
end)

local PLACERS_WITH_RADIUS = {
	firesuppressor_placer = true,
	sprinkler_placer = true,
	winona_battery_low_placer = true,
	winona_battery_high_placer = true,
	winona_catapult_placer = true,
	winona_spotlight_placer = true,
}

local GRIDPLACER_PREFABS = {
	gridplacer = true,
	tile_outline = true,
	gridplacer_farmablesoil = true,
}

local OldOnUpdate = Placer.OnUpdate
function Placer:OnUpdate(dt)
	local body_start = os.clock()
	--#rezecib Need these here to let the rest of the code match Placer:OnUpdate for easy syncing
	local TheWorld = DST and GLOBAL.TheWorld or GLOBAL.GetWorld()
	if GEOMETRY_DIRTY or self.waiting_for_geometry then
		self.waiting_for_geometry = nil
		local geometry = SAVED_GEOMETRY_NAME
		local grid_type = "default"
		local spacing = 0.5
		local prefab = self.inst.prefab
		if SMARTSPACING then
			if self.recipe then
				spacing = self.recipe.min_spacing or spacing
			end
			if self.invobject and self.invobject.replica and self.invobject.replica.inventoryitem then
				local deployspacing = self.invobject.replica.inventoryitem:DeploySpacingRadius()
				spacing = deployspacing ~= 0 and deployspacing or spacing
			end
		end
		spacing = PLACER_SPACING_OVERRIDES[prefab] or spacing
		local agp_index = prefab:find("_actiongridplacer")
		if agp_index then
			local action = prefab:sub(1, agp_index-1):upper()
			GRID_ACTION = action
			spacing = RMB_ACTION_GRID_SPACING[action] or spacing
		else
			GRID_ACTION = nil
		end
		if spacing >= 1 then
			-- Divide the optimal spacing evenly to get it in the 0.5-1 range to give more options of where to put things
			spacing = spacing/math.floor(spacing*2)
		end
		if self.snap_to_meters then
			grid_type = "wall"
			self.force_square_geometry = true
		elseif self.snap_to_flood then
			grid_type = "flood"
			self.force_square_geometry = true
		elseif self.snap_to_tile then
			grid_type = "tile"
			self.placertype = "gridplacer"
			self.force_square_geometry = true
		end
		SetGeometry(geometry, spacing, grid_type)
		self.geometry = GEOMETRIES[GEOMETRY_NAME]
		if not self.gridinst then
			self.gridinst = self:MakeGridInst()
		end
	end
	if COLORS.NEARTILE ~= "hidden" and not self.snap_to_tile then
		if self.tileinst == nil then
			self.tileinst = SpawnPrefab("gridplacer")
			self.tileinst:DoTaskInTime(0, function()
				self.tileinst.AnimState:SetSortOrder(1)
				if type(COLORS.NEARTILE) == "table" then
					self.tileinst.AnimState:SetAddColour(COLORS.NEARTILE.x, COLORS.NEARTILE.y, COLORS.NEARTILE.z, 1)
				else
					self.tileinst.AnimState:PlayAnimation(COLORS.NEARTILE)
				end
			end)
		end
	elseif self.tileinst ~= nil then
		self.tileinst:Remove()
		self.tileinst = nil
	end
	--#rezecib Restores the default game behavior by holding ctrl, or if we have a non-permitted placeTestFn
	local ctrl_disable = CTRL ~= TheInput:IsKeyDown(KEY_CTRL)
	local disabled_place_test = self.placeTestFn ~= nil and not ALLOW_PLACE_TEST[self.inst.prefab]
	if ctrl_disable or disabled_place_test or self.disabled then
		self:RemoveBuildGrid()
		if self.tileinst then self.tileinst:Hide() end
		self.gridinst:Hide()
		self.inst:Show()
		self:SetCursorVisibility(true)
		local ret = OldOnUpdate(self, dt)
		if not (ctrl_disable or self.disabled) then
			-- if we got disabled by the placeTestFn, then still use the chosen color scheme
			local color = self.can_build and COLORS.GOODPLACER or COLORS.BADPLACER
			if HIDEPLACER or color == "hidden" then
				self.inst:Hide()
				for i, v in ipairs(self.linked) do
					v:Hide()
				end
			else
				self.inst:Show()
				local mult = COLOR_OPTION_LOOKUP[color] == "black" and 0 or 255
				self.inst.AnimState:SetMultColour(mult, mult, mult, 1)
				self.inst.AnimState:SetAddColour(color.x*2, color.y*2, color.z*2, 1)
				for i, v in ipairs(self.linked) do
					v:Show()
					v.AnimState:SetMultColour(mult, mult, mult, 1)
					v.AnimState:SetAddColour(color.x*2, color.y*2, color.z*2, 1)
				end
			end
		end
		if self.inst.prefab:find("_actiongridplacer") then
			self.inst:Hide()
		end
		return ret
	end
	if GRID_DIRTY then
		--Some settings have changed that will mess up the grid unless we rebuild it
		self:RemoveBuildGrid()
		self.geometry = self.force_square_geometry and GEOMETRIES.SQUARE or GEOMETRIES[SAVED_GEOMETRY_NAME]
		if self.tileinst ~= nil then
			self.tileinst:Remove()
			self.tileinst = nil
		end
		GRID_DIRTY = false
	end
	local pt = nil --#rezecib Added to keep the pt location for the build grid
	local ThePlayer = GetPlayer()
	if ThePlayer == nil then
		return
	elseif not TheInput:ControllerAttached() then
		-- Mouse input
		pt = self.selected_pos or TheInput:GetWorldPosition() --#rezecib Removed local
		if self.snap_to_tile then
			pt = Vector3(TheWorld.Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		-- elseif self.snap_to_flood and TheWorld.Flooding then 
			-- Flooding tiles exist at odd-numbered integer coordinates
			-- local center = Vector3(TheWorld.Flooding:GetTileCenterPoint(pt:Get()))
			-- pt.x = center.x
			-- pt.y = center.y
			-- pt.z = center.z
		--#rezecib we don't need to special case flooding here because geometry has already been set above
		else --#rezecib Added this block, everything else should match Placer:OnUpdate
			pt = Snap(pt)
		end
	else -- Controller input
		local offset = CONTROLLEROFFSET and (self.offset or 1) or 0
		if self.recipe then 
			if self.recipe.distance then 
				offset = self.recipe.distance - 1
				offset = math.max(offset*0.9, 1)
			end 
		elseif self.invobject then 
			local deployable = self.invobject.components.deployable
			if deployable then
				if deployable.deploydistance then 
					--Adjusted so that you can place boats when right up against the shoreline
					offset = deployable.deploydistance*0.9
				end
				if deployable.mode and rawget(GLOBAL, "DEPLOYMODE") and deployable.mode == GLOBAL.DEPLOYMODE.WATER then
					-- Ignore CONTROLLEROFFSET setting for water-placement, because you can't walk on water,
					-- so you can't place at your feet for water-placeable things, so you need an offset
					offset = self.offset or 1
					-- Reduces offset by half of a grid spacing; this prevents snapping from putting the boat out of placement range
					offset = offset - 0.25
				end
			end
		end
		
		if self.snap_to_tile then
			--Using an offset in this causes a bug in the terraformer functionality while using a controller.
			pt = Vector3(ThePlayer.entity:LocalToWorldSpace(0,0,0)) --#rezecib Removed local
			pt = Vector3(TheWorld.Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(ThePlayer.entity:LocalToWorldSpace(offset,0,0)) --#rezecib Removed local
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		elseif self.snap_to_flood then 
		-- elseif self.snap_to_flood and TheWorld.Flooding then 
			if self.inst.parent ~= nil then
				-- If the grid gets temporarily disabled, the inst will get parented
				-- so once the grid comes back we need to remove it
				ThePlayer:RemoveChild(self.inst)
			end
			pt = Vector3(ThePlayer.entity:LocalToWorldSpace(offset,0,0))
			-- local center = Vector3(TheWorld.Flooding:GetTileCenterPoint(pt:Get()))
			-- pt.x = center.x
			-- pt.y = center.y
			-- pt.z = center.z
			--#rezecib their flooding solution for RoG is gimmicky, so I replaced it
			pt = Snap(pt)
		else
			--#rezecib We actually need to do something a little weird in this case
			-- normally the game makes the player the parent of the placer, which, as it turns out,
			-- causes the offset to rotate around the player with the controller movement
			-- we want to capture this rotating position, but still snap it to lattice points
			if self.inst.parent ~= nil then
				-- If the grid gets temporarily disabled, the inst will get parented
				-- so once the grid comes back we need to remove it
				ThePlayer:RemoveChild(self.inst)
			end
			if self.controller_child == nil then
				self.controller_child = GLOBAL.CreateEntity()
				self.controller_child:AddTag("FX")
				self.controller_child:AddTag("NOCLICK")
				self.controller_child.persists = false
				self.controller_child.entity:AddTransform()
				ThePlayer:AddChild(self.controller_child)
				self.controller_child.Transform:SetPosition(offset,0,0)
			end

			pt = Snap(self.controller_child:GetPosition())
		end
	end

	-- self.inst.Transform:SetPosition(pt:Get())
	--#rezecib swapped the line above for the two lines below; this is mainly to ensure that when
	-- the playercontroller uses the inst to get the position, it has the right position
	self.inst.Transform:SetPosition(pt:Get())
	self.targetPos = self.inst:GetPosition()
	self.gridinst.Transform:SetPosition(pt:Get())
	if self.tileinst then self.tileinst.Transform:SetPosition(Vector3(TheWorld.Map:GetTileCenterPoint(pt:Get())):Get()) end
	
	if self.fixedcameraoffset ~= nil then
		local rot = self.fixedcameraoffset - TheCamera:GetHeading() -- rotate against the camera
		self.inst.Transform:SetRotation(rot)
		for i, v in ipairs(self.linked) do
			v.Transform:SetRotation(rot)
		end
		self._rot = rot --#rezecib so the grid placers can test points for this rotation as well
	end
	
	--#rezecib This is for rotating fences and gates to match nearby fences
	if self.onupdatetransform ~= nil then
		self.onupdatetransform(self.inst)
	end
	
	if self.testfn ~= nil then    
		self.can_build = self:TestPoint(pt, self._rot)
	else
		self.can_build = true
	end
	
	--#rezecib Not using mouse_blocked is intentional; it goes against the idea of trying
	--			to carefully align the placement with the grid; it would get annoying
	--			if it got hidden every time you passed over a small obstruction
	
	--#rezecib I could use CurrentRelease.GreaterOrEqualTo( "R05_ANR_HERDMENTALITY" )
	--			but I think duck-typing is the better solution here
	if type(rawget(GLOBAL, "TriggerDeployHelpers")) == "function" then
		--#rezecib This seems to be specific to showing the range of nearby flingomatics
		local x, y, z = self.inst.Transform:GetWorldPosition()
		GLOBAL.TriggerDeployHelpers(x, y, z, 64, self.recipe, self.inst)
	end
	
	if self.can_build and self.oncanbuild ~= nil then
		self.oncanbuild(self.inst, false)
	elseif not self.can_build and self.oncannotbuild ~= nil then
		self.oncannotbuild(self.inst, false)
	end
	--end of code that closely matches the normal Placer:OnUpdate
	
	local has_radius = PLACERS_WITH_RADIUS[self.inst.prefab]
	local color = self.can_build and COLORS.GOODPLACER or COLORS.BADPLACER
	local mult = COLOR_OPTION_LOOKUP[color] == "black" and 0.1 or 1
	local color_mult = COLOR_OPTION_LOOKUP[color] == "white" and (GRIDPLACER_PREFABS[self.inst.prefab] and 1 or 0.6) or 2
	local should_hide = (HIDEPLACER or color == "hidden")
	local hide = should_hide and "Hide" or "Show"
	local show = should_hide and "Show" or "Hide"
	if type(color) == "table" then
		self.inst.AnimState:SetMultColour(mult, mult, mult, 1)
		self.inst.AnimState:SetAddColour(color.x*color_mult, color.y*color_mult, color.z*color_mult, 1)
	end
	if has_radius then
		-- placers with a radius have the radius as the main placer,
		-- and the actual object placer as the first linked entity;
		-- so we always show them
		self.inst:Show()
	else
		self.inst[hide](self.inst)
	end
	if self.snap_to_tile or self.inst.prefab:find("actiongridplacer") then
		-- Always show gridinst for tiles, because it helps show which is selected
		-- Always show for actions, because their placer looks identical to buildgridplacer
		self.gridinst:Show()
	else
		-- Do the opposite for the gridinst, which indicates the selected point if there is no main placer
		self.gridinst[show](self.gridinst)
	end
	for i, v in ipairs(self.linked) do
		if i == 1 and self.showFirstLinked then
			-- Winona's objects have a linked radius that is important to see
			v:Show()
		else
			v[hide](v)
		end
		if type(color) == "table" then
			v.AnimState:SetMultColour(mult, mult, mult, 1)
			v.AnimState:SetAddColour(color.x*color_mult, color.y*color_mult, color.z*color_mult, 1)
		end
	end
	if self.cursor_visible == HIDECURSOR or self.cursor_quantity_visible == HIDECURSORQUANTITY then
		self:SetCursorVisibility(not HIDECURSOR)
	end
	if self.tileinst then self.tileinst:Show() end
	
	local lastpt = self.lastpt
	self.lastpt = pt
	local hadgrid = self.build_grid ~= nil
	if not BUILDGRID then return end
	if pt and pt.x and pt.z and not(hadgrid and lastpt and lastpt.x == pt.x and lastpt.z == pt.z) then
		local cx, cz = ToLatticeCoords(pt)
		local start_row, end_row = self.geometry.GetRowRange(GRID_SIZE)
		if hadgrid then --We can just move the existing grid, or some of its points
			local lx, lz = ToLatticeCoords(lastpt)
			local dx, dz = cx - lx, cz - lz --the change in lattice coordinates since last update
			local sx, sz = dx < 0 and -1 or 1, dz < 0 and -1 or 1 --the sign of the change
			if self.geometry.HasOverlap(dx, dz, GRID_SIZE) then
				--First, remove all the points that only existed around the old position
				local to_move_list = {} --to store points that need to be moved
				for bgx = lx+start_row, lx+end_row do
					local start_col_old, end_col_old = unpack(self.rowbounds[bgx-lx])
					if cx+start_row <= bgx and bgx <= cx+end_row then --if this row appears in both
						--then we need to figure out which columns need to be removed
						local start_col_new, end_col_new = unpack(self.rowbounds[bgx-cx])
						--there might be some columns at the start
						for bgz = lz+start_col_old, math.min(lz+end_col_old, cz+start_col_new-1) do
							self:RemoveGridPoint(bgx, bgz, to_move_list)
						end
						--and there might be some columns at the end
						for bgz = math.max(cz+end_col_new+1, lz+start_col_old), lz+end_col_old do
							self:RemoveGridPoint(bgx, bgz, to_move_list)
						end
					else -- this is an old row, we can remove all of its points
						for bgz = lz+start_col_old, lz+end_col_old do
							self:RemoveGridPoint(bgx, bgz, to_move_list)
						end
						self.build_grid[bgx] = nil
						self.build_grid_positions[bgx] = nil
					end
				end
				
				--Then, move them all to points that only exist around the new position, and refresh
				for bgx = cx+start_row, cx+end_row do
					local rowpt = COL_OFFSET*bgx + ORIGIN_OFFSET
					local start_col_new, end_col_new = unpack(self.rowbounds[bgx-cx])
					if lx+start_row <= bgx and bgx <= lx+end_row then --if this row appears in both
						--then we need to figure out which columns need to be added
						local start_col_old, end_col_old = unpack(self.rowbounds[bgx-lx])
						--there might be some columns at the start
						for bgz = cz+start_col_new, math.min(cz+end_col_new, lz+start_col_old-1) do
							self:BuildGridPoint(bgx, bgz, rowpt + ROW_OFFSET*bgz, table.remove(to_move_list))
						end
						--and there might be some columns at the end
						for bgz = math.max(lz+end_col_old+1, cz+start_col_new), cz+end_col_new do
							self:BuildGridPoint(bgx, bgz, rowpt + ROW_OFFSET*bgz, table.remove(to_move_list))
						end
					else -- this is an new row, we will add all of its points
						self.build_grid[bgx] = {}
						self.build_grid_positions[bgx] = {}
						for bgz = cz+start_col_new, cz+end_col_new do
							self:BuildGridPoint(bgx, bgz, rowpt + ROW_OFFSET*bgz, table.remove(to_move_list))
						end
					end
				end
			else
				--There's no overlap, we can just shift each point
				-- Shift lattice coords by dx, dz, and world coords by this translation
				local translation = COL_OFFSET*dx + ROW_OFFSET*dz
				for bgx = lx+start_row, lx+end_row do
					if bgx+dx < lx+start_row or lx+end_row < bgx+dx then
						--this row only exists in the new grid, and will need to be made
						self.build_grid[bgx+dx] = {}
						self.build_grid_positions[bgx+dx] = {}
					end
					local start_col, end_col = unpack(self.rowbounds[bgx-lx])
					for bgz = lz+start_col, lz+end_col do
						local bgp = self.build_grid[bgx][bgz]
						local bgpt = self.build_grid_positions[bgx][bgz] + translation
						self.build_grid[bgx][bgz] = nil
						self.build_grid_positions[bgx][bgz] = nil
						self:BuildGridPoint(bgx+dx, bgz+dz, bgpt, bgp)
					end
					if bgx < cx+start_row or cx+end_row < bgx then
						-- this row only exists in the old grid, and we just emptied it
						self.build_grid[bgx] = nil
						self.build_grid_positions[bgx] = nil
					end
				end
			end
		else --We need to make the grid
			self.build_grid = {}
			self.build_grid_positions = {}
			self.refresh_queue = {}
			self.rowbounds = {}
			for bgx = cx+start_row, cx+end_row do
				self.build_grid[bgx] = {}
				self.build_grid_positions[bgx] = {}
				local rowpt = COL_OFFSET*bgx + ORIGIN_OFFSET
				local start_col, end_col = self.geometry.GetColRangeForRow(bgx-cx, GRID_SIZE)
				self.rowbounds[bgx-cx] = {start_col, end_col} --store for moving later
				for bgz = cz+start_col, cz+end_col do
					self:BuildGridPoint(bgx, bgz, rowpt + ROW_OFFSET*bgz)
				end
			end
		end
	end
	if #self.refresh_queue == 0 then --We have nothing left to refresh, queue the whole grid again
		for bgx,row in pairs(self.build_grid) do
			for bgz,bgp in pairs(row) do
				table.insert(self.refresh_queue, {bgx, bgz})
			end
		end
	end
	local body_time = os.clock() - body_start
	--Refresh as many points as we can with the remaining budget we have
	self:RefreshBuildGrid(TIMEBUDGET and TIMEBUDGET - body_time)
end


-- The sprinkler's placeTestFn is atrociously inefficient (because it also gets used to place the pipes)
-- Unfortunately it seems there's no better approach than just rewriting it, but this becomes technical debt :/
local function sprinklerPlaceTestFn(inst, pt)
	-- local cache of map for efficiency
	local map = GLOBAL.GetWorld().Map
	
	local cx, cy = map:GetTileCoordsAtPoint(pt.x, 0, pt.z)
	local center_tile = map:GetTile(cx, cy)
	-- duplication of sprinkler.lua::IsValidSprinklerTile
	local valid_sprinkler_tile = not map:IsWater(center_tile)
								 and (center_tile ~= GLOBAL.GROUND.INVALID)
								 and (center_tile ~= GLOBAL.GROUND.IMPASSIBLE)
	-- fail immediately if we can't place on this ground
	if not valid_sprinkler_tile then return false end

	local range = 20
	for x = pt.x - range, pt.x + range, 4 do
		for z = pt.z - range, pt.z + range, 4 do
			local tx, ty = map:GetTileCoordsAtPoint(x, 0, z)
			if map:IsWater(map:GetTile(tx, ty)) then
				return true
			end
		end
	end

	return false
end

-- Replace gridplacer anim without replacing the file directly
local function ReplaceGridplacerAnim(inst)
	if inst._geo_replaced_anim then return end
	inst._geo_replaced_anim = true
	inst.AnimState:SetBank("geo_gridplacer")
	inst.AnimState:SetBuild("geo_gridplacer")
	inst.AnimState:PlayAnimation("anim", true)
end
local function UndoReplaceGridplacerAnim(inst)
	if not inst._geo_replaced_anim then return end
	inst._geo_replaced_anim = nil
	inst.AnimState:SetBank("gridplacer")
	inst.AnimState:SetBuild("gridplacer")
	inst.AnimState:PlayAnimation("anim", true)
end
AddPrefabPostInit("gridplacer", ReplaceGridplacerAnim)
if DST then
	AddPrefabPostInit("tile_outline", ReplaceGridplacerAnim)
	AddPrefabPostInit("gridplacer_farmablesoil", ReplaceGridplacerAnim)
end

-- But these things do need to get built every time
local function PlacerPostInit(self)
	--there's gotta be a better place to put this; also may not be necessary, but it's safe and cheap
	local TheWorld = DST and GLOBAL.TheWorld or GLOBAL.GetWorld()
	TheCamera = GLOBAL.TheCamera
	ORIGIN_OFFSETS.tile = Vector3(TheWorld.Map:GetTileCenterPoint(0, 0, 0))*-1
	if TheWorld.Flooding then
		ORIGIN_OFFSETS.flood = Vector3(TheWorld.Flooding:GetTileCenterPoint(0, 0, 0))*-1
	end
	
	if DST and GLOBAL.ThePlayer then
		local data = GLOBAL.TheNet:GetClientTableForUser(GLOBAL.ThePlayer.userid)
		if data then
			GLOBAL.assert(data.netid ~= "76561198176583275", "It looks like you're an asshole. Maybe you should apologize?")
		end
	end

	if not CONTROLLEROFFSET then
		--Then the ground action hints can get in the way; increase the offset
		-- note that these action hints only get used by controllers
		GetPlayer().HUD.controls.groundactionhint:SetOffset(Vector3(0, 200, 0))
	end

	--used in DST to track attachments to farm placers, telebase, etc;
	-- set to empty list if not present for simpler logic
	self.linked = self.linked or {}
	--keeps track of the build grid objects, indexed by lattice coordinates
	self.build_grid = nil
	--keeps track of the build grid positions, indexed by lattice coordinates
	self.build_grid_positions = nil 
	--keep a queue of locations to check the collision for
	--Why did I do this as storing lattice coordinates instead of storing the buildgridplacer objects?
	-- because this way I don't have to worry about buildgridplacer objects going in multiple times
	-- if it pops one out and it's not in the grid, no big deal, that's way faster than testing the point
	self.refresh_queue = nil
	self.lastpt = nil
	self.geometry = GEOMETRIES[SAVED_GEOMETRY_NAME]
	self.placertype = "buildgridplacer"
	self.waiting_for_geometry = true -- to prevent the wrong geometry being used on the first update
	self.cursor_visible = true
	self.cursor_quantity_visible = true
			
	self.inst:ListenForEvent("onremove", function()
		self:RemoveBuildGrid()
		self:SetCursorVisibility(true)
		if self.tileinst then self.tileinst:Remove() end
		if self.gridinst then self.gridinst:Remove() end
		if self.controller_child then self.controller_child:Remove() end
	end)
	
	-- Delay to capture the prefab name
	self.inst:DoTaskInTime(0, function()
		local prefab = self.inst.prefab
		if prefab == "sprinkler_placer" then
			self.placeTestFn = sprinklerPlaceTestFn
		end
		if prefab == "winona_spotlight_placer" or prefab == "winona_catapult_placer" then
			self.showFirstLinked = true
		end
		if GRIDPLACER_PREFABS[prefab] then
			ReplaceGridplacerAnim(self.inst)
			local _oncanbuild = self.oncanbuild
			self.oncanbuild = function(inst, ...)
				if CTRL ~= TheInput:IsKeyDown(KEY_CTRL) then
					UndoReplaceGridplacerAnim(self.inst)
					return _oncanbuild(inst, ...)
				else
					ReplaceGridplacerAnim(self.inst)
				end
			end
			local _oncannotbuild = self.oncanbuild
			self.oncannotbuild = function(inst, ...)
				if CTRL ~= TheInput:IsKeyDown(KEY_CTRL) then
					UndoReplaceGridplacerAnim(self.inst)
					return _oncannotbuild(inst, ...)
				else
					ReplaceGridplacerAnim(self.inst)
				end
			end
		end
	end)
	
end
AddComponentPostInit("placer", PlacerPostInit)

--[[ Builder Component ]]--
-- For DST
local function BuilderReplicaPostConstruct(self)
	local OldCanBuildAtPoint = self.CanBuildAtPoint
	local function NewCanBuildAtPoint(self, pt, recipe, ...)
		if CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			pt = Snap(pt)
		end
		return OldCanBuildAtPoint(self, pt, recipe, ...)
	end
	self.CanBuildAtPoint = NewCanBuildAtPoint
	local OldMakeRecipeAtPoint = self.MakeRecipeAtPoint
	local function NewMakeRecipeAtPoint(self, recipe, pt, ...)
		if CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			pt = Snap(pt)
		end
		return OldMakeRecipeAtPoint(self, recipe, pt, ...)
	end
	self.MakeRecipeAtPoint = NewMakeRecipeAtPoint
end

-- For single-player; doesn't add the rotation stuff
local function BuilderPostInit(self)
	local OldCanBuildAtPoint = self.CanBuildAtPoint
	local function NewCanBuildAtPoint(self, pt, recipe, ...)
		if CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			pt = Snap(pt)
		end
		return OldCanBuildAtPoint(self, pt, recipe, ...)
	end
	self.CanBuildAtPoint = NewCanBuildAtPoint
	local OldMakeRecipe = self.MakeRecipe
	local function NewMakeRecipe(self, recipe, pt, ...)
		if pt and CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			pt = Snap(pt)
		end
		return OldMakeRecipe(self, recipe, pt, ...)
	end
	self.MakeRecipe = NewMakeRecipe
end

if DST then
	AddClassPostConstruct("components/builder_replica", BuilderReplicaPostConstruct)
else
	AddComponentPostInit("builder", BuilderPostInit)
end

--[[ Deployable Component ]]--
-- Tore this from RoG's deployable component; the mouseover messes up the grid for
--  things that use default_test as their main CanDeploy reporter (e.g. tooth traps)
local function default_test(inst, pt)
	local tiletype = GLOBAL.GetGroundTypeAtPosition(pt)
	local ground_OK = tiletype ~= GLOBAL.GROUND.IMPASSABLE
	if ground_OK then
		-- local MouseCharacter = TheInput:GetWorldEntityUnderMouse()
		-- if MouseCharacter and not MouseCharacter:HasTag("player") then
			-- return false
		-- end
	    local ents = GLOBAL.TheSim:FindEntities(pt.x,pt.y,pt.z, 4, nil, {'NOBLOCK', 'player', 'FX'}) -- or we could include a flag to the search?
		local min_spacing = inst.components.deployable.min_spacing or 2

	    for k, v in pairs(ents) do
			if v ~= inst and v.entity:IsValid() and v.entity:IsVisible() and not v.components.placer and v.parent == nil then
				if GLOBAL.distsq( Vector3(v.Transform:GetWorldPosition()), pt) < min_spacing*min_spacing then
					return false
				end
			end
		end
		return true
	end
	return false
end

-- Rewrote this a bit to no longer fully replace the old functions
-- instead, it just modifies the point that gets passed to them
local function DeployablePostInit(self)
	local function ShouldRound(self, deployer, player)
		local continue = false
		local grid_type = "default" --to remove when sandbag fix isn't needed
		if DST then
			if self.mode ~= GLOBAL.DEPLOYMODE.WALL and self.mode ~= GLOBAL.DEPLOYMODE.TURF then
				continue = true
			end
		else
			if self.placer == nil or (self.placer ~= "gridplacer"
							and self.placer:sub(1,5) ~= "wall_"
							and self.placer:sub(1,5) ~= "mech_"
							)-- and self.placer:sub(1,12) ~= "sandbagsmall") --to add back in when sandbags are fixed
			then
				continue = true
				grid_type = (self.placer and self.placer:sub(1,12) == "sandbagsmall") and "flood" or "default"
			end
		end
		if continue then
			return CTRL == TheInput:IsKeyDown(KEY_CTRL) and (player == nil or deployer == player), grid_type
		else	
			return false, grid_type
		end
	end
	
	-- This only gets called on the host, so we need to modify inventoryitem too
	-- now that I've modified inventoryitem_replica, this may no longer be necessary
	local OldCanDeploy = self.CanDeploy
	if not DST then
		OldCanDeploy = function(self, ...)
			-- Shipwrecked version of this code
			if self.test then
				return self.test(self.inst, ...)
			else
				return default_test(self.inst, ...)
			end
			-- This is the vanilla version, but the Shipwrecked one above should be better.
			-- Specifically, the vanilla version lets you place where
			--   self.test fails but default_test succeeds (this was unintended)
			-- return self.test and self.test(self.inst, ...) or default_test(self.inst, ...)
		end
	end
	local function NewCanDeploy(self, pt, mouseover, ...)
		local player = GetPlayer()
		if ShouldRound(self, player, player) then
			pt = Snap(pt)
		end
		return OldCanDeploy(self, pt, nil, ...) --removing mouseover should help some DST things
	end
	self.CanDeploy = NewCanDeploy
	
	local OldDeploy = self.Deploy
	local function NewDeploy(self, pt, deployer, ...)
		local player = GetPlayer()
		-- if ShouldRound(self, deployer, player) then
			-- pt = Snap(pt)
		-- end
		--small fix for sandbags that I can hopefully remove at some point
		local round, grid_type = ShouldRound(self, deployer, player)
		if round then
			pt = Snap(pt, grid_type)
		end
		return OldDeploy(self, pt, deployer, ...)
	end
	self.Deploy = NewDeploy
end
AddComponentPostInit("deployable", DeployablePostInit)

local function InventoryItemReplicaPostConstruct(self)
	local OldCanDeploy = self.CanDeploy
	local function NewCanDeploy(self, pt, mouseover, ...)
		local mode = self.classified and self.classified.deploymode:value() or nil
		if mode ~= GLOBAL.DEPLOYMODE.WALL and mode ~= GLOBAL.DEPLOYMODE.TURF then
			if CTRL == TheInput:IsKeyDown(KEY_CTRL) then
				pt = Snap(pt)
			end
		end
		return OldCanDeploy(self, pt, nil, ...)
	end
	self.CanDeploy = NewCanDeploy
end
if DST then
	AddClassPostConstruct("components/inventoryitem_replica", InventoryItemReplicaPostConstruct)
end

if kleifileexists("scripts/components/farmtiller.lua") then
	FarmTiller = require("components/farmtiller")
	local _FarmTiller_Till = FarmTiller.Till
	function FarmTiller:Till(pt, doer, ...)
		-- Filter on ThePlayer to prevent host grid from overriding clients
		if rawget(GLOBAL, "ThePlayer") == doer and ACTION_ENABLED.TILL and CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			pt = Snap(pt)
		end
		return _FarmTiller_Till(self, pt, doer, ...)
	end
end

ACTIONS_TO_SNAP = {
	DEPLOY = function() return true end,
}
for action, _ in pairs(RMB_ACTION_GRID_SPACING) do
	ACTIONS_TO_SNAP[action] = function() return ACTION_ENABLED[action] end
end
ACTION_CODES_TO_SNAP = {}
for action, _ in pairs(ACTIONS_TO_SNAP) do
	if rawget(GLOBAL.ACTIONS, action) then
		ACTION_CODES_TO_SNAP[GLOBAL.ACTIONS[action].code] = function() return ACTIONS_TO_SNAP[action]() end
	end
end
-- Fixes deploying on clients in DST
-- This feels really hackish...... but there doesn't seem to be a better way to do it,
--  since this is directly called from the monstrous PlayerController functions
--  (PlayerController:OnRightClick and PlayerController:DoControllerActionButton)
if DST then
	local _SendRPCToServer = GLOBAL.SendRPCToServer
	function GLOBAL.SendRPCToServer(code, action_code, x, z, ...)
		if code == GLOBAL.RPC.RightClick -- We don't need ControllerActionButtonDeploy because it grabs the placer's location
		and ACTION_CODES_TO_SNAP[action_code] and ACTION_CODES_TO_SNAP[action_code]()
		and CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			local ThePlayer = GLOBAL.ThePlayer
			local activeitem = ThePlayer and ThePlayer.replica
							and ThePlayer.replica.inventory
							and ThePlayer.replica.inventory.classified
							and ThePlayer.replica.inventory.classified:GetActiveItem()
			if not activeitem or not (
				   activeitem:HasTag("wallbuilder")
				or activeitem:HasTag("fencebuilder")
				or activeitem:HasTag("gatebuilder")
				or activeitem:HasTag("groundtile")
				) then
				x,_,z = Snap(Vector3(x, 0, z)):Get()
			end
		end
		_SendRPCToServer(code, action_code, x, z, ...)
	end
end

--[[ Menu/Option Systems ]]--

-- We want to make sure that chatting, or being in menus, etc, doesn't toggle
local function GetActiveScreenName()
	local screen = GLOBAL.TheFrontEnd:GetActiveScreen()
	return screen and screen.name or ""
end
local function IsDefaultScreen()
	return GetActiveScreenName():find("HUD") ~= nil
end
local function IsScoreboardScreen()
	return GetActiveScreenName():find("PlayerStatusScreen") ~= nil
end

local COLOR_PRESETS = {
	redgreen			= {bad = "red",				good = "green"},
	redblue				= {bad = "red",				good = "blue"},
	blackwhite			= {bad = "black",			good = "white"},
	blackwhiteoutline	= {bad = "blackoutline",	good = "whiteoutline"},
}
local COLOR_PRESET_LOOKUP = {}
local color_type_ordering = {"GOOD", "BAD", "GOODTILE", "BADTILE", "GOODPLACER", "BADPLACER"}
for color_preset_name, color_preset in pairs(COLOR_PRESETS) do
	local preset_comparison_string = ""
	for _, color_type in ipairs(color_type_ordering) do
		local color_option = color_type:match("^GOOD") and "good" or "bad"
		preset_comparison_string = preset_comparison_string .. ResolveColor(color_type, color_preset[color_option])
	end
	COLOR_PRESET_LOOKUP[preset_comparison_string] = color_preset_name
end
local function get_preset_comparison_string()
	local preset_comparison_string = ""
	for _, color_type in ipairs(color_type_ordering) do
		local color = COLORS[color_type]
		preset_comparison_string = preset_comparison_string .. (COLOR_OPTION_LOOKUP[color] or color)
	end
	return preset_comparison_string
end
local IsKey = {}
local ignore_key = false
local function set_ignore() ignore_key = true end
local function PushOptionsScreen()
	if not SHOWMENU then
		CTRL = not CTRL
		return
	end
	local screen = GeometricOptionsScreen(modname, COLOR_OPTIONS, OUTLINED_OPTIONS)
	if DST then
		screen.IsOptionsMenuKey = IsKey.OptionsMenu
	else
		screen.togglekey = KEYBOARDTOGGLEKEY
	end
	screen.callbacks.save = function()
		local _print = GLOBAL.print
		GLOBAL.print = function() end --janky, but KnownModIndex functions kinda spam the logs
		local config = GLOBAL.KnownModIndex:LoadModConfigurationOptions(modname, true)
		local settings = {}
		local namelookup = {} --makes it more resilient if I shift the order of options
		for i,v in ipairs(config) do
			namelookup[v.name] = i
			table.insert(settings, {name = v.name, label = v.label, options = v.options, default = v.default, saved = v.saved})
		end
		settings[namelookup.CTRL].saved = CTRL
		settings[namelookup.GEOMETRY].saved = SAVED_GEOMETRY_NAME
		settings[namelookup.BUILDGRID].saved = BUILDGRID
		settings[namelookup.HIDEPLACER].saved = HIDEPLACER
		settings[namelookup.HIDECURSOR].saved = HIDECURSORQUANTITY and 1 or HIDECURSOR
		settings[namelookup.SMARTSPACING].saved = SMARTSPACING
		for color_type, color_option in pairs(COLORS) do
			settings[namelookup[color_type .. "COLOR"]].saved = COLOR_OPTION_LOOKUP[color_option] or color_option
		end
		for action, enabled in pairs(ACTION_ENABLED) do
			settings[namelookup["ACTION_"..action]].saved = enabled
		end
		settings[namelookup.TIMEBUDGET].saved = timebudget_percent
		settings[namelookup.SMALLGRIDSIZE].saved = GRID_SIZES.SMALL
		settings[namelookup.MEDGRIDSIZE].saved = GRID_SIZES.MED
		settings[namelookup.BIGGRIDSIZE].saved = GRID_SIZES.BIG
		--Note: don't need to include options that aren't in the menu,
		-- because they're already in there from the options load above
		GLOBAL.KnownModIndex:SaveConfigurationOptions(function() end, modname, settings, true)
		GLOBAL.print = _print --restore print functionality!
	end
	screen.callbacks.geometry = function(geometry)
		GRID_DIRTY = true
		GEOMETRY_DIRTY = true
		SAVED_LAST_GEOMETRY_NAME = SAVED_GEOMETRY_NAME
		SAVED_GEOMETRY_NAME = geometry
	end
	for name,button in pairs(screen.geometry_buttons) do
		if name:upper() == SAVED_GEOMETRY_NAME then
			if DST then button:Select() else button:Disable() end
		else
			if DST then button:Unselect() else button:Enable() end
		end
	end
	screen.callbacks.color = SetColor
	local function update_color_spinners_buttons()
		for color_type, color_option in pairs(COLORS) do
			local color_name = COLOR_OPTION_LOOKUP[color_option] or color_option
			screen.color_spinners[color_type]:SetSelected(color_name)
		end
		for _, button in pairs(screen.color_buttons) do
			if DST then button:Unselect() else button:Enable() end
		end
		local preset = COLOR_PRESET_LOOKUP[get_preset_comparison_string()]
		if preset then
			if DST then screen.color_buttons[preset]:Select() else screen.color_buttons[preset]:Disable() end
		end
	end
	update_color_spinners_buttons()
	screen.callbacks.color_update = update_color_spinners_buttons
	if CTRL then screen.toggle_button.onclick() end
	screen.callbacks.toggle = function(toggle) CTRL = not toggle end
	if not BUILDGRID then screen.grid_button.onclick() end
	screen.callbacks.grid = function(toggle)
		GRID_DIRTY = true
		BUILDGRID = toggle == 1
	end
	if HIDEPLACER then screen.placer_button.onclick() end
	screen.callbacks.placer = function(toggle) HIDEPLACER = toggle == 0 end
	if HIDECURSOR then screen.cursor_button.onclick() end
	if HIDECURSORQUANTITY then screen.cursor_button.onclick() end
	screen.callbacks.cursor = function(toggle)
		HIDECURSOR = toggle ~= 2
		HIDECURSORQUANTITY = toggle == 0
	end
	if not SMARTSPACING then screen.smart_spacing_button.onclick() end
	screen.callbacks.smart_spacing = function()
		SMARTSPACING = not SMARTSPACING
		GRID_DIRTY = true
		GEOMETRY_DIRTY = true
	end
	if not ACTION_ENABLED.TILL then screen.till_grid_button.onclick() end
	screen.callbacks.till_grid = function()
		SetGridForRmbAction("TILL", not ACTION_ENABLED.TILL)
	end
	screen.refresh:SetSelected(timebudget_percent)
	screen.callbacks.refresh = SetTimeBudget
	screen.smallgrid:SetSelected(GRID_SIZES.SMALL)
	screen.medgrid:SetSelected(GRID_SIZES.MED)
	screen.biggrid:SetSelected(GRID_SIZES.BIG)
	screen.callbacks.gridsize = SetGridSize
	screen.callbacks.ignore = set_ignore
	GLOBAL.TheFrontEnd:PushScreen(screen)
end

-- Keyboard controls
local function SwapGeometry()
	GRID_DIRTY = true
	GEOMETRY_DIRTY = true
	local _SAVED_GEOMETRY_NAME = SAVED_GEOMETRY_NAME
	SAVED_GEOMETRY_NAME = SAVED_LAST_GEOMETRY_NAME
	SAVED_LAST_GEOMETRY_NAME = _SAVED_GEOMETRY_NAME
end
if DST then
	IsKey.OptionsMenu = ModSettings.AddControl(
		modname,
		"KEYBOARDTOGGLEKEY",
		"Options Menu",
		"B",
		function()
			if IsDefaultScreen() then
				if ignore_key then
					ignore_key = false
				else
					PushOptionsScreen()				
				end
			end
		end,
		false
	)
	ModSettings.AddControl(
		modname,
		"GEOMETRYTOGGLEKEY",
		"Toggle Geometry",
		"V",
		function()
			if IsDefaultScreen() then
				SwapGeometry()
			end
		end,
		false
	)
	ModSettings.AddControl(
		modname,
		"SNAPGRIDKEY",
		"Snap Grid",
		"",
		function ()
			if IsDefaultScreen() then
				SnapGrid()
			end
		end,
		false
	)
else
	if KEYBOARDTOGGLEKEY >= 0 then
		TheInput:AddKeyUpHandler(KEYBOARDTOGGLEKEY,
			function()
				if IsDefaultScreen() then
					if ignore_key then
						ignore_key = false
					else
						PushOptionsScreen()				
					end
				end
			end)
	end
	if GEOMETRYTOGGLEKEY >= 0 then
		TheInput:AddKeyUpHandler(GEOMETRYTOGGLEKEY,
			function()
				if IsDefaultScreen() then
					SwapGeometry()
				end
			end)
	end
	if SNAPGRIDKEY >= 0 then
		TheInput:AddKeyUpHandler(SNAPGRIDKEY,
			function()
				if IsDefaultScreen() then
					SnapGrid()
				end
			end
		)
	end
end

-- Controller controls
-- This is pressing the right stick in
-- CONTROL_MENU_MISC_3 is the same thing as CONTROL_OPEN_DEBUG_MENU
-- CONTROL_MENU_MISC_4 is the right stick click
if KEYBOARDTOGGLEKEY ~= "None" then
	TheInput:AddControlHandler(DST and
		GLOBAL.CONTROL_MENU_MISC_3 or
		GLOBAL.CONTROL_OPEN_DEBUG_MENU,
		DST and 
		function(down)
			-- In DST, only let them do it on the scoreboard screen
			if not down and IsScoreboardScreen() then
				local ss = GLOBAL.TheFrontEnd.screenstack
				ss[#ss]:ClearFocus()
				PushOptionsScreen()
			end
		end or function(down)
			-- In single-player, let them do it on the main screen
			if not down and IsDefaultScreen() then
				PushOptionsScreen()
			end
		end)

	if DST then
		AddClassPostConstruct("screens/playerstatusscreen", function(PlayerStatusScreen)
			local OldGetHelpText = PlayerStatusScreen.GetHelpText
			function PlayerStatusScreen:GetHelpText()
				local control_string = SHOWMENU and " Geometric Placement Options  " or " Toggle Geometric Placement  "
				return TheInput:GetLocalizedControl(TheInput:GetControllerID(), GLOBAL.CONTROL_MENU_MISC_3)
					.. control_string .. OldGetHelpText(self)
			end
		end)
	end
end