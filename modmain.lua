PrefabFiles = {
	"buildgridplacer",
}
Assets = {
	Asset("ANIM", "anim/buildgridplacer.zip"),
	
	--Geometry button icons
	Asset( "IMAGE", "images/diamond_geometry.tex" ),
	Asset( "ATLAS", "images/diamond_geometry.xml" ),
	Asset( "IMAGE", "images/square_geometry.tex" ),
	Asset( "ATLAS", "images/square_geometry.xml" ),
	Asset( "IMAGE", "images/flat_hexagon_geometry.tex" ),
	Asset( "ATLAS", "images/flat_hexagon_geometry.xml" ),
	Asset( "IMAGE", "images/pointy_hexagon_geometry.tex" ),
	Asset( "ATLAS", "images/pointy_hexagon_geometry.xml" ),
	Asset( "IMAGE", "images/x_hexagon_geometry.tex" ),
	Asset( "ATLAS", "images/x_hexagon_geometry.xml" ),
	Asset( "IMAGE", "images/z_hexagon_geometry.tex" ),
	Asset( "ATLAS", "images/z_hexagon_geometry.xml" ),
	
	--Toggle button icons
	Asset( "IMAGE", "images/cursor_toggle_icon.tex" ),
	Asset( "ATLAS", "images/cursor_toggle_icon.xml" ),
	Asset( "IMAGE", "images/cursor_toggle_icon_num.tex" ),
	Asset( "ATLAS", "images/cursor_toggle_icon_num.xml" ),
	Asset( "IMAGE", "images/placer_toggle_icon.tex" ),
	Asset( "ATLAS", "images/placer_toggle_icon.xml" ),
	Asset( "IMAGE", "images/grid_toggle_icon.tex" ),
	Asset( "ATLAS", "images/grid_toggle_icon.xml" ),
	Asset( "IMAGE", "images/toggle_x_out.tex" ),
	Asset( "ATLAS", "images/toggle_x_out.xml" ),
}

-- Thanks to simplex for this clever memoized DST check!
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
local SpawnPrefab = GLOBAL.SpawnPrefab
local GeometricOptionsScreen = DST and require("screens/geometricoptionsscreen")
										or require("screens/geometricoptionsscreen_singleplayer")

local CTRL = GetModConfigData("CTRL")
KEYBOARDTOGGLEKEY = GetModConfigData("KEYBOARDTOGGLEKEY")
if type(KEYBOARDTOGGLEKEY) == "string" then
	KEYBOARDTOGGLEKEY = KEYBOARDTOGGLEKEY:lower():byte()
end
GEOMETRYTOGGLEKEY = GetModConfigData("GEOMETRYTOGGLEKEY"):lower():byte()
SHOWMENU = GetModConfigData("SHOWMENU")
local BUILDGRID = GetModConfigData("BUILDGRID")
local CONTROLLEROFFSET = GetModConfigData("CONTROLLEROFFSET")

local TIMEBUDGET = GetModConfigData("TIMEBUDGET")
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

local grid_dirty = false
local SMALLGRIDSIZE = GetModConfigData("SMALLGRIDSIZE")
local MEDGRIDSIZE = GetModConfigData("MEDGRIDSIZE")
local FLOODGRIDSIZE = GetModConfigData("FLOODGRIDSIZE")
local BIGGRIDSIZE = GetModConfigData("BIGGRIDSIZE")
local GRID_SIZES = {SMALLGRIDSIZE, MEDGRIDSIZE, FLOODGRIDSIZE, BIGGRIDSIZE}
local function SetGridSize(grid_type, new_size)
	grid_dirty = true
	GRID_SIZES[grid_type] = new_size or GRID_SIZES[grid_type]
end

-- Storing these in lists for efficiency later on
local GRID_SPACINGS = {0.5, 1, 2, 4}

