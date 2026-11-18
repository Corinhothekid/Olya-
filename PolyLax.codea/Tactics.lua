-- PolyLax Build 013 | Positional lacrosse calls shared by practice and matches
PolyLax = PolyLax or {}
local Tactics = {}
PolyLax.Tactics = Tactics

local atan2 = math.atan2 or math.atan
local turn = 2 * math.pi

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function unit(x, z)
    local distance = length(x, z)
    if distance < .001 then return 0, 0 end
    return x / distance, z / distance
end

local function sign(value)
    return value < 0 and -1 or 1
end

local function attackGoal(game, team, options)
    return options and options.goal or game.goalsByTeam and game.goalsByTeam[team]
        or game.goalPhysics or game.goal
end

local function homeTeam(player)
    return player.team or 1
end

local function opposition(game, player)
    return game.teams and game.teams[3 - homeTeam(player)] or {}
end

local function teamIDs(game, player, options)
    return options and options.ids or game.teams and game.teams[homeTeam(player)]
end

local function wideThreshold(game)
    return game.field and math.max(4.4, game.field.halfWidth * .20) or 3.15
end

local function behindGoalSlot(game, player)
    if player.role == "X" or player.name == "X" then return true end
    local goal = game.goalsByTeam and game.goalsByTeam[homeTeam(player)]
    return goal and player.homeZ and (player.homeZ - goal.z) * (goal.attackSign or sign(goal.z)) > .65
end

local function usableTarget(game, from, to, options)
    return to and from ~= to and homeTeam(from) == homeTeam(to) and to.role ~= "G"
        and (not options.excluded or not options.excluded[to.id])
end

function Tactics.opponentSpace(game, player)
    local distance, nearest = math.huge, nil
    for _, id in ipairs(opposition(game, player)) do
        local defender = game.squad[id]
        if defender.role ~= "G" then
            local gap = length(defender.x - player.x, defender.z - player.z)
            if gap < distance then distance, nearest = gap, id end
        end
    end
    return distance, nearest
end

function Tactics.defender(game, userID)
    local player = game.squad[userID]
    if not player then return nil end
    local gap, nearest = Tactics.opponentSpace(game, player)
    local tactics = game.ai and game.ai.tactics
    local defense = tactics and tactics[3 - homeTeam(player)]
    local primary = defense and defense.primary and game.squad[defense.primary]
    if primary then
        local assignedGap = length(primary.x - player.x, primary.z - player.z)
        if assignedGap <= gap + 1.15 then return primary.id, assignedGap end
    end
    return nearest, gap
end

function Tactics.laneRisk(game, from, to)
    local x, z = to.x - from.x, to.z - from.z
    local span = x * x + z * z
    if span < .001 then return math.huge end
    local risk = 0
    for _, id in ipairs(opposition(game, from)) do
        local defender = game.squad[id]
        local fraction = clamp(((defender.x - from.x) * x + (defender.z - from.z) * z) / span, 0, 1)
        if fraction > .07 then
            local anticipation = fraction * .24
            local dx = defender.x + (defender.vx or 0) * anticipation - (from.x + fraction * x)
            local dz = defender.z + (defender.vz or 0) * anticipation - (from.z + fraction * z)
            risk = math.max(risk, (2.3 - length(dx, dz)) * (fraction > .9 and .85 or 1))
        end
    end
    return risk
end

local function phaseTime(game, detail)
    return (game.elapsed or 0) <= (detail.untilTime or detail.expires or 0)
end

local function cutDetails(game, detail, from, goal, front, width, fromID, ids)
    local target = game.squad[detail.target]
    local gx = goal.x or 0
    local half = game.field and game.field.halfWidth - 1 or 7.6
    if detail.call == "PASS DOWN" then
        local targetDepth = (target.z - goal.z) * front
        local fromDepth = (from.z - goal.z) * front
        local crease = game.field and game.field.creaseRadius or 2.1
        detail.cutID = fromID
        detail.cutX = gx + detail.side * math.min(1.9, width * .39)
        detail.cutZ = goal.z + clamp(targetDepth + 1.25, crease + .95, math.max(crease + .95, fromDepth - .8)) * front
    elseif detail.call == "CLEAR" then
        local cut, best = nil, math.huge
        for i = 1, #ids do
            local id = ids[i]
            local player = game.squad[id]
            local depth = (player.z - goal.z) * front
            local offset = math.abs(player.x - gx)
            if id ~= detail.target and id ~= fromID and player.role ~= "G"
                    and not behindGoalSlot(game, player) and depth > .65 and offset < width then
                local score = offset + depth * .28
                if score < best then cut, best = id, score end
            end
        end
        if cut then
            local player = game.squad[cut]
            local depth = (player.z - goal.z) * front
            local crease = game.field and game.field.creaseRadius or 2.1
            detail.cutID = cut
            detail.cutX = gx - detail.side * math.min(half, width * 1.45)
            detail.cutZ = goal.z + math.max(crease + .7, depth - 1.65) * front
        end
    end
