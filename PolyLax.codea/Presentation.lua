-- PolyLax 2.0 | On-field presentation using the live match rigs and scene.
PolyLax = PolyLax or {}
local P = PolyLax
local Presentation = {}
P.Presentation = Presentation

local durations = {pregame=11.6,goal=2.6,postgame=7.1,championship=8.4}
local scoreInk = color(251,207,105)
local white = color(244,250,255)
local shade = color(11,18,29,222)

local function clamp(v,a,b)
    return math.max(a,math.min(b,v))
end

local function ease(t)
    t = clamp(t,0,1)
    return t*t*(3-2*t)
end

local function blend(a,b,t)
    return a+(b-a)*t
end

local function copy(v)
    return vec3(v.x,v.y,v.z)
end

local function ground(x,z)
    return vec3(x,0,z)
end

local function yawTo(direction)
    return math.deg((math.atan2 or math.atan)(-direction.x,-direction.z))
end

local function snapshot(entity, saved, known)
    if not entity or known[entity] then return end
    known[entity] = true
    saved[#saved+1] = {entity=entity,position=copy(entity.position),rotation=entity.rotation}
end

local function actor(player,index,saved,known)
    local rig = player.rig
    snapshot(rig.root,saved,known)
    snapshot(rig.pelvis,saved,known)
    snapshot(rig.stickRoot,saved,known)
    for _, joint in pairs(rig.joints) do snapshot(joint,saved,known) end
    return {index=index,team=player.team or 1,slot=player.slot or index,
        player=player,base=copy(rig.root.position),yaw=player.yaw or 0}
end

local function shot(pose,time,grip,shaft,torso,crouch,freeHand)
    pose[#pose+1] = {time=time,grip=grip,shaft=shaft,torso=torso,
        crouch=crouch or 0,roll=0,freeHand=freeHand or 0}
end

local function registerClips(animation)
    if animation.clips.presentationLift then return end
    local poses = {}
    shot(poses,.24,vec3(.46,.97,-.20),vec3(.67,.73,-.11),vec3(-6,-13,5),.035,.45)
    shot(poses,.55,vec3(.43,1.14,-.18),vec3(.19,.98,-.15),vec3(3,-8,-7),0,1)
    shot(poses,1.15,vec3(.44,1.09,-.16),vec3(.16,.98,-.1),vec3(2,8,-12),.01,1)
    animation.clips.presentationLift = {duration=1.65,poses=poses}
    poses = {}
    shot(poses,.17,vec3(.43,.54,.06),vec3(.47,.78,.30),vec3(-5,0,-5),.025,1)
    shot(poses,.57,vec3(.39,.53,.11),vec3(.53,.77,.23),vec3(-5,4,-3),.025,1)
    animation.clips.presentationGreeting = {duration=.93,poses=poses}
    poses = {}
    shot(poses,.23,vec3(.32,.43,-.38),vec3(.58,.32,-.72),vec3(-23,0,0),.25,.05)
    shot(poses,.85,vec3(.33,.32,-.40),vec3(.63,.13,-.76),vec3(-30,0,0),.38,.08)
    animation.clips.presentationDraw = {duration=1.10,poses=poses}
end

local function findActor(state, requested)
    local id = type(requested) == "table" and (requested.id or requested.index) or requested
    local name = type(requested) == "table" and requested.name or requested
    for _, item in ipairs(state.actors) do
        if item.index == id or item.player.name == name then return item end
    end
end

local function nomination(state)
    local best, value
    for _, item in ipairs(state.actors) do
        local s = item.player.stats or {}
        local rating = (s.goals or 0)*5+(s.assists or 0)*3+(s.saves or 0)*1.1
            +(s.groundBalls or 0)*.65+(s.causedTurnovers or s.forcedTurnovers or 0)*1.6
            +(s.faceoffs or 0)*.8+(s.interceptions or 0)*.8-(s.turnovers or 0)*.3
        if not best or rating > value then best,value = item,rating end
    end
    return best
end

local function pose(item, position, facing, dt, clip)
    local rig = item.player.rig
    if not item.animation then item.animation = P.AnimationController.new(rig) end
    local movement = position-rig.root.position
    rig.root.position = position
    rig.root.eulerAngles = vec3(0,facing,0)
    if clip and item.clip ~= clip then
        if P.AnimationController.play(item.animation,clip) then item.clip=clip end
    elseif not clip then
        item.clip = nil
    end
    P.AnimationController.update(item.animation,dt,{speed=math.min(7.8,movement:len()/math.max(dt,.001))})
end

local function travel(item, start, finish, progress, restYaw, dt, clip)
    local at = blend(start,finish,ease(progress))
    local yaw = (finish-start):len() > .01 and yawTo(finish-start) or restYaw
    local turn = (restYaw-yaw+180)%360-180
    yaw = yaw+turn*ease((progress-.78)/.22)
    pose(item,at,yaw,dt,clip)
end

local function setCamera(play, state, eye, target, dt)
    local amount = state.eye and 1-math.exp(-4.5*dt) or 1
    state.eye = state.eye and blend(state.eye,eye,amount) or eye
    state.target = state.target and blend(state.target,target,amount) or target
    play.camera.entity.position = state.eye
    play.camera.entity.rotation = quat.lookRotation((state.target-state.eye):normalize(),vec3(0,1,0))
end

local function benchAndLine(state, game)
    local field = game.field
    local edge = field and math.min(field.halfWidth+1,27) or 11
    for _,item in ipairs(state.actors) do
        local side = item.team == 1 and 1 or -1
        item.bench = ground(-edge+math.floor((item.slot-1)/3)*.9,side*(2+(item.slot-1)*1.05))
        item.line = ground((item.slot-(field and 5.5 or 3.5))*1.44,side*2.25)
        item.approach = item.base
        if field and item.slot == 4 then
            item.approach = ground(item.base.x,item.base.z+side*1.7)
        end
        item.player.rig.root.position = item.bench
    end
end

local function pregame(play,state,dt)
    local game, t = play.game,state.time
    local width = game.field and game.field.halfWidth or 9
    local length = game.field and game.field.halfLength or 17
    local hero = state.lead.player.rig.root
    local eye, target
    if t < 1.25 then
        state.title = game.homeTeam and game.homeTeam.name or "Practice"
        state.subtitle = game.awayTeam and ("vs "..game.awayTeam.name)
        eye,target = vec3(width*.62,length*1.70,length*1.22),vec3(0,.6,0)
    elseif t < 4.65 then
        state.title,state.subtitle = "Run-on",nil
        for _,item in ipairs(state.actors) do
            local delay = ((item.slot-1)%4)*.075
            travel(item,item.bench,item.line,(t-1.25-delay)/3.17,
                item.team == 1 and 0 or 180,dt)
        end
        target = hero.position+vec3(0,1.16,0)
        eye = target+vec3(-6.0,5.4,10.0)
    elseif t < 5.80 then
        state.title = "Starting lineup"
        local track = -3.0+5.5*ease((t-4.65)/1.15)
        eye,target = vec3(track+5.8,4.55,11.5),vec3(track,1.34,0)
        for _,item in ipairs(state.actors) do
            pose(item,item.line,item.team == 1 and 0 or 180,dt)
        end
    elseif t < 10.28 then
        state.title = "To formation"
        for _,item in ipairs(state.actors) do
            travel(item,item.line,item.approach,(t-5.80)/4.48,item.yaw,dt)
        end
        target = hero.position+vec3(0,1.2,0)
        eye = target+vec3(5.1,13,18)
    else
        state.title = game.field and "Opening faceoff" or "Ready"
        for _,item in ipairs(state.actors) do
            local isDraw = game.field and item.slot == 4
            travel(item,item.approach,item.base,(t-10.28)/.81,item.yaw,dt,
                isDraw and t>10.88 and "presentationDraw" or nil)
        end
        eye,target = vec3(4.8,3.1,7.0),vec3(0,.91,0)
    end
    setCamera(play,state,eye,target,dt)
end

local function closestPartners(state, focus, team, count)
    local pool = {}
    for _,item in ipairs(state.actors) do
        if item ~= focus and item.team == team and item.slot ~= 10 then
            pool[#pool+1] = item
        end
    end
    table.sort(pool,function(a,b)
        local ad = (a.base-focus.base):len()
        local bd = (b.base-focus.base):len()
        return ad == bd and a.index < b.index or ad < bd
    end)
    while #pool > count do pool[#pool] = nil end
    return pool
end

local function prepareGoal(state, game, options)
    state.lead = findActor(state,options.scorer or game.lastGoalScorer or game.goalScorer) or state.lead
    local team = options.team or game.lastGoalTeam or state.lead.team
    local teamInfo = team == 1 and game.homeTeam or game.awayTeam
    if team ~= state.lead.team then
        for _,item in ipairs(state.actors) do
            if item.team == team then state.lead=item break end
        end
    end
    state.title = teamInfo and teamInfo.name.." GOAL" or "Goal"
    state.subtitle = state.lead.player.name
    local lead = state.lead
    local towardCenter = lead.base.z < 0 and 1 or -1
    lead.stage = lead.base+ground(1.0,towardCenter*2.1)
    state.group = {lead}
    for i, mate in ipairs(closestPartners(state,lead,team,2)) do
        mate.stage = blend(mate.base,lead.stage+ground((i==1 and -1 or 1)*1.48,.8),.68)
        state.group[#state.group+1] = mate
    end
end

local function celebration(play,state,dt)
    local t = state.time
    for i,item in ipairs(state.group) do
        travel(item,item.base,item.stage,(t-(i-1)*.11)/1.10,i == 1 and -30 or 24,dt,
            t>.31+(i-1)*.18 and "presentationLift" or nil)
    end
    local lead = state.lead.player.rig.root.position
    local target = lead+vec3(0,1.56,0)
    local eye = target+vec3(3.7,2.2,-5.9+ease(t/2.5)*1.25)
    setCamera(play,state,eye,target,dt)
end

local function nearMidfield(state,team)
    local group = {}
    for _,item in ipairs(state.actors) do
        if item.team == team and item.slot ~= 10 then group[#group+1] = item end
    end
    table.sort(group,function(a,b)
        local aa,bb = a.base:len(),b.base:len()
        return aa == bb and a.index < b.index or aa < bb
    end)
    return group
end

local function makeTrophy(play,state)
    local stage = play.scene
    local standard = asset and asset.builtin and asset.builtin.Materials
    local function material(tint,metal)
        local m = craft.material(standard and standard.Standard or "Materials:Standard")
        m.diffuse,m.metalness,m.roughness = tint,metal,.30
        return m
    end
    local gold = material(color(238,177,51),.61)
    local light = material(color(253,215,112),.48)
    local base = material(color(32,40,52),.14)
    local cube = craft.model.cube(vec3(1,1,1))
    local round = craft.model.icosphere(1,1,true)
    local trophy = {}
    local function part(model, tint, position, scaleValue, tilt)
        local e = stage:entity()
        e.model,e.material,e.position,e.scale = model,tint,position,scaleValue
        if tilt then e.eulerAngles = vec3(0,0,tilt) end
        trophy[#trophy+1] = e
    end
    part(cube,base,vec3(.52,.20,.25),vec3(1.05,.40,.73))
    part(cube,light,vec3(.52,.43,.25),vec3(.55,.07,.46))
    part(round,gold,vec3(.52,.68,.25),vec3(.073,.22,.073))
    part(round,gold,vec3(.52,1.00,.25),vec3(.25,.25,.21))
    part(round,light,vec3(.52,1.17,.25),vec3(.277,.055,.22))
    for _,s in ipairs({-1,1}) do
        part(cube,light,vec3(.52+s*.285,1.02,.25),vec3(.15,.043,.048),s*28)
        part(cube,gold,vec3(.52+s*.345,.98,.25),vec3(.045,.14,.048),-s*14)
        part(cube,light,vec3(.52+s*.285,.91,.25),vec3(.112,.041,.044),-s*26)
    end
    state.trophy = trophy
end

local function preparePostgame(state, game, options)
    local one, two = nearMidfield(state,1),nearMidfield(state,2)
    local home,away = game.homeScore or game.goals or 0,game.awayScore or 0
    local victor = home > away and 1 or away > home and 2
    state.winner = victor
    state.mvp = findActor(state,options.playerOfGame) or nomination(state)
    local requested = options.playerOfGame
    state.mvpName = type(requested) == "table" and requested.name or
        type(requested) == "string" and requested or state.mvp.player.name
    state.pairs = {}
    state.title = "Final whistle"
    state.subtitle = home.."–"..away
    for i=1,math.min(4,#one,#two) do
        local lane = (i-2.5)*1.85
        local home,away = one[i],two[i]
        home.stage,away.stage = ground(lane+.43,.62),ground(lane-.43,-.62)
        state.pairs[#state.pairs+1] = home
        state.pairs[#state.pairs+1] = away
    end
end

local function greeting(item,t)
    local amount = ease((t-3.18)/.25)*ease((4.10-t)/.27)
    if amount <= 0 then return end
    local joints = item.player.rig.joints
    local wiggle = math.sin((t-3.18)*17)*5*amount
    local toward = quat.eulerAngles(72+wiggle,0,-5)
    local bent = quat.eulerAngles(14-wiggle,0,1)
    -- The free glove reaches forward while the other hand keeps the stick.
    if joints.leftShoulder.rotation.slerp then
        joints.leftShoulder.rotation = joints.leftShoulder.rotation:slerp(toward,amount)
        joints.leftElbow.rotation = joints.leftElbow.rotation:slerp(bent,amount)
    else
        joints.leftShoulder.eulerAngles = vec3(65*amount+wiggle,0,-5*amount)
        joints.leftElbow.eulerAngles = vec3(14*amount-wiggle,0,amount)
    end
end

local function postgame(play,state,dt)
    local t = state.time
    if t < 1.16 then
        local focus = state.mvp
        local p = focus.player.rig.root.position
        for _,item in ipairs(state.pairs) do
            local clip = state.winner == item.team and t>.16 and "presentationLift" or nil
            pose(item,item.base,item.yaw,dt,clip)
            if state.winner and item.team ~= state.winner then
                item.player.rig.joints.head.eulerAngles = vec3(9*ease(t/.7),0,-5)
            end
        end
        setCamera(play,state,p+vec3(4.3,3.9,7.9),p+vec3(0,1.45,0),dt)
    elseif t < 4.32 then
        state.title,state.subtitle = "Postgame handshake",nil
        for _,item in ipairs(state.pairs) do
            travel(item,item.base,item.stage,(t-1.16)/1.99,item.team == 1 and 0 or 180,dt,
                t>3.08 and "presentationGreeting" or nil)
            greeting(item,t)
        end
        local slide = -1.6+3.3*ease((t-2.69)/1.63)
        setCamera(play,state,vec3(slide+3.2,3.65,8.3),vec3(slide,1.19,0),dt)
    else
        local focus = state.mvp
        local podium = state.kind == "championship"
        local start = focus.stage or focus.base
        local finish = ground(podium and -.57 or 0,0)
        local position = blend(start,finish,ease((t-4.32)/.80))
        pose(focus,position,166,dt,t>5.05 and "presentationLift" or nil)
        if podium and t>4.95 and not state.trophy then makeTrophy(play,state) end
        state.title = podium and "Championship trophy" or "Player of the Game"
        state.subtitle = podium and "Player of the Game  ·  "..state.mvpName or state.mvpName
        setCamera(play,state,vec3(2.9,3.1,6.8),vec3(0,1.36,0),dt)
    end
end

local function showMarker(game, visible)
    if game.marker then game.marker.active = visible end
end

function Presentation.start(play,kind,options)
    options = options or {}
    if options.championship and kind == "postgame" then kind = "championship" end
    if not durations[kind] or not play.game or #play.game.squad == 0 then return false end
    if play.presentation then Presentation.skip(play) end
    local game, camera = play.game,play.camera
    if not camera.playEye then
        local updateCamera = game.homeScore ~= nil and P.CameraController.match or P.CameraController.practice
        updateCamera(camera,game,0,nil,options.frame)
    end
    local state = {kind=kind,time=0,duration=durations[kind],actors={},saved={},
        markerActive=game.marker and game.marker.active,near=camera.lens.nearPlane,
        far=camera.lens.farPlane}
    registerClips(P.AnimationController)
    local known = {}
    for i,player in ipairs(game.squad) do
        state.actors[i]=actor(player,i,state.saved,known)
    end
    state.lead = state.actors[game.careerPlayer or game.controlled] or state.actors[1]
    if kind == "pregame" then
        benchAndLine(state,game)
    else
        state.eye,state.target = copy(camera.playEye),copy(camera.playTarget)
        if kind == "goal" then prepareGoal(state,game,options)
        else preparePostgame(state,game,options) end
    end
    camera.lens.nearPlane,camera.lens.farPlane = .30,math.max(455,state.far or 455)
    showMarker(game,false)
    play.presentation = state
    Presentation.update(play,0)
    return true
end

function Presentation.skip(play)
    local state = play.presentation
    if not state then return false end
    for _,part in ipairs(state.saved) do
        part.entity.position,part.entity.rotation = part.position,part.rotation
    end
    for _,part in ipairs(state.trophy or {}) do
        if part.destroy then part:destroy() else part.active = false end
    end
    local camera = play.camera
    camera.lens.nearPlane,camera.lens.farPlane = state.near,state.far
    camera.playEye,camera.playTarget = state.eye,state.target
    showMarker(play.game,state.markerActive)
    play.presentation = nil
    return true
end

function Presentation.update(play,dt)
    local state = play.presentation
    if not state then return false end
    state.time = state.time + math.max(0,dt)
    if state.time >= state.duration then
        Presentation.skip(play)
        return false
    end
    if state.kind == "pregame" then pregame(play,state,dt)
    elseif state.kind == "goal" then celebration(play,state,dt)
    else postgame(play,state,dt) end
    return true
end

function Presentation.skipBox()
    local safe = P.UI.safeArea()
    return {id="SKIP",x=WIDTH-safe.right-53,y=HEIGHT-safe.top-32,w=80,h=39}
end

function Presentation.touch(play,touch)
    if not play.presentation then return false end
    if touch.state == BEGAN and P.UI.hit(Presentation.skipBox(),touch.x,touch.y) then
        Presentation.skip(play)
    end
    return true
end

local function label(textValue,x,y,size,tint,maxWidth)
    fontSize(size)
    if maxWidth and textSize then
        local width = textSize(textValue)
        if width > maxWidth then fontSize(math.max(10,size*maxWidth/width)) end
    end
    fill(tint)
    text(textValue,x,y)
end

function Presentation.draw(play)
    local state = play.presentation
    if not state then return end
    local safe = P.UI.safeArea()
    local skip = Presentation.skipBox()
    local x = (WIDTH+safe.left-safe.right)*.5
    local w = math.min(390,WIDTH-safe.left-safe.right-28)
    local y = safe.bottom+53
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    P.Style.panel(skip.x,skip.y,skip.w,skip.h,false,11)
    label("SKIP",skip.x,skip.y,13,white)
    P.Style.rounded(x,y,w,65,13,shade)
    label(state.title or "",x,y+(state.subtitle and 8 or 0),16,white,w-22)
    if state.subtitle then label(state.subtitle,x,y-12,12,scoreInk,w-22) end
    local bar = (w-24)*clamp(state.time/state.duration,0,1)
    P.Style.rounded(x-w*.5+12+bar*.5,y-27,bar,2,1,scoreInk)
    popMatrix()
    popStyle()
end
