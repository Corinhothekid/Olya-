-- PolyLax Build 012 | Defense
PolyLax = PolyLax or {}
local P = PolyLax
local Defense = {}
P.Defense = Defense

local checks = {
    poke = {clip="pokeCheck", reach=1.78, cooldown=.64, impact=.16, force=3.0, stat="pokes", name="POKE CHECK"},
    slap = {clip="slapCheck", reach=1.50, cooldown=.86, impact=.23, force=4.2, stat="slaps", name="SLAP CHECK"},
    body = {clip="bodyCheck", reach=1.16, cooldown=1.15, impact=.21, force=5.0, stat="bodyChecks", name="BODY CHECK"}
}
Defense.checks = checks

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distance(x, z)
    return math.sqrt(x*x + z*z)
end

local function forwardDot(player, x, z, length)
    local yaw = math.rad(player.yaw)
    return (-math.sin(yaw)*x - math.cos(yaw)*z) / math.max(length, .001)
end

function Defense.configure(options)
    local group = options.ageGroup or "adult"
    local bodyAllowed = options.bodyContact
    if bodyAllowed == nil then
        local age = tonumber(tostring(group):match("%d+"))
        bodyAllowed = group == "adult" or group == "open" or (age and age >= 14) or false
    end
    return group, bodyAllowed == true
end

function Defense.attributes(role)
    return {
        stickCheck = role == "D" and .77 or .62,
        bodyCheck = role == "D" and .75 or .60,
        interception = role == "D" and .76 or .65,
        reaction = role == "G" and .80 or role == "D" and .74 or .65,
        ballSecurity = role == "A" and .75 or .65
    }
end

local function stat(player, key, fallback)
    local attributes = player.attributes
    local value = attributes and tonumber(attributes[key]) or fallback
    if value > 1 then value = value / 100 end
    return clamp(value, .05, 1)
end

local function frame(time, grip, shaft, torso, crouch, roll, freeHand)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand or 0}
end

function Defense.registerAnimations()
    local clips = P.AnimationController.clips
    if clips.pokeCheck then return end
    clips.pokeCheck = {
        duration=.36, eventTime=checks.poke.impact, event="check",
        poses={
            frame(.07,vec3(.36,.67,-.13),vec3(.71,.40,.34),vec3(-6,-10,-5),.08,-12),
            frame(.16,vec3(.29,.64,-.53),vec3(.24,.13,-.96),vec3(-16,8,2),.12,6,.28),
            frame(.25,vec3(.33,.61,-.29),vec3(.65,.38,-.55),vec3(-7,4,3),.07,2)
        }
    }
    clips.slapCheck = {
        duration=.51, eventTime=checks.slap.impact, event="check",
        poses={
            frame(.11,vec3(.39,.71,.01),vec3(.94,.31,.16),vec3(1,-29,-12),.05,-24,.19),
            frame(.23,vec3(.23,.66,-.37),vec3(.53,.11,-.84),vec3(-13,23,9),.12,18,.38),
            frame(.34,vec3(.15,.49,-.29),vec3(.89,-.08,-.44),vec3(-9,28,8),.06,34)
        }
    }
    clips.bodyCheck = {
        duration=.52, eventTime=checks.body.impact, event="check",
        poses={
            frame(.09,vec3(.31,.64,-.18),vec3(.86,.43,.07),vec3(-10,-15,-13),.18,-21),
            frame(.21,vec3(.38,.58,-.13),vec3(.90,.40,.06),vec3(-26,21,-24),.24,-25),
            frame(.34,vec3(.33,.57,-.16),vec3(.88,.42,-.08),vec3(-14,16,-12),.11,-11)
        }
    }
    clips.intercept = {
        duration=.44, eventTime=.18, event="intercept",
        poses={
            frame(.09,vec3(.24,.81,-.36),vec3(.48,.81,-.18),vec3(-9,-12,-3),.05,-18,.40),
            frame(.18,vec3(.16,.91,-.52),vec3(.39,.90,-.18),vec3(-13,-5,3),.06,-9,.55),
            frame(.30,vec3(.23,.67,-.30),vec3(.63,.72,.08),vec3(-4,-17,-4),.02,12,.20)
        }
    }
end

local function geometry(checker, target)
    local x, z = target.x - checker.x, target.z - checker.z
    local length = distance(x, z)
    return x, z, length, forwardDot(checker, x, z, length), forwardDot(target, -x, -z, length)
end

local function bodyLegal(match, target, victimFacing)
    return match.rules.bodyContact and match.carrier == target.id and target.role ~= "G"
        and victimFacing >= -.36
end

local function nearestContact(match, checker)
    local closest, reach = nil, checks.body.reach + .25
    for _, index in ipairs(match.teams[3-checker.team]) do
        local player = match.squad[index]
        local length = distance(checker.x - player.x, checker.z - player.z)
        if length < reach then closest, reach = player, length end
    end
    return closest
end

function Defense.request(match, checker, name)
    if name == "check" then name = "poke" end
    local check = checks[name]
    if not check or checker.role == "G" or checker.checkCooldown > 0 then return end
    local target = match.carrier and match.squad[match.carrier]
    if target and target.team == checker.team then target = nil end
    if not target and name == "body" then target = nearestContact(match, checker) end
    if not target then return end
    local _, _, length = geometry(checker, target)
    if length > check.reach + .40 then return end
    local skill = stat(checker, name == "body" and "bodyCheck" or "stickCheck", .63)
    if P.AnimationController.play(checker.anim, check.clip, .86 + skill * .22) then
        checker.checkCooldown = check.cooldown
        return {style=name, target=target.id, skill=skill, clip=check.clip}
    end
