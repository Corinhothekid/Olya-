-- PolyLax 2.0 | Match and player statistics
PolyLax = PolyLax or {}
local P = PolyLax
local Statistics = {}
P.Statistics = Statistics

local profileKey = "PolyLax.Statistics.2."
local serialKey = profileKey .. "MatchSerial"
local matchSerial
local storedProfiles = {}

local aliases = {faceoffs="faceoffsWon", forcedTurnovers="causedTurnovers"}
local measured = {
    goals=true, assists=true, shots=true, shotsOnGoal=true, saves=true, goalsAllowed=true,
    shotsFaced=true, groundBalls=true, passes=true, completions=true, turnovers=true,
    unforcedTurnovers=true, committedForcedTurnovers=true, causedTurnovers=true,
    interceptions=true, checks=true, pokes=true, slaps=true, bodyChecks=true,
    faceoffAttempts=true, faceoffsWon=true, faceoffViolations=true, faceoffScrambles=true,
    fouls=true, penalties=true, technicalFouls=true, personalFouls=true, penaltySeconds=true,
    clearsAttempted=true, clearsCompleted=true, screens=true, screenAssists=true,
    screenOpenShots=true, illegalScreens=true, screenCoachPoints=true,
    pipeHits=true, blockedShots=true, shotsWide=true, shotsHigh=true, shotsLow=true
}

