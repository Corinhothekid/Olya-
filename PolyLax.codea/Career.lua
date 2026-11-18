-- PolyLax Build 013 | Road to the Pros player profile and match handoff
PolyLax = PolyLax or {}
local P = PolyLax
local Career = {}
P.Career = Career

local saveKey = "PolyLax.Career.1"
local statKeys = {"goals", "assists", "saves", "groundBalls", "faceoffs",
    "causedTurnovers", "interceptions", "shots", "completions", "turnovers", "fouls",
    "screens", "screenAssists", "screenOpenShots", "illegalScreens"}
Career.statKeys = statKeys

Career.positions = {
    {label="Attack", slot=1, attributes={shooting=68, ballSecurity=67, speed=69, strength=64}},
    {label="Midfield", slot=5, attributes={speed=72, stamina=71, passing=65, strength=66}},
    {label="Defense", slot=7, attributes={stickCheck=72, bodyCheck=70, interception=70, strength=73}},
    {label="Faceoff", slot=4, attributes={faceoff=76, reaction=69, stamina=70, strength=70}},
    {label="Goalie", slot=10, attributes={reflexes=75, handSpeed=74, clearingAccuracy=68, strength=62}}
}

local baseAttributes = {
    shooting=57, ballSecurity=58, speed=61, passing=58, stamina=60, faceoff=51,
    reaction=58, bodyCheck=56, stickCheck=56, interception=56,
    reflexes=55, handSpeed=54, clearingAccuracy=57, strength=60
}

Career.stages = {highSchool="HIGH SCHOOL", college="COLLEGE", professional="PROFESSIONAL"}

local function position(index)
    return Career.positions[index] or Career.positions[2]
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function defaults(index)
    return P.Attributes.forPosition(index)
end

local function nameOf(value)
    return type(value) == "string" and value:sub(1, 24):gsub("[%c]", "") or ""
end

local function bounded(value, min, max)
    return math.max(min, math.min(max, math.floor(tonumber(value) or min)))
end

local function careerStats(stats)
    if type(stats) ~= "table" then stats = {} end
    for _, key in ipairs(statKeys) do stats[key] = bounded(stats[key], 0, 1000000) end
    stats.screenCoachPoints = bounded(tonumber(stats.screenCoachPoints) or 0, -1000000, 1000000)
    return stats
end

function Career.new()
    return {version=1, name="New Player", position=2, stage="highSchool", team="briarbank",
        season=1, games=0, wins=0, losses=0, ties=0, xp=0, stats=careerStats(), entries={},
        attributes=defaults(2)}
end

