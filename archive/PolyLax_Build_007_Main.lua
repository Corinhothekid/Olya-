-- POLYLAX BUILD 007: LACROSSE PLAYER CREATOR + SIX-MAN OFFENSE
-- Paste this entire file into Codea Main.lua

local scene, team, goalie, ball
local ready=false
local carrier=1
local ballMode="held"
local passFrom,passTo,passProgress,passStart,passEnd
local passDuration=.45
local mode="SET"
local swingTimer=0
local clearTimer=0
local action="idle"
local actionT=0
local actionRelease=false
local actionFired=false
local shotVel=vec3(0,0,0)
local shotReset=0
local aim=0
local joyID,shootID,joyOrigin,shootOrigin
local mx,mz=0,0
local dodgeTime,dodgeCD=0,0
local dodgeDX,dodgeDZ=0,-1
local message,messageTimer="",0
local goals,shots,passes,saves=0,0,0,0
local clock=180
local finished=false
local elapsed=0
local colors={blue=color(32,78,168),white=color(239,242,249),metal=color(168,181,190),skin=color(193,149,113),red=color(162,47,62)}
local screen="CREATOR"
local profile={name="MY PLAYER",number=3,skin=2,hair=1,helmet=1,jersey=1,shorts=1,stick=1}
local palette={color(22,120,64),color(25,86,178),color(172,44,62),color(242,242,237),color(28,31,37),color(241,170,48)}
local skinColors={color(246,207,166),color(215,162,120),color(168,109,75),color(112,70,52)}
local hairColors={color(26,24,24),color(95,55,31),color(197,145,69),color(129,51,34)}
local creatorTabs={"SKIN","HAIR","HELMET","JERSEY","SHORTS","STICK","NUMBER"}
local creatorTab=1
local function profileColor(key) return palette[profile[key]] end

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function lerp(a,b,t) return a+(b-a)*t end
local function smooth(t) t=clamp(t,0,1) return t*t*(3-2*t) end
local function distance(x,y,a,b) return math.sqrt((x-a)^2+(y-b)^2) end
local function say(s) message=s messageTimer=1.6 end
local function make(parent,name,pos)
    local e=scene:entity()
    e.name=name
    if parent then e.parent=parent end
    e.position=pos
    return e
end
local function cube(parent,name,pos,size,tint)
    local e=make(parent,name,pos)
    e.model=craft.model.cube()
    e.scale=size
    e.material=craft.material("Materials:Standard")
    e.material.diffuse=tint
    return e
end
local function worldCube(name,pos,size,tint) return cube(nil,name,pos,size,tint) end
local function segment(e,a,b,w)
    local d=b-a
    local len=d:len()
    if len<.001 then return end
    e.position=(a+b)*.5
    e.scale=vec3(w,len,w)
    local horizontal=math.sqrt(d.y*d.y+d.z*d.z)
    e.eulerAngles=vec3(math.deg(math.atan(d.z,d.y)),0,-math.deg(math.atan(d.x,horizontal)))
