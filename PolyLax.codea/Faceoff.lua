-- PolyLax Build 012 | Timing, clamp counters, and draw exits
PolyLax = PolyLax or {}
local Faceoff = {}
PolyLax.Faceoff = Faceoff

local difficulties = {
    EASY = {center = .28, spread = .26, technique = -.09, counter = .24},
    NORMAL = {center = .38, spread = .21, technique = 0, counter = .37},
    HARD = {center = .45, spread = .15, technique = .04, counter = .45},
    EXPERT = {center = .46, spread = .09, technique = .08, counter = .50}
}

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function roll(draw)
    draw.randomState = draw.randomState * 48271 % 2147483647
    return draw.randomState / 2147483647
end

local function normalized(value, default)
    value = tonumber(value)
    if not value then return default end
    if value > 1 then value = value / 100 end
    return clamp(value, 0, 1)
end

local function contestant(player, human)
    local attributes = player and player.attributes
    local rating = player and player.faceoffRating or attributes and attributes.faceoff
    local stamina = player and player.stamina or attributes and attributes.stamina
    local fatigue = player and player.faceoffFatigue
    return {
        id = player and player.id,
        rating = normalized(rating, .65),
        stamina = clamp(normalized(stamina, 1) - normalized(fatigue, 0), 0, 1),
        human = human
    }
end

local function scheduleCPU(draw, athlete, difficulty)
    if athlete.human then return end
    local variation = roll(draw) + roll(draw) - 1
    local edge = (athlete.rating - .65) * .15 + (athlete.stamina - 1) * .12
    athlete.cpuTiming = clamp(difficulty.center + variation * difficulty.spread + edge, .06, .96)
    athlete.cpuAction = roll(draw) < difficulty.counter and "counter" or "clamp"
    athlete.technique = difficulty.technique
end

function Faceoff.new(options, homePlayer, awayPlayer, serial, userTeam)
    options = options or {}
    if userTeam == nil then userTeam = 1 end
    local difficultyName = tostring(options.difficulty or "NORMAL"):upper()
    local difficulty = difficulties[difficultyName] or difficulties.NORMAL
    local setTime = clamp(tonumber(options.setTime) or .64, .20, 2.0)
    local duration = clamp(tonumber(options.duration) or .54, .26, 1.6)
    local draw = {
        active = true, phase = "SET", elapsed = 0, phaseTime = 0,
        meter = 0, windowStart = .23, windowEnd = .69, sweetSpot = .46,
        cpuMeter = 0, userTeam = userTeam,
        setTime = setTime, duration = duration,
        exitTime = clamp(tonumber(options.exitTime) or .30, .12, .80),
        randomState = (math.floor(tonumber(serial) or 1) * 12648430 + 38047) % 2147483646 + 1,
        home = contestant(homePlayer, userTeam == 1),
        away = contestant(awayPlayer, userTeam == 2)
    }
    scheduleCPU(draw, draw.home, difficulty)
    scheduleCPU(draw, draw.away, difficulty)
    return draw
end

function Faceoff.input(draw, action)
    if not draw.active or not draw.userTeam then return false end
    if draw.phase ~= "SET" and draw.phase ~= "DRAW" then return false end
    if action == "faceoff" then action = "clamp" end
    if action ~= "clamp" and action ~= "counter" then return false end
    local athlete = draw.userTeam == 1 and draw.home or draw.away
    if athlete.action then return false end
    athlete.action = action
    athlete.timing = (draw.elapsed - draw.setTime) / draw.duration
    return true
end

local function performCPU(athlete, meter)
    if not athlete.human and not athlete.action and meter >= athlete.cpuTiming then
        athlete.action, athlete.timing = athlete.cpuAction, athlete.cpuTiming
    end
end

local function timingQuality(draw, athlete)
    if not athlete.action or athlete.timing < 0 then return 0 end
    local error = math.abs(athlete.timing - draw.sweetSpot)
    return clamp(1 - error * 1.7, 0, 1)
end

local function score(athlete, opponent, quality)
    if quality == 0 then return 0 end
    local counterAdvantage = 0
    if athlete.action == "counter" and opponent.action == "clamp" then
        counterAdvantage = .14 * quality - .027
    elseif athlete.action == "counter" then
        counterAdvantage = -.035
    end
    return quality * .72 + athlete.rating * .18 + athlete.stamina * .10
        + counterAdvantage + (athlete.technique or 0)
end

