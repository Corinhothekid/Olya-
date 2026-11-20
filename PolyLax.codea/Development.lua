-- PolyLax 2.0 | Skill points, match rewards and training menu
PolyLax = PolyLax or {}
local P = PolyLax
local Development = {}
P.Development = Development

local schema = 1
local milestones = {
    {id="firstMatch", key="games", target=1, points=6},
    {id="fiveMatches", key="games", target=5, points=12},
    {id="firstWin", key="wins", target=1, points=6},
    {id="firstGoal", key="goals", target=1, points=6},
    {id="firstAssist", key="assists", target=1, points=5},
    {id="fiveSaves", key="saves", target=5, points=8},
    {id="fiveDraws", key="faceoffs", target=5, points=8},
    {id="tenGroundBalls", key="groundBalls", target=10, points=8},
    {id="firstScreen", key="screens", target=1, points=5}
}

local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge then return minimum end
    return math.max(minimum, math.min(maximum, math.floor(value)))
end

local function count(value)
    return integer(value, 0, 10000000)
end

local function copy(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do result[key] = value end
    end
    return result
end

local function savedState(career)
    local saved = career.development
    return type(saved) == "table" and saved.schema == schema and saved or nil
end

function Development.points(career)
    local xp = count(career.xp)
    local legacySpent = math.min(xp, count(career.spentXP))
    local saved = savedState(career)
    if not saved then return xp - legacySpent end
    -- Take in only XP and legacy expenditures accumulated since the last write.
    local earned = math.max(0, xp - count(saved.accountedXP))
    local spent = math.max(0, legacySpent - count(saved.accountedLegacy))
    return count(count(saved.points) + earned - spent)
end

local function snapshot(career)
    local saved = savedState(career) or {}
    return {
        schema=schema, points=Development.points(career),
        accountedXP=count(career.xp), accountedLegacy=math.min(count(career.xp), count(career.spentXP)),
        spent=count(saved.spent), claims=copy(saved.claims), milestones=copy(saved.milestones),
        lastReward=saved.lastReward
    }
end

function Development.claimed(career, key)
    local saved = savedState(career)
    return saved ~= nil and type(saved.claims) == "table" and saved.claims[key] == true
end

local function commit(career, candidate, save)
    save = save or P.Career.save
    if not save(candidate) then return false, "Could not save development" end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

local function performancePoints(stats)
    local score = count(stats.goals) * 2 + count(stats.assists) * 2 + count(stats.saves)
        + count(stats.groundBalls) + count(stats.faceoffs) * 2
        + count(stats.causedTurnovers) * 2 + count(stats.interceptions) * 2
        - count(stats.turnovers) - count(stats.fouls) * 2
    return integer(score, 0, 18)
end

local function milestonePoints(candidate, state, stats, won)
    local earned = 0
    local cumulative = type(candidate.stats) == "table" and candidate.stats or {}
    for _, milestone in ipairs(milestones) do
        local key = milestone.key
        local total, new
        if key == "games" then
            total, new = count(candidate.games), 1
        elseif key == "wins" then
            total, new = count(candidate.wins), won and 1 or 0
        else
            total, new = count(cumulative[key]), count(stats[key])
        end
        if not state.milestones[milestone.id] and total >= milestone.target and total - new < milestone.target then
            state.milestones[milestone.id] = true
            earned = earned + milestone.points
        end
    end
    return earned
end

-- Career.record owns the match transaction. This only updates its candidate.
function Development.onMatch(candidate, fixture, actualStats, match)
    if not fixture or type(fixture.id) ~= "string" or fixture.id == ""
        or not match or match.phase ~= "FINAL" then return false end
    local key = "match:" .. fixture.id
    if Development.claimed(candidate, key) then return false end
    actualStats = type(actualStats) == "table" and actualStats or {}
    local state = snapshot(candidate)
    local previous = savedState(candidate)
    local matchXP = previous and math.max(0, state.accountedXP - count(previous.accountedXP)) or nil
    local performance = performancePoints(actualStats)
    local coach = integer(count(actualStats.screenCoachPoints) * .5, 0, 8)
    local won = count(match.homeScore) > count(match.awayScore)
    local milestone = milestonePoints(candidate, state, actualStats, won)
    local bonus = performance + coach + milestone
    state.points = count(state.points + bonus)
    state.lastReward = {kind="match", xp=matchXP, performance=performance, coach=coach,
        milestone=milestone, bonus=bonus}
    state.claims[key] = true
    candidate.development = state
    return true, state.lastReward
end

function Development.reward(career, key, xp, bonus)
    if type(key) ~= "string" or key == "" or #key > 160 or key:find("^match:") then
        return false, "Invalid drill reward"
    end
    if Development.claimed(career, key) then return false, "Reward already earned" end
    xp, bonus = integer(xp, 0, 250), integer(bonus, 0, 250)
    if xp + bonus <= 0 then return false, "No reward earned" end
    local candidate = copy(career)
    local state = snapshot(career)
    candidate.xp = count(candidate.xp + xp)
    local gainedXP = candidate.xp - state.accountedXP
    state.accountedXP = candidate.xp
    state.claims[key] = true
    state.points = count(state.points + gainedXP + bonus)
    state.lastReward = {kind="drill", xp=gainedXP, bonus=bonus}
    candidate.development = state
    local ok, message = commit(career, candidate)
    if not ok then return false, message end
    return true, string.format("+%d XP  ·  +%d skill points", gainedXP, gainedXP + bonus)
end

function Development.upgrade(career, key, save)
    local attributes = P.Attributes
    local nextValue, cost = attributes.advance(career.attributes, key, career.position)
    if not nextValue then return false, "Skill is capped or unavailable" end
    local state = snapshot(career)
    if state.points < cost then return false, string.format("Need %d skill points", cost) end
    local candidate = copy(career)
    candidate.attributes = attributes.restore(career.attributes, career.position)
    candidate.attributes[key] = nextValue
    state.points, state.spent = state.points - cost, count(state.spent + cost)
    candidate.development = state
    local ok, message = commit(career, candidate, save)
    if not ok then return false, message end
    for _, descriptor in ipairs(attributes.descriptors) do
        if descriptor.key == key then
            return true, string.format("%s increased to %d", descriptor.label, nextValue)
        end
    end
    return true
end

local function box(id, x, y, width, height, label, enabled)
    return {id=id,x=x,y=y,w=width,h=height,label=label,enabled=enabled ~= false}
end

function Development.layout(career, page)
    local area = P.UI.safeArea()
    local top, bottom = HEIGHT - area.top - 12, area.bottom + 10
    local width = math.min(494, WIDTH - area.left - area.right - 28)
    local center = (WIDTH + area.left - area.right) * .5
    local left, right = center - width * .5, center + width * .5
    local gap = 7
    local topRow, bottomRow = top - 114, bottom + 89
    local available = topRow - bottomRow
    local perPage = available < 245 and 4 or 5
    local descriptors = P.Attributes.descriptors
    local pages = math.max(1, math.ceil(#descriptors / perPage))
    local index = integer(page, 1, pages)
    local first = (index - 1) * perPage + 1
    local rowHeight = math.max(26, math.min(65, (available - gap * (perPage - 1)) / perPage))
    local points = Development.points(career)
    local layout = {
        x=center, w=width, top=top, bottom=bottom, left=left, right=right,
        rows={}, points=points, overall=P.Attributes.overall(career.attributes, career.position),
        page=index, pages=pages, headerY=top-17, walletY=top-63, messageY=top-102,
        back=box("back", left+32, top-17, 64, 34, "Back"),
        previous=box("previous", left+27, bottom+62, 54, 34, "‹", index>1),
        next=box("next", right-27, bottom+62, 54, 34, "›", index<pages),
        drill=box("drill", center, bottom+19, width, 38, "Play Training Drill")
    }
    local current = P.Attributes.restore(career.attributes, career.position)
    for n = 0, perPage - 1 do
        local descriptor = descriptors[first+n]
        if not descriptor then break end
        local y = topRow - rowHeight * .5 - n * (rowHeight + gap)
        local rating = current[descriptor.key]
        local cost = P.Attributes.cost(current, descriptor.key, career.position)
        local upgradeWidth = math.min(75, width * .245)
        local upgrade = box(descriptor.key,right-upgradeWidth*.5-8,y,upgradeWidth,math.min(38,rowHeight-9),
            cost and ("+1  ·  " .. cost) or "MAX", cost and points >= cost or false)
        layout.rows[#layout.rows+1] = {
            x=center,y=y,w=width,h=rowHeight,key=descriptor.key,rating=rating,
            label=descriptor.label,detail=descriptor.description,upgrade=upgrade
        }
    end
    return layout
end

local function label(value, x, y, size, tint, corner, limit)
    if not value then return end
    fontSize(size)
    if limit and textSize then
        local measured = textSize(value)
        if measured > limit then fontSize(math.max(8, size * limit / measured)) end
    end
    fill(tint)
    if corner then textMode(CORNER) end
    text(value, x, corner and y - size*.53 or y)
    if corner then textMode(CENTER) end
end

local function button(style, item, active)
    style.panel(item.x, item.y, item.w, item.h, item.enabled and active, 9)
    local isPager = item.id == "previous" or item.id == "next"
    label(item.label, item.x, item.y, isPager and 17 or 12,
        item.enabled and style.palette.white or style.palette.muted)
end

local function detailLines(value, allowed)
    if not textSize or textSize(value) <= allowed then return value end
    local first, rest
    for offset in value:gmatch("() ") do
        if textSize(value:sub(1,offset-1)) > allowed then break end
        first, rest = value:sub(1,offset-1), value:sub(offset+1)
    end
    return first or value, rest
end

function Development.draw(career, hud, message)
    local style = P.Style
    local palette = style.palette
    background(palette.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    noStroke()
    font("AvenirNext-DemiBold")

    button(style, hud.back, false)
    label("Development", hud.x, hud.headerY, 22, palette.white)
    style.panel(hud.x,hud.walletY,hud.w,48,false,13)
    local walletX = hud.left + hud.w*.21
    local ratingX = hud.right - hud.w*.21
    label(tostring(hud.points),walletX,hud.walletY+7,22,palette.glow)
    label("SKILL POINTS",walletX,hud.walletY-13,9,palette.muted)
    label(tostring(count(career.xp)),hud.x,hud.walletY+5,17,palette.white)
    label("CAREER XP",hud.x,hud.walletY-13,9,palette.muted)
    label(tostring(hud.overall),ratingX,hud.walletY+7,22,palette.amber)
    label("OVERALL",ratingX,hud.walletY-13,9,palette.muted)
    label(message,hud.x,hud.messageY,11,palette.amber,false,hud.w)

    for _, row in ipairs(hud.rows) do
        style.panel(row.x,row.y,row.w,row.h,false,11)
        local plotX = hud.left+11
        local ratingX = row.upgrade.x-row.upgrade.w*.5-23
        local descriptionWidth = math.max(58,ratingX-plotX-22)
        local detailSize = row.h < 43 and 9 or 10
        label(row.label,plotX,row.y+row.h*.20,13,palette.white,true,descriptionWidth)
        fontSize(detailSize)
        local first, second = detailLines(row.detail,descriptionWidth)
        local y = row.y-row.h*.24
        label(first,plotX,y+(second and 4.5 or 0),detailSize,palette.muted,true,descriptionWidth)
        if second then label(second,plotX,y-4.5,detailSize,palette.muted,true,descriptionWidth) end
        label(tostring(row.rating),ratingX,row.y,19,palette.glow)
        button(style,row.upgrade,true)
    end
    button(style,hud.previous,false)
    button(style,hud.next,false)
    label(string.format("%d / %d",hud.page,hud.pages),hud.x,hud.previous.y,12,palette.muted)
    if hud.drill then button(style,hud.drill,true) end
    popMatrix()
    popStyle()
end
