-- PolyLax 3.2 | An isolated Craft replay for the front menu.
PolyLax = PolyLax or {}
local P = PolyLax
local Showcase = {}
P.MenuShowcase = Showcase

local duration, radius = 12.6, .09
local dodgeAt, shotAt, celebrateAt, returnAt = 3.0, 4.85, 6.25, 8.8
local up = vec3(0,1,0)
local gravity = vec3(0,-9.8,0)

-- Positions are authored relative to the near goal line. The end of every
-- path returns to its starting point while the camera is back on its crane.
-- Each entry is {time, x, distance from the goal}.
local routes = {
    {{0,-7,20.8},{1.5,-6.4,18.8},{3,-4.4,12.5},{3.62,-.65,10},
        {4.85,.95,7.2},{5.6,1.36,6.55},{6.25,1.75,6.40},{7.15,3.4,7.30},
        {8.8,3.5,7.30},{10.4,-1.8,13.6},{12.6,-7,20.8}},
    {{0,7,18.6},{3,6.3,13.5},{5.5,5.7,9.1},{7.25,4.65,8.3},
        {8.8,4.65,8.3},{12.6,7,18.6}},
    {{0,-9.7,13.3},{3.3,-8.6,10.2},{5.8,-5.5,8.0},{7.35,1.9,8.1},
        {8.8,1.9,8.1},{12.6,-9.7,13.3}},
    {{0,-4.7,12.7},{2.95,-3.55,11.55},{3.56,-4.2,10.7},{5.15,-2.5,8.6},
        {7,-3.6,6.8},{8.8,-4.5,9.1},{12.6,-4.7,12.7}},
    {{0,4.9,8.75},{3.1,4.2,6.9},{5,3.85,5.1},{6.65,5.7,4.8},
        {8.8,5.7,4.8},{12.6,4.9,8.75}},
    {{0,-.18,1.15},{2.5,-.46,1.36},{4.84,-.25,1.24},{5.44,-.72,1.10},
        {6.36,-.38,1.2},{8.8,-.18,1.15},{12.6,-.18,1.15}}
}

local function clamp(value, lo, hi)
    return math.max(lo,math.min(hi,value))
end

local function ease(value)
    local t = clamp(value,0,1)
    return t*t*(3-2*t)
end

local function range(t, start, finish)
    return ease((t-start)/(finish-start))
end

local function lerp(a,b,t)
    return a+(b-a)*t
end