end
local function createAthlete(name,tint,custom)
    local r={}
    local kit=custom and profileColor("jersey") or tint
    local shorts=custom and profileColor("shorts") or colors.white
    local skin=custom and skinColors[profile.skin] or colors.skin
    local helmet=custom and profileColor("helmet") or colors.white
    local stickColor=custom and profileColor("stick") or colors.white
    r.root=make(nil,name,vec3(0,0,0))
    r.body=make(r.root,"Body",vec3(0,1.14,0))
    -- Lacrosse silhouette: narrow torso, no football shoulder armor.
    cube(r.body,"Jersey",vec3(0,.5,0),vec3(.74,.81,.44),kit)
    cube(r.body,"Jersey Chest",vec3(0,.59,-.229),vec3(.55,.40,.025),kit)
    cube(r.body,"Collar",vec3(0,.94,-.07),vec3(.35,.08,.36),colors.white)
    for _,side in ipairs({-1,1}) do
        cube(r.body,"Short Sleeve",vec3(side*.44,.76,0),vec3(.25,.29,.45),kit)
        cube(r.body,"Sleeve Stripe",vec3(side*.44,.67,-.235),vec3(.22,.055,.025),colors.white)
        cube(r.body,"Side Panel",vec3(side*.38,.39,0),vec3(.025,.54,.43),colors.white)
    end
    cube(r.body,"Lacrosse Shorts",vec3(0,-.11,0),vec3(.77,.38,.48),shorts)
    for _,side in ipairs({-1,1}) do
        cube(r.body,"Shorts Stripe",vec3(side*.39,-.11,0),vec3(.025,.33,.46),kit)
    end
    -- Slightly oversized lacrosse helmet with faceted crown.
    r.head=make(r.body,"Head",vec3(0,1.13,0))
    cube(r.head,"Face",vec3(0,.07,-.07),vec3(.62,.48,.58),skin)
    cube(r.head,"Helmet Shell",vec3(0,.33,.05),vec3(.74,.46,.69),helmet)
    cube(r.head,"Helmet Crown",vec3(0,.58,.06),vec3(.57,.13,.55),helmet)
    for _,side in ipairs({-1,1}) do
        local facet=cube(r.head,"Angled Helmet",vec3(side*.31,.48,.05),vec3(.18,.19,.55),helmet)
        facet.eulerAngles=vec3(0,0,side*25)
        cube(r.head,"Ear Protector",vec3(side*.39,.14,.02),vec3(.13,.30,.36),helmet)
        cube(r.head,"Vent",vec3(side*.46,.31,-.03),vec3(.018,.075,.15),colors.metal)
    end
    cube(r.head,"Visor Brow",vec3(0,.28,-.35),vec3(.64,.08,.08),colors.white)
    for i=-2,2 do
        cube(r.head,"Facemask Upright",vec3(i*.135,-.005,-.435),vec3(.022,.34,.025),colors.metal)
    end
    for i=0,2 do
        cube(r.head,"Facemask Crossbar",vec3(0,-.14+i*.13,-.45),vec3(.61,.023,.027),colors.metal)
    end
    cube(r.head,"Chin Cup",vec3(0,-.22,-.39),vec3(.37,.09,.09),colors.white)
    r.leftLeg=make(r.root,"Left Leg",vec3(-.21,.93,0))
    r.rightLeg=make(r.root,"Right Leg",vec3(.21,.93,0))
    for _,leg in ipairs({r.leftLeg,r.rightLeg}) do
        cube(leg,"Short Leg",vec3(0,-.14,0),vec3(.31,.28,.36),shorts)
        cube(leg,"Bare Shin",vec3(0,-.45,0),vec3(.25,.44,.28),skin)
        cube(leg,"Crew Sock",vec3(0,-.68,0),vec3(.28,.20,.3),colors.white)
        cube(leg,"Cleat",vec3(0,-.82,-.11),vec3(.35,.20,.52),colors.white)
    end
    r.rightShoulder=make(r.body,"Right Shoulder",vec3(.49,.76,0))
    r.leftShoulder=make(r.body,"Left Shoulder",vec3(-.49,.76,0))
    r.stick=make(r.body,"Stick Assembly",vec3(.36,.43,-.47))
    cube(r.stick,"Shaft",vec3(0,-.08,0),vec3(.065,1.85,.065),colors.metal)
    cube(r.stick,"Grip Tape",vec3(0,-.55,0),vec3(.085,.45,.085),colors.black or color(20,20,20))
    cube(r.stick,"Left Sidewall",vec3(-.18,.94,0),vec3(.045,.47,.09),stickColor)
    cube(r.stick,"Right Sidewall",vec3(.18,.94,0),vec3(.045,.47,.09),stickColor)
    cube(r.stick,"Scoop",vec3(0,1.18,0),vec3(.42,.055,.09),stickColor)
    for i=-2,2 do
        cube(r.stick,"Pocket String",vec3(i*.065,.95,-.05),vec3(.012,.35,.014),colors.white)
    end
    for i=0,3 do
        cube(r.stick,"Cross String",vec3(0,.8+i*.1,-.05),vec3(.31,.012,.014),colors.white)
    end
    r.pocket=make(r.stick,"Pocket Marker",vec3(0,.94,-.09))
    r.rightGlove=cube(r.stick,"Top Glove",vec3(0,.25,0),vec3(.26,.23,.27),colors.white)
    r.leftGlove=cube(r.stick,"Bottom Glove",vec3(0,-.53,0),vec3(.26,.23,.27),colors.white)
    r.ru=cube(nil,name.." RU",vec3(0,0,0),vec3(.22,.5,.22),kit)
    r.rf=cube(nil,name.." RF",vec3(0,0,0),vec3(.20,.5,.20),skin)
    r.lu=cube(nil,name.." LU",vec3(0,0,0),vec3(.22,.5,.22),kit)
    r.lf=cube(nil,name.." LF",vec3(0,0,0),vec3(.20,.5,.20),skin)
    return r
