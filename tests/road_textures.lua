-- Imported-image bindings and mesh preservation. The Craft double captures the
-- actual image given to material.map, without emulating the iPhone renderer.
local checks=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(checks.."craft_mock.lua")
local keys={"camo","ducky","galaxy","zebra"}
local images,reads={},{}
asset={}
for index,key in ipairs(keys) do
    asset[key]="test-project/"..key
    images[key]={width=32*index,height=32}
end
function readImage(ref)
    local key=assert(ref:match("^test%-project/(.+)$"))
    reads[key]=(reads[key] or 0)+1
    return images[key]
end
for _,tab in ipairs({"TeamUniform","Profile","Character","CampusPeople","CampusHumanMeshes",
    "CampusCharacter","EquipmentTextures","RoadEquipment"}) do
    dofile(project.."/"..tab..".lua")
end

local P=PolyLax
local E,C=P.RoadEquipment,P.Character
local test=E.textureTest(craft.scene())
for i,slot in ipairs(test.shafts) do
    local key=keys[i]
    assert(slot.loaded and slot.key==key and slot.shaft.material.map==images[key])
    assert(slot.shaft.model==test.shafts[1].shaft.model and reads[key]==1)
    assert(slot.shaft.material.diffuse.r==255 and slot.shaft.material.diffuse.g==255)
