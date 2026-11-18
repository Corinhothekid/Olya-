-- PolyLax Build 012 | Playable season schedule, recruiting, and progression
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
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

local function league(career)
    if career.stage == "professional" then return P.TeamUniform.teams end
    if career.stage == "highSchool" then return P.SchoolTeams.highSchool end
    if P.TeamUniform.get(career.team).group == "club" then return P.SchoolTeams.clubLeague end
    return P.SchoolTeams.ncaa
end

local function newSeason(career)
    local wheel, rounds, records, ranks = {}, {}, {}, {}
    for index, team in ipairs(league(career)) do
        wheel[#wheel+1] = team.id
        ranks[team.id] = index
        records[tostring(team.id)] = {id=team.id,wins=0,losses=0,ties=0,differential=0}
    end
    local size = #wheel
    if size % 2 > 0 then wheel[#wheel+1] = false end
    for week = 1, #wheel-1 do
        local games = {}
        for index = 1, math.floor(#wheel*.5) do
            local a, b = wheel[index], wheel[#wheel+1-index]
            if a and b then
                local gap = (ranks[b]-ranks[a]) % size
                local swap = gap > math.floor(size/2)
                    or size % 2 == 0 and gap == size/2 and ranks[a] > ranks[b]
                if swap == (career.season % 2 == 1) then a,b = b,a end
                games[#games+1] = {home=a,away=b}
            end
        end
        rounds[week] = games
        table.insert(wheel, 2, table.remove(wheel))
    end
    return {team=career.team, stage=career.stage, season=career.season, week=1, phase="regular",
        rounds=rounds, records=records, results={}, playoffs={}, personal={}, games=0, xp=0,
        wins=0, losses=0, ties=0, replay=0}
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
    return data
end

local function fixtureID(career, suffix)
    return career.stage .. "-" .. career.season .. "-" .. suffix
end

local function regularFixture(career, data, week)
    for _, game in ipairs(data.rounds[week] or {}) do
        if game.home == career.team or game.away == career.team then
            local home = game.home == career.team
            return {id=fixtureID(career, "w"..week), opponent=home and game.away or game.home,
                home=home, label="Week "..week, week=week}
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

local function hash(value)
    local score = 3
    for i = 1, #value do score=(score*257+value:byte(i))%100003 end
    return score
end

local function cpuScore(data, home, away, week)
    local signature = data.stage..data.season..tostring(home).."/"..tostring(away).."/"..week
    return 3+hash(signature.."H")%8, 2+hash(signature.."A")%8
end

local function leagueResult(data, a, b, home, away)
    local first, second = data.records[tostring(a)], data.records[tostring(b)]
    first.differential = first.differential + home-away
    second.differential = second.differential + away-home
    if home > away then first.wins,second.losses=first.wins+1,second.losses+1
    elseif home < away then first.losses,second.wins=first.losses+1,second.wins+1
    else first.ties,second.ties=first.ties+1,second.ties+1 end
end

local function weekResults(career, data, week, score, opponentScore)
    for _, pair in ipairs(data.rounds[week]) do
        local home, away
        if pair.home == career.team then home, away = score, opponentScore
        elseif pair.away == career.team then home, away = opponentScore, score
        else home, away = cpuScore(data,pair.home,pair.away,week) end
        leagueResult(data, pair.home, pair.away, home, away)
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

local function advanceRegular(career, data)
    while data.week <= #data.rounds and not regularFixture(career,data,data.week) do
        weekResults(career,data,data.week)
        data.week = data.week+1
    end
    if data.week <= #data.rounds then return end
    local order, seed = ranked(data)
    for rank, row in ipairs(order) do
        if row.id == career.team then seed = rank break end
    end
    if not seed or seed > 4 then
        complete(career,data,false)
        return
    end
    local opponent = order[5-seed]
    local other = {}
    for index=1,4 do
        if index~=seed and index~=5-seed then other[#other+1]=order[index].id end
    end
    local a,b=cpuScore(data,other[1],other[2],#data.rounds+1)
    data.otherFinalist = a>=b and other[1] or other[2]
    data.phase = "semifinal"
    data.playoffs[1] = {opponent=opponent.id, label="Semifinal", home=seed<5-seed}
end

function Season.fixture(career)
    local data = state(career)
    if data.phase == "regular" then advanceRegular(career,data) end
    if data.phase == "regular" then return regularFixture(career,data,data.week) end
    local stage = data.phase == "semifinal" and 1 or data.phase == "final" and 2
    if not stage then return end
    local game = copy(data.playoffs[stage])
    game.id = fixtureID(career,data.phase.."-"..data.replay)
    if data.replay > 0 then game.label = game.label.." replay" end
    return game
end

function Season.record(career, fixture, match, experience, personal)
    local current = Season.fixture(career)
    if not current or current.id ~= fixture.id then return false end
    local data = copy(career.seasonData)
    career.seasonData = data
    if career.contract then career.contract = copy(career.contract) end
    local own, other = match.homeScore, match.awayScore
    data.results[fixture.id] = own.."–"..other
    data.games, data.xp = data.games+1, data.xp+experience
    for key, value in pairs(personal) do data.personal[key] = (data.personal[key] or 0)+value end
    if own>other then data.wins=data.wins+1
    elseif own<other then data.losses=data.losses+1
    else data.ties=data.ties+1 end
    if data.phase == "regular" then
        weekResults(career,data,data.week,own,other)
        data.week = data.week+1
        advanceRegular(career,data)
        return true
    end
    if own == other then
        data.replay = data.replay+1
        return true
    end
    local semifinal = data.phase == "semifinal"
    data.playoffs[semifinal and 1 or 2].result = data.results[fixture.id]
    data.replay = 0
    if semifinal and own > other then
        data.phase = "final"
        data.playoffs[2] = {opponent=data.otherFinalist,label="Championship",home=true}
    else
        complete(career,data,not semifinal and own>other)
    end
    return true
end

function Season.standings(career)
    Season.fixture(career)
    return ranked(state(career))
end

function Season.schedule(career)
    local current = Season.fixture(career)
    local data, rows = state(career), {}
    for week=1,#data.rounds do
        local game = regularFixture(career,data,week)
        if game then
            rows[#rows+1] = {label=game.label,opponent=P.TeamUniform.get(game.opponent).name,
                home=game.home,result=data.results[game.id],current=current and current.id==game.id}
        end
    end
    for i, game in ipairs(data.playoffs) do
        rows[#rows+1] = {label=game.label,opponent=P.TeamUniform.get(game.opponent).name,home=game.home,
            result=game.result,current=current and data.phase==(i==1 and "semifinal" or "final")}
    end
    return rows
end

function Season.status(career)
    Season.fixture(career)
    local data = state(career)
    local contract = career.contract
    local completeSeason = data.phase == "complete"
    local starter = data.games >= 2 and data.xp >= 56
    local status = completeSeason and "Season complete" or data.phase == "regular"
        and ("Week "..data.week.." of "..#data.rounds) or data.phase == "semifinal" and "Semifinal" or "Championship"
    if data.titleWon then status = "Championship won" end
    return {phase=data.phase,season=career.season,starter=starter,title=data.titleWon,
        statusLine=status,championships=career.championships or 0,
        contract=contract and (contract.remaining.." season(s) left · "..contract.value.." credits"),
        canAdvance=completeSeason and contract and contract.remaining > 0}
end

function Season.offers(career)
    local data = state(career)
    if data.phase ~= "complete" then return {} end
    local performance = data.xp + data.wins*5 + (data.titleWon and 30 or 0)
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
    local data = state(candidate)
    candidate.history = candidate.history or {}
    candidate.history[#candidate.history+1] = {season=candidate.season, stage=candidate.stage,
        team=candidate.team, wins=data.wins, losses=data.losses, ties=data.ties,
        stats=data.personal, title=data.titleWon}
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

function Season.training(career, index)
    local list = skills[career.position] or skills[2]
    local item = list[((index or 1)-1)%#list+1]
    local value = career.attributes[item[1]]
    local cost = 40 + math.max(0,value-65)*2
    return {key=item[1],label=item[2],value=value,cost=cost,gain=math.min(3,99-value),
        available=value<99 and career.xp-(career.spentXP or 0)>=cost}
end

function Season.train(career, key)
    for index=1,#skills[career.position] do
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
