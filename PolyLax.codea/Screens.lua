-- PolyLax Build 013 | Planted screens and roll/pop releases
PolyLax = PolyLax or {}
local P = PolyLax
local Screens = {}
P.Screens = Screens

local minPlant, stopSpeed = .14, .24
local approvalWindow = 2.8

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function direction(x, z, fallbackX, fallbackZ)
    local span = length(x, z)
    if span < .001 then return fallbackX or 0, fallbackZ or -1 end
    return x / span, z / span
end

local function speed(actor)
    return math.max(actor.speed or 0, length(actor.vx or 0, actor.vz or 0))
end

local function attribute(player, key, fallback)
    local value = tonumber(player.attributes and player.attributes[key]) or fallback
    return clamp(value > 1 and value / 100 or value, .05, 1)
end

local function frame(time, grip, shaft, torso, crouch, roll)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll or 0, freeHand=0}
end

function Screens.registerAnimations()
    local clips = P.AnimationController.clips
    if clips.screenPlant then return end
    local function plant(time, bend)
        return frame(time, vec3(.042,.67,-.29), vec3(.021,.99,-.085),
            vec3(bend,0,0), .075, 0)
    end
    clips.screenPlant = {duration=2.45, poses={plant(.13,-3), plant(.27,-1), plant(2.32,-1)}}
    clips.screenRoll = {
        duration=.36, eventTime=.12, event="screenRelease",
        poses={frame(.11,vec3(.12,.60,-.29),vec3(.25,.94,-.10),vec3(-5,16,5),.048,8),
            frame(.24,vec3(.27,.69,-.22),vec3(.65,.73,-.10),vec3(-8,-9,0),.015,-8)}
    }
    clips.screenPop = {
        duration=.36, eventTime=.12, event="screenRelease",
        poses={frame(.12,vec3(.13,.74,-.33),vec3(.25,.96,-.07),vec3(-3,-10,-4),.030,-9),
            frame(.24,vec3(.29,.79,-.29),vec3(.57,.78,-.09),vec3(1,7,3),.012,8)}
    }
end

local function limitPoint(game, x, z)
    local field = game.field
    local width = field and field.halfWidth or 9
    local lengthZ = field and field.halfLength or 17
    return clamp(x, -width + .65, width - .65), clamp(z, -lengthZ + .75, lengthZ - .75)
end

local function goalCoordinates(game, player, options)
    local goal = game.goalsByTeam and game.goalsByTeam[player.team] or game.goal
    return options.goalX or (goal and goal.x) or 0, options.goalZ or (goal and goal.z) or -13
end

local function releasePose(game, screen, player, moveX, moveZ)
    local style = screen.style
    local forwardX, forwardZ = direction(screen.goalX - player.x, screen.goalZ - player.z)
    local x, z
    if length(moveX or 0, moveZ or 0) > .25 then
        local ux, uz = direction(moveX, moveZ)
        style = ux * forwardX + uz * forwardZ > .36 and "roll" or "pop"
        local span = style == "roll" and 4.7 or 4.0
        x, z = player.x + ux * span, player.z + uz * span
    elseif style == "pop" then
        x = player.x - forwardX * 1.12 - forwardZ * screen.side * 3.8
        z = player.z - forwardZ * 1.12 + forwardX * screen.side * 3.8
    else
        x = player.x + forwardX * 4.9 - forwardZ * screen.side * 1.0
        z = player.z + forwardZ * 4.9 + forwardX * screen.side * 1.0
    end
    x, z = limitPoint(game, x, z)
    return x, z, style
end

local function stopPlant(player)
    local anim = player and player.anim
    if anim and anim.action == "screenPlant" then
        anim.action, anim.entry = nil, nil
    end
end

function Screens.reset(game)
    if game.screen then stopPlant(game.squad[game.screen.screener]) end
    game.screen, game.screenCredit, game.screenShotCredit = nil, nil, nil
end

