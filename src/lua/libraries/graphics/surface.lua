local surface = _G.surface or {}

local gl = desire("libopengl")
local render = render

local SHADER = {
	name = "mesh_2d",
	vertex = {
		mesh_layout = {
			{pos = "vec3"},
			{uv = "vec2"},
			{color = "vec4"},
		},
		source = "gl_Position = g_projection_view_world_2d * vec4(pos, 1);"
	},
	fragment = {
		mesh_layout = {
			{uv = "vec2"},
			{color = "vec4"},
		},
		source = [[
			out highp vec4 frag_color;

			void main()
			{
				vec4 tex_color = texture(lua[tex = "sampler2D"], uv);
				vec4 override = lua[color_override = Color(0,0,0,0)];

				if (override.r > 0) tex_color.r = override.r;
				if (override.g > 0) tex_color.g = override.g;
				if (override.b > 0) tex_color.b = override.b;
				if (override.a > 0) tex_color.a = override.a;

				frag_color = tex_color * color * lua[global_color = Color(1,1,1,1)];
				frag_color.a = frag_color.a * lua[alpha_multiplier = 1];

				vec3 hsv_mult = lua[hsv_mult = Vec3(1,1,1)];

				if (hsv_mult != vec3(1,1,1))
				{
					frag_color.rgb = hsv2rgb(rgb2hsv(frag_color.rgb) * hsv_mult);
				}
			}
		]]
	}
}

local RECT = {
	{pos = {0, 1, 0}, uv = {0, 0}, color = {1,1,1,1}},
	{pos = {0, 0, 0}, uv = {0, 1}, color = {1,1,1,1}},
	{pos = {1, 1, 0}, uv = {1, 0}, color = {1,1,1,1}},
	{pos = {1, 0, 0}, uv = {1, 1}, color = {1,1,1,1}},
	{pos = {1, 1, 0}, uv = {1, 0}, color = {1,1,1,1}},
	{pos = {0, 0, 0}, uv = {0, 1}, color = {1,1,1,1}},
}

function surface.CreateMesh(vertices, indices)
	vertices = vertices or RECT
	return render.CreateVertexBuffer(surface.mesh_2d_shader, vertices, indices)
end

surface.mesh_2d_shader = surface.mesh_2d_shader or NULL

function surface.Initialize()
	local shader = render.CreateShader(SHADER)
	surface.mesh_2d_shader = shader

	surface.rect_mesh = surface.CreateMesh()
	surface.rect_mesh:SetDrawHint("static")

	surface.SetWhiteTexture()

	surface.ready = true
end

function surface.IsReady()
	return surface.ready == true
end

function surface.GetSize()
	return render.camera_2d.Viewport.w, render.camera_2d.Viewport.h
end

do -- render world matrix helpers
	local ceil =math.ceil
	function surface.Translate(x, y, z)
		render.camera_2d:TranslateWorld(ceil(x), ceil(y), z or 0)
	end

	function surface.Translatef(x, y, z)
		render.camera_2d:TranslateWorld(x, y, z or 0)
	end

	function surface.Rotate(a)
		render.camera_2d:RotateWorld(a, 0, 0, 1)
	end

	function surface.Scale(w, h, z)
		render.camera_2d:ScaleWorld(w, h or w, z or 1)
	end

	function surface.Shear(x, y)
		render.camera_2d:ShearWorld(x, y, 0)
	end

	function surface.LoadIdentity()
		render.camera_2d:LoadIdentityWorld()
	end

	function surface.PushMatrix(x,y, w,h, a, dont_multiply)
		render.camera_2d:PushWorld(nil, dont_multiply)

		if x and y then surface.Translate(x, y) end
		if w and h then surface.Scale(w, h) end
		if a then surface.Rotate(a) end
	end

	function surface.PopMatrix()
		render.camera_2d:PopWorld()
	end

	function surface.SetWorldMatrix(mat)
		render.camera_2d:SetWorld(mat)
	end

	function surface.GetWorldMatrix()
		return render.camera_2d:GetWorld()
	end

	function surface.ScreenToWorld(x, y)
		return render.camera_2d:ScreenToWorld(x, y)
	end

	function surface.Start3D2D(pos, ang, scale)
		render.camera_2d:Start3D2DEx(pos, ang, scale)
	end

	function surface.End3D2D()
		render.camera_2d:End3D2D()
	end
end

