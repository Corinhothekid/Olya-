PolyLax = PolyLax or {}
local P = PolyLax
local Gameplay = {}
P.Gameplay = Gameplay

local formations = {
    {x = -4.6, z = 1.2, name = "M1"},
    {x = 4.6, z = 1.2, name = "M2"},
    {x = 0, z = -9.8, name = "M3"},
    {x = -6.3, z = -8.2, name = "A1"},
    {x = 6.3, z = -8.2, name = "A2"},
    {x = 0, z = -16, name = "X"}
}

local calls = {clear="CLEAR", swing="SWING", passdown="PASS DOWN"}
local passFlight = {speed=18,minDuration=.34,maxDuration=1.10,arcRate=.073,maxArc=.75}
local goalZ, goalieZ = -13, -12.3
local ballRadius, goalHalfWidth, goalTop = .09, .995, 1.745
local minX, maxX, minZ, maxZ = -8.4, 8.4, -16.5, 15.5
local gravity = 9.8
local atan2 = math.atan2 or math.atan

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function facing(x, z)
    return math.deg(atan2(-x, -z))
end

local function angleDifference(target, current)
    return (target - current + 180) % 360 - 180
end

local function makeField(scene)
    local cube = craft.model.cube()
    local function material(tint)
        local standard = asset and asset.builtin and asset.builtin.Materials
        local m = craft.material(standard and standard.Standard or "Materials:Standard")
        m.diffuse = tint
        return m
    end

    local ground = material(color(27, 77, 47))
    local stripe = {material(color(44, 121, 72)), material(color(36, 105, 61))}
    local white = material(color(240, 244, 247))
    local blue = material(color(43, 166, 255))

    local function block(parent, x, y, z, width, height, depth, tint)
        local entity = scene:entity()
        if parent then entity.parent = parent end
        entity.model, entity.material = cube, tint
        entity.position, entity.scale = vec3(x, y, z), vec3(width, height, depth)
        return entity
    end

    block(nil, 0, -.14, 0, 34, .25, 50, ground)
    for i = 0, 9 do
        block(nil, 0, .015, -17 + (i + .5) * 3.4, 18, .025, 3.4, stripe[i % 2 + 1])
    end
    for _, x in ipairs({-9, 9}) do
        block(nil, x, .045, 0, .07, .026, 34, white)
    end
    for _, z in ipairs({-17, -8, 0, 8, 17}) do
        block(nil, 0, .045, z, 18, .026, .07, white)
    end

    local function ring(parent, z, radius, pieces, tint)
        local chord = 2 * radius * math.sin(math.pi / pieces)
        local centerRadius = radius * math.cos(math.pi / pieces)
        for i = 1, pieces do
            local angle = i * 2 * math.pi / pieces
            local segment = block(parent, math.sin(angle) * centerRadius, .057,
                z + math.cos(angle) * centerRadius, chord, .012, .035, tint)
            segment.eulerAngles = vec3(0, math.deg(angle), 0)
        end
    end
    ring(nil, goalZ, 2.1, 28, white)

    local marker = scene:entity()
    ring(marker, 0, .65, 14, blue)

    local ball = scene:entity()
    ball.model = craft.model.icosphere(ballRadius, 1, true)
    ball.material = material(color(255, 211, 66))
    return ball, marker
end

local function announce(game, message, seconds)
    game.announcement, game.announcementTime = message, seconds or 1.1
end

local function pocket(player)
    return player.rig.pocket.worldPosition
end

local function resetPlay(game)
    game.carrier, game.controlled = 1, 1
    game.mode, game.clearTime = "SET", 0
    game.pending, game.flight, game.loose = nil, nil, nil
    game.scoopPlayer, game.goalDelay, game.inNet = nil, nil, nil
    game.tactical, game.passSerial = nil, 0
    P.Screens.reset(game)
    P.GoalPhysics.reset(game.goalPhysics)
    for i, player in ipairs(game.squad) do
        local anchor = formations[i]
        player.x, player.z = anchor.x, anchor.z
        player.vx, player.vz, player.dodge = 0, 0, nil
        player.yaw = facing(-player.x, goalZ - player.z)
        player.rig.root.position = vec3(player.x, 0, player.z)
        player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
        P.AnimationController.reset(player.anim)
    end
    game.goalieX, game.goaliePreviousX = 0, 0
    game.goalie.root.position = vec3(0, 0, goalieZ)
    P.AnimationController.reset(game.goalieAnim)
    game.ball.position = pocket(game.squad[1])
    game.marker.position = game.squad[1].rig.root.position
