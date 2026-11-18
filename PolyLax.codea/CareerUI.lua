-- PolyLax Build 012 | Road to the Pros menu
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.CareerUI = UI

local deep = color(7, 19, 35)
local surface = color(20, 40, 62)
local soft = color(158, 182, 206)
local white = color(246, 249, 255)
local amber = color(253, 205, 85)

local function box(x, y, w, h, label)
    return {x=x, y=y, w=w, h=h, label=label}
end

function UI.layout(career)
    local safe = P.UI.safeArea()
    local width = math.min(480, WIDTH-safe.left-safe.right-32)
    local center = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-18, math.max(26, safe.bottom+15)
    return {
        x=center, w=width, top=top, bottom=bottom,
        back=box(center-width*.5+37,top-20,74,36,"Back"),
        name=box(center,top-122,width,44,career.name),
        position=box(center,top-177,width,44,P.Career.positions[career.position].label),
        team=box(center,top-232,width,44,P.Career.teamName(career)),
        play=box(center,bottom+26,width,48,"Play career game")
    }
end

local function label(value, x, y, size, tint)
    fill(tint)
    fontSize(size)
    text(value,x,y)
end

local function card(item, sub, strong, disabled)
    rectMode(CENTER)
    fill(strong and amber or surface)
    rect(item.x,item.y,item.w,item.h)
    if sub then label(sub,item.x,item.y+9,10,soft) end
    label(item.label,item.x,item.y-(sub and 7 or 0),strong and 15 or 13,
        strong and deep or disabled and soft or white)
end

function UI.draw(career, l, playing, editing, draft, message)
    background(deep)
    pushStyle()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    card(l.back)
    label("Road to the Pros",l.x,l.top-54,24,white)
    label(P.Career.stages[career.stage],l.x,l.top-82,12,amber)
    if editing then
        card(box(l.name.x,l.name.y,l.name.w,l.name.h,draft.."|"),"PLAYER NAME")
    else
        card(l.name,"PLAYER NAME")
    end
    card(l.position,"POSITION",false,career.games>0)
    card(l.team,"TEAM",false,true)
    local y = l.top-275
    label(string.format("RECORD  %d–%d–%d       XP  %d",career.wins,career.losses,career.ties,career.xp),
        l.x,y,13,white)
    local stats = career.stats
    label(string.format("%d G   %d A   %d GB   %d CTO   %d SV   %d FO",
        stats.goals or 0,stats.assists or 0,stats.groundBalls or 0,stats.causedTurnovers or 0,
        stats.saves or 0,stats.faceoffs or 0),l.x,y-21,12,soft)
    if message then label(message,l.x,l.bottom+72,11,amber) end
    if playing then
        l.play.label = playing.game.phase == "FINAL" and "Retry saving result" or "Resume career game"
    end
    card(l.play,nil,true)
    popStyle()
end
