--[[
This is a huge monolithic file because mods are distributed as source code,
and I want this to behave like a single "plugin" that people can add to their mods,
without introducing the possibility of people getting some of it but missing pieces.
]]

--TODO: MAJOR update hooks into optionsscreen for redux, or whatever they are currently on when you get to this...
--TODO: check controller compatibility, focus hookups for the right panel
--TODO: maybe better handling of dirty options:
--	what happens when switching mods?
--	what about making mod settings changes, then going to normal settings and changing? (currently apply is separate)
--TODO: more documentation of the API
--TODO: check more edge cases to fix bugs?

--[[ Mod Settings Member Variables ]]--

local modsettings = {}
local modcontrols = {}
local modcontrols_lookup = {}

--[[ Mod Settings API ]]--

local ModSettings = {}

local mod_icon_prefabs = {}

local function CheckToLoadIcon(modname)
	-- Written with reference to ModsScreen:LoadModInfoPrefabs
	if modsettings[modname] == nil and modcontrols[modname] == nil then
		--In order to have the mod icons on the menu, we need to load them
		local info = KnownModIndex:GetModInfo(modname)
		if info and info.icon_atlas and info.iconpath then
			local modinfoassets = {
				Asset("ATLAS", info.icon_atlas),
				Asset("IMAGE", info.iconpath),
			}
			local prefab = Prefab("MODSCREEN_"..modname, nil, modinfoassets, nil)
			if mod_icon_prefabs then -- we haven't loaded them yet
				table.insert(mod_icon_prefabs, prefab)
			else
				RegisterPrefabs(prefab)
				TheSim:LoadPrefabs({prefab.name})
			end
		end
	end
end

local function GetModConfigTable(modname, configname)
	local config_options = KnownModIndex:LoadModConfigurationOptions(modname, TheNet:GetIsClient())
	for i,v in ipairs(config_options) do
		if v.name == configname then
			return v
		end
	end
end

ModSettings.AddSetting = function(modname, configname, callback, configdata)
	if modsettings[modname] == nil then
		CheckToLoadIcon(modname)
		modsettings[modname] = {}
	end
	if configdata == nil then
		configdata = GetModConfigTable(modname, configname)
	end
	if type(configdata) == "table" then
		configdata.callback = callback
		table.insert(modsettings[modname], configdata)
	end
end

--[[
Parameters:
	modname: The name of the mod. You can just pass in the variable modname from your modmain
	control_name: The name for the control. This must be unique within your mod.
	control_desc: The description for the control; this is what will show on the mod controls screen.
	default_key: The key string or id for the default button.
		You can pass in letters (upper or lowercase, it doesn't matter),
		or one of the ids from the KEY_... variables in constants.lua.
	handler: (optional) a function to run when the key is pressed or released (depending on down)
	down: (optional) whether to run the handler when the key is pressed (true) or released (false)
	
Usage:
1) (Recommended) with handler, which will let this set up the key handler registration and switching for you:
	local function ShoutHandler()
		-- Do shout
	end
	ModSettings.AddControl(modname, "shout", "Shout" "Z", ShoutHandler, false)
2) with no handler, in which case you should use the returned function to check the key:
	local IsShout = ModSettings.AddControl(modname, "shout", "Shout", "Z")
	function OnKeyPress(key, down)
		if IsShout(key) and not down then
			-- Do shout
		end
	end
3) Or both at once, since when you provide a handler it still returns the key checking function

