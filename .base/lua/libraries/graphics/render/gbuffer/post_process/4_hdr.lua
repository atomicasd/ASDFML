local PASS = {}

PASS.Name = "hdr"
PASS.Default = false
PASS.Position = FILE_NAME:sub(1, 1)

PASS.Variables = {
	tex_area = "sampler2D",
	tex_extracted = "sampler2D",
	bloom_factor = 0.005,
	exposure = 0.75,
}

function PASS:Initialize()
	self.fb = render.CreateFrameBuffer(render.GetWidth()/2, render.GetHeight()/2)
	self.area = render.CreateFrameBuffer(1,1)
	
	self.exposure = 1
	self.smooth_exposure = 1
	
	self.extract = render.CreateShader([[				
		vec4 color = vec4(1,1,1,1);
		color.rgb = pow(texture(self, uv).rgb, vec3(3));
		return color;
	]], {self = self.fb:GetTexture()})
	
	self.blur = render.CreateShader([[
		float dx = blur_size / g_screen_size.x;
		float dy = blur_size / g_screen_size.y;
		
		vec4 color = 4.0 * texture(self, uv);
		color += texture(self, uv + vec2(+dx, 0.0)) * 2.0;
		color += texture(self, uv + vec2(-dx, 0.0)) * 2.0;
		color += texture(self, uv + vec2(0.0, +dy)) * 2.0;
		color += texture(self, uv + vec2(0.0, -dy)) * 2.0;
		color += texture(self, uv + vec2(+dx, +dy));
		color += texture(self, uv + vec2(-dx, +dy));
		color += texture(self, uv + vec2(-dx, -dy));
		color += texture(self, uv + vec2(+dx, -dy));
		
		color.rgb /= 16;
		color.a = 1;
		
		return color;
	]], {
		self = self.fb:GetTexture(), 
		blur_size = 1,
	})
end

function PASS:Update()
	self.fb:Copy(render.gbuffer_mixer_buffer)
	
	render.SetBlendMode("alpha")
	
	surface.PushMatrix(0, 0, self.fb.w, self.fb.h)
		self.fb:Begin()
			--self.shader.exposure = 1
			self.extract:Bind()
			surface.rect_mesh:Draw()
		self.fb:End()
		
		for i = 1,4 do
			self.blur.blur_size = i
			self.fb:Begin()
				self.blur:Bind()
				surface.rect_mesh:Draw()
			self.fb:End()
		end
	surface.PopMatrix()
	
	
	--if not self.next_update or self.next_update < system.GetElapsedTime() then
		--self.area:Copy(render.gbuffer_mixer_buffer)
		--[[self.area:Begin()	
			local r,g,b = render.ReadPixels(0,0, 1,1)
			if r and g and b then
				self.exposure = math.clamp((-math.max(r,g,b)+1) * 2, 0.2, 1) ^ 0.5  
			end
		self.area:End()]]
	--	self.next_update = system.GetElapsedTime() + 1/30
	--end
		
	--self.smooth_exposure = self.smooth_exposure or 0
	--self.smooth_exposure = math.lerp(render.delta, self.smooth_exposure, self.exposure)
	
	self.shader.tex_extracted = self.fb:GetTexture()
	self.shader.tex_area = self.area:GetTexture()
end


function PASS:PostRender()
	self.area:Copy(render.gbuffer_mixer_buffer)
end

PASS.Source = [[
	out vec4 out_color;
		
	void main() 
	{ 	
		//float prev_exposure = clamp(-(length(texture(tex_area, uv).rgb)/3) +1, 0, 1);
		out_color.rgb = 1 - exp2(-((texture(self, uv).rgb) + (bloom_factor * (texture(tex_extracted, uv).rgb)*1.75)) * (exposure));
		out_color.rgb *= (-bloom_factor+1)*1.75;
		out_color.a = 1;
	}
]]

render.AddGBufferShader(PASS)