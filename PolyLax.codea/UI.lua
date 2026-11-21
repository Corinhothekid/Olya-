-- PolyLax 2.0 | Creator and match HUD
PolyLax = PolyLax or {}
local UI = {}
PolyLax.UI = UI

local navy = color(12, 18, 28)
local panel = color(17, 25, 36)
local blue = color(54, 133, 240)
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
    PolyLax.Style.panel(item.x, item.y, item.w, item.h, selected, 7)
    label(item.label, item.x, item.y, size or 12, white)
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

function UI.creatorLayout(categories, options)
    options = options or {}
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
        athlete=options.athlete, kit=options.kit,
        home=box(left+23,footerY,46,34,options.athlete and "BACK" or "HOME","home"),
        done=box(w-safe.right-49,headerY,82,39,options.athlete and "HOME KIT" or "PRACTICE"),
        fullGame=box(w-safe.right-136,headerY,82,39,options.athlete and "AWAY KIT" or "FULL GAME"),
        reset=box(right-68, panelHeight+23, 136, 34, "RESET CAMERA"),
        career=box(right-171, panelHeight+23, 56, 34, "CAREER", "career"),
        left=box(left+(right-left)*.29,footerY,48,34,"<"),
        right=box(right-(right-left)*.20,footerY,48,34,">"),
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