function Career.load()
    local fresh = Career.new()
    local raw = readLocalData and readLocalData(saveKey)
    if type(raw) ~= "string" or not json then return fresh end
    local ok, saved = pcall(json.decode, raw)
    if not ok or type(saved) ~= "table" or saved.version ~= fresh.version then return fresh end
    saved.position = bounded(saved.position, 1, #Career.positions)
    saved.name = nameOf(saved.name)
    if saved.name == "" then saved.name = fresh.name end
    if not Career.stages[saved.stage] then saved.stage = fresh.stage end
    if type(saved.team) ~= "string" and type(saved.team) ~= "number" then saved.team = fresh.team end
    local school = P.SchoolTeams.get(saved.team)
    if saved.stage == "highSchool" and (not school or school.group ~= "highSchool") then
        saved.team = fresh.team
    elseif saved.stage == "college" and (not school or school.group == "highSchool") then
        saved.team = "syracuse"
    elseif saved.stage == "professional" then
        saved.team = bounded(saved.team, 1, #P.TeamUniform.teams)
    elseif school then
        saved.team = school.id
    end
    for _, key in ipairs({"games", "wins", "losses", "ties", "xp"}) do
        saved[key] = bounded(saved[key], 0, 1000000)
    end
    saved.season = bounded(saved.season, 1, 10000)
    saved.championships = bounded(saved.championships, 0, 10000)
    saved.spentXP = bounded(saved.spentXP, 0, saved.xp)
    if saved.stage == "professional" then
        local contract = type(saved.contract) == "table" and saved.contract or {}
        saved.contract = {length=bounded(contract.length,1,5),remaining=bounded(contract.remaining,0,5),
            value=bounded(contract.value,0,1000000)}
    else
        saved.contract = nil
    end
    saved.history = type(saved.history) == "table" and saved.history or {}
    saved.attributes=P.Attributes.restore(saved.attributes,saved.position)
    saved.stats = careerStats(saved.stats)
    saved.entries = type(saved.entries) == "table" and saved.entries or {}
    return saved
end

function Career.save(career)
    if not saveLocalData or not json then return false end
    local ok, raw = pcall(json.encode, career)
    if not ok then return false end
    return pcall(saveLocalData, saveKey, raw)
end

function Career.rename(career, value)
    local name = nameOf(value):match("^%s*(.-)%s*$")
    if name == "" then return false end
    career.name = name
    return Career.save(career)
end

function Career.setPosition(career, index)
    if career.games > 0 or not Career.positions[index] then return false end
    career.position, career.attributes = index, defaults(index)
    return Career.save(career)
end

function Career.teamName(career)
    return P.TeamUniform.get(career.team).name
end

function Career.cycleSchool(career)
    if career.games > 0 or career.stage ~= "highSchool" then return false end
    local list = P.SchoolTeams.highSchool
    for index, school in ipairs(list) do
        if school.id == career.team then
            career.team = list[index % #list+1].id
            return Career.save(career)
        end
    end
    return false
end

function Career.fixture(career)
    return P.CareerSeason.fixture(career)
end

function Career.matchOptions(career, fixture)
    local home = P.TeamUniform.get(career.team)
    local age = home.ruleset
    return {name="Career short game", periods=2, periodLength=60, intermissionTime=2,
        ageGroup=age, bodyContact=age == "highSchool" or age == "adult",
        faceoffDifficulty=career.stage == "professional" and "HARD" or "NORMAL",
        careerEntryDelay=P.CareerSeason.status(career).starter and 0 or 4,
        fieldTeam=fixture.home and career.team or fixture.opponent, venueAway=not fixture.home,
        careerPlayerSlot=position(career.position).slot, playerName=career.name,
        playerAttributes=copy(career.attributes)}
end

local function screenEvaluation(events)
    local result, points = {}, 0
    for _, item in ipairs(type(events) == "table" and events or {}) do
        if type(item) == "table" and type(item.kind) == "string" and item.kind ~= ""
            and type(item.points) == "number" and item.points % 1 == 0 then
            local eventPoints = bounded(item.points, -100, 100)
            local event = {kind=item.kind:sub(1, 40), points=eventPoints}
            if type(item.time) == "number" and item.time >= 0 and item.time < math.huge then
                event.time = item.time
            end
            result[#result+1] = event
            points = points + eventPoints
        end
    end
    return result, points
end

function Career.record(career, fixture, match)
    if not fixture or not match or match.phase ~= "FINAL" then return false end
    if career.entries[fixture.id] then return false end
    local player = match.squad[match.careerPlayer]
    if not player then return false end
    local nextSave = copy(career)
    nextSave.stats, nextSave.entries = copy(career.stats), copy(career.entries)
    local personal, oldStats = {}, player.stats or {}
    for _, key in ipairs(statKeys) do
        local value = oldStats[key]
        if key == "causedTurnovers" then value = value or oldStats.forcedTurnovers end
        value = bounded(value, 0, 10000)
        personal[key] = value
        nextSave.stats[key] = (career.stats[key] or 0) + value
    end
    local screenEvents, coachPoints = screenEvaluation(player.screenCoachEvents)
    personal.screenCoachPoints = coachPoints
    nextSave.stats.screenCoachPoints = (career.stats.screenCoachPoints or 0) + coachPoints
    local win = match.homeScore > match.awayScore
    local tie = match.homeScore == match.awayScore
    nextSave.games = nextSave.games + 1
    if win then nextSave.wins = nextSave.wins + 1
    elseif tie then nextSave.ties = nextSave.ties + 1
    else nextSave.losses = nextSave.losses + 1 end
    local earned = 20 + (win and 10 or 0) + personal.goals * 6
        + personal.assists * 5 + personal.saves * 3 + personal.faceoffs * 4
        + personal.groundBalls * 2 + personal.causedTurnovers * 4 + personal.interceptions * 3
    nextSave.xp = nextSave.xp + earned
    P.Development.onMatch(nextSave,fixture,personal,match)
    if not P.CareerSeason.record(nextSave, fixture, match, earned, personal, screenEvents) then
        return false, "This result does not match the scheduled game"
    end
    nextSave.entries[fixture.id] = {home=match.homeScore, away=match.awayScore,
        opponent=fixture.opponent, stats=personal, screenCoachEvents=screenEvents}
    if not Career.save(nextSave) then return false, "Save unavailable" end
    for key, value in pairs(nextSave) do career[key] = value end
    return true
end
