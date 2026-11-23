-- Small procedural articulation profiles for campus rigs. World owns root travel and facing.
PolyLax = PolyLax or {}
local Motion = {}
PolyLax.CampusMotion = Motion

local V=vec3
local tau=math.pi*2
local sides={-1,1}
local presets={
    easy={stride=21,step=1.50,arms=15,sway=2,nod=5,tempo=1.7,
        breath=1.65,glance=4.5,restRoll=1.25,gesture="greet",hand=2},
    athletic={stride=24,step=1.67,arms=18,sway=1.4,nod=3,tempo=2.0,
        breath=2.05,glance=2.8,restRoll=.65,gesture="point",hand=2},
    measured={stride=17,step=1.26,arms=11,sway=1,nod=3.5,tempo=1.28,
        breath=1.31,glance=2.4,restRoll=.34,gesture="explain",hand=1},
    animated={stride=20,step=1.57,arms=16,sway=2.8,nod=6,tempo=2.25,
        breath=1.9,glance=5.4,restRoll=1.5,gesture="explain",hand=2}
}
local gestures={
    greet={time=.82,arm=48,elbow=32,roll=24,wrist=18,head=5},
    point={time=.67,arm=40,elbow=19,roll=9,wrist=3,head=2},
    explain={time=.94,arm=24,elbow=36,roll=18,wrist=12,head=6},
    nod={time=.58,arm=0,elbow=0,roll=0,wrist=0,head=11}
}

function Motion.new(rig,profile,seed)
    local offset=(seed or 0)%619/619
    return {
        rig=rig,profile=presets[profile] or presets.easy,mode="idle",
        time=offset*5,phase=offset*tau,bob=0,walking=0,talking=0,
        headX=0,headY=0,headZ=0,bodyX=0,bodyY=0,bodyZ=0,
        arms={0,0},elbows={9,9},roll={-6,6},wrists={0,0},legs={0,0},knees={0,0},ankles={0,0}
    }
end

function Motion.gesture(state,id)
    local beat=gestures[id]
    if not beat then return false end
    state.beat,state.beatTime=beat,0
    return true
end

local function toward(current,target,factor)
    return current+(target-current)*factor
end

function Motion.update(state,dt,mode,speed)
    if dt<=0 then return end
    local profile,rig=state.profile,state.rig
    if mode~=state.mode then
        if mode=="talk" then Motion.gesture(state,profile.gesture) end
        if mode=="walk" then state.beat=nil end
        state.mode=mode
    end
    local blend=1-math.exp(-dt*10)
    state.time=state.time+dt
    state.walking=toward(state.walking,mode=="walk" and math.min(1,(speed or 0)/.75) or 0,blend)
    state.talking=toward(state.talking,mode=="talk" and 1 or 0,blend)
    if mode=="walk" then
        state.phase=(state.phase+tau*profile.step*math.min(1.25,(speed or 0)/.75)*dt)%tau
    end
    local beat=state.beat
    local amount=0
    if beat then
        state.beatTime=state.beatTime+dt
        if state.beatTime<beat.time then amount=math.sin(math.pi*state.beatTime/beat.time)^2
        else state.beat=nil end
    end
    local wave=math.sin(state.phase)
    local gait=state.walking
    local speech=math.sin(state.time*profile.tempo*4)
    local breath=math.sin(state.time*profile.breath)
    local idle=1-gait
    local listening=mode=="listen"
    state.bob=.032*gait*math.abs(wave)+.006*idle*(1+breath)
    state.bodyX=toward(state.bodyX,-6*gait+(listening and -2.5 or 0),blend)
    state.bodyY=toward(state.bodyY,profile.sway*wave*gait,blend)
    state.bodyZ=toward(state.bodyZ,-profile.sway*wave*gait+profile.restRoll*idle*breath,blend)
    state.headX=toward(state.headX,1.5+speech*profile.nod*state.talking
        +(beat and beat.head*amount or 0)+(listening and 1.4*breath or 0),blend)
    state.headY=toward(state.headY,math.sin(state.time*.76)*profile.glance*idle*(1-state.talking),blend)
    state.headZ=toward(state.headZ,.8*breath*idle-profile.sway*wave*gait*.35,blend)
    rig.torso.eulerAngles=V(state.bodyX,state.bodyY,state.bodyZ)
    rig.head.eulerAngles=V(state.headX,state.headY,state.headZ)
    for i,side in ipairs(sides) do
        local step=-side*wave*gait
        local gesture=beat and i==profile.hand and amount or 0
        local speechHand=i==profile.hand and state.talking*(2+speech*2.5) or 0
        state.legs[i]=toward(state.legs[i],step*profile.stride,blend)
        state.knees[i]=toward(state.knees[i],-math.max(0,-step)*31,blend)
        state.ankles[i]=toward(state.ankles[i],-step*8+math.max(0,-step)*8,blend)
        state.arms[i]=toward(state.arms[i],-step*profile.arms-1.4*breath*idle
            +(beat and beat.arm*gesture or 0)+speechHand,blend)
        state.elbows[i]=toward(state.elbows[i],9+math.max(0,-step)*12+speechHand
            +(beat and beat.elbow*gesture or 0),blend)
        state.roll[i]=toward(state.roll[i],side*(6+(beat and beat.roll*gesture or 0)),blend)
        state.wrists[i]=toward(state.wrists[i],(beat and beat.wrist*gesture or 0),blend)
        rig.arms[i].eulerAngles=V(state.arms[i],0,state.roll[i])
        rig.elbows[i].eulerAngles=V(state.elbows[i],0,0)
        rig.wrists[i].eulerAngles=V(0,0,state.wrists[i]*side)
        rig.legs[i].eulerAngles=V(state.legs[i],0,0)
        rig.knees[i].eulerAngles=V(state.knees[i],0,0)
        rig.ankles[i].eulerAngles=V(state.ankles[i],0,0)
    end
end