function UI.creator(layout, category, categoryIndex, selected, firstOption, showCareer, options)
    if type(showCareer) == "table" then options,showCareer = showCareer,false end
    local athlete = layout.athlete or options and options.athlete
    local kit = options and options.kit or layout.kit
    local away = type(kit) == "string" and kit:lower() == "away"
    beginHud()
    fillRect(0, HEIGHT-layout.topBar, WIDTH, layout.topBar, navy)
    local title=athlete and options and options.team and options.team.short or "MODIFY PLAYER"
    leftLabel(title,layout.leftX+2,layout.headerY+(athlete and 6 or 0),WIDTH<350 and 15 or 18,white)
    if athlete and options and options.uniform then
        for index,tint in ipairs({options.uniform.primary,options.uniform.secondary,options.uniform.accent}) do
            fill(tint)
            ellipseMode(CENTER)
            ellipse(layout.leftX+9+(index-1)*16,layout.headerY-12,10)
        end
    end
    button(layout.fullGame,not athlete or away,11)
    button(layout.done,athlete and not away,11)
    fillRect(0,0,WIDTH,layout.panelHeight,navy)
    fillRect(0,layout.panelHeight-5,WIDTH,5,panel)
    fillRect(layout.leftX,layout.panelHeight-1,54,2,blue)
    leftLabel(category.label or category.key, layout.leftX+2, layout.panelHeight+23, 12, white)
    button(layout.reset, false, 11)
    if showCareer and not athlete then button(layout.career,false,10) end

    for _, item in ipairs(layout.categories) do
        button(item, item.id == categoryIndex, item.label == "LEG SLEEVES" and 10 or 12)
    end

    for slot = 1, math.min(#category.choices, #layout.options) do
        local item = layout.options[slot]
        local index = firstOption + slot - 1
        item.label = category.choices[index]
        if category.key=="IDENTITY" and options then
            local key=index==1 and "first" or "last"
            local value=options.part==key and (options.draft or "").."|" or options[key]
            PolyLax.Style.panel(item.x,item.y,item.w,item.h,options.part==key,7)
            label(item.label,item.x,item.y+6,8,silver)
            label(value and value~="" and value or "Edit",item.x,item.y-7,9,white)
        elseif category.key == "TEAM" or category.key == "OPPONENT" then
            local city, name = item.label:match("^(.*) (%S+)$")
            if city then
                local active = index == selected
                PolyLax.Style.panel(item.x,item.y,item.w,item.h,active,7)
                label(city,item.x,item.y+6,9,active and white or silver)
                label(name,item.x,item.y-7,11,white)
            else
                button(item, index == selected, 11)
            end
        else
            button(item, index == selected, 11)
        end
    end
    button(layout.home,false,10)
    button(layout.left,false,16)
    button(layout.right, false, 16)
    label(tostring(selected) .. " / " .. tostring(#category.choices),
        layout.centerX, layout.footerY, 12, silver)
    endHud()
end

local glass = color(10, 21, 38, 222)
local glassSoft = color(14, 26, 43, 188)
local muted = color(169, 190, 210)
local sky = color(117, 204, 255)
local warm = color(255, 217, 98)
local red = color(251, 141, 137)
local function rounded(...)
    return PolyLax.Style.rounded(...)
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

function UI.practiceLayout(showPositioning)
    local safe = UI.safeArea()
    local left, right = safe.left+12, WIDTH-safe.right-12
    local width, header = right-left, HEIGHT-safe.top
    local footer = math.max(12,safe.bottom+6)
    local tacticalHeight = 40
    local controlBase = footer+tacticalHeight+8
    local diameter = math.min(69,width*.21)
    local bX = right-diameter*.5-2
    local aX = bX-diameter-6
    local joyMaxX = left+math.min(width*.31,104)
    local joyX = (left+joyMaxX)*.5
    local joyRadius = math.min(43,(joyMaxX-left)*.44)
    local joyY = controlBase+joyRadius+1
    local auxRight = aX-diameter*.5-5
    local auxX = (joyMaxX+auxRight)*.5
    local auxWidth = math.min(64,auxRight-joyMaxX-4)
    local panelHeight = math.max(joyY+joyRadius+30,controlBase+diameter+36)
    local cameraW = math.max(106,math.min(137,width*.37))

    local layout = {
        panelHeight=panelHeight, headerY=header, leftX=left, rightX=right,
        centerX=(left+right)*.5, width=width, footer=footer, touches={}, motion={},
        frame={bottom=panelHeight+6,top=header-(showPositioning and 141 or 117)},
        joyX=joyX, joyY=joyY, joyRadius=joyRadius, joyMaxX=joyMaxX, joyMinY=controlBase,
        commands={}, tactical={},
        edit=box(right-25,header-60,50,32,"EDIT","edit"),
        reset=box(right-81,header-60,54,32,"RESET","reset"),
        zoomIn=box(right-18,header-98,36,33,"+","zoomIn"),
        zoomOut=box(right-58,header-98,36,33,"-","zoomOut"),
        camera=box(right-80-cameraW*.5,header-98,cameraW,33,"CAMERA","camera"),
        pause=box(left+25,header-98,50,33,"PAUSE","pause"),
        sprint=box(joyX,joyY+joyRadius+16,math.min(78,joyMaxX-left-6),28,"SPRINT","sprint")
    }
    if showPositioning then
        layout.positionNotice = box(layout.centerX,header-126,width,20)
    end

    local primaryA = box(aX,controlBase+diameter*.5,diameter,diameter,"PASS","pass")
    local primaryB = box(bX,controlBase+diameter*.89,diameter,diameter,"SHOOT","shoot")
    primaryA.primary, primaryB.primary = "A","B"
    layout.primaryA, layout.primaryB = primaryA, primaryB
    layout.commands = {
        box(auxX,controlBase+18,auxWidth,33,"DODGE","dodge"),
        box(auxX,controlBase+57,auxWidth,33,"PICK","setpick"),
        box(aX,controlBase+diameter+19,math.min(61,diameter),31,"SWITCH","switch"),
        primaryA, primaryB
    }

    layout.tacticalPanel = box(layout.centerX,footer+tacticalHeight*.5,width+8,tacticalHeight+6)
    local tactical = {
        {"swing","SWING"}, {"clear","CLEAR"}, {"passdown","PASS DOWN"}, {"pickdown","PICK DOWN"}
    }
    local span = width/#tactical
    for i,pair in ipairs(tactical) do
        local item = box(left+span*(i-.5),layout.tacticalPanel.y,span-5,tacticalHeight,pair[2],pair[1])
        item.tactical = true
        layout.tactical[i] = item
        layout.commands[#layout.commands+1] = item
    end
    return layout
end

local faceoffActions = {shoot="faceoff",pass="counter"}
local defenseActions = {pass="poke",shoot="body",dodge="slap",switch="switch"}
local legacyDefense = {pass="poke",switch="switch"}

local function holderOf(game)
    return game.carrier and game.squad[game.carrier]
end

function UI.action(game, item)
    if not item then return nil end
    local id = item.id
    if game.careerWaiting or id == "switch" and game.careerPlayer then return nil end
    if game.clubsPlayer and (id=="switch" or item.tactical) then return nil end
    if game.phase == "FACEOFF" then
        local draw = game.faceoff
        if game.clubsPlayer and (not draw or game.clubsPlayer~=draw.home.id) then return nil end
        if draw and (draw.userTeam == false or draw.phase == "EXIT") then return nil end
        if id == "pass" and (not draw or draw.meter == nil) then return nil end
        return faceoffActions[id]
    end
    if game.homeScore ~= nil and game.phase ~= "LIVE" then return nil end
    if game.inNet or game.clock and game.clock <= 0 then return nil end
    if id == "pass" and game.loose then return "scoop" end
    local holder = holderOf(game)
    if game.homeScore ~= nil and holder and holder.team == 2 then
        return (PolyLax.Defense and defenseActions or legacyDefense)[id]
    end
    if item.tactical and (not holder or game.pending or game.flight) then return nil end
    if id == "setpick" then
        local player = game.squad[game.controlled]
        if not holder or game.carrier == game.controlled or player and player.role == "G"
            or game.screen and game.screen.screener ~= game.controlled then return nil end
    end
    if id == "shoot" and game.carrier ~= game.controlled then return nil end
    if id == "pass" and not holder then return nil end
    if id == "sprint" and game.homeScore ~= nil and not holder then return nil end
    return id
end

local icons = {
    setpick={{-2,-7,-2,7},{2,-7,2,7},{-8,0,-2,0},{2,0,8,0}},
    switch={{-7,3,7,3},{7,3,3,7},{7,3,3,-1},{7,-3,-7,-3},{-7,-3,-3,-7},{-7,-3,-3,1}},
    dodge={{-7,-5,-2,3},{-2,3,2,-2},{2,-2,8,5},{8,5,4,5},{8,5,8,1}},
    slap={{-8,6,-2,3},{-2,3,7,-6},{-7,-3,-3,-3},{-5,-5,-5,-1},{2,6,7,6}},
    sprint={{-7,6,-1,0},{-1,0,-7,-6},{1,6,7,0},{7,0,1,-6}},
    pause={{-2,-6,-2,6},{2,-6,2,6}},
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

local primaryBlue = color(22,130,65,248)
local primaryBlueLight = color(43,177,92,244)
local primaryBlueDark = color(23,66,42,227)
local primaryRed = color(181,49,49,248)
local primaryRedLight = color(231,76,76,244)
local primaryRedDark = color(81,37,37,227)
local primaryRim = color(155,181,207,195)
local controlShadow = color(5,9,14,208)
local graphite = color(34,42,52,241)
local graphiteDim = color(26,33,42,228)
local graphiteEdge = color(107,122,136,132)

local function compactAction(layout, item, action, textValue, active)
    local press = 1-.06*motionAmount(layout,item)
    local fillTint = active and warm or action and graphite or graphiteDim
    local textTint = active and navy or action and white or muted
    rounded(item.x,item.y,item.w,item.h,9,graphiteEdge,press)
    rounded(item.x,item.y,item.w-2,item.h-2,8,fillTint,press)
    local symbol = not item.tactical and item.w >= 54 and (action or item.id)
    local hasSymbol = symbol and icons[symbol]
    if hasSymbol then
        icon(symbol,item.x-item.w*.5+11,item.y,.63,active and navy or muted)
    end
    label(textValue,item.x+(hasSymbol and 5 or 0),item.y,item.w < 51 and 9 or 10,textTint)
    if item.id == "dodge" or item.id == "setpick" then
        local key = item.id == "dodge" and "X" or "Y"
        local tint = item.id == "dodge" and color(38,120,205) or color(218,168,37)
        ellipseMode(CENTER)
        fill(tint)
        ellipse(item.x-item.w*.5+9,item.y+item.h*.5-3,16)
        label(key,item.x-item.w*.5+9,item.y+item.h*.5-3,9,white)
    end
end

local function primaryAction(layout, item, action, textValue, active)
    local press = 1-.085*motionAmount(layout,item)
    local span = item.w*press
    local isBlue = item.primary == "A"
    local fillTint = action and (isBlue and primaryBlue or primaryRed)
        or (isBlue and primaryBlueDark or primaryRedDark)
    local face = action and (isBlue and primaryBlueLight or primaryRedLight) or fillTint
    ellipseMode(CENTER)
    fill(controlShadow)
    ellipse(item.x,item.y-2,span+2)
    fill(active and warm or primaryRim)
    ellipse(item.x,item.y,span+1)
    fill(fillTint)
    ellipse(item.x,item.y,span-2)
    fill(face)
    ellipse(item.x,item.y+2,span-7)
    label(item.primary,item.x,item.y+7,25,action and white or muted)
    label(textValue,item.x,item.y-14,item.w < 51 and 8 or 10,action and white or muted)
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
    if not game.clubsPlayer then
        chip(layout,layout.reset,"RESET")
        chip(layout,layout.edit,"EDIT")
    end
end

local stickFace = color(13,19,26,232)
local stickThumb = color(61,74,90,247)
local stickLight = color(126,140,155,203)
local stickTexture = color(160,175,190,135)
local function drawJoystick(layout, x, y)
    local r, jx, jy = layout.joyRadius, layout.joyX, layout.joyY
    local knobX, knobY = jx+x*r*.55,jy+y*r*.55
    ellipseMode(CENTER)
    fill(controlShadow)
    ellipse(jx,jy-2,r*2+3)
    fill(graphiteEdge)
    ellipse(jx,jy,r*2+2)
    fill(graphite)
    ellipse(jx,jy,r*2)
    fill(stickFace)
    ellipse(jx,jy,r*1.70)
    stroke(graphiteEdge)
    strokeWidth(1.2)
    for index=0,11 do
        local theta = index*math.pi/6
        local dx,dy = math.cos(theta),math.sin(theta)
        local inner = r*(index % 3 == 0 and .78 or .86)
        line(jx+dx*inner,jy+dy*inner,jx+dx*r*.96,jy+dy*r*.96)
    end
    noStroke()
    fill(controlShadow)
    ellipse(knobX,knobY-2,r*.93)
    fill(stickLight)
    ellipse(knobX,knobY,r*.90)
    fill(stickThumb)
    ellipse(knobX,knobY+1,r*.80)
    fill(stickTexture)
    for column=-2,2 do
        for row=-2,2 do
            if column*column+row*row <= 5 then
                ellipse(knobX+column*r*.105,knobY+row*r*.105,1.6)
            end
        end
    end
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

local function passTarget(layout, guide)
    if not guide or guide.y < layout.frame.bottom or guide.y > layout.frame.top
        or guide.x < layout.leftX or guide.x > layout.rightX then return end
    local x, y = guide.x,guide.y
    local tint = guide.manual and sky or white
    ellipseMode(CENTER)
    stroke(tint)
    strokeWidth(guide.manual and 2.5 or 1.5)
    noFill()
    ellipse(x,y,guide.manual and 26 or 20)
    noStroke()
    if guide.name and guide.name ~= "" then
        local w = math.min(124,math.max(38,#guide.name*6+14))
        local bx = math.max(layout.leftX+w*.5,math.min(layout.rightX-w*.5,x))
        local by = y+21 < layout.frame.top and y+21 or y-21
        rounded(bx,by,w,18,7,glass)
        label(guide.name,bx,by,10,tint)
    end
end

local function tacticMode(game)
    local value = game.mode
    if type(game.tactical) == "table" and game.tactical.team ~= 2 then
        value = game.tactical.call or game.tactical.mode or game.tactical.name or value
    elseif type(game.tactical) == "string" then
        value = game.tactical
    end
    return type(value) == "string" and value:gsub("[%s_%-]",""):lower()
end

local function commandLabel(item, action, game, aim)
    if action == "shoot" and aim then return "AIM" end
    if action == "pass" and game.carrier and game.carrier ~= game.controlled then return "CALL" end
    return actionNames[action] or item.label
end

local warningGlass = color(57,42,22,237)
local offsidesGlass = color(63,29,41,240)
local function drawPositionNotice(layout, game)
    local positioning = game.positioning
    if game.phase ~= "LIVE" or not positioning or (positioning.noticeTime or 0) <= 0 then return end
    local message = positioning.notice
    if type(message) ~= "string" or message == "" then return end
    local strip = layout.positionNotice
    local x, y, width, height = layout.centerX,layout.frame.top-15,layout.width,23
    if strip then x, y, width, height = strip.x,strip.y,strip.w,strip.h end
    local foul = positioning.level == "offsides"
    local ink = foul and red or warm
    local size = 11
    if textSize then
        fontSize(size)
        local measured = textSize(message)
        if measured > width-25 then size = math.max(9,size*(width-25)/measured) end
    end
    rounded(x,y,width,height,8,foul and offsidesGlass or warningGlass)
    rounded(x-width*.5+8,y,3,height*.59,1.5,ink)
    label(message,x+3,y,size,ink)
    return message
end

local function drawRulesClock(layout, game)
    local strip, clock = layout.positionNotice, game.ruleClock
    if not strip or game.phase ~= "LIVE" or not clock then return end
    local labels = {}
    if clock.shot then labels[#labels+1] = "SHOT "..math.ceil(clock.shot) end
    if clock.clear then labels[#labels+1] = "CLEAR "..math.ceil(clock.clear) end
    if clock.crease then labels[#labels+1] = "CREASE "..math.ceil(clock.crease) end
    if #labels == 0 then return end
    local remaining = math.min(clock.shot or math.huge,clock.clear or math.huge,
        clock.crease or math.huge)
    rounded(strip.x,strip.y,strip.w,strip.h,8,glassSoft)
    label(table.concat(labels,"    ·    "),strip.x,strip.y,11,remaining <= 5 and warm or white)
end

function UI.practice(layout, game, moveX, moveZ, aim, cameraLabel, ballEdge, passGuide)
    beginHud()
    local positionMessage = drawPositionNotice(layout,game)
    if not positionMessage then drawRulesClock(layout,game) end
    drawAim(aim)
    drawBallEdge(ballEdge)
    passTarget(layout,passGuide)
    drawScore(layout,game)
    chip(layout,layout.pause,game.clubsPlayer and "LOBBY" or "PAUSE","pause")
    chip(layout,layout.camera,cameraLabel or "CAMERA","camera")
    chip(layout,layout.zoomOut,"","zoomOut")
    chip(layout,layout.zoomIn,"","zoomIn")

    local bar = layout.tacticalPanel
    rounded(bar.x,bar.y,bar.w,bar.h,11,glassSoft)
    drawJoystick(layout,moveX,moveZ)
    local sprintAction = UI.action(game,layout.sprint)
    compactAction(layout,layout.sprint,sprintAction,"SPRINT",
        sprintAction and motionAmount(layout,layout.sprint)>.1)

    local mode = tacticMode(game)
    local screen = game.screen
    local settingPick = screen and screen.phase ~= "RELEASE" and screen.screener == game.controlled
    for _, item in ipairs(layout.commands) do
        local action = UI.action(game,item)
        local active = item.tactical and mode == item.id
            or action == "shoot" and aim ~= nil
            or action == "setpick" and settingPick
        local title = commandLabel(item,action,game,aim)
        if item.primary then
            primaryAction(layout,item,action,title,active)
        else
            compactAction(layout,item,action,title,active)
        end
    end

    if game.phase == "FINAL" then
        finalScore(game,layout)
    else
        drawFaceoff(layout,game)
        local message = game.clubsStatus or game.careerWaiting and game.phase == "LIVE" and "FIRST SHIFT SOON"
            or game.announcementTime > 0 and game.announcement
            or game.clock <= 0 and game.homeScore == nil and "PRACTICE COMPLETE"
        if message and message ~= "" and message ~= positionMessage then
            local spacing = positionMessage and not layout.positionNotice and 33 or 0
            local y = layout.frame.top-15-spacing
            rounded(layout.centerX,y,math.min(layout.width,#message*8+32),34,12,glass)
            label(message,layout.centerX,y,14,warm)
        end
    end
    endHud()
end
