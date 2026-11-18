-- PolyLax 2.0 | Competition calendar, postseason, and career progression
PolyLax = PolyLax or {}
local P = PolyLax
local Season = {}
P.CareerSeason = Season

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function commit(career, candidate)
    if not P.Career.save(candidate) then return false end
    for key in pairs(career) do
        if candidate[key] == nil then career[key] = nil end
    end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

function Season.competition(career)
    return P.League.profile(career.stage,career.team)
end

local function newSeason(career)
    local profile, records = Season.competition(career), {}
    for _, team in ipairs(P.League.teams(profile)) do
        records[tostring(team.id)] = {id=team.id,wins=0,losses=0,ties=0,differential=0}
    end
    return {team=career.team, stage=career.stage, season=career.season, week=1, phase="regular",
        rounds=P.League.schedule(profile,career.season), records=records, results={},
        playoffs={}, personal={}, gameBoxes={}, games=0, xp=0,
        screenCoachCounts={}, wins=0, losses=0, ties=0, replay=0}
end

local function state(career)
    local data = career.seasonData
    if type(data) ~= "table" or data.team ~= career.team or data.stage ~= career.stage
        or data.season ~= career.season or type(data.records) ~= "table"
        or type(data.rounds) ~= "table" or type(data.results) ~= "table"
        or type(data.week) ~= "number" or type(data.playoffs) ~= "table" then
        data = newSeason(career)
        career.seasonData = data
    end
    if type(data.personal) ~= "table" then data.personal = {} end
    if type(data.screenCoachCounts) ~= "table" then data.screenCoachCounts = {} end
    if type(data.gameBoxes) ~= "table" then data.gameBoxes = {} end
    return data
end

local function fixtureID(career, suffix)
    return career.stage .. "-" .. career.season .. "-" .. suffix
end

local function regularFixture(career, data, week)
    for _, game in ipairs(data.rounds[week] or {}) do
        if game.home == career.team or game.away == career.team then
            local home = game.home == career.team
            local venue = P.League.venue(game.home)
            return {id=fixtureID(career, "w"..week), opponent=home and game.away or game.home,
                home=home, homeId=game.home, awayId=game.away, label="Week "..week, week=week,
                site=venue.name, venueId=venue.id, stage=career.stage, season=career.season}
        end
    end
end

