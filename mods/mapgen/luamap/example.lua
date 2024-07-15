-- forces the map into singlenode mode, don't do this if this is just a "realm".
luamap.set_singlenode()

-- creates a terrain noise
luamap.register_noise("terrain",{
    type = "2d",
    np_vals = {
        offset = 0,
        scale = 1,
        spread = {x=384, y=256, z=384},
        seed = 5900033,
        octaves = 5,
        persist = 0.63,
        lacunarity = 2.0,
        flags = ""
    },

})


local c_stone = minetest.get_content_id("default:stone")
local c_water = minetest.get_content_id("default:water_source")

local water_level = 0

local old_logic = luamap.logic

function luamap.logic(noise_vals,x,y,z,seed,original_content)

    -- get any terrain defined in another mod
    local content = old_logic(noise_vals,x,y,z,seed,original_content)

    if y < water_level then
        content = c_water
    end
    if y < noise_vals.terrain * 50 then
        content = c_stone
    end

    return content
end