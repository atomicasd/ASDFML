local love = ... or _G.love
local ENV = love._lovemu_env

love.filesystem = love.filesystem or {}

ENV.filesystem_identity = ENV.filesystem_identity or "none"

function love.filesystem.getAppdataDirectory()
	return R("data/lovemu/" .. ENV.filesystem_identity .. "/")
end

function love.filesystem.getSaveDirectory()
	return R("data/lovemu/" .. ENV.filesystem_identity .. "/")
end

function love.filesystem.getUserDirectory()
	return R("data/lovemu/" .. ENV.filesystem_identity .. "/")
end

function love.filesystem.getWorkingDirectory()
	return R("data/lovemu/" .. ENV.filesystem_identity .. "/")
end

function love.filesystem.getLastModified(path)
	return vfs.GetLastModified("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path) or vfs.GetLastModified(path)
end

function love.filesystem.enumerate(path)
	if path:sub(-1) ~= "/" then
		path = path .. "/"
	end

	if vfs.IsDirectory("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path) then
		return vfs.Find("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path)
	end

	return vfs.Find(path)
end

love.filesystem.getDirectoryItems = love.filesystem.enumerate

function love.filesystem.init()

end

function love.filesystem.isDirectory(path)
	return vfs.IsDirectory("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path) or vfs.IsDirectory(path)
end

function love.filesystem.isFile(path)
	return vfs.IsFile("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path) or vfs.IsFile(path)
end

function love.filesystem.exists(path)
	return vfs.Exists("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path) or vfs.Exists(path)
end

function love.filesystem.lines(path)
	local file = vfs.Open("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path)

	if not file then
		file = vfs.Open(path)
	end

	if file then
		return file:Lines()
	end
end

function love.filesystem.load(path)

	local func, err

	if lovemu.Type(path) == "FileData" then
		func, err = loadstring(path:getString())
	else
		func, err = vfs.loadfile("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path, mode)

		if not func then
			func, err = vfs.loadfile(path)
		end
	end

	if func then
		setfenv(func, getfenv(2))
	end

	return func, err
end

function love.filesystem.mkdir(path)
	vfs.OSCreateDirectory(R("data/") .. "lovemu/")
	vfs.OSCreateDirectory(R("data/lovemu/") .. ENV.filesystem_identity .. "/")
	vfs.OSCreateDirectory(R("data/lovemu/" .. ENV.filesystem_identity .. "/") .. path)

	return true
end

love.filesystem.createDirectory = love.filesystem.mkdir

function love.filesystem.read(path, size)
	local file = vfs.Open("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path)

	if not file then
		file = vfs.Open(path)
	end

	if file then
		local str = file:ReadBytes(size or math.huge)
		if str then
			return str, #str
		else
			return "", 0
		end
	end
end

function love.filesystem.remove(path)
	wlog("attempted to remove folder/file " .. path)
end

function love.filesystem.setIdentity(name)
	vfs.OSCreateDirectory(R("data/") .. "lovemu/")
	vfs.OSCreateDirectory(R("data/lovemu/") .. name .. "/")

	ENV.filesystem_identity = name

	vfs.Mount(love.filesystem.getUserDirectory())
end

function love.filesystem.getIdentity()
	return ENV.filesystem_identity
end

function love.filesystem.write(path, data)
	vfs.Write("data/lovemu/" .. ENV.filesystem_identity .. "/" .. path, data)
	return true
end

function love.filesystem.isFused()
	return false
end

function love.filesystem.mount(from, to)
	if not vfs.IsDirectory("data/lovemu/" .. ENV.filesystem_identity .. "/" .. from) then
		vfs.Mount(from, "data/lovemu/" .. ENV.filesystem_identity .. "/" .. to)
		return vfs.IsDirectory(from)
	else
		vfs.Mount("data/lovemu/" .. ENV.filesystem_identity .. "/" .. from, "data/lovemu/" .. ENV.filesystem_identity .. "/" .. to)
		return true
	end
end

function love.filesystem.unmount(from)
	vfs.Unmount("data/lovemu/" .. ENV.filesystem_identity .. "/" .. from)
end

function love.filesystem.append(name, data, size)

end

do -- File object
	local File = lovemu.TypeTemplate("File")

	function File:close()
		if not self.file then return end
		self.file:Close()
	end

	function File:eof()
		if not self.file then return 0 end
		return self.file:TheEnd() ~= nil
	end

	function File:setBuffer(mode, size)
		if self.file then return false, "file not opened" end

		self.file:setvbuf(mode == "none" and "no" or mode, size)

		self.mode = mode
		self.size = size
	end

	function File:getBuffer()
		return self.mode, self.size
	end

	function File:getMode()
		return self.mode
	end

	function File:getFilename()
		if self.dropped then
			return self.path
		else
			return self.path:match(".+/(.+)")
		end
	end

	function File:getSize()
		return 10
	end

	function File:isOpen()
		return self.file ~= nil
	end

	function File:lines()
		if not self.file then return function() end end
		return self.file:Lines()
	end

	function File:read(bytes)
		if not bytes then
			local size = self.file:GetSize()
			local str = self.file:ReadAll()
			return str, size
		end
		local str = self.file:ReadBytes(bytes)
		return str, #str
	end

	function File:write(data, size)
		if lovemu.Type(data) == "string" then
			self.file:WriteBytes(data)
			return true
		elseif lovemu.Type(data) == "Data" then
			lovemu.ErrorNotSupported("Data not supported")
		end
	end

	function File:open(mode)
		if mode == "w" then mode = "write" end
		if mode == "r" then mode = "read" end

		logn("[lovemu] file open ", self.path, " ", mode)
		local path = self.path

		if mode == "w" then
			path = "data/lovemu/" .. ENV.filesystem_identity .. "/" .. self.path
		end

		self.file = assert(vfs.Open(path, mode))
		self.mode = mode
	end

	function love.filesystem.newFile(path, mode)
		local self = lovemu.CreateObject("File")
		self.path = path

		if mode then
			self:open(mode)
		end

		return self
	end

	lovemu.RegisterType(File)
end


do -- FileData object
	local FileData = lovemu.TypeTemplate("FileData")

	function FileData:getPointer()
		return ffi.cast("uint8_t *", self.contents)
	end

	function FileData:getSize()
		return #self.contents
	end

	function FileData:getString()
		return self.contents
	end

	function FileData:getExtension()
		return self.ext
	end

	function FileData:getFilename()
		return self.filename
	end

	function love.filesystem.newFileData(contents, name, decoder)
		if name then
			love.filesystem.write(name, contents)
		else
			contents = love.filesystem.read(name)
		end

		local self = lovemu.CreateObject("FileData")

		self.contents = contents
		self.filename, self.ext = name:match("(.+)%.(.+)")

		return self
	end

	lovemu.RegisterType(FileData)
end

event.AddListener("WindowFileDrop", "love", function(wnd, path)
	if love.filedropped then
		local file = love.filesystem.newFile(path)
		file.dropped = true
		love.filedropped(file)
	end
end)