end
assert(#test.shafts==4)
local model=test.shafts[1].shaft.model
local ring=17
assert(#model.positions==ring*2*7 and #model.indices==16*6*7)
for tile=0,6 do
    local start=tile*ring*2+1
    assert(model.uvs[start].x==0 and model.uvs[start+ring-1].x==1)
    assert(model.uvs[start].y==0 and model.uvs[start+ring].y==1)
    assert((model.positions[start]-model.positions[start+ring-1]):len()<.00001)
    if tile>0 then assert((model.positions[start]-model.positions[start-ring]):len()<.00001) end
end
for _,mesh in ipairs({model}) do
    for index=1,#mesh.indices,3 do
        local a,b,c=mesh.positions[mesh.indices[index]],mesh.positions[mesh.indices[index+1]],
            mesh.positions[mesh.indices[index+2]]
        local normal=(b-a):cross(c-a)
        assert(normal:dot(vec3(a.x,0,a.z))>0,"Shaft winding is inward")
    end
end

local kit=E.restore({credits=500})
local function buyEquip(id,option)
    kit=assert(E.change(kit,"buy",id,option))
    kit=assert(E.change(kit,"equip",id,option))
end
buyEquip("shaftPattern",15)
buyEquip("gripPattern",16)
buyEquip("headPattern",4)
buyEquip("pocketPattern",5)
buyEquip("glovePattern",18)
buyEquip("gloveFinish",2)
buyEquip("leftSleeve",3)
buyEquip("leftSleevePattern",16)
buyEquip("rightSleeve",2)
buyEquip("rightSleevePattern",17)
kit=assert(E.change(kit,"savePreset",nil,1))
kit=E.restore(kit)
assert(kit.presets["1"].pocketPattern==5 and kit.equipped.shaftPattern==15)
assert(E.fields.shaftPattern[3][2]=="Woodland Camo","An older purchase was repurposed")

local function hasMap(part,key)
    assert(part.active and part.material.map==images[key],"Lost texture on "..key)
    local changes=false
    for _,uv in ipairs(part.model.uvs) do
        assert(uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1)
        if uv.x>.1 and uv.y>.1 then changes=true end
    end
    assert(changes,"Texture has no useful UVs")
end

local match=C.new(craft.scene())
local oldHead,oldPocket=match.stickHead.model,match.stickMesh.model
local legacy=E.restore()
E.applyMatch(match,kit)
hasMap(match.roadStick.upper,"camo")
hasMap(match.roadStick.lower,"camo")
hasMap(match.roadStick.center,"camo")
hasMap(match.roadStick.grip,"ducky")
hasMap(match.stickHead,"galaxy")
hasMap(match.stickMesh,"zebra")
assert(match.stickHead.model.indices==oldHead.indices and match.stickMesh.model.indices==oldPocket.indices,
    "Texturing changed the head or string topology")
hasMap(match.arms.left.glove,"zebra")
hasMap(match.arms.right.glove,"zebra")
hasMap(match.sleeveParts.left[1],"ducky")
hasMap(match.sleeveParts.left[2],"ducky")
hasMap(match.sleeveParts.right[2],"galaxy")
assert(not match.sleeveParts.right[1].active and not match.roadMatch.gloves.left.pads.active)
assert(not match.roadMatch.sleeves.left.thigh.active and not match.roadMatch.sleeves.right.shin.active)
local textured=match.stickHead.model
C.setStickType(match,"goalie")
local goalieHead,goaliePocket=match.stickHead.model,match.stickMesh.model
E.applyMatch(match,kit)
hasMap(match.stickHead,"galaxy")
hasMap(match.stickMesh,"zebra")
assert(match.stickHead.model~=textured and match.stickMesh.model.indices==goaliePocket.indices)
E.applyMatch(match,legacy)
assert(match.stickHead.model==goalieHead and match.stickMesh.model==goaliePocket)
assert(match.stickHead.material==match.materials.stick and not match.stickHead.material.map)
assert(match.arms.left.glove.material==match.materials.gloves and not match.roadStick.upper.active)

local profile=P.Profile.load()
local avatar=E.newCasual(craft.scene(),profile,kit,"long")
hasMap(avatar.roadStick.upper,"camo")
hasMap(avatar.stickHead,"galaxy")
hasMap(avatar.stickMesh,"zebra")
hasMap(avatar.casualGloves[1],"zebra")
hasMap(avatar.casualGloves[2],"zebra")
hasMap(avatar.thighs[1],"ducky")
hasMap(avatar.shins[1],"ducky")
hasMap(avatar.shins[2],"galaxy")
assert(not avatar.hands[1].active and avatar.casualGloves[1].parent==avatar.wrists[1])
assert(avatar.stickRoot.parent==avatar.backpackStick)
local count=#avatar.scene.entities
E.applyCasual(avatar,profile,legacy,"long")
assert(avatar.hands[1].active and not avatar.casualGloves[1].active)
assert(not avatar.thighs[1].material.map and not avatar.shins[2].material.map)
E.applyCasual(avatar,profile,kit,"long")
hasMap(avatar.shins[2],"galaxy")
assert(#avatar.scene.entities==count,"Repeated equip rebuilt the avatar")

-- Repeat the diagnostic with three kinds of failure. The intended IDs survive
-- reloading even when this particular installation cannot display the artwork.
images.ducky=nil
asset.zebra=nil
setmetatable(asset,{__index=function(_,key)
    if key=="zebra" then error("missing key") end
end})
local original=craft.material
function craft.material(...)
    return setmetatable(original(...),{__newindex=function(material,k,v)
        if k=="map" and v==images.galaxy then error("unknown image") end
        rawset(material,k,v)
    end})
end
dofile(project.."/EquipmentTextures.lua")
local failure=E.textureTest(craft.scene()).shafts
assert(failure[1].loaded and failure[2].status=="Image load failed"
    and failure[3].status=="Craft map rejected" and failure[4].status=="Missing asset")
for i=2,4 do assert(not failure[i].loaded and failure[i].shaft==nil) end
local result=E.change(legacy,"buy","shaftPattern",18)
assert(not result and legacy.credits==240,"Missing asset charged credits")
local restored=E.restore(kit)
assert(restored.equipped.glovePattern==18 and restored.equipped.pocketPattern==5)
E.applyCasual(avatar,profile,restored,"long")
assert(avatar.hands[1].active and not avatar.stickMesh.material.map)
assert(avatar.roadStick.upper.material.map==images.camo)
print("Drip Lab imported image bindings, tiled shaft UVs, open pocket, match/hub swaps, saves and missing assets passed.")
