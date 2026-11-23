-- Shared distance-driven campus gait. The scene owns root travel, yaw, and terrain height.
PolyLax = PolyLax or {}
local Motion = {}
PolyLax.CampusMotion = Motion

local V=vec3
local tau=math.pi*2
local sides={-1,1}
local atan2=math.atan2 or math.atan
local sqrt,sin,cos,acos=math.sqrt,math.sin,math.cos,math.acos
local presets={
    player={stride=1.01,arms=18,sway=1.7,nod=3,tempo=1.5,
        breath=1.5,glance=2.2,restRoll=.55,gesture="nod",hand=2},
    easy={stride=1,arms=15,sway=2,nod=5,tempo=1.7,
        breath=1.65,glance=4.5,restRoll=1.25,gesture="greet",hand=2},
    athletic={stride=1.09,arms=19,sway=1.4,nod=3,tempo=2.0,
        breath=2.05,glance=2.8,restRoll=.65,gesture="point",hand=2},
    measured={stride=.84,arms=11,sway=1,nod=3.5,tempo=1.28,
        breath=1.31,glance=2.4,restRoll=.34,gesture="explain",hand=1},
    animated={stride=.94,arms=16,sway=2.8,nod=6,tempo=2.25,
        breath=1.9,glance=5.4,restRoll=1.5,gesture="explain",hand=2}
}
local gestures={
    greet={time=.82,arm=48,elbow=32,roll=24,wrist=18,head=5},
    point={time=.67,arm=40,elbow=19,roll=9,wrist=3,head=2},
    explain={time=.94,arm=24,elbow=36,roll=18,wrist=12,head=6},
    nod={time=.58,arm=0,elbow=0,roll=0,wrist=0,head=11}
}

local function clamp(value,low,high)
    return math.max(low,math.min(high,value))
end

local function toward(current,target,factor)
    return current+(target-current)*factor
end

local function legAxes(rig,i)
    local upper,lower=rig.knees[i].position,rig.ankles[i].position
    return {
        upper=sqrt(upper.y^2+upper.z^2),
        lower=sqrt(lower.y^2+lower.z^2),
        upperRest=atan2(-upper.z,-upper.y),
        lowerRest=atan2(-lower.z,-lower.y),
        down=-upper.y-lower.y,
        ahead=-upper.z-lower.z
    }
end

function Motion.new(rig,profile,seed)
    local offset=(seed or 0)%619/619
    return {
        rig=rig,profile=presets[profile] or presets.easy,mode="idle",
        time=offset*5,phase=offset,bob=0,walking=0,running=0,talking=0,duty=.62,
        headX=0,headY=0,headZ=0,bodyX=0,bodyY=0,bodyZ=0,
        arms={0,0},elbows={9,9},roll={-4,4},wrists={0,0},legs={0,0},knees={0,0},ankles={0,0},
        legAxes={legAxes(rig,1),legAxes(rig,2)},footAhead={0,0},footLift={0,0},footPitch={0,0}
    }
end

function Motion.gesture(state,id)
    local beat=gestures[id]
    if not beat then return false end
    state.beat,state.beatTime=beat,0
    return true
end

local function trailFoot(phase,duty,stride,gait,running)
    if phase<duty then
        -- This offset cancels straight-ahead root travel while the shoe is planted.
        return stride*(duty*.5-phase)*gait,0,0
    end
    local t=(phase-duty)/(1-duty)
    local rise=sin(math.pi*t)
    local smooth=t*t*(3-2*t)
    -- Match stance velocity on each end of the swing rather than reversing at touchdown.
    local recoil=stride*(1-duty)*t*(1-t)*(1-2*t)
    local forward=(stride*duty*(smooth-.5)-recoil)*gait
    local swing=rise^1.4*gait
    return forward,swing*(.11+.22*running),swing*(31*t-13+running*(53*t-43))
end

local function solveLeg(axes,ahead,down,pitch)
    local upper,lower=axes.upper,axes.lower
    local reach=clamp(sqrt(ahead^2+down^2),math.abs(upper-lower)+.0001,upper+lower)
    local knee=acos(clamp((reach^2-upper^2-lower^2)/(2*upper*lower),-1,1))
    local hip=atan2(ahead,down)+acos(clamp((upper^2+reach^2-lower^2)/(2*upper*reach),-1,1))
    local upperAngle=math.deg(hip-axes.upperRest)
    local kneeAngle=math.deg(axes.upperRest-axes.lowerRest-knee)
    return upperAngle,kneeAngle,pitch-upperAngle-kneeAngle
end