Notes:
You can add both a down and an up handler for the same control name. If you do, it's best
to keep the rest of the parameters the same (everything except handler and down).
]]
ModSettings.AddControl = function(modname, control_name, control_desc, default_key, handler, down)
	if modcontrols[modname] == nil then
		CheckToLoadIcon(modname)
		modcontrols[modname] = {}
		modcontrols_lookup[modname] = {}
	end
	if type(default_key) == "number" then
		default_key = string.char(default_key)
	end
	default_key = default_key:upper()
	local saved_key = GetModConfigData(control_name, modname, true)
	if saved_key == nil then saved_key = default_key end
	if type(saved_key) == "number" then
		saved_key = string.char(saved_key)
	end
	saved_key = saved_key:upper()
	local control_data = modcontrols_lookup[modname][control_name]
	if not control_data then --We haven't added this one yet, make its table
		control_data = {
			name = control_name,
			label = control_desc,
			default = default_key,
			saved = saved_key,
			value = saved_key,
		}
		table.insert(modcontrols[modname], control_data)
	else --just add in the new description and default key
		control_data.label = control_desc
		if control_data.saved == control_data.default then
			control_data.saved = default_key
		end
		control_data.default = default_key
	end
	if handler then
		if control_data[down] then
			-- There was an earlier binding for this key and direction, remove it
			local handler_category = down and "onkeydown" or "onkeyup"
			TheInput[handler_category]:RemoveHandler(control_data[down])
		end
		local AddKeyHandler = TheInput["AddKey"..(down and "Down" or "Up").."Handler"]
		control_data[down] = saved_key == "" and {fn = handler} --key is unbound
											  or AddKeyHandler(TheInput, saved_key:lower():byte(), handler)
	end
	modcontrols_lookup[modname][control_name] = control_data
	return function(key) return modcontrols_lookup[modname][control_name].saved:lower():byte() == key end
end

--[[ Mod Settings GUI Setup ]]--
--TODO: focus hookups?

-- I believe this should allow them to be translated
STRINGS.UI.OPTIONS.MODSETTINGS = "Mod Settings"
STRINGS.UI.OPTIONS.MODCONTROLS = "Mod Controls"

local TEMPLATES = require("widgets/templates")
local Widget = require("widgets/widget")
local Button = require("widgets/button")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local Spinner = require("widgets/spinner")
local ScrollableList = require("widgets/scrollablelist")
local PopupDialogScreen = require("screens/popupdialog")

--This was written with reference to ModsScreen:UpdateForWorkshop()
local function BuildModWidget(self, modname)
	local modinfo = KnownModIndex:GetModInfo(modname)
	local opt = TEMPLATES.ModListItem(modname, KnownModIndex:GetModInfo(modname), "WORKING_NORMALLY", true)
	opt.modname = modname
	opt.checkbox:Hide()
	opt.status:Hide()
	
	opt.OnGainFocus =
		function()
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover")
			opt.state_bg:Show()
		end

	opt.OnLoseFocus =
		function()
			opt.state_bg:Hide()
			if opt.o_pos ~= nil then
				opt:SetPosition(opt.o_pos)
				opt.o_pos = nil
			end
		end
		
	opt.OnControl =
		function(_, control, down)
			if Widget.OnControl(opt, control, down) then return true end
			if down then
				if control == CONTROL_ACCEPT or (control == CONTROL_INSPECT and TheInput:ControllerAttached()) then
					if opt.o_pos == nil then
						opt.o_pos = opt:GetLocalPosition()
						opt:SetPosition(opt.o_pos + opt.clickoffset)
					end
				end
			else
				if opt.o_pos ~= nil then
					opt:SetPosition(opt.o_pos)
					opt.o_pos = nil
				end
				if control == CONTROL_ACCEPT then
					TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
					self:ShowModOptions(opt.idx)
					return true
				end
			end
		end
	
	return opt
end

local function BuildModSelectionPanel(self, root, mod_table, is_controls)
    root.middle_line = root:AddChild(Image("images/ui.xml", "line_vertical_5.tex"))
    root.middle_line:SetScale(0.70, .63)
    root.middle_line:SetPosition(-8, -40, 0)
	
	local mod_widgets = {}
	for modname, _ in pairs(mod_table) do
		table.insert(mod_widgets, BuildModWidget(self, modname))
	end
	table.sort(mod_widgets, function(a,b) return a.name:GetString():lower() < b.name:GetString():lower() end)
	for idx, widget in ipairs(mod_widgets) do
		widget.idx = idx
	end
	local mods_list_scale = 0.87
	root.mods_scroll_list = root:AddChild(ScrollableList(mod_widgets, 322/mods_list_scale, 400/mods_list_scale, 74/mods_list_scale, 10, nil, nil, 185, nil, nil, -22))
	root.mods_scroll_list:SetScale(mods_list_scale)
	root.mods_scroll_list:SetPosition(-185, -33)
	root.focus_start = root.mods_scroll_list
	
	root.options_scroll_list = root:AddChild(is_controls
		and ScrollableList({}, 500, 400, 40, 12, nil, nil, 232, nil, nil, -5)
		 or ScrollableList({}, 500, 400, 40, 12))
	root.options_scroll_list:SetPosition(245, -33)

	-- Lets you see the actual size of the scroll list by tinting the background
	-- root.mods_scroll_list.bg:SetTexture("images/ui.xml", "white.tex")
	-- root.mods_scroll_list.bg:SetTint(1,0,0,.5)
	-- root.options_scroll_list.bg:SetTexture("images/ui.xml", "white.tex")
	-- root.options_scroll_list.bg:SetTint(0,0,1,.5)