-- Tiles, walls, and flood tiles don't fall exactly as the lattice would predict
local GRID_OFFSETS = {0, 0.5, -1, -2} --the last two might depend on map size, so they get acquired in PlacerPostInit
for i,grid_offset in pairs(GRID_OFFSETS) do
	GRID_OFFSETS[i] = Vector3(grid_offset, 0, grid_offset)
end

local COLORS = GetModConfigData("COLORS") or "blackwhiteoutline"
local OUTLINE = false
local goodcolor = nil
local badcolor = nil
local h = 1
local l = 1/8
local COLORTABLE = {
	redgreen = { badcolor = Vector3(h, l, l), goodcolor = Vector3(l, h, l), outline = false },
	redblue = {	badcolor = Vector3(h, l, l), goodcolor = Vector3(l, l, h), outline = false },
	blackwhite = { badcolor = Vector3(l, l, l), goodcolor = Vector3(h, h, h), outline = false },
	blackwhiteoutline = { badcolor = Vector3(l, l, l), goodcolor = Vector3(h, h, h), outline = true },
}
local function SetColor(colorname)
	grid_dirty = true
	COLORS = colorname
	goodcolor = COLORTABLE[colorname].goodcolor
	badcolor = COLORTABLE[colorname].badcolor
	OUTLINE = COLORTABLE[colorname].outline
end
SetColor(COLORS)

local HIDEBLOCKED = GetModConfigData("HIDEBLOCKED")
local SHOWTILE = GetModConfigData("SHOWTILE")

local HIDEPLACER = GetModConfigData("HIDEPLACER")
local HIDECURSOR = GetModConfigData("HIDECURSOR")
local HIDECURSORQUANTITY = HIDECURSOR == 1
local HIDECURSOR = HIDECURSOR ~= false
local REDUCECHESTSPACING = GetModConfigData("REDUCECHESTSPACING")
if REDUCECHESTSPACING then
-- other geometry mods ignore the special case for chests that increases the spacing for them
-- in Builder:CanBuildAtPoint; however, reducing the built-in spacing by just a little bit
-- gives similar behavior in terms of which lattice points you can build the chest
	local treasurechestrecipe = DST
								and GLOBAL.GetValidRecipe('treasurechest')
								or  GLOBAL.GetRecipe('treasurechest')
	treasurechestrecipe.min_spacing = treasurechestrecipe.min_spacing - 0.1
end

local GEOMETRY = (GetModConfigData("GEOMETRY") or "SQUARE"):upper()
local inferred_last_geometries = {
	SQUARE = "X_HEXAGON",
	DIAMOND = "FLAT_HEXAGON",
	X_HEXAGON = "SQUARE",
	Z_HEXAGON = "SQUARE",
	FLAT_HEXAGON = "DIAMOND",
	POINTY_HEXAGON = "DIAMOND",
}
local LAST_GEOMETRY = inferred_last_geometries[GEOMETRY]

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

-- Precompute the offsets for each grid spacing to save time later
for geometry_name,geometry in pairs(GEOMETRIES) do
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
	local grid_inflation = geometry_name == "SQUARE" and 1 or (1 + 1.5e-4)
	geometry.name = geometry_name
	for _,offset_name in ipairs({"row_offset", "col_offset"}) do
		local offset = geometry[offset_name]
		geometry[offset_name] = {}
		for _,grid_spacing in ipairs(GRID_SPACINGS) do
			table.insert(geometry[offset_name], offset*grid_spacing*grid_inflation)
		end
	end
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
	local hexagonal = geometry_name:find("HEXAGON")
	--precompute the inverse determinants
	geometry.inv_determinant = {}
	for grid_type,col in pairs(geometry.col_offset) do
		local row = geometry.row_offset[grid_type]
		geometry.inv_determinant[grid_type] = 1/(col.x*row.z - col.z*row.x)
	end	
	if hexagonal then
		geometry.ToLatticeCoords = function(pt, grid_type)
			--Don't need to account for grid_spacing or grid_inflation; they're already in the offsets
			pt = pt - GRID_OFFSETS[grid_type]
			
			--Borrowing notation from http://www.redblobgames.com/grids/hexagons/
			local col = geometry.col_offset[grid_type]
			local row = geometry.row_offset[grid_type]
			local inv_determinant = geometry.inv_determinant[grid_type]
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
		geometry.ToLatticeCoords = function(pt, grid_type)
			--Don't need to account for grid_spacing or grid_inflation; they're already in the offsets
			pt = pt - GRID_OFFSETS[grid_type]
			local col = geometry.col_offset[grid_type]
			local row = geometry.row_offset[grid_type]
			local inv_determinant = geometry.inv_determinant[grid_type]
			return math.floor((row.z*pt.x - row.x*pt.z)*inv_determinant + .5),
				   math.floor((col.x*pt.z - col.z*pt.x)*inv_determinant + .5)
		end
	end
