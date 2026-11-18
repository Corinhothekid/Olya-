-- PolyLax 2.0 | Awards from the career season's match reports
PolyLax = PolyLax or {}
local P = PolyLax
local Awards = {}
P.Awards = Awards

local college = {{id="tewaaraton", title="Tewaaraton Award"}}
local professional = {
    {id="pro-mvp", title="Professional MVP"},
    {id="pro-offense", title="Offensive Player of the Year", roles={A=true,M=true}},
    {id="pro-defense", title="Defensive Player of the Year", roles={D=true}},
    {id="pro-goalie", title="Goalie of the Year", roles={G=true}},
    {id="pro-rookie", title="Rookie of the Year", rookie=true},
    {id="championship-mvp", title="Championship MVP", championship=true}
}

local totals = {"goals","assists","shots","shotsOnGoal","groundBalls","causedTurnovers",
    "interceptions","turnovers","penalties","penaltyMinutes","saves","goalsAllowed",
    "shotsFaced","faceoffWins","faceoffAttempts","passes","completions"}
local roleNames = {attack="A",mid="M",midfield="M",midfielder="M",defense="D",defender="D",
    faceoff="F",fogo="F",goalie="G",goalkeeper="G"}
local validRoles = {A=true,M=true,D=true,F=true,G=true}
local cache = setmetatable({}, {__mode="k"})

local function number(value)
    if type(value) == "number" and value >= 0 and value < math.huge then return value end
    return 0
end

local function clamp(value, maximum)
    return math.max(0,math.min(maximum or 1,value))
end

local function fraction(numerator, denominator, prior, weight)
    -- Shrink tiny samples toward typical efficiency.
    return (math.min(number(numerator),number(denominator)) + prior*weight)
        / (number(denominator)+weight)
end

local function field(stats,key)
    if key == "faceoffWins" then
        return number(stats.faceoffWins or stats.faceoffsWon or stats.faceoffs)
    elseif key == "causedTurnovers" then
        return number(stats.causedTurnovers or stats.forcedTurnovers)
    elseif key == "shotsFaced" then
        return math.max(number(stats.shotsFaced),number(stats.saves)+number(stats.goalsAllowed))
    end
    return number(stats[key])
end

local function roleOf(line, stats)
    local supplied = tostring(line.role or "M")
    local role = validRoles[supplied] and supplied or roleNames[supplied:lower()] or "M"
    if role == "M" and field(stats,"faceoffAttempts") >= 3 then return "F" end
    return role
end

local function quality(stats, role, games, production)
    production = production or stats
    local function output(key, norm)
        return clamp(field(production,key)/(games*norm),1.25)
    end
    local scoring = clamp((field(production,"goals")+.8*field(production,"assists"))/(games*3.15),1.25)
    local shooting = fraction(stats.goals,stats.shots,.29,5)
    local passing = fraction(stats.completions,stats.passes,.66,8)
    local ground = output("groundBalls",3)
    local caused = output("causedTurnovers",2.1)
    local value
    if role == "G" then
        local saveRate = fraction(stats.saves,field(stats,"shotsFaced"),.49,8)
        value = .42*output("saves",7.8) + .45*clamp((saveRate-.27)/.33,1.25)
            + .08*ground + .05*clamp(passing/.76,1.25)
    elseif role == "F" then
        local faceRate = fraction(field(stats,"faceoffWins"),stats.faceoffAttempts,.49,8)
        value = .40*output("faceoffWins",6.8) + .36*clamp((faceRate-.24)/.40,1.25)
            + .18*ground + .06*scoring
    elseif role == "D" then
        value = .49*caused + .26*ground + .14*output("interceptions",1.25)
            + .07*scoring + .04*clamp(passing/.76,1.25)
    elseif role == "A" then
        local efficiency = clamp(shooting/.38,1.25) * clamp(field(stats,"shots")/(games*2.8))
        value = .59*scoring + .17*efficiency + .13*output("assists",1.6)
            + .07*ground + .04*caused
    else
        local efficiency = clamp(shooting/.38,1.25) * clamp(field(stats,"shots")/(games*2.5))
        value = .47*scoring + .12*efficiency + .20*ground + .15*caused
            + .06*clamp(passing/.76,1.25)
    end
    local errors = (field(stats,"turnovers")*.023 + field(stats,"penalties")*.027
        + field(stats,"penaltyMinutes")*.012)/games
    return clamp(value-math.min(.28,errors),1.25)
end

local function eligibleTeam(career,teamId)
    if career.stage == "professional" then return true end
    local schools = P.SchoolTeams
    local team = schools and schools.get(teamId)
    return career.stage == "college" and team and team.group == "ncaa"
end

local function definitions(career)
    if career.stage == "professional" then return professional end
    if eligibleTeam(career,career.team) then return college end
end

