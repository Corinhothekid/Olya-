-- PolyLax Build 011 | FullMatch
PolyLax = PolyLax or {}
local P = PolyLax
local Match = {}
P.FullMatch = Match

local ballRadius, gravity = .09, 9.8
local userPlayer = 4
local atan2 = math.atan2 or math.atan
local formation = {
    {"A", 1, -13, 29}, {"A", 2, 13, 29}, {"A", 3, 0, 43},
    {"M", 1, 0, 0}, {"M", 2, -18.288, 3}, {"M", 3, 18.288, 3},
    {"D", 1, -12, -24}, {"D", 2, 12, -24}, {"D", 3, 0, -29},
    {"G", 1, 0, -35.2}
}

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distance(x, z)
    return math.sqrt(x * x + z * z)
end

local function directionFor(team)
    return team == 1 and -1 or 1
end

local function yawFor(x, z)
    return math.deg(atan2(-x, -z))
end

local function announce(match, text, seconds)
    match.announcement, match.announcementTime = text, seconds or 1.3
end

local function pocket(player)
    return player.rig.pocket.worldPosition
end

local function newStats()
    return {goals=0, score=0, shots=0, shotsOnGoal=0, saves=0, passes=0,
        completions=0, groundBalls=0, faceoffs=0, checks=0, turnovers=0,
        pokes=0, slaps=0, bodyChecks=0, interceptions=0, forcedTurnovers=0, fouls=0}
end

function Match.recordStat(match, index, key, amount)
    local player = match.squad[index]
    if not player then return end
    local team = match.stats[player.team]
    local increment = amount or 1
    player.stats[key] = (player.stats[key] or 0) + increment
    team[key] = (team[key] or 0) + increment
end

local function matchRules(options)
    options = options or {}
    local ageGroup, bodyContact = P.Defense.configure(options)
    return {
        name = options.name or "Arcade testing",
        periods = math.floor(clamp(tonumber(options.periods) or 4, 1, 8)),
        periodLength = clamp(tonumber(options.periodLength) or 90, 1, 900),
        intermissionTime = clamp(tonumber(options.intermissionTime) or 2.4, .4, 12),
        goalTime = clamp(tonumber(options.goalTime) or 1.7, .6, 5),
        foulTime = clamp(tonumber(options.foulTime) or 1.05, .4, 5),
        ageGroup = ageGroup, bodyContact = bodyContact
    }
end

local function makeBall(scene)
    local ball = scene:entity()
    ball.model = craft.model.icosphere(ballRadius, 1, true)
    local materials = asset and asset.builtin and asset.builtin.Materials
    ball.material = craft.material(materials and materials.Standard or "Materials:Standard")
    ball.material.diffuse = color(255, 211, 66)
    return ball
end

local function makeMarker(scene)
    local marker = scene:entity()
    local cube = craft.model.cube()
    local materials = asset and asset.builtin and asset.builtin.Materials
    local tint = craft.material(materials and materials.Standard or "Materials:Standard")
    tint.diffuse = color(43, 166, 255)
    for side = 1, 14 do
        local angle = side * math.pi / 7
        local part = scene:entity()
        part.parent = marker
        part.model, part.material = cube, tint
        part.position = vec3(.68 * math.sin(angle), .025, .68 * math.cos(angle))
        part.scale = vec3(.31, .014, .045)
        part.eulerAngles = vec3(0, math.deg(angle), 0)
    end
    return marker
end

local function playerProfile(team, slot)
    return {
        FACE = (slot + team - 2) % 4 + 1, HAIR = (slot + team) % 5 + 1,
        BODY = slot == 10 and 3 or slot % 4 + 1, HELMET = 1, STICK = 4,
        NUMBER = slot + (team == 1 and 8 or 18), SHORTS = 4, CLEATS = 1
    }
end

local function place(player)
    player.rig.root.position = vec3(player.x, 0, player.z)
    player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
end

