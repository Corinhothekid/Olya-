-- POLYLAX BUILD 009
-- FULL MAIN.LUA | 3D CREATOR + PRACTICE
-- Codea / Craft, portrait-friendly

local scene, athlete, closeAthlete, squad, ball, goalie
local page = "CREATOR"
local selectedTab = 2
local selectedOption = {}
local spin = 18
local dragID, dragX
local joyID, joyStart, moveX, moveZ = nil,nil,0,0
local shootID, shotCharge = nil,0
local carrier, mode, passTarget, passT = 1,"SET",nil,0
local shotTime, goals, passes, clock = 0,0,0,180
local announcement, announcementTime = "",0
local elapsed = 0
local ready = false

local C = {
    navy=color(7,28,60), panel=color(16,45,88), panel2=color(29,64,113),
    blue=color(16,115,245), yellow=color(255,211,66),
    white=color(240,244,247), silver=color(174,191,205),
    black=color(25,29,35), turf=color(39,114,65),
    skin={color(247,208,174),color(213,161,119),color(168,110,77),color(105,69,52)},
    hair={color(27,24,25),color(94,59,35),color(190,140,69),color(132,66,46)},
    gear={color(32,121,65),color(34,91,180),color(164,48,64),color(236,240,242),color(34,39,48),color(239,169,47)}
}

local tabs={"FACE","HAIR","BEARD","BODY","HELMET","JERSEY","GLOVES","SHORTS","CLEATS","STICK","NUMBER"}
local choices={
    FACE={"FACE 1","FACE 2","FACE 3","FACE 4"},
    HAIR={"NONE","CLASSIC 1","CLASSIC 2","CLASSIC 3","CLASSIC 4","CLASSIC 5"},
    BEARD={"CLEAN","STUBBLE","MUSTACHE","GOATEE","SHORT","FULL"},
    BODY={"LEAN","ATHLETIC","STOCKY","TALL"},
    HELMET={"WHITE","BLUE","RED","BLACK","GREEN","GOLD"},
    JERSEY={"GREEN","BLUE","RED","WHITE","BLACK","GOLD"},
    GLOVES={"WHITE","BLUE","RED","BLACK","GREEN","GOLD"},
    SHORTS={"WHITE","BLUE","RED","BLACK","GREEN","GOLD"},
    CLEATS={"WHITE","BLUE","RED","BLACK","GREEN","GOLD"},
    STICK={"WHITE","BLUE","RED","BLACK","GREEN","GOLD"},
    NUMBER={"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36","37","38","39","40","41","42","43","44","45","46","47","48","49","50","51","52","53","54","55","56","57","58","59","60","61","62","63","64","65","66","67","68","69","70","71","72","73","74","75","76","77","78","79","80","81","82","83","84","85","86","87","88","89","90","91","92","93","94","95","96","97","98","99"}
}
local profile={FACE=2,HAIR=3,BEARD=1,BODY=2,HELMET=1,JERSEY=1,GLOVES=1,SHORTS=4,CLEATS=1,STICK=1,NUMBER=4}
local formation={
    {-4.6,1.2,"M1"},{4.6,1.2,"M2"},{0,-9.8,"M3"},
    {-6.3,-8.2,"A1"},{6.3,-8.2,"A2"},{0,-16,"X"}
}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function inRect(x,y,cx,cy,w,h) return math.abs(x-cx)<w*.5 and math.abs(y-cy)<h*.5 end
local function gearColor(i) return C.gear[i] end
local function entity(parent,x,y,z)
    local e=scene:entity()
    if parent then e.parent=parent end
    e.position=vec3(x or 0,y or 0,z or 0)
    return e
end
local function block(parent,x,y,z,w,h,d,tint)
    local e=entity(parent,x,y,z)
    e.model=craft.model.cube()
    e.scale=vec3(w,h,d)
    e.material=craft.material("Materials:Standard")
    e.material.diffuse=tint
    return e
