-- PolyLax Build 013 | FullMatch
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
        pokes=0, slaps=0, bodyChecks=0, interceptions=0, forcedTurnovers=0, fouls=0,
        faceoffAttempts=0, faceoffViolations=0, faceoffScrambles=0}
end

function Match.recordStat(match, index, key, amount, detail)
    local player = match.squad[index]
    if not player then return end
    local team = match.stats[player.team]
    local increment = amount or 1
    if not (match.careerWaiting and index == match.careerPlayer) then
        player.stats[key] = (player.stats[key] or 0) + increment
    end
    team[key] = (team[key] or 0) + increment
    -- These outcomes use possession/keeper classification at their sources.
    if key ~= "turnovers" and key ~= "forcedTurnovers" and key ~= "saves" then
        P.Statistics.record(match,index,key,increment,detail)
    end
end

local screenEvaluation = {screens=2, screenAssists=3, screenOpenShots=2, illegalScreens=-4}

local function screenStat(match, index, key, detail)
    Match.recordStat(match,index,key,1,detail)
    local points = screenEvaluation[key]
    if not points then return end
    Match.recordStat(match,index,"screenCoachPoints",points)
    if match.careerWaiting and index==match.careerPlayer then return end
    local events = match.squad[index].screenCoachEvents
    events[#events+1] = {kind=key,points=points,time=match.elapsed,
        user=detail and detail.user,defender=detail and detail.defender}
end

local screenFoul