end

GEOMETRY = GEOMETRIES[GEOMETRY] or GEOMETRIES.SQUARE
LAST_GEOMETRY = GEOMETRIES[LAST_GEOMETRY] or GEOMETRIES.X_HEXAGON
local function Snap(pt, grid_type)
	grid_type = grid_type or 1
	local geometry = grid_type == 1 and GEOMETRY or GEOMETRIES.SQUARE
	local bgx, bgz = geometry.ToLatticeCoords(pt, grid_type)
	return geometry.col_offset[grid_type]*bgx + geometry.row_offset[grid_type]*bgz + GRID_OFFSETS[grid_type]
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
	local canbuild = self.testfn == nil or self.testfn(pt, self._rot)
	return canbuild, canbuild and goodcolor or badcolor
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
		if self.placertype == "gridplacer" then
			bgp.AnimState:SetMultColour(.05, .05, .05, 0.05)
		end
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

if HIDEBLOCKED then
	function Placer:RefreshGridPoint(bgx, bgz)
		local row = self.build_grid[bgx]
		if row == nil then return end
		local bgp = row[bgz]
		if bgp == nil then return end
		local bgpt = self.build_grid_positions[bgx][bgz]
		local can_build, color = self:TestPoint(bgpt)
		if can_build then
			bgp:Show()
		else
			bgp:Hide()
			return
		end
		if OUTLINE and self.placertype == "buildgridplacer" then
			bgp.AnimState:PlayAnimation(can_build and "on" or "off", true)
		else
			bgp.AnimState:SetAddColour(color.x, color.y, color.z, 0)
		end
	end
else
	function Placer:RefreshGridPoint(bgx, bgz)
		local row = self.build_grid[bgx]
		if row == nil then return end
		local bgp = row[bgz]
		if bgp == nil then return end
		local bgpt = self.build_grid_positions[bgx][bgz]
		local can_build, color = self:TestPoint(bgpt)
		if OUTLINE and self.placertype == "buildgridplacer" then
			bgp.AnimState:PlayAnimation(can_build and "on" or "off", true)
		else
			bgp.AnimState:SetAddColour(color.x, color.y, color.z, 0)
		end
	end
end

function Placer:RemoveGridPoint(bgx, bgz, to_move_list)
	table.insert(to_move_list, self.build_grid[bgx][bgz])
	self.build_grid[bgx][bgz] = nil
	self.build_grid_positions[bgx][bgz] = nil
end

