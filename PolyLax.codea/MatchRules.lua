-- PolyLax 3.0 | Men's field match rules and live ball clocks
PolyLax = PolyLax or {}
local P = PolyLax
local Rules = {}
P.MatchRules = Rules

local profiles = {
    arcade = {name="Arcade testing",periodLength=90},
    highSchool = {name="High school (NFHS 2027)",periodLength=720,ageGroup="highSchool",
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClockStartsAfterClear=true,optionalShotClock=70},
    ncaa = {name="NCAA men's field",periodLength=900,
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClock=80,shotRecovery=60},
    collegeClub = {name="MCLA college club",periodLength=900,
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClock=80,shotRecovery=60},
    professional = {name="Professional men's field",periodLength=720,
        clearClock=20,creaseClock=4,shotClock=52,faceoffShotClock=32,shotRecovery=32,recoveryThreshold=32,
        fieldMetrics={fieldLengthYards=100,wingFromCenterYards=19}},
}

local function limit(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(low, math.min(high, value))
end

local function seconds(value, fallback)
    if value == false or tonumber(value) == 0 then return nil end
    if value == nil and fallback == nil then return nil end
    if not tonumber(value) and fallback == nil then return nil end
    return limit(value, fallback, .1, 120)
end

function Rules.configure(options)
    options = options or {}
    local id = options.profile or options.ruleset
    if not profiles[id] then id = "arcade" end
    local defaults = profiles[id]
    local age = options.ageGroup or defaults.ageGroup
    local body = options.bodyContact
    if body == nil and age == "highSchool" and id == "highSchool" then body = true end
    local ageGroup, bodyContact = P.Defense.configure({ageGroup=age,bodyContact=body})
    local faceoff = type(options.faceoff) == "table" and options.faceoff or {}
    local shotClock = defaults.shotClock
    if options.stateShotClock == true then shotClock = defaults.optionalShotClock or shotClock end
    local startsAfterClear = options.shotClockStartsAfterClear
    if startsAfterClear == nil then startsAfterClear = defaults.shotClockStartsAfterClear end
    local fieldMetrics = {}
    for key, value in pairs(defaults.fieldMetrics or {}) do fieldMetrics[key] = value end
    for key, value in pairs(options.fieldMetrics or {}) do fieldMetrics[key] = value end
    return {
        profile=id, name=options.name or defaults.name,
        periods=math.floor(limit(options.periods, 4, 1, 8)),
        periodLength=limit(options.periodLength, defaults.periodLength, 1, 900),
        intermissionTime=limit(options.intermissionTime, 2.4, .4, 12),
        goalTime=limit(options.goalTime, 1.7, .6, 5),
        foulTime=limit(options.foulTime, 1.05, .4, 5),
        ageGroup=ageGroup, bodyContact=bodyContact,
        shotClock=seconds(options.shotClock, shotClock),
        clearClock=seconds(options.clearClock, defaults.clearClock),
        clearAtDeadline=defaults.clearAtDeadline == true,
        creaseClock=seconds(options.creaseClock, defaults.creaseClock),
        shotClockStartsAfterClear=startsAfterClear == true,
        faceoffShotClock=seconds(options.faceoffShotClock, defaults.faceoffShotClock),
        shotRecovery=seconds(options.shotRecovery, defaults.shotRecovery),
        recoveryThreshold=seconds(options.recoveryThreshold, defaults.recoveryThreshold),
        overAndBack=id ~= "arcade" and options.overAndBack ~= false,
        shotBoundary=options.shotBoundary or (id == "arcade" and "lastTouch" or "nearest"),
        maxLongPoles=math.floor(limit(options.maxLongPoles, 4, 0, 4)),
        fieldMetrics=fieldMetrics,
        faceoff={difficulty=faceoff.difficulty or options.faceoffDifficulty,
            setTime=faceoff.setTime, duration=faceoff.duration, exitTime=faceoff.exitTime},
    }
end

function Rules.reset(match)
    match.ruleClock = {}
end

function Rules.stop(match)
    Rules.reset(match)
end

local function inOffensiveHalf(match, team, z)
    return P.Midfield.halfAt(match, team, z) == "offense"
end

local function insideOwnCrease(match, team, x, z)
    local goal = match.goalsByTeam and match.goalsByTeam[3-team]
    local radius = match.field and match.field.creaseRadius
    return goal and radius and (x-goal.x)^2 + (z-goal.z)^2 < radius^2
end

local function start(match, holder, shot, source)
    local rules = match.rules
    local team = holder.team
    local needsClear = not inOffensiveHalf(match,team,holder.z)
    local clearing = needsClear or rules.clearAtDeadline and source ~= "rebound"
    match.ruleClock = {
        team=team, shot=shot, clear=needsClear and rules.clearClock or nil,
        advanceTime=clearing and rules.clearClock or nil, ballOver=not needsClear,
        waitingForClear=needsClear and rules.shotClockStartsAfterClear or nil,
        faceoffReturn=not needsClear and rules.profile == "professional"
            and source == "faceoff" and holder.id or nil,
        lastHolder=holder.id,
    }
    if match.ruleClock.waitingForClear then match.ruleClock.shot = nil end
end

function Rules.possession(match, index, source)
    local holder = match.squad[index]
    local clock, rules = match.ruleClock or {}, match.rules
    local team = holder.team
    if clock.team ~= team or clock.expired or source == "faceoff" then
        local initialShot = rules.shotClock
        if initialShot and source == "faceoff" then
            initialShot = math.min(initialShot, rules.faceoffShotClock or initialShot)
        end
        start(match,holder,initialShot,source)
    elseif clock.validShot then
        local shot = rules.shotClock
        if shot and inOffensiveHalf(match,team,holder.z) then
            shot = clock.recoveryShot
        end
        start(match,holder,shot,"rebound")
    else
        if clock.crease and not insideOwnCrease(match,team,holder.x,holder.z) then clock.crease = nil end
        if clock.faceoffReturn ~= holder.id and inOffensiveHalf(match,team,holder.z) then
            clock.faceoffReturn = nil
        end
        if source == "restart" then clock.ballOver = inOffensiveHalf(match,team,holder.z) end
        clock.lastHolder = holder.id
    end
end

function Rules.shotReleased(match, flight)
    local clock = match.ruleClock
    if clock and clock.team == flight.team and flight.kind == "shot" then
        flight.ruleShotTime = clock.shot
    end
end

function Rules.shotContact(match, flight, kind)
    local clock, rules = match.ruleClock, match.rules
    if not clock or clock.team ~= flight.team or clock.expired or not clock.shot
        or flight.kind ~= "shot" or (kind ~= "SAVE" and kind ~= "POST" and kind ~= "CROSSBAR") then
        return
    end
    -- An attempt from behind the goal line does not reset the timer.
    local goal = flight.goal
    if goal and (flight.origin.z-goal.z)*goal.attackSign > 0 then return end
    local shotAt = flight.ruleShotTime or clock.shot + (flight.time or 0)
    local reset = rules.shotRecovery or rules.shotClock
    if rules.recoveryThreshold and shotAt > rules.recoveryThreshold then reset = rules.shotClock end
    clock.validShot, clock.recoveryShot = true, math.min(reset, rules.shotClock)
    clock.shot = clock.recoveryShot
end

local function expire(clock, reason)
    clock.expired = true
    return {reason=reason,team=clock.team,player=clock.lastHolder}
end

local function advance(match, clock, rules, holder, ball, flight, dt)
    local side = P.Midfield.halfAt(match,clock.team,holder and holder.z or ball.z)
    local inOffense = side == "offense"
    if clock.advanceTime then
        clock.advanceTime = math.max(0,clock.advanceTime-dt)
        if clock.advanceTime == 0 or inOffense and not rules.clearAtDeadline then
            if not inOffense then return "clearClock" end
            clock.advanceTime = nil
        end
        clock.clear = not inOffense and clock.advanceTime or nil
    end
    if inOffense then
        clock.ballOver = true
        if clock.waitingForClear then clock.shot = rules.shotClock end
        clock.waitingForClear = nil
    elseif side == "defense" and clock.ballOver then
        clock.ballOver = false
        local ownAction = holder or flight and flight.team == clock.team or match.lastTouch == clock.team
        local fromShot = match.boundaryShot or flight and flight.kind == "shot"
        if rules.overAndBack and not clock.advanceTime and ownAction and not fromShot then
            if clock.faceoffReturn then clock.faceoffReturn = nil
            else return "overAndBack" end
        end
    end
end

function Rules.tick(match, dt)
    if match.phase ~= "LIVE" or dt <= 0 then return end
    local holder = match.carrier and match.squad[match.carrier]
    local clock, rules = match.ruleClock, match.rules
    -- Synchronize when explicit simulation setup supplied the first carrier.
    if holder and (not clock or clock.team ~= holder.team) then
        Rules.possession(match,holder.id)
        clock = match.ruleClock
    end
    if not clock or not clock.team or clock.expired or clock.validShot then return end

    local ball = match.ball.position
    local flight = match.flight
    local violation = advance(match,clock,rules,holder,ball,flight,dt)
    if violation then return expire(clock,violation) end

    if rules.creaseClock then
        if holder and insideOwnCrease(match,clock.team,holder.x,holder.z) then
            clock.crease = math.max(0,(clock.crease or rules.creaseClock)-dt)
            if clock.crease == 0 then return expire(clock,"creaseClock") end
        elseif holder or not (flight and flight.kind == "pass" and flight.team == clock.team
            and insideOwnCrease(match,clock.team,ball.x,ball.z)) then
            clock.crease = nil
        end
    end

    if clock.shot then
        clock.shot = math.max(0,clock.shot-dt)
        if clock.shot == 0 then
            -- Let a released attempt reach the goal or keeper before ruling it late.
            if flight and flight.kind == "shot" and flight.team == clock.team
                and (flight.ruleShotTime or 0) > 0 and flight.time < flight.duration then return end
            return expire(clock,"shotClock")
        end
    end
end