end

function Gameplay.applyUniform(game, uniform)
    for _, player in ipairs(game.squad) do
        P.Character.applyUniform(player.rig, uniform, false)
    end
    P.Character.applyUniform(game.goalie,
        P.TeamUniform.forKeeper(uniform, game.goalieRole, game.opponentId), false)
    game.uniform = uniform
end

function Gameplay.applyProfile(game, profile, uniform, opponentId)
    uniform = uniform or P.TeamUniform.fromProfile(profile)
    opponentId = opponentId or profile and profile.OPPONENT
    if uniform ~= game.uniform or opponentId ~= game.opponentId then
        game.opponentId = opponentId
        Gameplay.applyUniform(game, uniform)
    end
    P.Character.apply(game.squad[1].rig, profile, nil, uniform, false)
end

function Gameplay.new(scene, profile, uniform, opponentId)
    local Character, Animation = P.Character, P.AnimationController
    uniform = uniform or P.TeamUniform.fromProfile(profile)
    local ball, marker = makeField(scene)
    local game = {
        squad = {}, teams = {{1, 2, 3, 4, 5, 6}}, ball = ball, marker = marker, goal = vec3(0, .9, goalZ),
        goalPhysics = P.GoalPhysics.new(scene, {
            z=goalZ, attackSign=-1, halfWidth=goalHalfWidth, top=goalTop, radius=ballRadius
        }),
        goals = 0, passes = 0, clock = 180, elapsed = 0,
        announcement = "", announcementTime = 0, moveX = 0, moveZ = 0,
        uniform = uniform, goalieRole = "opponent", opponentId = opponentId or profile and profile.OPPONENT
    }
    P.Screens.registerAnimations()

    for i, anchor in ipairs(formations) do
        local rig = Character.new(scene)
        Character.apply(rig, i == 1 and profile or {
            FACE = (i - 1) % 4 + 1, HAIR = 2, BEARD = 1, BODY = 2, HELMET = 4,
            JERSEY = 2, GLOVES = 1, SHORTS = 4, CLEATS = 1, STICK = 4, NUMBER = i + 8
        }, nil, uniform, false)
        game.squad[i] = {
            id=i, team=1, role=i <= 3 and "M" or "A", slot=i,
            homeX=anchor.x, homeZ=anchor.z, rig=rig, anim=Animation.new(rig), name=anchor.name,
            attributes=i == 1 and profile and profile.attributes or nil
        }
    end

    game.goalie = Character.new(scene)
    Character.apply(game.goalie, {
        FACE = 2, HAIR = 2, BODY = 3, HELMET = 3, JERSEY = 6,
        GLOVES = 4, SHORTS = 4, CLEATS = 4, STICK = 4, NUMBER = 1
    }, nil, P.TeamUniform.forKeeper(uniform, game.goalieRole, game.opponentId), false)
    game.goalie.root.eulerAngles = vec3(0, 180, 0)
    game.goalieAnim = Animation.new(game.goalie)
    resetPlay(game)
    return game
end

local function startPass(game, plan, mode)
    local from = game.carrier
    if not from or not plan or not (plan.to or plan.point) or (plan.from and plan.from ~= from)
        or (plan.to and not game.squad[plan.to])
        or from == plan.to or game.pending or game.flight then return end
    if P.AnimationController.play(game.squad[from].anim, "pass") then
        game.pending = {kind="pass", from=from, to=plan.to, point=plan.point, call=mode}
        game.mode = mode
        game.clearTime = mode == "SET" and 0 or 3.5
        return true
    end
end

function Gameplay.passPreview(game, dx, dz)
    local from = game.carrier
    if game.clock <= 0 or game.goalDelay or not from or game.pending or game.flight
        or game.squad[from].anim.action then return end
    if from ~= game.controlled and length(dx or 0, dz or 0) < .12 then
        local plan = P.Passing.forTarget(game, game.controlled)
        plan.from = from
        return plan
    end
    return P.Passing.select(game, from, dx, dz)
end

