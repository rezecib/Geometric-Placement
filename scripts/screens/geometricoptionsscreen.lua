local Screen = require "widgets/screen"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local Spinner = require "widgets/spinner"

local function AddHoverText(widget, params, labelText)
	params = params or {}
	
	-- Widget class defaults these on its own in SetHoverText
	-- params.font = params.font or NEWFONT_OUTLINE
	-- params.size = params.size or 22
	
	params.offset_x = params.offset_x or 2
	-- add an extra 30 if it's got two lines of text
	params.offset_y = params.offset_y or 75
	local sign = params.offset_y < 0 and -1 or 1
	params.offset_y = params.offset_y + sign*(labelText:match("\n") and 30 or 0)
	params.colour = params.colour or UICOLOURS.WHITE
	
	-- switcharoo with the text to make sure the hover parenting works correctly (bypassing a dev workaround for labels)
	local text = widget.text
	widget.text = nil
	widget:SetHoverText(labelText, params)
	widget.text = text
end

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
	
	local function colorize(anim, color)
		if color == "hidden" then
			anim:Hide()
		else
			anim:Show()
			if colorname_vectors[color] then
				anim:GetAnimState():PlayAnimation("idle")
				color = colorname_vectors[color]
				anim:GetAnimState():SetMultColour(color.x, color.y, color.z, 1)
			else
				anim:GetAnimState():PlayAnimation(outlined_anims[color])
				anim:GetAnimState():SetMultColour(1, 1, 1, 1)
			end
		end
	end
		
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
	
	local function make_gridpoint_anim()
		local anim = UIAnim()
		anim:GetAnimState():SetBuild("buildgridplacer")
		anim:GetAnimState():SetBank("buildgridplacer")
		anim:GetAnimState():PlayAnimation("idle", true)
		anim:GetAnimState():SetLightOverride(1)
		anim:SetRotation(45)
		anim:SetClickable(false)
		return anim
	end
	
	self.color_spinners = {}
	local _Spinner_SetSelectedIndex = Spinner.SetSelectedIndex
	local color_type_descriptions = {"Fine/Wall:", "", "Turf:", "", "Placer:", "", "Nearest Tile:"}
	local color_type_hovers = {
		_GOOD = "not blocked and you can place there.",
		_BAD = "blocked and you can't place there.",
		[""] = "The color for the grid points,\nwhen they are ",
		TILE = "The color for tiles of turf,\nwhen they are ",
		PLACER = "The color for the shadow copy of the object,\nwhen it is ",
		NEARTILE = "The color for the outline of the nearest turf tile.",
	}
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
			function(selected, old)
				self.callbacks.color(color_type, selected)
				self.callbacks.color_update()
			end
		))
		local pos_x = i%2 == 1 and -30 or 60
		local pos_y = 55 - 45*math.ceil(i/2)
		if neartile then 
			pos_x = -17
			pos_y = -150
		end
		color_spinner:SetPosition(pos_x, pos_y)
		color_spinner.spinner.label = color_spinner.label
		color_spinner = color_spinner.spinner
		local hover = color_type_hovers[color_type]
		if not hover then
			local prefix = color_type:match("^GOOD") or color_type:match("^BAD")
			hover = color_type_hovers[color_type:sub(prefix:len()+1)] .. color_type_hovers["_"..prefix]
		end
		AddHoverText(color_spinner, {offset_x = -4, offset_y = -50}, hover)
		self.color_spinners[color_type] = color_spinner
		color_spinner.anim = color_spinner:AddChild(make_gridpoint_anim())
		color_spinner.anim:SetScale(.7)
		function color_spinner:SetSelectedIndex(idx)
			self.updating = true
			local color = self.options[idx].data
			colorize(self.anim, color)
			_Spinner_SetSelectedIndex(self, idx)
		end
	end
	
	--[[ Color Preset Buttons ]]--
	
	self.color_buttons = {
		redgreen = { text = "Red/Green", hover = "The standard red and green that the normal game uses.", goodcolor = "green", badcolor = "red"},
		redblue = { text = "Red/Blue", hover = "Substitutes blue in place of the green,\nhelpful for the red/green colorblind.", goodcolor = "blue", badcolor = "red"},
		blackwhite = { text = "Black/White", hover = "Black for blocked and white for placeable,\nusually more visible.", goodcolor = "white", badcolor = "black"},
		blackwhiteoutline = { text = "Outlined", hover = "Black and white, but with outlines for improved visibility.", goodcolor = "whiteoutline", badcolor = "blackoutline"},
		custom = { text = "Customize", hover = "Customize each type of point\nto have its own color or be hidden."},
		preset = { text = "Presets", hover = "Switch back to the preset-picking mode,\nwhich lets you quickly select color schemes."},
	}
    local button_y = 30
	for i, color_preset in pairs({"redgreen", "redblue", "blackwhite", "blackwhiteoutline", "custom", "preset"}) do
		local button_params = self.color_buttons[color_preset]
		local button = self.proot:AddChild(TEMPLATES.StandardButton(
			function()
				if color_preset == "custom" or color_preset == "preset" then
					self:SetColorMode(color_preset)
				else
					for color_name,color_button in pairs(self.color_buttons) do
						if color_name == color_preset then
							color_button:Select()
						else
							color_button:Unselect()
						end
					end
					self.callbacks.color("GOOD", button_params.goodcolor)
					self.callbacks.color("BAD", button_params.badcolor)
					self.callbacks.color("GOODTILE", button_params.goodcolor)
					self.callbacks.color("BADTILE", button_params.badcolor)
					self.callbacks.color("GOODPLACER", button_params.goodcolor)
					self.callbacks.color("BADPLACER", button_params.badcolor)
					self.callbacks.color_update()
				end
			end,
			button_params.text,
			{240, 50}))
		button:SetPosition(0, button_y)
		button:SetScale(.7)
		AddHoverText(button, {offset_y = 55}, button_params.hover)
		if color_preset ~= "custom" and color_preset ~= "preset" then
			button.leftanim = button:AddChild(make_gridpoint_anim())
			button.leftanim:SetPosition(-90, 0)
			colorize(button.leftanim, button_params.badcolor)
			button.rightanim = button:AddChild(make_gridpoint_anim())
			button.rightanim:SetPosition(80, 0)
			colorize(button.rightanim, button_params.goodcolor)
		end
		button_y = button_y - 35
		self.color_buttons[color_preset] = button
	end
	self.color_buttons.preset:SetPosition(self.color_buttons.custom:GetPosition():Get())

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
		{name="placer", hover="Whether to show the placer.\n(The ghost version of the thing you're placing)"},
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
		self[btn]:SetPosition(75 + 75*i, 10)
		self[btn].image:SetTint(.5, 1, .5, 1)
		self[btn].xout = self[btn]:AddChild(Image("images/toggle_x_out.xml", "toggle_x_out.tex"))
		self[btn].xout:SetScale(.8)
		self[btn].xout:Hide()
	end
	self.toggle_buttons = toggle_buttons
	
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
	self.subtitle_refresh = self.refresh.label -- also needed for gross fix
	self.refresh = self.refresh.spinner
	AddHoverText(self.refresh, {offset_x = -4, offset_y = 50}, "How quickly to refresh the grid.\nTurning it up will make it more responsive, but it may cause lag.")

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
	
	-- Gross fix for terribly brittle code in "Chinese Plus" mod which tries to invasively rewrite the strings
	self.title = self.bg.title
	self.close_button = self.bg.actions.items[1]
	-- end gross fix
	
	TheInputProxy:SetCursorVisible(true)
	
	self:SetColorMode("preset")