local function attach(match, index, select)
    local player = match.squad[index]
    match.carrier, match.lastTouch = index, player.team
    match.flight, match.loose, match.pending = nil, nil, nil
    match.scoopPlayer = nil
    match.ball.position = pocket(player)
    match.ballVelocity = vec3()
    if select and player.team == 1 then match.controlled = index end
    if match.mode == "SWING" then match.mode = "SET" end
end

local function freeBall(match, position, velocity, lastTouch)
    match.carrier, match.flight, match.pending, match.scoopPlayer = nil, nil, nil, nil
    match.loose, match.lastTouch = true, lastTouch
    match.ball.position, match.ballVelocity = position, velocity
    if match.mode == "SWING" then match.mode = "SET" end
end

local function startFaceoff(match)
    match.phase, match.phaseTime = "FACEOFF", 0
    match.mode, match.clearTime = "SET", 0
    match.pending, match.flight, match.loose, match.carrier = nil, nil, nil, nil
    match.scoopPlayer, match.lastTouch, match.inNet = nil, nil, nil
    match.foul = nil
    match.faceoff = {}
    match.controlled = userPlayer
    local reset = P.AnimationController.reset
    for _, player in ipairs(match.squad) do
        player.x, player.z = player.homeX, player.homeZ
        player.vx, player.vz, player.speed, player.turn = 0, 0, 0, 0
        player.dodge, player.check, player.checkCooldown = nil, nil, 0
        player.yaw = player.team == 1 and 0 or 180
        if player.role == "G" then player.yaw = (player.yaw + 180) % 360 end
        if player.slot == 4 then player.z = -.62 * directionFor(player.team) end
        place(player)
        reset(player.anim)
    end
    match.ball.position, match.ballVelocity = vec3(0, ballRadius, 0), vec3()
    for _, goal in ipairs(match.goalsByTeam) do P.GoalPhysics.reset(goal) end
    match.marker.position = match.squad[match.controlled].rig.root.position
    announce(match, "FACEOFF", .74)
end

local function resetMatch(match)
    match.homeScore, match.awayScore = 0, 0
    match.period, match.clock, match.elapsed = 1, match.rules.periodLength, 0
    match.stats = {newStats(), newStats()}
    for _, player in ipairs(match.squad) do player.stats = newStats() end
    match.ai = P.MatchAI.new()
    startFaceoff(match)
end

local function applyTeamKits(match, homeId, awayId)
    local homeKit, awayKit, homeTeam, awayTeam = P.TeamUniform.matchKits(homeId, awayId)
    match.homeTeam, match.awayTeam = homeTeam, awayTeam
    match.homeId, match.awayId = homeTeam.id, awayTeam.id
    match.kits = {homeKit, awayKit}
end

function Match.applyProfile(match, profile, homeId, awayId)
    applyTeamKits(match, homeId or match.homeId, awayId or match.awayId)
    for index, player in ipairs(match.squad) do
        local kit = match.kits[player.team]
        if index == userPlayer then
            P.Character.apply(player.rig, profile, nil, kit, false)
            player.number = player.rig.numberValue
        else
            P.Character.applyUniform(player.rig, kit, false)
        end
    end
end

function Match.new(scene, profile, homeId, awayId, rules)
    local field = P.Field.new(scene)
    local homeGoal = field.goals[1]
    local match = {
        field=field, goalsByTeam=field.goals, goal=vec3(homeGoal.x, homeGoal.top * .5, homeGoal.z),
        ball=makeBall(scene), marker=makeMarker(scene), squad={}, teams={{},{}}, keepers={}, rules=matchRules(rules)
    }
    P.MatchAI.registerAnimations()
    P.Defense.registerAnimations()
    applyTeamKits(match, homeId, awayId)
    for team = 1, 2 do
        local side = directionFor(team)
        for slot, spec in ipairs(formation) do
            local index = #match.squad + 1
            local rig = P.Character.new(scene)
            local appearance = index == userPlayer and profile or playerProfile(team, slot)
            P.Character.apply(rig, appearance, nil, match.kits[team], false)
            local player = {
                id=index, team=team, slot=slot, role=spec[1], name=spec[1]..spec[2],
                rig=rig, anim=P.AnimationController.new(rig), number=rig.numberValue,
                homeX=spec[3] * -side, homeZ=spec[4] * side,
                attributes=P.Defense.attributes(spec[1])
            }
            match.squad[index] = player
            match.teams[team][slot] = index
            if player.role == "G" then match.keepers[team] = index end
        end
    end
    resetMatch(match)
    return match
