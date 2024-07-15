-- LuaMap class
LuaMap = {}

function LuaMap:init()
    local obj = {
        noises_2d = {},
        noises_3d = {},
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end

function LuaMap:logic(noise_vals, on_pos, seed, original_content)
	return original_content or minetest.get_content_id("air")
end

-- override this functions
function LuaMap:precalc(data, area, vm, minp, maxp, seed) end
function LuaMap:postcalc(data, area, vm, minp, maxp, seed) end

function LuaMap.remap(val, min_val, max_val, min_map, max_map)
    return (val - min_val) / (max_val - min_val) * (max_map - min_map) + min_map
end

-- linear interpolation, optional power modifier
function LuaMap.lerp(var_a, var_b, ratio, power)
    if ratio > 1 then ratio = 1 end
    if ratio < 0 then ratio = 0 end
    power = power or 1
    return (1 - ratio) * (var_a ^ power) + (ratio * (var_b ^ power))
end

function LuaMap.coserp(var_a, var_b, ratio)
    if ratio > 1 then ratio = 1 end
    if ratio < 0 then ratio = 0 end
    local rat2 = (1 - math.cos(ratio * 3.14159)) / 2
    return (var_a * (1 - rat2) + var_b * rat2)
end

function LuaMap.generate_seed()
	return math.random(10000000, 99999999)
end

function LuaMap:add_noise_2D(name, data)
	self.noises_2d[name] = {
		np_vals = data.np_vals,
		nobj = nil,
		ymin = data.ymin or -31000,
		ymax = data.ymax or 31000
	}
end

function LuaMap:add_noise_3D(name, data)
	self.noises_3d[name] = {
		np_vals = data.np_vals,
		nobj = nil,
		ymin = data.ymin or -31000,
		ymax = data.ymax or 31000
	}
end

function LuaMap:generate(vm, emin, emax, area, data, minp, maxp, seed)
	self.noise_vals = {}
	-- localize vars
	local noises_2d = self.noises_2d
	local noises_3d = self.noises_3d
	local seed = seed or LuaMap.generate_seed()

	local sidelen = maxp.x - minp.x + 1
	local chulens3d = {x=sidelen, y=sidelen, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}

	local minpos3d = {x=minp.x, y=minp.y-16, z=minp.z}
	local minpos2d = {x=minp.x, y=minp.z}

	self.precalc(self, data, area, vm, minp, maxp, seed)

    for name,elements in pairs(noises_2d) do
		if not(maxp.y <= elements.ymin and minp.y >= elements.ymax) then
			noises_2d[name].nobj = noises_2d[name].nobj or minetest.get_perlin_map(noises_2d[name].np_vals, chulens2d)
			noises_2d[name].nvals = noises_2d[name].nobj:get_2d_map_flat(minpos2d)
			noises_2d[name].use = true
		else
			noises_2d[name].use = false
		end
    end

	for name,elements in pairs(noises_3d) do
		if not(maxp.y <= elements.ymin and minp.y >= elements.ymax) then
			noises_3d[name].nobj = noises_3d[name].nobj or minetest.get_perlin_map(noises_3d[name].np_vals, chulens3d)
			noises_3d[name].nvals = noises_3d[name].nobj:get_3d_map_flat(minpos3d)
			noises_3d[name].use = true
		else
			noises_3d[name].use = false
		end
    end

	local xstride, ystride, zstride = 1,sidelen,sidelen*sidelen


	local i2d = 1
	local i3dz = 1

	for z = minp.z, maxp.z do
		local i3dx=i3dz

		for x = minp.x, maxp.x do

			for name,elements in pairs(noises_2d) do
				if elements.use then
					self.noise_vals[name] = elements.nvals[i2d]
				end
			end

			local i3dy=i3dx
			for y = minp.y, maxp.y do
				local vi = area:index(x, y, z)
                for name,elements in pairs(noises_3d) do
					if elements.use then
                    	self.noise_vals[name] = elements.nvals[i3dy]
					end
                end
                data[vi] = self.logic(self, vector.new(x, y, z), seed, data[vi])
				i3dy = i3dy + ystride
			end

			i3dx = i3dx + xstride
			i2d = i2d + 1
		end
		i3dz=i3dz+zstride
	end
	self.postcalc(self, data, area, vm, minp, maxp, seed)
end