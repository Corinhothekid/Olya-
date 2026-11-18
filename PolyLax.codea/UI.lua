-- PolyLax Build 012 | Creator and match HUD
PolyLax = PolyLax or {}
local UI = {}
PolyLax.UI = UI

local navy = color(7, 28, 60)
local panel = color(16, 45, 88)
local tile = color(29, 64, 113)
local blue = color(16, 115, 245)
local yellow = color(255, 211, 66)
local white = color(240, 244, 247)
local silver = color(174, 191, 205)

local function box(x, y, width, height, label, id)
    return {x=x, y=y, w=width, h=height, label=label, id=id}
end

function UI.hit(item, x, y)
    return item ~= nil and math.abs(x - item.x) <= item.w * .5 and
           math.abs(y - item.y) <= item.h * .5
end

local function beginHud()
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

local function endHud()
    popMatrix()
    popStyle()
end

local function label(textValue, x, y, size, tint)
    fill(tint)
    fontSize(size)
    text(textValue, x, y)
end

local function leftLabel(textValue, x, y, size, tint)
    textMode(CORNER)
    label(textValue, x, y - size * .55, size, tint)
    textMode(CENTER)
end

local function fillRect(x, y, width, height, tint)
    rectMode(CORNER)
    fill(tint)
    rect(x, y, width, height)
end

local function button(item, selected, size)
    rectMode(CENTER)
    fill(selected and yellow or tile)
    rect(item.x, item.y, item.w, item.h)
    label(item.label, item.x, item.y, size or 12, selected and navy or white)
end

function UI.safeArea()
    local source = _ENV.layout
    local kind = type(source)
    local safe = (kind == "table" or kind == "userdata") and source.safeArea
    return {
        top=safe and safe.top or 0, bottom=safe and safe.bottom or 0,
        left=safe and safe.left or 0, right=safe and safe.right or 0
    }
end

function UI.creatorLayout(categories)
    local w, h = WIDTH, HEIGHT
    local safe = UI.safeArea()
    local topInset, bottomInset = safe.top, safe.bottom
    local topBar = topInset + 55
    local headerY = h - topInset - 27
    local panelHeight = math.min(365, h * .46)
    local clearBottom = math.max(27, bottomInset + 12)
    local footerY = clearBottom + 15
    local contentHeight = panelHeight - clearBottom - 43
    local optionHeight = contentHeight * .36 / 2
    local categoryHeight = contentHeight * .64 / 4
    local optionsBottom = clearBottom + 36
    local categoriesBottom = optionsBottom + optionHeight * 2 + 6
    local left, right = 12 + safe.left, w - 12 - safe.right
    local categoryWidth, optionWidth = (right-left)/4, (right-left)/3
    local layout = {
        topBar=topBar, headerY=headerY, panelHeight=panelHeight, footerY=footerY,
        frame={bottom=panelHeight+49, top=h-topBar-9},
        leftX=left, centerX=(left+right)*.5,
        done=box(w-safe.right-49, headerY, 82, 39, "PRACTICE"),
        fullGame=box(w-safe.right-136, headerY, 82, 39, "FULL GAME"),
        reset=box(right-68, panelHeight+23, 136, 34, "RESET CAMERA"),
        career=box(right-171, panelHeight+23, 56, 34, "CAREER", "career"),
        left=box(w * .25 + 10, footerY, 64, 34, "<"),
        right=box(w * .75 - 10, footerY, 64, 34, ">"),
        categories={}, options={}
    }

    for index, category in ipairs(categories) do
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        layout.categories[index] = box(left + (column + .5) * categoryWidth,
            categoriesBottom + (3.5 - row) * categoryHeight,
            categoryWidth - 5, categoryHeight - 4, category.label or category.key, index)
    end
    for index = 1, 6 do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        layout.options[index] = box(left + (column + .5) * optionWidth,
            optionsBottom + (1.5 - row) * optionHeight,
            optionWidth - 5, optionHeight - 4)
    end
    return layout
end

