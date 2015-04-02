local TOENUM = function(str) return "GL_" .. str:upper() end

local gl = require("graphics.ffi.opengl")

local META = prototype.CreateTemplate("texture2")

META:GetSet("StorageType", "2d")
META:GetSet("Size", Vec2())
META:GetSet("InternalFormat", "rgba8")
META:GetSet("MipMapLevels", 3)

function META:OnRemove()
	self.gl_tex:Delete()
end

function META:Upload(data)
	data.mip_map_level = data.mip_map_level or 0
	data.format = data.format or "rgba"
	data.type = data.type or "unsigned_byte"
	data.target = data.target or  "GL_TEXTURE_" .. self.StorageType:upper()
	
	if type(data.buffer) == "string" then 
		data.buffer = ffi.cast("uint8_t *", data.buffer) 
	end

	if not self.storage_setup then
		if self.StorageType == "3d" then
			self.gl_tex:Storage3D(
				self.MipMapLevels, 
				TOENUM(self.InternalFormat), 
				data.width, 
				data.height, 
				data.depth
			)	
		elseif self.StorageType == "2d" or self.StorageType == "rectangle" or self.StorageType == "cube_map" or self.StorageType == "2d_array" then		
			self.gl_tex:Storage2D(
				self.MipMapLevels, 
				TOENUM(self.InternalFormat), 
				data.width, 
				data.height
			)
		elseif self.StorageType == "1d" or self.StorageType == "1d_array" then		
			self.gl_tex:Storage1D(
				self.MipMapLevels, 
				TOENUM(self.InternalFormat), 
				data.width
			)
		end
		self.last_storage_setup = true
	end
	
	if self.StorageType == "cube_map" then
		data.z = data.face or data.z
		data.depth = data.depth or 1
	end
	
	if self.StorageType == "3d" or self.StorageType == "cube_map" or self.StorageType == "2d_array" then		
		data.x = data.x or 0
		data.y = data.y or 0
		data.z = data.z or 0
		
		if data.image_size then
			self.gl_tex:CompressedSubImage3D(
			data.mip_map_level, 
			data.x, 
			data.y, 
			data.z, 
			data.width, 
			data.height, 
			data.depth, 
			TOENUM(data.format), 
			TOENUM(data.type), 
			data.image_size, 
			data.buffer
		)
		else
			self.gl_tex:SubImage3D(
				data.mip_map_level, 
				data.x, 
				data.y, 
				data.z, 
				data.width, 
				data.height, 
				data.depth, 
				TOENUM(data.format), 
				TOENUM(data.type), 
				data.buffer
			)
		end		
	elseif self.StorageType == "2d" or self.StorageType == "1d_array" or self.StorageType == "rectangle" then		
		data.x = data.x or 0
		data.y = data.y or 0
	
		if data.image_size then
			self.gl_tex:CompressedSubImage2D(
				data.mip_map_level, 
				data.x, 
				data.y, 
				data.width, 
				data.height, 
				TOENUM(data.format), 
				TOENUM(data.type), 
				data.image_size, 
				data.buffer
			)
		else
			self.gl_tex:SubImage2D(
				data.mip_map_level, 
				data.x, 
				data.y, 
				data.width, 
				data.height, 
				TOENUM(data.format), 
				TOENUM(data.type), 
				data.buffer
			)
		end
	elseif self.StorageType == "1d" then		
		data.x = data.x or 0
		
		if data.image_size then
			self.gl_tex:CompressedSubImage1D(
				data.mip_map_level, 
				data.x, 
				data.width, 
				TOENUM(data.format), 
				TOENUM(data.type), 
				data.image_size, 
				data.buffer
			)
		else
			self.gl_tex:SubImage1D(
				data.mip_map_level, 
				data.x, 
				data.width, 
				TOENUM(data.format), 
				TOENUM(data.type), 
				data.buffer
			)
		end
	elseif self.StorageType == "buffer" then
		--self.gl_tex:Buffer(TOENUM(self.InternalFormat))
		--self.gl_tex:BufferRange(TOENUM(self.InternalFormat), )
		error("NYI", 2)
	end
	
	self.gl_tex:GenerateMipmap()
	
	self.Size.w = data.width
	self.Size.h = data.height
end

function META:Download()
	self.gl_tex:GetImage(0, "GL_RGBA", "GL_UNSIGNED_BYTE", bufSize, pixels)
end

function META:Bind(location)
	gl.BindTextureUnit(location, self.gl_tex.id)
end

META:Register()

local function Texture(storage_type)	
	local self = prototype.CreateObject(META)
	if storage_type then self:SetStorageType(storage_type) end
	self.gl_tex = gl.CreateTexture("GL_TEXTURE_" .. self.StorageType:upper())
	
	return self
end

local tex = Texture("cube_map")
local str = vfs.Read("textures/gui/skins/zsnes.png")
local buffer, w, h = require("graphics.ffi.devil").LoadImage(str, true)

for i = 0, 5 do
	tex:Upload({
		buffer = buffer,
		width = w,		
		height = h,
		format = "bgra",
		face = i,
	})
end

local shader = render.CreateShader({
	name = "test",
	fragment = {
		variables = {
			cam_dir = {vec3 = function() return render.camera_3d:GetAngles():GetForward() end},
		},
		mesh_layout = {
			{uv = "vec2"},
		},			
		source = [[
			#version 420
			#extension GL_NV_shadow_samplers_cube:enable
			
			layout(binding = 0) uniform samplerCube tex1;
			out highp vec4 frag_color;
			
			void main()
			{	
				vec4 tex_color = texture(tex1, cam_dir);
				
				frag_color = tex_color;
			}
		]],
	}
})

gl.Enable("GL_TEXTURE_CUBE_MAP") 

event.AddListener("PostDrawMenu", "lol", function()
	tex:Bind(0)
	surface.PushMatrix(0, 0, tex:GetSize():Unpack())
		render.SetShaderOverride(shader)
		surface.rect_mesh:Draw()
		render.SetShaderOverride()
	surface.PopMatrix()
end)