do
	function surface.SetColor(r, g, b, a)
		surface.mesh_2d_shader.global_color.r = r
		surface.mesh_2d_shader.global_color.g = g
		surface.mesh_2d_shader.global_color.b = b
		surface.mesh_2d_shader.global_color.a = a or surface.mesh_2d_shader.global_color.a
	end

	function surface.GetColor()
		return surface.mesh_2d_shader.global_color:Unpack()
	end

	utility.MakePushPopFunction(surface, "Color")

	function surface.SetAlpha(a)
		surface.mesh_2d_shader.global_color.a = a
	end

	function surface.GetAlpha()
		return surface.mesh_2d_shader.global_color.a
	end

	utility.MakePushPopFunction(surface, "Alpha")
end

function surface.SetAlphaMultiplier(a)
	surface.mesh_2d_shader.alpha_multiplier = a or surface.mesh_2d_shader.alpha_multiplier
end

function surface.GetAlphaMultiplier()
	return surface.mesh_2d_shader.alpha_multiplier
end

utility.MakePushPopFunction(surface, "AlphaMultiplier")

function surface.SetTexture(tex)
	surface.mesh_2d_shader.tex = tex
end

function surface.GetTexture()
	return surface.mesh_2d_shader.tex
end

utility.MakePushPopFunction(surface, "Texture")

function surface.SetWhiteTexture()
	surface.mesh_2d_shader.tex = render.GetWhiteTexture()
end