local function routeAt(route,t,goalZ)
    for index=2,#route do
        local b=route[index]
        if t <= b[1] then
            local a=route[index-1]
            local progress=range(t,a[1],b[1])
            return vec3(lerp(a[2],b[2],progress),0,goalZ+lerp(a[3],b[3],progress))
        end
    end
    local last=route[#route]
    return vec3(last[2],0,goalZ+last[3])
end

local function yaw(dx,dz)
    return math.deg((math.atan2 or math.atan)(-dx,-dz))
end

local function playOnce(actor,clip)
    P.AnimationController.play(actor.anim,clip)
end

local function registerCelebration()
    local clips=P.AnimationController.clips
    if clips.showcaseCelebrate then return end
    clips.showcaseCelebrate={duration=2.0,poses={
        {time=.27,grip=vec3(.45,.96,-.23),shaft=vec3(.62,.76,-.13),
            torso=vec3(-7,-15,4),crouch=.045,roll=-9,freeHand=.46},
        {time=.62,grip=vec3(.42,1.13,-.21),shaft=vec3(.19,.98,-.13),
            torso=vec3(3,-8,-7),crouch=0,roll=0,freeHand=1},
        {time=1.46,grip=vec3(.47,1.09,-.14),shaft=vec3(.14,.98,-.12),
            torso=vec3(2,8,-11),crouch=.01,roll=0,freeHand=1}
    }}
end

local function makeActor(scene, index, kit, goalZ)
    local rig=P.Character.new(scene)
    P.Character.apply(rig,{FACE=(index-1)%4+1,BODY=index==6 and 3 or 2,
        NUMBER=({24,8,32,27,15,1})[index]},nil,kit,false)
    if index==4 or index==5 then P.Character.setStickType(rig,"long") end
    local start=routeAt(routes[index],0,goalZ)
    local heading=index<=3 and 0 or 180
    rig.root.position=start
    rig.root.eulerAngles=vec3(0,heading,0)
    return {rig=rig,anim=P.AnimationController.new(rig),heading=heading,route=routes[index]}
end

local function cameraPose(state,dt)
    local t, goalZ=state.time,state.goal.z
    local hero=state.actors[1].rig.root.position
    local arc=math.sin(t/duration*math.pi*2)
    local wide=vec3(12+3.7*arc,30,goalZ+37)
    local wideTarget=vec3(-1.4,0,goalZ+12.5)
    local track=hero+vec3(-7.6,4.55,7.8)
    local trackTarget=hero+vec3(.75,1.45,-2.75)
    local shot=hero+vec3(5.1,3.85,7.25)
    local shotTarget=lerp(hero+vec3(0,1.25,0),vec3(.15,1.2,goalZ),.42)
    local close=hero+vec3(-4.3+range(t,6.3,8.75)*2.3,2.15,-6.9)
    local closeTarget=hero+vec3(.1,1.54,.18)

    local approach=range(t,1.35,2.85)
    local eye,target=lerp(wide,track,approach),lerp(wideTarget,trackTarget,approach)
    local windup=range(t,4.08,4.98)
    eye,target=lerp(eye,shot,windup),lerp(target,shotTarget,windup)
    local reaction=range(t,5.9,6.93)
    eye,target=lerp(eye,close,reaction),lerp(target,closeTarget,reaction)
    local retreat=range(t,8.38,9.82)
    eye,target=lerp(eye,wide,retreat),lerp(target,wideTarget,retreat)

    local amount=state.eye and 1-math.exp(-7*dt) or 1
    state.eye=state.eye and lerp(state.eye,eye,amount) or eye
    state.target=state.target and lerp(state.target,target,amount) or target
    state.camera.entity.position=state.eye
    -- Craft cameras look along local +Z, as in CameraController and Presentation.
    state.camera.entity.rotation=quat.lookRotation((state.target-state.eye):normalize(),up)
end

local function animateActor(state,actor,index,dt)
    local root,t=actor.rig.root,state.time
    local destination=routeAt(actor.route,t,state.goal.z)
    local displacement=destination-root.position
    local heading=actor.heading
    if index==1 and t>=shotAt-.22 and t<celebrateAt then
        heading=yaw(.58-destination.x,state.goal.z-destination.z)
    elseif t>=celebrateAt and t<returnAt and index<=3 then
        local teammate=state.actors[index==1 and 2 or 1].rig.root.position
        heading=yaw(teammate.x-destination.x,teammate.z-destination.z)
    elseif index==6 then
        local shooter=state.actors[1].rig.root.position
        heading=yaw(shooter.x-destination.x,shooter.z-destination.z)
    elseif displacement:len()>.002 then
        heading=yaw(displacement.x,displacement.z)
    end

    local turn=(heading-actor.heading+180)%360-180
    actor.heading=actor.heading+turn*(1-math.exp(-10*dt))
    root.position=destination
    root.eulerAngles=vec3(0,actor.heading,0)
    local speed=math.min(7.8,displacement:len()/math.max(dt,.001))
    return P.AnimationController.update(actor.anim,dt,{speed=speed,
        turn=clamp(turn/85,-1,1),possessed=index==1 and not state.shot and not state.scored})
end

local function launch(state)
    local origin=state.actors[1].rig.pocket.worldPosition
    local aim=vec3(.58,.91,state.goal.z-.20)
    local flightTime=.32
    state.ball.position=origin
    state.shot={origin=origin,time=0,velocity=(aim-origin)/flightTime-gravity*(flightTime*.5)}
end

local function advanceBall(state,dt)
    if state.shot then
        local shot=state.shot
        shot.time=shot.time+dt
        local t=shot.time
        local nextPosition=shot.origin+shot.velocity*t+gravity*(.5*t*t)
        local hit=P.GoalPhysics.step(state.goal,state.ball.position,nextPosition,shot.velocity+gravity*t)
        if hit and hit.kind=="GOAL" then
            state.ball.position=P.GoalPhysics.capture(state.goal,hit.position)
            state.shot,state.scored=nil,true
        elseif t>.50 then
            state.ball.position=P.GoalPhysics.capture(state.goal,vec3(.58,.91,state.goal.z))
            state.shot,state.scored=nil,true
        else
            state.ball.position=nextPosition
        end
    elseif not state.scored then
        state.ball.position=state.actors[1].rig.pocket.worldPosition
    elseif state.time>=11.9 then
        -- The ball is reset off the wide frame rather than visibly rewinding.
        state.ball.position=state.actors[1].rig.pocket.worldPosition
    end
    state.ball.active=state.time<returnAt or state.time>=11.9
    P.GoalPhysics.update(state.goal,dt)
end

function Showcase.new(scene,homeId,awayId)
    registerCelebration()
    local home,away,team=P.TeamUniform.matchKits(homeId,awayId)
    local field=P.Field.new(scene,team.field)
    local state={scene=scene,field=field,goal=field.goals[1],actors={},time=0,
        duration=duration,stage="opening",cycles=0,scored=false}
    state.camera=P.CameraController.new(scene,51)
    for index=1,#routes do
        state.actors[index]=makeActor(scene,index,index<=3 and home or away,state.goal.z)
    end
    local standard=asset and asset.builtin and asset.builtin.Materials
    state.ball=scene:entity()
    state.ball.model=craft.model.icosphere(radius,1,true)
    state.ball.material=craft.material(standard and standard.Standard or "Materials:Standard")
    state.ball.material.diffuse=color(255,215,91)
    state.ball.position=state.actors[1].rig.pocket.worldPosition
    cameraPose(state,0)
    return state
end

function Showcase.update(state,dt)
    dt=clamp(dt or 0,0,.05)
    local previous=state.time
    state.time=state.time+dt
    if state.time>=duration then
        state.time=state.time-duration
        state.shot,state.scored=nil,false
        state.cycles=state.cycles+1
        previous=0
        P.GoalPhysics.reset(state.goal)
    end
    local t=state.time
    if previous<dodgeAt and t>=dodgeAt then
        playOnce(state.actors[1],"dodge")
        playOnce(state.actors[4],"pokeCheckLong")
    elseif previous<shotAt and t>=shotAt then
        playOnce(state.actors[1],"shoot")
    elseif previous<celebrateAt and t>=celebrateAt then
        for index=1,3 do playOnce(state.actors[index],"showcaseCelebrate") end
    end
    for index,actor in ipairs(state.actors) do
        local event=animateActor(state,actor,index,dt)
        if index==1 and event=="release" then launch(state) end
    end
    advanceBall(state,dt)
    state.stage=t<1.35 and "opening" or t<dodgeAt and "tracking"
        or t<shotAt and "dodge" or t<celebrateAt and "shot"
        or t<returnAt and "celebration" or "return"
    cameraPose(state,dt)
end
