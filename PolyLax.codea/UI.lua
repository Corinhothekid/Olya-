-- PolyLax Build 010 | UI
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
    return math.abs(x - item.x) <= item.w * .5 and
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

local function safeInsets()
    local runtimeLayout = _ENV.layout
    local kind = type(runtimeLayout)
    if kind ~= "table" and kind ~= "userdata" then return 0, 0 end

    local safe = runtimeLayout.safeArea
    return safe and safe.top or 0, safe and safe.bottom or 0
end

function UI.creatorLayout(categories)
    local w, h = WIDTH, HEIGHT
    local topInset, bottomInset = safeInsets()
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
    local categoryWidth = (w - 24) / 4
    local optionWidth = (w - 24) / 3
    local layout = {
        topBar=topBar, headerY=headerY, panelHeight=panelHeight, footerY=footerY,
        frame={bottom=panelHeight+49, top=h-topBar-9},
        done=box(w-49, headerY, 82, 39, "PRACTICE"),
        fullGame=box(w-136, headerY, 82, 39, "FULL GAME"),
        reset=box(w-80, panelHeight+23, 136, 34, "RESET CAMERA"),
        left=box(w * .25 + 10, footerY, 64, 34, "<"),
        right=box(w * .75 - 10, footerY, 64, 34, ">"),
        categories={}, options={}
    }

    for index, category in ipairs(categories) do
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        layout.categories[index] = box(12 + (column + .5) * categoryWidth,
            categoriesBottom + (3.5 - row) * categoryHeight,
            categoryWidth - 5, categoryHeight - 4, category.label or category.key, index)
    end
    for index = 1, 6 do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        layout.options[index] = box(12 + (column + .5) * optionWidth,
            optionsBottom + (1.5 - row) * optionHeight,
            optionWidth - 5, optionHeight - 4)
    end
    return layout
end