local OldOnUpdate = Placer.OnUpdate
function Placer:OnUpdate(dt)
	local body_start = os.clock()
	--#rezecib Need these here to let the rest of the code match Placer:OnUpdate for easy syncing
	local TheWorld = DST and GLOBAL.TheWorld or GLOBAL.GetWorld()
	if self.waiting_for_geometry then
		self.waiting_for_geometry = nil
		if self.snap_to_tile then
			self.placertype = "gridplacer"
		elseif SHOWTILE then
			self.tileinst = SpawnPrefab("gridplacer")
			self.tileinst.AnimState:SetSortOrder(1)
		end
		if self.snap_to_meters or self.snap_to_flood or self.snap_to_tile then
			self.snap_to_large = true
			self.geometry = GEOMETRIES.SQUARE
		end
		self.gridinst = self:MakeGridInst()
	end
	--#rezecib Restores the default game behavior by holding ctrl
	if CTRL ~= TheInput:IsKeyDown(KEY_CTRL) then
		self:RemoveBuildGrid()
		if self.tileinst then self.tileinst:Hide() end
		self.gridinst:Hide()
		self.inst:Show()
		self:SetCursorVisibility(true)
		return OldOnUpdate(self, dt)
	end
	if grid_dirty then
		--Some settings have changed that will mess up the grid unless we rebuild it
		self:RemoveBuildGrid()
		self.geometry = self.snap_to_large and GEOMETRIES.SQUARE or GEOMETRY
		grid_dirty = false
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
		elseif self.snap_to_flood then
		-- elseif self.snap_to_flood and TheWorld.Flooding then 
			-- Flooding tiles exist at odd-numbered integer coordinates
			-- local center = Vector3(TheWorld.Flooding:GetTileCenterPoint(pt:Get()))
			-- pt.x = center.x
			-- pt.y = center.y
			-- pt.z = center.z
			--#rezecib their flooding solution for RoG is shitty, so I replaced it
			pt = Snap(pt, 3)
		else --#rezecib Added this block, everything else should match Placer:OnUpdate
			pt = Snap(pt)
		end
	else -- Controller input
		local offset = CONTROLLEROFFSET and 1 or 0
		if self.recipe then 
			if self.recipe.distance then 
				offset = self.recipe.distance - 1
				offset = math.max(offset*0.9, 1)
			end 
		elseif self.invobject then 
			if self.invobject.components.deployable and self.invobject.components.deployable.deploydistance then 
				--Adjusted so that you can place boats when right up against the shoreline
				offset = self.invobject.components.deployable.deploydistance*0.9
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
			--#rezecib their flooding solution for RoG is shitty, so I replaced it
			pt = Snap(pt, 3)
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
	self.gridinst.Transform:SetPosition(pt:Get())
	if self.tileinst then self.tileinst.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(pt:Get())) end
	
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
		self.can_build, self.mouse_blocked = self.testfn(pt, self._rot)
	else
		self.can_build = true
		self.mouse_blocked = false
	end
	--#rezecib Not using mouse_blocked is intentional; it goes against the idea of trying
	--			to carefully align the placement with the grid; it would get annoying
	--			if it got hidden every time you passed over a small obstruction
	
	--#rezecib I could use CurrentRelease.GreaterOrEqualTo( "R05_ANR_HERDMENTALITY" )
	--			but I think duck-typing is the better solution here
	if type(GLOBAL.rawget(GLOBAL, "TriggerDeployHelpers")) == "function" then
		--#rezecib This seems to be specific to showing the range of nearby flingomatics
		local x, y, z = self.inst.Transform:GetWorldPosition()
		GLOBAL.TriggerDeployHelpers(x, y, z, 64)
	end
	
	--end of code that closely matches the normal Placer:OnUpdate
	
	local color = self.can_build and goodcolor or badcolor
	self.inst.AnimState:SetAddColour(color.x*2, color.y*2, color.z*2, 0)
	for i, v in ipairs(self.linked) do
		v.AnimState:SetAddColour(color.x*2, color.y*2, color.z*2, 0)
	end
	local firesuppressor = self.inst.prefab == "firesuppressor_placer"
	if HIDEPLACER and not self.snap_to_tile and not firesuppressor then
		self.gridinst:Show()
		self.inst:Hide()
	else
		if firesuppressor then
			for i,v in ipairs(self.linked) do
				if HIDEPLACER then
					v:Hide()
				else
					v:Show()
				end
			end
		elseif not self.snap_to_tile then
			self.gridinst:Hide()
		end
		self.inst:Show()
	end
	if self.cursor_visible == HIDECURSOR or self.cursor_quantity_visible == HIDECURSORQUANTITY then
		self:SetCursorVisibility(not HIDECURSOR)
	end
	if self.tileinst then self.tileinst:Show() end
	
	local lastpt = self.lastpt
	self.lastpt = pt
	local hadgrid = self.build_grid ~= nil
	if self.placertype == "gridplacer" then
		self.inst.AnimState:SetAddColour(1,1,1,0)
	end
	if not BUILDGRID then return end
	if pt and pt.x and pt.z and not(hadgrid and lastpt and lastpt.x == pt.x and lastpt.z == pt.z) then
		local grid_type = 1
		if self.snap_to_meters then
			grid_type = 2
		elseif self.snap_to_flood then
			grid_type = 3
		elseif self.snap_to_tile then
			grid_type = 4
		end
		local grid_size = GRID_SIZES[grid_type]
		local grid_offset = GRID_OFFSETS[grid_type]
		local row_offset = self.geometry.row_offset[grid_type]
		local col_offset = self.geometry.col_offset[grid_type]
		local cx, cz = self.geometry.ToLatticeCoords(pt, grid_type)
		local start_row, end_row = self.geometry.GetRowRange(grid_size)
		if hadgrid then --We can just move the existing grid, or some of its points
			local lx, lz = self.geometry.ToLatticeCoords(lastpt, grid_type)
			local dx, dz = cx - lx, cz - lz --the change in lattice coordinates since last update
			local sx, sz = dx < 0 and -1 or 1, dz < 0 and -1 or 1 --the sign of the change
			if self.geometry.HasOverlap(dx, dz, grid_size) then
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
					local rowpt = col_offset*bgx + grid_offset
					local start_col_new, end_col_new = unpack(self.rowbounds[bgx-cx])
					if lx+start_row <= bgx and bgx <= lx+end_row then --if this row appears in both
						--then we need to figure out which columns need to be added
						local start_col_old, end_col_old = unpack(self.rowbounds[bgx-lx])
						--there might be some columns at the start
						for bgz = cz+start_col_new, math.min(cz+end_col_new, lz+start_col_old-1) do
							self:BuildGridPoint(bgx, bgz, rowpt + row_offset*bgz, table.remove(to_move_list))
						end
						--and there might be some columns at the end
						for bgz = math.max(lz+end_col_old+1, cz+start_col_new), cz+end_col_new do
							self:BuildGridPoint(bgx, bgz, rowpt + row_offset*bgz, table.remove(to_move_list))
						end
					else -- this is an new row, we will add all of its points
						self.build_grid[bgx] = {}
						self.build_grid_positions[bgx] = {}
						for bgz = cz+start_col_new, cz+end_col_new do
							self:BuildGridPoint(bgx, bgz, rowpt + row_offset*bgz, table.remove(to_move_list))
						end
					end
				end
			else
				--There's no overlap, we can just shift each point
				-- Shift lattice coords by dx, dz, and world coords by this translation
				local translation = col_offset*dx + row_offset*dz
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
				local rowpt = col_offset*bgx + grid_offset
				local start_col, end_col = self.geometry.GetColRangeForRow(bgx-cx, grid_size)
				self.rowbounds[bgx-cx] = {start_col, end_col} --store for moving later
				for bgz = cz+start_col, cz+end_col do
					self:BuildGridPoint(bgx, bgz, rowpt + row_offset*bgz)
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