local function tacticalPass(game, call)
    local from = game.carrier
    if not from or game.pending or game.flight then return end
    local to, detail = P.Tactics.choose(game, from, call)
    if not to then
        announce(game, "NO OPEN " .. (call == "PASS DOWN" and "DOWNFIELD" or call) .. " LANE")
        return
    end
    if startPass(game, P.Passing.forTarget(game, to), call) then
        P.Tactics.activate(game, detail, call, 1)
        return true
    end
end

local function playPick(game, manual)
    local holder = game.carrier
    if not holder or game.pending or game.flight or game.screen
        or (manual and game.controlled == holder) then return end
    local screener, detail
    if manual then
        screener = game.controlled
        local actor = game.squad[screener]
        detail = {x=actor.x, z=actor.z, manual=true}
    else
        detail = P.Tactics.pick(game, holder)
        if not detail then
            announce(game, "NO PICK AVAILABLE")
            return
        end
        screener = detail.screener
    end
    if P.Screens.request(game, screener, holder, nil, detail) then
        game.mode, game.clearTime = "PICK DOWN", 3.5
        return true
    end
end

local function startDodge(game, moveX, moveZ)
    local player = game.squad[game.controlled]
    local agility = P.Attributes.rating(player,"agility",60)-60
    if not P.AnimationController.play(player.anim, "dodge", 1+agility*.004) then return end

    local dx, dz = moveX, -moveZ
    local magnitude = length(dx, dz)
    if magnitude < .12 then
        local yaw = math.rad(player.yaw)
        local direction = player.x > 0 and 1 or -1
        dx, dz = direction * math.cos(yaw), -direction * math.sin(yaw)
        magnitude = 1
    end
    player.dodge = {x=dx/magnitude, z=dz/magnitude, time=.31, agility=agility}
end

local function startScoop(game, index, reach)
    if not game.loose or game.scoopPlayer or game.goalDelay then return false end
    local position = game.ball.position
    local velocity = game.loose.velocity
    local player = game.squad[index]
    local ground = P.Attributes.rating(player,"groundBalls",65)-65
    if position.y > .26 or length(velocity.x, velocity.z) > 2.7
        or length(position.x - player.x, position.z - player.z) > reach+ground*.005 then return false end
    if not P.AnimationController.play(player.anim, "scoop", 1+ground*.0038) then return false end
    game.scoopPlayer = index
    return true
end

function Gameplay.canAim(game)
    return game.clock > 0 and not game.goalDelay and game.carrier == game.controlled
        and not game.pending and not game.flight and not game.squad[game.controlled].anim.action
end

function Gameplay.aimContext(game)
    if not Gameplay.canAim(game) then return nil end
    return pocket(game.squad[game.carrier]), game.goalPhysics
end

function Gameplay.command(game, command, moveX, moveZ, aim)
    if command == "reset" then
        resetPlay(game)
        for _, player in ipairs(game.squad) do player.runningFatigue = 0 end
        game.goals, game.passes, game.clock, game.elapsed = 0, 0, 180, 0
        announce(game, "PRACTICE RESET")
        return
    end
    if game.clock <= 0 or game.goalDelay then return end

    if command == "switch" then
        game.controlled = game.controlled % #game.squad + 1
    elseif calls[command] then
        return tacticalPass(game, calls[command])
    elseif command == "pickdown" then
        return playPick(game, false)
    elseif command == "setpick" then
        return playPick(game, true)
    elseif command == "releasepick" then
        local screen = game.screen
        if screen and screen.manual then
            return P.Screens.endHold(game,screen.screener,moveX or game.moveX,-(moveZ or game.moveZ))
        end
    elseif command == "pass" then
        return startPass(game, aim or Gameplay.passPreview(game,
            moveX or game.moveX, -(moveZ or game.moveZ)), "SET")
    elseif command == "shoot" then
        if game.loose then
            announce(game, "RECOVER THE BALL")
        elseif game.carrier and game.carrier ~= game.controlled then
            announce(game, "PASS TO THE SHOOTER")
        elseif Gameplay.canAim(game)
            and P.AnimationController.play(game.squad[game.carrier].anim, "shoot") then
            local goal = game.goalPhysics
            local target = aim and vec3(
                clamp(aim.x, goal.x-goal.halfWidth-.75, goal.x+goal.halfWidth+.75),
                clamp(aim.y, 0, goal.top+.65), goal.z)
            game.pending = {kind="shot", from=game.carrier, aim=moveX or game.moveX, target=target}
            return true
        end
    elseif command == "dodge" then
        startDodge(game, moveX or game.moveX, moveZ or game.moveZ)
    elseif command == "scoop" and game.loose then
        if not game.scoopPlayer and not startScoop(game, game.controlled, 1.12) then
            announce(game, "MOVE TO THE BALL")
        end
    end
