-- PolyLax Build 013 | Passing
PolyLax = PolyLax or {}
local P = PolyLax
local Passing = {}
P.Passing = Passing

local cone = math.cos(math.rad(34))
local deadzone = .12
local ballRadius = .09

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x*x + z*z)
end

local function teammate(from, player)
    return player ~= from and player.team == from.team
end

function Passing.forTarget(game, id)
    local player = id and game.squad[id]
    if player then
        return {to=id, point=player.rig.pocket.worldPosition}
    end
end

function Passing.select(game, fromID, dx, dz)
    local from = fromID and game.squad[fromID]
    if not from then return end
    dx, dz = dx or 0, dz or 0
    local input = length(dx, dz)
    if input >= deadzone then
        dx, dz = dx/input, dz/input
    else
        local yaw = math.rad(from.yaw or 0)
        dx, dz = -math.sin(yaw), -math.cos(yaw)
    end

    local target, score = nil, -math.huge
    for index, player in ipairs(game.squad) do
        if teammate(from, player) then
            local x, z = player.x-from.x, player.z-from.z
            local range = length(x, z)
            if range > .28 then
                local alignment = (dx*x + dz*z) / range
                if alignment >= cone then
                    -- Aim direction wins. Distance breaks ties within the cone.
                    local rank = alignment - math.min(range,36)*.0002
                    if rank > score then target, score = index, rank end
                end
            end
        end
    end
    if target then
        local plan = Passing.forTarget(game, target)
        plan.from = fromID
        return plan
    end

    local maxRange = game.field and 26 or 16
    local range = 7 + (maxRange-7) * math.min(1,input)
    return {from=fromID, point=vec3(from.x+dx*range,ballRadius,from.z+dz*range), dx=dx, dz=dz}
end

-- The authored catch pose holds the pocket ahead and to the player's right.
-- Use the incoming direction and profile proportions to predict that position
-- without advancing the actual receiving animation before the ball launches.
local function catchOffset(receiver, source, x, z)
    local dx, dz = source.x-x, source.z-z
    local range = length(dx, dz)
    if range < .05 then
        local yaw = math.rad(receiver.yaw or 0)
        dx, dz, range = -math.sin(yaw), -math.cos(yaw), 1
    end
    dx, dz = dx/range, dz/range
    local scale = receiver.rig.proportions.scale
    return vec3((.67*dx-.82*dz)*scale.x, 2.23*scale.y, (.67*dz+.82*dx)*scale.z)
end

local function dispersion(game, pending, sender, origin, point, range)
    local attributes = sender.attributes or {}
    local clear = sender.role == "G" or pending.call == "CLEAR"
    local skill = tonumber(clear and attributes.clearingAccuracy or attributes.passing) or .66
    if skill > 1 then skill = skill/100 end
    skill = clamp(skill, 0, 1)

    local pressure = 0
    for _, player in ipairs(game.squad) do
        if player.team ~= sender.team then
            local gap = length(sender.x-player.x,sender.z-player.z)
            pressure = math.max(pressure, 1-gap/2.6)
        end
    end
    local motion = clamp((sender.speed or 0)/9, 0, 1)
    local error = clamp(range/17,.34,1.5) * (.11+.59*(1-skill)+.42*pressure+.32*motion)
    local seed = (game.passSerial or 0)*2.399963 + pending.from*.731
    game.passSerial = (game.passSerial or 0)+1
    local x, z = point.x-origin.x, point.z-origin.z
    local span = math.max(.25,length(x,z))
    local sideways, forward = math.sin(seed)*error, math.cos(seed*1.63)*error*.28
    return vec3((-z*sideways+x*forward)/span, 0, (x*sideways+z*forward)/span)
end

function Passing.launch(game, pending, options)
    options = options or {}
    local sender = game.squad[pending.from]
    local receiver = pending.to and game.squad[pending.to]
    local origin = sender.rig.pocket.worldPosition
    local point = receiver and receiver.rig.pocket.worldPosition or pending.point
    local speed = options.speed or 20
    local distance = length(point.x-origin.x, point.z-origin.z)
    local duration = clamp(distance / speed, options.minDuration or .34, options.maxDuration or 2.4)

    if receiver then
        local lead = math.min(.42, duration*.7)
        local x, z = receiver.x + (receiver.vx or 0)*lead, receiver.z + (receiver.vz or 0)*lead
        point = vec3(x,0,z) + catchOffset(receiver, origin, x, z)
    end
    point = point + dispersion(game,pending,sender,origin,point,distance)

    local arc = clamp(distance * (options.arcRate or .060), options.minArc or .18, options.maxArc or 1.25)
    local offset = point-origin
    return {
        kind="pass", from=pending.from, to=pending.to, team=sender.team,
        origin=origin, point=point, time=0, duration=duration, arc=arc,
        velocity=offset/duration + vec3(0,4*arc/duration,0)
    }
end

function Passing.sample(game, flight, time)
    local fraction = clamp(time / flight.duration, 0, 1)
    return flight.origin + (flight.point-flight.origin)*fraction
        + vec3(0, 4*flight.arc*fraction*(1-fraction), 0)
end

function Passing.endVelocity(game, flight)
    local speed = (Passing.sample(game,flight,flight.duration)
        - Passing.sample(game,flight,math.max(0,flight.duration-.025))) / .025
    return speed * (flight.to and .17 or .31)
end

function Passing.receiveTarget(game, index)
    local flight = game.flight
    if not flight or flight.kind ~= "pass" or not flight.point
        or flight.to ~= index or flight.duration-flight.time > .85 then return end
    local receiver = game.squad[index]
    local offset = catchOffset(receiver, flight.origin, receiver.x, receiver.z)
    return flight.point.x-offset.x, flight.point.z-offset.z
end

function Passing.scheduleCatch(game, flight, dt)
    if not flight or not flight.to or flight.catchStarted then return end
    local contact = P.AnimationController.clips.catch.eventTime
    local remaining = flight.duration-flight.time
    if remaining <= contact+dt then
        local scale = contact / math.max(dt, remaining-.001)
        flight.catchStarted = P.AnimationController.play(game.squad[flight.to].anim, "catch", scale)
    end
end

function Passing.catchPoint(game, index)
    local flight = game.flight
    if flight and flight.kind == "pass" and flight.to == index and flight.catchStarted then
        return flight.point
    end
end

function Passing.canCatch(game, flight, index, position)
    if not index or index ~= flight.to then return false end
    local receiver = game.squad[index]
    local gap = position - receiver.rig.pocket.worldPosition
    return gap:len() <= .82
end
