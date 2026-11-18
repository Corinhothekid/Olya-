-- PolyLax 2.0 | Competition profiles, stable rosters, schedules, and CPU box scores
PolyLax = PolyLax or {}
local P = PolyLax
local League = {}
P.League = League

-- Each competition is a condensed PolyLax format. School/PLL identities do not
-- imply that the game uses the organization's official fixtures or tournament rules.
League.profiles = {
    highSchool={id="high-school", name="High School", conference="PolyLax Scholastic League",
        rosterGroup="highSchool", qualified=4, periods=4, minutes=12, pace=30},
    ncaa={id="ncaa-d1", name="NCAA Division I", conference="PolyLax D1 Pool",
        rosterGroup="ncaa", qualified=8, periods=4, minutes=15, pace=38},
    club={id="mcla-club", name="College Club", conference="PolyLax Club League",
        rosterGroup="clubLeague", qualified=2, periods=4, minutes=15, pace=35},
    professional={id="pro", name="Professional", conference="PolyLax Pro League",
        rosterGroup="pll", qualified=6, periods=4, minutes=12, pace=41}
}

function League.profile(stage, teamId)
    if stage == "college" then
        local team = P.SchoolTeams.get(teamId)
        return team and team.group == "club" and League.profiles.club or League.profiles.ncaa
    end
    return League.profiles[stage] or League.profiles.highSchool
end

function League.teams(profile)
    if profile.rosterGroup == "pll" then return P.TeamUniform.teams end
    return P.SchoolTeams[profile.rosterGroup]
end

local givenNames = {"Avery","Blake","Brooks","Cameron","Casey","Cole","Drew","Eli","Emmett",
    "Finn","Hayden","Jaden","Jordan","Jules","Kai","Logan","Luca","Miles","Morgan","Nico",
    "Owen","Quinn","Reed","Remy","Rory","Sam","Shay","Tate","Theo","Wes"}
local familyNames = {"Alden","Archer","Avery","Bennett","Blaine","Byrne","Carter","Chen","Clarke",
    "Collins","Corbett","Dawson","Ellis","Foster","Grant","Han","Hayes","Holt","Keller","Kim",
    "Lane","Lowe","Marin","Mercer","Nolan","Parks","Patel","Quill","Reyes","Sato","Shaw",
    "Sloan","Stone","Vega","Wells","Wong","Young","Yu"}
local slots = {{"A",11},{"A",12},{"A",13},{"M",20,"FOGO"},{"M",21},{"M",22},
    {"D",30},{"D",31},{"D",32},{"G",1}}
local rosters = {}

local function hash(text)
    local state = 137
    for index=1,#text do state = (state*257 + text:byte(index)) % 2147483647 end
    return math.max(1,state)
end

local function randomSource(text)
    local state = hash(text)
    return function()
        state = state * 48271 % 2147483647
        return state / 2147483647
    end
end

function League.teamKey(teamId)
    local team = P.TeamUniform.get(teamId)
    return type(team.id) == "number" and ("pll-"..team.id) or team.id
end

function League.playerId(teamId, slot)
    return League.teamKey(teamId)..":"..slot
end