end

local function spacing(game, index)
    local player = game.squad[index]
    local x, z = 0, 0
    for i, other in ipairs(game.squad) do
        if i ~= index then
            local dx, dz = player.x - other.x, player.z - other.z
            local distance = length(dx, dz)
            if distance < .001 then
                dx, distance = index < i and -1 or 1, 1
            end
            if distance < 2 then
                local pressure = (2 - distance) / distance
                x, z = x + dx * pressure, z + dz * pressure
            end
        end
    end
    return x, z
end

local function offBallTarget(game, index, carrierX, carrierZ)
    local anchor = formations[index]
    local x, z = anchor.x, anchor.z
    if index ~= 6 then
        x = x + carrierX * .16
        z = z + clamp((carrierZ + 5) * .20, -1.6, 1.6)
        -- One off-ball player fills the middle at a time.
        local cutSlot = math.floor(game.elapsed / 2.7)
        if index == cutSlot % 5 + 1 and math.abs(carrierX - x) > 2.6 then
            local progress = game.elapsed / 2.7 - cutSlot
            local cut = math.sin(math.pi * progress)
            x = x * (1 - .45 * cut)
            z = z + (index < 3 and -2.7 or 1.8) * cut
        end
    end
    local sx, sz = spacing(game, index)
    return clamp(x + sx, minX, maxX), clamp(z + sz, minZ, maxZ)
end

local function nearestLoosePlayer(game)
    if not game.loose then return nil end
    local best, distance = nil, math.huge
    local ball = game.ball.position
    for i, player in ipairs(game.squad) do
        local d = length(ball.x - player.x, ball.z - player.z)
        if d < distance then best, distance = i, d end
    end
    return best, distance
end