end

function Defense.aiChoice(match, checker, target)
    if checker.role == "G" or target.role == "G" or checker.checkCooldown > 0 then return end
    local _, _, length, facing, victimFacing = geometry(checker, target)
    if bodyLegal(match, target, victimFacing) and length < .93 and facing >= .63
        and checker.role == "D" and target.speed >= 2.8 then return "body" end
    if facing < .06 or victimFacing < -.64 then return end
    if length < 1.18 and (target.speed < 3.2 or target.anim.action == "pass") then return "slap" end
    if length < checks.poke.reach - .13 then return "poke" end
end

local function stickGap(checker, target)
    local stick = checker.rig.stickRoot
    local base, tip = stick:transformPoint(vec3(0,.10,0)), checker.rig.pocket.worldPosition
    local ball = target.rig.pocket.worldPosition
    local guide = tip - base
    local time = clamp((ball-base):dot(guide) / math.max(.001, guide:dot(guide)), 0, 1)
    return (ball - (base+guide*time)):len()
end

function Defense.contact(match, checker, request)
    local target = match.squad[request.target]
    local check = checks[request.style]
    local dx, dz, length, facing, victimFacing = geometry(checker, target)
    local body = request.style == "body"
    local reach = check.reach + (request.skill - .65) * .20
    if length > reach or facing < (body and .32 or -.12) then return "miss" end
    if body and not bodyLegal(match, target, victimFacing) then return "foul" end
    if match.carrier ~= target.id or target.role == "G" then return "miss" end
    if not body and victimFacing < -.70 then return "miss" end

    local gap = body and length or stickGap(checker, target)
    local security = stat(target, "ballSecurity", .65)
    local protect = target.anim.action == "protect" or target.anim.action == "dodge"
    local ready = target.anim.action ~= "pass" and target.anim.action ~= "shoot"
    local impact = request.skill + (body and .21 or .05) + .22 * facing
        + .12 * math.max(0, victimFacing) - .13 * length / reach
    if not body then impact = impact - .20 * gap end
    local stability = security * .63 + (protect and .30 or 0) + (ready and .13 or 0)
    if impact < stability then return "miss" end

    local range = math.max(.28, length)
    local velocity = vec3(target.vx*.23 + dx*check.force/range,
        body and .78 or .48, target.vz*.23 + dz*check.force/range)
    return "loose", target.rig.pocket.worldPosition, velocity
end

function Defense.passPoint(match, flight, time)
    if flight.point then return P.Passing.sample(match,flight,time) end
    local fraction = clamp(time / flight.duration, 0, 1)
    local endPoint = match.squad[flight.to].rig.pocket.worldPosition
    return flight.origin + (endPoint-flight.origin)*fraction
        + vec3(0, math.sin(fraction*math.pi)*flight.arc, 0)
end

function Defense.prepareIntercept(match, flight)
    if flight.kind ~= "pass" or flight.interceptor then return end
    local eventTime = P.AnimationController.clips.intercept.eventTime
    if flight.duration - flight.time < eventTime + .08 then return end
    local target = Defense.passPoint(match, flight, flight.time + eventTime)
    local previous = match.ball.position
    if target.y < .44 or target.y > 3.05 then return end
    local best, player = math.huge, nil
    for _, id in ipairs(match.teams[3-flight.team]) do
        local candidate = match.squad[id]
        local reaction = stat(candidate, "reaction", .67)
        local savvy = stat(candidate, "interception", .63)
        local lead = .11 + .18 * (1-reaction)
        local dx, dz = previous.x - candidate.x, previous.z - candidate.z
        local gap = distance(target.x-candidate.x-candidate.vx*eventTime*.55,
            target.z-candidate.z-candidate.vz*eventTime*.55)
        if flight.time >= lead and gap < 1.14 + savvy*.34 and gap < best
            and forwardDot(candidate, dx, dz, distance(dx,dz)) > -.36
            and not candidate.anim.action then best, player = gap, candidate end
    end
    if player and P.AnimationController.play(player.anim, "intercept") then
        flight.interceptor = {id=player.id, pocket=player.rig.pocket.worldPosition}
    end
end

function Defense.intercept(match, flight, from, to)
    local contest = flight.interceptor
    if not contest then return end
    local player = match.squad[contest.id]
    local current = player.rig.pocket.worldPosition
    local previous = contest.pocket
    contest.pocket = current
    local event = P.AnimationController.clips.intercept.eventTime
    if player.anim.action ~= "intercept" or math.abs(player.anim.actionTime - event) > .074 then return end

    -- Sweep the ball relative to the moving pocket so a fast pass can cross it
    -- cleanly within a single frame without tunneling or snapping from afar.
    local start, finish = from - previous, to - current
    local travel = finish - start
    local time = clamp(-start:dot(travel) / math.max(.001, travel:dot(travel)), 0, 1)
    local offset = start + travel * time
    local run = stat(player, "interception", .65)
    local reach = .25 + run*.25
    if offset:dot(offset) <= reach*reach then return player.id end
end
