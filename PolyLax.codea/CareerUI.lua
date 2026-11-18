-- PolyLax Build 013 | Road to the Pros
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.CareerUI = UI

local backgroundColor = color(7,19,35)
local surface = color(19,37,58)
local raised = color(28,50,73)
local border = color(43,65,86)
local muted = color(164,183,204)
local white = color(246,249,255)
local amber = color(253,205,85)
local green = color(111,229,182)
local red = color(255,155,145)

local tabs = {
    {id="profile",label="Overview"},
    {id="schedule",label="Schedule"},
    {id="standings",label="Standings"},
    {id="stats",label="Stats"},
    {id="offers",label="Offers"}
}

local function box(x,y,w,h,label,id)
    return {x=x,y=y,w=w,h=h,label=label,id=id}
end

local function teamName(id)
    local team = id and P.TeamUniform.get(id)
    return team and team.name or ""
end

local function overview(l, career, playing, training)
    local width, center, top = l.w,l.x,l.contentTop
    local column = (width-8)*.5
    local fit = math.min(1, (top-l.bottom-72)/309)
    l.overviewScale = fit
    l.name = box(center,top-22*fit,width,42*fit,career.name,"name")
    local position = P.Career.positions[career.position] or P.Career.positions[2]
    l.position = box(l.left+column*.5,top-70*fit,column,43*fit,position.label,"position")
    l.team = box(l.right-column*.5,top-70*fit,column,43*fit,P.Career.teamName(career),"team")
    l.summary = box(center,top-134*fit,width,76*fit)
    l.statsY = top-185*fit
    l.screenStats = box(center,top-225*fit,width,62*fit)
    if P.Development then
        l.development=box(center,top-286*fit,width,43*fit,"Player development","development")
    elseif training then
        l.nextSkill = box(l.left+column*.5,top-286*fit,column,43*fit,training.label,"nextSkill")
        l.train = box(l.right-column*.5,top-286*fit,column,43*fit,"Train +"..(training.gain or 1),training.key)
        l.train.enabled = training.available and not playing or false
        l.training = training
    end
end