function League.roster(teamId)
    local team = P.TeamUniform.get(teamId)
    local key = League.teamKey(team.id)
    if rosters[key] then return rosters[key] end
    local roster, usedNames = {}, {}
    for slot, spec in ipairs(slots) do
        local id = League.playerId(team.id,slot)
        local roll = randomSource(id)
        local name
        repeat
            name = givenNames[math.floor(roll()*#givenNames)+1].." "..
                familyNames[math.floor(roll()*#familyNames)+1]
        until not usedNames[name]
        usedNames[name] = true
        roster[slot] = {playerId=id, name=name, number=spec[2], role=spec[1], specialty=spec[3],
            teamId=team.id, slot=slot, rating=58+math.floor(roll()*28),
            debutSeason=type(team.id) == "number" and (3+hash(id..":entry")%5) or nil}
    end
    rosters[key] = roster
    return roster
end

function League.venue(teamId)
    local team = P.TeamUniform.get(teamId)
    return {id=League.teamKey(team.id)..":home", name=team.name.." Home Field", teamId=team.id,
        theme=team.field}
end

function League.team(teamId)
    local team = P.TeamUniform.get(teamId)
    local stage = type(team.id) == "number" and "professional"
        or team.group == "highSchool" and "highSchool" or "college"
    local competition = League.profile(stage,team.id)
    return {id=team.id, key=League.teamKey(team.id), name=team.name, short=team.short,
        competition=competition.id, conference=competition.conference, home=team.home, away=team.away,
        venue=League.venue(team.id), roster=League.roster(team.id)}
end

function League.schedule(profile, season)
    local wheel, ranks, rounds = {}, {}, {}
    for index, team in ipairs(League.teams(profile)) do
        wheel[index], ranks[team.id] = team.id, index
    end
    local size = #wheel
    if size % 2 > 0 then wheel[#wheel+1] = false end
    for week=1,#wheel-1 do
        local games = {}
        for index=1,math.floor(#wheel*.5) do
            local home, away = wheel[index], wheel[#wheel+1-index]
            if home and away then
                local gap = (ranks[away]-ranks[home]) % size
                local swap = gap > math.floor(size/2)
                    or size % 2 == 0 and gap == size/2 and ranks[home] > ranks[away]
                if swap == (season % 2 == 1) then home, away = away, home end
                games[#games+1] = {home=home,away=away}
            end
        end
        rounds[week] = games
        table.insert(wheel,2,table.remove(wheel))
    end
    return rounds
end

local function increment(line, key, amount)
    line[key] = (line[key] or 0) + (amount or 1)
end

local offense = {1,2,3,5,6,1,2,3,5,6,1,2,3,4,7}
local attack = {1,1,1,2,2,2,3,3,3,5,5,6,6,4,7}
local defense = {7,7,8,8,9,9,5,6,4}

local function pick(roll, pool)
    return pool[math.floor(roll()*#pool)+1]
end

local function makeSide(box, profile, teamId, season)
    local side = {id=teamId, lines={}, roster={}, score=0}
    local clock = profile.minutes * profile.periods * 60
    for index, player in ipairs(League.roster(teamId)) do
        local time = player.role == "G" and clock or math.floor(clock * (.55 + player.rating*.004))
        local line = {playerId=player.playerId, teamId=teamId, role=player.role, name=player.name,
            number=player.number, slot=index, stats={gamesPlayed=1,gamesStarted=1,secondsPlayed=time,
                minutesPlayed=time/60}, rookie=player.debutSeason and player.debutSeason == season or nil}
        box.players[player.playerId] = line
        side.lines[index], side.roster[index] = line.stats, player.playerId
    end
    return side
end

local function possession(roll, side, opposing, efficiency)
    local facilitator, shooter = pick(roll,offense), pick(roll,attack)
    local pass = side.lines[facilitator]
    local shot, goalie = side.lines[shooter], opposing.lines[10]
    local defenders = opposing.lines[pick(roll,defense)]
    increment(pass,"passes")
    if roll() < .18 - efficiency*.1 then
        increment(pass,"turnovers")
        if roll() < .68 then
            increment(pass,"committedForcedTurnovers")
            increment(defenders,"causedTurnovers")
            increment(defenders,"checks")
            if roll() < .35 then increment(defenders,"interceptions") end
        else
            increment(pass,"unforcedTurnovers")
        end
        increment(defenders,"groundBalls")
        return
    end
    increment(pass,"completions")
    if roll() < .30 then increment(side.lines[pick(roll,offense)],"groundBalls") end
    if roll() < .21 then return end
    increment(shot,"shots")
    if roll() > .66 + efficiency*.36 then return end
    increment(shot,"shotsOnGoal")
    increment(goalie,"shotsFaced")
    if roll() > .54 + efficiency*.56 then
        increment(goalie,"saves")
        increment(goalie,"clearsAttempted")
        if roll() < .83 then increment(goalie,"clearsCompleted") end
        return
    end
    side.score = side.score + 1
    increment(shot,"goals")
    increment(goalie,"goalsAllowed")
    if facilitator ~= shooter and roll() < .76 then increment(pass,"assists") end
end

local function sumSide(box, side, opponent)
    local decision = side.score == opponent.score and "ties" or side.score > opponent.score and "wins" or "losses"
    side.lines[10][decision] = 1
    local totals = {}
    local rates = P.Statistics and P.Statistics.rates
    for index, line in ipairs(side.lines) do
        local points = (line.goals or 0) + (line.assists or 0)
        if points > 0 then line.points = points end
        for key,value in pairs(line) do increment(totals,key,value) end
        if rates then box.players[side.roster[index]].rates = rates(line) end
    end
    totals.secondsPlayed,totals.minutesPlayed = box.elapsed,box.elapsed/60
    box.teams[tostring(side.id)] = totals
    return {id=side.id,name=P.TeamUniform.get(side.id).name,roster=side.roster,stats=totals,
        rates=rates and rates(totals)}
end

function League.simulate(profile, game)
    local id, homeId, awayId = game.id, game.homeId, game.awayId
    assert(homeId ~= awayId and id, "Simulated fixtures require distinct teams and a stable ID")
    local roll = randomSource(id.."/"..tostring(homeId).."/"..tostring(awayId))
    local box = {id=id, source="simulated", mode="LEAGUE", final=true,
        elapsed=profile.minutes*profile.periods*60, competition=profile.id, season=game.season,
        stage=game.stage, week=game.week, postseason=game.postseason, venueId=League.venue(homeId).id,
        homeId=homeId, awayId=awayId, players={}, teams={}}
    local home, away = makeSide(box,profile,homeId,game.season), makeSide(box,profile,awayId,game.season)
    local efficiency = (League.roster(homeId)[1].rating-League.roster(awayId)[1].rating)*.006
    local turns = profile.pace + math.floor(roll()*9) - 4
    for _=1,turns do
        possession(roll,home,away,efficiency+.045)
        possession(roll,away,home,-efficiency)
    end
    if game.postseason and home.score == away.score then
        local leading, other = home, away
        if roll() < .48 then leading, other = away, home end
        -- Use a scoring shot and shot-faced event for the deciding goal.
        local scorer = leading.lines[pick(roll,attack)]
        increment(scorer,"shots")
        increment(scorer,"shotsOnGoal")
        increment(scorer,"goals")
        increment(other.lines[10],"shotsFaced")
        increment(other.lines[10],"goalsAllowed")
        leading.score = leading.score+1
    end
    local drawEdge = (League.roster(homeId)[4].rating-League.roster(awayId)[4].rating)*.005
    for _=1,home.score+away.score+profile.periods do
        increment(home.lines[4],"faceoffAttempts")
        increment(away.lines[4],"faceoffAttempts")
        local winner = roll() < .5+drawEdge and home or away
        increment(winner.lines[4],"faceoffsWon")
        increment(winner.lines[4],"groundBalls")
    end
    box.homeScore, box.awayScore = home.score, away.score
    box.sides = {sumSide(box,home,away),sumSide(box,away,home)}
    return box
end
