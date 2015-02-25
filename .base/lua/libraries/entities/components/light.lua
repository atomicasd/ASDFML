if not render then return end

local COMPONENT = {}

COMPONENT.Name = "light"
COMPONENT.Require = {"transform"}
COMPONENT.Events = {"Draw3DLights", "DrawShadowMaps", "DrawLensFlare"}

prototype.StartStorable()
	prototype.GetSet(COMPONENT, "Color", Color(1, 1, 1))
	
	-- automate this!!
	prototype.GetSet(COMPONENT, "DiffuseIntensity", 0.5)
	prototype.GetSet(COMPONENT, "SpecularIntensity", 1)
	prototype.GetSet(COMPONENT, "Roughness", 0.5)

	prototype.GetSet(COMPONENT, "Shadow", false)
	prototype.GetSet(COMPONENT, "FOV", 90, {editor_min = 0, editor_max = 180})
	prototype.GetSet(COMPONENT, "NearZ", 1)
	prototype.GetSet(COMPONENT, "FarZ", 32000)
	prototype.GetSet(COMPONENT, "OrthoSize", 0)
	prototype.GetSet(COMPONENT, "LensFlare", false)
prototype.EndStorable()

if GRAPHICS then	
	function COMPONENT:OnAdd(ent)
		utility.LoadRenderModel("models/cube.obj", function(meshes)
			self.light_mesh = meshes[1]
		end)
	end

	function COMPONENT:OnRemove(ent)
		render.shadow_maps[self] = nil
	end
	
	function COMPONENT:OnDraw3DLights(shader)
		if not render.matrices.vp_matrix or not self.light_mesh then return end -- grr
		
		local transform = self:GetComponent("transform")
		local matrix = transform:GetMatrix() 
		local screen = matrix * render.matrices.vp_matrix
		
		shader.pvm_matrix = screen.m
		self.screen_matrix = screen
		
		local mat = matrix * render.matrices.view_3d
		local x,y,z = mat:GetTranslation()
		shader.light_pos:Set(x*2,y*2,z*2) -- why do i need to multiply by 2?
		shader.light_radius = transform:GetSize()
		shader.inverse_projection = render.matrices.projection_3d_inverse.m
		shader.inverse_view_projection = (render.matrices.vp_3d_inverse).m
		
		-- automate this!!
		shader.light_color = self.Color
		shader.light_ambient_intensity = self.AmbientIntensity
		shader.light_diffuse_intensity = self.DiffuseIntensity
		shader.light_specular_intensity = self.SpecularIntensity
		shader.light_attenuation_constant = self.AttenuationConstant
		shader.light_attenuation_linear = self.AttenuationLinear
		shader.light_attenuation_exponent = self.AttenuationExponent
		shader.light_roughness = self.Roughness
		shader.light_shadow = self.Shadow and 1 or 0
		
		if self.Shadow then
			shader.tex_shadow_map = self.shadow_map:GetTexture("depth")
			shader.light_vp_matrix = self.vp_matrix.m
		end		

		shader:Bind()
		self.light_mesh:Draw()
	end
	
	render.shadow_maps = render.shadow_maps or utility.CreateWeakTable()
							
	function COMPONENT:OnDrawShadowMaps(shader)
		if self.Shadow then
			if not render.shadow_maps[self] then
				self.shadow_map = render.CreateFrameBuffer(render.gbuffer_width, render.gbuffer_height, {
					name = "depth",
					attach = "depth",
					draw_manual = true,
					texture_format = {
						internal_format = "DEPTH_COMPONENT32",	 
						depth_texture_mode = gl.e.GL_RED,
						min_filter = "nearest",				
					} 
				})
				
				render.shadow_maps[self] = self.shadow_map
			end
		else
			if render.shadow_maps[self] then
				render.shadow_maps[self] = nil
			end
			return
		end
		
		local transform = self:GetComponent("transform")					
		local pos = transform:GetPosition()
		local ang = transform:GetAngles()
		
		-- setup the view matrix
		local view = Matrix44()
		view:Rotate(ang.p, 0, 0, 1)
		view:Rotate(ang.r + math.pi/2, 1, 0, 0)
		view:Rotate(ang.y, 0, 0, 1)
		view:Translate(pos.y, pos.x, pos.z)			
		
		
		-- setup the projection matrix
		local projection = Matrix44()
		
		if self.OrthoSize == 0 then
			projection:Perspective(self.FOV, self.NearZ, self.FarZ, render.camera.ratio) 
		else
			local size = self.OrthoSize
			projection:Ortho(-size, size, -size, size, 200, 0) 
		end
		
		--entities.world:GetComponent("world").sun:SetPosition(render.GetCameraPosition()) 
		--entities.world:GetComponent("world").sun:SetAngles(render.GetCameraAngles())
		
		-- make a view_projection matrix
		self.vp_matrix = view * projection
					
		-- render the scene with this matrix
		self.shadow_map:Begin("depth")
			self.shadow_map:Clear()
			event.Call("Draw3DGeometry", shader, self.vp_matrix)
		self.shadow_map:End("depth")
	end
end

function COMPONENT:OnDrawLensFlare(shader)
	if not self.LensFlare or not self.screen_matrix then return end
	local x, y, z = self.screen_matrix:GetClipCoordinates()
	
	shader.pvm_matrix = self.screen_matrix.m
	
	if z > -1 then
		shader.screen_pos:Set(x, y)
	else
		shader.screen_pos:Set(-2,-2)
	end
	
	shader.intensity = self.DiffuseIntensity^0.25
	
	shader:Bind()
	self.light_mesh:Draw()
end

prototype.RegisterComponent(COMPONENT)

if RELOAD then
	render.InitializeGBuffer()
	
	do return end
	event.Delay(0.1, function()
	world.sun:SetShadow(true)
	world.sun:SetPosition(render.GetCameraPosition()) 
	world.sun:SetAngles(render.GetCameraAngles()) 
	world.sun:SetFOV(render.GetCameraFOV())
	world.sun:SetSize(1000) 
	end) 
end