local function resolve(draw)
    local home, away = draw.home, draw.away
    local homeQuality, awayQuality = timingQuality(draw, home), timingQuality(draw, away)
    local homeScore, awayScore = score(home, away, homeQuality), score(away, home, awayQuality)
    local homeViolation = home.action ~= nil and home.timing < 0
    local awayViolation = away.action ~= nil and away.timing < 0
    local advantage = homeScore - awayScore
    local winner, cause
    if homeViolation ~= awayViolation then
        winner, cause = homeViolation and 2 or 1, "FALSE_START"
    elseif homeScore == 0 and awayScore == 0 then
        cause = "CONTESTED"
    elseif math.abs(advantage) < .083 then
        cause = "CONTESTED"
    else
        winner, cause = advantage > 0 and 1 or 2, "CLEAN"
    end
    draw.result = {
        winner = winner, loose = winner == nil, cause = cause,
        homeId = home.id, awayId = away.id,
        homeAction = home.action, awayAction = away.action,
        homeTiming = home.timing, awayTiming = away.timing,
        homeQuality = homeQuality, awayQuality = awayQuality,
        homeScore = homeScore, awayScore = awayScore
    }
    draw.phase = "EXIT"
end

local function readExit(draw, moveX, moveZ)
    -- Store the latest deliberate direction during the steering window.
    local x, z = moveX or 0, moveZ or 0
    local magnitude = math.sqrt(x * x + z * z)
    if draw.result.winner == draw.userTeam and magnitude > .17 then
        local scale = math.max(1, magnitude)
        draw.moveX, draw.moveZ = x / scale, z / scale
    end
end

local function complete(draw)
    local result = draw.result
    local flank = roll(draw) < .5 and -1 or 1
    result.moveX, result.moveZ = draw.moveX, draw.moveZ
    if result.loose then
        -- An even clamp squirts sideways for a contested wing pickup.
        result.exitX, result.exitZ = flank, (roll(draw) - .5) * .48
    elseif draw.moveX then
        result.exitX, result.exitZ = draw.moveX, -draw.moveZ
    else
        -- Unsteered exits progress a little into the attacking half.
        result.exitX, result.exitZ = flank * .56, result.winner == 1 and -.72 or .72
    end
    draw.active, draw.phase, draw.phaseTime = false, "COMPLETE", 0
    return result
end

function Faceoff.update(draw, dt, moveX, moveZ)
    if not draw.active or dt <= 0 then return end
    draw.elapsed = draw.elapsed + dt
    if draw.phase == "SET" then
        draw.phaseTime = draw.elapsed
        if draw.elapsed < draw.setTime then return end
        draw.phase = "DRAW"
    end
    if draw.phase == "DRAW" then
        draw.phaseTime = draw.elapsed - draw.setTime
        draw.meter = clamp(draw.phaseTime / draw.duration, 0, 1)
        performCPU(draw.home, draw.meter)
        performCPU(draw.away, draw.meter)
        local cpu = draw.userTeam == 2 and draw.home or draw.away
        draw.cpuMeter = math.min(draw.meter, cpu.cpuTiming or 1)
        if draw.phaseTime < draw.duration then return end
        resolve(draw)
    end
    draw.phaseTime = draw.elapsed - draw.setTime - draw.duration
    readExit(draw, moveX, moveZ)
    if draw.phaseTime >= draw.exitTime then return complete(draw) end
end

function Faceoff.cancel(draw)
    draw.active, draw.phase, draw.phaseTime, draw.result = false, "CANCELLED", 0, nil
end

local function frame(time, grip, shaft, torso, crouch, roll, freeHand)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand}
end

function Faceoff.registerAnimations(animation)
    local clips = animation.clips
    if clips.faceoffClamp then return end
    clips.faceoffClamp = {
        duration = .23,
        poses = {
            frame(.075, vec3(.35,.32,-.31), vec3(.23,-.32,-.92), vec3(-23,-5,-6), .19,-5,.45),
            frame(.145, vec3(.38,.27,-.34), vec3(.09,-.43,-.90), vec3(-30,-4,-8), .30,22,.57)
        }
    }
    clips.faceoffCounter = {
        duration = .24,
        poses = {
            frame(.070, vec3(.34,.35,-.26), vec3(.30,-.24,-.92), vec3(-22,-12,-9), .17,-14,.38),
            frame(.165, vec3(.20,.40,-.32), vec3(-.36,-.30,-.88), vec3(-26,17,9), .25,-37,.64)
        }
    }
end
