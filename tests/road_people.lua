-- From the repository root: lua tests/road_people.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")
for _,tab in ipairs({"GoalPhysics","CampusPeople","CampusCharacter","CampusMotion","FreeRoamWorld"}) do
    dofile(project.."/"..tab..".lua")
end

local World,People,Character,Motion=PolyLax.FreeRoamWorld,PolyLax.CampusPeople,
    PolyLax.CampusCharacter,PolyLax.CampusMotion
local function campusPerson(id, room)
    for _,actor in ipairs(room.actors) do
        if actor.id==id then return actor end
    end
    error("Missing campus character "..id)
end

local function faceFor(actor, room)
    for _,part in ipairs(room.scene.entities) do
        if part.parent==actor.head and part.model then return part end
    end
    error("Missing face mesh for "..actor.id)
end

local function checkMesh(model)
    for index=1,#model.positions do
        local ink,normal=model.colors[index],model.normals[index]
        assert(ink and ink.r and ink.g and ink.b,"Missing NPC vertex color at "..index)
        assert(normal and normal:len()>.98,"Missing or degenerate NPC vertex normal at "..index)
    end
    for _,index in ipairs(model.indices) do
        assert(model.positions[index],"NPC mesh index points outside the vertex array")
    end
end

local rooms={}
local models={}
for zone, ids in pairs({
    campus={"ethan","jace","maya","studentA","studentB","fieldAssistant"},school={"hallStaff"},
    coach={"coach"},drip={"drip"},training={"training"}
}) do
    local room=World.new(craft.scene(),zone)
    rooms[zone]=room
    assert(#room.actors==#ids)
    for _,id in ipairs(ids) do
        local actor=campusPerson(id,room)
        local face=faceFor(actor,room)
        assert(face.scale.x>.9 and face.scale.y>.9,"Invalid NPC head scale")
        assert(face.model.positions and #face.model.positions>100)
        checkMesh(face.model)
        checkMesh(actor.rig.outfit.model)
        local colors={}
        for _,ink in ipairs(face.model.colors) do
            colors[("%d-%d-%d"):format(math.floor(ink.r),math.floor(ink.g),math.floor(ink.b))]=true
        end
        local distinct=0
        for _ in pairs(colors) do distinct=distinct+1 end
        assert(distinct>=5,"Face geometry lost its distinguishing features")
        assert(not models[face.model],"NPCs share a face that should be distinct")
        models[face.model]=true
        for i=1,2 do
            assert(actor.elbows[i].parent==actor.arms[i] and actor.knees[i].parent==actor.legs[i])
            assert(actor.rig.hands[i].model and actor.rig.hands[i].parent==actor.elbows[i])
            assert(actor.rig.feet[i].model and actor.rig.feet[i].parent==actor.knees[i])
            checkMesh(actor.rig.hands[i].model)
            checkMesh(actor.rig.feet[i].model)
        end
        if actor.point then
            assert(actor.point==World.interaction(room,actor.x,actor.z))
        end
    end
end

local campus=rooms.campus
local ethan=campusPerson("ethan",campus)
local face=faceFor(ethan,campus)
local ethanModel=face.model
local again=World.new(craft.scene(),"campus")
assert(faceFor(campusPerson("ethan",again),again).model==face.model,
    "Returning to a zone rebuilt the NPC face mesh")
assert(campusPerson("maya",again).definition.name=="Maya Brooks")
for _,id in ipairs({"maya","studentA","studentB","fieldAssistant"}) do
    assert(campusPerson(id,again).rig.face.model==campusPerson(id,campus).rig.face.model,
        "Reopening campus regenerated "..id)
end
local function checkValue(a,b)
    assert(type(a)==type(b))
    if type(a)=="table" then
        for key,value in pairs(a) do checkValue(value,b[key]) end
        for key in pairs(b) do assert(a[key]~=nil) end
    else assert(a==b) end
end
local slots={{id="studentA",role="student"},{id="hallStaff",role="staff"},{id="fieldAssistant",role="coach"}}
local first=People.background("fixture",slots)
math.random()
checkValue(People.background("fixture",{slots[3],slots[2],slots[1]}),first)
local used={}
for _,look in pairs(first) do
    local appearance=look.haircut.."/"..table.concat(look.shirt,",")
    assert(not used[appearance])
    used[appearance]=true
    assert(look.role and look.motion)
end
local mutable=People.named("ethan")
mutable.skin[1]=0
assert(People.named("ethan").skin[1]~=0)
local entityCount=#campus.scene.entities
local outfit,hand,shoe=ethan.rig.outfit.model,ethan.rig.hands[1].model,ethan.rig.feet[1].model
local variation=People.named("ethan")
variation.haircut,variation.headShape,variation.outfit,variation.accessory,variation.shoeStyle=
    "braids","angular","jacket","notebook","boot"
Character.apply(ethan.rig,variation)
assert(face.model~=ethanModel and ethan.rig.outfit.model~=outfit
    and ethan.rig.hands[1].model~=hand and ethan.rig.feet[1].model~=shoe)
checkMesh(ethan.rig.hands[1].model)
checkMesh(ethan.rig.feet[1].model)
Character.apply(ethan.rig,ethan.definition)
assert(face.model==ethanModel and #campus.scene.entities==entityCount)
local x,z=ethan.x,ethan.z
local playerX,playerZ=x-2,z+.2
for _=1,24 do World.update(campus,.08,"morning",playerX,playerZ) end
assert(ethan.x==x and ethan.z==z,"Named NPC drifted during interaction")
local front=(ethan.root:transformPoint(vec3(0,0,-1))-ethan.root.worldPosition):normalize()
local toward=vec3(playerX-x,0,playerZ-z):normalize()
assert(front:dot(toward)>.99,"NPC did not face the player during interaction")
assert(ethan.motion.mode=="listen")
for _=1,5 do World.update(campus,.05,"morning",playerX,playerZ,"ethan") end
assert(ethan.motion.mode=="talk" and ethan.motion.arms[2]>8,"Talk gesture did not animate")
assert(Motion.gesture(ethan.motion,"nod"))
for _=1,18 do World.update(campus,.05,"morning",playerX,playerZ) end
assert(ethan.motion.mode=="listen" and not ethan.motion.beat,"Gesture did not settle")
local easy=Motion.new(Character.new(craft.scene(),ethan.definition),"easy",10)
local measured=Motion.new(Character.new(craft.scene(),People.named("coach")),"measured",10)
for _=1,10 do
    Motion.update(easy,.05,"idle",0)
    Motion.update(measured,.05,"idle",0)
end
assert(math.abs(easy.headY-measured.headY)>.3,"Named idle profiles produced the same glance")
for _=1,10 do
    Motion.update(easy,.05,"walk",.7)
    Motion.update(measured,.05,"walk",.7)
end
assert(math.abs(easy.legs[1]-measured.legs[1])>2,"Named gait profiles produced the same stride")
local bent,moved=false,false
for _=1,90 do
    World.update(campus,.08,"evening",x+8,z)
    if math.abs(ethan.knees[1].rotation.x)>.03 then bent=true end
    if (ethan.x-x)^2+(ethan.z-z)^2>.02 then moved=true end
end
assert(bent and moved,"NPC schedule or articulated stride stopped")
assert(ethan.point.x==ethan.x and ethan.point.z==ethan.z,"NPC interaction lost its position")
World.update(campus,.08,"evening",x+32,z)
assert(not ethan.root.active,"Distant NPC stayed active")
assert(#campus.scene.entities==entityCount,"NPC updates created scene entities")
print(("NPC identities, generated roles, part swapping, silhouette, gestures, gait, culling and reuse passed (%d campus entities).")
    :format(entityCount))