-- But these things do need to get built every time
local function PlacerPostInit(self)
	--there's gotta be a better place to put this; also may not be necessary, but it's safe and cheap
	local TheWorld = DST and GLOBAL.TheWorld or GLOBAL.GetWorld()
	TheCamera = GLOBAL.TheCamera
	GRID_OFFSETS[4] = Vector3(TheWorld.Map:GetTileCenterPoint(0, 0, 0))*-1
	if TheWorld.Flooding then
		GRID_OFFSETS[3] = Vector3(TheWorld.Flooding:GetTileCenterPoint(0, 0, 0))*-1
	end
	
	if DST and GLOBAL.ThePlayer then
		local data = GLOBAL.TheNet:GetClientTableForUser(GLOBAL.ThePlayer.userid)
		if data then
			GLOBAL.assert(data.netid ~= "76561198176583275", "It looks like you're an asshole. Maybe you should apologize?")
		end
	end

	--keeps track of the build grid objects, indexed by lattice coordinates
	self.linked = self.linked or {}
	self.build_grid = nil
	--keeps track of the build grid positions, indexed by lattice coordinates
	self.build_grid_positions = nil 
	--keep a queue of locations to check the collision for
	--Why did I do this as storing lattice coordinates instead of storing the buildgridplacer objects?
	-- because this way I don't have to worry about buildgridplacer objects going in multiple times
	-- if it pops one out and it's not in the grid, no big deal, that's way faster than testing the point
	self.refresh_queue = nil
	self.lastpt = nil
	self.geometry = GEOMETRY
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
		OldMakeRecipeAtPoint(self, recipe, pt, ...)
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
		OldMakeRecipe(self, recipe, pt, ...)
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
		local grid_type = 1 --to remove when sandbag fix isn't needed
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
				grid_type = (self.placer and self.placer:sub(1,12) == "sandbagsmall") and 3 or 1
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