do
	--[[{
		{pos = {0, 0}, uv = {xbl, ybl}, color = color_bottom_left},
		{pos = {0, 1}, uv = {xtl, ytl}, color = color_top_left},
		{pos = {1, 1}, uv = {xtr, ytr}, color = color_top_right},

		{pos = {1, 1}, uv = {xtr, ytr}, color = color_top_right},
		{pos = {1, 0}, uv = {xbr, ybr}, color = mesh_data[1].color},
		{pos = {0, 0}, uv = {xbl, ybl}, color = color_bottom_left},
	})]]

	-- sdasdasd

	local last_xtl = 0
	local last_ytl = 0
	local last_xtr = 1
	local last_ytr = 0

	local last_xbl = 0
	local last_ybl = 1
	local last_xbr = 1
	local last_ybr = 1

	local last_color_bottom_left = Color(1,1,1,1)
	local last_color_top_left = Color(1,1,1,1)
	local last_color_top_right = Color(1,1,1,1)
	local last_color_bottom_right = Color(1,1,1,1)

	local function update_vbo()

		if
			last_xtl ~= surface.rect_mesh.Vertices[0].uv.A or
			last_ytl ~= surface.rect_mesh.Vertices[0].uv.B or
			last_xtr ~= surface.rect_mesh.Vertices[4].uv.A or
			last_ytr ~= surface.rect_mesh.Vertices[4].uv.B or

			last_xbl ~= surface.rect_mesh.Vertices[1].uv.A or
			last_ybl ~= surface.rect_mesh.Vertices[0].uv.B or
			last_xbr ~= surface.rect_mesh.Vertices[3].uv.A or
			last_ybr ~= surface.rect_mesh.Vertices[3].uv.B or

			last_color_bottom_left ~= surface.rect_mesh.Vertices[1].color or
			last_color_top_left ~= surface.rect_mesh.Vertices[0].color or
			last_color_top_right ~= surface.rect_mesh.Vertices[2].color or
			last_color_bottom_right ~= surface.rect_mesh.Vertices[3].color
		then

			surface.rect_mesh:UpdateBuffer()

			last_xtl = surface.rect_mesh.Vertices[0].uv.A
			last_ytl = surface.rect_mesh.Vertices[0].uv.B
			last_xtr = surface.rect_mesh.Vertices[4].uv.A
			last_ytr = surface.rect_mesh.Vertices[4].uv.B

			last_xbl = surface.rect_mesh.Vertices[1].uv.A
			last_ybl = surface.rect_mesh.Vertices[0].uv.B
			last_xbr = surface.rect_mesh.Vertices[3].uv.A
			last_ybr = surface.rect_mesh.Vertices[3].uv.B

			last_color_bottom_left = surface.rect_mesh.Vertices[1].color
			last_color_top_left = surface.rect_mesh.Vertices[0].color
			last_color_top_right = surface.rect_mesh.Vertices[2].color
			last_color_bottom_right = surface.rect_mesh.Vertices[3].color
		end
	end

	do
		local X, Y, W, H, SX, SY

		function surface.SetRectUV(x,y, w,h, sx,sy)
			if not x then
				surface.rect_mesh.Vertices[1].uv.A = 0
				surface.rect_mesh.Vertices[0].uv.B = 0
				surface.rect_mesh.Vertices[1].uv.B = 1
				surface.rect_mesh.Vertices[2].uv.A = 1
			else
				sx = sx or 1
				sy = sy or 1

				y = -y - h

				surface.rect_mesh.Vertices[1].uv.A = x / sx
				surface.rect_mesh.Vertices[0].uv.B = y / sy
				surface.rect_mesh.Vertices[1].uv.B = (y + h) / sy
				surface.rect_mesh.Vertices[2].uv.A = (x + w) / sx
			end

			surface.rect_mesh.Vertices[0].uv.A = surface.rect_mesh.Vertices[1].uv.A
			surface.rect_mesh.Vertices[2].uv.B = surface.rect_mesh.Vertices[0].uv.B
			surface.rect_mesh.Vertices[4].uv = surface.rect_mesh.Vertices[2].uv
			surface.rect_mesh.Vertices[3].uv.A = surface.rect_mesh.Vertices[2].uv.A
			surface.rect_mesh.Vertices[3].uv.B = surface.rect_mesh.Vertices[1].uv.B
			surface.rect_mesh.Vertices[5].uv = surface.rect_mesh.Vertices[1].uv

			update_vbo()

			X = x
			Y = y
			W = w
			H = h
			SX = sx
			SY = sy
		end

		function surface.GetRectUV()
			return X, Y, W, H, SX, SY
		end

		function surface.SetRectUV2(u1,v1, u2,v2)
			surface.rect_mesh.Vertices[1].uv.A = u1
			surface.rect_mesh.Vertices[0].uv.B = v1
			surface.rect_mesh.Vertices[1].uv.B = u2
			surface.rect_mesh.Vertices[2].uv.A = v2

			surface.rect_mesh.Vertices[0].uv.A = surface.rect_mesh.Vertices[1].uv.A
			surface.rect_mesh.Vertices[2].uv.B = surface.rect_mesh.Vertices[0].uv.B
			surface.rect_mesh.Vertices[4].uv = surface.rect_mesh.Vertices[2].uv
			surface.rect_mesh.Vertices[3].uv.A = surface.rect_mesh.Vertices[2].uv.A
			surface.rect_mesh.Vertices[3].uv.B = surface.rect_mesh.Vertices[1].uv.B
			surface.rect_mesh.Vertices[5].uv = surface.rect_mesh.Vertices[1].uv

			update_vbo()
		end
	end

	function surface.SetRectColors(cbl, ctl, ctr, cbr)
		if not cbl then
			for i = 1, 6 do
				surface.rect_mesh.Vertices[i].color = {1,1,1,1}
			end
		else
			surface.rect_mesh.Vertices[1].color = {cbl:Unpack()}
			surface.rect_mesh.Vertices[0].color = {ctl:Unpack()}
			surface.rect_mesh.Vertices[2].color = {ctr:Unpack()}
			surface.rect_mesh.Vertices[4].color = surface.rect_mesh.Vertices[2].color
			surface.rect_mesh.Vertices[3].color = {cbr:Unpack()}
			surface.rect_mesh.Vertices[5].color = surface.rect_mesh.Vertices[0]
		end

		update_vbo()
	end
end

function surface.DrawRect(x,y, w,h, a, ox,oy)
	surface.PushMatrix()
		if x and y then
			surface.Translate(x, y)
		end

		if a then
			surface.Rotate(a)
		end

		if ox then
			surface.Translate(-ox, -oy)
		end

		if w and h then
			surface.Scale(w, h)
		end

		surface.rect_mesh:Draw()
	surface.PopMatrix()
end

function surface.DrawLine(x1,y1, x2,y2, w, skip_tex, ox, oy)
	w = w or 1

	if not skip_tex then
		surface.SetWhiteTexture()
	end

	local dx,dy = x2-x1, y2-y1
	local ang = math.atan2(dx, dy)
	local dst = math.sqrt((dx * dx) + (dy * dy))

	ox = ox or (w*0.5)
	oy = oy or 0

	surface.DrawRect(x1, y1, w, dst, -ang, ox, oy)
end

function surface.SetScissor(x, y, w, h)
	if not x then
		render.SetScissor()
	else
		x, y = surface.ScreenToWorld(-x, -y)
		render.SetScissor(-x, -y, w, h)
	end
end

