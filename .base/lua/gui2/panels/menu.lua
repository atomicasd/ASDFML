local gui2 = ... or _G.gui2

do
	local PANEL = {}
	PANEL.ClassName = "menu"
	PANEL.sub_menu = NULL
	
	function PANEL:Initialize()
		self:SetStyle("frame")
		self:SetStack(true)
		self:SetStackRight(false)
		self:SetSizeStackToWidth(true)
	end
	
	function PANEL:AddEntry(text, on_click)
		local entry = self:CreatePanel("menu_entry")
		
		entry:SetText(text)
		entry.OnClick = on_click
		
		entry:Layout(true)
		self:Layout(true)
		
		return entry
	end

	function PANEL:AddSubMenu(text, on_click)
		local menu, entry = self:AddEntry(text, on_click):CreateSubMenu()
		
		self:CallOnRemove(function() gui2.RemovePanel(menu) end)
		self:CallOnHide(function() menu:SetVisible(false) end)
		
		self:Layout()
		
		return menu, entry 
	end
	
	function PANEL:AddSeparator()
		local panel = self:CreatePanel("base")
		panel:SetStyle("button_active")
		panel:SetIgnoreMouse(true)
		panel.separator = true
		
		self:Layout()
	end
	
	function PANEL:OnLayout(S)
		self:SetWidth(1000)
		
		self:CalcLayoutChain()
		
		local w = 0
		
		for i,v in ipairs(self:GetChildren()) do
			if v.separator then
				v:SetHeight(S*2)
			else
				v:SetHeight(S*10)
				w = math.max(w, v.label:GetX() + v.label:GetWidth() + v.label:GetPadding().right)
			end
		end
		
		self:SetHeight(self:StackChildren().h)
		self:SetWidth(w + self:GetMargin().right)
	end
	
	gui2.RegisterPanel(PANEL)
end

do
	local PANEL = {}
	
	PANEL.ClassName = "menu_entry"
	PANEL.menu = NULL
	
	function PANEL:Initialize()
		self:SetNoDraw(true)
		self:SetStyle("frame")
				
		local img = self:CreatePanel("base", "image")
		img:SetIgnoreMouse(true)
		img:SetVisible(false)
		img:SetupLayoutChain("left")
		
		local label = self:CreatePanel("text", "label")
		label:SetIgnoreMouse(true)
	end
	
	function PANEL:OnMouseEnter()
		self:SetNoDraw(false)
		
		-- close all parent menus
		for k,v in ipairs(self.Parent:GetChildren()) do
			if v ~= self and v.ClassName == "menu_entry" and v.menu and v.menu:IsValid() and v.menu.ClassName == "menu" then
				v.menu:SetVisible(false)
			end
		end
		
		if self.menu:IsValid() then				
			self.menu:SetVisible(true)
			self.menu:Layout(true)
			self.menu:SetPosition(self:GetWorldPosition() + Vec2(self:GetWidth(), 0))
			self.menu:Animate("DrawScaleOffset", {Vec2(0,1), Vec2(1,1)}, 0.25, "*", 0.25, true)
		end
	end
	
	function PANEL:OnLayout(S)
		self:SetMargin(Rect()+S*2)
		self.label:SetPadding(Rect()+S*2)
		self.image:SetPadding(Rect()+S*2)
		self.image:SetLayoutSize(Vec2(math.min(S*8, self.image.Texture.w), math.min(S*8, self.image.Texture.h)))
	end
	
	function PANEL:OnMouseExit()
		self:SetNoDraw(true)
	end
	
	function PANEL:SetText(str)
		self.label:SetText(str)
		self.label:SetupLayoutChain("left")
		self:Layout()
	end
	
	function PANEL:SetIcon(texture)
		if texture then
			self.image:SetTexture(texture)
			self.image:SetNoDraw(false)
		else
			self.image:SetNoDraw(true)
		end
	end
	
	function PANEL:CreateSubMenu()			
	
		local icon = self:CreatePanel("base")
		icon:SetIgnoreMouse(true)
		icon:SetStyle("menu_right_arrow")
		icon:SetupLayoutChain("right")

		self.menu = gui2.CreatePanel("menu")
		self.menu:SetVisible(false)
		
		if self.Skin then self.menu:SetSkin(self:GetSkin()) end
		
		return self.menu, self
	end
			 
	function PANEL:OnMouseInput(button, press)
		if button == "button_1" and press then
			self:OnClick()
		end
	end
	
	function PANEL:OnClick() gui2.SetActiveMenu() end 
	
	gui2.RegisterPanel(PANEL)
end