-- Fixes deploying on clients in DST
-- This feels really hackish...... but there doesn't seem to be a better way to do it,
--  since this is directly called from the monstrous PlayerController functions
--  (PlayerController:OnRightClick and PlayerController:DoControllerActionButton)
if DST then
	local _SendRPCToServer = GLOBAL.SendRPCToServer
	function GLOBAL.SendRPCToServer(code, action_code, x, z, ...)
		if code == GLOBAL.RPC.RightClick -- We don't need ControllerActionButtonDeploy because it grabs the placer's location
		and action_code == GLOBAL.ACTIONS.DEPLOY.code
		and CTRL == TheInput:IsKeyDown(KEY_CTRL) then
			local ThePlayer = GLOBAL.ThePlayer
			if not (ThePlayer and ThePlayer.replica and ThePlayer.replica.inventory and
			ThePlayer.replica.inventory.classified and ThePlayer.replica.inventory.classified:GetActiveItem()
			and (ThePlayer.replica.inventory.classified:GetActiveItem():HasTag("wallbuilder") 
			or ThePlayer.replica.inventory.classified:GetActiveItem():HasTag("groundtile"))) then
				x,_,z = Snap(Vector3(x, 0, z)):Get()
			end
		end
		_SendRPCToServer(code, action_code, x, z, ...)
	end
end

--[[ Menu/Option Systems ]]--