end
local function updateArms(r)
    local rs=r.rightShoulder.worldPosition
    local ls=r.leftShoulder.worldPosition
    local rh=r.rightGlove.worldPosition
    local lh=r.leftGlove.worldPosition
    local re=rs+(rh-rs)*.52+vec3(.22,-.13,.1)
    local le=ls+(lh-ls)*.52+vec3(-.22,-.13,.1)
    segment(r.ru,rs,re,.25)
    segment(r.rf,re,rh,.23)
    segment(r.lu,ls,le,.25)
    segment(r.lf,le,lh,.23)
end
local function field()
    worldCube("Ground",vec3(0,-.15,0),vec3(40,.25,55),color(30,75,44))
    for i=0,7 do
        worldCube("Turf",vec3(0,0,-17+(i+.5)*34/8),vec3(18,.025,34/8),i%2==0 and color(44,117,67) or color(38,103,58))
    end
    local function line(x,z,w,d) return worldCube("Line",vec3(x,.04,z),vec3(w,.025,d),colors.white) end
    line(-9,0,.09,34) line(9,0,.09,34)
    line(0,-17,18,.09) line(0,17,18,.09)
    line(0,0,18,.09) line(0,-8,18,.09) line(0,8,18,.09)
    for i=0,47 do
        local a=i*math.pi*2/48
        local b=(i+1)*math.pi*2/48
        local x1,z1=math.cos(a)*2.6,-13+math.sin(a)*2.6
        local x2,z2=math.cos(b)*2.6,-13+math.sin(b)*2.6
        local dx,dz=x2-x1,z2-z1
        local e=line((x1+x2)/2,(z1+z2)/2,.055,math.sqrt(dx*dx+dz*dz)+.025)
        e.eulerAngles=vec3(0,math.deg(math.atan(dx,dz)),0)
    end
    local orange=color(252,114,25)
    worldCube("Left Post",vec3(-1.05,.9,-13),vec3(.12,1.8,.12),orange)
    worldCube("Right Post",vec3(1.05,.9,-13),vec3(.12,1.8,.12),orange)
    worldCube("Crossbar",vec3(0,1.8,-13),vec3(2.2,.12,.12),orange)
    worldCube("Back Net",vec3(0,.95,-14.2),vec3(2.1,1.7,.04),color(193,208,217))
    worldCube("Net Roof",vec3(0,1.8,-13.6),vec3(2.1,.04,1.2),color(193,208,217))
    for side=-1,1,2 do
        for row=1,3 do worldCube("Bleachers",vec3(side*(10+row),row*.35,0),vec3(1.5,.3,28),color(107,118,131)) end
    end
end
-- Goal is at z=-13. X stays behind the goal at z<-13.
-- M1 and M2 are high; M3 is crease; A1/A2 wings; A3 is X.
local base={
    {name="M1",role="mid",x=-4.6,z=1.2},
    {name="M2",role="mid",x=4.6,z=1.2},
    {name="M3",role="mid",x=0,z=-9.8},
    {name="A1",role="attack",x=-6.3,z=-8.2},
    {name="A2",role="attack",x=6.3,z=-8.2},
    {name="A3",role="attack",x=0,z=-16.0}
}
local function assignBase()
    for i,p in ipairs(team) do p.tx=base[i].x p.tz=base[i].z end
end
local function setupClear()
    assignBase()
    -- Which midfielder is carrying determines the clear.
    if carrier==1 then
        team[1].tx=-5.7 team[1].tz=-1.5
        team[2].tx=2.3 team[2].tz=2.5
        team[3].tx=3.3 team[3].tz=-9.5
        team[4].tx=-1.2 team[4].tz=-12.0
        team[5].tx=6.6 team[5].tz=-8.0
        team[6].tx=-1.0 team[6].tz=-16.0
        say("LEFT ALLEY OPEN")
    elseif carrier==2 then
        team[2].tx=5.7 team[2].tz=-1.5
        team[1].tx=-2.3 team[1].tz=2.5
        team[3].tx=-3.3 team[3].tz=-9.5
        team[5].tx=1.2 team[5].tz=-12.0
        team[4].tx=-6.6 team[4].tz=-8.0
        team[6].tx=1.0 team[6].tz=-16.0
        say("RIGHT ALLEY OPEN")
    elseif carrier==3 then
        team[3].tx=0 team[3].tz=-1.2
        team[1].tx=-6.6 team[1].tz=1.8
        team[2].tx=6.6 team[2].tz=1.8
        team[4].tx=-5.7 team[4].tz=-10.2
        team[5].tx=5.7 team[5].tz=-10.2
        team[6].tx=0 team[6].tz=-16
        say("MIDDLE LANE OPEN")
    else
        say("CLEAR: PASS TO A MIDFIELDER")
    end
