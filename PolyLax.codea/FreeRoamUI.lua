-- Safe-area-aware campus HUD, dialogue and pause panel.
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.FreeRoamUI = UI

local ink = {
    paper=color(245,245,233), dim=color(183,197,192), gold=color(238,206,137),
    glass=color(13,24,27,232), rim=color(74,91,81,232), green=color(38,85,65,246),
    soft=color(119,170,145), empty=color(22,35,36,169), veil=color(8,15,19,155),
    knob=color(68,112,91,245), shade=color(8,13,16,172)
}

local names = {
    campus="Briarbank Campus", school="Briarbank High", lockers="Locker Rooms",
    training="Training Facility", coach="Coach’s Office", drip="PolyLax Drip Lab",
    clubhouse="Pro Clubs Clubhouse"
}

local actions = {
    ethan="Talk", coach="Talk", jace="Talk", clubs="ENTER PRO CLUBS",
    tryout="Start Tryout", practice="Practice", training="Train", drip="Browse Gear"
}

local timeLabels = {
    morning="Morning", afternoon="Afternoon", practice="Practice time", evening="Evening"
}

local function box(id, title, x, y, width, height)
    return {id=id,label=title,x=x,y=y,w=width,h=height}
end

local function baseLayout(safe)
    local left = safe.left+12
    local right = WIDTH-safe.right-12
    local top = HEIGHT-safe.top-10
    local bottom = safe.bottom+12
    local width = right-left
    local center = (left+right)*.5
    local radius = math.min(48, width*.149)
    local joystick = box("move",nil,left+radius+5,bottom+radius+12,2*radius,2*radius)
    joystick.radius = radius
    local actionWidth = math.min(145,width*.42)
    local interact = box("interact","Interact",right-actionWidth*.5,bottom+73,actionWidth,45)
    local dockWidth = math.min(184,right-(joystick.x+radius+12))
    local gap = 5
    local buttonWidth = (dockWidth-3*gap)*.25
    local function cameraButton(id,label,index)
        local x = right-dockWidth+buttonWidth*.5+(index-1)*(buttonWidth+gap)
        return box(id,label,x,bottom+20,buttonWidth,38)
    end
    local orbitLeft = cameraButton("orbitLeft","‹",1)
    local orbitRight = cameraButton("orbitRight","›",2)
    local zoomOut = cameraButton("zoomOut","−",3)
    local zoomIn = cameraButton("zoomIn","+",4)
    local pause = box("pause","Ⅱ",right-21,top-22,42,42)
    local career = box("career","Career Log",left+(width-7)*.25,top-137,(width-7)*.5,37)
    local equipment = box("equipment","Equipment",right-(width-7)*.25,top-137,(width-7)*.5,37)
    return {
        left=left,right=right,top=top,bottom=bottom,center=center,width=width,
        joystick=joystick,interact=interact,orbitLeft=orbitLeft,orbitRight=orbitRight,
        zoomOut=zoomOut,zoomIn=zoomIn,
        pause=pause,career=career,equipment=equipment,lookBottom=bottom+121,lookTop=top-165,
        controls={interact,orbitLeft,orbitRight,zoomOut,zoomIn,pause,career,equipment}
    }
end

