local Screen = require "widgets/screen"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local Spinner = require "widgets/spinner"

local GeometricOptionsScreen = Class(Screen, function(self, colorname_vectors, outlined_anims)
	Screen._ctor(self, "GeometricOptionsScreen")

	self.active = true
	SetPause(true,"pause")
	
	self.togglekey = "B"
	self.togglekey = self.togglekey:lower():byte()
	
	-- make it so that all callbacks are an empty function by default
	-- the modmain will set up the callbacks to manipulate modmain options
	local blank_function = function() end
	local blank_function_table = {__index = function() return blank_function end}
	self.callbacks = {}
	setmetatable(self.callbacks, blank_function_table)
	
	--darken everything behind the dialog
    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
	self.black:SetTint(0,0,0,.5)	

	self.proot = self:AddChild(Widget("ROOT"))
    self.proot:SetVAnchor(ANCHOR_MIDDLE)
    self.proot:SetHAnchor(ANCHOR_MIDDLE)
    self.proot:SetPosition(0,0,0)
    self.proot:SetScaleMode(SCALEMODE_PROPORTIONAL)

	--throw up the background
	local close_button = {{text = STRINGS.UI.CONTROLSSCREEN.CLOSE, cb = function() self:Close() end}}
	self.bg = self.proot:AddChild(TEMPLATES.RectangleWindow(619, 359, "Geometric Placement Options", close_button))
	self.bg.title:SetPosition(0, -70)

	--subtitles
    self.subtitle_geometry = self.proot:AddChild(Text(CHATFONT, 25))
    self.subtitle_geometry:SetPosition(-205, 80, 0)
    self.subtitle_geometry:SetString("Geometry")
    self.subtitle_geometry:SetColour(UICOLOURS.GOLD)
	
    self.subtitle_geometry1 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_geometry1:SetPosition(-250, 37, 0)
    self.subtitle_geometry1:SetString("Axis\nAligned")
    self.subtitle_geometry1:SetColour(UICOLOURS.GOLD)
	
    self.subtitle_geometry2 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_geometry2:SetPosition(-160, 37, 0)
    self.subtitle_geometry2:SetString("Default\nCamera")
    self.subtitle_geometry2:SetColour(UICOLOURS.GOLD)
	
    self.subtitle_color = self.proot:AddChild(Text(CHATFONT, 25))
    self.subtitle_color:SetPosition(0, 80, 0)
    self.subtitle_color:SetString("Colors")
    self.subtitle_color:SetColour(UICOLOURS.GOLD)

    self.subtitle_color_good = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_color_good:SetPosition(5, 40, 0)
    self.subtitle_color_good:SetString("Open")
    self.subtitle_color_good:SetColour(UICOLOURS.GOLD)
	
    self.subtitle_color_bad = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_color_bad:SetPosition(60, 40, 0)
    self.subtitle_color_bad:SetString("Blocked")
    self.subtitle_color_bad:SetColour(UICOLOURS.GOLD)

    self.subtitle_misc = self.proot:AddChild(Text(CHATFONT, 25))
    self.subtitle_misc:SetPosition(205, 80, 0)
    self.subtitle_misc:SetString("Other")
    self.subtitle_misc:SetColour(UICOLOURS.GOLD)

    self.subtitle_gridsize = self.proot:AddChild(Text(CHATFONT, 22))
    self.subtitle_gridsize:SetPosition(205, -105, 0)
    self.subtitle_gridsize:SetString("Grid Sizes")
    self.subtitle_gridsize:SetColour(UICOLOURS.GOLD)

    self.subtitle_gridsize1 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_gridsize1:SetPosition(125, -125, 0)
    self.subtitle_gridsize1:SetString("Fine")
    self.subtitle_gridsize1:SetColour(UICOLOURS.GOLD)

    self.subtitle_gridsize2 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_gridsize2:SetPosition(178, -125, 0)
    self.subtitle_gridsize2:SetString("Wall")
    self.subtitle_gridsize2:SetColour(UICOLOURS.GOLD)

    self.subtitle_gridsize3 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_gridsize3:SetPosition(231, -125, 0)
    self.subtitle_gridsize3:SetString("Sandbag")
    self.subtitle_gridsize3:SetColour(UICOLOURS.GOLD)

    self.subtitle_gridsize4 = self.proot:AddChild(Text(CHATFONT, 18))
    self.subtitle_gridsize4:SetPosition(284, -125, 0)
    self.subtitle_gridsize4:SetString("Turf")
    self.subtitle_gridsize4:SetColour(UICOLOURS.GOLD)

	-- dividers
	-- local r, g, b = unpack(UICOLOURS.GOLD)
	
	self.vertical_line1 = self.proot:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
	self.vertical_line1:SetRotation(90)
	self.vertical_line1:SetScale(1, .32)
	self.vertical_line1:SetPosition(-100, -40)
	-- self.vertical_line1:SetTint(r,g,b,1)

	self.vertical_line2 = self.proot:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
	self.vertical_line2:SetRotation(90)
	self.vertical_line2:SetScale(1, .32)
	self.vertical_line2:SetPosition(100, -40)
	-- self.vertical_line2:SetTint(r,g,b,1)

	self.horizontal_line = self.proot:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
	self.horizontal_line:SetScale(.8, 1)
	self.horizontal_line:SetPosition(0, 60)
	-- self.horizontal_line:SetTint(r,g,b,1)
	
	--[[  Color Spinners   ]]--
	
	local placer_colors = {"green", "blue", "red", "white", "black"}
	local colors = {}
	for _,color in ipairs(placer_colors) do
		table.insert(colors, color)
	end
	table.insert(placer_colors, "hidden")
	table.insert(colors, "hidden")
	
	-- Copy-pasted from modinfo for ease of use
	local placer_color_options = {
		{description = "Green", data = "green", hover = "The normal green  the game uses."},
		{description = "Blue", data = "blue", hover = "Blue, helpful if you're red/green colorblind."},
		{description = "Red", data = "red", hover = "The normal red the game uses."},
		{description = "White", data = "white", hover = "A bright white, for better visibility."},
		{description = "Black", data = "black", hover = "Black, to contrast with the brighter colors."},
	}
	local color_options = {}
	for i,option in ipairs(placer_color_options) do
		color_options[i] = option
	end
	color_options[#color_options+1] = {description = "Outlined White", data = "whiteoutline", hover = "White with a black outline, for the best visibility."}
	color_options[#color_options+1] = {description = "Outlined Black", data = "blackoutline", hover = "Black with a white outline, for the best visibility."}
	local hidden_option = {description = "Hidden", data = "hidden", hover = "Hide it entirely, because you didn't need to see it anyway, right?"}
	placer_color_options[#placer_color_options+1] = hidden_option
	color_options[#color_options+1] = hidden_option
	-- end modinfo copypaste
	
	hidden_option.text = "hide"
	
	self.color_spinners = {}
	local _Spinner_SetSelectedIndex = Spinner.SetSelectedIndex
	local color_type_descriptions = {"Fine/Wall:", "", "Turf:", "", "Placer:", "", "Nearest Tile:"}
	for i, color_type in pairs({"GOOD", "BAD", "GOODTILE", "BADTILE", "GOODPLACER", "BADPLACER", "NEARTILE"}) do
		local neartile = color_type == "NEARTILE"
		local color_spinner = self.proot:AddChild(TEMPLATES.LabelSpinner(
			color_type_descriptions[i],
			color_type:match("PLACER$") and placer_color_options or color_options,
			neartile and 100 or (i%2)*70, -- label width
			60, -- spinner width
			25, -- height
			0,  -- spacing between label and spinner
			nil, 18, -- font and size
			0, -- horizontal offset
			function(selected, old) self.callbacks.color(color_type, selected) end
		))
		local pos_x = i%2 == 1 and -30 or 60
		if neartile then pos_x = -17 end
		color_spinner:SetPosition(pos_x, 55 - 45*math.ceil(i/2))
		color_spinner = color_spinner.spinner
		self.color_spinners[color_type] = color_spinner
		color_spinner.anim = color_spinner:AddChild(UIAnim())
		color_spinner.anim:GetAnimState():SetLightOverride(1)
		color_spinner.anim:SetRotation(45)
		color_spinner.anim:SetScale(.7)
		color_spinner.anim:SetClickable(false)
		function color_spinner:SetSelectedIndex(idx)
			self.updating = true
			self.anim:GetAnimState():SetBuild("buildgridplacer")
			self.anim:GetAnimState():SetBank("buildgridplacer")
			local color = self.options[idx].data
			if color == "hidden" then
				self.anim:Hide()
			else
				self.anim:Show()
				if colorname_vectors[color] then
					self.anim:GetAnimState():PlayAnimation("idle")
					color = colorname_vectors[color]
					self.anim:GetAnimState():SetMultColour(color.x, color.y, color.z, 1)
				else
					self.anim:GetAnimState():PlayAnimation(outlined_anims[color])
					self.anim:GetAnimState():SetMultColour(1, 1, 1, 1)
				end
			end
			_Spinner_SetSelectedIndex(self, idx)
		end
	end
	
	--[[ Geometry Buttons ]]--
	
	self.geometry_buttons = {}
	local geometries = {
		{name="Square", hover="Aligned with the world's X-Z coordinate system.\nWalls and turf always use this geometry."},
		{name="Diamond", hover="Square rotated 45\176.\nLooks square from the default camera."},
		{name="X Hexagon", hover="Hexagon with a flat top parallel to the X axis."},
		{name="Flat Hexagon", hover="Hexagon with a flat top from the default camera."},
		{name="Z Hexagon", hover="Hexagon with a flat top parallel to the Z axis."},
		{name="Pointy Hexagon", hover="Hexagon with a pointy top from the default camera."},
	}
	for i,geometry in ipairs(geometries) do
		local geometry_option = geometry.name:gsub(" ", "_"):upper()
		local geometry_filename = geometry_option:lower() .. "_geometry"
		local button = self.proot:AddChild(TEMPLATES.IconButton(
			"images/"..geometry_filename..".xml",
			geometry_filename..".tex",
			geometry.hover, false, false,
			function()
				for geometry_name,geometry_button in pairs(self.geometry_buttons) do
					if geometry_name:upper() == geometry_option then
						geometry_button:Select()
					else
						geometry_button:Unselect()
					end
				end
				self.callbacks.geometry(geometry_option)
			end,
			{offset_y = geometry.hover:match("\n") and 120 or 90}))
		button.icon:SetScale(.7)
		self.geometry_buttons[geometry_option:lower()] = button
		button:SetPosition(((i+1)%2)*90-250, -10-math.floor((i-1)/2)*60)
	end
	
	--[[   Misc Buttons   ]]--
	
	local toggle_strings = {[true] = "Turn the mod off, except when holding control.",
							[false]= "Turn the mod on, except when holding control."}
	local toggle_state = true
	self.toggle_button = self.proot:AddChild(TEMPLATES.IconButton(
		"images/frontend.xml",
		"button_square_highlight.tex",
		toggle_strings[true], false, false,
		function()
			toggle_state = not toggle_state
			self.toggle_button.text:SetString(toggle_state and "On" or "Off")
			self.toggle_button.image:SetTint(toggle_state and .5 or 1, toggle_state and 1 or .5, .5, 1)
			self.toggle_button.hovertext:SetString(toggle_strings[toggle_state])
			self.callbacks.toggle(toggle_state)
		end,
		{offset_y=90}))
	self.toggle_button.icon:Hide()
	self.toggle_button:SetTextSize(30)
	self.toggle_button:SetText("On")
	self.toggle_button.image:SetTint(.5, 1, .5, 1)
	self.toggle_button:SetPosition(240, 135)
	
	local toggle_buttons = {
		{name="grid", hover="Whether to show the build grid."},
		{name="cursor", hover="Whether to show the item on the cursor,\njust the number, or nothing.", toggle=2, atlases={"", "_num", ""}},
	}
	local function GetAtlasAndTexture(name, atlases, toggle_state)
		local suffix = atlases ~= nil and atlases[toggle_state+1] or ""
		return "images/"..name.."_toggle_icon"..suffix..".xml", name.."_toggle_icon"..suffix..".tex"
	end
	for i,button in ipairs(toggle_buttons) do
		local btn = button.name.."_button"
		button.toggle = button.toggle or 1
		button.toggle_states = button.toggle + 1
		local initial_atlas, initial_texture = GetAtlasAndTexture(button.name, button.atlases, button.toggle)
		self[btn] = self.proot:AddChild(TEMPLATES.IconButton(initial_atlas, initial_texture, button.hover, false, false,
			function()
				button.toggle = (button.toggle - 1)%button.toggle_states
				if button.toggle == button.toggle_states-1 then
					self[btn].xout:Hide()
					self[btn].image:SetTint(.5, 1, .5, 1)
				elseif button.toggle == 0 then
					if not button.no_x then
						self[btn].xout:Show()
					end
					self[btn].image:SetTint(1, .5, .5, 1)
				else --only used by cursor button
					self[btn].xout:Hide()
					self[btn].image:SetTint(1, 1, .5, 1)
				end
				local atlas, texture = GetAtlasAndTexture(button.name, button.atlases, button.toggle)
				self[btn].icon:SetTexture(atlas, texture)
				self.callbacks[button.name](button.toggle)
			end,
			{offset_y = button.hover:match("\n") and 120 or 90}))
		self[btn].icon:SetScale(.7)
		self[btn]:SetPosition(100 + 75*i, 10)
		self[btn].image:SetTint(.5, 1, .5, 1)
		self[btn].xout = self[btn]:AddChild(Image("images/toggle_x_out.xml", "toggle_x_out.tex"))
		self[btn].xout:SetScale(.8)
		self[btn].xout:Hide()
	end
	
	local percent_options = {}
	for i = 1, 10 do percent_options[i] = {text = i.."0%", data = i/10} end
	percent_options[11] = {text = "Unlimited", data = false}
	self.refresh = self.proot:AddChild(TEMPLATES.LabelSpinner(
			"Refresh Speed:",
			percent_options,
			100, -- label width
			110, -- spinner width
			30, -- height
			0,  -- spacing between label and spinner
			nil, 18, -- font and size
			0, -- horizontal offset
			function(selected, old) self.callbacks.refresh(selected) end
		))
	self.refresh:SetPosition(205, -60)
	self.refresh = self.refresh.spinner
	-- a little switcharoo to get the right parenting to happen in SetHoverText
	local refreshtext = self.refresh.text
	self.refresh.text = nil
	self.refresh:SetHoverText(
		"How quickly to refresh the grid.\nTurning it up will make it more responsive, but it may cause lag.",
		{font = NEWFONT_OUTLINE, size = 22, offset_x = -4, offset_y = 120, colour = {1,1,1,1}})
	self.refresh.text = refreshtext

	local gridsize_y = -145
	local smallgridsizeoptions = {}
	for i=0,10 do smallgridsizeoptions[i+1] = {text=""..(i*2).."", data=i*2} end
	self.smallgrid = self.proot:AddChild(TEMPLATES.StandardSpinner(smallgridsizeoptions, 50, 20, nil, 18, function(selected, old) self.callbacks.gridsize(1, selected) end))
	self.smallgrid:SetPosition(125, gridsize_y)
	local medgridsizeoptions = {}
	for i=0,10 do medgridsizeoptions[i+1] = {text=""..(i).."", data=i} end
	self.medgrid = self.proot:AddChild(TEMPLATES.StandardSpinner(medgridsizeoptions, 50, 20, nil, 18, function(selected, old) self.callbacks.gridsize(2, selected) end))
	self.medgrid:SetPosition(178, gridsize_y)
	local floodgridsizeoptions = {}
	for i=0,10 do floodgridsizeoptions[i+1] = {text=""..(i).."", data=i} end
	self.floodgrid = self.proot:AddChild(TEMPLATES.StandardSpinner(floodgridsizeoptions, 50, 20, nil, 18, function(selected, old) self.callbacks.gridsize(3, selected) end))
	self.floodgrid:SetPosition(231, gridsize_y)
	local biggridsizeoptions = {}
	for i=0,5 do biggridsizeoptions[i+1] = {text=""..(i).."", data=i} end
	self.biggrid = self.proot:AddChild(TEMPLATES.StandardSpinner(biggridsizeoptions, 50, 20, nil, 18, function(selected, old) self.callbacks.gridsize(4, selected) end))
	self.biggrid:SetPosition(284, gridsize_y)


	--[[ Button Focus Hookups ]]--
	
    if TheInput:ControllerAttached() then
		self.last_focus = self.toggle_button
		self.default_focus = self.toggle_button
		self.current_focus = self.toggle_button
		self.toggle_button:SetFocus()
    end
	-- Set up a table to know what section each button is in
	self.section_lookup = {
		[self.toggle_button] = 1,
		[self.refresh] = 4,
		[self.smallgrid] = 4,
		[self.medgrid] = 4,
		[self.floodgrid] = 4,
		[self.biggrid] = 4,
	}
	for _,button in pairs(self.geometry_buttons) do
		self.section_lookup[button] = 2
	end
	for _,spinner in pairs(self.color_spinners) do
		self.section_lookup[spinner] = 3
	end
	for _,button in pairs(toggle_buttons) do
		self.section_lookup[self[button.name.."_button"]] = 4
	end
	-- Set up a table to know what button to focus when switching sections
	self.section_mainbuttons = {self.toggle_button, self.geometry_buttons.square, self.color_spinners.GOOD, self.grid_button}

	for button,section in pairs(self.section_lookup) do
		local OldSetFocus = button.SetFocus
		button.SetFocus = function(button)
			self.current_focus = button or self.current_focus
			OldSetFocus(button)
		end
	end

	self.toggle_button:SetFocusChangeDir(MOVE_DOWN, self.cursor_button)
	self.toggle_button:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.square)
	self.toggle_button:SetFocusChangeDir(MOVE_RIGHT, self.cursor_button)

	--Within geometry
	self.geometry_buttons.square:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.geometry_buttons.square:SetFocusChangeDir(MOVE_RIGHT, self.geometry_buttons.diamond)
	self.geometry_buttons.square:SetFocusChangeDir(MOVE_DOWN, self.geometry_buttons.x_hexagon)
	self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.square)
	self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_DOWN, self.geometry_buttons.flat_hexagon)
	self.geometry_buttons.x_hexagon:SetFocusChangeDir(MOVE_UP, self.geometry_buttons.square)
	self.geometry_buttons.x_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.geometry_buttons.flat_hexagon)
	self.geometry_buttons.x_hexagon:SetFocusChangeDir(MOVE_DOWN, self.geometry_buttons.z_hexagon)
	self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_UP, self.geometry_buttons.diamond)
	self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.x_hexagon)
	self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_DOWN, self.geometry_buttons.pointy_hexagon)
	self.geometry_buttons.z_hexagon:SetFocusChangeDir(MOVE_UP, self.geometry_buttons.x_hexagon)
	self.geometry_buttons.z_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.geometry_buttons.pointy_hexagon)
	self.geometry_buttons.pointy_hexagon:SetFocusChangeDir(MOVE_UP, self.geometry_buttons.flat_hexagon)
	self.geometry_buttons.pointy_hexagon:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.z_hexagon)
	
	--Geometry to colors
	self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.GOOD)
	self.color_spinners.GOOD:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
	self.color_spinners.GOODTILE:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
	self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.GOODPLACER)
	self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.flat_hexagon)
	self.geometry_buttons.pointy_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.NEARTILE)
	self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.pointy_hexagon)
	
	--Within colors
	self.color_spinners.GOOD:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.color_spinners.GOOD:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.BAD)
	self.color_spinners.GOOD:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.GOODTILE)
	self.color_spinners.BAD:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.color_spinners.BAD:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.GOOD)
	self.color_spinners.BAD:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.BADTILE)
	self.color_spinners.GOODTILE:SetFocusChangeDir(MOVE_UP, self.color_spinners.GOOD)
	self.color_spinners.GOODTILE:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.BADTILE)
	self.color_spinners.GOODTILE:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.GOODPLACER)
	self.color_spinners.BADTILE:SetFocusChangeDir(MOVE_UP, self.color_spinners.BAD)
	self.color_spinners.BADTILE:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.GOODTILE)
	self.color_spinners.BADTILE:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.BADPLACER)
	self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_UP, self.color_spinners.GOODTILE)
	self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.BADPLACER)
	self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.NEARTILE)
	self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_UP, self.color_spinners.BADTILE)
	self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.GOODPLACER)
	self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.NEARTILE)
	self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_UP, self.color_spinners.GOODPLACER)
	
	--Colors to misc
	self.color_spinners.BAD:SetFocusChangeDir(MOVE_RIGHT, self.grid_button)
	self.grid_button:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BAD)
	self.color_spinners.BADTILE:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
	self.refresh:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BADTILE)
	self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
	self.refresh:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BADPLACER)
	self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_RIGHT, self.smallgrid)
	self.smallgrid:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.NEARTILE)
	
	--Within misc
	self.grid_button:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.grid_button:SetFocusChangeDir(MOVE_RIGHT, self.cursor_button)
	self.grid_button:SetFocusChangeDir(MOVE_DOWN, self.refresh)
	self.cursor_button:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.cursor_button:SetFocusChangeDir(MOVE_LEFT, self.grid_button)
	self.cursor_button:SetFocusChangeDir(MOVE_DOWN, self.refresh)
	self.refresh:SetFocusChangeDir(MOVE_UP, self.cursor_button)
	self.refresh:SetFocusChangeDir(MOVE_DOWN, self.biggrid)
	self.smallgrid:SetFocusChangeDir(MOVE_UP, self.refresh)
	self.smallgrid:SetFocusChangeDir(MOVE_RIGHT, self.medgrid)
	self.medgrid:SetFocusChangeDir(MOVE_UP, self.refresh)
	self.medgrid:SetFocusChangeDir(MOVE_LEFT, self.smallgrid)
	self.medgrid:SetFocusChangeDir(MOVE_RIGHT, self.floodgrid)
	self.floodgrid:SetFocusChangeDir(MOVE_UP, self.refresh)
	self.floodgrid:SetFocusChangeDir(MOVE_LEFT, self.medgrid)
	self.floodgrid:SetFocusChangeDir(MOVE_RIGHT, self.biggrid)
	self.biggrid:SetFocusChangeDir(MOVE_UP, self.refresh)
	self.biggrid:SetFocusChangeDir(MOVE_LEFT, self.floodgrid)
	
	TheInputProxy:SetCursorVisible(true)
	self.default_focus = self.menu
