-- From the repository root: lua tests/road_app.lua [PolyLax.codea]
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock = dofile(tests.."craft_mock.lua")
local zebraImage={width=48,height=48}
asset={zebra="zebra-fixture"}
function readImage(ref) if ref==asset.zebra then return zebraImage end end
WIDTH = tonumber(os.getenv("POLYLAX_TEST_WIDTH")) or WIDTH
HEIGHT = tonumber(os.getenv("POLYLAX_TEST_HEIGHT")) or HEIGHT
viewer = {safeArea={top=44,bottom=34,left=0,right=0}}
layout = viewer
DeltaTime = .05
for _, key in ipairs({"stroke","strokeWidth","noFill","line","translate","scale","rotate",
    "clip","textWrapWidth","spriteMode","smooth","noSmooth","showKeyboard","hideKeyboard"}) do
    _G[key] = function() end
end
function background(r,g,b)
    assert(r~=7 or g~=28 or b~=60,"Main displayed its fatal error screen")
end
function textSize(s) return #s*fontSize()*.5,fontSize() end

local function copy(value)
    if type(value)~="table" then return value end
    local result = {}
    for key,item in pairs(value) do result[key]=copy(item) end
    return result
end

local records = {}
json = {
    encode=function(value)
        records[#records+1]=copy(value)
        return tostring(#records)
    end,
    decode=function(value)
        return copy(records[tonumber(value)])
    end
}

local combined = os.getenv("POLYLAX_TEST_DELIVERABLE")
if combined then
    dofile(combined)
else
    local info = assert(io.open(project.."/Info.plist"))
    for tab in info:read("*a"):gmatch("<string>([%w_]+)</string>") do
        dofile(project.."/"..tab..".lua")
    end
    info:close()
end

local function upvalue(fn, key)
    for i=1,80 do
        local name,value = debug.getupvalue(fn,i)
        if name==key then return value end
        if not name then break end
    end
end

local function appState()
    return assert(upvalue(upvalue(draw,"runFrame"),"state"),"Could not locate Main state")
end

local serial=0
local function input(kind,id,x,y)
    touched({state=kind,id=id,x=x,y=y})
end
local function tap(box)
    assert(box,"Missing touch target")
    serial=serial+1
    input(BEGAN,serial,box.x,box.y)
    input(ENDED,serial,box.x,box.y)
end
local function frames(count, stop)
    for _=1,count do
        if stop and stop() then return end
        draw()
    end
end
local function almost(a,b)
    return math.abs(a-b) < .0001
end

local P = PolyLax
local career=P.Career.new()
career.name="Existing Senior"
assert(P.Career.save(career))
local clubs=P.Clubs.load()
assert(P.Clubs.create(clubs,"Creekside Club","highSchool","briarbank"))
assert(P.Ultimate.Economy.grantStarter(P.Ultimate.load()))
local outside = copy(mock.store)

setup()
draw()
local app=appState()
local front=P.Style.screenLayout("FRONT")
for _,id in ipairs({"MODES","CAREER","ULTIMATE","CLUBS","SETTINGS","ROAD"}) do
    assert(front.byId[id],"Front menu lost "..id)
end
for i,box in ipairs(front.buttons) do
    assert(box.y-box.h*.5>=front.bottom and box.y+box.h*.5<=front.top)
    if i>1 then
        local prior=front.buttons[i-1]
        assert(box.y+box.h*.5<prior.y-prior.h*.5,"Front menu buttons overlap")
    end
end
assert(not P.Ultimate.isDeveloperBuild(),"Public build enabled the private developer grant")
tap(front.byId.ROAD)
draw()
assert(app.page=="ROAD","Road to Glory did not open")
local road=assert(app.road)
local roam=assert(road.roam)
assert(roam.zone=="campus")

local function holdJoystick(dx,dy,count)
    local joy=P.FreeRoamUI.layout(roam).joystick
    local radius=joy.radius
    serial=serial+1
    local id=serial
    input(BEGAN,id,joy.x,joy.y)
    input(MOVING,id,joy.x+dx*radius,joy.y+dy*radius)
    frames(count)
    input(ENDED,id,joy.x+dx*radius,joy.y+dy*radius)
end

-- Campus facades and interior signs are read from +Z. Read the actual
-- merged quads left to right along +X and check asymmetric letter shapes.
local function checkSignPrefix(world, z, cell, letters)
    local centers, left, top={}, math.huge, -math.huge
    for _,entity in ipairs(world.scene.entities) do
        local positions=entity.model and entity.model.positions
        for i=1,positions and #positions or 0,4 do
            local a,b,c,d=positions[i],positions[i+1],positions[i+2],positions[i+3]
            if d and math.abs(a.z-z)<.00001 and math.abs(b.z-z)<.00001
                and math.abs(c.z-z)<.00001 and math.abs(d.z-z)<.00001 then
                local x,y=(a.x+b.x+c.x+d.x)*.25,(a.y+b.y+c.y+d.y)*.25
                centers[#centers+1]={x,y}
                left,top=math.min(left,x),math.max(top,y)
            end
        end
    end
    assert(#centers>0,"Campus sign is missing")
    local grid={{},{},{},{},{}}
    for _,center in ipairs(centers) do
        local col=math.floor((center[1]-left)/cell+.5)
        local row=math.floor((top-center[2])/cell+.5)+1
        grid[row][col]=true
    end
    for index,letter in ipairs(letters) do
        for row,mask in ipairs(letter) do
            for col=0,2 do
                local lit=math.floor(mask/2^(2-col))%2==1
                assert((grid[row][(index-1)*4+col] or false)==lit,"Campus sign glyph is mirrored")
            end
        end
    end
end
checkSignPrefix(roam.world,-26.715,.114,{{4,4,4,4,7},{2,5,7,5,5}}) -- LA

local function checkStrafe(direction)
    frames(20)
    local heading=math.rad(roam.cameraYaw)
    local x,z=roam.x,roam.z
    holdJoystick(direction,0,7)
    local across=(roam.x-x)*math.cos(heading)-(roam.z-z)*math.sin(heading)
    assert(direction*across>.25,"Horizontal joystick is reversed")
end

checkStrafe(1)
checkStrafe(-1)
tap(P.FreeRoamUI.layout(roam).orbitRight)
frames(30)
assert(roam.cameraYaw>20 and roam.cameraYaw<40,"Right orbit did not turn")
checkStrafe(1)
checkStrafe(-1)
tap(P.FreeRoamUI.layout(roam).orbitLeft)
frames(35)

local zoomHUD=P.FreeRoamUI.layout(roam)
for _,zoom in ipairs({assert(zoomHUD.zoomOut),assert(zoomHUD.zoomIn)}) do
    assert(zoom.x-zoom.w*.5>=zoomHUD.left and zoom.x+zoom.w*.5<=zoomHUD.right
        and zoom.y-zoom.h*.5>=zoomHUD.bottom and zoom.y+zoom.h*.5<=zoomHUD.top)
    for _,other in ipairs(zoomHUD.buttons) do
        if other~=zoom then
            assert(math.abs(zoom.x-other.x)>=(zoom.w+other.w)*.5
                or math.abs(zoom.y-other.y)>=(zoom.h+other.h)*.5,"Zoom overlaps another touch target")
        end
    end
    local joy=zoomHUD.joystick
    assert(math.abs(zoom.x-joy.x)>=(zoom.w+joy.w)*.5
        or math.abs(zoom.y-joy.y)>=(zoom.h+joy.h)*.5,"Zoom overlaps the joystick")
end
local baselineFov=roam.camera.lens.fieldOfView
for _=1,5 do tap(P.FreeRoamUI.layout(roam).zoomOut) end
frames(30)
assert(roam.zoomSteps==-3 and roam.camera.lens.fieldOfView>baselineFov+10,"Zoom Out did not widen the view")
for _=1,8 do tap(P.FreeRoamUI.layout(roam).zoomIn) end
frames(30)
assert(roam.zoomSteps==3 and roam.camera.lens.fieldOfView<baselineFov-10,"Zoom In did not tighten the view")
tap(P.FreeRoamUI.layout(roam).zoomOut)
frames(20)
assert(road.story.location.zoomSteps==2,"Stationary zoom did not save")

local initial=P.FreeRoam.location(roam)
local cameraBefore=roam.world.scene.camera.position
holdJoystick(0,1,15)
local moved=P.FreeRoam.location(roam)
assert((moved.x-initial.x)^2+(moved.z-initial.z)^2 > .05,"Campus joystick did not move the athlete")
assert((roam.world.scene.camera.position-cameraBefore):len()>.05,"Campus camera did not follow")
local wallX,wallZ=P.FreeRoamWorld.move(roam.world,0,-9,0,-4,.35)
assert(wallX==0 and wallZ>-10 and wallZ<-9,"School wall did not stop movement")
local eye=P.FreeRoamWorld.camera(roam.world,vec3(0,2,-9),vec3(0,2,-16))
assert(eye.z>-10.25 and eye.z<-9.1,"Camera did not clip in front of the school")
local rig=roam.rig
assert(rig.campus and rig.backpack and rig.backpackStick,"Campus outfit or backpack is missing")
assert(rig.stickRoot.parent==rig.backpackStick and rig.backpackStick.parent==rig.backpack,
    "The stick is not attached to the backpack")
local count=#roam.world.scene.entities
frames(15)
assert(#roam.world.scene.entities==count,"Campus created entities every frame")

local layout=P.FreeRoamUI.layout(roam)
tap(layout.career)
draw()
assert(app.page=="ROAD_JOURNAL")
tap(P.RoadToGlory.layout(road).byId.PLAYER)
draw()
assert(app.page=="CREATOR" and app.storyCreator)
tap(app.layout.options[1])
assert(app.careerNamePart=="first" and type(app.careerName)=="string")
for _=1,#app.careerName do keyboard("\b") end
for part in ("Jordan"):gmatch(".") do keyboard(part) end
keyboard("\n")
assert(P.Athlete.names(road.story.athlete)=="Jordan","Story creator did not save the athlete")
tap(app.layout.home)
draw()
if app.page=="ROAD_JOURNAL" then tap(P.RoadToGlory.layout(road).byId.BACK); draw() end
assert(app.page=="ROAD")

local function near(id)
    local points=P.FreeRoamWorld.anchors(roam.world)
    for _,point in pairs(points) do
        if point.id==id then
            -- Fixture positioning skips only travel time. The world still resolves proximity,
            -- the app consumes the actual touch, and doors build/render the destination.
            P.FreeRoam.release(roam)
            roam.x,roam.z=point.x,point.z
            roam.rig.root.position=vec3(point.x,0,point.z)
            draw()
            return
        end
    end
    error("No campus interaction "..id.." in "..roam.zone)
end

local function interact(id)
    near(id)
    tap(P.FreeRoamUI.layout(roam).interact)
    draw()
end
local function doorTo(zone)
    for _,point in pairs(P.FreeRoamWorld.anchors(roam.world)) do
        if point.zone==zone then
            local zoom=roam.zoomSteps
            interact(point.id)
            frames(20,function() return roam.zone==zone and not roam.transition end)
            assert(roam.zone==zone and not roam.transition,"Door did not load "..zone)
            assert(roam.zoomSteps==zoom and road.story.location.zoomSteps==zoom,"A doorway reset campus zoom")
            draw()
            return true
        end
    end
    return false
end
local function visit(zone)
    if roam.zone==zone or doorTo(zone) then return end
    if roam.zone=="campus" then
        assert(doorTo("school") and doorTo(zone),"No path from campus to "..zone)
    elseif doorTo("campus") then
        visit(zone)
    else
        assert(doorTo("school"),"No path from "..roam.zone.." to "..zone)
        assert(doorTo(zone),"No path from main school to "..zone)
    end
end
local function dialogue()
    local length=0
    while roam.dialogue do
        length=length+1
        assert(length<=8,"Dialogue did not close")
        tap(P.FreeRoamUI.layout(roam).choices[1])
        draw()
    end
    assert(length>0,"Expected authored dialogue")
end

local function walkTo(id)
    local point
    for _,candidate in pairs(P.FreeRoamWorld.anchors(roam.world)) do
        if candidate.id==id then point=candidate break end
    end
    assert(point)
    local joy=P.FreeRoamUI.layout(roam).joystick
    serial=serial+1
    local finger=serial
    input(BEGAN,finger,joy.x,joy.y)
    for _=1,60 do
        local dx,dz=point.x-roam.x,point.z-roam.z
        local distance=math.sqrt(dx*dx+dz*dz)
        if distance<point.radius*.65 then break end
        local angle=math.rad(roam.cameraYaw)
        local s,c=math.sin(angle),math.cos(angle)
        input(MOVING,finger,joy.x+(c*dx-s*dz)*joy.radius/distance,
            joy.y+(-s*dx-c*dz)*joy.radius/distance)
        draw()
    end
    input(ENDED,finger,joy.x,joy.y)
    assert(roam.point and roam.point.id==id,"Could not walk to "..id)
end

-- The remaining route is authored and exercised through the existing touch handler.
local startingBond=road.story.relationships.ethan
walkTo("ethan")
tap(P.FreeRoamUI.layout(roam).interact)
draw()
dialogue()
assert(road.story.mission=="coach" and road.story.relationships.ethan>startingBond)
visit("coach")
interact("coach")
dialogue()
assert(road.story.mission=="rival" and road.story.relationships.coach>0)
visit("campus")
interact("jace")
dialogue()
assert(road.story.mission=="equipment" and road.story.relationships.jace>0)

local function finishPractice(mission)
    interact("practice")
    assert(app.page=="ROAD_PRACTICE" and road.play.controller==P.Gameplay and #road.play.game.squad==6)
    road.play.game.clock=.001
    frames(10,function() return app.page=="ROAD" end)
    assert(app.page=="ROAD" and road.story.results.practice and road.story.mission==mission)
end
finishPractice("equipment")

visit("drip")
checkSignPrefix(roam.world,-5.943,.11,{{6,5,5,5,6},{6,5,6,5,5}}) -- DR
interact("drip")
dialogue()
assert(app.page=="ROAD_SHOP" and road.story.mission=="locker")
local shop=assert(road.shop)
local function shopTap(id)
    tap(P.RoadEquipmentUI.layout(shop).byId[id])
    draw()
end
local original=road.story.equipment.equipped.shaftPattern
local balance=road.story.equipment.credits
local shaftField=P.RoadEquipment.fields.shaftPattern
local zebraChoice=#shaftField[3]
assert(shaftField[3][zebraChoice]=="Imported Zebra")
shopTap("VALUE_PREV")
assert(shop.rig.roadStick.upper.material.map==zebraImage,"Imported preview lost its image")
assert(road.story.equipment.equipped.shaftPattern==original,"Preview changed the save")
shopTap("BUY")
assert(road.story.equipment.credits<balance)
shopTap("EQUIP")
assert(road.story.equipment.equipped.shaftPattern==zebraChoice,"Shaft pattern was not equipped")
shopTap("GLOVES")
shopTap("VALUE_NEXT")
shopTap("BUY")
shopTap("EQUIP")
assert(road.story.equipment.equipped.gloveFinish==2)
shopTap("SLEEVES")
shopTap("VALUE_NEXT")
local sleeve = P.RoadEquipmentUI.layout(shop).byId
if sleeve.BUY and sleeve.BUY.enabled~=false then shopTap("BUY") end
shopTap("EQUIP")
assert(road.story.equipment.equipped.leftSleeve==2)
assert(road.story.equipment.equipped.rightSleeve==1)
shopTap("PRESETS")
shopTap("SAVE_PRESET")
assert(road.story.equipment.presets["1"].gloveFinish==2)
shopTap("BACK")
assert(app.page=="ROAD" and roam.zone=="drip")
assert(road.story.equipment.equipped.shaftPattern==zebraChoice and road.story.equipment.equipped.leftSleeve==2)
assert(roam.rig.stickRoot.parent==roam.rig.backpackStick)
assert(roam.rig.roadStick.upper.material.map==zebraImage,"Hub lost the equipped image")

visit("lockers")
interact("tryout")
dialogue()
assert(road.story.mission=="practice")
visit("campus")
local creditsBeforePractice=road.story.equipment.credits
finishPractice("tryout")
assert(road.story.equipment.credits==creditsBeforePractice,"Optional practice let players claim the practice reward twice")
visit("lockers")
assert(road.story.mission=="tryout" and not road.story.results.tryout)
interact("tryout")
assert(app.page=="ROAD_TRYOUT")
local function finishActivity()
    local session=assert(road.play)
    local game=session.game
    assert(game.positioning and #game.squad==20,"Story did not open the actual FullMatch engine")
    local athlete=P.FullMatch.careerAthlete(game)
    assert(athlete and athlete.rig.root.active and not athlete.rig.campus,"Story match retained the casual rig")
    assert(athlete.rig.roadStick.upper.material.map==zebraImage,"Match lost the equipped image")
    assert(athlete.rig.materials.gloves.metalness>.5,"Equipped chrome gloves did not reach the match rig")
    assert(game.statistics.players["road-ethan"].name=="Ethan Cole","Ethan was missing from the actual lineup")
    if session.presentation then P.Presentation.skip(session) end
    frames(420,function() return game.phase=="LIVE" and not game.careerWaiting end)
    assert(game.phase=="LIVE" and not game.careerWaiting,"Story athlete did not get an active shift")
    -- Seed an in-game stat event and compress the match clock. The normal
    -- update, finalization, summary, award, and persistence routes still run.
    P.FullMatch.recordStat(game,game.careerPlayer,"groundBalls")
    game.clock=.001
    game.period=game.rules.periods
    frames(180,function() return app.page=="STATS" or app.page=="ROAD" end)
    assert(game.phase=="FINAL","Story match did not reach the final whistle")
    if app.page=="STATS" then
        assert(app.statView.summary.final and (app.statView.summary.players["road-player"].stats.groundBalls or 0)>=1)
        tap(P.StatsUI.layout(app.statView).close)
        draw()
    end
    assert(app.page=="ROAD","Story game did not return to campus")
end
finishActivity()
assert(road.story.mission=="debrief")
local evaluation=assert(road.story.results.tryout)
assert(evaluation.grade and evaluation.placement and evaluation.focus)
assert(evaluation.stats.groundBalls and evaluation.stats.groundBalls>=1)
assert(roam.zone=="lockers" and roam.rig.stickRoot.parent==roam.rig.backpackStick)

visit("coach")
interact("coach")
dialogue()
assert(road.story.mission=="promise")
visit("campus")
interact("ethan")
dialogue()
assert(road.story.mission=="debut")
interact("practice")
assert(app.page=="ROAD_TRYOUT")
finishActivity()
assert(road.story.mission=="complete" and road.story.results.debut)
assert(road.story.ethan.statTotals.games>=1 and road.story.athlete.games==1)

interact("maya")
assert(roam.dialogue and roam.dialogue.speaker=="Maya Brooks" and roam.dialogueActor=="maya")
assert(roam.dialogue.text:find("final",1,true),"Maya did not recognize the debut result")
frames(8)
for _,actor in ipairs(roam.world.actors) do
    if actor.id=="maya" then assert(actor.motion.mode=="talk") end
end
dialogue()
assert(not roam.dialogueActor and road.story.mission=="complete")

visit("clubhouse")
near("clubs")
tap(P.FreeRoamUI.layout(roam).orbitRight)
draw()
local clubLocation=P.FreeRoam.location(roam)
assert(clubLocation.cameraYaw~=0,"Orbit control did not move the camera heading")
tap(P.FreeRoamUI.layout(roam).interact)
draw()
assert(app.page=="CLUBS" and app.clubView=="CLUBS")
tap(P.ClubsUI.layout(app.clubView,app.clubs).byId.BACK)
draw()
assert(app.page=="ROAD" and roam==road.roam)
local restored=P.FreeRoam.location(roam)
assert(restored.zone==clubLocation.zone and almost(restored.x,clubLocation.x)
    and almost(restored.z,clubLocation.z) and almost(restored.yaw,clubLocation.yaw)
    and almost(restored.cameraYaw,clubLocation.cameraYaw)
    and restored.zoomSteps==clubLocation.zoomSteps,"Clubs changed the campus return position or zoom")

setup()
draw()
app=appState()
tap(P.Style.screenLayout("FRONT").byId.ROAD)
draw()
assert(app.page=="ROAD")
road=assert(app.road)
restored=P.FreeRoam.location(road.roam)
assert(road.story.mission=="complete" and road.story.results.tryout.grade==evaluation.grade)
assert(P.Athlete.names(road.story.athlete)=="Jordan")
assert(road.story.equipment.equipped.shaftPattern==zebraChoice and road.story.equipment.equipped.leftSleeve==2)
assert(road.roam.rig.roadStick.upper.material.map==zebraImage,"Reloaded shaft lost the image")
assert(road.story.equipment.equipped.gloveFinish==2 and road.story.equipment.presets["1"])
assert(restored.zone==clubLocation.zone and almost(restored.x,clubLocation.x)
    and almost(restored.z,clubLocation.z) and almost(restored.yaw,clubLocation.yaw)
    and almost(restored.cameraYaw,clubLocation.cameraYaw)
    and restored.zoomSteps==clubLocation.zoomSteps,"Reload did not restore campus location or camera")
for key,value in pairs(outside) do
    assert(mock.store[key]==value,"Story touched unrelated save "..key)
end
assert(not mock.store["PolyLax.Statistics.2.career-player"],"Story wrote legacy career statistics")
print("Road to Glory passed camera-relative controls, sign geometry, zoom and persistence, story, equipment, games, Clubs return, and save isolation.")