function Screens.request(game, screenerId, userId, defenderId, options)
    if game.screen or game.phase and game.phase ~= "LIVE" then return nil, "busy" end
    options = options or {}
    local screener, user = game.squad[screenerId], game.squad[userId]
    local defender = defenderId and game.squad[defenderId]
    if not screener or not user or screener == user or screener.role == "G"
        or game.carrier == screenerId or screener.team and user.team and screener.team ~= user.team then
        return nil, "invalid screener"
    end
    if defenderId and (not defender or defender == user or defender == screener
        or defender.role == "G" or user.team and defender.team == user.team) then
        return nil, "invalid defender"
    end
    local goalX, goalZ = goalCoordinates(game, user, options)
    local fx, fz = direction(goalX - user.x, goalZ - user.z)
    local side = options.side or (screener.x < user.x and -1 or 1)
    side = side >= 0 and 1 or -1
    local x, z
    if defender then
        local ux, uz = direction(user.x - defender.x, user.z - defender.z, -fx, -fz)
        x = defender.x + ux * 1.22 - uz * side * .52
        z = defender.z + uz * 1.22 + ux * side * .52
    else
        x, z = user.x + fx * 1.9 - fz * side * 1.35, user.z + fz * 1.9 + fx * side * 1.35
    end
    x, z = limitPoint(game, options.x or x, options.z or z)
    local faceX, faceZ = direction(user.x - x, user.z - z, -fx, -fz)
    local screen = {
        screener=screenerId, user=userId, defender=defenderId, team=user.team,
        x=x, z=z, faceX=faceX, faceZ=faceZ, goalX=goalX, goalZ=goalZ,
        side=side, style=options.release == "pop" and "pop" or "roll",
        phase="APPROACH", age=0, phaseTime=0, planted=0, unpossessed=0,
        contact=false, effective=false, realDefender=defender ~= nil,
        manual=options.manual == true
    }
    if defender then
        screen.previous = {sx=screener.x,sz=screener.z,dx=defender.x,dz=defender.z}
    end
    game.screen = screen
    return screen
end

function Screens.release(game, id, moveX, moveZ)
    local screen = game.screen
    if not screen or screen.screener ~= id or screen.phase == "RELEASE" then return false end
    local player = game.squad[id]
    local lastPose = player.anim and player.anim.lastPose
    stopPlant(player)
    screen.releaseX, screen.releaseZ, screen.style = releasePose(game, screen, player, moveX, moveZ)
    screen.phase, screen.phaseTime = "RELEASE", 0
    if player.anim then
        local clip = screen.style == "roll" and "screenRoll" or "screenPop"
        if P.AnimationController.play(player.anim, clip) then player.anim.entry = lastPose end
    end
    return true
end

-- A quick button tap queues a complete plant. A hold gives the player
-- direct control over when the planted athlete rolls or pops.
function Screens.endHold(game,id,moveX,moveZ)
    local screen = game.screen
    if screen and screen.screener==id and screen.manual
        and (screen.phase=="APPROACH" or screen.phase=="PLANT") then
        screen.manual = false
        screen.exitX,screen.exitZ = moveX,moveZ
        return true
    end
    return Screens.release(game,id,moveX,moveZ)
end

local function manualMovement(game, id)
    return game.controlled == id and length(game.moveX or 0, game.moveZ or 0) > .25
end

local function copyIntent(intent)
    local copy = {}
    for key, value in pairs(intent or {}) do copy[key] = value end
    return copy
end