end

local function startPass(match, player, target, mode)
    local teammate = match.squad[target]
    if player.id ~= match.carrier or match.pending or not teammate
        or teammate.team ~= player.team or target == player.id then return end
    if P.AnimationController.play(player.anim, "pass") then
        match.pending = {kind="pass", from=player.id, to=target}
        match.mode = mode or "SET"
    end
end

local function startShot(match, player, aim)
    if player.id == match.carrier and not match.pending
        and P.AnimationController.play(player.anim, "shoot") then
        match.pending = {kind="shot", from=player.id, aim=aim}
    end
end

local function startDodge(player, moveX, moveZ)
    if not P.AnimationController.play(player.anim, "dodge") then return end
    local x, z = moveX or 0, -(moveZ or 0)
    local length = distance(x, z)
    if length < .12 then
        local yaw = math.rad(player.yaw)
        x, z, length = math.cos(yaw), -math.sin(yaw), 1
    end
    player.dodge = {x=x / length, z=z / length, time=.29}
end

local function startCheck(match, player, style)
    if player.check then return end
    player.check = P.Defense.request(match, player, style)
end

local function startScoop(match, player)
    if match.scoopPlayer or not match.loose then return end
    local ball = match.ball.position
    if ball.y <= .28 and distance(ball.x - player.x, ball.z - player.z) <= 1.12
        and distance(match.ballVelocity.x, match.ballVelocity.z) <= 4
        and P.AnimationController.play(player.anim, "scoop") then
        match.scoopPlayer = player.id
    end
end

function Match.canAim(match)
    return match.phase == "LIVE" and match.carrier == match.controlled
        and not match.pending and not match.squad[match.controlled].anim.action
end

function Match.aimContext(match)
    if not Match.canAim(match) then return nil end
    return pocket(match.squad[match.controlled]), match.goalsByTeam[1]
end

local function nextPlayer(match)
    local selected, closest = match.controlled, math.huge
    local ball = match.ball.position
    local holder = match.carrier and match.squad[match.carrier]
    if holder and holder.team == 1 and holder.id ~= selected then return holder.id end
    for _, index in ipairs(match.teams[1]) do
        local player = match.squad[index]
        if index ~= match.controlled then
            local length = distance(player.x - ball.x, player.z - ball.z)
            if length < closest then selected, closest = index, length end
        end
    end
    return selected
end

function Match.command(match, action, moveX, moveZ, aim)
    if action == "reset" then
        resetMatch(match)
        return
    end
    if match.phase == "FACEOFF" then
        if (action == "faceoff" or action == "pass" or action == "shoot")
            and not match.faceoff.winner then
            local time = match.phaseTime
            match.faceoff.winner = time >= .74 and time <= 1.18 and 1 or 2
            if time < .74 then announce(match, "EARLY CLAMP") end
        end
        return
    end
    if match.phase ~= "LIVE" then return end

    local player = match.squad[match.controlled]
    local holder = match.carrier and match.squad[match.carrier]
    if action == "switch" then
        match.controlled = nextPlayer(match)
    elseif action == "clear" then
        match.mode, match.clearTime = "CLEAR", 4.5
        announce(match, "CLEAR THROUGH")
    elseif action == "dodge" then
        if holder and holder.team ~= 1 then startCheck(match, player, "poke")
        else startDodge(player, moveX, moveZ) end
    elseif action == "check" or P.Defense.checks[action] then
        startCheck(match, player, action)
    elseif action == "scoop" then
        startScoop(match, player)
    elseif action == "shoot" then
        if holder == player then startShot(match, player, aim) end
    elseif action == "pass" or action == "swing" then
        if not holder or holder.team ~= 1 then return end
        local target
        if player.id ~= holder.id then target = player.id
        else target = P.MatchAI.passTarget(match, holder.id, action == "swing") end
        startPass(match, holder, target, action == "swing" and "SWING" or "SET")
    end
