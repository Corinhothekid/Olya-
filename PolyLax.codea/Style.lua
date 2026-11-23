-- PolyLax | Shared menu treatments and pause overlays
PolyLax = PolyLax or {}
local Style = {}
PolyLax.Style = Style

local palette = {
    deep=color(9,13,19), graphite=color(21,28,38), body=color(26,34,46),
    inset=color(15,21,29), steel=color(57,73,91), rim=color(80,98,117),
    muted=color(164,180,197), white=color(245,249,254), blue=color(38,137,75),
    glow=color(118,228,153), red=color(235,73,93), amber=color(253,206,100)
}
Style.palette = palette

local meshes = {}

function Style.rounded(x, y, w, h, radius, tint, press)
    if w <= 0 or h <= 0 then return end
    radius = math.min(radius,w*.5,h*.5)
    if not mesh then
        rectMode(CENTER)
        fill(tint)
        rect(x,y,w*(press or 1),h*(press or 1))
        return
    end
    local key = string.format("%.2f,%.2f,%.2f",w,h,radius)
    local shape = meshes[key]
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
            local start = #vertices+1
            vertices[start],vertices[start+1],vertices[start+2] = center,point,perimeter[index % #perimeter+1]
        end
        shape = mesh()
        shape.vertices = vertices
        if (meshes.count or 0) >= 160 then meshes = {} end
        meshes[key],meshes.count = shape,(meshes.count or 0)+1
    end
    shape:setColors(tint)
    pushMatrix()
    translate(x,y)
    if press then scale(press) end
    shape:draw()
    popMatrix()
end

local panelShadow = color(5,9,14,173)
local panelActive = color(21,92,52)
function Style.panel(x, y, w, h, active, radius)
    radius = radius or 12
    Style.rounded(x,y-2,w,h,radius,panelShadow)
    Style.rounded(x,y,w,h,radius,active and palette.blue or palette.steel)
    Style.rounded(x,y,w-2,h-2,math.max(0,radius-1),active and panelActive or palette.body)
end

local choices = {
    FRONT = {
        {id="ROAD", title="Road to Glory", detail="Explore campus and play Brothers in Arms", prominent=true},
        {id="MODES", title="Quick Play", detail="Practice or play a full match", prominent=true},
        {id="CAREER", title="Be a Pro", detail="Develop your single-player career"},
        {id="ULTIMATE", title="Ultimate Team", detail="Build a squad and compete", icon="ultimate"},
        {id="CLUBS", title="PolyLax Clubs", detail="Manage your club and athlete", icon="clubs"},
        {id="SETTINGS", title="Settings", detail="Player Creator and online connection"}
    },
    MODES = {
        {id="PRACTICE", title="Practice", detail="Six-player offense and shooting", prominent=true},
        {id="MATCH", title="Full Match", detail="Twenty-player field lacrosse"},
        {id="CAREER", title="Be a Pro", detail="Continue your career"},
        {id="HOME", title="Home"}
    },
    PAUSE = {
        {id="RESUME", title="Resume", prominent=true},
        {id="RESET", title="Restart"},
        {id="STATS", title="Stats"},
        {id="CREATOR", title="Player Creator"},
        {id="HOME", title="Home"}
    }
}

local function hitbox(id, x, y, w, h, choice, enabled)
    return {id=id,x=x,y=y,w=w,h=h,label=choice.title,detail=choice.detail,
        prominent=choice.prominent,icon=choice.icon,enabled=enabled}
end

function Style.screenLayout(page, options)
    page = tostring(page or "FRONT"):upper()
    if not choices[page] then page = "FRONT" end
    local safe = PolyLax.UI.safeArea()
    local w = math.min(452,WIDTH-safe.left-safe.right-36)
    local x = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-12,safe.bottom+12
    local room = top-bottom
    local list = choices[page]
    local pause = page == "PAUSE"
    local dashboard = {
        page=page,x=x,w=w,top=top,bottom=bottom,buttons={},byId={},
        touches={},motion={}
    }
    local front = page == "FRONT"
    local row = pause and math.min(53,room*.115) or front and math.min(66,room*.102)
        or math.min(76,room*.142)
    local gap = pause and 9 or front and math.min(9,room*.016) or 12
    local stack = #list*row + (#list-1)*gap
    local firstTop
    if pause then
        local paneHeight = stack+87
        dashboard.overlay = {x=x,y=(top+bottom)*.5,w=w+16,h=paneHeight}
        dashboard.titleY = dashboard.overlay.y+paneHeight*.5-34
        firstTop = dashboard.titleY-31
    elseif page == "FRONT" then
        firstTop = bottom+stack+16
        dashboard.titleY = (top+firstTop)*.5
        dashboard.logoHeight = math.min(120,(top-firstTop)*.84)
    else
        local reserve = math.min(147,room*.30)
        firstTop = math.max(bottom+stack+20,top-reserve)
        dashboard.titleY = (top+firstTop)*.5
    end
    for index, choice in ipairs(list) do
        local enabled = choice.id ~= "STATS" or options and options.statsEnabled == true
        if choice.id == "RESET" and options and options.resetEnabled == false then enabled=false end
        if choice.id == "CREATOR" and options and options.roadPause then enabled=false end
        local y = firstTop-row*.5-(index-1)*(row+gap)
        local item = hitbox(choice.id,x,y,w,row,choice,enabled == true)
        if choice.id == "HOME" and options and options.ultimatePause then item.label="Ultimate Team" end
        if choice.id == "HOME" and options and options.roadPause then item.label="Return to Campus" end
        dashboard.buttons[index],dashboard.byId[item.id] = item,item
    end
    return dashboard
end

local function label(value, x, y, size, tint, corner, maxWidth)
    if not value then return end
    fontSize(size)
    if textSize and maxWidth then
        local used = textSize(value)
        if used > maxWidth then fontSize(math.max(9,size*maxWidth/used)) end
    end
    fill(tint)
    if corner then textMode(CORNER) end
    text(value,x,corner and y-size*.53 or y)
    if corner then textMode(CENTER) end
end

local lineInk = color(72,108,143,83)
local banner = color(22,32,46,239)
local overlayInk = color(6,10,16,191)
local cardShadow = color(7,10,15,221)
local blueTop = color(24,110,62)
local disabled = color(122,136,152)
local disabledCard = color(21,28,38,228)

local function fieldMarks(l)
    local cx, cy = l.x,l.titleY
    local extent = l.w*.49
    stroke(lineInk)
    strokeWidth(1)
    line(cx-extent,cy-63,cx-extent*.75,cy+67)
    line(cx+extent,cy-63,cx+extent*.75,cy+67)
    line(cx-extent*.92,cy-25,cx+extent*.92,cy-25)
    line(cx-extent*.81,cy+27,cx+extent*.81,cy+27)
    noFill()
    ellipseMode(CENTER)
    ellipse(cx,cy-25,87,29)
    ellipse(cx,cy+27,51,21)
    noStroke()
end

function Style.clubsIcon(x, y, size, tint)
    local radius = size * .095
    ellipseMode(CENTER)
    fill(tint)
    noStroke()
    ellipse(x, y+size*.16, radius*2.2)
    ellipse(x-size*.21, y+size*.08, radius*2)
    ellipse(x+size*.21, y+size*.08, radius*2)
    Style.rounded(x, y-size*.12, size*.27, size*.22, size*.065, tint)
    Style.rounded(x-size*.22, y-size*.17, size*.14, size*.16, size*.046, tint)
    Style.rounded(x+size*.22, y-size*.17, size*.14, size*.16, size*.046, tint)
end

local function drawButton(l, item)
    local motion = l.motion[item]
    local s = 1-.035*(motion and motion.amount or 0)
    local colorTop = item.prominent and blueTop or item.enabled and palette.body or disabledCard
    local colorRim = item.prominent and palette.glow or item.icon=="ultimate" and palette.amber
        or item.icon and palette.rim
        or item.enabled and palette.steel or palette.inset
    local x,y,w,h = item.x,item.y,item.w,item.h
    Style.rounded(x,y-3,w,h,13,cardShadow,s)
    Style.rounded(x,y,w,h,13,colorRim,s)
    Style.rounded(x,y,w-2,h-2,12,colorTop,s)
    if item.prominent then Style.rounded(x-w*.5+12,y,3,h*.54,1.5,palette.glow) end
    local left = x-w*.5+27
    local maxLabelWidth = w-75
    if item.icon == "clubs" then
        Style.rounded(left+6,y,37,37,10,palette.inset)
        Style.clubsIcon(left+6,y,36,palette.glow)
        left,maxLabelWidth = left+33,maxLabelWidth-33
    elseif item.icon == "ultimate" then
        Style.rounded(left+6,y,37,37,10,palette.inset)
        Style.rounded(left+6,y-1,17,23,4,palette.amber)
        Style.rounded(left+6,y+1,13,18,3,palette.inset)
        Style.rounded(left+6,y+3,8,2,1,palette.amber)
        Style.rounded(left+6,y-2,6,2,1,palette.amber)
        left,maxLabelWidth = left+33,maxLabelWidth-33
    end
    local fg = item.enabled and palette.white or disabled
    label(item.label,left,y+(item.detail and 9 or 0),item.prominent and 19 or 16,fg,true,maxLabelWidth)
    if item.detail then label(item.detail,left,y-12,11,item.prominent and palette.white or palette.muted,true,maxLabelWidth) end
    if item.enabled then
        local arrowX = x+w*.5-18
        stroke(item.prominent and palette.white or item.icon=="ultimate" and palette.amber or palette.glow)
        strokeWidth(2)
        line(arrowX-4,y+4,arrowX,y)
        line(arrowX,y,arrowX-4,y-4)
        noStroke()
    end
end

function Style.screen(page, l, elapsed, showcase, menuAssets)
    page = l.page or page
    if page ~= "PAUSE" and not showcase then background(palette.deep) end
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    if page == "PAUSE" then
        fill(overlayInk)
        rect(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT)
        local panel = l.overlay
        Style.rounded(panel.x,panel.y,panel.w,panel.h,20,banner)
        label("Paused",l.x,l.titleY,28,palette.white)
    else
        if showcase then
            fill(8,14,26,53)
            rect(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT)
            local panelTop = l.buttons[1].y + l.buttons[1].h*.5 + 19
            fill(8,14,26,96)
            rect(WIDTH*.5,panelTop*.5,WIDTH,panelTop)
        else
            fieldMarks(l)
        end
        local logoHeight = l.logoHeight or math.min(115,(l.top-l.titleY)*1.38)
        local hasLogo = menuAssets and PolyLax.MenuAssets.drawLogo(menuAssets,l.x,l.titleY,l.w*.94,logoHeight)
        local tempo = .5+.5*math.sin((elapsed or 0)*1.6)
        if not hasLogo then
            local title = page == "FRONT" and "POLYLAX 3.4.2" or "Play Modes"
            local size = page == "FRONT" and math.min(48,l.w*.164) or 30
            font("AvenirNext-HeavyItalic")
            if showcase then label(title,l.x+1,l.titleY+7,size,palette.deep,false,l.w) end
            label(title,l.x,l.titleY+9,size,palette.white,false,l.w)
            font("AvenirNext-DemiBold")
            Style.rounded(l.x,l.titleY-25,41+tempo*7,2,1,palette.glow)
        end
    end
    for _,item in ipairs(l.buttons) do drawButton(l,item) end
    popMatrix()
    popStyle()
end


function Style.fade(age)
    local alpha=math.floor(118*math.max(0,1-age/.18))
    if alpha==0 then return end
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CORNER)
    fill(8,15,26,alpha)
    rect(0,0,WIDTH,HEIGHT)
    popMatrix()
    popStyle()
end