end
local function beginClear()
    mode="CLEAR"
    clearTimer=5
    setupClear()
end
local function swingTargets()
    assignBase()
    -- Small perimeter exchanges preserve passing angles.
    local wave=math.sin(elapsed*1.4)
    team[1].tx=-4.8+wave*.45
    team[2].tx=4.8+wave*.45
    team[4].tz=-8.1+wave*.5
    team[5].tz=-8.1-wave*.5
    team[6].tx=wave*1.1
end
local swingOrder={1,2,5,6,4,1}
local function nextSwing(i)
    for n=1,#swingOrder-1 do
        if swingOrder[n]==i then return swingOrder[n+1] end
    end
    return 1
end
local function startPass(to,automatic)
    if ballMode~="held" or to==carrier or shotReset>0 then return false end
    passFrom=carrier
    passTo=to
    passProgress=0
    passStart=team[carrier].rig.pocket.worldPosition
    passEnd=team[to].rig.pocket.worldPosition
    local len=(passEnd-passStart):len()
    passDuration=clamp(len/17,.25,.85)
    ballMode="pass"
    action="pass"
    actionT=0
    actionRelease=true
    actionFired=true
    passes=passes+1
    if not automatic then mode="SET" say("PASS TO "..team[to].name) end
    return true
end
local function nearestReceiver()
    local origin=team[carrier].rig.root.position
    local best,bestD=nil,999
    for i,p in ipairs(team) do
        if i~=carrier then
            local d=(p.rig.root.position-origin):len()
            if d<bestD then best,bestD=i,d end
        end
    end
    return best
end
local function manualPass()
    local to=nearestReceiver()
    if to then startPass(to,false) end
end
local function beginSwing()
    if ballMode~="held" or shotReset>0 then return end
    mode="SWING"
    swingTimer=.12
    say("SWING THE BALL")
end
local function beginShoot()
    if ballMode~="held" or action~="idle" or shotReset>0 then return end
    mode="SET"
    action="shoot"
    actionT=0
    actionRelease=false
    actionFired=false
    aim=0
end
local function releaseShoot()
    if action=="shoot" then actionRelease=true end
end
local function beginDodge()
    if dodgeCD>0 or ballMode~="held" or shotReset>0 then return end
    local len=math.sqrt(mx*mx+mz*mz)
    if len>.12 then dodgeDX,dodgeDZ=mx/len,mz/len else dodgeDX,dodgeDZ=0,-1 end
    dodgeTime=.32 dodgeCD=2
    mode="SET"
    say("DODGE!")
end
local function resetBall()
    ballMode="held"
    action="idle"
    actionT=0
    actionRelease=false
    actionFired=false
    shotReset=0
    carrier=1
    mode="SET"
    assignBase()
    for i,p in ipairs(team) do
        p.rig.root.position=vec3(base[i].x,0,base[i].z)
    end
    mx,mz=0,0
