local Screen = require "widgets/screen"
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local Spinner = require "widgets/spinner"
local ModSettings = require "tools/modsettings"
local PopupDialogScreen = require "screens/popupdialog"
local ImageButton = require "widgets/imagebutton"

local TEMPLATES = {}

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

local function PopClick()
	TheFrontEnd:PopScreen()
	TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
end

local GeometricControlsScreen = Class(Screen, function(self, modname, options_screen, templates)
	Screen._ctor(self, "GeometricControlsScreen")
	
	TEMPLATES = templates
	
	self.modname = modname
	self.options_screen = options_screen
	self.dirty = 0
	
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
	self.bg = self.proot:AddChild(TEMPLATES.CurlyWindow())
	self.bg:SetPosition(0, 15)
	
	--title	
    self.title = self.proot:AddChild(Text(BUTTONFONT, 50))
    self.title:SetPosition(0, 135, 0)
    self.title:SetString("Geometric Placement Key Bindings")
	
	self.apply_button = self.proot:AddChild(ImageButton())
    self.apply_button:SetPosition(-180, -180, 0)
    self.apply_button:SetText(STRINGS.UI.CONTROLSSCREEN.APPLY)
    self.apply_button.text:SetColour(0,0,0,1)
    self.apply_button:SetOnClick( function() self:Apply() end )
    self.apply_button:SetFont(BUTTONFONT)
    self.apply_button:SetTextSize(40)    
    self.apply_button:Hide()
	
	self.cancel_button = self.proot:AddChild(ImageButton())
    self.cancel_button:SetPosition(0, -180, 0)
    self.cancel_button:SetText(STRINGS.UI.CONTROLSSCREEN.CANCEL)
    self.cancel_button.text:SetColour(0,0,0,1)
    self.cancel_button:SetOnClick( function() self:Close() end )
    self.cancel_button:SetFont(BUTTONFONT)
    self.cancel_button:SetTextSize(40)
    
	self.reset_button = self.proot:AddChild(ImageButton())
    self.reset_button:SetPosition(180, -180, 0)
    self.reset_button:SetText(STRINGS.UI.CONTROLSSCREEN.RESET)
    self.reset_button.text:SetColour(0,0,0,1)
    self.reset_button:SetOnClick( function() self:Reset() end )
    self.reset_button:SetFont(BUTTONFONT)
    self.reset_button:SetTextSize(40)
    
	self.controlwidgets = {}
	local last_button = nil
	local function BuildControlGroup(name, label, value, default)
		local group = Widget("control"..name)
		group:SetScale(0.75,0.75,0.75)
		
		group.name = name
		group.desc = label
		group.value = value
		group.prev_value = value
		group.default = default
		group.dirty = false
		
		group.bg = group:AddChild(Image("images/ui.xml", "nondefault_customization.tex"))
		group.bg:SetPosition(80,0,0)
		group.bg:SetScale(1.5, 0.95, 1)
		group.bg:Hide()
		
		group.binding_btn = group:AddChild(ImageButton("images/ui.xml", "button_long.tex", "button_long_over.tex", "button_long_disabled.tex"))
		group.binding_btn:SetText(value:len() > 0 and value or STRINGS.UI.CONTROLSSCREEN.INPUTS[6][2])
		group.binding_btn.text:SetColour(0,0,0,1)
		group.binding_btn:SetFont(BUTTONFONT)
		group.binding_btn:SetTextSize(30)  
		group.binding_btn:SetPosition(-25,0,0)
		group.binding_btn:SetOnClick( 
			function() 
				self:MapControl(group)
			end 
		)
		
		if last_button then
			group.binding_btn:SetFocusChangeDir(MOVE_UP, last_button)
			last_button:SetFocusChangeDir(MOVE_DOWN, group.binding_btn)
		end
		
		last_button = group.binding_btn
		
		group.text = group:AddChild(Text(UIFONT, 40))
		group.text:SetString(label)
		group.text:SetHAlign(ANCHOR_LEFT)
		group.text:SetRegionSize( 500, 50 )
		group.text:SetPosition(325,0,0)
		group.text:SetClickable(false)

		return group
	end
	
	self.groups = {}
	for i,v in pairs(ModSettings.GetControlsForMod(modname)) do
		local group = BuildControlGroup(v.name, v.label, v.value, v.default)
		self.proot:AddChild(group)
		group:SetPosition(-50, 110 - 60*i)
		table.insert(self.groups, group)
	end
	
	TheInputProxy:SetCursorVisible(true)
end)

function GeometricControlsScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
	table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_3) .. " " .. STRINGS.UI.HELP.BACK)
	
	return table.concat(t, "  ")
end

function GeometricControlsScreen:OnRawKey(key, down)
	if GeometricControlsScreen._base.OnRawKey(self, key, down) then return true end
	
	-- if self.IsOptionsMenuKey(key) and not down then	
		-- self.callbacks.ignore()
		-- self:Close()
		-- return true
	-- end
end

