-- From the repository root: lua tests/road_people.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")
for _,tab in ipairs({"GoalPhysics","CampusPeople","CraftPalette","CampusHumanMeshes","CampusCharacter","CampusMotion",
    "FreeRoamWorld","Character","AnimationController"}) do
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

-- Probe the front and back surfaces at the seam in pelvis space. A bounding box
-- overlap alone misses the holes left by tapered meshes when the torso leans.
local function coversWaist(part,pelvis,height,width,depth)
    local points={}
    for i,point in ipairs(part.model.positions) do
        points[i]=pelvis:inverseTransformPoint(part:transformPoint(point))
    end
    for _,x in ipairs({-width,0,width}) do
        local front,back=math.huge,-math.huge
        local indices=part.model.indices
        for i=1,#indices,3 do
            local a,b,c=points[indices[i]],points[indices[i+1]],points[indices[i+2]]
            local denominator=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
            if math.abs(denominator)>1e-7 then
                local u=((b.y-c.y)*(x-c.x)+(c.x-b.x)*(height-c.y))/denominator
                local v=((c.y-a.y)*(x-c.x)+(a.x-c.x)*(height-c.y))/denominator
                local w=1-u-v
                if math.min(u,v,w)>=-1e-6 then
                    local z=u*a.z+v*b.z+w*c.z
                    front,back=math.min(front,z),math.max(back,z)
                end
            end
        end
        if front>=-depth or back<=depth then return false end
    end
    return true
end

local function checkCampusWaist(rig)
    assert(coversWaist(rig.outfit,rig.pelvis,.020,.075,.042),"The top lifted off the campus waist")
    assert(coversWaist(rig.waist,rig.pelvis,.020,.075,.042),"Campus trousers do not meet the hem")
    assert(coversWaist(rig.waist,rig.pelvis,-.072,.068,.028),"The trouser seat pulled away from the legs")
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
        checkMesh(actor.rig.waist.model)
        checkCampusWaist(actor.rig)
        assert(actor.rig.legs[1].parent==actor.rig.pelvis and actor.rig.torso.parent==actor.rig.pelvis)
        local function extent(part,axis)
            local low,high=math.huge,-math.huge
            for _,vertex in ipairs(part.model.positions) do
                local value=vertex[axis]*part.scale[axis]
                low,high=math.min(low,value),math.max(high,value)
            end
            return high-low
        end
        assert(extent(face,"y")>.20 and extent(face,"y")<.40,"Oversized head")
        assert(extent(actor.rig.outfit,"x")<.53,"Oversized torso")
        assert(extent(actor.rig.forearms[1],"x")<.15,"Oversized forearm")
        assert(extent(actor.rig.hands[1],"y")<.24,"Oversized hand")
        local sharedTriangles={}
        for _,index in ipairs(actor.rig.outfit.model.indices) do
            sharedTriangles[index]=(sharedTriangles[index] or 0)+1
        end
        local smooth=false
        for _,count in pairs(sharedTriangles) do if count>=6 then smooth=true end end
        assert(smooth,"The torso is missing shared smooth-shaded vertices")
        local swatches={}
        for _,uv in ipairs(face.model.uvs) do swatches[uv.x..":"..uv.y]=true end
        local distinct=0
        for _ in pairs(swatches) do distinct=distinct+1 end
        assert(face.material.map and distinct>=5,"Face material lost its distinguishing colors")
        assert(not models[face.model],"NPCs share a face that should be distinct")
        models[face.model]=true
        for i=1,2 do
            assert(actor.elbows[i].parent==actor.arms[i] and actor.knees[i].parent==actor.legs[i])
            assert(actor.rig.hands[i].model and actor.rig.hands[i].parent==actor.rig.wrists[i]
                and actor.rig.wrists[i].parent==actor.elbows[i])
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
local player=People.player({FACE=4,HAIR=1,BEARD=6,BODY=4})
assert(player.headShape=="long" and player.skin[1]==105 and player.haircut=="none")
assert(player.beardStyle==6 and player.height>1,"Campus avatar lost the saved athlete proportions")
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
assert(math.abs(easy.stride-measured.stride)>.07,"Named gait profiles produced the same stride")
for _=1,15 do
    Motion.update(easy,.05,"run",5.9,-1)
    checkCampusWaist(easy.rig)
end

local match=PolyLax.Character.new(craft.scene())
local shirt,shorts
for _,part in ipairs(match.scene.entities) do
    if part.parent==match.body and part.material==match.materials.jersey then shirt=part end
    if part.parent==match.pelvis and part.material==match.materials.shorts then shorts=part end
end
assert(shirt and shorts and match.hoodieParts[1],"Match waist parts missing")
for _,action in ipairs({"dodge","shoot","scoop"}) do
    for _,pose in ipairs(PolyLax.AnimationController.clips[action].poses) do
        match.body.eulerAngles=pose.torso
        assert(coversWaist(shorts,match.pelvis,.193,.09,.10),"Match shorts waistband missing")
        assert(coversWaist(shirt,match.pelvis,.193,.09,.05),"Jersey waist separated during "..action)
        assert(coversWaist(match.hoodieParts[1],match.pelvis,.193,.09,.05),"Hoodie waist separated during "..action)
    end
end
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
print(("Campus and match waist coverage, NPC identities, gestures, gait, culling and reuse passed (%d campus entities).")
    :format(entityCount))