local function movePlayers(game, dt)
    local holder = game.carrier and game.squad[game.carrier]
    local carrierX, carrierZ = holder and holder.x or 0, holder and holder.z or -5
    local chase = nearestLoosePlayer(game)
    local ball = game.ball.position
    local cut = P.Tactics.activeCut(game)
    local manual = length(game.moveX, game.moveZ) > .08

    for index, player in ipairs(game.squad) do
        local vx, vz = 0, 0
        local screen = game.screen and P.Screens.intent(game, index)
        local receiveX, receiveZ = P.Passing.receiveTarget(game, index)
        local cutting = cut and cut.cutID == index
        local screenControl = screen and screen.screenControl
        player.screenIntent = screen
        if index == game.controlled and not screenControl and (manual or not (cutting or receiveX)) then
            local speed = P.Attributes.pace(player,game.sprinting and 8.3 or 6.1)
            vx, vz = game.moveX * speed, -game.moveZ * speed
        elseif index ~= game.carrier or screenControl then
            local tx, tz = offBallTarget(game, index, carrierX, carrierZ)
            local limit = 4.4
            if index == chase then
                local dx, dz = player.x - ball.x, player.z - ball.z
                local distance = length(dx, dz)
                if distance < .05 then
                    local yaw = math.rad(player.yaw)
                    dx, dz, distance = math.sin(yaw), math.cos(yaw), 1
                end
                tx, tz = ball.x + dx * .65 / distance, ball.z + dz * .65 / distance
                limit = 5.3
            elseif receiveX then
                tx, tz, limit = receiveX, receiveZ, 5.8
            elseif cutting then
                tx, tz, limit = cut.cutX, cut.cutZ, 5.6
            elseif screenControl then
                tx, tz, limit = screen.x, screen.z, screen.speed
            end
            local dx, dz = tx - player.x, tz - player.z
            local distance = length(dx, dz)
            if distance > .08 then
                local speed = math.min(distance*3, limit > 0 and P.Attributes.pace(player,limit) or 0)
                vx, vz = dx * speed / distance, dz * speed / distance
            end
        end

        local dodge = player.dodge
        if dodge then
            local burst = 6.8+3*dodge.time/.31+(dodge.agility or 0)*.033
            vx, vz = dodge.x * burst, dodge.z * burst
            dodge.time = dodge.time - dt
            if dodge.time <= 0 then player.dodge = nil end
        end

        local dvx, dvz = vx - player.vx, vz - player.vz
        local acceleration = dodge and 43 or 19+(P.Attributes.rating(player,"acceleration",60)-60)*.16
        local accel = math.min(1, acceleration*dt/math.max(.001,length(dvx,dvz)))
        local oldX, oldZ = player.x, player.z
        player.x = clamp(oldX + (player.vx + accel * dvx) * dt, minX, maxX)
        player.z = clamp(oldZ + (player.vz + accel * dvz) * dt, minZ, maxZ)
        player.vx, player.vz = (player.x - oldX) / dt, (player.z - oldZ) / dt
        player.speed = length(player.vx, player.vz)
        P.Attributes.updateFatigue(player,dt)
    end

    for index, player in ipairs(game.squad) do
        local lookX, lookZ = player.vx, player.vz
        local pending, flight = game.pending, game.flight
        if pending and pending.from == index then
            local target = pending.to and game.squad[pending.to] or pending.point or pending.target or game.goal
            lookX, lookZ = target.x-player.x, target.z-player.z
        elseif player.screenIntent and player.screenIntent.lookX then
            lookX, lookZ = player.screenIntent.lookX-player.x, player.screenIntent.lookZ-player.z
        elseif flight and flight.to == index and flight.duration - flight.time < .43 then
            lookX, lookZ = flight.origin.x-player.x, flight.origin.z-player.z
        elseif game.scoopPlayer == index then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        elseif player.speed < .25 then
            lookX, lookZ = (holder and holder ~= player and carrierX or 0) - player.x,
                (holder and holder ~= player and carrierZ or goalZ) - player.z
        end
        local rotation = 0
        local turnRate = 540+(P.Attributes.rating(player,"agility",60)-60)*3.1
        if length(lookX, lookZ) > .04 then
            rotation = clamp(angleDifference(facing(lookX, lookZ), player.yaw), -turnRate*dt, turnRate*dt)
        end
        player.yaw = (player.yaw + rotation) % 360
        player.turn = rotation / (turnRate*dt)
        player.rig.root.position = vec3(player.x, 0, player.z)
        player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
    end

    local goalieTarget = clamp(carrierX, -.9, .9)
    local flight = game.flight
    if flight and flight.kind == "shot" then
        goalieTarget = game.goalieX
        if ball.z > goalieZ and ball.z < goalieZ + 3 then
            goalieTarget = clamp(ball.x, -.9, .9)
        end
    end
    local shift = clamp(goalieTarget - game.goalieX, -3 * dt, 3 * dt)
    game.goaliePreviousX = game.goalieX
    game.goalieX = game.goalieX + shift
    game.goalie.root.position = vec3(game.goalieX, 0, goalieZ)
    P.AnimationController.update(game.goalieAnim, dt, {speed = math.abs(shift / dt)})
end

local function makeLoose(game, position, velocity)
    game.carrier, game.flight, game.pending = nil, nil, nil
    game.loose = {velocity = velocity}
    game.ball.position = position
    if game.mode == "SWING" then game.mode = "SET" end
end

local function beginGoal(game, contact)
    if game.inNet then return end
    local fixed = P.GoalPhysics.capture(game.goalPhysics, contact.position)
    game.carrier, game.flight, game.pending, game.loose = nil, nil, nil, nil
    game.scoopPlayer = nil
    game.inNet = {state="IN_NET", entrance=contact.position, fixed=fixed, age=0}
    game.goalDelay = P.GoalPhysics.scoreHold
    game.ball.position = contact.position
    game.goals = game.goals + 1
    announce(game, "GOAL", game.goalDelay)
end

