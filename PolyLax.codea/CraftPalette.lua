-- Bake authored mesh colors into Standard material inputs used by Legacy Craft.
PolyLax = PolyLax or {}
local Palette = {}
PolyLax.CraftPalette = Palette

local white = color(255,255,255)
local solids = setmetatable({}, {__mode="v"})

local function standard(paint)
    local materials = asset and asset.builtin and asset.builtin.Materials
    local mat = craft.material(materials and materials.Standard or "Materials:Standard")
    mat.diffuse,mat.roughness = paint,.89
    return mat
end

local function rgb(ink)
    return math.floor(ink.r+.5),math.floor(ink.g+.5),math.floor(ink.b+.5)
end

local function solid(swatch)
    local key = swatch[4]
    local mat = solids[key]
    if not mat then
        mat = standard(color(swatch[1],swatch[2],swatch[3]))
        solids[key] = mat
    end
    return mat
end

local function makeModel(positions,normals,indices,uvs)
    local inks={}
    for i=1,#positions do inks[i]=white end
    local model=craft.model()
    model.positions,model.normals,model.indices,model.uvs,model.colors =
        positions,normals,indices,uvs,inks
    return model
end

local function faceColor(slots,a,b,c)
    if slots[b]==slots[c] then return slots[b] end
    return slots[a]
end

local function dominant(mesh,slots)
    local areas={}
    local best,bestArea = slots[1],0
    for i=1,#mesh.indices,3 do
        local a,b,c=mesh.indices[i],mesh.indices[i+1],mesh.indices[i+2]
        local color=faceColor(slots,a,b,c)
        local A,B,C=mesh.positions[a],mesh.positions[b],mesh.positions[c]
        local area=(B-A):cross(C-A):len()
        areas[color]=(areas[color] or 0)+area
        if areas[color]>bestArea then best,bestArea=color,areas[color] end
    end
    return best
end

-- A padded swatch has the same color in all four neighboring samples.
-- Keeping each triangle on a single swatch prevents interpolation across colors.
local function atlas(swatches)
    local columns,tile = 8,4
    local width,height = columns*tile,tile
    while height/tile*columns<#swatches do height=height*2 end
    local texture=image(width,height)
    local samples={}
    for i,swatch in ipairs(swatches) do
        local x=((i-1)%columns)*tile
        local y=math.floor((i-1)/columns)*tile
        for row=y+1,y+tile do
            for col=x+1,x+tile do texture:set(col,row,swatch[1],swatch[2],swatch[3],255) end
        end
        samples[i]=vec2((x+tile*.5)/width,(y+tile*.5)/height)
    end
    local mat=standard(white)
    mat.map=texture
    return mat,samples
end

local function paintedModel(mesh,slots,samples)
    local positions,normals,indices,uvs = {},{},{},{}
    local vertices={}
    for i=1,#mesh.indices,3 do
        local a,b,c=mesh.indices[i],mesh.indices[i+1],mesh.indices[i+2]
        local slot=faceColor(slots,a,b,c)
        for j=i,i+2 do
            local source=mesh.indices[j]
            local byColor=vertices[source]
            if not byColor then byColor={} vertices[source]=byColor end
            local target=byColor[slot]
            if not target then
                target=#positions+1
                byColor[slot]=target
                positions[target],normals[target],uvs[target] =
                    mesh.positions[source],mesh.normals[source],samples[slot]
            end
            indices[j]=target
        end
    end
    return makeModel(positions,normals,indices,uvs)
end

function Palette.build(mesh)
    local swatches,lookup,slots={},{},{}
    for i,ink in ipairs(mesh.colors) do
        local r,g,b=rgb(ink)
        local key=r*65536+g*256+b
        local slot=lookup[key]
        if not slot then
            slot=#swatches+1
            swatches[slot],lookup[key]={r,g,b,key},slot
        end
        slots[i]=slot
    end
    if #swatches>1 then
        local ok,mat,samples=pcall(atlas,swatches)
        if ok then return paintedModel(mesh,slots,samples),mat end
    end
    -- Flat-color parts and older material implementations still use a real tint.
    local slot=#swatches==1 and 1 or dominant(mesh,slots)
    return makeModel(mesh.positions,mesh.normals,mesh.indices,mesh.uvs),solid(swatches[slot])
end