local function ranked(data)
    local order = {}
    for _, record in pairs(data.records) do
        local row = copy(record)
        row.name = P.TeamUniform.get(row.id).name
        row.points = 2*row.wins + row.ties
        order[#order+1] = row
    end
    table.sort(order, function(a,b)
        if a.points ~= b.points then return a.points>b.points end
        if a.differential ~= b.differential then return a.differential>b.differential end
        return tostring(a.id)<tostring(b.id)
    end)
    return order
end

local function leagueResult(data, a, b, home, away)
    local first, second = data.records[tostring(a)], data.records[tostring(b)]
    first.differential = first.differential + home-away
    second.differential = second.differential + away-home
    if home > away then first.wins,second.losses=first.wins+1,second.losses+1
    elseif home < away then first.losses,second.wins=first.losses+1,second.wins+1
    else first.ties,second.ties=first.ties+1,second.ties+1 end
end

local function simulate(career, data, label, homeId, awayId, week, postseason)
    local id = fixtureID(career,label.."-"..P.League.teamKey(homeId).."-"..P.League.teamKey(awayId))
    local box = data.gameBoxes[id]
    if not box then
        box = P.League.simulate(Season.competition(career), {
            id=id, season=career.season, stage=career.stage, week=week, postseason=postseason,
            homeId=homeId, awayId=awayId
        })
        data.gameBoxes[id] = box
    end
    return box
end

local function weekResults(career, data, week, actual)
    for _, pair in ipairs(data.rounds[week]) do
        local box = actual
        if pair.home ~= career.team and pair.away ~= career.team then
            box = simulate(career,data,"w"..week,pair.home,pair.away,week)
        end
        leagueResult(data,pair.home,pair.away,box.homeScore,box.awayScore)
    end
end

local function complete(career, data, title)
    data.phase = "complete"
    if title then career.championships = (career.championships or 0) + 1 end
    data.titleWon = title == true
    if career.contract then
        career.contract.remaining = math.max(0,career.contract.remaining-1)
    end
end

local postseasonLabels = {quarterfinal="Quarterfinal", semifinal="Semifinal", final="Championship"}

local function phaseLabel(phase)
    local size = phase:match("^round%-of%-(%d+)$")
    return postseasonLabels[phase] or (size and "Round of "..size) or phase
end

local function postseasonName(phase)
    return phase == "final" and "championship" or phase
end

local function winner(box)
    return box.homeScore > box.awayScore and box.homeId or box.awayId
end

local function playoffGame(career, home, away, phase)
    local venue = P.League.venue(home)
    return {home=home == career.team, opponent=home == career.team and away or home,
        label=phaseLabel(phase), phase=phase, postseason=postseasonName(phase),
        homeId=home,awayId=away,site=venue.name, venueId=venue.id, stage=career.stage,season=career.season}
end

local function openBracketRound(career, data, remaining)
    local bracket = data.bracket
    while #remaining > 1 do
        table.sort(remaining,function(a,b) return bracket.seeds[tostring(a)] < bracket.seeds[tostring(b)] end)
        local capacity = 2
        while capacity < #remaining do capacity = capacity*2 end
        local phase = capacity == 2 and "final" or capacity == 4 and "semifinal"
            or capacity == 8 and "quarterfinal" or "round-of-"..capacity
        local byeCount = capacity - #remaining
        local pending = {}
        for index=1,byeCount do pending[index] = remaining[index] end
        bracket.userIndex, bracket.pending = nil, pending
        for index=1,(#remaining-byeCount)/2 do
            local home,away = remaining[byeCount+index],remaining[#remaining+1-index]
            if home == career.team or away == career.team then
                data.playoffs[#data.playoffs+1] = playoffGame(career,home,away,phase)
                bracket.userIndex = #data.playoffs
            else
                local box = simulate(career,data,phase,home,away,nil,postseasonName(phase))
                pending[#pending+1] = winner(box)
            end
        end
        if bracket.userIndex then
            data.phase, data.replay = phase, 0
            return
        end
        remaining = pending
    end
    data.champion = remaining[1]
    complete(career,data,data.champion == career.team)
end

local function advanceRegular(career, data)
    while data.week <= #data.rounds and not regularFixture(career,data,data.week) do
        weekResults(career,data,data.week)
        data.week = data.week+1
    end
    if data.week <= #data.rounds then return end
    local order, seeds, remaining = ranked(data), {}, {}
    local qualified = math.min(#order, math.max(2, Season.competition(career).qualified))
    for index=1,qualified do
        local id = order[index].id
        seeds[tostring(id)], remaining[index] = index, id
    end
    data.bracket = {seeds=seeds}
    openBracketRound(career,data,remaining)
end

function Season.fixture(career)
    local data = state(career)
    if data.phase == "regular" then advanceRegular(career,data) end
    if data.phase == "regular" then return regularFixture(career,data,data.week) end
    local stage = data.bracket and data.phase ~= "complete" and data.bracket.userIndex
        or data.phase == "semifinal" and 1 or data.phase == "final" and 2
    if not stage then return end
    local game = copy(data.playoffs[stage])
    game.id = fixtureID(career,data.phase.."-"..data.replay)
    game.phase, game.postseason = data.phase,postseasonName(data.phase)
    if not game.site then
        game.homeId = game.home and career.team or game.opponent
        game.awayId = game.home and game.opponent or career.team
        local venue = P.League.venue(game.homeId)
        game.site, game.venueId = venue.name,venue.id
        game.stage, game.season = career.stage,career.season
    end
    if data.replay > 0 then game.label = game.label.." replay" end
    return game
end

local function actualBox(career, fixture, match, captured)
    local box = captured and copy(captured) or {players={},teams={},detailUnavailable=true}
    if box.sides and box.awayId == fixture.homeId and box.homeId ~= fixture.homeId then
        box.sides[1],box.sides[2] = box.sides[2],box.sides[1]
    end
    box.id, box.source, box.competition = fixture.id,"played",Season.competition(career).id
    box.stage, box.season, box.week = career.stage,career.season,fixture.week
    box.postseason, box.venueId = fixture.postseason,fixture.venueId
    box.homeId,box.awayId = fixture.homeId,fixture.awayId
    box.homeScore = fixture.home and match.homeScore or match.awayScore
    box.awayScore = fixture.home and match.awayScore or match.homeScore
    return box
end

function Season.record(career, fixture, match, experience, personal, screenEvents, captured)
    local current = Season.fixture(career)
    if not current or current.id ~= fixture.id then return false end
    fixture = current
    local data = copy(career.seasonData)
    career.seasonData = data
    if career.contract then career.contract = copy(career.contract) end
    local own, other = match.homeScore, match.awayScore
    local box = actualBox(career,fixture,match,captured)
    data.gameBoxes[fixture.id] = box
    data.results[fixture.id] = own.."–"..other
    data.lastFixtureId = fixture.id
    data.games, data.xp = data.games+1, data.xp+experience
    for key, value in pairs(personal) do data.personal[key] = (data.personal[key] or 0)+value end
    screenEvents = screenEvents or {}
    for _, event in ipairs(screenEvents) do
        local kind = event.kind
        data.screenCoachCounts[kind] = (data.screenCoachCounts[kind] or 0)+1
    end
    data.lastScreenCoach = {fixtureId=fixture.id, points=personal.screenCoachPoints or 0, count=#screenEvents}
    if own>other then data.wins=data.wins+1
    elseif own<other then data.losses=data.losses+1
    else data.ties=data.ties+1 end
    if data.phase == "regular" then
        weekResults(career,data,data.week,box)
        data.week = data.week+1
        advanceRegular(career,data)
        return true
    end
    if own == other then
        data.replay = data.replay+1
        return true
    end
    local bracket = data.bracket
    if bracket then
        local game = data.playoffs[bracket.userIndex]
        game.result,game.fixtureId = data.results[fixture.id],fixture.id
        bracket.pending[#bracket.pending+1] = winner(box)
        openBracketRound(career,data,bracket.pending)
        return true
    end

    -- Keep the already-open legacy two-round bracket playable on older saves.
    local semifinal = data.phase == "semifinal"
    local game = data.playoffs[semifinal and 1 or 2]
    game.result, game.fixtureId = data.results[fixture.id], fixture.id
    data.replay = 0
    if semifinal and own > other then
        data.phase = "final"
        data.playoffs[2] = playoffGame(career,career.team,data.otherFinalist,"final")
    else
        if semifinal and data.otherFinalist then
            local final = simulate(career,data,"final",fixture.opponent,data.otherFinalist,nil,"championship")
            data.champion = winner(final)
        else
            data.champion = winner(box)
        end
        complete(career,data,not semifinal and own>other)
    end
    return true
end

function Season.standings(career)
    Season.fixture(career)
    return ranked(state(career))
end

function Season.boxScores(career, season)
    if not season or season == career.season then return state(career).gameBoxes end
    for _, archived in ipairs(career.history or {}) do
        if archived.season == season then return archived.boxScores or {} end
    end
    return {}
end

function Season.leaderboard(career, key, season)
    local byPlayer, rows = {}, {}
    for _, box in pairs(Season.boxScores(career,season)) do
        for id,line in pairs(box.players or {}) do
            local row = byPlayer[id]
            if not row then
                row = {playerId=id,teamId=line.teamId,name=line.name,role=line.role,career=line.career,stats={},
                    playedGames=0,simulatedGames=0}
                byPlayer[id] = row
            end
            local source = box.source == "simulated" and "simulatedGames" or "playedGames"
            row[source] = row[source] + 1
            for stat,value in pairs(line.stats or {}) do
                if type(value) == "number" then row.stats[stat] = (row.stats[stat] or 0)+value end
            end
        end
    end
    for _, row in pairs(byPlayer) do
        row.value = row.stats[key] or 0
        if row.value ~= 0 then rows[#rows+1] = row end
    end
    table.sort(rows,function(a,b)
        if a.value ~= b.value then return a.value > b.value end
        return a.playerId < b.playerId
    end)
    return rows
end

local function gameScreenPoints(career, fixtureId)
    local entry = fixtureId and career.entries[fixtureId]
    return entry and entry.stats and entry.stats.screenCoachPoints
end

function Season.schedule(career)
    local current = Season.fixture(career)
    local data, rows = state(career), {}
    for week=1,#data.rounds do
        local game = regularFixture(career,data,week)
        if game then
            rows[#rows+1] = {id=game.id,label=game.label,opponent=P.TeamUniform.get(game.opponent).name,
                home=game.home,result=data.results[game.id],current=current and current.id==game.id,
                site=game.site,week=week,opponentRecord=data.records[tostring(game.opponent)],
                screenCoachPoints=gameScreenPoints(career, game.id)}
        end
    end
    for i, game in ipairs(data.playoffs) do
        local phase = game.phase or (i==1 and "semifinal" or "final")
        rows[#rows+1] = {id=game.fixtureId, label=game.label,opponent=P.TeamUniform.get(game.opponent).name,
            home=game.home,site=game.site,opponentRecord=data.records[tostring(game.opponent)],
            result=game.result,current=current and phase==data.phase,
            screenCoachPoints=gameScreenPoints(career, game.fixtureId)}
    end
    return rows
end

local function screenCoachAdjustment(data)
    return math.max(-12, math.min(12, data.personal.screenCoachPoints or 0))
end

function Season.status(career)
    local nextGame = Season.fixture(career)
    local data = state(career)
    local contract = career.contract
    local completeSeason = data.phase == "complete"
    local starter = data.games >= 2 and data.xp + screenCoachAdjustment(data) >= 56
    local status = completeSeason and "Season complete" or data.phase == "regular"
        and ("Week "..data.week.." of "..#data.rounds) or phaseLabel(data.phase)
    if data.titleWon then status = "Championship won" end
    if nextGame then nextGame.opponentRecord = data.records[tostring(nextGame.opponent)] end
    local lastResult = data.lastFixtureId and data.results[data.lastFixtureId]
    if not lastResult then
        local lastPlayoff = data.playoffs[#data.playoffs]
        lastResult = lastPlayoff and lastPlayoff.result
        for week=data.week-1,1,-1 do
            if lastResult then break end
            lastResult = data.results[fixtureID(career,"w"..week)]
        end
    end
    return {phase=data.phase,season=career.season,starter=starter,title=data.titleWon,
        statusLine=status,championships=career.championships or 0,
        competition=Season.competition(career),nextGame=nextGame,lastResult=lastResult,champion=data.champion,
        screenCoachPoints=data.personal.screenCoachPoints or 0, lastScreenCoach=data.lastScreenCoach,
        contract=contract and (contract.remaining.." season(s) left · "..contract.value.." credits"),
        canAdvance=completeSeason and contract and contract.remaining > 0}
end

function Season.offers(career)
    local data = state(career)
    if data.phase ~= "complete" then return {} end
    local performance = data.xp + data.wins*5 + (data.titleWon and 30 or 0) + screenCoachAdjustment(data)
    local list = {}
    if career.stage == "highSchool" then
        for i, team in ipairs(P.SchoolTeams.ncaa) do
            if performance >= 80+i*8 then
                list[#list+1] = {id=team.id,name=team.name,detail="Division I scholarship"}
            end
        end
        local club = P.SchoolTeams.get("florida-state")
        list[#list+1] = {id=club.id,name=club.name,detail="MCLA club invitation"}
    elseif career.stage == "college" or career.contract and career.contract.remaining <= 0 then
        local count = math.max(2,math.min(#P.TeamUniform.teams,math.floor(performance/37)))
        local pick = math.max(1,64-math.floor(performance/5))
        for i=1,count do
            local team = P.TeamUniform.teams[(i+career.season-2)%#P.TeamUniform.teams+1]
            local length = i<=2 and 2 or 1
            local value = 40+math.floor(performance*.35)+i*3
            list[#list+1] = {id=team.id,name=team.name,length=length,value=value,
                detail=(career.stage=="college" and ("Draft "..pick.." · ") or "")
                    ..length.." yr · "..value.." credits"}
        end
    end
    return list
end

local function nextSeason(career, candidate, stage, team)
    local data=state(candidate)
    P.Awards.finalize(candidate)
    candidate.history = candidate.history or {}
    candidate.history[#candidate.history+1] = {season=candidate.season, stage=candidate.stage,
        team=candidate.team, wins=data.wins, losses=data.losses, ties=data.ties,
        stats=data.personal, screenCoachCounts=data.screenCoachCounts, title=data.titleWon,
        champion=data.champion, competition=Season.competition(candidate).id, boxScores=data.gameBoxes,
        standings=ranked(data),awards=data.awards}
    candidate.stage, candidate.team = stage, team
    candidate.season, candidate.seasonData = candidate.season+1, nil
    return commit(career,candidate)
end

function Season.accept(career, id)
    for _, offer in ipairs(Season.offers(career)) do
        if offer.id == id then
            local candidate = copy(career)
            local stage = career.stage == "highSchool" and "college" or "professional"
            if offer.length then candidate.contract = {length=offer.length,remaining=offer.length,value=offer.value} end
            return nextSeason(career,candidate,stage,id)
        end
    end
    return false
end

function Season.advance(career)
    if not Season.status(career).canAdvance then return false end
    return nextSeason(career,copy(career),career.stage,career.team)
end

local skills = {
    {{"shooting","Shooting"},{"ballSecurity","Ball security"},{"speed","Speed"},{"passing","Passing"}},
    {{"speed","Speed"},{"stamina","Stamina"},{"passing","Passing"},{"shooting","Shooting"}},
    {{"stickCheck","Stick checks"},{"bodyCheck","Body checks"},{"interception","Interceptions"},{"speed","Speed"}},
    {{"faceoff","Faceoffs"},{"stamina","Stamina"},{"reaction","Reactions"},{"ballSecurity","Ball security"}},
    {{"reflexes","Reflexes"},{"handSpeed","Hand speed"},{"clearingAccuracy","Clears"},{"reaction","Reactions"}}
}

for _, list in ipairs(skills) do
    list[#list+1] = {"strength", "Strength"}
end

function Season.trainingCount(career)
    return #(skills[career.position] or skills[2])
end

local modernSkill={shooting="shotPower",ballSecurity="ballControl",
    interception="defensiveAwareness",reaction="defensiveAwareness",
    handSpeed="reflexes",clearingAccuracy="passing"}

function Season.training(career, index)
    local list = skills[career.position] or skills[2]
    local item = list[((index or 1)-1)%#list+1]
    if P.Development then
        local key=modernSkill[item[1]] or item[1]
        local current=P.Attributes.restore(career.attributes,career.position)[key]
        local nextValue,cost=P.Attributes.advance(career.attributes,key,career.position)
        return {key=key,label=item[2],value=current,cost=cost or 0,
            gain=nextValue and nextValue-current or 0,available=nextValue and P.Development.points(career)>=cost or false}
    end
    local value = career.attributes[item[1]]
    local cost = 40 + math.max(0,value-65)*2
    return {key=item[1],label=item[2],value=value,cost=cost,gain=math.min(3,99-value),
        available=value<99 and career.xp-(career.spentXP or 0)>=cost}
end

function Season.train(career, key)
    if P.Development then return P.Development.upgrade(career,modernSkill[key] or key) end
    for index=1,Season.trainingCount(career) do
        local skill = Season.training(career,index)
        if skill.key==key and skill.available then
            local candidate = copy(career)
            candidate.spentXP = (candidate.spentXP or 0)+skill.cost
            candidate.attributes[key] = math.min(99,skill.value+3)
            return commit(career,candidate)
        end
    end
    return false
end