end
local function animate(p,dt,isCarrier)
    local r=p.rig
    local moving=clamp(p.speed/6,0,1)
    p.phase=p.phase+dt*(2+moving*8)
    local stride=math.sin(p.phase)*moving
    local lean=5*moving
    local twist,roll=0,0
    local pitch=-12+math.sin(p.phase)*7*moving
    local yaw=math.sin(p.phase)*5*moving
    local stickRoll=0
    local sx,sy,sz=.36,.43,-.47
    local leftLeg,rightLeg=stride*29,-stride*29
    if isCarrier and dodgeTime>0 then
        local pulse=math.sin((1-dodgeTime/.32)*math.pi)
        lean=lean+18*pulse
        roll=-dodgeDX*22*pulse
        twist=dodgeDX*18*pulse
        pitch=pitch-27*pulse
    end
    if isCarrier and action~="idle" then
        local isShot=action=="shoot"
        local duration=isShot and .72 or .38
        local t=clamp(actionT/duration,0,1)
        local loadEnd=isShot and .38 or .25
        local release=isShot and .67 or .58
        local lp=isShot and -115 or -62
        local ly=isShot and 38 or 22
        local lr=isShot and 30 or 15
        local lx=isShot and .78 or .58
        local lheight=isShot and .95 or .65
        local lz=isShot and .65 or .15
        local lt=isShot and -60 or -30
        if t<loadEnd then
            local k=smooth(t/loadEnd)
            twist=lerp(0,lt,k)
            lean=lerp(0,-15,k)
            roll=10*k
            leftLeg=-25*k rightLeg=15*k
            pitch=lerp(-12,lp,k)
            yaw=lerp(0,ly,k)
            stickRoll=lerp(0,lr,k)
            sx=lerp(.36,lx,k)
            sy=lerp(.43,lheight,k)
            sz=lerp(-.47,lz,k)
        elseif t<release then
            local k=smooth((t-loadEnd)/(release-loadEnd))
            twist=lerp(lt,24,k)
            lean=lerp(-15,18,k)
            roll=lerp(10,-8,k)
            leftLeg=lerp(-25,-35,k)
            rightLeg=lerp(15,20,k)
            pitch=lerp(lp,48,k)
            yaw=lerp(ly,-30,k)
            stickRoll=lerp(lr,-35,k)
            sx=lerp(lx,.25,k)
            sy=lerp(lheight,.48,k)
            sz=lerp(lz,-.8,k)
        else
            local k=smooth((t-release)/(1-release))
            twist=lerp(24,isShot and 42 or 20,k)
            lean=lerp(18,isShot and 26 or 12,k)
            roll=lerp(-8,-12,k)
            leftLeg=lerp(-35,-12,k)
            rightLeg=lerp(20,8,k)
            pitch=lerp(48,isShot and 112 or 70,k)
            yaw=lerp(-30,-55,k)
            stickRoll=lerp(-35,-50,k)
            sx=lerp(.25,-.15,k)
            sy=lerp(.48,.3,k)
            sz=lerp(-.8,-.65,k)
        end
    end
    r.leftLeg.eulerAngles=vec3(leftLeg,0,0)
    r.rightLeg.eulerAngles=vec3(rightLeg,0,0)
    r.body.position=vec3(0,1.14+math.abs(math.sin(p.phase))*.06*moving,0)
    r.body.eulerAngles=vec3(lean,twist,roll)
    r.head.eulerAngles=vec3(-lean*.2,0,0)
    r.stick.position=vec3(sx,sy,sz)
    r.stick.eulerAngles=vec3(pitch,yaw,stickRoll)
    updateArms(r)
end
function setup()
    ready=false
    scene=craft.scene()
    scene.ambientColor=color(145,155,170)
    scene.sun.rotation=quat.eulerAngles(45,30,0)
    scene.camera.position=vec3(0,24,27)
    scene.camera.eulerAngles=vec3(42,180,0)
    field()
    team={}
    for i,data in ipairs(base) do
        local rig=createAthlete(data.name,colors.blue,i==1)
        rig.root.position=vec3(data.x,0,data.z)
        team[i]={name=data.name,role=data.role,rig=rig,tx=data.x,tz=data.z,phase=i*.9,speed=0}
    end
    goalie=createAthlete("Goalie",colors.red,false)
    goalie.root.position=vec3(0,0,-12.5)
    goalie.speed=0 goalie.phase=0 goalie.rig=goalie
    ball=worldCube("Ball",vec3(0,2,0),vec3(.23,.23,.23),color(255,226,49))
    carrier=1 ballMode="held" mode="SET"
    action="idle" actionT=0 actionRelease=false actionFired=false
    swingTimer=0 clearTimer=0 shotReset=0
    mx,mz=0,0 joyID=nil shootID=nil joyOrigin=nil shootOrigin=nil
    dodgeTime=0 dodgeCD=0
    goals=0 shots=0 passes=0 saves=0 clock=180 finished=false
    elapsed=0
    message="2-3-1 OFFENSE" messageTimer=2
    ready=true