function UI.firstOption(category, selected)
    return math.max(1, math.min(selected - 2, #category.choices - 5))
end

function UI.creator(layout, category, categoryIndex, selected, firstOption)
    beginHud()
    fillRect(0, HEIGHT-layout.topBar, WIDTH, layout.topBar, navy)
    leftLabel("MODIFY PLAYER", 14, layout.headerY, WIDTH < 350 and 15 or 18, white)
    button(layout.fullGame, true, 11)
    button(layout.done, false, 11)
    fillRect(0, 0, WIDTH, layout.panelHeight, navy)
    fillRect(0, layout.panelHeight, WIDTH, 2, blue)
    leftLabel(category.label or category.key, 14, layout.panelHeight+23, 12, white)
    button(layout.reset, false, 11)

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
        WIDTH * .5, layout.footerY, 12, silver)
    endHud()
end

function UI.practiceLayout()
    local w, h = WIDTH, HEIGHT
    local topInset, bottomInset = safeInsets()
    local headerY = h - topInset
    local footer = math.max(28, bottomInset + 10)
    local rowHeight = math.min(49, h * .078)
    local panelHeight = 2 * rowHeight + footer + 15
    local joystickX, joystickY = w * .19, footer + rowHeight
    local joystickRadius = math.min(w * .135, rowHeight - 2)
    local firstX = w * .36
    local buttonWidth = (w - firstX - 10) / 3
    local layout = {
        panelHeight=panelHeight, headerY=headerY, joyX=joystickX, joyY=joystickY, joyRadius=joystickRadius,
        commands={},
        edit=box(w-50, headerY-56, 76, 32, "EDIT"),
        reset=box(w-132, headerY-56, 76, 32, "RESET")
    }
    local labels = {"SWING", "CLEAR", "SWITCH", "DODGE", "PASS", "SHOOT"}
    for index, name in ipairs(labels) do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        layout.commands[index] = box(firstX + (column + .5) * buttonWidth,
            footer + (1.5 - row) * rowHeight, buttonWidth - 5, rowHeight - 5,
            name, string.lower(name))
    end
    return layout
end

local function drawAim(guide)
    if not guide then return end
    local start, target = guide.from, guide.target
    stroke(yellow)
    strokeWidth(2)
    line(start.x, start.y, target.x, target.y)
    noFill()
    ellipseMode(CENTER)
    ellipse(target.x, target.y, 16)
    line(target.x - 11, target.y, target.x + 11, target.y)
    line(target.x, target.y - 11, target.x, target.y + 11)
    noStroke()
end

local function finalScore(game, layout)
    local y = (layout.panelHeight + layout.headerY - 80) * .5
    fillRect(18, y-83, WIDTH-36, 166, navy)
    label("FINAL SCORE", WIDTH*.5, y+60, 15, silver)
    label(string.format("%s %d  -  %d %s", game.homeTeam.short, game.homeScore,
        game.awayScore, game.awayTeam.short), WIDTH*.5, y+31, 24, yellow)
    local home, away = game.stats[1], game.stats[2]
    label(string.format("SHOTS     %d - %d        SAVES     %d - %d",
        home.shots, away.shots, home.saves, away.saves), WIDTH*.5, y-2, 12, white)
    label(string.format("GROUND BALLS     %d - %d", home.groundBalls, away.groundBalls),
        WIDTH*.5, y-28, 12, white)
    label(string.format("TURNOVERS     %d - %d", home.turnovers, away.turnovers),
        WIDTH*.5, y-52, 12, white)
end

function UI.practice(layout, game, moveX, moveZ, aim)
    beginHud()
    drawAim(aim)
    fillRect(0, layout.headerY-80, WIDTH, HEIGHT-layout.headerY+80, navy)
    local minutes, seconds = math.floor(game.clock / 60), math.floor(game.clock % 60)
    if game.homeScore ~= nil then
        leftLabel(string.format("%s %d - %d %s", game.homeTeam.short, game.homeScore,
            game.awayScore, game.awayTeam.short), 12, layout.headerY-23, 17, white)
        label(string.format("Q%d   %d:%02d", game.period, minutes, seconds),
            WIDTH - 60, layout.headerY-23, 13, white)
    else
        leftLabel("POLYLAX", 12, layout.headerY-24, 19, white)
        label(string.format("%d:%02d    G %d    P %d", minutes, seconds, game.goals, game.passes),
            WIDTH - 83, layout.headerY-23, 13, white)
    end
    local holder = game.carrier and game.squad[game.carrier]
    local ballLabel = holder and holder.name or (game.inNet and "IN NET" or "LOOSE")
    if holder and game.homeScore ~= nil then
        local team = holder.team == 1 and game.homeTeam or game.awayTeam
        ballLabel = team.short .. " " .. holder.name
    end
    leftLabel(game.squad[game.controlled].name .. "  /  BALL " .. ballLabel,
        12, layout.headerY - 56, 12, silver)
    button(layout.reset, false, 11)
    button(layout.edit, false, 11)

    fillRect(0, 0, WIDTH, layout.panelHeight, navy)
    fillRect(0, layout.panelHeight, WIDTH, 2, panel)
    ellipseMode(CENTER)
    fill(tile)
    ellipse(layout.joyX, layout.joyY, layout.joyRadius*2)
    fill(blue)
    ellipse(layout.joyX + moveX*layout.joyRadius*.62, layout.joyY + moveZ*layout.joyRadius*.62,
        layout.joyRadius*.77)
    for _, item in ipairs(layout.commands) do
        local active = (item.id == "clear" and game.mode == "CLEAR") or
                       (item.id == "swing" and game.mode == "SWING")
        local name = item.label
        if item.id == "pass" and game.loose then name = "SCOOP" end
        if item.id == "shoot" then
            if game.phase == "FACEOFF" then name = "CLAMP"
            elseif aim then name, active = "AIM", true end
        end
        local holder = game.carrier and game.squad[game.carrier]
        if item.id == "dodge" and game.homeScore ~= nil and holder and holder.team ~= 1 then
            name = "CHECK"
        end
        if name == item.label then
            button(item, active, 11)
        else
            button(box(item.x, item.y, item.w, item.h, name), active, 11)
        end
    end
    if game.phase == "FINAL" then
        finalScore(game, layout)
    elseif game.announcementTime > 0 then
        label(game.announcement, WIDTH * .5, layout.headerY - 109, 18, yellow)
    elseif game.clock <= 0 then
        label("PRACTICE COMPLETE", WIDTH * .5, layout.headerY - 109, 18, yellow)
    end
    endHud()
end