local function reportsFor(career,data)
    local season = P.CareerSeason
    local stored = season and season.boxScores and season.boxScores(career)
        or data.matchReports or data.boxScores or {}
    local distinct = {}
    for key, report in pairs(stored) do
        if type(report) == "table" and type(report.players) == "table"
            and (report.source == "played" or report.source == "simulated")
            and (not report.stage or report.stage == career.stage)
            and (not report.season or report.season == career.season)
            and report.homeId ~= nil and report.awayId ~= nil
            and eligibleTeam(career,report.homeId) and eligibleTeam(career,report.awayId)
            and type(report.homeScore) == "number" and type(report.awayScore) == "number" then
            local id = tostring(report.id or key)
            if not distinct[id] or report.source == "played" then distinct[id] = report end
        end
    end
    local ids = {}
    for id in pairs(distinct) do ids[#ids+1] = id end
    table.sort(ids)
    local reports = {}
    for i,id in ipairs(ids) do reports[i] = distinct[id] end
    return reports
end

local function resultFor(report,teamId)
    local home = tostring(report.homeId) == tostring(teamId)
    local own,opp = report.homeScore,report.awayScore
    local opponent = report.awayId
    if not home then own,opp,opponent = opp,own,report.homeId end
    return own == opp and .5 or own > opp and 1 or 0,opponent
end

local function recordTeams(reports)
    local teams = {}
    for _,report in ipairs(reports) do
        for _,teamId in ipairs({report.homeId,report.awayId}) do
            local key = tostring(teamId)
            local team = teams[key] or {games=0, wins=0}
            local result = resultFor(report,teamId)
            team.games,team.wins = team.games+1,team.wins+result
            teams[key] = team
        end
    end
    return teams
end

local function firstProfessionalSeason(career)
    if career.stage~="professional" then return false end
    for _,season in ipairs(career.history or {}) do
        if season.stage=="professional" then return false end
    end
    return true
end

local function opportunityScale(report)
    -- Compare production against available game events. Published counters and
    -- efficiency are still raw, including in shorter player-controlled games.
    local teams = report.teams or {}
    local home = teams[tostring(report.homeId)] or teams[report.homeId]
    local away = teams[tostring(report.awayId)] or teams[report.awayId]
    if not home or not away then return 1 end
    local shots = field(home.stats or home,"shots") + field(away.stats or away,"shots")
    return math.max(.84,clamp(math.sqrt(46/(shots+10)),1.58))
end

local function candidateRows(career,reports,teams)
    local rows = {}
    local userRookie = firstProfessionalSeason(career)
    for _,report in ipairs(reports) do
        local opportunity = opportunityScale(report)
        for mapId,line in pairs(report.players) do
            if type(line) == "table" and type(line.stats) == "table" and line.teamId ~= nil
                and eligibleTeam(career,line.teamId) then
                local stats,role = line.stats,roleOf(line,line.stats)
                local participated = number(stats.gamesPlayed)>0 or number(stats.secondsPlayed)>0
                    or number(stats.minutesPlayed)>0
                local teamKey = tostring(line.teamId)
                local id = tostring(line.playerId or mapId)
                local profile = line.career==true or line.profile==true
                    or id==career.playerId or id==career.profileId
                if participated and (report.source=="played" or not profile)
                    and (teamKey == tostring(report.homeId) or teamKey == tostring(report.awayId)) then
                    local rookie = line.rookie==true or profile and userRookie
                    local row = rows[id] or {id=id,teamId=line.teamId,name=line.name or id,
                        role=role,number=line.number,career=false,rookie=false,
                        games=0,played=0,simulated=0,stats={},production={},
                        sum=0,squared=0,wins=0,opponents=0,clutch=0,clutchGames=0,
                        championship=0,championshipGames=0}
                    if role == "F" then row.role = role end
                    row.career = row.career or profile
                    row.rookie = row.rookie or rookie
                    row.games = row.games+1
                    row[report.source] = row[report.source]+1
                    local result,opponent = resultFor(report,line.teamId)
                    local other = teams[tostring(opponent)]
                    local opponentStrength = other and (other.wins+1)/(other.games+2) or .5
                    local production = {}
                    for _,key in ipairs(totals) do
                        local value = field(stats,key)
                        production[key] = value*opportunity
                        row.stats[key] = (row.stats[key] or 0)+value
                        row.production[key] = (row.production[key] or 0)+production[key]
                    end
                    local impact = quality(stats,role,1,production)
                    row.wins = row.wins+result
                    row.opponents = row.opponents+opponentStrength
                    row.sum,row.squared = row.sum+impact,row.squared+impact*impact
                    local championship = report.postseason == "championship"
                    if report.postseason or opponentStrength > .59 then
                        local weight = championship and 1.4 or 1
                        row.clutch,row.clutchGames = row.clutch+impact*weight,row.clutchGames+weight
                    end
                    if championship and result > .5 then
                        row.championship = row.championship+impact
                        row.championshipGames = row.championshipGames+1
                    end
                    rows[id] = row
                end
            end
        end
    end
    return rows
end

local function ranking(row,teams)
    local team = teams[tostring(row.teamId)]
    local mean = row.sum/row.games
    local spread = math.sqrt(math.max(0,row.squared/row.games - mean*mean))
    local consistency = clamp(mean/.72)*clamp(1-spread/.53)
    local exposure = clamp(row.games/math.max(1,team and team.games or row.games))
    local impact = quality(row.stats,row.role,row.games,row.production)
    local clutch = (row.clutch+.9*mean)/(row.clutchGames+.9)
    local sample = clamp(row.games/5)
    local score = (64*impact + 10*(row.wins/row.games) + 8*consistency + 6*exposure
        + 5*(row.opponents/row.games) + 7*clutch) * (.88 + .12*sample)
    return score,exposure
end

local labels = {A="Attack",M="Midfield",D="Defense",F="Faceoff",G="Goalie"}

local function publicRow(row,score,exposure)
    local stats = row.stats
    return {id=row.id, name=row.name, role=row.role, roleLabel=labels[row.role], teamId=row.teamId,
        number=row.number, career=row.career, rookie=row.rookie, score=math.floor(score*10+.5)/10,
        games=row.games, played=row.played, simulated=row.simulated, exposure=exposure,
        goals=stats.goals, assists=stats.assists, saves=stats.saves, goalsAllowed=stats.goalsAllowed,
        causedTurnovers=stats.causedTurnovers, groundBalls=stats.groundBalls,
        faceoffWins=stats.faceoffWins, faceoffAttempts=stats.faceoffAttempts}
end

local function buildBoard(definition,rows,teams,phase)
    local rank = {}
    for _,row in pairs(rows) do
        if (not definition.roles or definition.roles[row.role])
            and (not definition.rookie or row.rookie)
            and (not definition.championship or row.championshipGames > 0) then
            local score,exposure = ranking(row,teams)
            local enough = phase == "watchlist" or phase == "midseason"
                or definition.championship or row.games>=2 and exposure>=.45
            if enough then
                if definition.championship then score = 92*row.championship/row.championshipGames+8 end
                rank[#rank+1] = publicRow(row,score,exposure)
            end
        end
    end
    table.sort(rank,function(a,b)
        if a.score ~= b.score then return a.score > b.score end
        if a.games ~= b.games then return a.games > b.games end
        return a.id < b.id
    end)
    local finalists,leaderboard = {},{}
    for i=1,math.min(15,#rank) do
        local row = rank[i]
        row.rank = i
        leaderboard[i] = row
        if i<=3 and (phase=="finalists" or phase=="complete") then finalists[i] = row end
    end
    return {id=definition.id,title=definition.title,rows=leaderboard,finalists=finalists,
        winner=phase=="complete" and rank[1] or nil}
end

local function racePhase(data)
    if data.phase == "complete" then return "complete" end
    local week, count = number(data.week), #(data.rounds or {})
    if data.phase and data.phase ~= "regular" or count>0 and week>count*.76 then return "finalists" end
    if count>0 and week>count*.48 then return "midseason" end
    return "watchlist"
end

function Awards.preview(career)
    local catalog = definitions(career)
    if not catalog then
        local reason = career.stage=="college" and "College club has a separate competition"
            or "Season honors open in NCAA Division I and professional play"
        return {eligible=false,reason=reason,boards={}}
    end
    local data = career.seasonData
    if not data then return {eligible=true,phase="watchlist",boards={}} end
    if data.awards and data.awards.phase == "complete" then return data.awards end
    local phase = racePhase(data)
    local signature = table.concat({phase,data.season or "",data.week or "",data.games or "",
        data.replay or "",data.phase or ""},":")
    local old = cache[career]
    if old and old.data==data and old.signature==signature then return old.preview end
    local reports = reportsFor(career,data)
    local teams = recordTeams(reports)
    local rows = candidateRows(career,reports,teams)
    local output = {eligible=true,phase=phase,season=career.season,stage=career.stage,
        games=#reports,boards={}}
    for i,definition in ipairs(catalog) do
        output.boards[i] = buildBoard(definition,rows,teams,phase)
    end
    cache[career] = {data=data,signature=signature,preview=output}
    return output
end

function Awards.trophies(career)
    return type(career.trophies)=="table" and career.trophies or {}
end

function Awards.finalize(career)
    local data = career.seasonData
    if not data or data.phase ~= "complete" or not definitions(career) then return nil end
    if data.awards then return data.awards end
    local output = Awards.preview(career)
    if not output.games or output.games == 0 then return nil end
    data.awards = output
    local shelf,seen = {},{}
    for _,trophy in ipairs(Awards.trophies(career)) do
        shelf[#shelf+1] = trophy
        if type(trophy)=="table" and trophy.key then seen[trophy.key] = true end
    end
    for _,board in ipairs(output.boards) do
        local winner = board.winner
        local key = table.concat({career.stage,career.season,tostring(career.team),board.id},":")
        if winner and winner.career and not seen[key] then
            shelf[#shelf+1] = {key=key,id=board.id,title=board.title,stage=career.stage,
                season=career.season,teamId=winner.teamId,playerId=winner.id,
                player=winner.name,role=winner.role,score=winner.score}
        end
    end
    career.trophies = shelf
    return output
end