end

local function drive(match, player, vx, vz, dt)
    local dodge = player.dodge
    local acceleration = 24
    if dodge then
        local burst = 8.6 + 3.1 * dodge.time / .29
        vx, vz, acceleration = dodge.x * burst, dodge.z * burst, 52
        dodge.time = dodge.time - dt
        if dodge.time <= 0 then player.dodge = nil end
    end
    local dx, dz = vx - player.vx, vz - player.vz
    local speedup = math.min(1, acceleration * dt / math.max(distance(dx, dz), .001))
    local x, z = player.x, player.z
    local field = match.field
    local targetX = clamp(x + (player.vx + dx * speedup) * dt, -.987 * field.halfWidth, .987 * field.halfWidth)
    local targetZ = clamp(z + (player.vz + dz * speedup) * dt, -.991 * field.halfLength, .991 * field.halfLength)
    -- Keep the defenseless crease free of attacking players.
    if player.role ~= "G" then
        local goal = match.goalsByTeam[player.team]
        local gx, gz = targetX - goal.x, targetZ - goal.z
        local length = distance(gx, gz)
        local crease = field.creaseRadius + .18
        if length < crease then
            if length < .01 then gx, gz, length = 1, 0, 1 end
            targetX, targetZ = goal.x + crease * gx / length, goal.z + crease * gz / length
        end
    end
    player.x, player.z = targetX, targetZ
    player.vx, player.vz = (targetX - x) / dt, (targetZ - z) / dt
    player.speed = distance(player.vx, player.vz)
end

local function movePlayers(match, dt, moveX, moveZ, intents)
    local goal = match.goalsByTeam
    for _, player in ipairs(match.squad) do
        local intent = intents[player.id]
        local vx, vz = 0, 0
        if player.id == match.controlled then
            local rate = match.sprinting and 1.18 or 1
            vx, vz = moveX * 8.8 * rate, -moveZ * 8.8 * rate
        elseif intent and intent.x and intent.z then
            local dx, dz = intent.x - player.x, intent.z - player.z
            local length = distance(dx, dz)
            if length > .07 then
                local speed = math.min(length * 3.2, intent.speed or (player.role == "G" and 4.8 or 7.2))
                vx, vz = speed * dx / length, speed * dz / length
            end
        end
        drive(match, player, vx, vz, dt)
    end

    local ball = match.ball.position
    local flight = match.flight
    for _, player in ipairs(match.squad) do
        local lookX, lookZ = player.vx, player.vz
        local intent = intents[player.id]
        local pending = match.pending
        if pending and pending.from == player.id then
            local target = pending.to and match.squad[pending.to] or goal[player.team]
            lookX, lookZ = target.x - player.x, target.z - player.z
        elseif match.scoopPlayer == player.id or
            flight and (flight.to == player.id and flight.catchStarted or
                flight.interceptor and flight.interceptor.id == player.id) then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        elseif player.check then
            local target = match.squad[player.check.target]
            lookX, lookZ = target.x - player.x, target.z - player.z
        elseif intent and intent.lookX and intent.lookZ then
            lookX, lookZ = intent.lookX - player.x, intent.lookZ - player.z
        elseif player.speed < .21 then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        end
        local rotate = 0
        if distance(lookX, lookZ) > .04 then
            local angle = (yawFor(lookX, lookZ) - player.yaw + 180) % 360 - 180
            rotate = clamp(angle, -530 * dt, 530 * dt)
        end
        player.yaw, player.turn = (player.yaw + rotate) % 360, rotate / (530 * dt)
        player.checkCooldown = math.max(0, player.checkCooldown - dt)
        place(player)
    end
end