end)

function GeometricOptionsScreen:OnFocusMove(dir, down)
	if not self.focus then return end
	if not self.section_lookup[TheFrontEnd:GetFocusWidget()] then
		--None of the widgets we want to be focusable are focused, the mouse probably stole it
		self.toggle_button:SetFocus()
		return true
	end
	return GeometricOptionsScreen._base.OnFocusMove(self, dir, down)
end

function GeometricOptionsScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
	table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_3) .. " " .. STRINGS.UI.HELP.BACK)
    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_OPEN_CRAFTING).."/"..TheInput:GetLocalizedControl(controller_id, CONTROL_OPEN_INVENTORY).. " Change Section")
	
	return table.concat(t, "  ")
end

function GeometricOptionsScreen:OnRawKey(key, down)
	if GeometricOptionsScreen._base.OnRawKey(self, key, down) then return true end
	
	if self.IsOptionsMenuKey(key) and not down then	
		self.callbacks.ignore()
		self:Close()
		return true
	end
end

function GeometricOptionsScreen:OnControl(control, down)
	if GeometricOptionsScreen._base.OnControl(self,control, down) then return true end
	
	if down then return end
	if control == CONTROL_PAUSE or control == CONTROL_CANCEL or control == CONTROL_MENU_MISC_3 then
		self:Close()
		return true
	elseif TheInput:ControllerAttached() and (control == CONTROL_OPEN_CRAFTING or control == CONTROL_OPEN_INVENTORY) then
		local section = self.section_lookup[self.current_focus]
		if section then
			section = section + (control == CONTROL_OPEN_CRAFTING and -1 or 1)
		else
			section = 1
		end
		local focus = self.section_mainbuttons[((section-1)%#self.section_mainbuttons)+1]
		focus:SetFocus()
		return true
	end
end

function GeometricOptionsScreen:Close()
	self.active = false
	self.callbacks.save()
	TheFrontEnd:PopScreen() 
	SetPause(false)
	TheWorld:PushEvent("continuefrompause")
	TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
end

function GeometricOptionsScreen:OnUpdate(dt)
	if self.active then
		SetPause(true)
	end
end

function GeometricOptionsScreen:OnBecomeActive()
	GeometricOptionsScreen._base.OnBecomeActive(self)
	-- Hide the topfade, it'll obscure the pause menu if paused during fade. Fade-out will re-enable it
	TheFrontEnd:HideTopFade()
end

return GeometricOptionsScreen