end
local function sphere(parent,x,y,z,s,tint)
    -- Low-resolution Craft sphere provides softened, faceted contours.
    local e=entity(parent,x,y,z)
    e.model=craft.model.icosphere(1)
    e.scale=vec3(s,s,s)
    e.material=craft.material("Materials:Standard")
    e.material.diffuse=tint
    return e
end
local function recolor(parts,tint)
    if not parts then return end
    for _,e in ipairs(parts) do e.material.diffuse=tint end
end
local function add(parts,e) parts[#parts+1]=e; return e end
local function newAthlete(custom)
    local r={}
    r.root=entity(nil,0,0,0)
    r.groups={skin={},hair={},beard={},helmet={},jersey={},shorts={},gloves={},cleats={},stick={}}
    local g=r.groups
    local skin=C.skin[custom and profile.FACE or 2]
    local jersey=gearColor(custom and profile.JERSEY or 2)
    local shorts=gearColor(custom and profile.SHORTS or 4)
    local glove=gearColor(custom and profile.GLOVES or 1)
    local shoe=gearColor(custom and profile.CLEATS or 1)
    local shell=gearColor(custom and profile.HELMET or 4)
    local headTint=gearColor(custom and profile.STICK or 4)
    local hair=C.hair[2]
    r.body=entity(r.root,0,1.06,0)
    add(g.jersey,block(r.body,0,.48,0,.76,.72,.44,jersey))
    add(g.jersey,block(r.body,0,.79,-.02,.81,.18,.47,jersey))
    block(r.body,0,.86,-.06,.35,.06,.35,C.white)
    for _,side in ipairs({-1,1}) do
        add(g.jersey,block(r.body,side*.46,.72,0,.25,.25,.41,jersey))
        block(r.body,side*.46,.64,-.218,.23,.045,.025,C.white)
    end
    add(g.shorts,block(r.body,0,-.09,0,.78,.34,.49,shorts))
    for _,side in ipairs({-1,1}) do
        add(g.shorts,block(r.body,side*.2,-.26,0,.35,.28,.45,shorts))
        add(g.skin,block(r.body,side*.22,-.57,0,.24,.47,.26,skin))
        block(r.body,side*.22,-.81,0,.27,.16,.29,C.white)
        add(g.cleats,block(r.body,side*.22,-.94,-.11,.34,.18,.50,shoe))
        -- Short sleeves and elbow pads, no football shoulder shells
        add(g.skin,block(r.body,side*.56,.44,0,.22,.37,.25,skin))
        add(g.gloves,block(r.body,side*.57,.25,-.04,.28,.24,.30,glove))
        block(r.body,side*.57,.48,-.14,.24,.12,.05,C.silver)
    end
    add(g.skin,block(r.body,0,.99,0,.25,.21,.25,skin))
    r.head=entity(r.body,0,1.18,0)
    add(g.skin,block(r.head,0,.08,-.015,.59,.57,.55,skin))
    add(g.skin,block(r.head,0,-.20,-.04,.49,.13,.48,skin))
    for _,side in ipairs({-1,1}) do
        block(r.head,side*.14,.13,-.299,.055,.055,.025,C.black)
        block(r.head,side*.14,.205,-.30,.15,.025,.025,C.black)
    end
    r.hairRoot=entity(r.head,0,0,0)
    add(g.hair,block(r.hairRoot,0,.42,.015,.65,.19,.59,hair))
    for i=-2,2 do
        local strand=add(g.hair,block(r.hairRoot,i*.12,.51,-.12,.13,.13,.32,hair))
        strand.eulerAngles=vec3(0,0,i*7)
    end
    r.beardRoot=entity(r.head,0,0,0)
    add(g.beard,block(r.beardRoot,0,-.21,-.305,.45,.14,.045,hair))
    add(g.beard,block(r.beardRoot,-.22,-.1,-.30,.07,.22,.045,hair))
    add(g.beard,block(r.beardRoot,.22,-.1,-.30,.07,.22,.045,hair))
    r.helmetRoot=entity(r.head,0,0,0)
    -- Distinctive lacrosse helmet: brow, crown, side vents, chin guard and cage
    add(g.helmet,block(r.helmetRoot,0,.44,.055,.75,.37,.68,shell))
    add(g.helmet,block(r.helmetRoot,0,.62,.08,.54,.13,.54,shell))
    add(g.helmet,block(r.helmetRoot,0,.31,-.34,.70,.11,.15,shell))
    for _,side in ipairs({-1,1}) do
        local wing=add(g.helmet,block(r.helmetRoot,side*.35,.39,.06,.16,.27,.51,shell))
        wing.eulerAngles=vec3(0,0,side*22)
        add(g.helmet,block(r.helmetRoot,side*.40,.11,.03,.12,.32,.32,shell))
        block(r.helmetRoot,side*.43,.32,-.08,.026,.075,.16,C.black)
    end
    -- Visor and cage sit in front of the face, but stick does not
    block(r.helmetRoot,0,.27,-.40,.64,.055,.07,C.white)
    for i=-2,2 do
        block(r.helmetRoot,i*.13,-.015,-.42,.018,.34,.022,C.silver)
    end
    for i=0,2 do
        block(r.helmetRoot,0,-.15+i*.13,-.43,.60,.018,.022,C.silver)
    end
    block(r.helmetRoot,0,-.24,-.38,.37,.09,.09,C.white)
    -- Stick rests at right side, its head below shoulder height.
    r.stickRoot=entity(r.root,.94,.85,-.02)
    r.stickRoot.eulerAngles=vec3(0,0,-8)
    block(r.stickRoot,0,-.04,0,.055,1.72,.055,C.silver)
    block(r.stickRoot,0,-.56,0,.08,.36,.08,C.black)
    for _,side in ipairs({-1,1}) do
        add(g.stick,block(r.stickRoot,side*.17,.89,0,.045,.40,.075,headTint))
    end
    add(g.stick,block(r.stickRoot,0,1.1,0,.39,.05,.08,headTint))
    for i=-2,2 do block(r.stickRoot,i*.065,.89,-.04,.012,.33,.012,C.white) end
    for i=0,3 do block(r.stickRoot,0,.75+i*.1,-.04,.31,.012,.012,C.white) end
    r.pocket=entity(r.stickRoot,0,.92,-.08)
    r.custom=custom
    return r
end
local function applyProfile(r)
    if not r or not r.custom then return end
    local g=r.groups
    recolor(g.skin,C.skin[profile.FACE])
    recolor(g.hair,C.hair[math.min(4,math.max(1,profile.HAIR-1))])
    recolor(g.beard,C.hair[math.min(4,math.max(1,profile.HAIR-1))])
    recolor(g.helmet,gearColor(profile.HELMET))
    recolor(g.jersey,gearColor(profile.JERSEY))
    recolor(g.shorts,gearColor(profile.SHORTS))
    recolor(g.gloves,gearColor(profile.GLOVES))
    recolor(g.cleats,gearColor(profile.CLEATS))
    recolor(g.stick,gearColor(profile.STICK))
    r.hairRoot.active=(profile.HAIR~=1)
    r.beardRoot.active=(profile.BEARD~=1)
    r.helmetRoot.active=(tabs[selectedTab]=="HELMET")
    r.stickRoot.active=(tabs[selectedTab]=="STICK")
    local width=({.91,1,1.13,.96})[profile.BODY]
    local height=({.97,1,1,1.10})[profile.BODY]
    r.body.scale=vec3(width,height,width)
end
local function configureScene()
    scene=craft.scene()
    scene.ambientColor=color(170,180,198)
    scene.sun.rotation=quat.eulerAngles(48,28,0)
end
local function creatorScene()
    ready=false
    configureScene()
    scene.camera.position=vec3(0,2.9,8.6)
    scene.camera.eulerAngles=vec3(8,180,0)
    block(nil,0,-.22,0,15,.25,15,C.navy)
    block(nil,-1.55,-.09,0,2.25,.15,2.3,C.panel2)
    block(nil,1.55,-.09,0,2.25,.15,2.3,C.panel2)
    athlete=newAthlete(true)
    athlete.root.position=vec3(-1.55,0,0)
    athlete.root.eulerAngles=vec3(0,spin,0)
    closeAthlete=newAthlete(true)
    closeAthlete.root.position=vec3(1.55,-.2,1.8)
    closeAthlete.root.scale=vec3(1.55,1.55,1.55)
    closeAthlete.root.eulerAngles=vec3(0,0,0)
    applyProfile(athlete)
    applyProfile(closeAthlete)
    ready=true
end
local function makeField()
    block(nil,0,-.14,0,34,.25,50,color(27,77,47))
    for i=0,9 do
        block(nil,0,.015,-17+(i+.5)*3.4,18,.025,3.4,
            i%2==0 and color(44,121,72) or color(36,105,61))
    end
    local function line(x,z,w,d) block(nil,x,.045,z,w,.026,d,C.white) end
    line(-9,0,.07,34); line(9,0,.07,34)
    line(0,-17,18,.07); line(0,17,18,.07)
    line(0,0,18,.07); line(0,-8,18,.07); line(0,8,18,.07)
    local orange=color(245,112,26)
    block(nil,-1.05,.9,-13,.11,1.8,.11,orange)
    block(nil,1.05,.9,-13,.11,1.8,.11,orange)
    block(nil,0,1.8,-13,2.2,.11,.11,orange)
    for i=0,10 do
        block(nil,-1.05+i*.21,.88,-14.1,.018,1.75,.018,C.silver)
    end
    for i=0,8 do
        block(nil,0,i*.22,-14.1,2.1,.018,.018,C.silver)
    end
end
local function gameScene()
    ready=false
    page="GAME"
    configureScene()
    scene.camera.position=vec3(0,24,27)
    scene.camera.eulerAngles=vec3(42,180,0)
    makeField()
    squad={}
    for i,f in ipairs(formation) do
        local rig=newAthlete(i==1)
        rig.root.position=vec3(f[1],0,f[2])
        squad[i]={rig=rig,x=f[1],z=f[2],name=f[3],phase=i*.8}
        if i==1 then
            -- Gameplay always wears helmet and holds stick
            applyProfile(rig)
            rig.helmetRoot.active=true
            rig.stickRoot.active=true
            rig.hairRoot.active=false
            rig.beardRoot.active=false
        else
            rig.hairRoot.active=false
            rig.beardRoot.active=false
            rig.helmetRoot.active=true
        end
    end
    goalie=newAthlete(false)
    goalie.root.position=vec3(0,0,-12.3)
    goalie.hairRoot.active=false
    goalie.beardRoot.active=false
    ball=block(nil,0,1.5,0,.2,.2,.2,C.yellow)
    carrier=1; mode="SET"; passTarget=nil; shotTime=0
    clock=180; goals=0; passes=0; elapsed=0
    ready=true
end
local function resetFormation()
    for i,p in ipairs(squad) do p.x=formation[i][1]; p.z=formation[i][2] end
end
local function passTo(i)
    if passTarget or shotTime>0 or i==carrier then return end
    passTarget=i; passT=0; passes=passes+1
end
local function passNearest()
    local pos=squad[carrier].rig.root.position
    local best,idx=999,nil
    for i,p in ipairs(squad) do
        if i~=carrier then
            local d=(p.rig.root.position-pos):len()
            if d<best then best=d; idx=i end
        end
    end
    if idx then passTo(idx) end
end
local function swingNext()
    local order={1,2,5,6,4,1}
    for i=1,#order-1 do
        if order[i]==carrier then return order[i+1] end
    end
    return 1
end
local function resetPlay()
    carrier=1; passTarget=nil; shotTime=0; mode="SET"
    resetFormation()
    for i,p in ipairs(squad) do p.rig.root.position=vec3(p.x,0,p.z) end
end
local function updateGame(dt)
    elapsed=elapsed+dt
    clock=math.max(0,clock-dt)
    announcementTime=math.max(0,announcementTime-dt)
    if clock<=0 then return end
    resetFormation()
    if mode=="CLEAR" then
        squad[3].x=carrier==1 and 3.5 or -3.5
        squad[4].z=-12
        squad[5].z=-12
    end
    for i,p in ipairs(squad) do
        local pos=p.rig.root.position
        local tx,tz=p.x,p.z
        if i==carrier and not passTarget and shotTime<=0 then
            tx=clamp(pos.x+moveX*6*dt,-8.4,8.4)
            tz=clamp(pos.z+moveZ*6*dt,-16.5,15.5)
        end
        local delta=vec3(tx-pos.x,0,tz-pos.z)
        local len=delta:len()
        local step=math.min(len,(i==carrier and 10 or 4.4)*dt)
        if len>.0001 then pos=pos+delta/len*step end
        p.rig.root.position=vec3(pos.x,0,pos.z)
        p.phase=p.phase+dt*6
        p.rig.body.eulerAngles=vec3(math.sin(p.phase)*1.2,0,0)
    end
    local goalX=clamp(squad[carrier].rig.root.position.x,-1,1)
    goalie.root.position=vec3(goalX,0,-12.3)
    if passTarget then
        passT=passT+dt/.48
        local t=clamp(passT,0,1)
        local a=squad[carrier].rig.pocket.worldPosition
        local b=squad[passTarget].rig.pocket.worldPosition
        ball.position=a+(b-a)*t+vec3(0,math.sin(t*math.pi)*.5,0)
        if t>=1 then
            carrier=passTarget; passTarget=nil
            if mode=="SWING" then
                -- One pass per tap; prevents endless automatic loops.
                mode="SET"
            end
        end
    elseif shotTime>0 then
        shotTime=shotTime+dt
        local a=squad[carrier].rig.pocket.worldPosition
        local b=vec3(0,1.1,-13)
        local t=clamp(shotTime/.65,0,1)
        ball.position=a+(b-a)*t
        if t>=1 then
            if math.abs(squad[carrier].rig.root.position.x)<7 then goals=goals+1 end
            announcement="SHOT COMPLETE"; announcementTime=1.3
            resetPlay()
        end
    else
        ball.position=squad[carrier].rig.pocket.worldPosition
    end
end
local function button(x,y,w,h,label,active)
    rectMode(CENTER); noStroke()
    fill(active and C.yellow or C.panel2)
    rect(x,y,w,h,8)
    fill(active and C.navy or C.white)
    fontSize(12); textAlign(CENTER); text(label,x,y)
end
local function creatorHUD()
    pushStyle(); resetMatrix(); ortho(); viewMatrix(matrix())
    rectMode(CORNER); noStroke()
    fill(C.navy); rect(0,HEIGHT-95,WIDTH,95)
    fill(C.white); textAlign(LEFT); fontSize(21)
    text("MODIFY PLAYER",22,HEIGHT-45)
    fontSize(11); fill(C.silver)
    text("3D FULL BODY  /  FEATURE CLOSE-UP",22,HEIGHT-70)
    -- 3D models remain visible above the customization tray
    fill(C.white); textAlign(CENTER); fontSize(11)
    text("ROTATE PLAYER",WIDTH*.25,HEIGHT*.54)
    text(tabs[selectedTab].." VIEW",WIDTH*.75,HEIGHT*.54)
    fill(C.navy); rect(0,0,WIDTH,HEIGHT*.51)
    fill(C.white); textAlign(LEFT); fontSize(18)
    text(tabs[selectedTab],18,HEIGHT*.47)
    button(WIDTH*.79,HEIGHT*.47,WIDTH*.34,43,"DONE",false)
    -- Scrollable category strip, two rows
    local cw=(WIDTH-16)/4
    for i,label in ipairs(tabs) do
        local row=math.floor((i-1)/4)
        local col=(i-1)%4
        button(8+cw*(col+.5),HEIGHT*.414-row*38,cw-5,32,label,i==selectedTab)
    end
    local list=choices[tabs[selectedTab]]
    local maxVisible=6
    local start=clamp(profile[tabs[selectedTab]]-2,1,math.max(1,#list-maxVisible+1))
    local tileW=(WIDTH-34)/3
    for slot=1,math.min(maxVisible,#list) do
        local index=start+slot-1
        local col=(slot-1)%3
        local row=math.floor((slot-1)/3)
        local cx=12+tileW*(col+.5)
        local cy=HEIGHT*.235-row*78
        local isOn=profile[tabs[selectedTab]]==index
        rectMode(CENTER); fill(isOn and C.yellow or C.panel)
        rect(cx,cy,tileW-9,70,9)
        fill(isOn and C.navy or C.white)
        textAlign(CENTER); fontSize(12)
        text(list[index],cx,cy)
    end
    fill(C.silver); fontSize(11); textAlign(CENTER)
    text("USE ARROWS FOR MORE OPTIONS",WIDTH/2,HEIGHT*.075)
    button(WIDTH*.16,HEIGHT*.035,WIDTH*.26,38,"<",false)
    button(WIDTH*.84,HEIGHT*.035,WIDTH*.26,38,">",false)
    popStyle()
end
local function gameHUD()
    pushStyle(); resetMatrix(); ortho(); viewMatrix(matrix())
    rectMode(CORNER); noStroke()
    fill(C.navy); rect(0,HEIGHT-85,WIDTH,85)
    fill(C.white); textAlign(LEFT); fontSize(22)
    text("POLYLAX",12,HEIGHT-30)
    fontSize(12)
    text("BALL "..squad[carrier].name.."  |  "..mode,12,HEIGHT-59)
    textAlign(RIGHT)
    text("GOALS "..goals.."  PASSES "..passes,WIDTH-12,HEIGHT-30)
    text(string.format("%d:%02d",math.floor(clock/60),math.floor(clock%60)),WIDTH-12,HEIGHT-59)
    fill(C.navy); rect(0,0,WIDTH,HEIGHT*.28)
    fill(C.panel2); ellipse(WIDTH*.17,HEIGHT*.105,100)
    fill(C.blue); ellipse(WIDTH*.17+moveX*29,HEIGHT*.105+moveZ*29,43)
    button(WIDTH*.24,HEIGHT*.235,WIDTH*.42,42,"SWING",mode=="SWING")
    button(WIDTH*.74,HEIGHT*.235,WIDTH*.44,42,"CLEAR THROUGH",mode=="CLEAR")
    button(WIDTH*.50,HEIGHT*.085,WIDTH*.22,55,"DODGE",false)
    button(WIDTH*.71,HEIGHT*.085,WIDTH*.19,55,"PASS",false)
    button(WIDTH*.89,HEIGHT*.105,WIDTH*.19,72,"SHOOT",false)
    if announcementTime>0 then
        fill(C.yellow); fontSize(20); textAlign(CENTER)
        text(announcement,WIDTH/2,HEIGHT*.73)
    end
    popStyle()
end
function setup()
    page="CREATOR"
    selectedTab=2
    spin=18
    creatorScene()
end
function draw()
    if not ready then background(C.navy); return end
    local dt=math.min(DeltaTime or .016,.05)
    if page=="CREATOR" then
        athlete.root.eulerAngles=vec3(0,spin,0)
        -- Focus close-up preview by enlarging a second copy and hiding its lower body
        closeAthlete.root.eulerAngles=vec3(0,spin*.25,0)
        scene:update(dt)
        scene:draw()
        creatorHUD()
    else
        updateGame(dt)
        scene:update(dt)
        scene:draw()
        gameHUD()
    end
end
local function changeChoice(direction)
    local key=tabs[selectedTab]
    local count=#choices[key]
    profile[key]=((profile[key]-1+direction)%count)+1
    applyProfile(athlete)
    applyProfile(closeAthlete)
end
local function creatorTouch(t)
    if t.state==BEGAN then
        if inRect(t.x,t.y,WIDTH*.79,HEIGHT*.47,WIDTH*.34,43) then
            gameScene(); return
        end
        local cw=(WIDTH-16)/4
        for i=1,#tabs do
            local row=math.floor((i-1)/4)
            local col=(i-1)%4
            if inRect(t.x,t.y,8+cw*(col+.5),HEIGHT*.414-row*38,cw-5,32) then
                selectedTab=i
                applyProfile(athlete); applyProfile(closeAthlete)
                return
            end
        end
        if t.y<HEIGHT*.065 then
            changeChoice(t.x<WIDTH/2 and -1 or 1)
            return
        end
        local list=choices[tabs[selectedTab]]
        local start=clamp(profile[tabs[selectedTab]]-2,1,math.max(1,#list-6+1))
        local tileW=(WIDTH-34)/3
        for slot=1,math.min(6,#list) do
            local col=(slot-1)%3
            local row=math.floor((slot-1)/3)
            local cx=12+tileW*(col+.5)
            local cy=HEIGHT*.235-row*78
            if inRect(t.x,t.y,cx,cy,tileW-9,70) then
                profile[tabs[selectedTab]]=start+slot-1
                applyProfile(athlete); applyProfile(closeAthlete)
                return
            end
        end
        if t.y>HEIGHT*.52 then dragID=t.id; dragX=t.x end
    elseif t.state==MOVING then
        if dragID==t.id then
            spin=spin+(t.x-dragX)*.6
            dragX=t.x
        end
    elseif t.state==ENDED or t.state==CANCELLED then
        if dragID==t.id then dragID=nil end
    end
end
local function gameTouch(t)
    if t.state==BEGAN then
        if inRect(t.x,t.y,WIDTH*.24,HEIGHT*.235,WIDTH*.42,42) then
            mode="SWING"; passTo(swingNext()); return
        end
        if inRect(t.x,t.y,WIDTH*.74,HEIGHT*.235,WIDTH*.44,42) then
            mode="CLEAR"; return
        end
        if inRect(t.x,t.y,WIDTH*.71,HEIGHT*.085,WIDTH*.19,55) then
            mode="SET"; passNearest(); return
        end
        if inRect(t.x,t.y,WIDTH*.89,HEIGHT*.105,WIDTH*.19,72) then
            if not passTarget and shotTime<=0 then shotTime=.001 end
            return
        end
        if inRect(t.x,t.y,WIDTH*.50,HEIGHT*.085,WIDTH*.22,55) then
            -- Quick lateral dodge
            local p=squad[carrier].rig.root
            p.position=vec3(clamp(p.position.x+1.1,-8,8),0,p.position.z)
            return
        end
        if t.x<WIDTH*.38 and t.y<HEIGHT*.20 then
            joyID=t.id; joyStart=vec2(t.x,t.y)
        end
    elseif t.state==MOVING then
        if joyID==t.id and joyStart then
            local d=vec2(t.x,t.y)-joyStart
            if d:len()>45 then d=d:normalize()*45 end
            moveX=d.x/45; moveZ=d.y/45
        end
    elseif t.state==ENDED or t.state==CANCELLED then
        if joyID==t.id then joyID=nil; joyStart=nil; moveX=0; moveZ=0 end
    end
end
function touched(t)
    if page=="CREATOR" then creatorTouch(t) else gameTouch(t) end
end
-- END BUILD 009