end
local function updateGame(dt)
    elapsed=elapsed+dt
    messageTimer=math.max(0,messageTimer-dt)
    dodgeTime=math.max(0,dodgeTime-dt)
    dodgeCD=math.max(0,dodgeCD-dt)
    if finished then return end
    clock=math.max(0,clock-dt)
    if clock<=0 then finished=true say("SESSION COMPLETE") return end
    if shotReset>0 then
        shotReset=shotReset-dt
        if shotReset<=0 then resetBall() end
    end
    if mode=="SWING" then
        swingTargets()
        if ballMode=="held" and shotReset<=0 then
            swingTimer=swingTimer-dt
            if swingTimer<=0 then
                if startPass(nextSwing(carrier),true) then swingTimer=.35 end
            end
        end
    elseif mode=="CLEAR" then
        clearTimer=clearTimer-dt
        if clearTimer<=0 then mode="SET" assignBase() end
    elseif mode=="SET" then
        assignBase()
    end
    for i,p in ipairs(team) do
        local pos=p.rig.root.position
        local tx,tz=p.tx,p.tz
        if i==carrier and ballMode=="held" and shotReset<=0 then
            local speed=dodgeTime>0 and 14 or 6
            local dx,dz=mx,mz
            if dodgeTime>0 then dx,dz=dodgeDX,dodgeDZ end
            if action~="idle" then speed=speed*.3 end
            tx=clamp(pos.x+dx*speed*dt,-8.2,8.2)
            tz=clamp(pos.z+dz*speed*dt,-16.4,15.4)
        end
        local delta=vec3(tx-pos.x,0,tz-pos.z)
        local d=delta:len()
        local maxStep=(i==carrier and ballMode=="held" and 14 or 4.7)*dt
        local step=math.min(d,maxStep)
        if d>.001 then pos=pos+delta/d*step end
        p.rig.root.position=vec3(pos.x,0,pos.z)
        p.speed=step/dt
    end
    local gp=goalie.root.position
    local cx=team[carrier].rig.root.position.x
    goalie.root.position=vec3(gp.x+clamp(clamp(cx,-1.15,1.15)-gp.x,-3*dt,3*dt),0,-12.5)
    if action~="idle" then
        local duration=action=="shoot" and .72 or .38
        local load=action=="shoot" and .38 or .25
        if action=="shoot" and not actionRelease then
            actionT=math.min(actionT+dt,duration*load)
        else
            actionT=actionT+dt
        end
    end
    for i,p in ipairs(team) do animate(p,dt,i==carrier) end
    animate(goalie,dt,false)
    if action=="shoot" and not actionFired and actionT>=.72*.67 then
        actionFired=true
        shots=shots+1
        ball.position=team[carrier].rig.pocket.worldPosition
        local target=vec3(aim*1.8,1.1,-13.05)
        local delta=target-ball.position
        shotVel=delta:len()>.001 and delta:normalize()*24 or vec3(0,0,-24)
        ballMode="shot"
    end
    if action~="idle" then
        local duration=action=="shoot" and .72 or .38
        if actionT>=duration then action="idle" actionT=0 end
    end
    if ballMode=="held" then
        ball.position=team[carrier].rig.pocket.worldPosition
    elseif ballMode=="pass" then
        passProgress=passProgress+dt/passDuration
        local t=clamp(passProgress,0,1)
        local target=team[passTo].rig.pocket.worldPosition
        local p=passStart+(target-passStart)*t
        ball.position=p+vec3(0,math.sin(t*math.pi)*.4,0)
        if t>=1 then
            carrier=passTo
            ballMode="held"
            ball.position=team[carrier].rig.pocket.worldPosition
            if mode=="SWING" then swingTimer=.5 else say(team[carrier].name.." HAS BALL") end
        end
    elseif ballMode=="shot" then
        local previous=ball.position
        local nextPos=previous+shotVel*dt
        ball.position=nextPos
        if (previous.z>-12.5 and nextPos.z<=-12.5) or (previous.z<=-12.5 and nextPos.z>=-12.5) then
            local fraction=clamp((-12.5-previous.z)/(nextPos.z-previous.z),0,1)
            local hit=previous+(nextPos-previous)*fraction
            local gx=goalie.root.position.x
            if math.abs(hit.x-gx)<.5 and hit.y<2.4 then
                saves=saves+1 say("GOALIE SAVE")
            elseif math.abs(hit.x)<1.05 and hit.y>0 and hit.y<1.8 then
                goals=goals+1 say("GOAL!")
            else
                say("SHOT WIDE")
            end
            ballMode="dead"
            shotReset=1
        end
    end
end
-- ============================================
-- CHARACTER CREATOR: TOUCH-FRIENDLY PORTRAIT
-- ============================================
local function panelButton(x,y,w,h,label,selected)
    rectMode(CENTER)
    noStroke()
    fill(selected and color(255,215,66) or color(25,64,116))
    rect(x,y,w,h)
    fill(selected and color(8,31,68) or color(255))
    fontSize(14)
    textAlign(CENTER)
    text(label,x,y)
end