end

local function ReregisterControl(handler, key, down)
	local handler_fn = handler.fn
	if handler.event ~= nil then
		local handler_category = down and "onkeydown" or "onkeyup"
		TheInput[handler_category]:RemoveHandler(handler)
	end
	if key == "" then --this was unbinding the key
		-- return an "empty" handler that just preserves the callback function
		return {fn = handler_fn}
	end
	local AddKeyHandler = TheInput["AddKey"..(down and "Down" or "Up").."Handler"]
	return AddKeyHandler(TheInput, key:lower():byte(), handler_fn)
end

--[[ -- TODO
local OptionsScreen = require("screens/optionsscreen")
local OptionsScreen_ctor = OptionsScreen._ctor
function OptionsScreen:_ctor(...)
	local _SetTab = self.SetTab
	self.SetTab = function() end
	local _UpdateMenu = self.UpdateMenu
	self.UpdateMenu = function() end
	OptionsScreen_ctor(self, ...)
	self.SetTab = _SetTab
	self.UpdateMenu = _UpdateMenu
	if mod_icon_prefabs then
		local mod_icon_prefab_names = {}
		for _,prefab in ipairs(mod_icon_prefabs) do
			RegisterPrefabs(prefab)
			table.insert(mod_icon_prefab_names, prefab.name)
		end
		TheSim:LoadPrefabs(mod_icon_prefab_names)
		mod_icon_prefabs = nil --mark it as having been loaded
	end
	local nav_bar = self.nav_bar
	self.nav_bar = self.root:AddChild(TEMPLATES.NavBarWithScreenTitle(nav_bar.title:GetString(), "tall"))
	local existing_nav_bar_buttons = {}
	local top = -math.huge
	local separation = 0
	for _,v in pairs(nav_bar.children) do
		if v:is_a(Button) then
			table.insert(existing_nav_bar_buttons, v)
			top = math.max(v:GetPosition().y, top)
			separation = separation + v:GetPosition().y
		end
	end
	local n = #existing_nav_bar_buttons
	-- first subtract the top from each element that contributed to separation
	-- then divide by the number of separations, which should be the (n-1)th triangular number
	separation = (separation - (top * n)) / ((n-1)*n/2)
	--According to servercreationscreen, -10 is the right start point for "tall" nav bars
	local new_top = -10
	-- But by default this results in 4 buttons intead of 5, so bump it down by half a separation
	if n == 2 then new_top = new_top + separation/2 end
	
	for i,v in ipairs(existing_nav_bar_buttons) do
		local p = v:GetPosition()
		v:SetPosition(p.x, p.y - top + new_top, p.z)
		self.nav_bar:AddChild(v)
	end
	
	local mod_settings_buttons = {
		TEMPLATES.NavBarButton(0, STRINGS.UI.OPTIONS.MODSETTINGS,
			function() self:SetTab("modsettings") end
		),
		TEMPLATES.NavBarButton(0, STRINGS.UI.OPTIONS.MODCONTROLS,
			function() self:SetTab("modcontrols") end
		),
	}
	for i,v in ipairs(mod_settings_buttons) do
		local p = v:GetPosition()
		v:SetPosition(p.x, (n+i-1)*separation + new_top, p.z)
		self.nav_bar:AddChild(v)
	end
	
	self:RemoveChild(nav_bar)
	nav_bar:Kill()
	
	self.nav_button_order = { "settings", "controls", "modsettings", "modcontrols" }
	self.nav_buttons = {
		settings = self.settings_button,
		controls = self.controls_button,
		modsettings = mod_settings_buttons[1],
		modcontrols = mod_settings_buttons[2],
	}
	
	local modsettings_root = self.root:AddChild(Widget("ROOT"))
	modsettings_root:SetPosition(self.settingsroot:GetPosition())
	local modsettings_title = modsettings_root:AddChild(Text(BUTTONFONT, 50, STRINGS.UI.OPTIONS.MODSETTINGS))
	modsettings_title:SetPosition(self.settings_title:GetPosition())
	modsettings_title:SetColour(self.settings_title:GetColour())
	BuildModSelectionPanel(self, modsettings_root, modsettings, false)
	
	local modcontrols_root = self.root:AddChild(Widget("ROOT"))
	modcontrols_root:SetPosition(self.controlsroot:GetPosition())
	local modcontrols_title = modcontrols_root:AddChild(Text(BUTTONFONT, 50, STRINGS.UI.OPTIONS.MODCONTROLS))
	modcontrols_title:SetPosition(self.controls_title:GetPosition())
	modcontrols_title:SetColour(self.controls_title:GetColour())
	BuildModSelectionPanel(self, modcontrols_root, modcontrols, true)
	
	self.mod_reset_button = self.root:AddChild(TEMPLATES.Button(STRINGS.UI.CONTROLSSCREEN.RESET, function() 
		TheFrontEnd:PushScreen(PopupDialogScreen( STRINGS.UI.CONTROLSSCREEN.RESETTITLE, STRINGS.UI.CONTROLSSCREEN.RESETBODY,
		{ 
			{ 
				text = STRINGS.UI.CONTROLSSCREEN.YES, 
				cb = function()
					local root = modcontrols_root
					for _, item in ipairs(root.options_scroll_list.items) do
						local v = item.control
						v.value = v.default
						root.dirty_options[v] = true
						self.mod_apply_button.onclick()
						item.button_kb:SetText(v.default)
						item.changed_image:Hide()
					end					
					TheFrontEnd:PopScreen()
				end
			},
			{ 
				text = STRINGS.UI.CONTROLSSCREEN.NO, 
				cb = function()
					TheFrontEnd:PopScreen()					
				end
			}
		}))
	end))
	self.mod_reset_button:SetScale(.8)
	self.mod_reset_button:Hide()
	
	self.mod_apply_button = self.root:AddChild(TEMPLATES.Button(STRINGS.UI.MODSSCREEN.APPLY, function()
		-- First we write the mod config, then we run the callbacks
		-- in case some callbacks check the mod config
		local dirty_options = self.tabs[self.selected_tab].dirty_options
		local modname = self.tabs[self.selected_tab].modname
		if type(dirty_options) ~= "table" then
			--shouldn't happen, but avoid a crash at least
			print("dirty options wasn't a table?")
			return
		end
		local _print = print
		print = function() end --janky, but KnownModIndex functions kinda spam the logs
		local config = KnownModIndex:LoadModConfigurationOptions(modname, true)
		local settings = {}
		local namelookup = {} --so we don't have to scan through the options
		for i,v in ipairs(config) do
			namelookup[v.name] = i
			table.insert(settings, {name = v.name, label = v.label, options = v.options, default = v.default, saved = v.saved})
		end
		for option,widget in pairs(dirty_options) do
			if option[false] then
				option[false] = ReregisterControl(option[false], option.value, false)
			end
			if option[true] then
				option[true] = ReregisterControl(option[true], option.value, true)
			end
			option.saved = option.value
			widget.last_value = option.value
			local setting_index = namelookup[option.name]
			if setting_index == nil then
				-- Maybe this isn't in the normal mod config; we should save it anyway
				table.insert(settings, {
					name = option.name,
					label = option.label or "",
					options = option.options or {},
					default = option.default,
				})
				setting_index = #settings
			end
			settings[setting_index].saved = option.saved
		end
		--Note: don't need to include options that aren't in the menu,
		-- because they're already in there from the options load above
		KnownModIndex:SaveConfigurationOptions(function() end, modname, settings, true)
		print = _print --restore print functionality!
		-- Now run the callbacks
		for option,_ in pairs(dirty_options) do
			if option.callback then option.callback(option.value) end
		end
		self.tabs[self.selected_tab].dirty_options = {}
		self.tabs[self.selected_tab].num_dirty_options = 0
		self.mod_apply_button:Disable()
	end))
	self.mod_apply_button:Hide()

	self.settingsroot.focus_start = self.grid
	self.controlsroot.focus_start = self.active_list
	self.tabs = {
		settings = self.settingsroot,
		controls = self.controlsroot,
		modsettings = modsettings_root,
		modcontrols = modcontrols_root,
	}
	for _,v in pairs(self.tabs) do
		v:Hide()
	end
	self:SetTab("settings")
	
	self:RefreshNav()
end

local OptionsScreen_UpdateMenu = OptionsScreen.UpdateMenu
function OptionsScreen:UpdateMenu(...)
	local ret = OptionsScreen_UpdateMenu(self, ...)
	if #self.menu.items == 2 then -- controller is not attached and the apply/reset buttons have been added
		self.menu:AddCustomItem(self.mod_apply_button)
		-- if self.apply_button then -- if not, controller is attached and it won't show this at all anyway
		self.mod_apply_button:SetPosition(self.apply_button:GetPosition())
		-- end
		self.mod_apply_button:Disable()
		
		self.menu:AddCustomItem(self.mod_reset_button)
		-- if self.reset_button then -- if not, controller is attached and it won't show this at all anyway
		self.mod_reset_button:SetPosition(self.reset_button:GetPosition())
		-- end
	end
	return ret
end

-- Unfortunately this part of OptionsScreen was really not written in an extensible way
-- local OptionsScreen_SetTab = OptionsScreen.SetTab
function OptionsScreen:SetTab(tab, ...)
	if self.selected_tab then
		if self.nav_buttons[self.selected_tab].shown then
			self.nav_buttons[self.selected_tab]:Unselect()
		end
		self.tabs[self.selected_tab]:Hide()
	end
	if self.tabs[tab] then
		self.selected_tab = tab
		if self.nav_buttons[tab].shown then
			self.nav_buttons[tab]:Select()
		end
		self.tabs[tab]:Show()
		if self.tabs[tab].mods_scroll_list and self.tabs[tab].last_idx == nil then
			-- When opened for the first time, select the first mod
			self:ShowModOptions(1)
		end
	end
	if self.apply_button then
		if tab == "modsettings" or tab == "modcontrols" then
			self.mod_apply_button:Show()
			self.apply_button:Hide()
		else
			self.apply_button:Show()
			self.mod_apply_button:Hide()
		end
	end
	if self.reset_button then
		if tab == "modcontrols" then
			self.mod_reset_button:Show()
		else
			self.mod_reset_button:Hide()
		end
	end
	self:UpdateMenu()
end

local OptionsScreen_RefreshNav = OptionsScreen.RefreshNav
function OptionsScreen:RefreshNav(...)
	local ret = OptionsScreen_RefreshNav(self, ...)
	local function toleftcol()
		return self.nav_buttons[self.selected_tab]
	end
	local function torightcol()
		return self.tabs[self.selected_tab].focus_start
	end
	for i,v in ipairs(self.nav_button_order or {}) do
		local button = self.nav_buttons[v]
		if i > 1 then
			button:SetFocusChangeDir(MOVE_UP, self.nav_buttons[ self.nav_button_order[i-1] ])
		end
		button:SetFocusChangeDir(MOVE_RIGHT, torightcol)
		self.tabs[v].focus_start:SetFocusChangeDir(MOVE_LEFT, toleftcol)
		if i < #self.nav_button_order then
			button:SetFocusChangeDir(MOVE_DOWN, self.nav_buttons[ self.nav_button_order[i+1] ])
		end
	end
	-- Blatantly copied from the original
    if self.active_list and self.active_list.items then
    	for k,v in pairs(self.active_list.items) do
            if v.button_kb then
    		    v.button_kb:SetFocusChangeDir(MOVE_LEFT, toleftcol)
            elseif v.button_controller then
                v.button_controller:SetFocusChangeDir(MOVE_LEFT, toleftcol)
            end
    	end
    end
	return ret
end

local spinner_height = 40
local spinner_width = 170
local label_width = 225
local function BuildOptionSpinner(self, root, i, v)
	-- Written with reference to modconfigurationscreen
	local spin_options = {}
	local spin_options_hover = {}
	for _,o in ipairs(v.options) do
		table.insert(spin_options, {text=o.description, data=o.data})
		spin_options_hover[o.data] = o.hover
	end
	
	local opt = Widget("Option"..v.name)
	
	opt.spinner = opt:AddChild(Spinner( spin_options, spinner_width, nil, {font=NEWFONT, size=25}, nil, nil, nil, true, 100, nil))
	opt.spinner:SetTextColour(0,0,0,1)
	local default_value = v.saved
	if default_value == nil then default_value = v.default end
	opt.last_value = default_value
	
	opt.spinner.OnChanged =
		function( _, data )
			v.value = data
			opt.spinner:SetHoverText( spin_options_hover[data] or "" )
			if opt.last_value == data then
				if root.dirty_options[v] then
					root.num_dirty_options = root.num_dirty_options - 1
					if root.num_dirty_options == 0 then
						self.mod_apply_button:Disable()
					end
				end
				root.dirty_options[v] = nil
			else
				if root.dirty_options[v] == nil then
					root.num_dirty_options = root.num_dirty_options + 1
				end
				root.dirty_options[v] = opt
				self.mod_apply_button:Enable()
			end
		end
	opt.spinner:SetSelected(default_value)
	opt.spinner:SetHoverText( spin_options_hover[default_value] or "" )
	opt.spinner:SetPosition( 325, 0, 0 )

	local label = opt.spinner:AddChild( Text( NEWFONT, 25, (v.label or v.name) .. ":" or STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING..":" ) )
	label:SetColour( 0, 0, 0, 1 )
	label:SetPosition( -label_width/2 - 90, 0, 0 )
	label:SetRegionSize( label_width, 50 )
	label:SetHAlign( ANCHOR_RIGHT )
	label:SetHoverText( v.hover or "" )
	if TheInput:ControllerAttached() then
		opt:SetHoverText( v.hover or "" )
	end

	opt.spinner.OnGainFocus = function()
		Spinner._base.OnGainFocus(self)
		opt.spinner:UpdateBG()
	end
	opt.focus_forward = opt.spinner
	
	return opt
end

local button_x = 167 -- x coord of the right column
local function BuildControlBinder(self, root, i, v)
	-- Written with reference to optionsscreen DoInit -- CONTROLS -- section
	local group = Widget("Control"..v.name)
	group:SetScale(0.93, 0.93, 0.75)
	
	group.control = v
	
	group.bg = group:AddChild(Image("images/ui.xml", "single_option_bg.tex"))
	group.bg:SetPosition(10, 3, 0)
	group.bg:SetScale(0.99, 1, 1)

	group.changed_image = group:AddChild(Image("images/ui.xml", "option_highlight.tex"))
	group.changed_image:SetPosition(button_x-1,2,0)
	group.changed_image:SetScale(.65, .89)
	group.changed_image:Hide()

	group.label = group:AddChild(Text(NEWFONT, 28))
	group.label:SetString(v.label)
	group.label:SetHAlign(ANCHOR_LEFT)
	group.label:SetColour(0,0,0,1)
	group.label:SetRegionSize(300, 50)
	group.label:SetPosition(-90,5,0)
	group.label:SetClickable(false)
	
	group.button_kb = group:AddChild(ImageButton("images/ui.xml", "blank.tex", "spinner_focus.tex", nil, nil, nil, {1,1}, {0,0}))
	group.button_kb:ForceImageSize(198, 48)

	group.button_kb:SetTextColour(0,0,0,1)
	group.button_kb:SetFont(NEWFONT)
	group.button_kb:SetTextSize(30)  
	group.button_kb:SetPosition(button_x,2,0)
	group.button_kb.idx = i
	group.button_kb:SetOnClick( 
		function() 
			self:MapModControl(group, v)
		end 
	) 
	group.button_kb:SetHelpTextMessage(STRINGS.UI.CONTROLSSCREEN.CHANGEBIND)
	group.button_kb:SetDisabledFont(NEWFONT)
	group.button_kb:SetText(v.saved)

	group.focus_forward = group.button_kb
			
	return group
end

local function PopClick()
	TheFrontEnd:PopScreen()
	TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
end


function OptionsScreen:MapModControl(option, v)
	-- Written with reference to OptionsScreen:MapControl
	local root = self.tabs[self.selected_tab]
    local default_text = string.format(STRINGS.UI.CONTROLSSCREEN.DEFAULT_CONTROL_TEXT, v.default)
    local body_text = STRINGS.UI.CONTROLSSCREEN.CONTROL_SELECT .. "\n\n" .. default_text
	
	local function SetKeyChar(key_char)
		if v.saved == key_char then
			if root.dirty_options[v] then
				root.num_dirty_options = root.num_dirty_options - 1
				option.changed_image:Hide()
				if root.num_dirty_options == 0 then
					self.mod_apply_button:Disable()
				end
			end
			root.dirty_options[v] = nil
		else
			if root.dirty_options[v] == nil then
				root.num_dirty_options = root.num_dirty_options + 1
			end
			option.changed_image:Show()
			root.dirty_options[v] = option
			self.mod_apply_button:Enable()
		end
		v.value = key_char
		option.button_kb:SetText(key_char)
	end

	local function OnUnbind()
		SetKeyChar("")
		TheFrontEnd:PopScreen()
		return true
	end
	
    local popup = PopupDialogScreen(v.label, body_text, {
		{text=STRINGS.UI.CONTROLSSCREEN.CANCEL, cb=function() TheFrontEnd:PopScreen() end},
		{text=STRINGS.UI.CONTROLSSCREEN.UNBIND, cb=OnUnbind},
	})
    popup.text:SetRegionSize(480, 150)
    popup.text:SetPosition(0, -25, 0)    
	popup.text:SetColour(0,0,0,1)
	popup.text:SetFont(NEWFONT)
    	
    popup.OnRawKey = function(_, key, down)
		if down then return end
		local key_char = nil
		local function GetKeyChar()
			key_char = string.char(key):upper()
		end
		-- It fails when key is invalid, so we reject it
		if not pcall(GetKeyChar) then return false end
		SetKeyChar(key_char)
		PopClick()
		return true
	end	
	TheFrontEnd:PushScreen(popup)
end

function OptionsScreen:ShowModOptions(idx)
	local show_controls = self.selected_tab == "modcontrols"
	local root = self.tabs[self.selected_tab]
	-- Defense against this being called on other tabs, somehow
	if root == nil or root.mods_scroll_list == nil then return end
	local mod_widget = root.mods_scroll_list.items[idx]
	-- Protects against empty lists and stray idxs
	if not mod_widget then return end
	if root.last_idx then
		local last_widget = root.mods_scroll_list.items[root.last_idx]
		last_widget.white_bg:SetTint(1,1,1,1)
		last_widget.name:SetColour(0,0,0,1)
	end
	root.last_idx = idx
	mod_widget.white_bg:SetTint(0,0,0,1)
	mod_widget.name:SetColour(1,1,1,1)
	
	local options = (show_controls and modcontrols or modsettings)[mod_widget.modname]
	if options == nil then
		root.options_scroll_list:Clear()
		return
	end
	local optionwidgets = {}
	root.modname = mod_widget.modname
	root.dirty_options = {}
	root.num_dirty_options = 0
	for i,v in ipairs(options) do
		local opt = nil
		if show_controls then
			opt = BuildControlBinder(self, root, i, v)
		else
			opt = BuildOptionSpinner(self, root, i, v)
		end
		table.insert(optionwidgets, opt)
	end
	root.options_scroll_list:SetList(optionwidgets)
end

local OptionsScreen_IsDirty = OptionsScreen.IsDirty
function OptionsScreen:IsDirty(...)
	for _,tab in pairs(self.tabs or {}) do
		if tab.num_dirty_options and tab.num_dirty_options > 0 then
			return true
		end
	end
	return OptionsScreen_IsDirty(self, ...)
end
]]

return ModSettings