end

local function candidateIDs(game, from, options)
    local ids = teamIDs(game, from, options)
    if ids then return ids end
    ids = {}
    for id in ipairs(game.squad) do ids[#ids + 1] = id end
    return ids
end

function Tactics.choose(game, fromID, call, options)
    options = options or {}
    local from = game.squad[fromID]
    if not from then return nil end
    call = tostring(call or "SAFE"):upper():gsub("_", " ")
    if call == "PICK DOWN" then
        local pick = Tactics.pick(game, fromID, options.defender, options)
        return pick and pick.screener, pick
    end
    local goal = attackGoal(game, homeTeam(from), options)
    if not goal then return nil end
    local gx = goal.x or 0
    local front = goal.attackSign and -goal.attackSign or goal.z < 0 and 1 or -1
    local fromDepth, fromX = (from.z - goal.z) * front, from.x - gx
    local width = options.minWidth or wideThreshold(game)
    local side = options.side or (math.abs(fromX) > width * .48 and sign(fromX) or nil)
    local swing = game.tactical
    local continuation = call == "SWING" and swing and swing.call == "SWING"
        and swing.target == fromID and phaseTime(game, swing)
    local previous = options.previous or continuation and swing.from
    local direction = options.direction or continuation and swing.swingDirection or (fromX > 0 and -1 or 1)
    local angle = atan2(fromX, fromDepth)
    local ids = candidateIDs(game, from, options)
    local best, detail, rating = nil, nil, -math.huge
    for _, id in ipairs(ids) do
        local to = game.squad[id]
        if id ~= fromID and id ~= previous and usableTarget(game, from, to, options) then
            local offset, depth = to.x - gx, (to.z - goal.z) * front
            local distance = length(to.x - from.x, to.z - from.z)
            local gain = fromDepth - depth
            local outside = math.abs(offset) >= width and depth > .65 and not behindGoalSlot(game, to)
            local eligible = distance >= (call == "NEAREST" and .01 or 1.35)
                and distance <= (options.maxDistance or (game.field and 36 or 17))
            if call == "CLEAR" then
                eligible = eligible and outside and (not options.side or offset * options.side > 0)
            elseif call == "PASS DOWN" then
                eligible = eligible and outside and gain >= 1.2 and fromDepth > 1
                    and (not side or offset * side > 0)
            elseif call == "SWING" then
                local aroundX = depth < -.6 and behindGoalSlot(game, to)
                eligible = eligible and (math.abs(offset) >= width * .70 or aroundX)
            end
            if eligible then
                local space = Tactics.opponentSpace(game, to)
                local risk = Tactics.laneRisk(game, from, to)
                local score = 5.8 - math.abs(distance - 10) * .12 - risk * 2.6
                    + math.min(space, 7) * .38 + clamp(gain, -9, 15) * .12
                if call == "CLEAR" then
                    eligible = space >= 2.1 and risk < 1.10
                    score = score + math.min(math.abs(offset), 14) * .11
                    if from.role == "G" then score = score + clamp(gain, -12, 24) * .16 end
                elseif call == "PASS DOWN" then
                    eligible = space >= 1.5 and risk < 1.35
                    score = score + math.min(gain, 13) * .19
                elseif call == "SWING" then
                    local step = (atan2(offset, depth) - angle) * direction % turn
                    eligible = step >= .13 and step <= math.pi * 1.02 and risk < 1.65
                    score = 8.15 - step * 2.9 - math.abs(distance - 10) * .10
                        + math.min(space, 7) * .26 - risk * 2.9
                elseif call == "NEAREST" then
                    score = -distance
                else
                    local goalDistance = length(offset, depth)
                    if from.role == "G" then
                        score = score + math.min(math.abs(offset), 15) * .08 + clamp(gain, -12, 24) * .16
                    elseif goalDistance < 14 then
                        score = score + 1.5 - goalDistance * .06
                    end
                end
                if eligible and score > rating then
                    best, rating = id, score
                    detail = {target=id, from=fromID, side=sign(offset), downfield=gain,
                        laneRisk=risk, space=space, score=score, call=call, team=homeTeam(from)}
                end
            end
        end
    end
    if detail then
        if call == "SWING" then detail.swingDirection = direction end
        cutDetails(game, detail, from, goal, front, width, fromID, ids)
        local delay = call == "CLEAR" and 2.6 or call == "PASS DOWN" and 2.4 or 3.2
        detail.untilTime = (game.elapsed or 0) + (options.duration or delay)
    end
    return best, detail
end

function Tactics.activate(game, detail, call, team, seconds)
    if not detail then return end
    detail.call, detail.team = call or detail.call, team or detail.team
    if seconds then detail.untilTime = (game.elapsed or 0) + seconds end
    game.tactical = detail
    return detail
end

function Tactics.activeCut(game)
    local detail = game.tactical or game.cut
    if not detail then return nil end
    local carrier = game.carrier and game.squad[game.carrier]
    local flight = game.flight
    local passer = flight and flight.kind == "pass" and game.squad[flight.from]
    local team = carrier and homeTeam(carrier) or passer and homeTeam(passer)
    if not phaseTime(game, detail) or game.loose or (team and team ~= detail.team)
            or game.phase and game.phase ~= "LIVE" then
        if game.tactical == detail then game.tactical = nil end
        if game.cut == detail then game.cut = nil end
        if game.mode == detail.call then game.mode = "SET" end
        return nil
    end
    if not detail.cutID or detail.cutID == game.carrier or detail.cutID == (game.flight and flight.to) then
        return nil
    end
    return detail
end

function Tactics.pick(game, userID, defenderID, options)
    options = options or {}
    local user = game.squad[userID]
    if not user or user.role == "G" then return nil end
    local goal = attackGoal(game, homeTeam(user), options)
    if not goal then return nil end
    defenderID = defenderID or Tactics.defender(game, userID)
    local defender = defenderID and game.squad[defenderID]
    if defender and homeTeam(defender) == homeTeam(user) then return nil end
    local goalX = goal.x or 0
    local fx, fz = unit(goalX - user.x, goal.z - user.z)
    if fx == 0 and fz == 0 then return nil end
    local side = options.side or (user.x > goalX and -1 or 1)
    local px, pz
    if defender then
        local ux, uz = unit(user.x - defender.x, user.z - defender.z)
        if ux == 0 and uz == 0 then ux, uz = -fx, -fz end
        px, pz = defender.x + ux * 1.22 - uz * side * .52,
            defender.z + uz * 1.22 + ux * side * .52
    else
        px, pz = user.x + fx * 1.55 - fz * side * .95, user.z + fz * 1.55 + fx * side * .95
    end
    if game.field then
        px = clamp(px, -game.field.halfWidth + 1.2, game.field.halfWidth - 1.2)
        pz = clamp(pz, -game.field.halfLength + 1.2, game.field.halfLength - 1.2)
    else
        px, pz = clamp(px, -7.7, 7.7), clamp(pz, -15.8, 14.8)
    end
    local ids = candidateIDs(game, user, options)
    local selected, best = nil, math.huge
    for _, id in ipairs(ids) do
        local player = game.squad[id]
        if id ~= userID and usableTarget(game, user, player, options)
                and (not options.screener or id == options.screener) and (id ~= game.controlled or options.screener) then
            local distance = length(player.x - px, player.z - pz)
            local limit = options.screener and 12 or game.field and 8.4 or 7.4
            if distance <= limit then
                local roleCost = player.role == "D" and 2.5 or 0
                if distance + roleCost < best then selected, best = id, distance + roleCost end
            end
        end
    end
    if not selected then return nil end
    return {
        screener=selected, user=userID, defender=defenderID, x=px, z=pz, side=side,
        release=options.release or (length(px - goalX, pz - goal.z) >= 13 and "pop" or "roll"),
        goalX=goalX, goalZ=goal.z, call="PICK DOWN", team=homeTeam(user),
        untilTime=(game.elapsed or 0) + 3.3
    }
end