local function drawCreator()
    background(7,31,68)
    pushStyle()
    rectMode(CORNER)
    noStroke()
    fill(16,45,88)
    rect(15,HEIGHT*.40,WIDTH-30,HEIGHT*.45)
    fill(255)
    textAlign(CENTER)
    fontSize(24)
    text("CREATE YOUR PLAYER",WIDTH/2,HEIGHT*.92)
    fontSize(13)
    text("POLYLAX  |  LACROSSE CAREER",WIDTH/2,HEIGHT*.885)

    -- Geometric 2D preview, updated immediately by selections.
    local x=WIDTH/2
    local y=HEIGHT*.60
    local k=math.min(WIDTH/390,1.2)
    local jersey=profileColor("jersey")
    local helmet=profileColor("helmet")
    local shorts=profileColor("shorts")
    local skin=skinColors[profile.skin]
    local hair=hairColors[profile.hair]
    pushMatrix()
    translate(x,y)
    scale(k,k)
    rectMode(CENTER)
    fill(shorts)
    rect(-22,-112,35,60)
    rect(22,-112,35,60)
    fill(skin)
    rect(-22,-165,22,55)
    rect(22,-165,22,55)
    fill(255)
    rect(-22,-198,33,19)
    rect(22,-198,33,19)
    fill(jersey)
    rect(0,0,116,136)
    rect(-69,34,39,58)
    rect(69,34,39,58)
    fill(255)
    rect(-69,13,38,8)
    rect(69,13,38,8)
    fill(skin)
    rect(-70,-27,23,67)
    rect(70,-27,23,67)
    fill(255)
    fontSize(50)
    text(tostring(profile.number),0,-10)
    fill(skin)
    rect(0,114,87,88)
    fill(hair)
    rect(0,155,88,23)
    if creatorTab~=2 then
        fill(helmet)
        rect(0,159,106,43)
        rect(-45,124,16,40)
        rect(45,124,16,40)
        fill(255)
        rect(0,138,101,9)
        for i=-2,2 do rect(i*19,109,4,52) end
        for i=0,2 do rect(0,88+i*16,97,4) end
    end
    -- A clearly recognizable lacrosse stick
    fill(188,197,207)
    pushMatrix()
    translate(98,-12)
    rotate(-14)
    rect(0,0,8,225)
    fill(profileColor("stick"))
    rect(-15,123,7,54)
    rect(15,123,7,54)
    rect(0,153,39,7)
    fill(225)
    for i=-1,1 do rect(i*10,123,2,42) end
    popMatrix()
    popMatrix()

    fill(255)
    fontSize(16)
    text(profile.name.."  #"..profile.number,WIDTH/2,HEIGHT*.43)

    -- Category tabs in two rows
    local cols=4
    for i,label in ipairs(creatorTabs) do
        local col=(i-1)%cols
        local row=math.floor((i-1)/cols)
        local w=(WIDTH-24)/4
        local cx=12+w*(col+.5)
        local cy=HEIGHT*.35-row*49
        panelButton(cx,cy,w-6,41,label,creatorTab==i)
    end
    local key=({"skin","hair","helmet","jersey","shorts","stick","number"})[creatorTab]
    local value=profile[key]
    local max=key=="skin" and 4 or key=="hair" and 4 or key=="number" and 99 or 6
    fill(255)
    fontSize(17)
    text(creatorTabs[creatorTab].."   "..tostring(value),WIDTH/2,HEIGHT*.205)
    panelButton(WIDTH*.21,HEIGHT*.15,WIDTH*.25,48,"<",false)
    panelButton(WIDTH*.79,HEIGHT*.15,WIDTH*.25,48,">",false)
    panelButton(WIDTH/2,HEIGHT*.065,WIDTH*.78,56,"DONE - PLAY",true)
    popStyle()
end

local function creatorTouch(t)
    if t.state~=BEGAN then return end
    if t.y<HEIGHT*.10 then
        screen="GAME"
        setup()
        screen="GAME"
        return
    end
    local w=(WIDTH-24)/4
    for i=1,#creatorTabs do
        local col=(i-1)%4
        local row=math.floor((i-1)/4)
        local cx=12+w*(col+.5)
        local cy=HEIGHT*.35-row*49
        if math.abs(t.x-cx)<(w-6)/2 and math.abs(t.y-cy)<21 then
            creatorTab=i
            return
        end
    end
    if math.abs(t.y-HEIGHT*.15)<28 then
        local key=({"skin","hair","helmet","jersey","shorts","stick","number"})[creatorTab]
        local max=key=="skin" and 4 or key=="hair" and 4 or key=="number" and 99 or 6
        local min=key=="number" and 0 or 1
        local step=t.x<WIDTH/2 and -1 or 1
        profile[key]=profile[key]+step
        if profile[key]>max then profile[key]=min end
        if profile[key]<min then profile[key]=max end
    end
end

function draw()
    if not ready then background(20,35,50) return end
    local dt=math.min(DeltaTime or .016,.05)
    if screen=="CREATOR" then
        drawCreator()
        return
    end
    updateGame(dt)
    scene:update(dt)
    scene:draw()
    drawHUD()
end
local function button(x,y,w,h,label,tint,selected)
    noStroke()
    fill(selected and color(255,192,65) or tint)
    rect(x-w/2,y-h/2,w,h,9)
    fill(255)
    fontSize(12)
    textAlign(CENTER)
    text(label,x,y)