local function aimPoint(match, shot, player)
    local goal = match.goalsByTeam[player.team]
    local aim = shot.aim
    if aim and type(aim) ~= "number" and aim.x and aim.y then
        return clamp(aim.x, goal.x - 2.6, goal.x + 2.6), clamp(aim.y, .02, goal.top + 1.6)
    end
    local keeper = match.squad[match.keepers[3 - player.team]]
    local x = goal.x + (keeper.x <= goal.x and .57 or -.57)
    if type(aim) == "number" then x = goal.x + clamp(aim,-1,1) * .72 end
    return x, goal.top * .64
end

local function release(match, pending)
    local player = match.squad[pending.from]
    local origin = pocket(player)
    local flight = {kind=pending.kind, from=pending.from, team=player.team, origin=origin, time=0}
    if flight.kind == "pass" then
        local target = match.squad[pending.to]
        local length = distance(target.x - player.x, target.z - player.z)
        flight.to = target.id
        flight.duration = clamp(length / 23, .35, 2.4)
        flight.arc = clamp(length * .060, .18, 1.25)
        Match.recordStat(match, player.id, "passes")
        match.ballVelocity = (pocket(target) - origin) / flight.duration
    else
        local goal = match.goalsByTeam[player.team]
        local x, y = aimPoint(match, pending, player)
        local span = math.sqrt((x - origin.x)^2 + (goal.z - origin.z)^2)
        local time = clamp(span / 32, .11, 2.1)
        flight.duration = time + .29
        flight.velocity = vec3((x - origin.x) / time, (y - origin.y) / time + .5 * gravity * time,
            (goal.z - origin.z) / time)
        flight.goal = goal
        flight.onTarget = math.abs(x - goal.x) < goal.halfWidth - ballRadius
            and y >= ballRadius and y < goal.top - ballRadius
        Match.recordStat(match, player.id, "shots")
        match.ballVelocity = flight.velocity
    end
    match.lastTouch, match.carrier = player.team, nil
    match.pending, match.flight = nil, flight
    match.ball.position = origin
end

local function planCatch(match, dt)
    local flight = match.flight
    if not flight or not flight.to or flight.catchStarted then return end
    local connect = P.AnimationController.clips.catch.eventTime
    local remaining = flight.duration - flight.time
    if remaining <= connect + dt then
        flight.catchStarted = P.AnimationController.play(match.squad[flight.to].anim,
            "catch", connect / math.max(dt, remaining))
    end
end

local function completeCheck(match, player)
    local request = player.check
    player.check = nil
    local result, position, velocity = P.Defense.contact(match, player, request)
    local target = match.squad[request.target]
    if result == "loose" then
        freeBall(match, position, velocity, player.team)
        Match.recordStat(match, player.id, "checks")
        Match.recordStat(match, player.id, P.Defense.checks[request.style].stat)
        Match.recordStat(match, player.id, "forcedTurnovers")
        Match.recordStat(match, target.id, "turnovers")
        announce(match, P.Defense.checks[request.style].name .. " · BALL LOOSE")
    elseif result == "foul" then
        local oldHolder = match.carrier
        if oldHolder and match.squad[oldHolder].team == player.team then
            Match.recordStat(match, oldHolder, "turnovers")
        end
        Match.recordStat(match, player.id, "fouls")
        match.pending, match.flight, match.loose, match.scoopPlayer = nil, nil, nil, nil
        local recipient = oldHolder and match.squad[oldHolder].team == target.team and oldHolder or target.id
        match.foul = {recipient=recipient, oldHolder=oldHolder}
        match.phase, match.phaseTime = "FOUL", 0
        match.ballVelocity = vec3()
        announce(match, "ILLEGAL BODY CHECK", match.rules.foulTime)
    end
end

local function act(match, intents)
    for index, intent in pairs(intents) do
        if index ~= match.controlled then
            local player = match.squad[index]
            local action = intent.action
            if action == "pass" then startPass(match, player, intent.target)
            elseif action == "shoot" then startShot(match, player, intent.aim)
            elseif action == "dodge" then startDodge(player, intent.moveX, intent.moveZ)
            elseif action == "check" or P.Defense.checks[action] then
                startCheck(match, player, action)
            elseif action == "scoop" then startScoop(match, player)
            elseif action == "save" and intent.style then
                P.AnimationController.play(player.anim, intent.style)
            end
        end
    end