function Screens.intent(game, playerId, intent)
    local screen = game.screen
    if not screen then return intent end
    if playerId == screen.screener then
        if (screen.phase == "PLANT" or screen.phase == "HOLD") and manualMovement(game, playerId) then
            return intent
        end
        intent = copyIntent(intent)
        intent.screenControl = true
        if screen.phase == "RELEASE" then
            intent.x, intent.z, intent.speed = screen.releaseX, screen.releaseZ,
                screen.style == "roll" and 6.4 or 5.6
            local user = game.squad[screen.user]
            if screen.style == "pop" then intent.lookX, intent.lookZ = user.x, user.z
            else intent.lookX, intent.lookZ = screen.releaseX, screen.releaseZ end
        else
            intent.x, intent.z = screen.x, screen.z
            intent.speed = screen.phase == "APPROACH" and 4.8 or 0
            local player = game.squad[playerId]
            intent.lookX, intent.lookZ = player.x + screen.faceX, player.z + screen.faceZ
        end
        return intent
    end
    if playerId == screen.defender and (screen.dragTime or 0) > 0 then
        intent = copyIntent(intent)
        local strength = math.min(1, screen.dragTime / .20)
        intent.screenDrag = 1 - screen.dragStrength * strength
        if game.controlled ~= playerId then
            if screen.escapeX then intent.x, intent.z = screen.escapeX, screen.escapeZ end
            intent.speed = (intent.speed or 7.2) * intent.screenDrag
        end
        return intent
    end
    return intent
end

local function actorShape(player)
    local scale = player.rig and player.rig.proportions and player.rig.proportions.scale
    return scale and scale.x or 1
end

local function approachContact(screen, player, guard)
    local prev = screen.previous
    local x0, z0 = prev.dx - prev.sx, prev.dz - prev.sz
    local x1, z1 = guard.x - player.x, guard.z - player.z
    local vx, vz = x1 - x0, z1 - z0
    local fraction = clamp(-(x0*vx + z0*vz) / math.max(vx*vx + vz*vz,.000001), 0, 1)
    local x, z = x0 + vx * fraction, z0 + vz * fraction
    local span = length(x, z)
    local yaw = math.rad(player.yaw or 0)
    local ux, uz = direction(x, z, 1, 0)
    local lateral = math.cos(yaw) * ux - math.sin(yaw) * uz
    local depth = math.sin(yaw) * ux + math.cos(yaw) * uz
    local width = actorShape(player) * math.sqrt((.405*lateral)^2 + (.25*depth)^2)
    local close = span <= width + actorShape(guard) * .31
    local previousGap, currentGap = length(x0,z0), length(x1,z1)
    local closing = previousGap - span > .003 or currentGap < previousGap - .003
    local initiator = (player.x-prev.sx)*ux + (player.z-prev.sz)*uz > .009
    prev.sx, prev.sz, prev.dx, prev.dz = player.x, player.z, guard.x, guard.z
    return close, closing, initiator
end

local function stanceIssue(actor, guard)
    local anim, rig = actor.anim, actor.rig
    local pose = anim and anim.lastPose
    if pose and (math.abs(pose.torso.x) > 13 or math.abs(pose.torso.z) > 11) then
        return "leaning into the defender"
    end
    if not rig or not rig.body or not rig.joints or not rig.stickRoot then return end
    local body, joints = rig.body, rig.joints
    local left, right = joints.leftAnkle.worldPosition, joints.rightAnkle.worldPosition
    local span = length(left.x - right.x, left.z - right.z)
    local shoulder = joints.rightShoulder.position.x - joints.leftShoulder.position.x
    if span > (shoulder + .05) * actorShape(actor) then return "wide stance" end
    local function outside(point, radius)
        local localPoint = body:inverseTransformPoint(point)
        if math.abs(localPoint.x) > shoulder * .57 or math.abs(localPoint.z) > .67 then
            local near = length(point.x - guard.x, point.z - guard.z)
            return near < radius and point.y > .32 and point.y < 2.38
        end
    end
    for _, ordinate in ipairs({-.82, 0, .79, 1.02}) do
        if outside(rig.stickRoot:transformPoint(vec3(0, ordinate, 0)), .48) then
            return "stick outside the body frame"
        end
    end
    if outside(joints.leftWrist.worldPosition, .44) or outside(joints.rightWrist.worldPosition, .44) then
        return "arms outside the body frame"
    end
