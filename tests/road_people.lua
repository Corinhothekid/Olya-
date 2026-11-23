-- From the repository root: lua tests/road_people.lua [PolyLax.codea]
local helpers=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(helpers.."craft_mock.lua")
for _,tab in ipairs({"GoalPhysics","Character","CampusPeople","CraftPalette","CampusHumanMeshes","CampusCharacter",
    "CampusMotion","FreeRoamWorld","AnimationController"}) do
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
    assert(coversWaist(rig.outfit,rig.pelvis,.115,.075,.042),"The top lifted off the campus waist")
    assert(coversWaist(rig.waist,rig.pelvis,.115,.075,.042),"Campus trousers do not meet the hem")
    assert(coversWaist(rig.waist,rig.pelvis,-.072,.068,.028),"The trouser seat pulled away from the legs")
end

local rooms={}
local match=PolyLax.Character.new(craft.scene())
local matchNeck
for _,part in ipairs(match.scene.entities) do
    if part.parent==match.body and part.material==match.materials.skin then matchNeck=part end
end
assert(matchNeck,"Main game has no neck model to compare")
local function checkMainStyle(rig)
    assert(rig.face.model==match.headShell.model,"Campus actor is missing the main-game head mesh")
    assert(rig.neck.model==matchNeck.model,"Campus neck diverged from match play")
    for i,part in ipairs(rig.faceParts) do
        assert(part.model==match.faceParts[rig.faceIndex][i].model,"Campus face details diverged from match play")
    end
    assert(#rig.faceParts==3,"Campus actor lost nose, eye, or expression geometry")
    local hair,beard=match.hairParts[rig.hairIndex],match.beardParts[rig.beardIndex]
    assert(rig.hairPart.active==(hair~=nil) and (not hair or rig.hairPart.model==hair.model),
        "Campus hair does not match the selected game model")
    assert(rig.beardPart.active==(beard~=nil) and (not beard or rig.beardPart.model==beard.model),
        "Campus beard does not match the selected game model")
    for i,side in ipairs({"left","right"}) do
        local shoulder=match.arms[side].shoulder.position*.74
        local hip=match.legs[side].hip.position*.74
        assert((rig.arms[i].position-shoulder):len()<1e-6,"Campus shoulder diverged from match proportions")
        assert((rig.legs[i].position-hip):len()<1e-6,"Campus hip diverged from match proportions")
    end
end

local function checkScaledGeometry(part,source)
    local function key(v) return ("%.6f/%.6f/%.6f"):format(v.x,v.y,v.z) end
    local points={}
    for _,v in ipairs(part.model.positions) do points[key(v)]=true end
    for _,v in ipairs(source.positions) do
        assert(points[key(v*.74)],"Campus hoodie lost the main-game geometry")
    end
end
for zone, ids in pairs({
    campus={"ethan","jace","maya","studentA","studentB","fieldAssistant"},school={"hallStaff"},
    coach={"coach"},drip={"drip"},training={"training"}
}) do
    local room=World.new(craft.scene(),zone)
    rooms[zone]=room
    assert(#room.actors==#ids)
    for _,id in ipairs(ids) do
        local actor=campusPerson(id,room)
        local face=actor.rig.face
        checkMainStyle(actor.rig)
        assert(face.material.diffuse and not face.material.map,"Campus face should use the match material style")
        checkMesh(face.model)
        checkMesh(actor.rig.outfit.model)
        checkMesh(actor.rig.waist.model)
        checkCampusWaist(actor.rig)
        assert(actor.rig.legs[1].parent==actor.rig.pelvis and actor.rig.torso.parent==actor.rig.pelvis)
        local skin=face.material.diffuse
        for i,component in ipairs({"r","g","b"}) do
            assert(skin[component]==actor.definition.skin[i],"Campus actor lost their authored complexion")
        end
        local glasses=actor.rig.glasses
        local earrings=actor.rig.earrings
        assert((glasses and glasses.active==true or false)==(actor.definition.glasses==true))
        assert((earrings and earrings.active==true or false)==(actor.definition.earrings==true))
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
local ethanFaceIndex,ethanHairIndex=ethan.rig.faceIndex,ethan.rig.hairIndex
local faceModel=ethan.rig.faceParts[1].model
local again=World.new(craft.scene(),"campus")
assert(campusPerson("ethan",again).rig.faceParts[1].model==faceModel,
    "Returning to a zone rebuilt the NPC face mesh")
assert(campusPerson("maya",again).definition.name=="Maya Brooks")
for _,id in ipairs({"maya","studentA","studentB","fieldAssistant"}) do
    local restored,original=campusPerson(id,again).rig,campusPerson(id,campus).rig
    assert(restored.faceIndex==original.faceIndex and restored.hairIndex==original.hairIndex,
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
local savedAppearance={FACE=4,HAIR=4,BEARD=6,BODY=4}
local player=People.player(savedAppearance)
assert(player.skin[1]==105)
assert(player.beardStyle==6 and player.height>1,"Campus avatar lost the saved athlete proportions")
local wardrobe=People.named("ethan")
player.shirt,player.trim,player.pants,player.shoe=wardrobe.shirt,wardrobe.trim,wardrobe.pants,wardrobe.shoe
local playerRig=Character.new(craft.scene(),player)
checkMainStyle(playerRig)
checkScaledGeometry(playerRig.outfit,match.hoodieParts[1].model)
checkScaledGeometry(playerRig.sleeves[1],PolyLax.Character.campusApparel("upperArm"))
checkScaledGeometry(playerRig.forearms[1],PolyLax.Character.campusApparel("forearm"))
assert(playerRig.faceIndex==4 and playerRig.hairIndex==4 and playerRig.beardIndex==6,
    "Campus changed the player's saved match appearance")
PolyLax.Character.apply(match,savedAppearance,"FACE")
assert((playerRig.root.scale-match.proportions.scale):len()<1e-6,
    "Campus changed the player's saved body proportions")
local restoredLook=ethan.definition
local entityCount=#campus.scene.entities
local outfit,hand,shoe=ethan.rig.outfit.model,ethan.rig.hands[1].model,ethan.rig.feet[1].model
local variation=People.named("ethan")
variation.haircut,variation.headShape,variation.outfit,variation.accessory,variation.shoeStyle=
    "braids","angular","jacket","notebook","boot"
Character.apply(ethan.rig,variation)
assert(ethan.rig.faceIndex~=ethanFaceIndex and ethan.rig.hairIndex~=ethanHairIndex and ethan.rig.outfit.model~=outfit
    and ethan.rig.hands[1].model~=hand and ethan.rig.feet[1].model~=shoe)
checkMesh(ethan.rig.hands[1].model)
checkMesh(ethan.rig.feet[1].model)
Character.apply(ethan.rig,restoredLook)
assert(ethan.rig.faceParts[1].model==faceModel and #campus.scene.entities==entityCount)
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
