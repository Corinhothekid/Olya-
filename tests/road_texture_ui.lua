-- Touch and layout regression for the Drip Lab texture comparison.
local checks=arg and arg[0] and arg[0]:match("^(.*[/])")
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock=io.open(checks.."craft_mock.lua")
if mock then mock:close() else checks="PolyLax-3.3-Checks/" end
dofile(checks.."craft_mock.lua")
for _,tab in ipairs({"TeamUniform","Profile","Character","AnimationController","CameraController","UI",
    "Style","CampusPeople","CraftPalette","CampusHumanMeshes","CampusCharacter","CampusMotion","EquipmentTextures",
    "RoadEquipment","RoadEquipmentUI"}) do
    dofile(project.."/"..tab..".lua")
end

local P=PolyLax
local equipment,shop=P.RoadEquipment,P.RoadEquipmentUI
local writes=0
local view=shop.new(craft.scene(),P.Profile.load(),equipment.restore(),"short",function()
    writes=writes+1
    return true
end)
local function touch(key)
    local button=assert(shop.layout(view).byId[key],key.." was not shown")
    return shop.touch(view,{id=1,state=BEGAN,x=button.x,y=button.y})
end

touch("VALUE_PREV")
local missing=shop.layout(view)
assert(missing.valueLabel=="Imported Zebra" and missing.valueUnavailable)
assert(missing.byId.TEXTURE_UNAVAILABLE and not missing.byId.TEXTURE_UNAVAILABLE.enabled and not missing.byId.BUY)
touch("TEXTURE_UNAVAILABLE")
touch("VALUE_NEXT")
touch("VALUE_NEXT")
local before={scene=view.scene,rig=view.rig,section=view.section,field=view.field,
    choice=view.choice,kit=view.kit,goalHeading=view.goalHeading}
touch("TEXTURE_TEST")
local comparison=assert(view.texturePreview,"Texture Test did not open")
assert(view.textureTesting and comparison.scene~=view.scene)
assert(#comparison.shafts==4,"Texture Test must show exactly four shafts")
local expected={"camo","ducky","galaxy","zebra"}
for i,key in ipairs(expected) do
    assert(comparison.shafts[i].key==key,"Unexpected shaft order")
end

local captions={}
function text(value,x,y) captions[#captions+1]={value=value,x=x,y=y} end
function textSize(value) return #value*fontSize()*.54,fontSize() end

for _,screen in ipairs({{320,568,20,0,0,0},{390,844,47,34,0,0},{430,932,59,34,8,0}}) do
    WIDTH,HEIGHT=screen[1],screen[2]
    layout={safeArea={top=screen[3],bottom=screen[4],left=screen[5],right=screen[6]}}
    local L=shop.layout(view)
    assert(L.previewBottom>=layout.safeArea.bottom and L.previewTop<=HEIGHT-layout.safeArea.top)
    assert(L.previewTop-L.previewBottom>=300)
    assert(L.byId.TEXTURE_BACK and not L.byId.BACK and not L.byId.BUY)
    captions={}
    shop.draw(view,.016)
    local locations={}
    local unavailable=0
    for _,entry in ipairs(captions) do
        locations[entry.value]=entry
        if entry.value=="Missing" or entry.value=="Unavailable" then unavailable=unavailable+1 end
    end
    assert(unavailable==4,"Unavailable project assets were reported as loaded")
    local previous=layout.safeArea.left-40
    for i,key in ipairs(expected) do
        local location=assert(locations["asset."..key],"Missing asset caption")
        assert(location.x>previous+40 and location.x<WIDTH-layout.safeArea.right-20)
        assert(location.y<L.previewBottom and location.y>=layout.safeArea.bottom)
        local root=comparison.shafts[i].root
        local screenPoint=assert(P.CameraController.project(comparison.camera,root.worldPosition))
        assert(math.abs(screenPoint.x-location.x)<.0001 and screenPoint.y>L.previewBottom and screenPoint.y<L.previewTop)
        previous=location.x
    end
end

local L=shop.layout(view)
local x,y=WIDTH*.5,(L.previewTop+L.previewBottom)*.5
shop.touch(view,{id=2,state=BEGAN,x=x,y=y})
shop.touch(view,{id=2,state=MOVING,x=x+75,y=y})
shop.touch(view,{id=2,state=ENDED,x=x+75,y=y})
shop.draw(view,.04)
assert(comparison.heading>5 and not view.drag)
for _,shaft in ipairs(comparison.shafts) do assert(math.abs(shaft.root.rotation.y)>.001) end
assert(touch("TEXTURE_BACK")~="BACK","Texture Test Back exited Drip Lab")
assert(not view.textureTesting and not view.drag)
for key,value in pairs(before) do assert(view[key]==value,"Texture Test changed editor "..key) end
assert(writes==0 and view.kit.credits==240)
touch("TEXTURE_TEST")
assert(view.texturePreview==comparison,"Texture Test rebuilt an existing scene")
touch("TEXTURE_BACK")
assert(touch("BACK")=="BACK","Normal Drip Lab Exit is broken")

print("Drip Lab Texture Test opens, lays out and rotates four shafts, then returns without editing the kit.")
