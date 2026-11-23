-- From the repository root: lua tests/road_color.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")

-- Lua's color() results expose RGB channels. Craft material readback may instead
-- expose a vector with no .r field, so the test keeps independent writes for checks.
local diffuseWrites = setmetatable({},{__mode="k"})
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
            rawset(self,key,value)
        end
    end
}
function craft.material() return setmetatable({},materialMeta) end

for _,tab in ipairs({"TeamUniform","Profile","Character","AnimationController","CameraController",
    "UI","Style","GoalPhysics","RoadEquipment","RoadEquipmentUI","CampusPeople",
    "CampusCharacter","CampusMotion","FreeRoamWorld","FreeRoamUI","FreeRoam"}) do
    dofile(project.."/"..tab..".lua")
end

local P=PolyLax
local Equipment,Shop=P.RoadEquipment,P.RoadEquipmentUI
local appearance=P.Profile.load()
local kit=Equipment.restore()
local roam=P.FreeRoam.new({profile=appearance,equipment=kit,location={zone="campus"}})
assert(roam.zone=="campus" and roam.rig.stickRoot.parent==roam.rig.backpackStick)
local casual=roam.rig.roadCasual
assert(casual.sneakers.diffuse.r==nil and casual.pack.diffuse.r==nil)

local function expectTint(material,base,amount)
    local expected={r=base[1]+(24-base[1])*amount,g=base[2]+(31-base[2])*amount,
        b=base[3]+(42-base[3])*amount}
    for key,channel in pairs(expected) do
        assert(math.abs(diffuseWrites[material][key]-channel)<.001,"Equipment trim color changed")
    end
end
expectTint(casual.shoeTrim,{230,238,245},.78)
expectTint(casual.packTrim,{40,53,67},.54)
local preview=assert(Equipment.change(kit,"buy","sneakerColor",4))
preview=assert(Equipment.change(preview,"equip","sneakerColor",4))
preview=Equipment.preview(preview,"backpackColor",8)
P.FreeRoam.appearance(roam,appearance,preview)
expectTint(casual.shoeTrim,{45,99,190},.78)
expectTint(casual.packTrim,{101,218,228},.54)

local shop=Shop.new(craft.scene(),appearance,kit,"short")
local function tap(id)
    local box=assert(Shop.layout(shop).byId[id])
    Shop.touch(shop,{id=1,state=BEGAN,x=box.x,y=box.y})
end
tap("VALUE_NEXT")
assert(shop.choice==2 and shop.rig.roadStick.upper.active)
assert(shop.rig.roadStick.upper.model.colors[1].r~=nil)
tap("GLOVES")
tap("VALUE_NEXT")
assert(shop.rig.materials.gloves.metalness>.7)
tap("OUTFIT")
assert(shop.rig.stickRoot.parent==shop.rig.backpackStick)
expectTint(shop.rig.roadCasual.shoeTrim,{230,238,245},.78)
print("Road to Glory handles opaque Craft material readback in campus outfits and Drip Lab previews.")
