-- PolyLax 2.0.3 | MatchAI
PolyLax = PolyLax or {}
local P = PolyLax
local AI = {}
PolyLax.MatchAI = AI

local TACTICAL_INTERVAL = .16
local BALL_RADIUS = .09
local GRAVITY = 9.8
local atan2 = math.atan2 or math.atan

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distanceSquared(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx*dx + dz*dz
end

local function planDistance(ax, az, bx, bz)
    return math.sqrt(distanceSquared(ax, az, bx, bz))
end

local function unit(dx, dz, fallbackZ)
    local length = math.sqrt(dx*dx + dz*dz)
    if length < .0001 then return 0, fallbackZ or 0 end
    return dx / length, dz / length
end

local function goalX(goal)
    return goal.x or 0
end

local function goalHeight(goal)
    return goal.height or goal.top or goal.crossbar or 1.83
end

local function midfielder(player)
    return player.role == "M" or player.role == "FOGO" or player.role == "LSM" or player.role == "SSDM"
end

local function humanControls(match, id)
    if match.humans then return match.humans[id] ~= nil end
    return id == match.controlled and not match.careerWaiting and not match.careerOnBench
end

local function attackingSign(match, team)
    local goal = match.goalsByTeam[team]
    return goal.attackSign or (goal.z < 0 and -1 or 1)
end

local function acrossMidfield(match, player, sign)
    local z = player.z * sign
    if math.abs(z) > .0001 then return z > 0 end
    local side = P.Midfield and P.Midfield.side and P.Midfield.side(match,player)
    if side == "offense" or side == "OFFENSE" then return true end
    if side == "defense" or side == "DEFENSE" then return false end
    if type(side) == "number" then return side * sign > 0 end
    if type(side) == "boolean" then return side end
    return (player.homeZ or 0) * sign > 0
end

local function numbers(match,team,sign)
    if P.Midfield and P.Midfield.counts then return P.Midfield.counts(match,team) end
    local attack, defense = 0, 0
    for _, id in ipairs(match.teams[team]) do
        if acrossMidfield(match,match.squad[id],sign) then attack = attack + 1
        else defense = defense + 1 end
    end
    return {offense=attack,defense=defense}
end

function AI.new()
    return {
        elapsed=0, nextTick=0, phase=nil, lastTeam=nil,
        intents={}, players={}, goalies={},
        tactics={{mark={}}, {mark={}}},
        awareness={}
    }
end

local function ballTeam(match)
    if match.carrier then return match.squad[match.carrier].team end
    if match.flight and match.flight.kind == "pass" then
        return match.squad[match.flight.from].team
    end
end

local function updateAwareness(match, ai)
    local snapshot = ai.awareness
    snapshot.ball = match.ball.position
    snapshot.velocity = match.ballVelocity
    snapshot.carrier = match.carrier
    snapshot.possessionTeam = ballTeam(match)
    snapshot.phase = match.phase
    snapshot.flight = match.flight
    snapshot.loose = match.loose ~= nil
    snapshot.teams = match.teams
    snapshot.players = ai.players
    for id, player in ipairs(match.squad) do
        local entry = ai.players[id] or {}
        ai.players[id] = entry
        entry.id, entry.team, entry.role = id, player.team, player.role
        entry.x, entry.z = player.x, player.z
        entry.teammates, entry.opponents = match.teams[player.team], match.teams[3 - player.team]
        local goal = match.goalsByTeam[player.team]
        entry.distanceToGoal = planDistance(player.x, player.z, goalX(goal), goal.z)
        entry.distanceToBall = planDistance(player.x, player.z, snapshot.ball.x, snapshot.ball.z)
        entry.phase = snapshot.phase
    end
    return snapshot
end

local function move(intent, x, z)
    intent.x, intent.z = x, z
end

local function restrict(match, intent)
    local field = match.field
    intent.x = clamp(intent.x, -field.halfWidth + .5, field.halfWidth - .5)
    intent.z = clamp(intent.z, -field.halfLength + .5, field.halfLength - .5)
end

local function nearestOpponent(match, player)
    local best, bestDistance = nil, math.huge
    for _, id in ipairs(match.teams[3 - player.team]) do
        local opponent = match.squad[id]
        if opponent.role ~= "G" then
            local distance = distanceSquared(player.x, player.z, opponent.x, opponent.z)
            if distance < bestDistance then best, bestDistance = opponent, distance end
        end
    end
    return best, math.sqrt(bestDistance)
end

function AI.passTarget(match, fromID, swing)
    local target, detail = P.Tactics.choose(match, fromID, swing and "SWING" or "SAFE")
    return target, detail and detail.score
end

local function moveKeeper(match, keeper, intent, ball, sightTime)
    local goal = match.goalsByTeam[3 - keeper.team]
    local cx = goalX(goal)
    local inside = goal.z < 0 and 1 or -1
    local depth = (ball.z - goal.z) * inside
    local lateral = ball.x - cx
    local angle = atan2(lateral, math.max(2.5, depth))
    local positioning = P.Attributes.unit(keeper,"goaliePositioning",keeper.positioning or .78)
    local arc = 1.08+(positioning-.5)*.34
    local px = cx + math.sin(angle) * arc
    local pz = goal.z + math.cos(angle) * arc * inside
    if depth < .4 then
        px = cx + clamp(lateral * .18, -.86, .86)
        pz = goal.z + .34 * inside
    end
    if sightTime then
        px = cx + clamp(lateral, -.98, .98) * .83
        pz = goal.z + .76 * inside
    end
    move(intent, px, pz)
    intent.lookX, intent.lookZ = ball.x, ball.z
    intent.role = sightTime and "SHOT" or "GOAL ARC"
    local footwork = P.Attributes.unit(keeper,"goaliePositioning",keeper.footwork or .73)
    intent.speed = 2.7+footwork*(sightTime and 4.1 or 2.5)
end

local function useScreen(match, ai, tactic, carrier, defender, pressure, depth, goal, intent)
    local screens = P.Screens
    if not screens then return false end
    local now = ai.elapsed
    local screen = match.screen
    if not screen and defender and pressure > 1.15 and pressure < 4.2
        and depth > 7 and depth < 23 and not carrier.anim.action
        and now >= (tactic.nextPick or 0) then
        local plan = P.Tactics.pick(match, carrier.id, defender.id)
        if plan and not (match.humans and humanControls(match,plan.screener)) then
            screen = screens.request(match, plan.screener, carrier.id, defender.id, plan)
            if screen then tactic.nextPick = now + 5 end
        end
    end
    if not screen or screen.user ~= carrier.id then return false end

    local towardX, towardZ = unit(goalX(goal) - screen.x, goal.z - screen.z)
    if screen.phase == "APPROACH" or screen.phase == "PLANT" then
        -- Stay on the entry side while the screener gets both feet set.
        move(intent, screen.x - towardX*1.65 - towardZ*screen.side*.65,
            screen.z - towardZ*1.65 + towardX*screen.side*.65)
        intent.speed, intent.role = 2.9, "WAIT FOR PICK"
        return true
    end
    if screen.phase == "HOLD" then
        local tangentX, tangentZ = -towardZ*screen.side, towardX*screen.side
        local vx, vz = unit(screen.x + towardX*2.7 + tangentX*1.06 - carrier.x,
            screen.z + towardZ*2.7 + tangentZ*1.06 - carrier.z)
        move(intent, carrier.x + vx*3.6, carrier.z + vz*3.6)
        intent.speed, intent.role = 7.7, "USE PICK"
        if not match.pending and not carrier.anim.action and (screen.contact or pressure < 2.6)
            and now >= (tactic.nextDodge or 0) then
            intent.action, intent.moveX, intent.moveZ = "dodge", vx, -vz
            tactic.nextDodge = now + 1.4
        end
        return true
    end
    if screen.phase == "RELEASE" and not match.pending and not carrier.anim.action then
        local receiver = match.squad[screen.screener]
        local gap = planDistance(carrier.x, carrier.z, receiver.x, receiver.z)
        if gap > 2.1 and gap < 14 and P.Tactics.opponentSpace(match, receiver) > 1.7
            and P.Tactics.laneRisk(match, carrier, receiver) < 1.25
            and now >= (tactic.nextAction or 0) then
            intent.action, intent.target = "pass", receiver.id
            intent.tactic = {call="PICK DOWN", from=carrier.id, target=receiver.id,
                team=carrier.team, untilTime=(match.elapsed or 0) + 2}
            tactic.nextAction = now + .9
            return true
        end
    end
    return false
end

local function tacticalPass(match, tactic, carrierID, pressure, depth, now)
    local call
    if match.mode == "SWING" or match.mode == "CLEAR" or match.mode == "PASS DOWN" then
        call = match.mode
    elseif now >= (tactic.nextCall or 0) then
        if pressure < 2 and depth > 9 then call = "CLEAR"
        elseif depth > 8 and depth < 25 and pressure < 4.1 then call = "PASS DOWN"
        elseif depth < 26 then call = "SWING" end
    end
    if not call then return nil end
    local target, detail = P.Tactics.choose(match, carrierID, call)
    if target then tactic.nextCall = now + 2.2 end
    return target, detail
end

local function midfieldOutlet(slot,ball,progress)
    local firstWing = ball.x < 0 and 4 or 5
    local order = slot == firstWing and 1 or slot == 6 and 3 or 2
    local leaders = progress >= -1 and 3 or progress > -11 and 2 or progress > -24 and 1 or 0
    if order <= leaders then return nil, 2.8 + order * 1.4 end
    local width = slot == 4 and -12.4 or slot == 5 and 12.4 or ball.x * .22
    local depth = clamp(-progress * (.18 + order * .10) + order,3.6,22)
    return width, -depth
end

local function offBallAttack(match, ai, snapshot, team)
    local goal = match.goalsByTeam[team]
    local cx = goalX(goal)
    local inside = goal.z < 0 and 1 or -1
    local ball = snapshot.ball
    local distance = (ball.z - goal.z) * inside
    local advance = clamp((distance - 24) * .78, 0, match.field.halfLength * 1.45)
    local spread = clamp(math.abs(ball.x - cx) * .18, 0, 3.5)
    local sides, depths = {-8.8, 8.8, 0, -6.4, 6.4, 0}, {10.4, 10.4, -4, 18.5, 18.5, 7}
    local tactic = ai.tactics[team]
    local cut = P.Tactics.activeCut(match)
    local carrierID = match.carrier
    local carrier = carrierID and match.squad[carrierID]
    local sign = attackingSign(match,team)
    local progress = (carrier and carrier.z or ball.z) * sign
    local attackSlot, midSlot = 0, 3
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local intent = ai.intents[identifier]
        if player.role == "G" then
            moveKeeper(match, player, intent, ball)
        elseif player.role == "A" or midfielder(player) then
            if player.role == "A" then attackSlot = attackSlot + 1 else midSlot = midSlot + 1 end
            local slot = player.role == "A" and math.min(attackSlot,3) or math.min(midSlot,6)
            local x, z = sides[slot], depths[slot] + advance
            if match.mode == "CLEAR" and advance < 2 then
                if slot < 3 then x, z = x * 1.46, 2 end
                if slot == 6 then x, z = ball.x > 0 and -5.6 or 5.6, 14 end
            elseif slot == 3 then
                x = x - ball.x * .11
            else
                x = x + (x < 0 and -spread or spread) + ball.x*.08
            end
            if tactic.cut == identifier and advance < 3 and slot ~= 3 then
                x, z = -ball.x * .10, 6.1
            end
            local fieldX, fieldZ = cx+x, (goal.z+z*inside)*sign
            if player.role == "A" then
                fieldZ = math.max(fieldZ, slot == 3 and 13 or 6.0)
            else
                local outlet, depth = midfieldOutlet(slot,ball,progress)
                if outlet then fieldX,fieldZ = cx+outlet,depth
                else fieldZ = math.max(fieldZ,depth) end
            end
            move(intent, fieldX, fieldZ*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = fieldZ < 0 and "MIDFIELD OUTLET" or tactic.cut == identifier and "CUT"
                or advance > 8 and "TRANSITION" or "2-3-1"
        else
            local ownGoal = match.goalsByTeam[3 - team]
            local depthFromOwn = (ball.z - ownGoal.z) * -inside
            local reserve = clamp(depthFromOwn * .42 + 7, 8, 34)
            local z = math.min(-2.4,(ownGoal.z-reserve*inside)*sign)
            move(intent, player.homeX + ball.x*.08, z*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = "RELEASE SUPPORT"
        end
        if cut and cut.team == team and cut.cutID == identifier then
            move(intent, cut.cutX, cut.cutZ)
            intent.lookX, intent.lookZ, intent.speed = ball.x, ball.z, 7.4
            intent.role = cut.call == "CLEAR" and "CLEAR THROUGH" or "PASS DOWN CUT"
        end
    end

    if not carrier or carrier.team ~= team or carrier.role == "G" then
        return
    end
    local defender, pressure = nearestOpponent(match, carrier)
    local intent = ai.intents[carrierID]
    local approachX, approachZ = unit(cx - carrier.x, goal.z - carrier.z, -inside)
    if distance < 5.2 then
        local side = carrier.x >= 0 and 1 or -1
        move(intent, cx + 4.4 * side, goal.z + 6 * inside)
    else
        move(intent, carrier.x + approachX*7, carrier.z + approachZ*7)
    end
    intent.lookX, intent.lookZ = cx, goal.z
    intent.role = "BALL"

    local now = ai.elapsed
    if now >= (tactic.nextCut or 0) and distance < 22 then
        local best, bestSpace = nil, -math.huge
        for _, identifier in ipairs(match.teams[team]) do
            local player = match.squad[identifier]
            if player.role == "A" and identifier ~= carrierID and player.x * ball.x <= 0 then
                local _, space = nearestOpponent(match, player)
                local score = space - planDistance(player.x, player.z, cx, goal.z) * .15
                if score > bestSpace then best, bestSpace = identifier, score end
            end
        end
        tactic.cut, tactic.nextCut = best, now + 2.1
    elseif now >= (tactic.nextCut or 0) or distance > 25 then
        tactic.cut = nil
    end

    if humanControls(match,carrierID) then return end
    if not match.pending and not match.flight
        and useScreen(match, ai, tactic, carrier, defender, pressure, distance, goal, intent) then return end

    if match.pending or match.flight or carrier.anim and carrier.anim.action then return end
    if now < (tactic.nextAction or 0) then return end
    local shotRange = planDistance(carrier.x, carrier.z, cx, goal.z)
    local keeper = match.squad[match.keepers[3 - team]]
    local shotSide = keeper.x >= cx and -1 or 1
    local shootingAngle = distance / math.max(1, shotRange)
    local read = P.Attributes.unit(carrier,"lacrosseIQ",.60)-.60
    local decisionDelay = 1-read*.42
    if shotRange < 15 and distance > 2.6 and shootingAngle > .49+read*.11
            and (pressure > 2.15 or shotRange < 7.4) then
        intent.action = "shoot"
        intent.aim = vec3(cx + goal.halfWidth*.66*shotSide, goalHeight(goal)*.66, goal.z)
        tactic.nextAction = now+.72*decisionDelay
    elseif defender and pressure < 2.6 and distance < 23 then
        local side = defender.x <= carrier.x and 1 or -1
        local nextX = carrier.x + side * 3.1
        local nextZ = carrier.z + approachZ * 3.3
        if match.mode ~= "SWING" and math.abs(nextX) < match.field.halfWidth - 1.5
                and now >= (tactic.nextDodge or 0) then
            move(intent, nextX, nextZ)
            intent.action, intent.moveX, intent.moveZ = "dodge", side*.79, -approachZ*.61
            tactic.nextDodge, tactic.nextAction = now+1.4,now+.38*decisionDelay
        end
    end
    if not intent.action and (pressure < 3.8 or distance < 25 or match.mode == "SWING") then
        local target, detail = tacticalPass(match, tactic, carrierID, pressure, distance, now)
        local score = detail and detail.score
        if not target and match.mode ~= "CLEAR" then
            target, score = AI.passTarget(match, carrierID, false)
        end
        if target and score > 2.5+read*.58 then
            intent.action, intent.target = "pass", target
            intent.tactic = detail
            tactic.nextAction = now+.68*decisionDelay
        end
    end
end

function AI.canCheck(match, checkerID, carrierID)
    local checker, carrier = match.squad[checkerID], match.squad[carrierID]
    if not checker or not carrier or checker.team == carrier.team
            or match.carrier ~= carrierID or match.flight
            or match.phase ~= "LIVE" then return false end
    local style = PolyLax.Defense.aiChoice(match, checker, carrier)
    return style ~= nil, style
end

local function chooseMatchups(match, ai, team, ownGoal, carrier)
    local tactic = ai.tactics[team]
    local marks, used = {}, {}
    local opposition = match.teams[3 - team]
    local gx = goalX(ownGoal)
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        if player.role == "D" or midfielder(player) then
            local best, score = nil, math.huge
            for _, otherID in ipairs(opposition) do
                local other = match.squad[otherID]
                if not used[otherID] and other.role ~= "G" and other.role ~= "D" then
                    local candidate = planDistance(player.x, player.z, other.x, other.z)
                        + planDistance(other.x, other.z, gx, ownGoal.z)*.16
                    if tactic.mark[identifier] == otherID then candidate = candidate - 2 end
                    if player.role == "D" and midfielder(other) then candidate = candidate + 2.8 end
                    if candidate < score then best, score = otherID, candidate end
                end
            end
            if best then marks[identifier], used[best] = best, true end
        end
    end
    -- Preserve the settled matchup on routine passes, but orient on the ball.
    local primary, primaryScore = nil, math.huge
    if carrier and carrier.role ~= "G" then
        for identifier, mark in pairs(marks) do
            local defender = match.squad[identifier]
            local candidate = planDistance(defender.x, defender.z, carrier.x, carrier.z)
            if mark == carrier.id then candidate = candidate - 2.4 end
            if tactic.primary == identifier then candidate = candidate - .85 end
            if candidate == primaryScore and identifier < primary then candidate = candidate - .001 end
            if candidate < primaryScore then primary, primaryScore = identifier, candidate end
        end
    end
    tactic.mark, tactic.primary = marks, primary
    return tactic
end

local function coordinateSlide(match, tactic, goal, carrier)
    local primary = tactic.primary and match.squad[tactic.primary]
    local gx = goalX(goal)
    if not carrier or not primary then
        tactic.firstSlide, tactic.secondSlide = nil, nil
        return
    end
    local distance = planDistance(carrier.x, carrier.z, gx, goal.z)
    local fx, fz = unit(gx-carrier.x, goal.z-carrier.z)
    local defenderX, defenderZ = primary.x-carrier.x, primary.z-carrier.z
    local goalSide = defenderX*fx + defenderZ*fz
    local miss = math.abs(defenderX*fz - defenderZ*fx)
    local danger = distance < 13 and (goalSide < .35 or miss > 1.8) and (carrier.speed > .9 or distance < 8)
    if not danger then
        tactic.firstSlide, tactic.secondSlide = nil, nil
        return
    end

    local first, firstScore = nil, math.huge
    for identifier in pairs(tactic.mark) do
        local defender = match.squad[identifier]
        if identifier ~= primary.id then
            local cost = planDistance(defender.x, defender.z, carrier.x + fx*1.4, carrier.z + fz*1.4)
            cost = cost + planDistance(defender.x, defender.z, gx, goal.z)*.22
            if identifier == tactic.firstSlide then cost = cost - 1.35 end
            if cost < firstScore or cost == firstScore and identifier < first then
                first, firstScore = identifier, cost
            end
        end
    end
    tactic.firstSlide = first

    local second, secondScore = nil, math.huge
    local vacated = first and match.squad[tactic.mark[first]]
    if vacated then
        for identifier in pairs(tactic.mark) do
            if identifier ~= primary.id and identifier ~= first then
                local defender = match.squad[identifier]
                local cost = planDistance(defender.x, defender.z, vacated.x, vacated.z)
                if identifier == tactic.secondSlide then cost = cost - .65 end
                if cost < secondScore or cost == secondScore and identifier < second then
                    second, secondScore = identifier, cost
                end
            end
        end
    end
    tactic.secondSlide = second
end

local function swapMark(marks, defender, assignment)
    local old = marks[defender]
    for id, other in pairs(marks) do
        if id ~= defender and other == assignment then
            marks[id] = old
            break
        end
    end
    marks[defender] = assignment
end

local function obstructed(screen, x, z, tx, tz)
    local fx, fz = tx - x, tz - z
    local span = fx*fx + fz*fz
    if span < .01 then return false end
    local at = ((screen.x-x)*fx + (screen.z-z)*fz) / span
    return at >= -.04 and at <= 1.18
        and planDistance(screen.x, screen.z, x + fx*at, z + fz*at) < 1.02
end

local function defendScreen(match, ai, tactic, team, carrier)
    local swap = tactic.screenSwitch
    if swap and (ai.elapsed >= swap.untilTime or not carrier
        or (carrier.id ~= swap.user and carrier.id ~= swap.screener)) then
        tactic.screenSwitch, swap = nil, nil
    end
    local screen = match.screen
    if not swap and screen and screen.team ~= team and carrier and carrier.id == screen.user
        and screen.defender and tactic.mark[screen.defender] and screen.phase == "HOLD" then
        local held = match.squad[screen.defender]
        if screen.contact or obstructed(screen, held.x, held.z, carrier.x, carrier.z) then
            local gap = planDistance(held.x, held.z, carrier.x, carrier.z)
            local helper, best = nil, math.huge
            for _, id in ipairs(match.teams[team]) do
                local assignment = tactic.mark[id]
                if id ~= held.id and assignment then
                    local help = match.squad[id]
                    local cover = planDistance(help.x, help.z, carrier.x, carrier.z)
                    local partner = assignment == screen.screener
                    if cover < 4.6 and (partner or screen.contact and cover < gap - .25)
                        and cover < gap + (screen.contact and 1.15 or .15) then
                        local score = cover - (partner and .95 or 0)
                        if score < best then helper, best = id, score end
                    end
                end
            end
            if helper then
                swap = {user=screen.user, screener=screen.screener, on=helper,
                    off=held.id, untilTime=ai.elapsed + 1.25}
                tactic.screenSwitch = swap
            end
        end
    end
    if swap then
        swapMark(tactic.mark, swap.on, swap.user)
        swapMark(tactic.mark, swap.off, swap.screener)
        tactic.primary = carrier.id == swap.user and swap.on or swap.off
    end
    return swap
end

local function routeAroundScreen(screen, player, intent, goal)
    if not screen or screen.phase ~= "HOLD" or screen.defender ~= player.id then return false end
    local ux, uz = unit(intent.x - player.x, intent.z - player.z)
    local gap = planDistance(player.x, player.z, screen.x, screen.z)
    if gap > 3.3 or not obstructed(screen, player.x, player.z, intent.x, intent.z) then return false end
    -- Pick the goal side when available. Lead the waypoint past the obstacle so
    -- the next decision resumes the assignment instead of aiming at its edge.
    local goalDx, goalDz = goalX(goal) - screen.x, goal.z - screen.z
    local over = -uz*goalDx + ux*goalDz >= 0 and 1 or -1
    local clearance = screen.contact and 1.48 or 1.22
    move(intent, screen.x - uz*over*clearance + ux*.83, screen.z + ux*over*clearance + uz*.83)
    intent.speed = screen.contact and 4.4 or 5.7
    intent.role = screen.contact and "SCREEN RECOVERY" or gap < 1.65 and "FIGHT OVER" or "GO AROUND"
    return true
end

local function defend(match, ai, snapshot, team)
    local goal = match.goalsByTeam[3 - team]
    local gx = goalX(goal)
    local ball = snapshot.ball
    local carrierID = match.carrier
    local carrier = carrierID and match.squad[carrierID]
    local sign = attackingSign(match,team)
    local inRide = (carrier and carrier.z or ball.z)*sign > 2
    local tactic = chooseMatchups(match, ai, team, goal, carrier)
    local switching = defendScreen(match, ai, tactic, team, carrier)
    coordinateSlide(match, tactic, goal, carrier)
    local onBall = tactic.firstSlide or tactic.primary
    local inside = goal.z < 0 and 1 or -1
    if inRide then
        onBall = nil
        if carrier then
            local best = math.huge
            for _, id in ipairs(match.teams[team]) do
                local player = match.squad[id]
                if player.role == "A" and not humanControls(match,id) then
                    local gap = distanceSquared(player.x,player.z,carrier.x,carrier.z)
                    if gap < best then onBall,best=id,gap end
                end
            end
        end
    end

    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local intent = ai.intents[identifier]
        local mark = tactic.mark[identifier]
        if player.role == "G" then
            moveKeeper(match, player, intent, ball)
        elseif carrier and identifier == onBall then
            local fx, fz = unit(gx-carrier.x, goal.z-carrier.z, -inside)
            local spacing = identifier == tactic.firstSlide and 1.48 or 1.26
            local z = carrier.z+fz*spacing
            if inRide then z = math.max(1.25,z*sign)*sign
            else z = math.min(-1.25,z*sign)*sign end
            move(intent, carrier.x + fx*spacing,z)
            intent.lookX, intent.lookZ = carrier.x, carrier.z
            intent.role = inRide and "RIDE PRESSURE" or identifier == tactic.firstSlide and "FIRST SLIDE"
                or switching and "SCREEN SWITCH" or "BALL PRESSURE"
            local gap = planDistance(player.x, player.z, carrier.x, carrier.z)
            intent.speed = gap < 3.4 and 4.4 or 7.2
            if not routeAroundScreen(match.screen, player, intent, goal) then
                local canCheck, style = AI.canCheck(match, identifier, carrierID)
                if canCheck and ai.elapsed >= (tactic.nextCheck or 0) then
                    intent.action, intent.target = style, carrierID
                    tactic.nextCheck = ai.elapsed + .72
                end
            end
        elseif player.role == "A" then
            local depth = clamp(ball.z*sign+12,6,math.max(7,math.abs(player.homeZ)-3))
            move(intent, player.homeX + ball.x*.16, depth*sign)
            intent.lookX,intent.lookZ = ball.x,ball.z
            intent.role = inRide and "RIDE SUPPORT" or "HIGH OUTLET"
        elseif inRide then
            local depth = midfielder(player) and -clamp(math.abs(player.homeX)*.21+3,3,8)
                or -math.max(10,math.abs(player.homeZ)*.68)
            move(intent, player.homeX + ball.x*.12,depth*sign)
            intent.lookX,intent.lookZ = ball.x,ball.z
            intent.role = midfielder(player) and "MIDFIELD RECOVERY" or "DEFENSIVE SHAPE"
        elseif mark then
            if identifier == tactic.secondSlide then mark = tactic.mark[tactic.firstSlide] end
            if identifier == tactic.primary and tactic.firstSlide and tactic.secondSlide then
                mark = tactic.mark[tactic.secondSlide]
            end
            local assignment = match.squad[mark]
            local towardX, towardZ = unit(gx-assignment.x, goal.z-assignment.z)
            local gap = identifier == tactic.secondSlide and .94 or 1.76
            local help = (assignment.x * ball.x < 0) and .20 or .1
            local x = assignment.x + towardX*gap + (ball.x-assignment.x) * help
            local z = assignment.z + towardZ*gap
            if match.flight and match.flight.kind == "pass" and match.flight.to == mark then
                x, z = x + (ball.x-x)*.31, z + (ball.z-z)*.31
                intent.role = "DENY PASS"
            else
                intent.role = identifier == tactic.secondSlide and "SECOND SLIDE"
                    or identifier == tactic.primary and "RECOVER" or "MATCHUP"
            end
            move(intent, x, math.min(-1.5,z*sign)*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            routeAroundScreen(match.screen, player, intent, goal)
        else
            local support = clamp((ball.z-goal.z)*inside + 9, 32, match.field.halfLength*1.48)
            move(intent, player.homeX + ball.x*.13, math.min(-1.5,(goal.z+support*inside)*sign)*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = "RIDE"
        end
    end
end

local function assignLoose(match, ai, snapshot, team)
    local ball = snapshot.ball
    local velocity = snapshot.velocity or vec3()
    local x, z = ball.x + velocity.x*.16, ball.z + velocity.z*.16
    local sign = attackingSign(match,team)
    local limits = numbers(match,team,sign)
    local onAttack = z*sign > 0
    local best, second, d1, d2 = nil, nil, math.huge, math.huge
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local distance = distanceSquared(player.x, player.z, x, z)
        if player.role == "G" then
            local ownGoal = match.goalsByTeam[3 - team]
            if distanceSquared(goalX(ownGoal), ownGoal.z, x, z) > 6.4 then distance = math.huge end
        end
        if math.abs(z) > .65 and acrossMidfield(match,player,sign) ~= onAttack
            and (onAttack and limits.offense >= 6 or not onAttack and limits.defense >= 7) then
            distance = math.huge
        end
        if distance < d1 then
            second, d2 = best, d1
            best, d1 = identifier, distance
        elseif distance < d2 then
            second, d2 = identifier, distance
        end
    end
    if best then
        local chaser = match.squad[best]
        local intent = ai.intents[best]
        local dx, dz = unit(x-chaser.x, z-chaser.z, 1)
        move(intent, x-dx*.37, z-dz*.37)
        intent.lookX, intent.lookZ = x, z
        intent.role = "GROUND BALL"
        if ball.y < .34 and distanceSquared(chaser.x,chaser.z,ball.x,ball.z) < 1.35^2 then
            intent.action = "scoop"
        end
    end
    if second and d2 < 80 and match.squad[second].role ~= "G" then
        local support = match.squad[second]
        local sx, sz = unit(support.x-x, support.z-z, 1)
        local intent = ai.intents[second]
        move(intent, x + sx*3, z + sz*3)
        intent.role = "GROUND COVER"
    end
end

local function humanCrossing(match, human, team, sign, moveZ)
    if human and human.team == team and math.abs(human.z) <= 10 then
        local advance = -(moveZ or 0)*sign
        if math.abs(advance) < .14 then advance = (human.vz or 0)*sign*.16 end
        if math.abs(advance) >= .14 and (advance > 0) ~= acrossMidfield(match,human,sign) then
            return human,advance > 0
        end
    end
end

local function requestCrossing(match,ai,team,sign)
    if match.humans then
        for _, id in ipairs(match.teams[team]) do
            local input = match.humans[id]
            if input then
                local player, heading = humanCrossing(match,match.squad[id],team,sign,input.z)
                if player then return player,heading end
            end
        end
    else
        local human = not (match.careerWaiting or match.careerOnBench) and match.squad[match.controlled]
        local player, heading = humanCrossing(match,human,team,sign,match.moveZ)
        if player then return player,heading end
    end
    local carrier = match.carrier and match.squad[match.carrier]
    if carrier and not humanControls(match,carrier.id) and carrier.team == team and carrier.role ~= "G"
        and math.abs(carrier.z) <= 9 then
        local target = ai.intents[carrier.id].z*sign
        if math.abs(target) > .65 and (target > 0) ~= acrossMidfield(match,carrier,sign) then
            return carrier,target > 0
        end
    end
end

local function exchangeAtMidfield(match,ai,snapshot,team,sign)
    local tactic = ai.tactics[team]
    local exchange = tactic.exchange
    local mover,toAttack = requestCrossing(match,ai,team,sign)
    if exchange then
        local player = match.squad[exchange.mover]
        if acrossMidfield(match,player,sign) == exchange.toAttack then
            exchange = nil
        elseif mover and mover.id == exchange.mover and toAttack == exchange.toAttack then
            exchange.untilTime = ai.elapsed + .55
        elseif ai.elapsed >= exchange.untilTime then
            exchange = nil
        end
    end
    if not exchange and mover then
        local count = numbers(match,team,sign)
        if toAttack and count.offense >= 6 or not toAttack and count.defense >= 7 then
            local best,bestCost
            for _, id in ipairs(match.teams[team]) do
                local player = match.squad[id]
                local screen = match.screen
                if id ~= mover.id and id ~= match.carrier and player.role ~= "G"
                    and not humanControls(match,id)
                    and acrossMidfield(match,player,sign) == toAttack
                    and not (screen and (screen.screener == id or screen.user == id)) then
                    local cost = math.abs(player.z) + math.abs(player.x-mover.x)*.13
                    if not midfielder(player) then
                        cost = cost + ((toAttack and player.role == "A"
                            or not toAttack and player.role == "D") and 44 or 25)
                    end
                    if not bestCost or cost < bestCost then best,bestCost=id,cost end
                end
            end
            if best then
                exchange = {mover=mover.id,reserve=best,toAttack=toAttack,untilTime=ai.elapsed+.55}
            end
        end
    end
    tactic.exchange = exchange
    return exchange
end

local function balanceMidfield(match,ai,snapshot,team)
    local sign = attackingSign(match,team)
    local exchange = exchangeAtMidfield(match,ai,snapshot,team,sign)
    local midfielders,nonMidAttack,wanted = {},0,0
    for _, id in ipairs(match.teams[team]) do
        local player,intent = match.squad[id],ai.intents[id]
        local attacking = acrossMidfield(match,player,sign)
        if midfielder(player) then
            local desire = intent.z*sign > 0
            if humanControls(match,id) or id == match.carrier then
                desire = attacking
            end
            if exchange and id == exchange.mover then desire = exchange.toAttack
            elseif exchange and id == exchange.reserve then desire = not exchange.toAttack end
            if desire then wanted = wanted + 1 end
            local priority = (desire and 100 or 0) + (attacking and 6 or 0) - math.abs(player.z)*.27
            if humanControls(match,id) or id == match.carrier then priority = priority + (desire and 180 or -180) end
            if exchange and id == exchange.reserve then priority = priority + (desire and 400 or -400) end
            midfielders[#midfielders+1] = {id=id,priority=priority}
        elseif attacking then
            nonMidAttack = nonMidAttack + 1
        end
    end
    local duringExchange = nonMidAttack
    if exchange then
        local mover = match.squad[exchange.mover]
        local reserve = match.squad[exchange.reserve]
        if exchange.toAttack and not midfielder(mover) then duringExchange = duringExchange + 1 end
        if not exchange.toAttack and not midfielder(reserve)
            and not acrossMidfield(match,reserve,sign) then duringExchange = duringExchange + 1 end
    end
    local maximum = clamp(6-duringExchange,0,#midfielders)
    local minimum = clamp(3-nonMidAttack,0,maximum)
    local selected = clamp(wanted,minimum,maximum)
    table.sort(midfielders,function(a,b)
        return a.priority == b.priority and a.id < b.id or a.priority > b.priority
    end)
    for rank, entry in ipairs(midfielders) do
        local id = entry.id
        local player,intent = match.squad[id],ai.intents[id]
        local front = rank <= selected
        if id ~= match.carrier and not humanControls(match,id) and (intent.z*sign > 0) ~= front then
            local depth = front and (3.3+rank*1.3) or -(3.6+rank*.8)
            local width = math.abs(player.homeX) > 1 and player.homeX*.78 or snapshot.ball.x*.35
            move(intent,width,depth*sign)
            intent.speed = 6.4
            intent.role = front and "MIDFIELD REPLACEMENT" or "MIDFIELD COVER"
            intent.action,intent.target = nil,nil
        end
    end
    if exchange then
        local reserve = match.squad[exchange.reserve]
        local intent = ai.intents[reserve.id]
        local depth = exchange.toAttack and -2.8 or 2.8
        move(intent,reserve.x,depth*sign)
        intent.speed,intent.role = 7.8,"MIDFIELD EXCHANGE"
        intent.lookX,intent.lookZ = snapshot.ball.x,snapshot.ball.z
        intent.action,intent.target = nil,nil
    end
end

local function gait(time, grip, shaft, torso, crouch, roll, freeHand)
    return {
        time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand or 0
    }
end

function AI.registerAnimations()
    local clips = PolyLax.AnimationController.clips
    if clips.saveHighLeft then return end
    for _, side in ipairs({-1,1}) do
        local sideName = side < 0 and "Left" or "Right"
        clips["saveHigh"..sideName] = {
            duration=.46,
            poses={
                gait(.09, vec3(.20*side,.76,-.29), vec3(.68*side,.79,-.14), vec3(-4,11*side,-5*side), .07, -12*side, .15),
                gait(.17, vec3(.37*side,.93,-.38), vec3(.72*side,.73,-.08), vec3(-8,16*side,-11*side), .10, -20*side, .28),
                gait(.30, vec3(.27*side,.72,-.30), vec3(.67*side,.74,-.13), vec3(-2,9*side,-5*side), .04, -6*side, .12)
            }
        }
        clips["saveLow"..sideName] = {
            duration=.50,
            poses={
                gait(.08, vec3(.24*side,.52,-.24), vec3(.73*side,.14,-.45), vec3(-12,9*side,-9*side), .15, -19*side, .20),
                gait(.17, vec3(.39*side,.35,-.38), vec3(.80*side,-.53,-.30), vec3(-23,12*side,-19*side), .35, -19*side, .45),
                gait(.34, vec3(.25*side,.60,-.32), vec3(.82*side,.54,-.03), vec3(-8,6*side,-7*side), .12, -11*side, .13)
            }
        }
    end
end

local function saveStyle(keeper, sample)
    local relative = keeper.rig.body:inverseTransformPoint(sample)
    local side = relative.x < 0 and "Left" or "Right"
    local level = sample.y < .91 and "Low" or "High"
    return "save" .. level .. side
end

local function watchShot(match, ai)
    local flight = match.flight
    if not flight or flight.kind ~= "shot" then
        for _, index in ipairs(match.keepers) do ai.goalies[index] = nil end
        return
    end
    local shooter = match.squad[flight.from]
    local keeperID = match.keepers[3 - shooter.team]
    local keeper = match.squad[keeperID]
    local goal = match.goalsByTeam[shooter.team]
    local ball, velocity = match.ball.position, match.ballVelocity
    if not velocity or math.abs(velocity.z) < 1 then return end
    local travelTime = (keeper.z - ball.z) / velocity.z
    if travelTime < -.08 or travelTime > 1.8 then return end
    local memory = ai.goalies[keeperID]
    if not memory or memory.flight ~= flight then
        local reflexes = P.Attributes.unit(keeper,"reflexes",keeper.reflexes or .76)
        local anticipation = P.Attributes.unit(keeper,"goaliePositioning",keeper.anticipation or .72)
        local distance = math.abs(goal.z-ball.z)
        local delay = clamp(.29 - reflexes*.18 - anticipation*.025 + distance*.002, .085, .31)
        memory = {flight=flight, ready=ai.elapsed+delay}
        ai.goalies[keeperID] = memory
    end
    local wait = math.max(0, travelTime)
    local intercept = vec3(ball.x + velocity.x*wait,
        ball.y + velocity.y*wait - GRAVITY*.5*wait*wait, keeper.z)
    if math.abs(intercept.x-goalX(goal)) > goal.halfWidth + .85
            or intercept.y > goalHeight(goal) + .65 or intercept.y < -.15 then return end
    local intent = ai.intents[keeperID]
    if ai.elapsed >= memory.ready then
        moveKeeper(match, keeper, intent, intercept, wait)
        intent.lookX, intent.lookZ = ball.x, ball.z
        if not memory.actionSent and wait < .42 then
            memory.style = saveStyle(keeper, intercept)
            memory.actionSent = true
            intent.action, intent.style = "save", memory.style
        end
    end
end

local function segmentSphere(a, b, center, radius)
    local difference, offset = b-a, a-center
    local squaredRadius = radius*radius
    if offset:dot(offset) <= squaredRadius then return 0 end
    local lengthSquared = difference:dot(difference)
    if lengthSquared < 1e-10 then return nil end
    local projection = offset:dot(difference)
    if projection >= 0 then return nil end
    local discriminant = projection*projection - lengthSquared*(offset:dot(offset)-squaredRadius)
    if discriminant < 0 then return nil end
    local t = (-projection - math.sqrt(discriminant))/lengthSquared
    if t >= 0 and t <= 1 then return t end
end

function AI.sweepKeeper(match, keeperID, from, to, velocity)
    local keeper = match.squad[keeperID]
    if not keeper then return nil end
    local rate = P.Attributes.unit(keeper,"goaliePositioning",keeper.positioning or .78)
    local hands = P.Attributes.unit(keeper,"handSpeed",keeper.handSpeed or .75)
    local memory = match.ai and match.ai.goalies[keeperID]
    local ready = memory and match.ai.elapsed >= memory.ready
    local best, caught, center = nil, false, nil

    local function consider(point, radius, canCatch)
        local time = segmentSphere(from, to, point, radius + BALL_RADIUS)
        if time and (not best or time < best) then
            best, caught, center = time, canCatch, point
        end
    end

    if ready and keeper.rig.pocket then
        local head = keeper.rig.pocket.worldPosition
        local gap = memory.style and .26 or .18
        local maxCatchSpeed = 14.5 + hands*10 + rate*3
        local catchable = velocity:len() <= maxCatchSpeed
        consider(head, gap + hands*.09, catchable)
        local stick = keeper.rig.stickRoot
        if stick then
            if keeper.stickType=="goalie" then
                for _, side in ipairs({-1,1}) do
                    consider(stick:transformPoint(vec3(side*.218,.88,-.10)),.16+hands*.035,catchable)
                end
                consider(stick:transformPoint(vec3(0,1.11,-.134)),.14,catchable)
            end
            consider(stick:transformPoint(vec3(0,.35,0)), .08, false)
            consider(stick:transformPoint(vec3(0,.01,0)), .08, false)
        end
    end
    local block = .33 + rate*.10
    for _, y in ipairs({.55, .92, 1.27, 1.61}) do
        consider(vec3(keeper.x,y,keeper.z), block, false)
    end
    if not best then return nil end
    local point = from + (to-from)*best
    local normal = (point-center):normalize()
    local outward = keeper.team == 1 and -1 or 1
    local rebound = vec3(
        velocity.x*.18 + normal.x*2.8,
        clamp(math.abs(velocity.y)*.24 + .9, .65, 3.6),
        outward*math.max(2.6, math.abs(velocity.z)*.28)
    )
    return {
        t=best, time=best, position=point, caught=caught, velocity=rebound,
        style=memory and memory.style or saveStyle(keeper, point)
    }
end

local function keepOutlet(match, ai)
    local id = match.carrier
    local holder = id and match.squad[id]
    if not holder or holder.role ~= "G" or match.pending or match.flight then return end
    local intent = ai.intents[id]
    local tactic = ai.tactics[holder.team]
    intent.role = "OUTLET"
    if ai.elapsed < (tactic.nextOutlet or 0) then return end
    local target = AI.passTarget(match, id, false)
    if target then
        intent.action, intent.target = "pass", target
        tactic.nextOutlet = ai.elapsed + .9
    else
        local goal = match.goalsByTeam[3 - holder.team]
        local inside = goal.z < 0 and 1 or -1
        move(intent, holder.x < 0 and -3.6 or 3.6, goal.z + inside*3.8)
    end
end

function AI.update(match, dt)
    local ai = match.ai or AI.new()
    match.ai = ai
    ai.elapsed = ai.elapsed + dt
    AI.registerAnimations()
    for id, player in ipairs(match.squad) do
        if not ai.intents[id] then ai.intents[id] = {x=player.x, z=player.z} end
        local intent = ai.intents[id]
        intent.action, intent.target, intent.aim, intent.style = nil, nil, nil, nil
        intent.tactic, intent.moveX, intent.moveZ = nil, nil, nil
    end
    if match.phase ~= "LIVE" then
        ai.nextTick = ai.elapsed
        if ai.phase == "LIVE" then ai.goalies = {} end
        ai.phase = match.phase
        return ai.intents
    end
    if ai.elapsed >= ai.nextTick or ai.phase ~= match.phase then
        local snapshot = updateAwareness(match, ai)
        for _, intent in ipairs(ai.intents) do intent.speed = nil end
        ai.phase = match.phase
        ai.nextTick = ai.elapsed + TACTICAL_INTERVAL
        local attacking = snapshot.possessionTeam
        if attacking then ai.lastTeam = attacking end
        attacking = attacking or ai.lastTeam or 1
        offBallAttack(match, ai, snapshot, attacking)
        defend(match, ai, snapshot, 3-attacking)
        if snapshot.loose then
            assignLoose(match, ai, snapshot, 1)
            assignLoose(match, ai, snapshot, 2)
        elseif snapshot.possessionTeam then
            keepOutlet(match, ai)
        end
        balanceMidfield(match,ai,snapshot,1)
        balanceMidfield(match,ai,snapshot,2)
        for _, intent in ipairs(ai.intents) do restrict(match, intent) end
    end
    watchShot(match, ai)
    return ai.intents
end