end

local function meta(screen, reason)
    return {screener=screen.screener, user=screen.user, defender=screen.defender,
        release=screen.style, reason=reason}
end

local function record(callbacks, screen, key, reason)
    if callbacks and callbacks.stat then callbacks.stat(screen.screener, key, meta(screen, reason)) end
end

local function registerContact(game, screen, screener, user, defender, callbacks, mature)
    local close, closing, initiator = approachContact(screen, screener, defender)
    local issue
    if close or length(defender.x-screener.x,defender.z-screener.z) < 1.48 then
        issue = stanceIssue(screener, defender)
    end
    local gearHit = issue == "stick outside the body frame" or issue == "arms outside the body frame"
    local firstGearHit = gearHit and not screen.gearTouching
    local alreadyTouching = screen.touching
    screen.gearTouching, screen.touching = gearHit, close
    if not close and not gearHit then return end
    local moving = speed(screener) > stopSpeed or screener.dodge or screener.check
    if screen.phase == "RELEASE" and (alreadyTouching or not initiator) then return end
    if screen.contact and not (initiator and moving) and not firstGearHit then return end
    if not closing and not initiator and not firstGearHit then return end
    if moving or not mature or issue then
        local reason = moving and "moving pick" or issue or "contact before the plant"
        record(callbacks, screen, "illegalScreens", reason)
        stopPlant(screener)
        game.screen, game.screenCredit = nil, nil
        if callbacks and callbacks.foul then callbacks.foul(screen.screener, screen.defender, meta(screen, reason)) end
        return
    end

    screen.contact = true
    screen.contactTime = screen.age
    screen.dragTime = .10 + .82 * clamp(.42 + .56 * (attribute(screener,"strength",.64)
        - attribute(defender,"reaction",.67)), .05, .87)
    screen.dragStrength = clamp(.52 + .60 * (attribute(screener,"strength",.64)
        - attribute(defender,"strength",.60)), .24, .80)
    if defender.vx and defender.vz then
        local retention = 1 - screen.dragStrength * .48
        defender.vx, defender.vz = defender.vx * retention, defender.vz * retention
        defender.speed = length(defender.vx, defender.vz)
    end
    screen.contactGap = length(user.x-defender.x,user.z-defender.z)
    screen.userX, screen.userZ = user.x, user.z
    local ux, uz = direction(user.x-defender.x,user.z-defender.z)
    screen.escapeX, screen.escapeZ = limitPoint(game, screener.x - uz * screen.side * 1.55 + ux * .65,
        screener.z + ux * screen.side * 1.55 + uz * .65)
    record(callbacks, screen, "screens", "legal planted contact")
end

local function samePossession(game, screen)
    local owner = game.carrier and game.squad[game.carrier]
    if owner then
        if screen.team and owner.team then return owner.team == screen.team end
        return game.carrier ~= screen.screener
    end
    return game.flight ~= nil and not game.loose
        and (not screen.team or not game.flight.team or game.flight.team == screen.team)
end

local function updateCredit(game, dt)
    local credit = game.screenCredit
    if credit then
        local holder = game.carrier and game.squad[game.carrier]
        credit.time = credit.time - dt
        if credit.time <= 0 or (holder and credit.team and holder.team ~= credit.team) then
            game.screenCredit = nil
        end
    end
    local shot = game.screenShotCredit
    if shot then
        shot.time = shot.time - dt
        if shot.time <= 0 then game.screenShotCredit = nil end
    end
end

