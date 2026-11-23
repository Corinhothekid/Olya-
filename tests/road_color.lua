-- From the repository root: lua tests/road_color.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")

function image(width,height)
    local pixels = {}
    return {width=width,height=height,pixels=pixels,set=function(_,x,y,r,g,b,a)
        assert(x%1==0 and y%1==0 and x>=1 and x<=width and y>=1 and y<=height)
        local ink = type(r)=="table" and r or color(r,g,b,a)
        pixels[(y-1)*width+x] = ink
    end}
end

local imported = image(4,4)
asset = {camo="asset.camo"}
function readImage(key) if key==asset.camo then return imported end end

-- Lua's color() results expose RGB channels. Craft material readback may instead
-- expose a vector with no .r field, so the test keeps independent writes for checks.
local diffuseWrites = setmetatable({},{__mode="k"})
local rejectMaps = false
local materialMeta = {
    __index=function(self,key)
        local value=key=="diffuse" and diffuseWrites[self]
        if value then return vec3(value.r/255,value.g/255,value.b/255) end
    end,
    __newindex=function(self,key,value)
        if key=="diffuse" then
            assert(type(value.r)=="number" and type(value.g)=="number" and type(value.b)=="number",
                "Equipment must assign a valid color to the material")
            diffuseWrites[self]=value
        else
            if key=="map" and rejectMaps then error("Craft map binding disabled for fallback test") end
            rawset(self,key,value)
        end
    end
}
function craft.material() return setmetatable({},materialMeta) end

for _,tab in ipairs({"TeamUniform","Profile","Character","AnimationController","CameraController",
    "UI","Style","GoalPhysics","CraftPalette","EquipmentTextures","RoadEquipment","RoadEquipmentUI","CampusPeople",
    "CampusHumanMeshes","CampusCharacter","CampusMotion","FreeRoamWorld","FreeRoamUI","FreeRoam"}) do
    dofile(project.."/"..tab..".lua")
end

local P=PolyLax
local Equipment,Shop=P.RoadEquipment,P.RoadEquipmentUI
local appearance=P.Profile.load()
local kit=Equipment.restore()
local roam=P.FreeRoam.new({profile=appearance,equipment=kit,location={zone="drip"}})
assert(roam.zone=="drip" and roam.rig.stickRoot.parent==roam.rig.backpackStick)
local casual=roam.rig
assert(casual.outfit.material.diffuse.r==nil and casual.backpack.material.diffuse.r==nil)
local function matches(ink,wanted)
    return ink and math.abs(ink.r-wanted[1])<1.1 and math.abs(ink.g-wanted[2])<1.1
        and math.abs(ink.b-wanted[3])<1.1
end

local function expectRGB(part,wanted)
    -- Legacy Craft can ignore vertex colors. Sample the bound map using the
    -- actual model UVs, or inspect the assigned diffuse for a solid surface.
    local map=part.material.map
    local diffuse=assert(diffuseWrites[part.material])
    if map then
        for _,uv in ipairs(part.model.uvs) do
            local x=math.min(map.width,math.floor(uv.x*map.width)+1)
            local y=math.min(map.height,math.floor(uv.y*map.height)+1)
            local ink=map.pixels[(y-1)*map.width+x]
            if ink and matches(color(ink.r*diffuse.r/255,ink.g*diffuse.g/255,ink.b*diffuse.b/255),wanted) then
                return
            end
        end
    elseif matches(diffuse,wanted) then
        return
    end
    error("Rendered material missing color "..table.concat(wanted,", "),2)
end
expectRGB(casual.outfit,{39,115,88})
expectRGB(casual.face,casual.definition.skin)
expectRGB(casual.face,casual.definition.hair)
expectRGB(casual.neck,casual.definition.skin)
expectRGB(casual.feet[1],{230,238,245})
expectRGB(casual.backpack,{40,53,67})
local shopkeeper=assert(roam.world.actors[1])
assert(shopkeeper.id=="drip")
expectRGB(shopkeeper.rig.outfit,shopkeeper.definition.shirt)
expectRGB(shopkeeper.rig.outfit,shopkeeper.definition.trim)
expectRGB(shopkeeper.rig.face,shopkeeper.definition.skin)
expectRGB(shopkeeper.rig.face,shopkeeper.definition.hair)
local preview=assert(Equipment.change(kit,"buy","sneakerColor",4))
preview=assert(Equipment.change(preview,"equip","sneakerColor",4))
preview=Equipment.preview(preview,"backpackColor",8)
P.FreeRoam.appearance(roam,appearance,preview)
expectRGB(casual.feet[1],{45,99,190})
expectRGB(casual.backpack,{101,218,228})

local camoIndex
for i,label in ipairs(Equipment.fields.leftSleevePattern[3]) do
    if label=="Imported Camo" then camoIndex=i break end
end
local sleeve=assert(Equipment.change(kit,"buy","leftSleeve",2))
sleeve=assert(Equipment.change(sleeve,"equip","leftSleeve",2))
sleeve=Equipment.preview(sleeve,"leftSleevePattern",assert(camoIndex))
P.FreeRoam.appearance(roam,appearance,sleeve)
assert(casual.shins[1].material.map==imported)
expectRGB(casual.shins[2],{40,53,67})
P.FreeRoam.appearance(roam,appearance,kit)
assert(casual.shins[1].material.map~=imported)
expectRGB(casual.shins[1],{40,53,67})

local shop=Shop.new(craft.scene(),appearance,kit,"short")
local function tap(id)
    local box=assert(Shop.layout(shop).byId[id])
    Shop.touch(shop,{id=1,state=BEGAN,x=box.x,y=box.y})
end
tap("VALUE_NEXT")
assert(shop.choice==2 and shop.rig.roadStick.upper.active)
expectRGB(shop.rig.roadStick.upper,{35.25,61.5,71.5})
expectRGB(shop.rig.roadStick.upper,{82.5,78.75,77.5})
tap("GLOVES")
tap("VALUE_NEXT")
assert(shop.rig.materials.gloves.metalness>.7)
tap("OUTFIT")
assert(shop.rig.stickRoot.parent==shop.rig.backpackStick)
expectRGB(shop.rig.feet[1],{230,238,245})

rejectMaps=true
local fallbackLook=P.CampusPeople.named("jace")
fallbackLook.shirt={52,87,124}
local fallback=P.CampusCharacter.new(craft.scene(),fallbackLook)
assert(not fallback.outfit.material.map)
assert(matches(diffuseWrites[fallback.outfit.material],fallbackLook.shirt),"Texture fallback washed out the outfit")
expectRGB(fallback.face,fallbackLook.skin)
print("Drip Lab player and NPC colors reach Craft maps, imported sleeves restore their palette, and diffuse fallback retains color.")
