-- Project-local image maps for Drip Lab. UV tiles stay inside [0,1] on Legacy Craft.
PolyLax = PolyLax or {}
local Textures = {}
PolyLax.EquipmentTextures = Textures

local readers = {
    camo=function() return asset.camo end,
    ducky=function() return asset.ducky end,
    galaxy=function() return asset.galaxy end,
    zebra=function() return asset.zebra end
}

local white = color(255,255,255)
local V = vec3
local loaded, tiles = {}, {}
local mappedModels = setmetatable({}, {__mode="k"})

local function surface(image,roughness,metalness,environment)
    local standard = asset and asset.builtin and asset.builtin.Materials
    local result = craft.material(standard and standard.Standard or "Materials:Standard")
    result.diffuse, result.roughness, result.metalness = white, roughness or .78, metalness or 0
    result.map = image
    if environment then result.envMap = environment end
    return result
end

local function resolve(key)
    if not loaded[key] then
        local entry = {status="Missing asset"}
        loaded[key] = entry
        local found, ref = pcall(readers[key])
        if found and ref ~= nil then
            local decoded, image, width, height = pcall(function()
                local data = readImage(ref)
                return data,data and data.width,data and data.height
            end)
            if decoded and type(width)=="number" and type(height)=="number" and width>0 and height>0 then
                local bound, material = pcall(surface,image)
                if bound then
                    entry.image, entry.material = image, material
                    entry.variants = {}
                    entry.status = string.format("%d × %d • mapped",width,height)
                else
                    entry.status = "Craft map rejected"
                end
            else
                entry.status = "Image load failed"
            end
        end
    end
    return loaded[key]
end

function Textures.status(key)
    local entry = resolve(key)
    return entry.material ~= nil, entry.status
end

function Textures.material(key,roughness,metalness,environment)
    local entry = resolve(key)
    if not (entry.material and roughness) then return entry.material end
    local variant = roughness..":"..(metalness or 0)..":"..tostring(environment ~= nil)
    local mat = entry.variants[variant]
    if not mat then
        local ok, result = pcall(surface,entry.image,roughness,metalness,environment)
        mat = ok and result or entry.material
        entry.variants[variant] = mat
    end
    return mat
end

local function model(positions,normals,indices,uvs)
    local colors = {}
    for i=1,#positions do colors[i] = white end
    local result = craft.model()
    result.positions,result.normals,result.indices,result.uvs,result.colors =
        positions,normals,indices,uvs,colors
    return result
end

-- Separate rings at each repeat keep the map tiling even on a clamped sampler.
function Textures.shaft(repeats)
    if tiles[repeats] then return tiles[repeats] end
    local positions,normals,indices,uvs = {},{},{},{}
    local sides = 16
    for row=0,repeats-1 do
        local start = #positions + 1
        for edge=0,1 do
            local y = (row+edge)/repeats-.5
            for col=0,sides do
                local u = col/sides
                local angle = (col%sides)*2*math.pi/sides
                local x,z = math.cos(angle),math.sin(angle)
                positions[#positions+1] = V(x,y,z)
                normals[#normals+1] = V(x,0,z)
                uvs[#uvs+1] = vec2(u,edge)
            end
        end
        for col=0,sides-1 do
            local a,b = start+col,start+col+sides+1
            local index=#indices
            indices[index+1],indices[index+2],indices[index+3] = a,b,b+1
            indices[index+4],indices[index+5],indices[index+6] = a,b+1,a+1
        end
    end
    tiles[repeats] = model(positions,normals,indices,uvs)
    return tiles[repeats]
end

-- Keep the original triangles, including the holes between the actual woven
-- strings. The sleeve projection wraps an image onto each half of the limb.
function Textures.uvModel(source,projection)
    local variants = mappedModels[source]
    if not variants then variants = {} mappedModels[source] = variants end
    if variants[projection] then return variants[projection] end
    local positions,normals = source.positions,source.normals
    local x0,y0,z0,x1,y1,z1 = math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
    for _,p in ipairs(positions) do
        x0,y0,z0 = math.min(x0,p.x),math.min(y0,p.y),math.min(z0,p.z)
        x1,y1,z1 = math.max(x1,p.x),math.max(y1,p.y),math.max(z1,p.z)
    end
    local width,height,depth = math.max(.0001,x1-x0),math.max(.0001,y1-y0),math.max(.0001,z1-z0)
    local centerZ = (z0+z1)*.5
    local atan2 = math.atan2 or math.atan
    local uvs = {}
    for i,p in ipairs(positions) do
        local u,v = (p.x-x0)/width,(p.y-y0)/height
        if projection=="sleeve" then
            u = atan2(math.abs(p.x),p.z-centerZ)/math.pi
        elseif projection=="glove" then
            local n = normals[i]
            local nx,ny,nz = math.abs(n.x),math.abs(n.y),math.abs(n.z)
            if ny>nx and ny>nz then v=(p.z-z0)/depth
            elseif nx>nz then u=(p.z-z0)/depth end
        end
        uvs[i]=vec2(u,v)
    end
    variants[projection] = model(positions,normals,source.indices,uvs)
    return variants[projection]
end
