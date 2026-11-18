-- PolyLax 2.0 | Live statistics and final box score
PolyLax = PolyLax or {}
local P = PolyLax
local StatsUI = {}
P.StatsUI = StatsUI

local background = color(11,18,29)
local panel = color(23,36,52)
local alternate = color(29,43,59)
local active = color(48,103,179)
local white = color(242,246,249)
local soft = color(172,190,208)
local accent = color(149,210,255)

local pages = {
    {
        title="Scoring & passing",
        {"Goals","goals"}, {"Assists","assists"}, {"Points","points"}, {"Shots","shots"},
        {"Shots on goal","shotsOnGoal"}, {"Shooting %","shootingPct",true},
        {"Passes","passes"}, {"Completions","completions"}, {"Completion %","completionPct",true}
    },
    {
        title="Possession & discipline",
        {"Ground balls","groundBalls"}, {"Caused turnovers","causedTurnovers"},
        {"Turnovers","turnovers"}, {"Forced losses","committedForcedTurnovers"},
        {"Unforced losses","unforcedTurnovers"}, {"Interceptions","interceptions"},
        {"Penalties","penalties"}, {"Penalty minutes","penaltyMinutes",false,1},
        {"Legal screens","screens"}
    },
    {
        title="Goalkeeping & faceoffs",
        {"Saves","saves"}, {"Goals allowed","goalsAllowed"}, {"Shots faced","shotsFaced"},
        {"Save %","savePct",true}, {"Goalie wins","wins"}, {"Goalie losses","losses"},
        {"Faceoffs won","faceoffsWon"}, {"Faceoff attempts","faceoffAttempts"},
        {"Faceoff %","faceoffPct",true}
    }
}

local playerInfo = {
    title="Appearances",
    {"Games played","gamesPlayed"}, {"Games started","gamesStarted"},
    {"Minutes played","minutesPlayed",false,1}, {"Clear attempts","clearsAttempted"},
    {"Clears completed","clearsCompleted"}, {"Clear %","clearPct",true},
    {"Screen assists","screenAssists"}, {"Open shots from screens","screenOpenShots"},
    {"Illegal screens","illegalScreens"}
}

local function box(x,y,w,h,label,id)
    return {x=x,y=y,w=w,h=h,label=label,id=id}
end

local function clamp(value,low,high)
    return math.min(high,math.max(low,value))
end

local function begin()
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    font("AvenirNext-DemiBold")
    textAlign(CENTER)
    textMode(CENTER)
end

local function finish()
    popMatrix()
    popStyle()
end

local function fillBox(item,tint)
    fill(tint)
    rectMode(CENTER)
    if P.Style then P.Style.rounded(item.x,item.y,item.w,item.h,8,tint)
    else rect(item.x,item.y,item.w,item.h) end
end

local function label(value,x,y,size,tint,maximum)
    value = tostring(value or "")
    fill(tint or white)
    fontSize(size)
    if maximum and textSize then
        local width = textSize(value)
        if width > maximum then fontSize(math.max(8,size*maximum/width)) end
    end
    text(value,x,y)
end

local function button(item,selected)
    fillBox(item,selected and active or panel)
    label(item.label,item.x,item.y,13,white,item.w-8)
end

local function formatted(line,stat)
    if stat[3] then
        local value = line.rates[stat[2]]
        return value and string.format("%.0f%%",value*100) or "–"
    end
    local value = line.stats[stat[2]] or 0
    if stat[4] then return string.format("%.1f",value) end
    return tostring(value)
end

function StatsUI.entry(playHUD,game)
    if not game.statistics then return nil end
    local pause,camera=playHUD.pause,playHUD.camera
    local left=pause and pause.x+pause.w*.5+4 or (playHUD.leftX or 12)
    local right=camera and camera.x-camera.w*.5-4 or left+84
    local width=math.min(84,right-left)
    if width<39 then return nil end
    local title=game.statSummary and width>=66 and "BOX SCORE" or "STATS"
    return box(left+width*.5,playHUD.headerY-98,width,33,title,"statistics")
end

function StatsUI.drawEntry(playHUD,game)
    local item = StatsUI.entry(playHUD,game)
    if not item then return end
    begin()
    button(item,false)
    finish()
end

function StatsUI.open(game)
    local summary = game.source and game.sides and game or P.Statistics.matchSummary(game)
    if not summary then return nil end
    return {summary=summary,view="teams",page=1,side=1}
end