function UI.firstOption(category, selected)
    return math.max(1, math.min(selected - 2, #category.choices - 5))
end

function UI.creator(layout, category, categoryIndex, selected, firstOption, showCareer)
    beginHud()
    fillRect(0, HEIGHT-layout.topBar, WIDTH, layout.topBar, navy)
    leftLabel("MODIFY PLAYER", layout.leftX+2, layout.headerY, WIDTH < 350 and 15 or 18, white)
    button(layout.fullGame, true, 11)
    button(layout.done, false, 11)
    fillRect(0, 0, WIDTH, layout.panelHeight, navy)
    fillRect(0, layout.panelHeight, WIDTH, 2, blue)
    leftLabel(category.label or category.key, layout.leftX+2, layout.panelHeight+23, 12, white)
    button(layout.reset, false, 11)
    if showCareer then button(layout.career, true, 10) end

    for _, item in ipairs(layout.categories) do
        button(item, item.id == categoryIndex, item.label == "LEG SLEEVES" and 10 or 12)
    end

    for slot = 1, math.min(#category.choices, #layout.options) do
        local item = layout.options[slot]
        local index = firstOption + slot - 1
        item.label = category.choices[index]
        if category.key == "TEAM" or category.key == "OPPONENT" then
            local city, name = item.label:match("^(.*) (%S+)$")
            if city then
                local active = index == selected
                rectMode(CENTER)
                fill(active and yellow or tile)
                rect(item.x, item.y, item.w, item.h)
                label(city, item.x, item.y + 6, 9, active and navy or silver)
                label(name, item.x, item.y - 7, 11, active and navy or white)
            else
                button(item, index == selected, 11)
            end
        else
            button(item, index == selected, 11)
        end
    end
    button(layout.left, false, 16)
    button(layout.right, false, 16)
    label(tostring(selected) .. " / " .. tostring(#category.choices),
        layout.centerX, layout.footerY, 12, silver)
    endHud()
end

local glass = color(10, 21, 38, 222)
local glassSoft = color(14, 26, 43, 188)
local control = color(32, 54, 79, 238)
local outline = color(119, 155, 187, 108)
local muted = color(169, 190, 210)
local sky = color(117, 204, 255)
local warm = color(255, 217, 98)
local red = color(251, 141, 137)
local roundMeshes = {}

-- Tessellated corners preserve the opacity of the translucent surface.
local function rounded(x, y, w, h, radius, tint, scaleFactor)
    if w <= 0 or h <= 0 then return end
    radius = math.min(radius,w*.5,h*.5)
    if not mesh then
        rectMode(CENTER)
        fill(tint)
        rect(x,y,w*(scaleFactor or 1),h*(scaleFactor or 1))
        return
    end
    local key = string.format("%.2f,%.2f,%.2f",w,h,radius)
    local shape = roundMeshes[key]
    if not shape then
        local perimeter = {}
        for corner=0,3 do
            local cx = (corner == 0 or corner == 3) and w*.5-radius or radius-w*.5
            local cy = corner < 2 and h*.5-radius or radius-h*.5
            for sub=0,4 do
                local angle = (corner+sub*.25)*math.pi*.5
                perimeter[#perimeter+1] = vec3(cx+math.cos(angle)*radius,cy+math.sin(angle)*radius,0)
            end
        end
        local vertices, center = {}, vec3(0,0,0)
        for index, point in ipairs(perimeter) do
            vertices[#vertices+1] = center
            vertices[#vertices+1] = point
            vertices[#vertices+1] = perimeter[index % #perimeter+1]
        end
        shape = mesh()
        shape.vertices = vertices
        if (roundMeshes.count or 0) >= 120 then roundMeshes = {} end
        roundMeshes[key] = shape
        roundMeshes.count = (roundMeshes.count or 0) + 1
    end
    shape:setColors(tint)
    pushMatrix()
    translate(x,y)
    if scaleFactor then scale(scaleFactor) end
    shape:draw()
    popMatrix()
end

function UI.press(layout, item, id)
    if not item or id == nil then return end
    layout.motion = layout.motion or {}
    layout.touches = layout.touches or {}
    UI.release(layout,id)
    local motion = layout.motion[item] or {amount=0,held=0}
    layout.motion[item], layout.touches[id] = motion, item
    motion.held = motion.held+1
    motion.amount = math.max(motion.amount,.18)
end

function UI.release(layout, id)
    local item = layout.touches and id ~= nil and layout.touches[id]
    if not item then return end
    local motion = layout.motion[item]
    motion.held = math.max(0,motion.held-1)
    layout.touches[id] = nil
end

function UI.step(layout, dt)
    if not layout.motion then return end
    for item, motion in pairs(layout.motion) do
        local target = motion.held > 0 and 1 or 0
        local easing = 1-math.exp(-(target == 1 and 27 or 17)*dt)
        motion.amount = motion.amount+(target-motion.amount)*easing
        if target == 0 and motion.amount < .002 then layout.motion[item] = nil end
    end
end

function UI.practiceLayout()
    local safe = UI.safeArea()
    local left, right = safe.left+12, WIDTH-safe.right-12
    local width, header = right-left, HEIGHT-safe.top
    local footer = math.max(12,safe.bottom+8)
    local row = math.min(55,math.max(50,HEIGHT*.085))
    local actionLeft = left+width*.37
    local actionWidth = (right-actionLeft)/3
    local joyRadius = math.min(40,width*.135,row*.68)
    local panelHeight = footer+row*2+11
    local joyX, joyY = (left+actionLeft)*.5, footer+joyRadius+2
    local cameraW = math.max(106,math.min(137,width*.37))

    local layout = {
        panelHeight=panelHeight, headerY=header, leftX=left, rightX=right,
        centerX=(left+right)*.5, width=width, footer=footer, touches={}, motion={},
        frame={bottom=panelHeight+6,top=header-120},
        joyX=joyX, joyY=joyY, joyRadius=joyRadius, joyMaxX=actionLeft,
        commands={},
        edit=box(right-25,header-60,50,32,"EDIT","edit"),
        reset=box(right-81,header-60,54,32,"RESET","reset"),
        zoomIn=box(right-18,header-98,36,33,"+","zoomIn"),
        zoomOut=box(right-58,header-98,36,33,"-","zoomOut"),
        camera=box(right-80-cameraW*.5,header-98,cameraW,33,"CAMERA","camera"),
        sprint=box(joyX,footer+row*2-12,math.min(width*.34,120),30,"SPRINT","sprint")
    }
    local names = {"swing","clear","switch","dodge","pass","shoot"}
    for index, name in ipairs(names) do
        local column, rowIndex = (index-1)%3, math.floor((index-1)/3)
        layout.commands[index] = box(actionLeft+(column+.5)*actionWidth,
            footer+(1.5-rowIndex)*row,actionWidth-6,row-6,name:upper(),name)
    end
    return layout
end

local defenseActions = {dodge="poke",pass="slap",shoot="body",switch="switch"}
local legacyDefense = {dodge="poke",switch="switch"}
local faceoffActions = {shoot="faceoff",dodge="counter"}

function UI.action(game, item)
    if not item then return nil end
    local id = item.id
    if game.careerWaiting or id == "switch" and game.careerPlayer then return nil end
    if game.phase == "FACEOFF" then
        local draw = game.faceoff
        if draw and (draw.userTeam == false or draw.phase == "EXIT") then return nil end
        if id == "dodge" and (not draw or draw.meter == nil) then return nil end
        return faceoffActions[id]
    end
    if game.homeScore ~= nil and game.phase ~= "LIVE" then return nil end
    if game.inNet then return nil end
    if id == "pass" and game.loose then return "scoop" end
    local holder = game.carrier and game.squad[game.carrier]
    if game.homeScore ~= nil and holder and holder.team == 2 then
        return (PolyLax.Defense and defenseActions or legacyDefense)[id]
    end
    return id
end

local icons = {
    swing={{-8,-3,5,-3},{5,-3,1,-7},{5,-3,1,1},{8,3,-5,3},{-5,3,-1,7},{-5,3,-1,-1}},
    clear={{-8,-5,1,4},{1,4,7,4},{7,4,4,7},{7,4,4,1},{0,-5,7,-5}},
    switch={{-7,3,7,3},{7,3,3,7},{7,3,3,-1},{7,-3,-7,-3},{-7,-3,-3,-7},{-7,-3,-3,1}},
    dodge={{-7,-5,-2,3},{-2,3,2,-2},{2,-2,8,5},{8,5,4,5},{8,5,8,1}},
    pass={{-8,-4,7,4},{7,4,0,5},{7,4,3,-2},{-7,1,-3,3}},
    shoot={{-7,6,7,6},{-7,-6,7,-6},{-7,6,-7,-6},{7,6,7,-6},{-3,0,3,0},{0,-3,0,3}},
    scoop={{-8,-5,2,-5},{2,-5,7,0},{7,0,7,4},{3,3,7,7},{7,7,10,3}},
    poke={{-7,-5,7,5},{7,5,2,5},{7,5,6,0},{-7,1,-3,1}},
    slap={{-8,6,-2,3},{-2,3,7,-6},{-7,-3,-3,-3},{-5,-5,-5,-1},{2,6,7,6}},
    body={{0,7,0,-7},{-6,2,6,2},{-6,2,-8,-2},{6,2,8,-2},{-5,-7,0,-3},{0,-3,5,-7}},
    faceoff={{-8,6,0,-3},{8,6,0,-3},{-5,-4,5,-4},{-3,-7,3,-7}},
    counter={{-7,-5,-7,3},{-7,3,5,3},{5,3,1,7},{5,3,1,-1},{1,-4,7,-4}},
    sprint={{-7,6,-1,0},{-1,0,-7,-6},{1,6,7,0},{7,0,1,-6}},
    camera={{-8,5,4,5},{4,5,4,-5},{4,-5,-8,-5},{-8,-5,-8,5},{4,2,8,5},{8,5,8,-5},{8,-5,4,-2}},
    zoomIn={{-5,0,5,0},{0,-5,0,5}},
    zoomOut={{-5,0,5,0}}
}
local actionNames = {faceoff="CLAMP",counter="COUNTER",body="BODY",poke="POKE",slap="SLAP",scoop="SCOOP"}

local function icon(name, x, y, factor, tint)
    local strokes = icons[name]
    if not strokes then return end
    stroke(tint)
    strokeWidth(1.65*factor)
    for _, edge in ipairs(strokes) do
        line(x+edge[1]*factor,y+edge[2]*factor,x+edge[3]*factor,y+edge[4]*factor)
    end
    noStroke()
end

local function motionAmount(layout, item)
    local motion = layout.motion[item]
    return motion and motion.amount or 0
end

local function chip(layout, item, name, symbol, emphatic)
    local press = 1-.06*motionAmount(layout,item)
    rounded(item.x,item.y,item.w,item.h,10,emphatic and warm or glass,press)
    if symbol then
        local iconX = name == "" and item.x or item.x-item.w*.5+15
        icon(symbol,iconX,item.y,.76,emphatic and navy or sky)
    end
    if name ~= "" then
        label(name,item.x+(symbol and 7 or 0),item.y,10,emphatic and navy or white)
    end
end

local primaryControl = color(244,195,74,239)
local defensiveControl = color(48,56,78,242)
local function actionButton(layout, item, action, textValue, active)
    local press = 1-.085*motionAmount(layout,item)
    local primary = action == "shoot" or action == "faceoff"
    local defense = action == "body" or action == "poke" or action == "slap"
    local background = active and warm or primary and primaryControl or defense and defensiveControl or control
    local ink = (active or primary) and navy or white
    local accent = (active or primary) and navy or defense and red or sky
    rounded(item.x,item.y,item.w,item.h,13,outline,press)
    rounded(item.x,item.y,item.w-2,item.h-2,12,background,press)
    icon(action,item.x,item.y+7,.91*press,accent)
    label(textValue,item.x,item.y-12,item.w < 49 and 9 or 10,ink)
end

local function drawAim(guide)
    if not guide then return end
    local start, target = guide.from, guide.target
    stroke(color(255,217,98,196))
    strokeWidth(2)
    line(start.x,start.y,target.x,target.y)
    stroke(warm)
    noFill()
    ellipseMode(CENTER)
    ellipse(target.x,target.y,20)
    line(target.x-14,target.y,target.x-8,target.y)
    line(target.x+8,target.y,target.x+14,target.y)
    line(target.x,target.y-14,target.x,target.y-8)
    line(target.x,target.y+8,target.x,target.y+14)
    noStroke()
end

local function drawScore(layout, game)
    local x, y = layout.centerX, layout.headerY-19
    local left, right = layout.leftX, layout.rightX
    rounded(x,y,layout.width,34,12,glass)
    local minutes, seconds = math.floor(game.clock/60), math.floor(game.clock%60)
    local time = string.format("%d:%02d",minutes,seconds)
    if game.homeScore ~= nil then
        local home, away = game.homeTeam, game.awayTeam
        local homeColor = home.home and home.home.accent or sky
        local awayColor = away.home and away.home.accent or muted
        rounded(left+10,y,4,18,2,homeColor)
        rounded(right-10,y,4,18,2,awayColor)
        label(home.short,left+33,y,13,white)
        label(away.short,right-33,y,13,white)
        label(tostring(game.homeScore),left+67,y,19,white)
        label(tostring(game.awayScore),right-67,y,19,white)
        label("Q"..game.period.."   "..time,x,y,13,warm)
    else
        leftLabel("POLYLAX",left+11,y,15,white)
        label(time,x,y,14,warm)
        label("G "..game.goals.."   P "..game.passes,right-43,y,11,muted)
    end

    local holder = game.carrier and game.squad[game.carrier]
    local controlled = game.squad[game.controlled]
    local contact = holder and holder.name
        or game.inNet and "IN NET"
        or game.flight and "IN FLIGHT"
        or "LOOSE"
    if holder and game.homeScore ~= nil then
        contact = (holder.team == 1 and game.homeTeam.short or game.awayTeam.short).." "..contact
    elseif game.phase == "FACEOFF" then
        contact = "FACEOFF"
    end
    local status = (controlled and controlled.name or "-").."  /  "..contact
    local width = math.min(layout.width-116,math.max(114,#status*6.5+16))
    rounded(left+width*.5,layout.edit.y,width,32,10,glassSoft)
    leftLabel(status,left+8,layout.edit.y,11,white)
    chip(layout,layout.reset,"RESET")
    chip(layout,layout.edit,"EDIT")
end

local stickCenter = color(145,185,224,76)
local function drawJoystick(layout, x, y)
    local r, jx, jy = layout.joyRadius, layout.joyX, layout.joyY
    ellipseMode(CENTER)
    fill(outline)
    ellipse(jx,jy,r*2+2)
    fill(glass)
    ellipse(jx,jy,r*2)
    fill(stickCenter)
    ellipse(jx,jy,r*.89)
    fill(sky)
    ellipse(jx+x*r*.63,jy+y*r*.63,r*.76)
end

local function clamp01(value)
    return math.max(0,math.min(1,value))
end

local meterTrack = color(46,62,82,255)
local meterWindow = color(87,192,142,235)
local function drawFaceoff(layout, game)
    local faceoff = game.faceoff
    if game.phase ~= "FACEOFF" or not faceoff then return end
    local x, y = layout.centerX,layout.frame.bottom+48
    local width = math.min(264,layout.width-20)
    local meterWidth, yMeter = width-30,y-3
    local defaultTime = 1.55
    local meter = clamp01(faceoff.meter or (game.phaseTime or 0)/defaultTime)
    local start = clamp01(faceoff.windowStart or .74/defaultTime)
    local finish = clamp01(faceoff.windowEnd or 1.18/defaultTime)
    local left = x-meterWidth*.5
    local cpu = faceoff.cpuMeter or (type(faceoff.cpu) == "number" and faceoff.cpu)
    local exit = faceoff.phase == "EXIT"
    local title, prompt = "FACEOFF","Time your clamp in the green"
    if exit then
        title,prompt = "CHOOSE EXIT","Move to your outlet"
        if faceoff.result and faceoff.result.loose then
            title,prompt = "LOOSE BALL","Chase the exit"
        end
    elseif faceoff.active == false then
        title,prompt = "GET SET","Watch the whistle"
    end
    if faceoff.userTeam == false then
        title,prompt = "FACEOFF","Waiting for possession"
    end

    rounded(x,y,width,77,15,glass)
    label(title,x,y+22,13,white)
    rounded(x,yMeter,meterWidth,13,6,meterTrack)
    rounded(left+meterWidth*(start+finish)*.5,yMeter,meterWidth*(finish-start),
        13,6,meterWindow)
    if faceoff.sweetSpot then
        rounded(left+meterWidth*clamp01(faceoff.sweetSpot),yMeter,2,11,1,white)
    end
    rounded(left+meterWidth*meter,yMeter,6,20,3,warm)
    if cpu then rounded(left+meterWidth*clamp01(cpu),yMeter-12,5,5,2,red) end
    label(prompt,x,y-25,11,muted)
end

local function finalScore(game, layout)
    local x, y = layout.centerX,(layout.frame.top+layout.frame.bottom)*.5
    local home, away = game.stats[1],game.stats[2]
    rounded(x,y,layout.width-9,176,22,glass)
    label("FINAL SCORE",x,y+63,13,muted)
    label(string.format("%s %d  -  %d %s",game.homeTeam.short,game.homeScore,
        game.awayScore,game.awayTeam.short),x,y+34,25,warm)
    label(string.format("SHOTS  %d - %d       SAVES  %d - %d",
        home.shots,away.shots,home.saves,away.saves),x,y+1,12,white)
    label(string.format("GROUND BALLS   %d - %d",home.groundBalls,away.groundBalls),x,y-26,12,white)
    label(string.format("TURNOVERS   %d - %d",home.turnovers,away.turnovers),x,y-52,12,white)
end

local function drawBallEdge(mark)
    if not mark then return end
    local x, y, dx, dy = mark.x,mark.y,mark.dx,mark.dy
    rounded(x-dx*6,y-dy*6,22,22,10,glass)
    fill(warm)
    ellipseMode(CENTER)
    ellipse(x-dx*6,y-dy*6,6)
    stroke(warm)
    strokeWidth(2)
    line(x+dx*7,y+dy*7,x-dy*4,y+dx*4)
    line(x+dx*7,y+dy*7,x+dy*4,y-dx*4)
    noStroke()
end

function UI.practice(layout, game, moveX, moveZ, aim, cameraLabel, ballEdge)
    beginHud()
    drawAim(aim)
    drawBallEdge(ballEdge)
    drawScore(layout,game)
    chip(layout,layout.camera,cameraLabel or "CAMERA","camera")
    chip(layout,layout.zoomOut,"","zoomOut")
    chip(layout,layout.zoomIn,"","zoomIn")

    local y = (layout.panelHeight+layout.footer)*.5
    rounded(layout.centerX,y,layout.width+8,layout.panelHeight-layout.footer+12,20,glassSoft)
    drawJoystick(layout,moveX,moveZ)
    if UI.action(game,layout.sprint) then
        chip(layout,layout.sprint,"SPRINT","sprint",motionAmount(layout,layout.sprint)>.1)
    end

    for _, item in ipairs(layout.commands) do
        local action = UI.action(game,item)
        if action then
            local active = action == "clear" and game.mode == "CLEAR"
                or action == "swing" and game.mode == "SWING"
                or action == "shoot" and aim ~= nil
            local textValue = action == "shoot" and aim and "AIM" or actionNames[action] or item.label
            actionButton(layout,item,action,textValue,active)
        end
    end

    if game.phase == "FINAL" then
        finalScore(game,layout)
    else
        drawFaceoff(layout,game)
        local message = game.careerWaiting and game.phase == "LIVE" and "FIRST SHIFT SOON"
            or game.announcementTime > 0 and game.announcement
            or game.clock <= 0 and game.homeScore == nil and "PRACTICE COMPLETE"
        if message and message ~= "" then
            local y = layout.frame.top-15
            rounded(layout.centerX,y,math.min(layout.width,#message*8+32),34,12,glass)
            label(message,layout.centerX,y,14,warm)
        end
    end
    endHud()
end