function Screens.update(game, dt, callbacks)
    updateCredit(game, dt)
    local screen = game.screen
    if not screen then return end
    local actor, user = game.squad[screen.screener], game.squad[screen.user]
    if game.carrier == screen.screener then
        stopPlant(actor)
        game.screen = nil
        return
    end
    screen.age, screen.phaseTime = screen.age + dt, screen.phaseTime + dt
    screen.unpossessed = samePossession(game, screen) and 0 or screen.unpossessed + dt
    if screen.unpossessed > .21 or screen.age > 5.25 then
        stopPlant(actor)
        game.screen = nil
        return
    end

    local drift = length(actor.x-screen.x,actor.z-screen.z)
    local mature = screen.phase == "HOLD" and screen.planted >= minPlant
    if screen.phase == "APPROACH" and drift <= .28 and speed(actor) <= .65 then
        screen.phase, screen.phaseTime = "PLANT", 0
        if actor.anim then P.AnimationController.play(actor.anim, "screenPlant") end
    end
    if screen.phase == "PLANT" or screen.phase == "HOLD" then
        local set = speed(actor) <= stopSpeed and drift <= .31 and not actor.dodge and not actor.check
        if actor.anim and actor.anim.action ~= "screenPlant" then
            set = set and P.AnimationController.play(actor.anim, "screenPlant")
        end
        screen.planted = set and screen.planted + dt or 0
        if screen.phase == "PLANT" and screen.planted >= minPlant then
            screen.phase, screen.phaseTime = "HOLD", 0
        end
        mature = mature and set
    end

    local defender = screen.defender and game.squad[screen.defender]
    if defender then
        if screen.dragTime then screen.dragTime = math.max(0, screen.dragTime - dt) end
        registerContact(game, screen, actor, user, defender, callbacks, mature)
        if game.screen ~= screen then return end
        if screen.contact and not screen.effective and screen.age - screen.contactTime <= .76 then
            local separation = length(user.x-defender.x,user.z-defender.z)
            if separation >= math.max(1.42, screen.contactGap + .38)
                and length(user.x-screen.userX,user.z-screen.userZ) >= .32 then
                screen.effective = true
                game.screenCredit = {screener=screen.screener,user=screen.user,defender=screen.defender,
                    team=screen.team,time=approvalWindow,metadata=meta(screen,"screen opened a lane")}
            end
        end
    end

    local automatic = not screen.manual and (screen.phaseTime >= .82
        or screen.effective and screen.phaseTime >= .27)
    local receiving = game.pending and game.pending.to == screen.screener
        or game.flight and game.flight.to == screen.screener
    if screen.phase ~= "RELEASE" and receiving then
        Screens.release(game, screen.screener)
    elseif screen.phase == "HOLD" and (automatic or screen.phaseTime >= 1.8) then
        Screens.release(game,screen.screener,screen.exitX,screen.exitZ)
    elseif screen.phase == "RELEASE" and (screen.phaseTime >= 1.15
        or length(actor.x-screen.releaseX,actor.z-screen.releaseZ) < .30) then
        game.screen = nil
    elseif screen.phase == "APPROACH" and screen.phaseTime >= 3.9 then
        game.screen = nil
    end
end

local function nearestPressure(game, shooter)
    local nearest = math.huge
    for _, player in ipairs(game.squad) do
        if player.team ~= shooter.team and player.role ~= "G" then
            nearest = math.min(nearest, length(player.x-shooter.x,player.z-shooter.z))
        end
    end
    return nearest
end

function Screens.creditShot(game, shooterId, stat, flight)
    local credit = game.screenCredit
    if not credit or credit.user ~= shooterId or credit.time <= 0 then return false end
    if nearestPressure(game, game.squad[shooterId]) < 1.42 then return false end
    game.screenCredit = nil
    game.screenShotCredit = {screener=credit.screener,user=shooterId,time=2.9,
        metadata=credit.metadata,flight=flight}
    if stat then stat(credit.screener, "screenOpenShots", credit.metadata) end
    return true
end

function Screens.creditGoal(game, shooterId, stat, flight)
    local shot = game.screenShotCredit
    if not shot or shot.user ~= shooterId or shot.time <= 0 or (shot.flight and shot.flight ~= flight) then
        return false
    end
    game.screenShotCredit = nil
    if stat then stat(shot.screener, "screenAssists", shot.metadata) end
    return true
end
