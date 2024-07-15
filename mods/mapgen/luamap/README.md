## Intro and usage
Luamap is a library for modders to focus on mapgen logic rather than figuruing
out how mapgen works. using it is simple: override the luamap.logic function.
The goal of the luamap logic function is to return a content id at a point.

Calling the old logic function before running your own logic allows you to add
to other mods that use luamap. If you do not save and call the old luamap
function, then your mod will completely override any other mapgens made by other
mods using luamap.

```lua
local c_stone = minetest.get_content_id("default:stone")
local c_water = minetest.get_content_id("default:water_source")
local water_level = 0
local old_logic = luamap.logic
function luamap.logic(noise_vals,x,y,z,seed,original_content)
    -- get any terrain defined in another mod
    local content = old_logic(noise_vals,x,y,z,seed,original_content)
    -- use our own logic to add to that logic 
    -- make any nodes below sea level water and below stone level stone
    if y < water_level then
        content = c_water
    end
    if y < -3 then
        content = c_stone
    end
    return content
end
```

This would make a flat mapgen covered in a layer of water.

luamap gives you an easy way to make and use 2d and 3d noises in your mapgen:

```lua
-- 2d noise mapgen
luamap.register_noise("terrainmap",{
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
    ymin = -31000,
    ymax = 31000,
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
    if y < noise_vals.terrainmap * 50 then
        content = c_stone
    end

    return content
end
```

you can also register a 3d noise like so:
```lua
luamap.register_noise("terrainmap",{
    type = "3d",
    np_vals = {
        offset = 0,
        scale = 1,
        spread = {x=384, y=384, z=384},
        seed = 5900033,
        octaves = 5,
        persist = 0.63,
        lacunarity = 2.0,
        flags = ""
    },
    ymin = -31000,
    ymax = 31000,
})
```

## API

### luamap.logic
```lua
luamap.logic(noise_vals,x,y,z,seed,original_content)
```

DESCRIPTION: Override this function to define mapgen logic. Best practice is to
save the original function and call it to get a preset content id from any
previously-defined mapgens.

PARAMETERS:

`noise_vals` 

A table indexed by noise names defined with `luamap.register_noise()`. So, if I
have registered 2 noises: `terrain_2d` and `caves_3d` then noisevals might be: 

```lua
{
    ["terrain_2d"] = .7,
    ["caves_3d"] = -.9,
}
```

`x,y,z`

The coordinates of the position to set the content for

`seed`

The seed passed to minetest.register_on_generated()

`original_content`

The original content of the mapgen

RETURNS:

should return a content id such as that gotten from
`minetest.get_content_id("nodename")`

NOTES:
remember that this function is called for every single node ever generated.
Keep your calculations fast or the mapgen will slow down.
2d noise is much faster than 3d noise.

### luamap.register_noise

```lua
luamap.register_noise(name,data)
```

DESCRIPTION: creates a mapgen noise that will be calculated and returned in
`luamap.logic`

PARAMETERS: 

`name`

String, the name of the noise

`data` 

table, the noise data:

```lua
{
    type = "2d", -- or "3d"
    np_vals = { -- noise params, see minetest lua api
        offset = 0,
        scale = 1,
        spread = {x=384, y=256, z=384},
        seed = 5900033,
        octaves = 5,
        persist = 0.63,
        lacunarity = 2.0,
        flags = ""
    },
    ymin = -31000,
    ymax = 31000,
}
```
NOTES:
`ymin` and `ymax` define a range in which to calculate the noise. This is useful
for making realms: a noise might not be needed in a certian y-range. Note that
if the position passed to `luamap.logic` is outside of the y-range, then
`noise_vals` will not contain that noise, which saves on calculation times. Be
sure to set the y-range to completely encompass the range that you expect to
find your noises. 


### luamap.precalc

```lua
luamap.precalc(data, area, vm, minp, maxp, seed)
```

DESCRIPTION: An overridable function called just before calculating the noise
and calling the logic function for each node.  Best practice is to save the old
function and call it before adding one's own logic, just like with
`luamap.logic`


### luamap.postcalc

```lua
luamap.postcalc(data, area, vm, minp, maxp, seed)
```

DESCRIPTION: An overridable function called just before setting the map lighting
and data after the noise has been calculated and luamap.logic has been called
for each node in the mapblock. It offers compatability with biomegen by Gaël de
Sailly, which needs these parameters to function. Best practice is to save the
old function and call it before adding one's own logic, just like with
`luamap.logic`

example:
```lua
local old_postcalc = luamap.precalc
function luamap.postcalc(data, area, vm, minp, maxp, seed)
    old_postcalc(data, area, vm, minp, maxp, seed)
    biomegen.generate_all(data, area, vm, minp, maxp, seed)
end
```

### luamap.set_singlenode

```lua
luamap.set_singlenode()
```

DESCRIPTION: Sets the mapgen to singlenode. Do not call this if you intend to
make a realm, only call if you intend to completely replace engine mapgens

No params, returns nothing.

## HELPER FUNCTIONS

### luamap.remap

```lua
luamap.remap(val, min_val, max_val, min_map, max_map)
```

DESCRIPTION: remaps a value between a range of values to a new range of values

PARAMETERS: 

`val`
value to remap
`min_val`
old range minimum
`max_val`
old range maximum
`min_map`
new range min
`max_map`
new range max

NOTES:

Minetest's perlin noises range from -2 to 2. If you want a noise that ranges
from 0 to 1, then you can use remap:

```lua
mynoise = noisevals.mynoise
mynoise = luamap.remap(mynoise, -2, 2, 0, 1)
```
### luamap.lerp

```lua
luamap.lerp(var_a, var_b, ratio, power)
```
DESCRIPTION: a linear interpolation function
Interpolates between 2 values

PARAMETERS:
`var_a`
first value to interpolate between

`var_b`
second value to interpolate between

`ratio` 
number between 0 and 1 interpolation ratio: 0 is 100% var_a, 1 is 100%
var_b, values between 0 and 1 return a mix of var_a and var_b

`power` 
(optional, default 1) controls the exponent of the power. By default, it
is 1, which gives linear interpolation. 3 would give cubic interpolation. 
Controls the shape of the interpolation curve.

NOTES:

useful for mixing two noises. If you use a third noise as the ratio, you can
have areas that are mostly controlled by one noise, and other areas controlled
by another noise.

### luamap.coserp

```lua
luamap.coserp(var_a,var_b,ratio)
```

DESCRIPTION:
Same as `luamap.lerp` but uses cosine interpolation for a smoother curve.



