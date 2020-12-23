local Screen = require "widgets/screen"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local Spinner = require "widgets/spinner"
local ModSettings = require "tools/modsettings"
local PopupDialogScreen = require "screens/redux/popupdialog"
local ImageButton = require "widgets/imagebutton"
local ScrollableList = require "widgets/scrollablelist"

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

local GeometricControlsScreen = Class(Screen, function(self, modname, options_screen)
	Screen._ctor(self, "GeometricControlsScreen")
	
	self.modname = modname
	self.options_screen = options_screen
	self.dirty = false
	
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
	local bottom_buttons = {
		{text = STRINGS.UI.CONTROLSSCREEN.RESET, cb = function() self:Reset() end},
		{text = STRINGS.UI.CONTROLSSCREEN.CLOSE, cb = function() self:Close() end},
		{text = STRINGS.UI.CONTROLSSCREEN.APPLY, cb = function() self:Apply() end},
	}
	
	self.bg = self.proot:AddChild(TEMPLATES.RectangleWindow(619, 359, "Geometric Placement Keybinds", bottom_buttons))
	self.bg.title:SetPosition(0, -70)
	
	self.reset_button = self.bg.actions.items[1]
	self.close_button = self.bg.actions.items[2]
	self.apply_button = self.bg.actions.items[3]
	self.apply_button:Disable()
	
	local button_x = -361 -- x coord of the left edge
    local button_width = 250
    local button_height = 48
	local action_label_width = 350
	local action_btn_width = 250
    local spacing = 15
	local group_width = action_label_width + spacing + action_btn_width
	local function BuildControlGroup(name, label, value, default)
		local group = Widget("control"..name)
		group.bg = group:AddChild(TEMPLATES.ListItemBackground(group_width+20, button_height))
		group.bg:SetPosition(-60,0)
		group:SetScale(1,1,0.75)

		group.name = name
		group.desc = label
		group.value = value
		group.default = default

		local x = button_x

		group.label = group:AddChild(Text(CHATFONT, 28))
		group.label:SetString(label)
		group.label:SetHAlign(ANCHOR_LEFT)
		group.label:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
		group.label:SetRegionSize(action_label_width, 50)
		x = x + action_label_width/2
		group.label:SetPosition(x,0)
		x = x + action_label_width/2 + spacing
		group.label:SetClickable(false)

		x = x + button_width/2
		group.changed_image = group:AddChild(Image("images/global_redux.xml", "wardrobe_spinner_bg.tex"))
		group.changed_image:SetTint(1,1,1,0.3)
		group.changed_image:ScaleToSize(button_width, button_height)
		group.changed_image:SetPosition(x,0)
		group.changed_image:Hide()

		group.binding_btn = group:AddChild(ImageButton("images/global_redux.xml", "blank.tex", "spinner_focus.tex"))
		group.binding_btn:ForceImageSize(button_width, button_height)
		group.binding_btn:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
		group.binding_btn:SetTextFocusColour(UICOLOURS.GOLD_FOCUS)
		group.binding_btn:SetFont(CHATFONT)
		group.binding_btn:SetTextSize(30)
		group.binding_btn:SetPosition(x,0)
		group.binding_btn:SetOnClick(
			function()
				self:MapControl(group)
			end)
		x = x + button_width/2 + spacing

		group.binding_btn:SetHelpTextMessage(STRINGS.UI.CONTROLSSCREEN.CHANGEBIND)
		group.binding_btn:SetDisabledFont(CHATFONT)
		group.binding_btn:SetText(value:len() > 0 and value or STRINGS.UI.CONTROLSSCREEN.INPUTS[9][2])

		group.focus_forward = group.binding_btn

		return group
	end
	
	self.groups = {}
	for i,v in pairs(ModSettings.GetControlsForMod(self.modname)) do
		local group = BuildControlGroup(v.name, v.label, v.value, v.default)
		table.insert(self.groups, group)
	end
	
    local function CreateScrollableList(items)
        return ScrollableList(items, group_width/2, 280, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "GOLD")
    end
	
	self.controllist = self.proot:AddChild(CreateScrollableList(self.groups))
	self.controllist:SetScale(0.9)
	self.controllist:SetPosition(150, -20)

	self:SetUpFocusHookups()

	TheInputProxy:SetCursorVisible(true)
end)

function GeometricControlsScreen:SetUpFocusHookups()

end

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
		self.dirty = true
		self.apply_button:Enable()
	end

	local function OnUnbind()
		SetKeyChar("")
		TheFrontEnd:PopScreen()
		return true
	end
	
    local popup = PopupDialogScreen(group.desc, body_text, {
		{text=STRINGS.UI.CONTROLSSCREEN.CANCEL, cb=function() TheFrontEnd:PopScreen() end},
		{text=STRINGS.UI.CONTROLSSCREEN.UNBIND, cb=OnUnbind},
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
		TheWorld:PushEvent("continuefrompause")
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
	end
	if self.dirty then
		self:Confirm(STRINGS.UI.OPTIONS.BACKTITLE, STRINGS.UI.OPTIONS.BACKBODY, callback_yes)
	else
		callback_yes()
	end
end

function GeometricControlsScreen:SaveChanges()
	for _, group in pairs(self.groups) do
		ModSettings.RebindControl(self.modname, group.name, group.value)
	end
	self.dirty = false
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
	return key:len() > 0 and key or STRINGS.UI.CONTROLSSCREEN.INPUTS[9][2]
end

function GeometricControlsScreen:OnControl(control, down)
	if GeometricControlsScreen._base.OnControl(self,control, down) then return true end
	
	if down then return end
	if control == CONTROL_PAUSE or control == CONTROL_CANCEL or control == CONTROL_MENU_MISC_3 then
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