local function release(game, pending)
    local flight
    local from = game.squad[pending.from]
    if pending.kind == "pass" then
        local speed = 18+(P.Attributes.rating(from,"passing",60)-60)*.12
        flight = P.Passing.launch(game, pending, passFlight, speed)
        game.passes = game.passes + 1
    else
        local launch = pocket(from)
        flight = {kind="shot", from=pending.from, origin=launch, time=0}
        local aim = (pending.aim + game.moveX) * .5
        local goal = game.goalPhysics
        local targetX = game.goalieX <= goal.x and goal.x+.69 or goal.x-.69
        if math.abs(aim) > .16 then targetX = goal.x + aim * 1.45 end
        local target = pending.target or vec3(targetX, 1.12 + from.speed*.018, goal.z)
        local span = length(target.x-launch.x,target.z-launch.z)
        local spreadX,spreadY = P.Attributes.shotSpread(game,from,span)
        target = target+vec3(spreadX,spreadY,0)
        local velocity = 23+(P.Attributes.rating(from,"shotPower",60)-60)*.15
        local crossingTime = clamp(span/velocity,.15,1.05)
        flight.duration = crossingTime + .32
        flight.velocity = (target-launch)/crossingTime + vec3(0, .5*gravity*crossingTime, 0)
        if pending.target then
            flight.velocity = flight.velocity + vec3(from.vx*.10, 0, from.vz*.10)
        end
        flight.canScore = (launch.z-goal.z)*goal.attackSign <= 0
        local y = math.max(0, launch.y-ballRadius)
        local vy = flight.velocity.y
        flight.groundTime = (vy+math.sqrt(vy*vy+2*gravity*y))/gravity
    end

    game.pending, game.carrier, game.flight = nil, nil, flight
    game.ball.position = flight.origin
end

local function planScoop(game)
    if not game.loose or game.scoopPlayer or game.goalDelay then return end
    local index = nearestLoosePlayer(game)
    if index then startScoop(game, index, .84) end
end

local function attach(game, index)
    game.carrier, game.controlled = index, index
    game.scoopPlayer, game.loose, game.flight = nil, nil, nil
    game.ball.position = pocket(game.squad[index])
    if game.mode == "SWING" then game.mode = "SET" end
end

local function rebound(game, contact, canScore)
    local position = contact.position + contact.normal * .003
    local y = math.max(ballRadius, position.y)
    makeLoose(game, vec3(position.x,y,position.z), contact.velocity * .65)
    game.loose.canScore = canScore
    announce(game, contact.kind)
end

local function updateShot(game, flight, dt)
    local endTime = math.min(flight.time+dt, flight.duration, flight.groundTime)
    local goal = game.goalPhysics
    local frameStart = flight.time
    while flight.time < endTime do
        -- Chord sweeps over short ballistic steps preserve contact order
        -- through a frame spike and follow a moving keeper's body.
        local t = math.min(flight.time+.018, endTime)
        local previous = game.ball.position
        local position = flight.origin + flight.velocity*t - vec3(0,.5*gravity*t*t,0)
        local velocity = flight.velocity - vec3(0,gravity*t,0)
        local keeperDelta = game.goalieX - game.goaliePreviousX
        local keeper = {
            z=goalieZ, x=game.goaliePreviousX+keeperDelta*((t-frameStart)/dt),
            prevX=game.goaliePreviousX+keeperDelta*((flight.time-frameStart)/dt)
        }
        local contact = P.GoalPhysics.step(goal, previous, position, velocity, keeper)
        if contact then
            local kind = contact.kind
            if kind == "GOAL" and flight.canScore then
                beginGoal(game, contact)
                return
            elseif kind == "POST" or kind == "CROSSBAR" or kind == "SAVE" then
                rebound(game, contact, flight.canScore)
                return
            elseif kind ~= "GOAL" and flight.canScore then
                flight.miss = kind
                announce(game, kind)
            end
        end
        flight.time, game.ball.position = t, position
    end

    if flight.time >= flight.duration or flight.time >= flight.groundTime then
        if not flight.miss then
            if not flight.canScore then
                announce(game, "BEHIND THE GOAL LINE")
            elseif (game.ball.position.z-goal.z)*goal.attackSign < goal.radius then
                announce(game, "SHOT FELL SHORT")
            end
        end
        local position = game.ball.position
        local velocity = flight.velocity - vec3(0,gravity*flight.time,0)
        makeLoose(game, vec3(position.x,math.max(ballRadius,position.y),position.z), velocity*.26)
        game.loose.canScore = flight.canScore
    end
end

local function updateFlight(game, dt, catchIndex)
    local flight = game.flight
    if flight.kind == "shot" then
        updateShot(game, flight, dt)
        return
    end
    flight.time = math.min(flight.time + dt, flight.duration)
    game.ball.position = P.Passing.sample(game, flight, flight.time)
    if P.Passing.canCatch(game, flight, catchIndex, game.ball.position) then
        local autoSelect = game.controlled == flight.from
        local controlled = game.controlled
        attach(game, flight.to)
        if not autoSelect then game.controlled = controlled end
    elseif flight.time >= flight.duration then
        makeLoose(game, game.ball.position, P.Passing.endVelocity(game, flight))
        announce(game, flight.to and "PASS DROPPED" or "BALL TO SPACE")
    end