local function listLayout(l, entries, requestedPage, height)
    local start = l.contentTop-34
    local reserve = l.bottom+103
    local capacity = math.max(1,math.floor((start-reserve)/height))
    l.pages = math.max(1,math.ceil(#entries/capacity))
    l.page = math.max(1,math.min(l.pages,math.floor(tonumber(requestedPage) or 1)))
    l.rows = {}
    local first = (l.page-1)*capacity+1
    for i=first,math.min(#entries,first+capacity-1) do
        l.rows[#l.rows+1] = {
            item=box(l.x,start-((i-first)+.5)*height,l.w,height-5),
            value=entries[i]
        }
    end

    if l.page > 1 then
        l.leftPage = box(l.left+43,l.bottom+84,86,32,"Previous","previous")
    end
    if l.page < l.pages then
        l.rightPage = box(l.right-43,l.bottom+84,86,32,"Next","next")
    end
end

local statModes={{id="career",label="Career"},{id="season",label="Season"},{id="matches",label="Box scores"}}
local statFields={
    {"Games played","gamesPlayed"},{"Starts","gamesStarted"},{"Minutes","minutesPlayed",1},
    {"Goals","goals"},{"Assists","assists"},{"Points","points"},{"Shots","shots"},
    {"On target","shotsOnGoal"},{"Shooting %","shootingPct",2},{"Ground balls","groundBalls"},
    {"Caused turnovers","causedTurnovers"},{"Turnovers","turnovers"},{"Forced losses","committedForcedTurnovers"},
    {"Unforced losses","unforcedTurnovers"},{"Penalties","penalties"},{"Penalty minutes","penaltyMinutes",1},
    {"Faceoff wins","faceoffs"},{"Faceoff attempts","faceoffAttempts"},{"Faceoff %","faceoffPct",2},
    {"Saves","saves"},{"Goals allowed","goalsAllowed"},{"Save %","savePct",2},
    {"Screens","screens"},{"Screen assists","screenAssists"},{"Team wins","wins"},{"Team losses","losses"}
}

local function report(career,kind)
    local entries={}
    if kind=="matches" then
        local profile=P.Statistics.profile("career-player")
        for index=#profile.order,1,-1 do
            local summary=profile.matches[profile.order[index]]
            if summary then
                local away=summary.awayId and P.TeamUniform.get(summary.awayId).short or ""
                entries[#entries+1]={label=(summary.mode or "Match").."  "..away,
                    value=summary.homeScore.."–"..summary.awayScore,box=summary}
            end
        end
        return entries
    end
    local season=career.seasonData or {}
    local stats=kind=="season" and (season.personal or {}) or career.stats
    local rates=P.Statistics.rates(stats)
    local record=kind=="season" and season or career
    for _,field in ipairs(statFields) do
        local key,format=field[2],field[3]
        local value=key=="wins" or key=="losses"
        value=value and record[key] or stats[key]
        if format==2 then value=rates[key] and string.format("%.0f%%",rates[key]*100) or "–"
        elseif format==1 then value=string.format("%.1f",value or 0)
        else value=tostring(value or 0) end
        entries[#entries+1]={label=field[1],value=value}
    end
    return entries
end

function UI.layout(career, view, playing, trainIndex, page, statMode)
    view = view or "profile"
    local safe = P.UI.safeArea()
    local width = math.min(480,WIDTH-safe.left-safe.right-28)
    local center = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-12,math.max(18,safe.bottom+10)
    local left, right = center-width*.5,center+width*.5
    local season = P.CareerSeason
    local status = season and season.status(career)
    local fixture = not playing and (season and season.fixture(career) or
        not season and P.Career.fixture(career))
    local l = {
        x=center,w=width,left=left,right=right,top=top,bottom=bottom,contentTop=top-91,
        view=view,nav={},offerButtons={},fixture=fixture,status=status,
        back=box(left+29,top-19,58,36,"Back","back")
    }
    for i, tab in ipairs(tabs) do
        local span = width/#tabs
        l.nav[i] = box(left+span*(i-.5),top-61,span-4,37,tab.label,tab.id)
    end
    if playing then
        local finished = playing.game.phase == "FINAL"
        l.play = box(center,bottom+23,width,46,
            finished and "Retry saving result" or "Resume career game","play")
    elseif fixture then
        l.play = box(center,bottom+23,width,46,"Play next game","play")
    elseif career.stage == "professional" and status and status.canAdvance then
        l.advance = box(center,bottom+23,width,46,"Start next pro season","advance")
    end

    if view == "schedule" then
        listLayout(l,season and season.schedule(career) or {},page,37)
    elseif view == "standings" then
        listLayout(l,season and season.standings(career) or {},page,34)
    elseif view=="stats" then
        l.statMode=statMode or "career"
        l.statModes={}
        for i,kind in ipairs(statModes) do
            local span=width/#statModes
            l.statModes[i]=box(left+span*(i-.5),l.contentTop-12,span-5,29,kind.label,kind.id)
        end
        listLayout(l,report(career,l.statMode),page,35)
    elseif view == "offers" then
        listLayout(l,season and season.offers(career) or {},page,49)
        if not playing then
            for _, row in ipairs(l.rows) do
                local item = row.item
                item.id = row.value.id
                l.offerButtons[#l.offerButtons+1] = item
            end
        end
    else
        overview(l,career,playing,not P.Development and season and season.training(career,trainIndex or 1))
    end
    return l
end

local function label(value,x,y,size,tint,maxWidth)
    if type(value) ~= "string" or value == "" then return end
    fill(tint)
    fontSize(size)
    if maxWidth and textSize then
        local width = textSize(value)
        if width > maxWidth then fontSize(math.max(9,size*maxWidth/width)) end
    end
    text(value,x,y)
end

local function rectAt(item,tint)
    rectMode(CENTER)
    fill(tint)
    if P.Style then P.Style.rounded(item.x,item.y,item.w,item.h,9,tint)
    else rect(item.x,item.y,item.w,item.h) end
end

local function leading(value,x,y,size,tint,maxWidth)
    textMode(CORNER)
    label(value,x,y-size*.54,size,tint,maxWidth)
    textMode(CENTER)
end

local function card(item,sub,strong,disabled)
    rectAt(item,strong and amber or surface)
    local tint = strong and backgroundColor or disabled and muted or white
    if sub then label(sub,item.x,item.y+9,9,strong and backgroundColor or muted,item.w-12) end
    label(item.label,item.x,item.y-(sub and 7 or 0),strong and 14 or 13,tint,item.w-12)
end

local function drawScreenStats(l, stats, status)
    local item, scale = l.screenStats, l.overviewScale
    local side, width = item.w*.25, item.w*.5-10
    rectAt(item,surface)
    label("SCREENS "..(stats.screens or 0),item.x-side,item.y+17*scale,10,white,width)
    label("SCREEN ASSISTS "..(stats.screenAssists or 0),item.x+side,item.y+17*scale,10,white,width)
    label("OPEN SHOTS "..(stats.screenOpenShots or 0),item.x-side,item.y+2*scale,10,white,width)
    label("ILLEGAL SCREENS "..(stats.illegalScreens or 0),item.x+side,item.y+2*scale,10,white,width)
    local points = status.screenCoachPoints or 0
    local textValue = string.format("COACH %+d SEASON",points)
    if status.lastScreenCoach then
        textValue = textValue..string.format("  ·  %+d LAST GAME",status.lastScreenCoach.points)
    end
    local tint = points > 0 and green or points < 0 and red or muted
    label(textValue,item.x,item.y-18*scale,10,tint,item.w-12)
end

local function drawOverview(career,l,editing,draft,playing)
    local name = l.name
    if editing then name = box(name.x,name.y,name.w,name.h,(draft or "").."|") end
    card(name,"PLAYER NAME")
    card(l.position,"POSITION",false,career.games>0 or playing)
    card(l.team,"TEAM",false,career.games>0 or playing)
    local status = l.status or {}
    local summary, stats, scale = l.summary,career.stats,l.overviewScale
    rectAt(summary,surface)
    local title = type(status.title) == "string" and status.title
        or status.title == true and "CHAMPIONSHIP WON" or P.Career.stages[career.stage]
    label(title,l.x,summary.y+25*scale,12,amber,l.w-18)
    local xp = math.max(0,career.xp-(career.spentXP or 0))
    label(string.format("RECORD  %d–%d–%d     XP  %d",career.wins,career.losses,career.ties,xp),
        l.x,summary.y+7*scale,13,white,l.w-18)
    local role = status.starter == true and "STARTER" or status.starter == false and "RESERVE"
    local detail = status.statusLine or ""
    if role then detail = role .. (detail == "" and "" or "  ·  "..detail) end
    label(detail,l.x,summary.y-11*scale,10,muted,l.w-18)
    local award = (status.championships or 0) > 0 and ("Titles "..status.championships)
    if status.contract then
        award = status.contract .. (award and "  ·  "..award or "")
    end
    label(award,l.x,summary.y-26*scale,9,muted,l.w-18)
    label(string.format("%d G   %d A   %d GB   %d CTO   %d SV   %d FO",
        stats.goals or 0,stats.assists or 0,stats.groundBalls or 0,stats.causedTurnovers or 0,
        stats.saves or 0,stats.faceoffs or 0),l.x,l.statsY,11,white,l.w-10)
    drawScreenStats(l,stats,status)
    if l.development then
        local overall=P.Attributes.overall(career.attributes,career.position)
        card(l.development,string.format("OVR %d  ·  %d SP",overall,P.Development.points(career)),true)
    elseif l.training then
        local training = l.training
        card(l.nextSkill,"SKILL  "..tostring(training.value).."   ›",false)
        local cost = training.available and ("COST  "..tostring(training.cost).." XP")
            or (training.value >= 99 and "MAX RATING" or ("NEEDS "..tostring(training.cost).." XP"))
        card(l.train,cost,l.train.enabled,not l.train.enabled)
    end
end

local function gameResultTint(result)
    local first = result and result:sub(1,1)
    return first == "W" and green or first == "L" and red or muted
end

local function drawSchedule(l)
    leading("FIXTURES",l.left+3,l.contentTop-12,11,muted)
    for _, row in ipairs(l.rows) do
        local item, fixture = row.item,row.value
        rectAt(item,fixture.current and raised or surface)
        if fixture.current then rectAt(box(l.left+2,item.y,4,item.h),amber) end
        local venue = fixture.home == false and "AT" or "VS"
        leading(venue.."  "..fixture.opponent,l.left+10,item.y+5,12,white,l.w-106)
        local detail = fixture.label
        if fixture.screenCoachPoints then
            detail = detail..string.format("  ·  Coach %+d",fixture.screenCoachPoints)
        end
        leading(detail,l.left+10,item.y-8,9,muted,l.w-106)
        local result = fixture.result or (fixture.current and "NEXT" or "—")
        label(result,l.right-44,item.y,11,fixture.current and amber or gameResultTint(result),77)
    end
    if #l.rows == 0 then label("No fixtures scheduled",l.x,l.contentTop-78,14,muted) end
end

local function drawStandings(career,l)
    local w = l.w
    local sites = {l.right-w*.36,l.right-w*.28,l.right-w*.20,l.right-w*.115,l.right-w*.04}
    leading("TEAM",l.left+10,l.contentTop-12,10,muted)
    for i,value in ipairs({"W","L","T","PTS","+/-"}) do
        label(value,sites[i],l.contentTop-12,9,muted)
    end
    for _,row in ipairs(l.rows) do
        local item,team = row.item,row.value
        local selected = team.id == career.team
        rectAt(item,selected and raised or surface)
        if selected then rectAt(box(l.left+2,item.y,4,item.h),amber) end
        leading(team.name,l.left+9,item.y,11,selected and amber or white,w*.56)
        local numbers = {team.wins,team.losses,team.ties,team.points,team.differential}
        for i,value in ipairs(numbers) do label(tostring(value),sites[i],item.y,10,white) end
    end
    if #l.rows == 0 then label("Standings appear with the season",l.x,l.contentTop-78,13,muted) end
end

local function drawStats(l)
    for _,item in ipairs(l.statModes) do card(item,nil,item.id==l.statMode) end
    for _,row in ipairs(l.rows) do
        rectAt(row.item,surface)
        leading(row.value.label,l.left+11,row.item.y,12,white,l.w-90)
        label(row.value.value,l.right-43,row.item.y,12,amber,76)
    end
    if #l.rows==0 then label("Finish a game to see a box score",l.x,l.contentTop-57,12,muted,l.w-12) end
end

local function drawOffers(l,playing)
    local title = #l.rows > 0 and "SELECT AN OFFER" or "RECRUITING & CONTRACTS"
    leading(title,l.left+3,l.contentTop-12,11,muted)
    for _, row in ipairs(l.rows) do
        local item, offer = row.item,row.value
        rectAt(item,playing and surface or raised)
        leading(offer.name,l.left+11,item.y+7,13,white,l.w-45)
        leading(offer.detail,l.left+11,item.y-9,10,muted,l.w-45)
        if not playing then label("›",l.right-18,item.y,21,amber) end
    end
    if #l.rows == 0 then
        local status = l.status or {}
        label(status.contract or "No offers yet",l.x,l.contentTop-74,15,white,l.w-18)
        label(status.statusLine,l.x,l.contentTop-99,11,muted,l.w-18)
        if (status.championships or 0) > 0 then
            label("Championships  "..status.championships,l.x,l.contentTop-125,12,amber)
        end
    end
end

function UI.draw(career,l,playing,editing,draft,message)
    background(backgroundColor)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    card(l.back)
    leading("Road to the Pros",l.left+69,l.top-16,19,white,l.w-76)
    local stage = P.Career.stages[career.stage]
    local season = l.status and l.status.season or career.season
    leading((stage or "").."   ·   SEASON "..(season or 1),l.left+70,l.top-32,9,amber,l.w-76)
    for _,tab in ipairs(l.nav) do
        local active = tab.id == l.view
        rectAt(tab,active and raised or surface)
        if active then rectAt(box(tab.x,tab.y-tab.h*.5+1,tab.w,2,tab.label),amber) end
        label(tab.label,tab.x,tab.y,12,active and amber or muted,tab.w-3)
    end

    if l.view == "schedule" then drawSchedule(l)
    elseif l.view == "standings" then drawStandings(career,l)
    elseif l.view=="stats" then drawStats(l)
    elseif l.view == "offers" then drawOffers(l,playing)
    else drawOverview(career,l,editing,draft,playing) end

    if l.pages and l.pages > 1 then
        if l.leftPage then card(l.leftPage) end
        if l.rightPage then card(l.rightPage) end
        label(string.format("%d / %d",l.page,l.pages),l.x,l.bottom+84,11,muted)
    end
    if l.play then
        local opponent = l.fixture and teamName(l.fixture.opponent)
        local detail = opponent and ((l.fixture.home == false and "AT " or "VS ")..opponent)
        card(l.play,detail,true)
    elseif l.advance then
        card(l.advance,nil,true)
    end
    if message then label(message,l.x,l.bottom+58,11,amber,l.w-10) end
    popMatrix()
    popStyle()
end