end

local function trySave(match, flight, previous, position, velocity, hit)
    local goal = flight.goal
    local id = match.keepers[3 - flight.team]
    local keeper = match.squad[id]
    local range = (goal.z - keeper.z) * goal.attackSign
    if range < .08 or range > match.field.creaseRadius + .6
        or (position.z - previous.z) * goal.attackSign <= 0 then return false end
    local save = P.MatchAI.sweepKeeper(match, id, previous, position, velocity)
    if not save or hit and hit.time < save.t then return false end
    if flight.onTarget then
        Match.recordStat(match, keeper.id, "saves")
        Match.recordStat(match, flight.from, "shotsOnGoal")
    end
    if save.style then P.AnimationController.play(keeper.anim, save.style) end
    if save.caught then
        attach(match, keeper.id, false)
        announce(match, flight.onTarget and "SAVE" or "SHOT BLOCKED")
    else
        freeBall(match, save.position, save.velocity, keeper.team)
        announce(match, flight.onTarget and "SAVE · REBOUND" or "SHOT BLOCKED")
    end
    return true
end

local function score(match, flight, hit)
    local team = flight.team
    Match.recordStat(match, flight.from, "goals")
    Match.recordStat(match, flight.from, "shotsOnGoal")
    Match.recordStat(match, flight.from, "score")
    match.homeScore, match.awayScore = match.stats[1].goals, match.stats[2].goals
    match.flight, match.loose, match.carrier = nil, nil, nil
    local fixed = P.GoalPhysics.capture(flight.goal, hit.position)
    match.inNet = {state="IN_NET", position=fixed}
    match.ball.position = fixed
    match.ballVelocity = vec3()
    match.phase, match.phaseTime = "GOAL", 0
    local scorer = team == 1 and match.homeTeam or match.awayTeam
    announce(match, scorer.name .. " GOAL", match.rules.goalTime)
end

local function updateFlight(match, dt, catchIndex)
    local flight = match.flight
    flight.time = math.min(flight.time + dt, flight.duration)
    local previous = match.ball.position
    if flight.kind == "pass" then
        local progress = flight.time / flight.duration
        local position = P.Defense.passPoint(match, flight, flight.time)
        match.ball.position, match.ballVelocity = position, (position - previous) / dt
        local intercepted = P.Defense.intercept(match, flight, previous, position)
        if intercepted then
            attach(match, intercepted, true)
            Match.recordStat(match, intercepted, "interceptions")
            Match.recordStat(match, intercepted, "forcedTurnovers")
            Match.recordStat(match, flight.from, "turnovers")
            announce(match, "INTERCEPTION")
        elseif catchIndex == flight.to then
            attach(match, flight.to, match.controlled == flight.from)
            Match.recordStat(match, flight.from, "completions")
        elseif progress >= 1 then
            freeBall(match, position, vec3(0, -.6, 0), flight.team)
            announce(match, "PASS DROPPED")
        end
        return
    end

    local time = flight.time
    local position = flight.origin + flight.velocity * time - vec3(0, .5 * gravity * time^2, 0)
    local velocity = flight.velocity - vec3(0, gravity * time, 0)
    local goal = flight.goal
    local hit = P.GoalPhysics.step(goal, previous, position, velocity)
    if trySave(match, flight, previous, position, velocity, hit) then return end
    if hit then
        if hit.kind == "GOAL" and (flight.origin.z - goal.z) * goal.attackSign <= 0 then
            score(match, flight, hit)
            return
        elseif hit.kind == "POST" or hit.kind == "CROSSBAR" then
            freeBall(match, hit.position, hit.velocity, flight.team)
            announce(match, hit.kind == "POST" and "OFF THE POST" or "OFF THE BAR")
            return
        elseif hit.kind == "WIDE" or hit.kind == "HIGH" or hit.kind == "LOW" then
            announce(match, hit.kind)
        end
    end

    if position.y <= ballRadius or time >= flight.duration then
        position.y = math.max(ballRadius, position.y)
        freeBall(match, position, velocity * .36, flight.team)
    else
        match.ball.position, match.ballVelocity = position, velocity
    end