function GeometricControlsScreen:OnControl(control, down)
	if GeometricControlsScreen._base.OnControl(self,control, down) then return true end
	
	-- if down then return end
	-- if control == CONTROL_PAUSE or control == CONTROL_CANCEL or control == CONTROL_MENU_MISC_3 then
		-- self:Close()
		-- return true
	-- elseif TheInput:ControllerAttached() and (control == CONTROL_OPEN_CRAFTING or control == CONTROL_OPEN_INVENTORY) then
		-- local section = self.section_lookup[self.current_focus]
		-- if section then
			-- section = section + (control == CONTROL_OPEN_CRAFTING and -1 or 1)
		-- else
			-- section = 1
		-- end
		-- local focus = self.section_mainbuttons[((section-1)%#self.section_mainbuttons)+1]
		-- focus:SetFocus()
		-- return true
	-- end
end

function GeometricControlsScreen:MapControl(group)
	-- Written with reference to OptionsScreen:MapControl
    local default_text = string.format(STRINGS.UI.CONTROLSSCREEN.DEFAULT_CONTROL_TEXT, group.default)
    local body_text = STRINGS.UI.CONTROLSSCREEN.CONTROL_SELECT .. "\n\n" .. default_text
	
	local function SetKeyChar(key_char)
		if key_char == group.value then return end
		group.value = key_char
		group.binding_btn:SetText(self:GetKeyText(key_char))
		local prev_dirty = group.dirty
		if group.value == group.prev_value then
			group.dirty = false
			group.bg:Hide()
		else
			group.dirty = true
			group.bg:Show()
		end
		if group.dirty ~= group.prev_dirty then
			self.dirty = self.dirty + (group.dirty and 1 or -1)
		end
		if self.dirty > 0 then
			self.apply_button:Show()
		else
			self.apply_button:Hide()
		end
	end

	local function OnUnbind()
		SetKeyChar("")
		TheFrontEnd:PopScreen()
		return true
	end
	
    local popup = PopupDialogScreen(group.desc, body_text, {
		{text=STRINGS.UI.CONTROLSSCREEN.CANCEL, cb=function() TheFrontEnd:PopScreen() end},
		{text=STRINGS.UI.CONTROLSSCREEN.UNBIND or "Unbind", cb=OnUnbind},
	})
    	
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

function GeometricControlsScreen:Close()
	local function callback_yes()
		self.options_screen:Show()
		TheFrontEnd:PopScreen()
		GetWorld():PushEvent("continuefrompause")
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
	end
	if self.dirty > 0 then
		self:Confirm(STRINGS.UI.OPTIONS.BACKTITLE, STRINGS.UI.OPTIONS.BACKBODY, callback_yes)
	else
		callback_yes()
	end
end

function GeometricControlsScreen:SaveChanges()
	for _, group in pairs(self.groups) do
		if group.dirty then
			ModSettings.RebindControl(self.modname, group.name, group.value)
			group.dirty = false
			group.bg:Hide()
		end
	end
	self.dirty = 0
end

function GeometricControlsScreen:Apply()
	self:SaveChanges()
	self:Close()
end

function GeometricControlsScreen:Reset()
	local function callback_yes()
		for _, group in pairs(self.groups) do
			group.value = group.default
			group.binding_btn:SetText(self:GetKeyText(group.value))
		end
		self:SaveChanges()
	end
	self:Confirm(STRINGS.UI.CONTROLSSCREEN.RESETTITLE, STRINGS.UI.CONTROLSSCREEN.RESETBODY, callback_yes)
end

function GeometricControlsScreen:Confirm(title, body, callback_yes, callback_no)
	callback_yes = type(callback_yes) == "function" and callback_yes or function() end
	callback_no = type(callback_no) == "function" and callback_no or function() end
	TheFrontEnd:PushScreen(
		PopupDialogScreen(title, body,
		  { 
		  	{ 
		  		text = STRINGS.UI.OPTIONS.YES,
		  		cb = function()
					callback_yes()
					TheFrontEnd:PopScreen()
				end
			},
			
			{ 
				text = STRINGS.UI.OPTIONS.NO,
				cb = function()
					callback_no()
					TheFrontEnd:PopScreen()
				end
			}
		  }
		)
	)
end

function GeometricControlsScreen:GetKeyText(key)
	return key:len() > 0 and key or STRINGS.UI.CONTROLSSCREEN.INPUTS[6][2]
end

function GeometricControlsScreen:OnControl(control, down)
	if GeometricControlsScreen._base.OnControl(self,control, down) then return true end
	
	if down then return end
	if control == CONTROL_PAUSE or control == CONTROL_CANCEL or control == CONTROL_OPEN_DEBUG_MENU then
		self:Close()
		return true
	end
end

function GeometricControlsScreen:OnBecomeActive()
	GeometricControlsScreen._base.OnBecomeActive(self)
	-- Hide the topfade, it'll obscure the pause menu if paused during fade. Fade-out will re-enable it
	TheFrontEnd:HideTopFade()
end

return GeometricControlsScreen