function StatsUI.layout(state)
    local safe = P.UI and P.UI.safeArea and P.UI.safeArea() or {left=0,right=0,top=0,bottom=0}
    local w = math.min(560,WIDTH-safe.left-safe.right-28)
    local cx = (WIDTH+safe.left-safe.right)*.5
    local left,right = cx-w*.5,cx+w*.5
    local top = HEIGHT-safe.top-24
    local footer = safe.bottom+33
    local summary = state.summary
    local view = state.view
    local selected = state.player and summary.players[state.player]
    local hud = {
        cx=cx,w=w,left=left,right=right,top=top,footer=footer,
        state=state,summary=summary,selected=selected,
        close=box(right-33,top,66,33,"CLOSE","close"),
        teams=box(left+w*.25,top-50,w*.5-4,36,"TEAM STATS","teams"),
        players=box(left+w*.75,top-50,w*.5-4,36,"PLAYERS","players"),
        leftPage=box(left+28,footer,56,36,"‹","previous"),
        rightPage=box(right-28,footer,56,36,"›","next"),
        rows={}
    }
    local topRows = top-177
    if view == "teams" or selected then
        hud.pages = selected and #pages+1 or #pages
        hud.page = clamp(state.page,1,hud.pages)
        hud.section = pages[hud.page] or playerInfo
        local height = clamp((topRows-footer-20)/#hud.section,21,39)
        for i, stat in ipairs(hud.section) do
            hud.rows[i] = box(cx,topRows-(i-.5)*height,w,height-2,stat[1],stat[2])
            hud.rows[i].stat = stat
        end
        if selected then
            hud.back = box(left+39,top-121,78,29,"ROSTER","roster")
        end
    else
        local side = summary.sides[state.side]
        local roster = side and side.roster or {}
        hud.home = box(left+w*.25,top-116,w*.5-4,31,summary.sides[1].name,"home")
        hud.away = box(left+w*.75,top-116,w*.5-4,31,summary.sides[2].name,"away")
        local count = clamp(math.floor((topRows-footer-12)/42),3,8)
        hud.pages = math.max(1,math.ceil(#roster/count))
        hud.page = clamp(state.page,1,hud.pages)
        local first = (hud.page-1)*count+1
        for i = first, math.min(first+count-1,#roster) do
            local line = summary.players[roster[i]]
            local item = box(cx,topRows-(i-first)*42-14,w,39,line.name,"player")
            item.player = line
            hud.rows[#hud.rows+1] = item
        end
    end
    return hud
end

local function teamHeader(hud)
    local summary = hud.summary
    local one,two = summary.sides[1],summary.sides[2]
    local y = hud.top-101
    label(one.name,hud.cx-hud.w*.29,y,14,soft,hud.w*.40)
    label(two.name,hud.cx+hud.w*.29,y,14,soft,hud.w*.40)
    label(summary.homeScore.." – "..summary.awayScore,hud.cx,y,21,white,hud.w*.19)
    local id = summary.playerOfGame
    local player = id and summary.players[id]
    if player then
        label("PLAYER OF THE GAME  ·  "..player.name,hud.cx,y-29,12,accent,hud.w-12)
    elseif not summary.final then
        label("LIVE BOX SCORE",hud.cx,y-29,11,accent,hud.w)
    end
end

local function drawStats(hud)
    local one,two = hud.summary.sides[1],hud.summary.sides[2]
    if hud.selected then
        button(hud.back,false)
        local player = hud.selected
        label(("#%s  %s  ·  %s"):format(player.number or "–",player.name or "",player.role or ""),
            hud.cx+hud.w*.14,hud.top-111,17,white,hud.w-101)
    else
        teamHeader(hud)
    end
    label(hud.section.title,hud.cx,hud.top-160,14,accent,hud.w)
    for i, item in ipairs(hud.rows) do
        fillBox(item,i%2==0 and alternate or panel)
        if hud.selected then
            label(item.label,hud.cx-hud.w*.17,item.y,13,soft,hud.w*.60)
            label(formatted(hud.selected,item.stat),hud.cx+hud.w*.34,item.y,14,white,hud.w*.17)
        else
            label(item.label,hud.cx,item.y,13,soft,hud.w*.52)
            label(formatted(one,item.stat),hud.cx-hud.w*.39,item.y,14,white,hud.w*.18)
            label(formatted(two,item.stat),hud.cx+hud.w*.39,item.y,14,white,hud.w*.18)
        end
    end
end

local function drawRoster(hud)
    button(hud.home,hud.state.side==1)
    button(hud.away,hud.state.side==2)
    label("PLAYER",hud.left+39,hud.top-151,11,soft,65)
    label("G / A / GB",hud.right-59,hud.top-151,11,soft,96)
    for i,item in ipairs(hud.rows) do
        local player = item.player
        fillBox(item,i%2==0 and alternate or panel)
        label(player.number or "–",hud.left+22,item.y,13,accent,33)
        label(player.name,hud.left+hud.w*.35,item.y,14,white,hud.w*.47)
        local stats = player.stats
        local line = player.role=="G" and (tostring(stats.saves or 0).." SV")
            or ("%d / %d / %d"):format(stats.goals or 0,stats.assists or 0,stats.groundBalls or 0)
        label(line,hud.right-57,item.y,13,soft,104)
    end
end

function StatsUI.draw(hud)
    begin()
    fillBox(box(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT),background)
    local mode = hud.summary.final and "Box score" or "Match statistics"
    label(mode,hud.left+78,hud.top,22,white,157)
    button(hud.close,false)
    button(hud.teams,hud.state.view=="teams")
    button(hud.players,hud.state.view=="players")
    if hud.state.view=="teams" or hud.selected then drawStats(hud)
    else drawRoster(hud) end
    if hud.page>1 then button(hud.leftPage,false) end
    if hud.page<hud.pages then button(hud.rightPage,false) end
    label(("%d / %d"):format(hud.page,hud.pages),hud.cx,hud.footer,13,soft,84)
    finish()
end

function StatsUI.touch(state,hud,touch)
    if touch.state~=BEGAN then return nil end
    local function hit(item)
        return item and math.abs(touch.x-item.x)<=item.w*.5 and math.abs(touch.y-item.y)<=item.h*.5
    end
    if hit(hud.close) then return "close" end
    if hit(hud.teams) then state.view,state.page,state.player="teams",1,nil
    elseif hit(hud.players) then state.view,state.page,state.player="players",1,nil
    elseif hit(hud.home) then state.side,state.page=1,1
    elseif hit(hud.away) then state.side,state.page=2,1
    elseif hit(hud.back) then state.player,state.page=nil,state.rosterPage or 1
    elseif hit(hud.leftPage) and hud.page>1 then state.page=hud.page-1
    elseif hit(hud.rightPage) and hud.page<hud.pages then state.page=hud.page+1
    else
        for _,item in ipairs(hud.rows) do
            if item.player and hit(item) then
                state.player,state.page,state.rosterPage=item.player.playerId,1,hud.page
                break
            end
        end
    end
    return "handled"
end
