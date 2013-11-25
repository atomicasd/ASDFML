local function parse_scene(scene, dir)

	print("PARSING SCENE")

	local out = {}
	
	out = {}
			
	for i = 0, scene.mNumMeshes-1 do
		local mesh = scene.mMeshes[i]
		
		local sub_model = {mesh_data = {}}
		
		for i = 0, scene.mMeshes[i].mNumVertices-1 do
			local data = {}
			
			if mesh.mVertices ~= nil then
				local val = mesh.mVertices[i]
				data.pos = {val.x, val.y, val.z}
			end

			if mesh.mNormals ~= nil then
				local val = mesh.mNormals[i]
				data.normal = {val.x, val.y, val.z}
			end

			if mesh.mTangents ~= nil then
				local val = mesh.mTangents[i]
				data.tangent = {val.x, val.y, val.z}
			end	
						
			if mesh.mTextureCoords ~= nil then
				local val = mesh.mTextureCoords[0] and mesh.mTextureCoords[0][i]
				data.uv = {val.x, val.y}
			end
			
			sub_model.mesh_data[#sub_model.mesh_data+1] = data
		end
				
		sub_model.name = ffi.string(mesh.mName.data, mesh.mName.length):trim()
		
		if mesh.mMaterialIndex > 0 then
			local mat = scene.mMaterials[mesh.mMaterialIndex]
			sub_model.material = {}
			for i = 0, mat.mNumProperties-1 do
				local property = mat.mProperties[i]
				local key = ffi.string(property.mKey.data, property.mKey.length)
				local val = ffi.string(property.mData, property.mDataLength)
				
				key = key:sub(2)
				val = val:sub(4) 
					
				val = val:gsub("(.)", function(char) if char:byte() == 0 then return "" end end) 
				
				if key == "mat.name" then
					sub_model.material.name = val
				end
				
				if key == "tex.file" and val then
					if val:sub(1,1) == "." then
						sub_model.material.path = vfs.FixPath(dir .. val:sub(2))
					else
						sub_model.material.path = vfs.FixPath(val)
					end
				end
			end
		end
				
		out[i] = sub_model
	end	
		
	print("DONE PARSING SCENE")
		
	return out
end

local META = {}
META.__index = META
META.Type = "model"

class.GetSet(META, "TextureOverride", NULL)

function META:Draw()
	for _, model in pairs(self.sub_models) do
		if self.TextureOverride:IsValid() then
			model.mesh.diffuse = self.TextureOverride
			model.mesh.bump = self.TextureOverride
			model.mesh.specular = self.TextureOverride
		else
			model.mesh.diffuse = model.diffuse
			model.mesh.bump = model.bump
			model.mesh.specular = model.specular
		end
		model.mesh:Draw()
	end
end

function META:IsValid()
	return true
end

function META:Remove()
	for _, model in pairs(self.sub_models) do
		model.mesh.diffuse:Remove()
		model.mesh.bump:Remove()
		model.mesh.specular:Remove()
		model.mesh:Remove()
	end
	
	utilities.MakeNull(self)
end

local format = {mip_map_levels = 4, mag_filter = e.GL_LINEAR_MIPMAP_LINEAR, min_filter = e.GL_LINEAR_MIPMAP_LINEAR,}

local function try_find(sub_model, path, key, a, b)
	-- try to find the normal
	local nrm = path:gsub("(.+)(%.)", "%1"..a.."%2")
	
	if nrm ~= path and vfs.Exists(nrm) then
		sub_model[key] = Image(nrm, format)
	else
		nrm = path:gsub("(.+)(%.)", "%1"..b.."%2")
		if nrm ~= path and vfs.Exists(nrm) then
			sub_model[key] = Image(nrm, format)
		else
			nrm = path:gsub("_diff%.", b.."%.")
			if nrm ~= path and vfs.Exists(nrm) then
				sub_model[key] = Image(nrm, format)
			else
				logf("could not find %s for %q", key, path)
			end
		end
	end				
end

local cache = {}

function Model(path)
	check(path, "string")
	
	if cache[path] then
		return cache[path]
	end
	
	local new_path = R(path)
	
	if not vfs.Exists(new_path) then
		error(new_path .. " not found", 2)
	end
	
	local scene = assimp.ImportFile(new_path,0)

	if not scene then
		error(ffi.string(assimp.GetErrorString()), 2)
	end
	
	models = parse_scene(scene, new_path:match("(.+)/"))	
	
	assimp.ReleaseImport(scene)
	
	local self = setmetatable({}, META)
	
	self.sub_models = {}
					
	for i, model in pairs(models) do
		local sub_model = {mesh = Mesh3D(model.mesh_data), name = model.name}
					
		if model.material and model.material.path then
			sub_model.diffuse = Image(model.material.path, format)

			try_find(sub_model, model.material.path, "bump", "_n", "_ddn")
			try_find(sub_model, model.material.path, "specular", "_s", "_spec")
		else
			sub_model.diffuse = Image("error")
		end

		--sub_model.diffuse = Image("error")
		
		if not sub_model.bump then
			sub_model.bump = Texture(8,8):Fill(function() return 255, 255, 255, 255 end)
		end
		
		if not sub_model.specular then
			sub_model.specular = Texture(8,8):Fill(function() return 255, 255, 255, 255 end)
		end	
		
		sub_model.diffuse:SetChannel(1)
		sub_model.bump:SetChannel(2)
		sub_model.specular:SetChannel(3)

		self.sub_models[i] = sub_model
		
	--	I = i
	end
		
	cache[path] = self
	
	return self 
end
