-- calc_flag_center() calculates the center of a map from the positions of the flags.
function ctf_map.calc_flag_center(mapmeta)
	local flag_center = vector.zero()
	local flag_count = 0

	for _, team in pairs(mapmeta.teams) do
		flag_center = flag_center + team.flag_pos
		flag_count = flag_count + 1
	end

	flag_center = flag_center:apply(function(value)
		return value / flag_count
	end)

	return flag_center
end

function ctf_map.prepare_area(pos1, pos2, data, area)
	local c_air = minetest.get_content_id("air")
	local c_ind_glass = minetest.get_content_id("ctf_map:ind_glass")
	for index in area:iterp(pos1, pos2) do
		local p = area:position(index)
		if p.x == pos1.x or p.x == pos2.x or p.y == pos1.y or p.y == pos2.y or p.z == pos1.z or p.z == pos2.z then
			data[index] = c_ind_glass
		else
			data[index] = c_air
		end
	end
	return vector.add(pos1 , 1), vector.subtract(pos2, 1)
end

local function get_table_len(t)
	local length = 0
	for key, value in pairs(t) do
		length = length + 1
	end
	return length
end

function ctf_map.allocate_teams_territory(mapmeta)
	local min_x, min_z = mapmeta.pos1.x, mapmeta.pos1.z
	local max_x, max_z = mapmeta.pos2.x, mapmeta.pos2.z

	local num_teams = get_table_len(mapmeta.teams)

	-- Split the map into equal halves horizontally
	local half_x = (max_x - min_x) / num_teams

	local index = 0
	for team_name, _ in pairs(mapmeta.teams) do
		-- Calculate pos of the team area
		local team_min_x = min_x + index * half_x
		local team_max_x = team_min_x + half_x
		local team_min_z = min_z
		local team_max_z = max_z

		-- Calculate flag coordinates
		local flag_x = team_min_x + half_x / 2
		local flag_z = min_z + (max_z - min_z) / 2
		mapmeta.teams[team_name].flag_pos = vector.floor(vector.new(flag_x, 0, flag_z))

		mapmeta.teams[team_name].pos1 = vector.new(team_min_x, mapmeta.pos1.y, team_min_z)
		mapmeta.teams[team_name].pos2 = vector.new(team_max_x, mapmeta.pos2.y, team_max_z)

		index = index + 1
	end
end

function ctf_map.make_border(data, area, pos1, pos2, node)
	local c_barrier = minetest.get_content_id(node or "ctf_map:ind_glass_red")
	local c_water = minetest.get_content_id("default:water_source")
	local c_air = minetest.get_content_id("air")
	for index in area:iterp(pos1, pos2) do
		local p = area:position(index)
		-- Check if pos is on the boundary of area
		if (p.x == pos1.x or p.x == pos2.x or p.y == pos1.y or p.y == pos2.y or p.z == pos1.z or p.z == pos2.z) and
			(data[index] == c_air or data[index] == c_water) then

			data[index] = c_barrier
		end
	end
end

function ctf_map.place_flags(mapmeta, data, area, radius, find_flag_location_callback, on_flag_place_callback)
	local pos1, pos2 = mapmeta.pos1, mapmeta.pos2
	local c_air = minetest.get_content_id("air")

	for name, def in pairs(mapmeta.teams) do
		ctf_map.make_border(data, area, def.pos1, def.pos2)
		local new_flag_pos = def.flag_pos
		local flag_pos_found = false
		local success = false

		if find_flag_location_callback then
			new_flag_pos = find_flag_location_callback(name, def)
		else
			local attempts = 0
			local map_center = vector.divide(vector.add(pos1, pos2), 2)

			while not flag_pos_found do
				attempts = attempts + 1

				local tpos1 = vector.copy(def.pos1)
				local tpos2 = vector.copy(def.pos2)
				local offset = mapmeta.flag_offset_from_border or 20
				tpos1 = vector.add(tpos1, offset)
				tpos2 = vector.subtract(tpos2, offset)

				-- trying to place the flag farther away from each other
				local max_dist = 0
				local p
				for di = 1, 3 do
					local cp = vector.new(math.random(tpos1.x, tpos2.x), 0,  math.random(tpos1.z, tpos2.z))
					local curr_dist = vector.distance(map_center, cp)
					if curr_dist > max_dist then
						max_dist = curr_dist
						p = cp
					end
				end

				for y = pos1.y, pos2.y do
					local node_id = data[area:index(p.x, y, p.z)]
					if node_id and minetest.get_name_from_content_id(node_id) == "air" then

						new_flag_pos = vector.floor(vector.new(p.x, y, p.z))
						mapmeta.teams[name].flag_pos = new_flag_pos

						flag_pos_found = true
						minetest.debug(name .. " flag placed")
						break
					end
				end
				if attempts > 10 then
					new_flag_pos = def.flag_pos
					minetest.log("warning", "The " .. name .. " flag cannot be placed! Using default position.")
					break
				end
			end
		end

		local c_indwool = minetest.get_content_id("ctf_map:wool_" .. name)
		local fpos1 = vector.new(new_flag_pos.x - radius, new_flag_pos.y - 1, new_flag_pos.z - radius)
		local fpos2 = vector.new(new_flag_pos.x + radius, new_flag_pos.y + 2, new_flag_pos.z + radius)

		local handled = false
		if on_flag_place_callback then
			handled = on_flag_place_callback(name, new_flag_pos, fpos1, fpos2)
		end

		if handled == false then
			-- Clean up the team base area
			for index in area:iterp(fpos1, fpos2) do
				data[index] = c_air
			end

			for x = fpos1.x, fpos2.x do
				for z = fpos1.z, fpos2.z do
					data[area:index(x, new_flag_pos.y - 1, z)] = c_indwool
				end
			end
			data[area:indexp(new_flag_pos)] = minetest.get_content_id("ctf_modebase:flag")

			local team_chest_pos = vector.new(new_flag_pos.x + radius , new_flag_pos.y, new_flag_pos.z)
			data[area:indexp(team_chest_pos)] = minetest.get_content_id("ctf_teams:chest_" .. name)
		end
	end

	mapmeta.flag_center = ctf_map.calc_flag_center(mapmeta)
end