end)

local function set_visibility(element, show)
	if show then
		element:Show()
	else
		element:Hide()
	end
end

function GeometricOptionsScreen:SetColorMode(mode)
	local show_preset = mode == "preset"
	local show_custom = mode == "custom"
	if show_preset or show_custom then
		self.colormode = mode
	else
		return
	end
	for preset, button in pairs(self.color_buttons) do
		if preset == "preset" then -- only show the preset button in custom mode, to switch back to preset mode
			set_visibility(button, show_custom)
		else
			set_visibility(button, show_preset)
		end
	end
	for colortype, spinner in pairs(self.color_spinners) do
		if colortype ~= "NEARTILE" then -- always show the nearest tile spinner
			set_visibility(spinner.label, show_custom)
			set_visibility(spinner, show_custom)
		end
	end
	set_visibility(self.subtitle_color_good, show_custom)
	set_visibility(self.subtitle_color_bad, show_custom)
	self:SetUpFocusHookups()
	if show_preset then
		self.color_buttons.custom:SetFocus()
	else
		self.color_buttons.preset:SetFocus()
	end
end

function GeometricOptionsScreen:SetUpFocusHookups()
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
	for _,button in pairs(self.color_buttons) do
		self.section_lookup[button] = 3
	end
	for _,spinner in pairs(self.color_spinners) do
		self.section_lookup[spinner] = 3
	end
	for _,button in pairs(self.toggle_buttons) do
		self.section_lookup[self[button.name.."_button"]] = 4
	end
	-- Set up a table to know what button to focus when switching sections
	local color_main = self.colormode == "preset" and self.color_buttons.redgreen or self.color_spinners.GOOD
	self.section_mainbuttons = {self.toggle_button, self.geometry_buttons.square, color_main, self.grid_button}

	for button,section in pairs(self.section_lookup) do
		button.OldSetFocus = button.OldSetFocus or button.SetFocus
		button.SetFocus = function(button)
			self.current_focus = button or self.current_focus
			button:OldSetFocus()
		end
	end

	self.toggle_button:SetFocusChangeDir(MOVE_DOWN, self.cursor_button)
	self.toggle_button:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.square)
	self.toggle_button:SetFocusChangeDir(MOVE_RIGHT, self.cursor_button)

	-- Within geometry
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
	
	if self.colormode == "preset" then
		
		-- Geometry to colors
		self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_RIGHT, self.color_buttons.redgreen)
		self.color_buttons.redgreen:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
		self.color_buttons.redblue:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
		self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.color_buttons.blackwhiteoutline)
		self.color_buttons.blackwhite:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.flat_hexagon)
		self.color_buttons.blackwhiteoutline:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.flat_hexagon)
		self.color_buttons.custom:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.pointy_hexagon)
		self.geometry_buttons.pointy_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.NEARTILE)
		self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.pointy_hexagon)
		
		--Within colors
		self.color_buttons.redgreen:SetFocusChangeDir(MOVE_UP, self.toggle_button)
		self.color_buttons.redgreen:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.redblue)
		self.color_buttons.redblue:SetFocusChangeDir(MOVE_UP, self.color_buttons.redgreen)
		self.color_buttons.redblue:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.blackwhite)
		self.color_buttons.blackwhite:SetFocusChangeDir(MOVE_UP, self.color_buttons.redblue)
		self.color_buttons.blackwhite:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.blackwhiteoutline)
		self.color_buttons.blackwhiteoutline:SetFocusChangeDir(MOVE_UP, self.color_buttons.blackwhite)
		self.color_buttons.blackwhiteoutline:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.custom)
		self.color_buttons.custom:SetFocusChangeDir(MOVE_UP, self.color_buttons.blackwhiteoutline)
		self.color_buttons.custom:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.NEARTILE)
		self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_UP, self.color_buttons.custom)
	
		--Colors to misc
		self.color_buttons.redgreen:SetFocusChangeDir(MOVE_RIGHT, self.grid_button)
		self.color_buttons.redblue:SetFocusChangeDir(MOVE_RIGHT, self.grid_button)
		self.grid_button:SetFocusChangeDir(MOVE_LEFT, self.color_buttons.redgreen)
		self.color_buttons.blackwhite:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
		self.color_buttons.blackwhiteoutline:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
		self.refresh:SetFocusChangeDir(MOVE_LEFT, self.color_buttons.blackwhite)
		self.color_buttons.custom:SetFocusChangeDir(MOVE_RIGHT, self.smallgrid)
		self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_RIGHT, self.smallgrid)
		self.smallgrid:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.NEARTILE)
		
	elseif self.colormode == "custom" then
	
		-- Geometry to colors
		self.geometry_buttons.diamond:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.GOOD)
		self.color_spinners.GOOD:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
		self.color_spinners.GOODTILE:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.diamond)
		self.geometry_buttons.flat_hexagon:SetFocusChangeDir(MOVE_RIGHT, self.color_spinners.GOODPLACER)
		self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.flat_hexagon)
		self.color_buttons.preset:SetFocusChangeDir(MOVE_LEFT, self.geometry_buttons.pointy_hexagon)
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
		self.color_spinners.GOODPLACER:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.preset)
		self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_UP, self.color_spinners.BADTILE)
		self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.GOODPLACER)
		self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_DOWN, self.color_buttons.preset)
		self.color_buttons.preset:SetFocusChangeDir(MOVE_UP, self.color_spinners.GOODPLACER)
		self.color_buttons.preset:SetFocusChangeDir(MOVE_DOWN, self.color_spinners.NEARTILE)
		self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_UP, self.color_buttons.preset)
		
		--Colors to misc
		self.color_spinners.BAD:SetFocusChangeDir(MOVE_RIGHT, self.grid_button)
		self.grid_button:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BAD)
		self.color_spinners.BADTILE:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
		self.refresh:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BADTILE)
		self.color_spinners.BADPLACER:SetFocusChangeDir(MOVE_RIGHT, self.refresh)
		self.refresh:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.BADPLACER)
		self.color_buttons.preset:SetFocusChangeDir(MOVE_RIGHT, self.smallgrid)
		self.color_spinners.NEARTILE:SetFocusChangeDir(MOVE_RIGHT, self.smallgrid)
		self.smallgrid:SetFocusChangeDir(MOVE_LEFT, self.color_spinners.NEARTILE)
	
	end
	
	--Within misc
	self.grid_button:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.grid_button:SetFocusChangeDir(MOVE_RIGHT, self.placer_button)
	self.grid_button:SetFocusChangeDir(MOVE_DOWN, self.refresh)
	self.placer_button:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.placer_button:SetFocusChangeDir(MOVE_LEFT, self.grid_button)
	self.placer_button:SetFocusChangeDir(MOVE_RIGHT, self.cursor_button)
	self.placer_button:SetFocusChangeDir(MOVE_DOWN, self.refresh)
	self.cursor_button:SetFocusChangeDir(MOVE_UP, self.toggle_button)
	self.cursor_button:SetFocusChangeDir(MOVE_LEFT, self.placer_button)
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
end

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