end

local function outOfBounds(match, position)
    local field = match.field
    local team = 3 - (match.lastTouch or 2)
    local selected, best = nil, math.huge
    local x = clamp(position.x, -field.halfWidth + .9, field.halfWidth - .9)
    local z = clamp(position.z, -field.halfLength + .9, field.halfLength - .9)
    for _, index in ipairs(match.teams[team]) do
        local player = match.squad[index]
        if player.role ~= "G" then
            local length = distance(player.x - x, player.z - z)
            if length < best then selected, best = player, length end
        end
    end
    selected.x, selected.z, selected.vx, selected.vz = x, z, 0, 0
    place(selected)
    P.AnimationController.reset(selected.anim)
    attach(match, selected.id, true)
    announce(match, "OUT OF BOUNDS")
end

local function updateLoose(match, dt, scoopIndex)
    local previous, velocity = match.ball.position, match.ballVelocity
    local position = previous + velocity * dt
    velocity.y = velocity.y - gravity * dt
    if position.y <= ballRadius then
        position.y = ballRadius
        velocity.y = math.abs(velocity.y) > 1.05 and math.abs(velocity.y) * .29 or 0
        local drag = math.max(0, 1 - dt * 2.7)
        velocity.x, velocity.z = velocity.x * drag, velocity.z * drag
    end
    match.ball.position, match.ballVelocity = position, velocity
    if scoopIndex and scoopIndex == match.scoopPlayer then
        local player = match.squad[scoopIndex]
        local contact = pocket(player)
        match.scoopPlayer = nil
        if position.y <= .34 and contact.y <= .75
            and distance(position.x - contact.x, position.z - contact.z) <= .79 then
            attach(match, scoopIndex, match.controlled == scoopIndex)
            Match.recordStat(match, player.id, "groundBalls")
            announce(match, "GROUND BALL")
        end
    end
end

local function settlePossession(match, dt, flight, loose, catchIndex, scoopIndex)
    if flight and match.flight == flight then
        updateFlight(match, dt, catchIndex)
    elseif loose and match.loose then
        updateLoose(match, dt, scoopIndex)
    elseif match.carrier then
        local position = pocket(match.squad[match.carrier])
        match.ballVelocity = (position - match.ball.position) / dt
        match.ball.position = position
    end
    if match.phase ~= "LIVE" then return end
    local position = match.ball.position
    if not match.carrier and (math.abs(position.x) > match.field.halfWidth
        or math.abs(position.z) > match.field.halfLength) then
        outOfBounds(match, position)
    end
end

local function finishPeriod(match)
    match.phaseTime = 0
    if match.period >= match.rules.periods then
        match.phase = "FINAL"
        local winner = match.homeScore > match.awayScore and match.homeTeam
            or match.awayScore > match.homeScore and match.awayTeam
        announce(match, winner and winner.name .. " WIN" or "DRAW", 3)
    else
        match.phase = "INTERMISSION"
        announce(match, "END OF PERIOD " .. match.period, match.rules.intermissionTime)
    end
end

local function faceoff(match, dt)
    local contest = match.faceoff
    match.phaseTime = match.phaseTime + dt
    if not contest.signaled and match.phaseTime >= .74 and not contest.winner then
        contest.signaled = true
        announce(match, "CLAMP NOW", .45)
    end
    if not contest.winner and match.phaseTime >= 1.18 then contest.winner = 2 end
    local update, play = P.AnimationController.update, P.AnimationController.play
    local first, second = match.squad[userPlayer], match.squad[match.teams[2][4]]
    if contest.winner and not contest.started then
        contest.started = match.phaseTime
        play(first.anim, "scoop")
        play(second.anim, "scoop")
    end
    local firstEvent = update(first.anim, dt, {scoopPoint=match.ball.position})
    local secondEvent = update(second.anim, dt, {scoopPoint=match.ball.position})
    local event = secondEvent
    if contest.winner == 1 then event = firstEvent end
    if contest.started and (event == "scoop" or match.phaseTime - contest.started > .65) then
        local team = contest.winner
        local winner = team == 1 and first or second
        attach(match, winner.id, true)
        match.phase, match.phaseTime = "LIVE", 0
        Match.recordStat(match, winner.id, "faceoffs")
        announce(match, (team == 1 and match.homeTeam.short or match.awayTeam.short) .. " FACEOFF WIN")
    end