local function matchRules(options)
    options = options or {}
    local ageGroup, bodyContact = P.Defense.configure(options)
    local faceoffOptions = type(options.faceoff) == "table" and options.faceoff or {}
    return {
        name = options.name or "Arcade testing",
        periods = math.floor(clamp(tonumber(options.periods) or 4, 1, 8)),
        periodLength = clamp(tonumber(options.periodLength) or 90, 1, 900),
        intermissionTime = clamp(tonumber(options.intermissionTime) or 2.4, .4, 12),
        goalTime = clamp(tonumber(options.goalTime) or 1.7, .6, 5),
        foulTime = clamp(tonumber(options.foulTime) or 1.05, .4, 5),
        ageGroup = ageGroup, bodyContact = bodyContact,
        faceoff = {
            difficulty = faceoffOptions.difficulty or options.faceoffDifficulty,
            setTime = faceoffOptions.setTime, duration = faceoffOptions.duration,
            exitTime = faceoffOptions.exitTime
        }
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

local function careerLock(match)
    local id = match.playerId or match.careerPlayer
    if type(id) == "table" then id = id.id end
    if type(id) == "number" and match.squad[id] then return id end
end

local function attach(match, index, select)
    local player = match.squad[index]
    P.Statistics.possession(match,index)
    local draw = match.faceoffScramble
    if draw then
        local contestant = player.team == 1 and draw.homeId or draw.awayId
        Match.recordStat(match, contestant, "faceoffs")
        match.faceoffScramble = nil
    end
    match.carrier, match.lastTouch, match.assist = index, player.team, nil
    match.flight, match.loose, match.pending = nil, nil, nil
    match.scoopPlayer = nil
    match.ball.position = pocket(player)
    match.ballVelocity = vec3()
    if select and player.team == 1 and not careerLock(match) then match.controlled = index end
    if match.mode == "SWING" then match.mode = "SET" end
end

local function freeBall(match, position, velocity, lastTouch)
    match.carrier, match.flight, match.pending, match.scoopPlayer = nil, nil, nil, nil
    match.loose, match.lastTouch, match.assist = true, lastTouch, nil
    match.ball.position, match.ballVelocity = position, velocity
    if match.mode == "SWING" then match.mode = "SET" end
end

local function startFaceoff(match)
    P.Statistics.resetPossession(match)
    local afterPeriod = match.phase == "INTERMISSION"
    P.Screens.reset(match)
    match.tactical, match.cut, match.swingDirection = nil, nil, nil
    match.assist = nil
    match.phase, match.phaseTime = "FACEOFF", 0
    match.mode, match.clearTime = "SET", 0
    match.pending, match.flight, match.loose, match.carrier = nil, nil, nil, nil
    match.scoopPlayer, match.lastTouch, match.inNet = nil, nil, nil
    match.foul = nil
    match.faceoffScramble = nil
    local first = match.squad[match.teams[1][4]]
    local second = match.squad[match.teams[2][4]]
    local locked = careerLock(match)
    match.controlled = locked or first.id
    match.faceoffSerial = match.faceoffSerial + 1
    if afterPeriod then
        first.faceoffFatigue = math.max(0, first.faceoffFatigue - .15)
        second.faceoffFatigue = math.max(0, second.faceoffFatigue - .15)
    end
    match.faceoff = P.Faceoff.new(match.rules.faceoff, first, second, match.faceoffSerial,
        (not locked or locked == first.id and not match.careerWaiting) and 1 or false)
    local reset = P.AnimationController.reset
    for _, player in ipairs(match.squad) do
        player.x, player.z = player.homeX, player.homeZ
        player.vx, player.vz, player.speed, player.turn = 0, 0, 0, 0
        player.dodge, player.check, player.checkCooldown = nil, nil, 0
        player.faceoffExit = nil
        player.yaw = player.team == 1 and 0 or 180
        if player.role == "G" then player.yaw = (player.yaw + 180) % 360 end
        if player.slot == 4 then player.z = -.62 * directionFor(player.team) end
        place(player)
        reset(player.anim)
    end
    P.Midfield.reset(match)
    match.ball.position, match.ballVelocity = vec3(0, ballRadius, 0), vec3()
    for _, goal in ipairs(match.goalsByTeam) do P.GoalPhysics.reset(goal) end
    match.marker.position = match.squad[match.controlled].rig.root.position
    announce(match, "FACEOFF", match.faceoff.setTime)
end

local function resetMatch(match)
    match.homeScore, match.awayScore = 0, 0
    match.lastGoalScorer,match.lastGoalTeam=nil,nil
    match.period, match.clock, match.elapsed = 1, match.rules.periodLength, 0
    match.stats = {newStats(), newStats()}
    match.faceoffSerial = 0
    match.careerWaiting = match.careerEntryDelay and match.careerEntryDelay > 0
    for _, player in ipairs(match.squad) do
        player.stats, player.screenCoachEvents = newStats(), {}
        player.runningFatigue = 0
        player.faceoffFatigue = 0
    end
    match.ai = P.MatchAI.new()
    P.Statistics.new(match,match.statisticsOptions)
    startFaceoff(match)
end

local function applyTeamKits(match, homeId, awayId)
    local homeKit, awayKit, homeTeam, awayTeam
    if match.venueAway then
        awayKit, homeKit, awayTeam, homeTeam = P.TeamUniform.matchKits(awayId, homeId)
    else
        homeKit, awayKit, homeTeam, awayTeam = P.TeamUniform.matchKits(homeId, awayId)
    end
    match.homeTeam, match.awayTeam = homeTeam, awayTeam
    match.homeId, match.awayId = homeTeam.id, awayTeam.id
    match.kits = {homeKit, awayKit}
end

function Match.applyProfile(match, profile, homeId, awayId)
    applyTeamKits(match, homeId or match.homeId, awayId or match.awayId)
    for index, player in ipairs(match.squad) do
        local kit = match.kits[player.team]
        if index == (match.careerPlayer or userPlayer) then
            P.Character.apply(player.rig, profile, nil, kit, false)
            player.number = player.rig.numberValue
        else
            P.Character.applyUniform(player.rig, kit, false)
        end
    end
end

function Match.new(scene, profile, homeId, awayId, rules)
    rules = rules or {}
    local venue = P.TeamUniform.get(rules.fieldTeam or homeId)
    local field = P.Field.new(scene, venue.field, rules.fieldMetrics)
    local homeGoal = field.goals[1]
    local match = {
        field=field, venueAway=rules.venueAway == true, goalsByTeam=field.goals, goal=vec3(homeGoal.x, homeGoal.top * .5, homeGoal.z),
        ball=makeBall(scene), marker=makeMarker(scene), squad={}, teams={{},{}}, keepers={}, rules=matchRules(rules)
    }
    match.statisticsOptions = rules.statistics
    match.movementProposals = {}
    local slot = rules and tonumber(rules.careerPlayerSlot)
    if slot then
        match.careerPlayer = clamp(math.floor(slot), 1, 10)
        match.careerEntryDelay = clamp(tonumber(rules.careerEntryDelay) or 0, 0,
            math.min(10,match.rules.periodLength*.3))
    end
    P.MatchAI.registerAnimations()
    P.Defense.registerAnimations()
    P.Screens.registerAnimations()
    P.Faceoff.registerAnimations(P.AnimationController)
    applyTeamKits(match, homeId, awayId)
    for team = 1, 2 do
        local side = directionFor(team)
        local roster=P.League and P.League.roster(team==1 and match.homeId or match.awayId)
        for slot, spec in ipairs(formation) do
            local index = #match.squad + 1
            local rig = P.Character.new(scene)
            local custom = index==(match.careerPlayer or userPlayer)
            local appearance = custom and profile or playerProfile(team,slot)
            local member = roster and roster[slot]
            if member and not custom then appearance.NUMBER=member.number+1 end
            P.Character.apply(rig, appearance, nil, match.kits[team], false)
            local player = {
                id=index, team=team, slot=slot, role=spec[1],
                name=member and not custom and member.name or spec[1]..spec[2],
                rig=rig, anim=P.AnimationController.new(rig), number=rig.numberValue,
                homeX=spec[3] * -side, homeZ=spec[4] * side,
                attributes=P.Defense.attributes(spec[1])
            }
            if slot == 4 then player.attributes.faceoff = .68 end
            if index == match.careerPlayer then
                player.name = rules.playerName or player.name
                for key, value in pairs(rules.playerAttributes or {}) do
                    if type(value) == "number" then player.attributes[key] = value end
                end
            end
            match.squad[index] = player
            match.movementProposals[index] = {}
            match.teams[team][slot] = index
            if player.role == "G" then match.keepers[team] = index end
        end
    end
    match.screenStat = function(id,key,detail) screenStat(match,id,key,detail) end
    match.screenCallbacks = {stat=match.screenStat,
        foul=function(id,defender) screenFoul(match,id,defender) end}
    resetMatch(match)
    return match
end

local function startPass(match, player, plan, mode)
    if type(plan) == "number" then plan = P.Passing.forTarget(match,plan) end
    if player.id ~= match.carrier or match.pending or not plan or not plan.point then return false end
    if plan.from and plan.from ~= player.id then return false end
    if plan.to then
        local teammate = match.squad[plan.to]
        if not teammate or teammate == player or teammate.team ~= player.team then return false end
    end
    if not P.AnimationController.play(player.anim,"pass") then return false end
    match.pending = {kind="pass",from=player.id,to=plan.to,point=plan.point,play=mode}
    match.mode = mode or "SET"
    return true
end

local function startShot(match, player, aim)
    if player.id == match.carrier and not match.pending
        and P.AnimationController.play(player.anim, "shoot") then
        match.pending = {kind="shot", from=player.id, aim=aim}
    end
end

local function startDodge(player, moveX, moveZ)
    local agility = P.Attributes.rating(player,"agility",60)-60
    if not P.AnimationController.play(player.anim, "dodge", 1+agility*.004) then return end
    local x, z = moveX or 0, -(moveZ or 0)
    local length = distance(x, z)
    if length < .12 then
        local yaw = math.rad(player.yaw)
        x, z, length = math.cos(yaw), -math.sin(yaw), 1
    end
    player.dodge = {x=x / length, z=z / length, time=.29, agility=agility}
end

local function startCheck(match, player, style)
    if player.check then return end
    player.check = P.Defense.request(match, player, style)
end

local function startScoop(match, player)
    if match.scoopPlayer or not match.loose then return end
    local ball = match.ball.position
    local ground = P.Attributes.rating(player,"groundBalls",65)-65
    if ball.y <= .28 and distance(ball.x - player.x, ball.z - player.z) <= 1.12+ground*.005
        and distance(match.ballVelocity.x, match.ballVelocity.z) <= 4
        and P.AnimationController.play(player.anim, "scoop", 1+ground*.0038) then
        match.scoopPlayer = player.id
    end
end

function Match.canAim(match)
    return not match.careerWaiting and match.phase == "LIVE" and match.carrier == match.controlled
        and not match.pending and not match.squad[match.controlled].anim.action
end

function Match.aimContext(match)
    if not Match.canAim(match) then return nil end
    return pocket(match.squad[match.controlled]), match.goalsByTeam[1]
end

function Match.passPreview(match, dx, dz)
    if Match.canAim(match) then return P.Passing.select(match,match.carrier,dx,dz) end
end

local calls = {swing="SWING",clear="CLEAR",passdown="PASS DOWN",pickdown="PICK DOWN"}

local function startPick(match, holder, screener)
    local defender = P.Tactics.defender(match,holder.id)
    if screener then
        if screener == holder or screener.role == "G" then return false end
        local mark = defender and match.squad[defender]
        if not mark or distance(mark.x-screener.x,mark.z-screener.z) > 3.4 then
            announce(match,"MOVE NEAR A DEFENDER")
            return false
        end
        local screen = P.Screens.request(match,screener.id,holder.id,defender,
            {x=screener.x,z=screener.z,manual=true})
        if screen then announce(match,"SET YOUR FEET") end
        return screen ~= nil
    end

    local detail = P.Tactics.pick(match,holder.id,defender)
    if detail and P.Screens.request(match,detail.screener,holder.id,defender,detail) then
        P.Tactics.activate(match,detail,"PICK DOWN",holder.team)
        match.mode = "PICK DOWN"
        announce(match,"PICK DOWN")
        return true
    end
    announce(match,"NO SCREEN AVAILABLE")
    return false
end

local function callTactic(match, holder, call)
    if call == "PICK DOWN" then return startPick(match,holder) end
    if match.pending or match.flight then return false end
    local receiver, detail = P.Tactics.choose(match,holder.id,call)
    if receiver and startPass(match,holder,receiver,call) then
        P.Tactics.activate(match,detail,call,holder.team)
        announce(match,call)
        return true
    end
    if call == "CLEAR" then
        match.mode, match.clearTime = "CLEAR", 3.5
        P.Tactics.activate(match,{},"CLEAR",holder.team,3.5)
        announce(match,"CLEAR · OUTLETS COVERED")
    else
        announce(match,call .. " · LANE COVERED")
    end
    return false
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
    if match.careerWaiting then return end
    if match.phase == "FACEOFF" then
        if action == "pass" or action == "shoot" then action = "clamp" end
        if P.Faceoff.input(match.faceoff, action) and match.faceoff.phase == "SET" then
            announce(match, "FALSE START")
        end
        return
    end
    if match.phase ~= "LIVE" then return end

    local player = match.squad[match.controlled]
    local holder = match.carrier and match.squad[match.carrier]
    if action == "switch" then
        if not careerLock(match) then match.controlled = nextPlayer(match) end
    elseif calls[action] then
        if holder and holder.team==1 then return callTactic(match,holder,calls[action]) end
    elseif action == "setpick" then
        if holder and holder.team==1 then return startPick(match,holder,player) end
    elseif action == "releasepick" then
        return P.Screens.endHold(match,player.id,moveX or 0,-(moveZ or 0))
    elseif action == "dodge" then
        if holder and holder.team ~= 1 then startCheck(match, player, "poke")
        else startDodge(player, moveX, moveZ) end
    elseif action == "check" or P.Defense.checks[action] then
        startCheck(match, player, action)
    elseif action == "scoop" then
        startScoop(match, player)
    elseif action == "shoot" then
        if holder == player then startShot(match, player, aim) end
    elseif action == "pass" then
        if not holder or holder.team ~= 1 then return end
        if player ~= holder then
            if not aim then return startPass(match,holder,player.id) end
            return
        end
        local plan = aim or P.Passing.select(match,holder.id,moveX or 0,-(moveZ or 0))
        return startPass(match,holder,plan)
    end
end

local function proposeMovement(match, player, vx, vz, dt, proposal)
    local dodge = player.dodge
    local acceleration = 24+(P.Attributes.rating(player,"acceleration",60)-60)*.18
    local exit = player.faceoffExit
    if exit then
        exit.remaining = exit.remaining - dt
        local speed = 4.5 + 2 * math.max(0, exit.remaining) / .25
        vx, vz = exit.x * speed, exit.z * speed
        acceleration = 36
        if exit.remaining <= 0 then player.faceoffExit = nil end
    end
    if dodge then
        local burst = 8.6 + 3.1*dodge.time/.29 + (dodge.agility or 0)*.033
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
    proposal.x, proposal.z, proposal.intentZ = targetX, targetZ, vz
end

local function applyMovement(player, proposal, dt)
    player.vx, player.vz = (proposal.x - player.x) / dt, (proposal.z - player.z) / dt
    player.x, player.z = proposal.x, proposal.z
    player.speed = distance(player.vx, player.vz)
    P.Attributes.updateFatigue(player,dt)
    if player.slot == 4 then
        local effort = (player.speed - 4.2) * .005
        player.faceoffFatigue = clamp(player.faceoffFatigue + effort * dt, 0, .55)
    end
end

local function movePlayers(match, dt, moveX, moveZ, intents)
    local goal = match.goalsByTeam
    local cut = P.Tactics.activeCut(match)
    local movementIntents = {}
    local proposals = match.movementProposals
    local humanID = not match.careerWaiting and match.controlled
    local input = distance(moveX,moveZ)
    for _, player in ipairs(match.squad) do
        local intent = P.Screens.intent(match,player.id,intents[player.id] or {})
        movementIntents[player.id] = intent
        local human = player.id==humanID
        local tx,tz = intent.x,intent.z
        local receiveX,receiveZ = P.Passing.receiveTarget(match,player.id)
        if not intent.screenControl then
            if receiveX then
                tx,tz = receiveX,receiveZ
            elseif cut and cut.cutID==player.id and not match.pending then
                tx,tz = cut.cutX,cut.cutZ
            end
        end
        local guided = receiveX or (cut and cut.cutID==player.id and not match.pending)
        local vx,vz = 0,0
        if human and not intent.screenControl and (not guided or input>.12) then
            local rate = match.sprinting and 1.18 or 1
            local pace = P.Attributes.pace(player,8.8) * (intent.screenDrag or 1)
            vx,vz = moveX*pace*rate,-moveZ*pace*rate
        elseif tx and tz then
            local dx,dz = tx-player.x,tz-player.z
            local gap = distance(dx,dz)
            if gap > .045 then
                local limit = intent.speed or (player.role=="G" and 4.8 or 7.2)
                local speed = math.min(gap*3.7,limit > 0 and P.Attributes.pace(player,limit) or 0)
                vx,vz = speed*dx/gap,speed*dz/gap
            end
        end
        proposeMovement(match,player,vx,vz,dt,proposals[player.id])
    end

    -- Apply both teams' steps together so a legal midfield exchange does not
    -- depend on the order of players in the squad.
    P.Midfield.resolve(match, proposals, humanID, dt)
    for _, player in ipairs(match.squad) do
        applyMovement(player, proposals[player.id], dt)
    end

    local ball = match.ball.position
    local flight = match.flight
    for _, player in ipairs(match.squad) do
        local lookX, lookZ = player.vx, player.vz
        local intent = movementIntents[player.id]
        local pending = match.pending
        if pending and pending.from == player.id then
            local target = pending.to and match.squad[pending.to] or pending.point or goal[player.team]
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
        local turnRate = 530+(P.Attributes.rating(player,"agility",60)-60)*3.1
        if distance(lookX, lookZ) > .04 then
            local angle = (yawFor(lookX, lookZ) - player.yaw + 180) % 360 - 180
            rotate = clamp(angle, -turnRate*dt, turnRate*dt)
        end
        player.yaw, player.turn = (player.yaw + rotate) % 360, rotate / (turnRate*dt)
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
        local skill = player.role == "G" and P.Attributes.rating(player,"clearingAccuracy") or nil
        local velocity = 23+((skill or P.Attributes.rating(player,"passing",60))-60)*.12
        flight = P.Passing.launch(match,pending,{speed=velocity,minDuration=.35})
        Match.recordStat(match,player.id,"passes",1,{target=flight.to,call=pending.play})
        if player.role == "G" then
            flight.keeperOutlet = true
            P.Statistics.record(match,player.id,"clearsAttempted",1,{target=flight.to})
        end
        match.ballVelocity = flight.velocity
    else
        local goal = match.goalsByTeam[player.team]
        local x, y = aimPoint(match, pending, player)
        local span = math.sqrt((x - origin.x)^2 + (goal.z - origin.z)^2)
        local spreadX,spreadY = P.Attributes.shotSpread(match,player,span)
        x,y = x+spreadX,y+spreadY
        local velocity = 32+(P.Attributes.rating(player,"shotPower",60)-60)*.15
        local time = clamp(span / velocity, .11, 2.1)
        flight.duration = time + .29
        flight.velocity = vec3((x - origin.x) / time, (y - origin.y) / time + .5 * gravity * time,
            (goal.z - origin.z) / time)
        flight.goal = goal
        flight.onTarget = math.abs(x - goal.x) < goal.halfWidth - ballRadius
            and y >= ballRadius and y < goal.top - ballRadius
        Match.recordStat(match, player.id, "shots")
        P.Screens.creditShot(match,player.id,match.screenStat,flight)
        match.ballVelocity = flight.velocity
    end
    match.lastTouch, match.carrier = player.team, nil
    match.pending, match.flight = nil, flight
    match.ball.position = origin
end

screenFoul = function(match, screenerID, defenderID)
    if match.phase~="LIVE" then return end
    local holder = match.carrier
    if holder then
        Match.recordStat(match,holder,"turnovers")
        P.Statistics.turnover(match,holder,"illegalScreen")
    end
    Match.recordStat(match,screenerID,"fouls")
    P.Statistics.penalty(match,screenerID,"technical",0,{reason="illegalScreen",other=defenderID})
    match.pending,match.flight,match.loose,match.scoopPlayer = nil,nil,nil,nil
    match.assist,match.tactical,match.cut = nil,nil,nil
    match.mode = "SET"
    match.foul = {recipient=defenderID,oldHolder=holder}
    match.phase,match.phaseTime = "FOUL",0
    match.ballVelocity = vec3()
    announce(match,"ILLEGAL SCREEN",match.rules.foulTime)
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
        P.Statistics.deferTurnover(match,target.id,request.style,player.id)
        announce(match, P.Defense.checks[request.style].name .. " · BALL LOOSE")
    elseif result == "foul" then
        local oldHolder = match.carrier
        if oldHolder and match.squad[oldHolder].team == player.team then
            Match.recordStat(match, oldHolder, "turnovers")
            P.Statistics.turnover(match,oldHolder,"illegalBodyCheck")
        end
        Match.recordStat(match, player.id, "fouls")
        -- Assessed time for the arcade box score. The existing foul pause is unchanged.
        P.Statistics.penalty(match,player.id,"personal",60,{reason="illegalBodyCheck",other=target.id})
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
        if index ~= match.controlled or match.careerWaiting
            or (intent.action == "save" and index == match.careerPlayer) then
            local player = match.squad[index]
            local action = intent.action
            if action == "pass" then
                local call = intent.tactic and intent.tactic.call
                if startPass(match,player,intent.target,call) and call then
                    P.Tactics.activate(match,intent.tactic,call,player.team)
                end
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
    P.Statistics.goalkeeper(match,keeper.id,flight.onTarget and "save" or "block",flight.from)
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
    match.lastGoalScorer,match.lastGoalTeam=flight.from,team
    Match.recordStat(match, flight.from, "goals")
    Match.recordStat(match, flight.from, "shotsOnGoal")
    P.Statistics.goalkeeper(match,match.keepers[3-team],"goal",flight.from)
    Match.recordStat(match, flight.from, "score")
    P.Screens.creditGoal(match,flight.from,match.screenStat,flight)
    P.Screens.reset(match)
    local assist = match.assist
    if assist and assist.to==flight.from and match.elapsed-assist.at<=4.8
        and (not assist.received or (flight.origin-assist.received):len()<=12) then
        Match.recordStat(match, assist.from, "assists",1,{other=flight.from})
    end
    match.assist = nil
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
            P.Statistics.turnover(match,flight.from,"interception",intercepted)
            announce(match, "INTERCEPTION")
        elseif P.Passing.canCatch(match,flight,catchIndex,position) then
            attach(match, flight.to, match.controlled == flight.from)
            Match.recordStat(match, flight.from, "completions",1,{other=flight.to})
            if flight.keeperOutlet then
                P.Statistics.record(match,flight.from,"clearsCompleted",1,{other=flight.to})
            end
            match.assist = {from=flight.from,to=flight.to,at=match.elapsed,received=position}
        elseif progress >= 1 then
            local velocity = P.Passing.endVelocity(match,flight)
            if not flight.to then position.y = ballRadius end
            freeBall(match, position, velocity, flight.team)
            P.Statistics.deferTurnover(match,flight.from,flight.to and "droppedPass" or "passToSpace")
            announce(match,flight.to and "PASS DROPPED" or "BALL LOOSE")
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
            P.Statistics.record(match,flight.from,"pipeHits",1,{reason=hit.kind})
            announce(match, hit.kind == "POST" and "OFF THE POST" or "OFF THE BAR")
            return
        elseif hit.kind == "WIDE" or hit.kind == "HIGH" or hit.kind == "LOW" then
            local misses = {WIDE="shotsWide",HIGH="shotsHigh",LOW="shotsLow"}
            if not flight.missRecorded then
                P.Statistics.record(match,flight.from,misses[hit.kind])
                flight.missRecorded = true
            end
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
    local fallback, fallbackDistance = nil, math.huge
    local x = clamp(position.x, -field.halfWidth + .9, field.halfWidth - .9)
    local z = clamp(position.z, -field.halfLength + .9, field.halfLength - .9)
    local half = P.Midfield.halfAt(match, team, z)
    for _, index in ipairs(match.teams[team]) do
        local player = match.squad[index]
        if player.role ~= "G" and player.onField ~= false and player.active ~= false and not player.bench then
            local length = distance(player.x - x, player.z - z)
            if not half or P.Midfield.side(match, player) == half then
                if length < best then selected, best = player, length end
            elseif length < fallbackDistance then
                fallback, fallbackDistance = player, length
            end
        end
    end
    -- Restart at the same depth if an incomplete lineup has no one in this half.
    if not selected and fallback then selected, z = fallback, fallback.z end
    if not selected then return end
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
        local ground = P.Attributes.rating(player,"groundBalls",65)-65
        if position.y <= .34 and contact.y <= .75
            and distance(position.x - contact.x, position.z - contact.z) <= .79+ground*.004 then
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
    P.Screens.reset(match)
    match.phaseTime = 0
    if match.period >= match.rules.periods then
        match.phase = "FINAL"
        P.Statistics.finalize(match)
        local winner = match.homeScore > match.awayScore and match.homeTeam
            or match.awayScore > match.homeScore and match.awayTeam
        announce(match, winner and winner.name .. " WIN" or "DRAW", 3)
    else
        match.phase = "INTERMISSION"
        announce(match, "END OF PERIOD " .. match.period, match.rules.intermissionTime)
    end
end

local function updateDrawActor(player, entry, dt, ballPosition, collecting)
    local animation = P.AnimationController
    if entry.action and not entry.animated then
        local clip = entry.action == "counter" and "faceoffCounter" or "faceoffClamp"
        entry.animated = animation.play(player.anim, clip)
    end
    if collecting and not entry.collecting then
        entry.collecting = animation.play(player.anim, "scoop")
    end
    return animation.update(player.anim, dt, {
        scoopPoint = entry.collecting and ballPosition or nil
    })
end

local function faceoff(match, dt, moveX, moveZ)
    local draw = match.faceoff
    local previous = draw.phase
    match.phaseTime = match.phaseTime + dt
    P.Faceoff.update(draw, dt, moveX, moveZ)
    if previous == "SET" and draw.phase == "DRAW" and draw.userTeam and not draw.home.action then
        announce(match, "TIME YOUR CLAMP", .44)
    end
    local first, second = match.squad[draw.home.id], match.squad[draw.away.id]
    local result = draw.result
    local winner = result and result.winner
    local ballPosition = match.ball.position
    local firstEvent = updateDrawActor(first, draw.home, dt, ballPosition, winner == 1)
    local secondEvent = updateDrawActor(second, draw.away, dt, ballPosition, winner == 2)
    if winner == 1 and firstEvent == "scoop" or winner == 2 and secondEvent == "scoop" then
        draw.contact = true
    end

    if previous ~= "EXIT" and draw.phase == "EXIT" then
        if result.loose then announce(match, "CONTESTED DRAW")
        elseif winner == draw.userTeam then announce(match, "STEER THE EXIT", draw.exitTime + .20) end
    end
    if draw.active then return end
    if winner and not draw.contact
        and match.phaseTime < draw.setTime + draw.duration + draw.exitTime + .65 then return end

    Match.recordStat(match, first.id, "faceoffAttempts")
    Match.recordStat(match, second.id, "faceoffAttempts")
    if result.cause == "FALSE_START" then
        local offender = winner == 1 and second or first
        Match.recordStat(match, offender.id, "faceoffViolations")
    end
    if result.loose then
        Match.recordStat(match, first.id, "faceoffScrambles")
        Match.recordStat(match, second.id, "faceoffScrambles")
        local x, z = result.exitX, result.exitZ
        local wingSlot = x < 0 and 5 or 6
        match.faceoffScramble = {
            homeId=first.id, awayId=second.id, time=2.4,
            wings={match.teams[1][wingSlot], match.teams[2][11 - wingSlot]}
        }
        freeBall(match, vec3(x * .16, ballRadius, z * .16), vec3(x * 5.6, .42, z * 5.6))
        announce(match, "LOOSE DRAW")
    else
        local player = winner == 1 and first or second
        attach(match, player.id, not careerLock(match))
        player.faceoffExit = {x=result.exitX, z=result.exitZ, remaining=.25}
        Match.recordStat(match, player.id, "faceoffs")
        local team = winner == 1 and match.homeTeam or match.awayTeam
        announce(match, team.short .. " FACEOFF WIN")
    end
    match.phase, match.phaseTime = "LIVE", 0
end

local function pursueDraw(match, intents, dt)
    local draw = match.faceoffScramble
    if not draw or draw.time <= 0 or not match.loose then return end
    draw.time = draw.time - dt
    local ball, velocity = match.ball.position, match.ballVelocity
    for _, index in ipairs(draw.wings) do
        local wing = match.squad[index]
        local sign = wing.homeX >= 0 and 1 or -1
        local intent = intents[index]
        if intent then
            -- Enter from the flank so both wings leave a lane for the faceoff players.
            intent.x, intent.z = ball.x + velocity.x * .3 + sign * .8, ball.z + velocity.z * .3
            intent.lookX, intent.lookZ, intent.speed = ball.x, ball.z, 7.8
        end
    end
end

local function live(match, dt, moveX, moveZ)
    if match.careerWaiting and match.elapsed >= match.careerEntryDelay then
        match.careerWaiting = false
        announce(match, "YOUR SHIFT", 1.7)
    end
    local length = math.max(distance(moveX, moveZ), 1)
    moveX, moveZ = moveX / length, moveZ / length
    match.moveX, match.moveZ = moveX, moveZ
    if match.clearTime > 0 then
        match.clearTime = math.max(0, match.clearTime - dt)
        if match.clearTime == 0 and match.mode == "CLEAR" then match.mode = "SET" end
    end
    local intents = P.MatchAI.update(match, dt)
    pursueDraw(match, intents, dt)
    act(match, intents)
    P.Passing.scheduleCatch(match,match.flight,dt)
    if match.flight then P.Defense.prepareIntercept(match, match.flight) end
    if match.loose and not match.careerWaiting then startScoop(match, match.squad[match.controlled]) end
    movePlayers(match, dt, moveX, moveZ, intents)
    P.Screens.update(match,dt,match.screenCallbacks)
    if match.phase~="LIVE" then return end
    local animation = P.AnimationController
    local flight, loose = match.flight, match.loose
    local catchIndex, scoopIndex
    for index, player in ipairs(match.squad) do
        local event = animation.update(player.anim, dt, {
            speed=player.speed, turn=player.turn, possessed=match.carrier==index,
            scoopPoint=match.scoopPlayer==index and match.ball.position or nil,
            catchPoint=P.Passing.catchPoint(match,index)
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
        faceoff(match, dt, moveX, moveZ)
    elseif match.phase == "LIVE" then
        local liveTime = math.min(dt, match.clock)
        match.clock = math.max(0, match.clock - liveTime)
        match.elapsed = match.elapsed + liveTime
        P.Statistics.tick(match,liveTime)
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
