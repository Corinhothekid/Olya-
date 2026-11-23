-- From the repository root: lua tests/road_people.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")
dofile(project.."/GoalPhysics.lua")
dofile(project.."/FreeRoamWorld.lua")

local World=PolyLax.FreeRoamWorld
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

local rooms={}
local models={}
for zone, ids in pairs({
    campus={"ethan","jace","studentA","studentB"},coach={"coach"},drip={"drip"}
}) do
    local room=World.new(craft.scene(),zone)
    rooms[zone]=room
    assert(#room.actors==#ids)
    for _,id in ipairs(ids) do
        local actor=campusPerson(id,room)
        local face=faceFor(actor,room)
        assert(face.scale.x>.9 and face.scale.y>.9,"Invalid NPC head scale")
        assert(face.model.positions and #face.model.positions>100)
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
        end
        if actor.point then
            assert(actor.point==World.interaction(room,actor.x,actor.z))
        end
    end
end

local campus=rooms.campus
local ethan=campusPerson("ethan",campus)
local face=faceFor(ethan,campus)
local again=World.new(craft.scene(),"campus")
assert(faceFor(campusPerson("ethan",again),again).model==face.model,
    "Returning to a zone rebuilt the NPC face mesh")
local entityCount=#campus.scene.entities
local x,z=ethan.x,ethan.z
local playerX,playerZ=x-2,z+.2
for _=1,24 do World.update(campus,.08,"morning",playerX,playerZ) end
assert(ethan.x==x and ethan.z==z,"Named NPC drifted during interaction")
local front=(ethan.root:transformPoint(vec3(0,0,-1))-ethan.root.worldPosition):normalize()
local toward=vec3(playerX-x,0,playerZ-z):normalize()
assert(front:dot(toward)>.99,"NPC did not face the player during interaction")
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
print(("Six distinct NPCs passed silhouette, facing, gait, proximity, and mesh reuse checks (%d campus entities).")
    :format(entityCount))