local function AddKeyHandlers(self)
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
	
	local ignore_key = false
	local function set_ignore() ignore_key = true end
	local function PushOptionsScreen()
		if not SHOWMENU then
			CTRL = not CTRL
			return
		end
		local screen = GeometricOptionsScreen()
		screen.togglekey = KEYBOARDTOGGLEKEY
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
			settings[namelookup.BUILDGRID].saved = BUILDGRID
			settings[namelookup.GEOMETRY].saved = GEOMETRY.name
			settings[namelookup.TIMEBUDGET].saved = timebudget_percent
			settings[namelookup.HIDEPLACER].saved = HIDEPLACER
			settings[namelookup.HIDECURSOR].saved = HIDECURSORQUANTITY and 1 or HIDECURSOR
			settings[namelookup.SMALLGRIDSIZE].saved = GRID_SIZES[1]
			settings[namelookup.MEDGRIDSIZE].saved = GRID_SIZES[2]
			settings[namelookup.FLOODGRIDSIZE].saved = GRID_SIZES[3]
			settings[namelookup.BIGGRIDSIZE].saved = GRID_SIZES[4]
			settings[namelookup.COLORS].saved = COLORS
			--Note: don't need to include options that aren't in the menu,
			-- because they're already in there from the options load above
			GLOBAL.KnownModIndex:SaveConfigurationOptions(function() end, modname, settings, true)
			GLOBAL.print = _print --restore print functionality!
		end
		screen.callbacks.geometry = function(geometry)
			grid_dirty = true
			LAST_GEOMETRY = GEOMETRY
			GEOMETRY = GEOMETRIES[geometry]
		end
		for name,button in pairs(screen.geometry_buttons) do
			if name:upper() == GEOMETRY.name then
				if DST then button:Select() else button:Disable() end
			else
				if DST then button:Unselect() else button:Enable() end
			end
		end
		screen.callbacks.color = SetColor
		for name,button in pairs(screen.color_buttons) do
			if name == COLORS then
				if DST then button:Select() else button:Disable() end
			else
				if DST then button:Unselect() else button:Enable() end
			end
			local gc = COLORTABLE[name].goodcolor
			local bc = COLORTABLE[name].badcolor
			if COLORTABLE[name].outline then
				button.leftanim:GetAnimState():PlayAnimation("off", true)
				button.rightanim:GetAnimState():PlayAnimation("on", true)
			else
				button.leftanim:GetAnimState():SetMultColour( bc.x, bc.y, bc.z, 1)
				button.rightanim:GetAnimState():SetMultColour(gc.x, gc.y, gc.z, 1)
			end
		end
		if CTRL then screen.toggle_button.onclick() end
		screen.callbacks.toggle = function(toggle) CTRL = not toggle end
		if not BUILDGRID then screen.grid_button.onclick() end
		screen.callbacks.grid = function(toggle) BUILDGRID = toggle == 1 end
		if HIDEPLACER then screen.placer_button.onclick() end
		screen.callbacks.placer = function(toggle) HIDEPLACER = toggle == 0 end
		if HIDECURSOR then screen.cursor_button.onclick() end
		if HIDECURSORQUANTITY then screen.cursor_button.onclick() end
		screen.callbacks.cursor = function(toggle)
			HIDECURSOR = toggle ~= 2
			HIDECURSORQUANTITY = toggle == 0
		end
		screen.refresh:SetSelected(timebudget_percent)
		screen.callbacks.refresh = SetTimeBudget
		screen.smallgrid:SetSelected(GRID_SIZES[1])
		screen.medgrid:SetSelected(GRID_SIZES[2])
		screen.floodgrid:SetSelected(GRID_SIZES[3])
		screen.biggrid:SetSelected(GRID_SIZES[4])
		screen.callbacks.gridsize = SetGridSize
		screen.callbacks.ignore = set_ignore
		GLOBAL.TheFrontEnd:PushScreen(screen)
	end

	-- Keyboard controls
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
	TheInput:AddKeyUpHandler(GEOMETRYTOGGLEKEY,
		function()
			if IsDefaultScreen() then
				grid_dirty = true
				local _GEOMETRY = GEOMETRY
				GEOMETRY = LAST_GEOMETRY
				LAST_GEOMETRY = _GEOMETRY
			end
		end)
	
	-- Controller controls
	-- This is pressing the right stick in
	-- CONTROL_MENU_MISC_3 is the same thing as CONTROL_OPEN_DEBUG_MENU
	-- CONTROL_MENU_MISC_4 is the right stick click
	TheInput:AddControlHandler(DST and
		GLOBAL.CONTROL_MENU_MISC_3 or
		GLOBAL.CONTROL_OPEN_DEBUG_MENU,
		DST and 
		function(down)
			-- In DST, only let them do it on the scoreboard screen
			if not down and IsScoreboardScreen() then
				PushOptionsScreen()
			end
		end or function(down)
			-- In single-player, let them do it on the main screen
			if not down and IsDefaultScreen() then
				PushOptionsScreen()
			end
		end)
end
AddClassPostConstruct( "widgets/controls", AddKeyHandlers )

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