function Motion.update(state,dt,mode,speed,turn)
    if dt<=0 then return end
    local profile,rig=state.profile,state.rig
    local travel=mode=="walk" or mode=="run"
    if mode~=state.mode then
        if mode=="talk" then Motion.gesture(state,profile.gesture) end
        if travel then state.beat=nil end
        state.mode=mode
    end
    local blend=1-math.exp(-dt*10)
    local armBlend=1-math.exp(-dt*20)
    state.time=state.time+dt
    speed=travel and math.max(0,speed or 0) or 0
    local scale=rig.root.scale
    local height,depth=math.max(.01,scale.y),math.max(.01,scale.z)
    local localSpeed=speed/depth
    local run=clamp((speed-2.65)/2.9,0,1)
    state.walking=toward(state.walking,math.min(1,speed/.4),blend)
    state.running=toward(state.running,run,blend)
    state.talking=toward(state.talking,mode=="talk" and 1 or 0,blend)
    local gait,running=state.walking,state.running
    local stride=profile.stride*toward(.46+.89*math.min(1,localSpeed/2.7),
        math.min(2.64,1.30+localSpeed*.23),running)
    state.stride=state.stride and toward(state.stride,stride,blend) or stride
    state.duty=toward(.62,.31,running)
    state.phase=(state.phase+localSpeed*dt/state.stride)%1
    local beat=state.beat
    local amount=0
    if beat then
        state.beatTime=state.beatTime+dt
        if state.beatTime<beat.time then amount=math.sin(math.pi*state.beatTime/beat.time)^2
        else state.beat=nil end
    end
    local wave=sin(state.phase*tau)
    local speech=sin(state.time*profile.tempo*4)
    local breath=sin(state.time*profile.breath)
    local idle=1-gait
    local listening=mode=="listen"
    local groundLimit=math.huge
    for i=1,2 do
        local phase=(state.phase+(i-1)*.5)%1
        local axes=state.legAxes[i]
        local forward,lift,pitch=trailFoot(phase,state.duty,state.stride,gait,running)
        local reach=axes.upper+axes.lower-.006*gait
        state.footAhead[i],state.footLift[i],state.footPitch[i]=forward,lift,pitch
        groundLimit=math.min(groundLimit,sqrt(math.max(0,reach^2-(axes.ahead+forward)^2))-axes.down+lift)
    end
    local flight=math.min(state.footLift[1],state.footLift[2])
    local lift=math.min(groundLimit,gait*(-.006+running*.020)+running*flight*.72)
    state.bob=lift*height
    state.bodyX=toward(state.bodyX,-gait*(3+running*12)+(listening and -2.5 or 0),blend)
    state.bodyY=toward(state.bodyY,profile.sway*wave*gait,blend)
    state.bodyZ=toward(state.bodyZ,-profile.sway*wave*gait+profile.restRoll*idle*breath
        +clamp(turn or 0,-1,1)*gait*(2+running*5),blend)
    state.headX=toward(state.headX,1.5+speech*profile.nod*state.talking
        +(beat and beat.head*amount or 0)+(listening and 1.4*breath or 0),blend)
    state.headY=toward(state.headY,sin(state.time*.76)*profile.glance*idle*(1-state.talking),blend)
    state.headZ=toward(state.headZ,.8*breath*idle-profile.sway*wave*gait*.35,blend)
    rig.torso.eulerAngles=V(state.bodyX,state.bodyY,state.bodyZ)
    rig.head.eulerAngles=V(state.headX,state.headY,state.headZ)
    for i,side in ipairs(sides) do
        local step=side*cos(state.phase*tau)*gait
        local gesture=beat and i==profile.hand and amount or 0
        local speechHand=i==profile.hand and state.talking*(2+speech*2.5) or 0
        local axes=state.legAxes[i]
        state.legs[i],state.knees[i],state.ankles[i]=solveLeg(axes,axes.ahead+state.footAhead[i],
            axes.down+lift-state.footLift[i],state.footPitch[i])
        state.arms[i]=toward(state.arms[i],step*toward(profile.arms,33,running)-1.4*breath*idle
            +(beat and beat.arm*gesture or 0)+speechHand,armBlend)
        state.elbows[i]=toward(state.elbows[i],9+running*62+math.max(0,step)*13+speechHand
            +(beat and beat.elbow*gesture or 0),armBlend)
        state.roll[i]=toward(state.roll[i],side*(4+running*4+(beat and beat.roll*gesture or 0)),blend)
        state.wrists[i]=toward(state.wrists[i],(beat and beat.wrist*gesture or 0),blend)
        rig.arms[i].eulerAngles=V(state.arms[i],0,state.roll[i])
        rig.elbows[i].eulerAngles=V(state.elbows[i],0,0)
        local wristPitch=-gait*2-running*(9+step*4)
        local wristYaw=side*gait*(5+running*13)
        rig.wrists[i].eulerAngles=V(wristPitch,wristYaw,state.wrists[i]*side)
        rig.legs[i].eulerAngles=V(state.legs[i],0,0)
        rig.knees[i].eulerAngles=V(state.knees[i],0,0)
        rig.ankles[i].eulerAngles=V(state.ankles[i],0,0)
    end
end