end

local function live(match, dt, moveX, moveZ)
    local length = math.max(distance(moveX, moveZ), 1)
    moveX, moveZ = moveX / length, moveZ / length
    match.moveX, match.moveZ = moveX, moveZ
    if match.clearTime > 0 then
        match.clearTime = math.max(0, match.clearTime - dt)
        if match.clearTime == 0 and match.mode == "CLEAR" then match.mode = "SET" end
    end
    local intents = P.MatchAI.update(match, dt)
    act(match, intents)
    planCatch(match, dt)
    if match.flight then P.Defense.prepareIntercept(match, match.flight) end
    if match.loose then startScoop(match, match.squad[match.controlled]) end
    movePlayers(match, dt, moveX, moveZ, intents)
    local animation = P.AnimationController
    local flight, loose = match.flight, match.loose
    local catchIndex, scoopIndex
    for index, player in ipairs(match.squad) do
        local event = animation.update(player.anim, dt, {
            speed=player.speed, turn=player.turn, possessed=match.carrier==index,
            scoopPoint=match.scoopPlayer==index and match.ball.position or nil
        })
        if player.check then
            if event == "check" then completeCheck(match, player)
            elseif player.anim.action ~= player.check.clip then player.check = nil end
        end
        if match.phase ~= "LIVE" then return end
        if event == "release" and match.pending and match.pending.from == index then
            release(match, match.pending)
        elseif event == "catch" then
            catchIndex = index
        elseif event == "scoop" then
            scoopIndex = index
        end
    end
    if match.scoopPlayer and not match.squad[match.scoopPlayer].anim.action and not scoopIndex then
        match.scoopPlayer = nil
    end
    settlePossession(match, dt, flight, loose, catchIndex, scoopIndex)
    match.marker.position = match.squad[match.controlled].rig.root.position
end

function Match.update(match, dt, moveX, moveZ)
    if dt <= 0 then return end
    match.announcementTime = math.max(0, match.announcementTime - dt)
    for _, goal in ipairs(match.goalsByTeam) do P.GoalPhysics.update(goal, dt) end
    if match.phase == "FACEOFF" then
        faceoff(match, dt)
    elseif match.phase == "LIVE" then
        local liveTime = math.min(dt, match.clock)
        match.clock = math.max(0, match.clock - liveTime)
        match.elapsed = match.elapsed + liveTime
        if liveTime > 0 then live(match, liveTime, moveX or 0, moveZ or 0) end
        if match.clock <= 0 and match.phase == "LIVE" then finishPeriod(match) end
    elseif match.phase == "FOUL" then
        match.phaseTime = match.phaseTime + dt
        if match.phaseTime >= match.rules.foulTime then
            local foul, animation = match.foul, P.AnimationController
            match.foul = nil
            if foul.oldHolder and foul.oldHolder ~= foul.recipient then
                animation.reset(match.squad[foul.oldHolder].anim)
            end
            animation.reset(match.squad[foul.recipient].anim)
            attach(match, foul.recipient, true)
            match.phase, match.phaseTime = "LIVE", 0
            if match.clock <= 0 then finishPeriod(match)
            else announce(match, "POSSESSION AWARDED") end
        end
    elseif match.phase == "INTERMISSION" or match.phase == "GOAL" then
        match.phaseTime = match.phaseTime + dt
        if match.phase == "GOAL" and match.phaseTime >= match.rules.goalTime then
            if match.clock <= 0 then finishPeriod(match)
            else startFaceoff(match) end
        elseif match.phase == "INTERMISSION" and match.phaseTime >= match.rules.intermissionTime then
            match.period, match.clock = match.period + 1, match.rules.periodLength
            startFaceoff(match)
        end
    end
end