local function wrapped(value, width, fontPixels)
    local lines, current = {}, ""
    local limit = math.max(14,math.floor(width/(fontPixels*.55)))
    for word in tostring(value or ""):gmatch("%S+") do
        if #current+#word+1 > limit and current~="" then
            lines[#lines+1],current = current,word
        else
            current = (current=="" and word or current.." "..word)
        end
    end
    if current~="" then lines[#lines+1] = current end
    return lines
end

local function modalLayout(layout, dialogue)
    local options = dialogue.choices
    local count = math.max(1,options and #options or 0)
    local width = math.min(490,layout.width)
    local textHeight = 21
    local lines = wrapped(dialogue.text,width-35,15)
    local viewport = layout.top-layout.bottom-18
    local optionHeight = math.min(44,(viewport-100)/math.max(count,4))
    local card = {
        w=width, h=67+#lines*textHeight+count*(optionHeight+7), x=layout.center,
        bottom=layout.bottom+6, choices={}, lines=lines, textHeight=textHeight,
        speaker=dialogue.speaker or "Campus"
    }
    local excess = card.h-viewport
    if excess>0 and #lines>0 then
        card.textHeight = math.max(12,textHeight-excess/#lines)
        card.h = 67+#lines*card.textHeight+count*(optionHeight+7)
    end
    card.y = card.bottom+card.h*.5
    card.top = card.bottom+card.h
    for i=1,count do
        local option = options and options[i]
        local button = box("choice",option and option.label or "Continue",
            card.x, card.bottom+(count-i+.5)*(optionHeight+7)+6, card.w-24, optionHeight)
        button.choice = i
        card.choices[i] = button
    end
    return card
end

function UI.layout(roam)
    local safe = P.UI.safeArea()
    local cache = roam.hud
    local stamp = WIDTH..":"..HEIGHT..":"..safe.left..":"..safe.right..":"..safe.top..":"..safe.bottom
    if not cache or cache.stamp~=stamp then
        cache = baseLayout(safe)
        cache.stamp = stamp
        roam.hud = cache
    end
    if roam.dialogue then
        if cache.dialogue ~= roam.dialogue then
            cache.dialogue,cache.modal = roam.dialogue,modalLayout(cache,roam.dialogue)
        end
        cache.buttons,cache.choices = cache.modal.choices,cache.modal.choices
    elseif roam.paused then
        if not cache.pauseItems then
            local y = (cache.top+cache.bottom)*.5+28
            local width = math.min(290,cache.width-30)
            cache.pauseItems = {
                box("resume","Resume",cache.center,y,width,44),
                box("settings","Settings",cache.center,y-57,width,44),
                box("home","Main Menu",cache.center,y-114,width,44)
            }
        end
        cache.buttons,cache.choices = cache.pauseItems,nil
    else
        cache.interact.enabled = roam.point~=nil
        cache.zoomOut.enabled = roam.zoomSteps>P.FreeRoam.minZoom
        cache.zoomIn.enabled = roam.zoomSteps<P.FreeRoam.maxZoom
        cache.buttons,cache.choices = cache.controls,nil
    end
    return cache
end

local function begin()
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    font("AvenirNext-DemiBold")
    textMode(CENTER)
    textAlign(CENTER)
end

local function shade(value, x, y, size, tint, width, left)
    if not value then return end
    value = tostring(value)
    fill(tint)
    fontSize(size)
    if width and textSize then
        local used = textSize(value)
        if used > width then fontSize(math.max(10,size*width/used)) end
    end
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.53 or y)
    if left then textMode(CENTER) end
end

local function rounded(x,y,w,h,r,tint)
    P.Style.rounded(x,y,w,h,r,tint)
end

local function panel(x,y,w,h,r,tint,edge)
    rounded(x,y,w,h,r,edge or ink.rim)
    rounded(x,y,w-2,h-2,r-1,tint or ink.glass)
end

local function button(item, active, title, size, accent)
    local color = item.enabled==false and ink.empty or active and ink.knob or accent and ink.green or ink.glass
    panel(item.x,item.y,item.w,item.h,12,color,accent and ink.soft or ink.rim)
    shade(title or item.label,item.x,item.y,size or 14,item.enabled==false and ink.dim or ink.paper,item.w-11)
end

local function blackout(tint)
    rectMode(CORNER)
    fill(tint)
    rect(0,0,WIDTH,HEIGHT)
end

local function pressed(roam, item)
    return roam.press and roam.press.item==item
end

local function drawDialogue(roam, card)
    blackout(ink.veil)
    panel(card.x,card.y,card.w,card.h,18)
    rounded(card.x-card.w*.5+17,card.top-26,4,21,2,ink.gold)
    shade(card.speaker,card.x-card.w*.5+28,card.top-25,20,ink.gold,card.w-39,true)
    for index,line in ipairs(card.lines) do
        shade(line,card.x-card.w*.5+18,card.top-52-(index-1)*card.textHeight,
            math.min(15,card.textHeight),ink.paper,card.w-36,true)
    end
    for _,item in ipairs(card.choices) do
        button(item,pressed(roam,item),nil,14,true)
    end
end

local function drawPause(roam, hud)
    blackout(ink.veil)
    local centerY = (hud.top+hud.bottom)*.5
    panel(hud.center,centerY-12,math.min(320,hud.width),246,18)
    shade("Paused",hud.center,centerY+82,24,ink.paper,hud.width-20)
    for _,item in ipairs(hud.pauseItems) do
        button(item,pressed(roam,item),nil,15,item.id=="resume")
    end
end

local function drawObjective(roam, hud)
    local y = hud.top-82
    panel(hud.center,y,hud.width,59,12)
    shade("Objective",hud.left+13,y+17,12,ink.gold,hud.width-26,true)
    local objective = roam.objective and roam.objective() or "Explore the campus"
    if hud.objectiveText ~= objective then
        hud.objectiveText = objective
        hud.objectiveLines = wrapped(objective,hud.width-25,14)
    end
    local lines = hud.objectiveLines
    if #lines==1 then
        shade(lines[1],hud.left+13,y-7,14,ink.paper,hud.width-26,true)
    else
        shade(lines[1],hud.left+13,y-2,13,ink.paper,hud.width-26,true)
        shade(table.concat(lines," ",2),hud.left+13,y-18,13,ink.paper,hud.width-26,true)
    end
end

local function drawCampus(roam,hud)
    local headerWidth = hud.width-49
    local headerX = hud.left+headerWidth*.5
    panel(headerX,hud.top-22,headerWidth,42,12)
    local time = timeLabels[roam.timeOfDay]
    shade(names[roam.zone] or "Campus",hud.left+13,hud.top-(time and 17 or 22),17,
        ink.paper,headerWidth-25,true)
    if time then shade(time,hud.left+13,hud.top-33,11,ink.gold,headerWidth-25,true) end
    button(hud.pause,pressed(roam,hud.pause),nil,18)
    drawObjective(roam,hud)
    button(hud.career,pressed(roam,hud.career))
    button(hud.equipment,pressed(roam,hud.equipment))
    button(hud.orbitLeft,pressed(roam,hud.orbitLeft),nil,21)
    button(hud.orbitRight,pressed(roam,hud.orbitRight),nil,21)
    button(hud.zoomOut,pressed(roam,hud.zoomOut),nil,21)
    button(hud.zoomIn,pressed(roam,hud.zoomIn),nil,21)

    local joy = hud.joystick
    ellipseMode(CENTER)
    fill(ink.shade)
    ellipse(joy.x,joy.y-2,joy.w+3)
    fill(ink.rim)
    ellipse(joy.x,joy.y,joy.w)
    fill(ink.glass)
    ellipse(joy.x,joy.y,joy.w-2)
    for quarter=0,3 do
        fill(ink.soft)
        ellipse(joy.x+math.cos(quarter*math.pi*.5)*joy.radius*.77,
            joy.y+math.sin(quarter*math.pi*.5)*joy.radius*.77,4)
    end
    local x,y = joy.x+roam.axisX*joy.radius*.61,joy.y+roam.axisY*joy.radius*.61
    fill(ink.soft)
    ellipse(x,y,joy.radius*.91)
    fill(ink.knob)
    ellipse(x,y,joy.radius*.79)
    local point = roam.point
    button(hud.interact,pressed(roam,hud.interact),
        point and (point.action or actions[point.id] or (point.zone and "Enter" or "Interact")) or nil,
        point and point.id=="clubs" and 13 or 15,point~=nil)
    if point then
        shade(point.label,hud.interact.x,hud.interact.y+40,12,ink.paper,hud.interact.w+18)
    end
    if roam.noticeTime>0 then
        local noticeY = hud.bottom+149
        panel(hud.center,noticeY,hud.width,33,10)
        shade(roam.noticeText,hud.center,noticeY,12,ink.paper,hud.width-17)
    end
end

function UI.draw(roam, fade)
    local hud = UI.layout(roam)
    begin()
    if roam.dialogue then
        drawDialogue(roam,hud.modal)
    elseif roam.paused then
        drawPause(roam,hud)
    else
        drawCampus(roam,hud)
    end
    if fade and fade>0 then blackout(color(8,15,19,math.floor(math.min(1,fade)*255))) end
    popMatrix()
    popStyle()
end