end
function drawHUD()
    pushStyle()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CORNER)
    noStroke()
    fill(15,28,49,235)
    rect(0,HEIGHT-88,WIDTH,88)
    fill(255) textAlign(LEFT) fontSize(21)
    text("POLYLAX",12,HEIGHT-33)
    fontSize(12)
    text("BALL: "..team[carrier].name.."   |   "..mode,12,HEIGHT-65)
    textAlign(RIGHT)
    text("GOALS "..goals.."  PASSES "..passes,WIDTH-12,HEIGHT-30)
    text(string.format("%d:%02d",math.floor(clock/60),math.floor(clock%60)),WIDTH-12,HEIGHT-58)
    if messageTimer>0 then
        fill(255,228,71) fontSize(20) textAlign(CENTER)
        text(message,WIDTH/2,HEIGHT*.75)
    end
    noStroke()
    fill(13,27,44,225)
    rect(0,0,WIDTH,HEIGHT*.29)
    local jx,jy=WIDTH*.18,HEIGHT*.105
    fill(52,80,104) ellipse(jx,jy,100)
    fill(195,218,238) ellipse(jx+mx*28,jy-mz*28,44)
    button(WIDTH*.22,HEIGHT*.245,WIDTH*.39,42,"SWING",color(43,111,160),mode=="SWING")
    button(WIDTH*.70,HEIGHT*.245,WIDTH*.52,42,"CLEAR THROUGH",color(137,88,167),mode=="CLEAR")
    button(WIDTH*.47,HEIGHT*.075,68,54,dodgeCD>0 and string.format("%.1f",dodgeCD) or "DODGE",color(186,115,37),false)
    button(WIDTH*.66,HEIGHT*.075,68,54,"PASS",color(45,140,108),false)
    button(WIDTH*.85,HEIGHT*.13,82,82,shootID and "AIM" or "SHOOT",color(26,108,179),shootID~=nil)
    if finished then
        fill(10,23,42,238)
        rect(WIDTH*.07,HEIGHT*.4,WIDTH*.86,155,10)
        fill(255) fontSize(21) textAlign(CENTER)
        text("SESSION COMPLETE",WIDTH/2,HEIGHT*.4+112)
        fontSize(15)
        text(goals.." GOALS  |  "..passes.." PASSES",WIDTH/2,HEIGHT*.4+75)
        text("TAP SHOOT TO RESTART",WIDTH/2,HEIGHT*.4+38)
    end
    popStyle()
end
function touched(t)
    local swingX,swingY=WIDTH*.22,HEIGHT*.245
    local clearX,clearY=WIDTH*.70,HEIGHT*.245
    local dodgeX,dodgeY=WIDTH*.47,HEIGHT*.075
    local passX,passY=WIDTH*.66,HEIGHT*.075
    local shootX,shootY=WIDTH*.85,HEIGHT*.13
    if screen=="CREATOR" then
        creatorTouch(t)
        return
    end
    if t.state==BEGAN then
        if finished and distance(t.x,t.y,shootX,shootY)<50 then setup() return end
        if math.abs(t.x-swingX)<WIDTH*.195 and math.abs(t.y-swingY)<23 then beginSwing() return end
        if math.abs(t.x-clearX)<WIDTH*.26 and math.abs(t.y-clearY)<23 then beginClear() return end
        if distance(t.x,t.y,dodgeX,dodgeY)<40 then beginDodge() return end
        if distance(t.x,t.y,passX,passY)<40 then manualPass() return end
        if distance(t.x,t.y,shootX,shootY)<48 then
            shootID=t.id shootOrigin=t.x beginShoot() return
        end
        if t.x<WIDTH*.38 and t.y<HEIGHT*.21 then
            joyID=t.id joyOrigin=vec2(t.x,t.y)
        end
    elseif t.state==MOVING then
        if t.id==joyID and joyOrigin then
            local delta=vec2(t.x,t.y)-joyOrigin
            if delta:len()>45 then delta=delta:normalize()*45 end
            mx=delta.x/45 mz=-delta.y/45
        end
        if t.id==shootID then aim=clamp((t.x-shootOrigin)/90,-1,1) end
    elseif t.state==ENDED or t.state==CANCELLED then
        if t.id==joyID then joyID=nil joyOrigin=nil mx=0 mz=0 end
        if t.id==shootID then
            shootID=nil
            if t.state==ENDED then releaseShoot()
            elseif action=="shoot" then action="idle" end
        end
    end
end