do
    local stack = {}
	local depth = 1

	local stencil_debug_tex

	function surface.DrawStencilTexture()

	    stencil_debug_tex = stencil_debug_tex or render.CreateBlankTexture(Vec2(render.GetWidth(), render.GetHeight()))

		local stencilStateArray = ffi.new("GLboolean[1]", 0)
		gl.GetBooleanv("GL_STENCIL_TEST", stencilStateArray)

		--if wait(0.25) then

			gl.Enable("GL_STENCIL_TEST")

			local stencilWidth = render.GetWidth()
			local stencilHeight = render.GetHeight()
			local stencilSize = stencilWidth*stencilHeight
			local stencilData = ffi.new("unsigned char[?]", stencilSize)
			gl.ReadPixels(0, 0, stencilWidth, stencilHeight, "GL_STENCIL_INDEX", "GL_UNSIGNED_BYTE", stencilData)

			--[[for y = 0, stencilHeight-1 do
				for x = 0, stencilWidth-1 do
					local i = y*stencilWidth + x
					io.stdout:write(string.format("%02X ", stencilData[i]))
				end
				io.stdout:write("\n")
			end]]

			local y = math.floor(stencilHeight/2)
			for x = math.floor(stencilWidth/2-10), math.floor(stencilWidth/2+10) do
				local i = y*stencilWidth + x
				stencilData[i] = 1
			end

			local maxValue = 0
			for i = 0, stencilSize-1 do
				maxValue = math.max(maxValue, stencilData[i])
			end

			local scale = 255/maxValue
			for i = 0, stencilSize-1 do
				stencilData[i] = math.floor(stencilData[i]*scale)
			end

			stencil_debug_tex:Upload(stencilData, {upload_format = "red", internal_format = "r8"})
		--end

		surface.PushMatrix()
		surface.LoadIdentity()
    		surface.SetColor(1,1,1,1)
    		surface.SetTexture(stencil_debug_tex)
    		gl.Disable("GL_STENCIL_TEST")
    		surface.DrawRect(64,64,128,128)
    		gl.Enable("GL_STENCIL_TEST")
		surface.PopMatrix()

		if stencilStateArray[0] == 0 then
		    gl.Disable("GL_STENCIL_TEST")
	    end
    end

	function surface.EnableStencilClipping()
		--assert(#stack == 0, "I think this is good assertion, wait, you may want to draw something regardless of clipping, so nvm")
		--table.clear(stack)
		-- that means the stack should not be emptied, in case you want to disobey clipping?

		-- Don't consider depth buffer while stenciling or drawing
		gl.DepthMask(0)
		gl.DepthFunc("GL_ALWAYS")

		-- Enable stencil test
		gl.Enable("GL_STENCIL_TEST")

		-- Write to all stencil bits
		gl.StencilMask(0xFF)

		-- Don't consider stencil buffer while clearing it
		gl.StencilFunc("GL_ALWAYS", 0, 0xFF)

		-- Clear the stencil buffer to zero
		gl.ClearStencil(0)
		gl.Clear("GL_STENCIL_BUFFER_BIT")

		-- Stop writing to stencil
		gl.StencilMask("GL_FALSE")
	end

	function surface.DisableStencilClipping()
		-- disable stencil completely, how2
		gl.Disable("GL_STENCIL_TEST")
	end

    --[[
		it works like this:

		00000000000000000000000000
	    push frame; depth = 1
    		00011111111111111000000000
		    push panel; depth = 2
        		00011222222222211000000000
        		push button1; depth = 3
        		    00011233322222211000000000
    		    pop button1; depth = 2
    		    00011222222222211000000000
    		    push button2; depth = 3
    		        00011222222333211000000000
		        pop button2; depth = 2
		        00011222222222211000000000
	        pop panel; depth = 1
	        00011111111111111000000000
        pop frame; depth = 0
        00000000000000000000000000

        gl.StencilFunc("GL_EQUAL", depth, 0xFF)
        means
        only draw if stencil == current depth
	]]

	local function update_stencil_buffer(mode)

		-- Write to all stencil bits
		gl.StencilMask(0xFF)

		-- For each object on the stack, increment/decrement any pixel it touches by 1
		gl.DepthMask(0) -- Don't write to depth buffer
		gl.StencilFunc("GL_NEVER", 0, 0xFF) -- Update stencil regardless of current value
		gl.StencilOp(
			mode, -- For each pixel white pixel, increment/decrement
			"GL_REPLACE", -- Ignore depth buffer
			"GL_REPLACE" -- Ignore depth buffer
		)

		local data = stack[depth]
		data.func(unpack(data.args))

		-- Stop writing to stencil
		gl.StencilMask("GL_FALSE")

		-- Now make future drawing obey stencil buffer
		gl.DepthMask(1) -- Write to depth buffer
		gl.StencilFunc("GL_EQUAL", depth-1, 0xFF) -- Pass test if stencil value is equal to depth
	end

	function surface.PushClipFunction(draw_func, ...)
	    depth = depth+1

		stack[depth] = {func = draw_func, args = {...}}

		update_stencil_buffer("GL_INCR")
	end

	function surface.PopClipFunction()
		update_stencil_buffer("GL_DECR")

		stack[depth] = nil
		depth = depth-1

		if depth < 1 then
			error("stack underflow", 2)
		end
	end
end

do
	local X, Y, W, H
	function surface.EnableClipRect(x, y, w, h)
		gl.Enable("GL_STENCIL_TEST")

		gl.StencilFunc("GL_ALWAYS", 1, 0xFF) -- Set any stencil to 1
		gl.StencilOp("GL_KEEP", "GL_KEEP", "GL_REPLACE")
		gl.StencilMask(0xFF) -- Write to stencil buffer
		render.GetFrameBuffer():ClearStencil(0xFF) -- Clear stencil buffer (0 by default)

		surface.PushColor(0,0,0,0)
		surface.DrawRect(x, y, w, h)
		surface.PopColor()

		gl.StencilFunc("GL_EQUAL", 1, 0xFF) -- Pass test if stencil value is 1
		gl.StencilMask(0x00) -- Don't write anything to stencil buffer

		X = x
		Y = y
		W = w
		H = h
	end

	function surface.GetClipRect()
		return X or 0, Y or 0, W or render.GetWidth(), H or render.GetHeight()
	end

	function surface.DisableClipRect()
		gl.Disable("GL_STENCIL_TEST")
	end
end

function surface.GetMousePosition()
	if window.GetMouseTrapped() then
		return render.GetWidth() / 2, render.GetHeight() / 2
	end
	return window.GetMousePosition():Unpack()
end

local last_x = 0
local last_y = 0
local last_diff = 0

function surface.GetMouseVel()
	local x, y = window.GetMousePosition():Unpack()

	local vx = x - last_x
	local vy = y - last_y

	local time = system.GetElapsedTime()

	if last_diff < time then
		last_x = x
		last_y = y
		last_diff = time + 0.1
	end

	return vx, vy
end

function surface.SetHSV(h,s,v)
	surface.mesh_2d_shader.hsv_mult.x = h
	surface.mesh_2d_shader.hsv_mult.y = s
	surface.mesh_2d_shader.hsv_mult.z = v
end

function surface.GetHSV()
	return surface.mesh_2d_shader.hsv_mult:Unpack()
end

utility.MakePushPopFunction(surface, "HSV")

do -- effects
	function surface.EnableEffects(b)
		if b then
			local fb = render.CreateFrameBuffer()
			fb:SetTexture(1, render.CreateBlankTexture(render.GetScreenSize()))
			fb:SetTexture("depth_stencil", {internal_format = "depth_stencil", size = render.GetScreenSize()})
			fb:CheckCompletness()

			surface.framebuffer = fb
		elseif surface.framebuffer then
			surface.framebuffer = nil
		end
	end

	surface.effects = {}

	function surface.AddEffect(name, pos, ...)
		surface.RemoveEffect(name)

		table.insert(surface.effects, {name = name, pos = pos, args = {...}})

		table.sort(surface.effects, function(a, b)
			return a.pos > b.pos
		end)
	end

	function surface.RemoveEffect(name)
		for i, info in ipairs(surface.effects) do
			if info.name == name then
				table.remove(surface.effects, i)
			end
		end

		table.sort(surface.effects, function(a, b)
			return a.pos > b.pos
		end)
	end

	function surface.Start()
		if surface.framebuffer then
			surface.framebuffer:Begin()
		end
	end

	function surface.End()
		if surface.framebuffer then
			for _, info in ipairs(surface.effects) do
				surface.framebuffer:GetTexture():Shade(unpack(info.args))
			end

			surface.framebuffer:End()

			surface.framebuffer:Blit(render.GetScreenFrameBuffer())
		end
	end
end

if RELOAD then
	surface.Initialize()
end

return surface