end

local function updateLoose(game, dt, scoopIndex)
    local loose = game.loose
    local v = loose.velocity
    local position = game.ball.position + v * dt
    local x, y, z = position.x, position.y, position.z
    local vx, vy, vz = v.x, v.y - gravity * dt, v.z

    if y < ballRadius then
        y = ballRadius
        vy = math.abs(vy) > .85 and math.abs(vy) * .28 or 0
        local drag = math.max(0, 1 - 4 * dt)
        vx, vz = vx * drag, vz * drag
    end
    if x < minX or x > maxX then
        x, vx = clamp(x, minX, maxX), -vx * .45
    end
    if z < minZ or z > maxZ then
        z, vz = clamp(z, minZ, maxZ), -vz * .45
    end

    local nextPosition = vec3(x,y,z)
    local frame = P.GoalPhysics.step(game.goalPhysics, game.ball.position, nextPosition, v)
    if frame then
        if frame.kind == "GOAL" and loose.canScore then
            beginGoal(game, frame)
            return
        elseif frame.kind == "POST" or frame.kind == "CROSSBAR" then
            rebound(game, frame, loose.canScore)
            return
        end
    end
    game.ball.position = nextPosition
    loose.velocity = vec3(vx, vy, vz)

    if scoopIndex and scoopIndex == game.scoopPlayer then
        local player = game.squad[scoopIndex]
        game.scoopPlayer = nil
        local contact = pocket(player)
        local ground = P.Attributes.rating(player,"groundBalls",65)-65
        if y <= .32 and contact.y <= .72 and length(x-contact.x,z-contact.z) <= .73+ground*.004 then
            attach(game, scoopIndex)
            announce(game, "GROUND BALL")
        end
    end
end

function Gameplay.update(game, dt, moveX, moveZ)
    if dt <= 0 then return end
    game.announcementTime = math.max(0, game.announcementTime - dt)
    P.GoalPhysics.update(game.goalPhysics, dt)
    if game.inNet then
        local net = game.inNet
        net.age = net.age + dt
        game.goalDelay = math.max(0, P.GoalPhysics.scoreHold - net.age)
        local progress = math.min(1,net.age/.18)
        local travel = 1-(1-progress)^2
        game.ball.position = net.entrance + (net.fixed-net.entrance)*travel
        if game.goalDelay == 0 then
            resetPlay(game)
            if game.clock <= 0 then announce(game, "PRACTICE COMPLETE", 2) end
        end
    end
    if game.clock <= 0 then return end
    game.clock = math.max(0, game.clock - dt)
    game.elapsed = game.elapsed + dt
    local magnitude = math.max(1, length(moveX, moveZ))
    game.moveX, game.moveZ = moveX / magnitude, moveZ / magnitude

    if game.clearTime > 0 then
        game.clearTime = math.max(0, game.clearTime - dt)
        if game.clearTime == 0 then game.mode = "SET" end
    end

    movePlayers(game, dt)
    P.Passing.scheduleCatch(game, game.flight, dt)
    planScoop(game)

    local flight, loose = game.flight, game.loose
    local catchIndex, scoopIndex
    for index, player in ipairs(game.squad) do
        local event = P.AnimationController.update(player.anim, dt, {
            speed = player.speed, possessed = game.carrier == index, turn = player.turn,
            scoopPoint = game.scoopPlayer == index and game.ball.position or nil,
            catchPoint = P.Passing.catchPoint(game, index)
        })
        if event == "release" and game.pending and game.pending.from == index then
            release(game, game.pending)
        elseif event == "catch" then
            catchIndex = index
        elseif event == "scoop" then
            scoopIndex = index
        end
    end
    if game.scoopPlayer and not game.squad[game.scoopPlayer].anim.action and not scoopIndex then
        game.scoopPlayer = nil
    end

    if flight then
        updateFlight(game, dt, catchIndex)
    elseif loose then
        updateLoose(game, dt, scoopIndex)
    elseif game.carrier then
        game.ball.position = pocket(game.squad[game.carrier])
    end

    P.Screens.update(game, dt)
    game.marker.position = game.squad[game.controlled].rig.root.position
    if game.clock == 0 and not game.inNet then announce(game, "PRACTICE COMPLETE", 2) end
end