local function copy(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function increment(values, key, amount)
    values[key] = (values[key] or 0) + amount
end

local function ratio(numerator, denominator)
    if denominator > 0 then return numerator / denominator end
end

local function value(stats, key)
    return stats[key] or 0
end

function Statistics.rates(stats)
    return {
        shootingPct=ratio(value(stats,"goals"),value(stats,"shots")),
        onTargetPct=ratio(value(stats,"shotsOnGoal"),value(stats,"shots")),
        savePct=ratio(value(stats,"saves"),value(stats,"shotsFaced")),
        faceoffPct=ratio(value(stats,"faceoffsWon"),value(stats,"faceoffAttempts")),
        completionPct=ratio(value(stats,"completions"),value(stats,"passes")),
        clearPct=ratio(value(stats,"clearsCompleted"),value(stats,"clearsAttempted")),
        goalsAgainstAvg=ratio(value(stats,"goalsAllowed") * 3600,value(stats,"secondsPlayed"))
    }
end

local function nextId()
    if not matchSerial then
        matchSerial = tonumber(readLocalData and readLocalData(serialKey)) or 0
    end
    matchSerial = matchSerial + 1
    if saveLocalData then pcall(saveLocalData,serialKey,matchSerial) end
    return ("played:%d:%d"):format(os.time(), matchSerial)
end

local function stablePlayerId(teamId, slot, practice)
    if practice then return ("practice:%s:%s"):format(tostring(teamId), tostring(slot)) end
    if P.League and P.League.playerId then return P.League.playerId(teamId, slot) end
    local key = type(teamId) == "number" and ("pll-" .. teamId) or tostring(teamId)
    return ("%s:%s"):format(key, tostring(slot))
end

local function newSide(team, id)
    return {id=id, name=team and team.name or tostring(id), stats={}, roster={}}
end

local function register(statistics, side, id, player, profile)
    local line = {
        playerId=id, teamId=side.id, role=player.role, name=player.name,
        number=player.number or player.rig and player.rig.numberValue, slot=player.slot,
        profile=profile or nil, stats={}
    }
    statistics.players[id] = line
    side.roster[#side.roster+1] = id
    return line
end

function Statistics.new(game, options)
    options = options or {}
    local practice = options.mode == "PRACTICE" or game.homeScore == nil
    local home = game.homeTeam
    local away = game.awayTeam
    local homeId = game.homeId or home and home.id or game.uniform and game.uniform.teamId or options.homeId or "practice"
    local awayId = game.awayId or away and away.id or game.opponentId or options.awayId or "practice-keeper"
    if practice and P.TeamUniform and game.uniform then
        home = P.TeamUniform.get(homeId)
        local keeperKit = P.TeamUniform.forKeeper(game.uniform,game.goalieRole,awayId)
        awayId = keeperKit.teamId
        away = P.TeamUniform.get(awayId)
    end
    local fixture = options.fixture or {}
    local profileId = tostring(options.profileId or "career-player")
    local created = options.profilePlayer or game.careerPlayer or (practice and 1) or 4
    local calendarId = options.fixtureId or fixture.id
    local identity = options.id or calendarId or nextId()
    local statistics = {
        id=identity, mode=options.mode or (practice and "PRACTICE" or game.careerPlayer and "CAREER" or "FULL GAME"),
        source="played", createdAt=os.time(), elapsed=0, players={}, entries={}, events={},
        homeId=homeId, awayId=awayId, sides={newSide(home,homeId),newSide(away,awayId)},
        profileId=profileId, profilePlayer=created, practice=practice,
        fixtureId=calendarId, season=options.season or fixture.season,
        stage=options.stage or fixture.stage, week=options.week or fixture.week,
        postseason=options.postseason or fixture.postseason,
        venueHomeId=fixture.homeId or options.venueHomeId,
        competition=options.competition, venueId=options.venueId
    }
    game.statistics, game.statSummary = statistics, nil
    local rosters
    if not options.useMatchRoster and not practice and P.League and P.League.roster then
        rosters = {P.League.roster(homeId),P.League.roster(awayId)}
    end
    for i, player in ipairs(game.squad) do
        local side = statistics.sides[player.team or 1]
        local id = player.statId or stablePlayerId(side.id, player.slot or i, practice)
        local rosterPlayer = not player.statId and rosters and rosters[player.team or 1][player.slot or i] or player
        local shift = game.specialistShift
        if shift and i==shift.slot then rosterPlayer = shift.idle end
        local line = register(statistics,side,id,rosterPlayer)
        if not (shift and i==shift.slot) then line.number = player.number or line.number end
        statistics.entries[i] = {actor=line, team=player.team or 1}
        if i == created and not options.useMatchRoster then
            local personal = register(statistics,side,profileId,player,true)
            if not game.careerPlayer then
                -- Exhibition and practice use the creator for the whole slot.
                side.roster[#side.roster-1] = personal.playerId
                side.roster[#side.roster] = nil
                statistics.players[line.playerId] = nil
                statistics.entries[i].actor = personal
            end
            statistics.entries[i].profile = personal
        end
    end
    if practice and game.goalie then
        local side = statistics.sides[2]
        local id = stablePlayerId(side.id, "G", true)
        local line = register(statistics,side,id,{name="Practice goalkeeper",role="G",slot=10,
            number=game.goalie.numberValue})
        local index = #game.squad + 1
        statistics.entries[index] = {actor=line,team=2}
        statistics.practiceKeeper = index
    end
    return statistics
end

local function participant(game, playerIndex)
    local statistics = game.statistics
    local entry = statistics and statistics.entries[playerIndex]
    if not entry then return nil end
    if entry.profile and not game.careerWaiting and not game.careerOnBench then return entry.profile, entry.team end
    return entry.actor, entry.team
end

function Statistics.tick(game, dt)
    local statistics = game.statistics
    if not statistics or statistics.summary or dt <= 0 then return end
    local opening = statistics.elapsed == 0
    statistics.elapsed = statistics.elapsed + dt
    for i, entry in ipairs(statistics.entries) do
        local line = participant(game,i)
        local athlete = game.squad[i]
        if line and entry and (not athlete or athlete.active ~= false and not athlete.suspended) then
            local stats = line.stats
            stats.gamesPlayed = 1
            if opening then stats.gamesStarted = 1 end
            increment(stats,"secondsPlayed",dt)
        end
    end
end

local function safeMetadata(game, metadata)
    if type(metadata) ~= "table" then return nil end
    local detail = {}
    for key, value in pairs(metadata) do
        local kind = type(value)
        if type(key) == "string" and (kind == "boolean" or kind == "string" or kind == "number"
            and value == value and math.abs(value) < math.huge) then
            if key == "other" or key == "target" or key == "user" or key == "defender" then
                local actor = participant(game,value)
                detail[key] = actor and actor.playerId or value
            else
                detail[key] = value
            end
        end
    end
    return detail
end

local function recordFor(game, line, team, key, amount, metadata)
    local statistics = game.statistics
    if not statistics or statistics.summary or key == "score" then return false end
    key = aliases[key] or key
    amount = tonumber(amount) or 1
    if not line or not measured[key] or amount == 0 or amount ~= amount or math.abs(amount) == math.huge then
        return false
    end
    if amount < 0 and key ~= "screenCoachPoints" then return false end
    increment(line.stats,key,amount)
    increment(statistics.sides[team].stats,key,amount)
    line.stats.gamesPlayed = 1
    local events = statistics.events
    events[#events+1] = {event=key, playerId=line.playerId, teamId=line.teamId, amount=amount,
        time=statistics.elapsed, detail=safeMetadata(game,metadata)}
    return true
end

function Statistics.record(game, playerIndex, key, amount, metadata)
    local player, team = participant(game,playerIndex)
    return recordFor(game,player,team,key,amount,metadata)
end

function Statistics.penalty(game, playerIndex, kind, seconds, metadata)
    local detail = copy(metadata)
    detail.foulType = kind
    Statistics.record(game,playerIndex,"penalties",1,detail)
    if kind == "technical" then Statistics.record(game,playerIndex,"technicalFouls")
    elseif kind == "personal" then Statistics.record(game,playerIndex,"personalFouls") end
    if seconds and seconds > 0 then Statistics.record(game,playerIndex,"penaltySeconds",seconds) end
end

local function recordTurnover(game, line, team, reason, by, byTeam)
    if not line then return end
    local detail = {reason=reason,other=by and by.playerId}
    recordFor(game,line,team,"turnovers",1,detail)
    recordFor(game,line,team,by and "committedForcedTurnovers" or "unforcedTurnovers",1,detail)
    if by then recordFor(game,by,byTeam,"causedTurnovers",1,{reason=reason,other=line.playerId}) end
end

function Statistics.turnover(game, playerIndex, reason, forcedBy)
    local line, team = participant(game,playerIndex)
    local by, byTeam = participant(game,forcedBy)
    recordTurnover(game,line,team,reason,by,byTeam)
end

function Statistics.deferTurnover(game, playerIndex, reason, forcedBy)
    local statistics = game.statistics
    local line, team = participant(game,playerIndex)
    if statistics and not statistics.summary and line then
        local by, byTeam = participant(game,forcedBy)
        statistics.turnover = {line=line,team=team,reason=reason,by=by,byTeam=byTeam}
    end
end

function Statistics.possession(game, playerIndex)
    local statistics = game.statistics
    if not statistics then return end
    local pending = statistics.turnover
    local _, team = participant(game,playerIndex)
    if pending and team and team ~= pending.team then
        recordTurnover(game,pending.line,pending.team,pending.reason,pending.by,pending.byTeam)
    end
    statistics.turnover = nil
end

function Statistics.resetPossession(game)
    if game.statistics then game.statistics.turnover = nil end
end

function Statistics.goalkeeper(game, playerIndex, result, other)
    local detail = {other=other,result=result}
    if result == "save" or result == "goal" then
        Statistics.record(game,playerIndex,"shotsFaced",1,detail)
        Statistics.record(game,playerIndex,result == "save" and "saves" or "goalsAllowed",1,detail)
    elseif result == "block" then
        Statistics.record(game,playerIndex,"blockedShots",1,detail)
    end
end

local function exported(values)
    local stats = copy(values)
    stats.faceoffs = stats.faceoffsWon or 0
    stats.forcedTurnovers = stats.causedTurnovers or 0
    stats.points = (stats.goals or 0) + (stats.assists or 0)
    stats.minutesPlayed = (stats.secondsPlayed or 0) / 60
    stats.penaltyMinutes = (stats.penaltySeconds or 0) / 60
    return stats
end

function Statistics.playerOfGame(summary)
    local best, bestScore = nil, -math.huge
    for _, player in pairs(summary.players) do
        local stats = player.stats
        if value(stats,"gamesPlayed") > 0 then
            local score = value(stats,"goals")*5 + value(stats,"assists")*3.5
                + value(stats,"saves")*1.7 - value(stats,"goalsAllowed")*.8
                + value(stats,"groundBalls")*.88 + value(stats,"causedTurnovers")*2.4
                + value(stats,"faceoffsWon")*1.65 - value(stats,"faceoffAttempts")*.5
                + value(stats,"screenAssists")*.85 - value(stats,"turnovers")*.95
                - value(stats,"penaltySeconds")/90
            if score > bestScore or score == bestScore and player.playerId < best.playerId then
                best, bestScore = player, score
            end
        end
    end
    return best
end

local function snapshot(game, options, final)
    local data = game.statistics
    options = options or {}
    local fixture = options.fixture or {}
    local result = {final=final or nil, competition=options.competition or data.competition,
        venueId=options.venueId or data.venueId}
    result.id, result.source, result.mode = data.id, data.source, data.mode
    result.profileId, result.date, result.elapsed = data.profileId, data.createdAt, data.elapsed
    result.homeId, result.awayId = data.homeId, data.awayId
    result.homeScore = game.homeScore or game.goals or 0
    result.awayScore = game.awayScore or 0
    result.result = data.practice and "PRACTICE" or result.homeScore > result.awayScore and "WIN"
        or result.homeScore < result.awayScore and "LOSS" or "DRAW"
    result.fixtureId = options.fixtureId or fixture.id or data.fixtureId
    result.season = options.season or fixture.season or data.season
    result.stage = options.stage or fixture.stage or data.stage
    result.week = options.week or fixture.week or data.week
    result.postseason = options.postseason or fixture.postseason or data.postseason
    result.events, result.players, result.teams, result.sides = copy(data.events), {}, {}, {}
    for id, line in pairs(data.players) do
        local player = copy(line)
        player.stats = exported(line.stats)
        player.rates = Statistics.rates(player.stats)
        result.players[id] = player
    end
    for index, line in ipairs(data.sides) do
        local team = copy(line)
        team.roster = copy(line.roster)
        team.stats = exported(line.stats)
        team.stats.secondsPlayed = data.elapsed
        team.stats.minutesPlayed = data.elapsed / 60
        team.rates = Statistics.rates(team.stats)
        result.teams[tostring(team.id)] = team.stats
        result.sides[index] = team
    end
    if final and not data.practice then
        for index, team in ipairs(result.sides) do
            local won = (index == 1 and result.homeScore > result.awayScore)
                or (index == 2 and result.awayScore > result.homeScore)
            local decision = result.homeScore == result.awayScore and "ties" or won and "wins" or "losses"
            team.stats[decision] = 1
            local keeper, minutes = nil, 0
            for _, id in ipairs(team.roster) do
                local line = result.players[id]
                local played = line.stats.secondsPlayed or 0
                if line.role == "G" and played > minutes then keeper, minutes = line, played end
            end
            if keeper then keeper.stats[decision] = 1 end
        end
    end
    local venueHome = options.venueHomeId or fixture.homeId or data.venueHomeId
    if venueHome == result.awayId and venueHome ~= result.homeId then
        result.homeId, result.awayId = result.awayId, result.homeId
        result.homeScore, result.awayScore = result.awayScore, result.homeScore
        result.sides[1], result.sides[2] = result.sides[2], result.sides[1]
    end
    local player = final and not data.practice and Statistics.playerOfGame(result)
    result.playerOfGame = player and player.playerId
    return result
end

function Statistics.matchSummary(game, options)
    local data = game and game.statistics
    if not data then return nil end
    if type(options) == "string" then options = {fixtureId=options} end
    return data.summary or snapshot(game,options)
end

function Statistics.profile(id)
    id = tostring(id or "career-player")
    if storedProfiles[id] then return storedProfiles[id] end
    local key = profileKey .. id
    local payload = readLocalData and readLocalData(key)
    local profile
    if type(payload) == "string" and json and json.decode then
        local okay, value = pcall(json.decode,payload)
        if okay and type(value) == "table" and type(value.matches) == "table"
            and type(value.order) == "table" then profile = value end
    end
    profile = profile or {id=id,matches={},order={}}
    storedProfiles[id] = profile
    return profile
end

function Statistics.saveSummary(summary)
    local profile = Statistics.profile(summary.profileId)
    if profile.matches[summary.id] then return true end
    local entry = copy(summary)
    entry.events = nil
    local nextProfile = {id=profile.id,matches=copy(profile.matches),order=copy(profile.order)}
    nextProfile.matches[entry.id] = entry
    nextProfile.order[#nextProfile.order+1] = entry.id
    if saveLocalData and json and json.encode then
        local ok, bytes = pcall(json.encode,nextProfile)
        if not ok then return false end
        local saved, returned = pcall(saveLocalData,profileKey .. profile.id,bytes)
        if not saved or returned == false then return false end
    end
    profile.matches, profile.order = nextProfile.matches, nextProfile.order
    return true
end

function Statistics.finalize(game, options)
    local data = game and game.statistics
    if not data then return nil end
    if not data.summary then
        data.summary = snapshot(game,options,true)
        game.statSummary = data.summary
    end
    if not data.saved and not (options and options.persist == false)
        and not (game.statisticsOptions and game.statisticsOptions.persist == false) then
        data.saved = Statistics.saveSummary(data.summary)
    end
    return data.summary
end
