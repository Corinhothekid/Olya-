-- PolyLax 2.0 | Career awards panel
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.AwardUI = UI

local headings = {watchlist="Watchlist",midseason="Midseason rankings",finalists="Finalists",
    complete="Season results"}

local function box(id,x,y,w,h,label,selected)
    return {id=id,x=x,y=y,w=w,h=h,label=label,selected=selected}
end

local function add(panel,id,x,y,w,h,label,selected)
    local item = box(id,x,y,w,h,label,selected)
    panel.buttons[#panel.buttons+1] = item
    return item
end

function UI.layout(career,area,state)
    state = state or {}
    local awards = P.Awards.preview(career)
    local mode = state.mode == "trophies" and "trophies" or "race"
    local left,right,top,bottom = area.left,area.right,area.top,area.bottom
    local w,x = right-left,(right+left)*.5
    local panel = {left=left,right=right,x=x,w=w,bottom=bottom,top=top,mode=mode,
        buttons={},rows={},award=awards}
    add(panel,"race",left+w*.25-1.5,top-15,w*.5-3,30,"Season awards",mode=="race")
    add(panel,"trophies",right-w*.25+1.5,top-15,w*.5-3,30,"Trophy case",mode=="trophies")

    local available,firstTop
    if mode=="trophies" then
        local shelf = P.Awards.trophies(career)
        available = {}
        for i=#shelf,1,-1 do available[#available+1] = shelf[i] end
        firstTop = top-37
        if #available==0 then panel.notice = "Earn season honors to fill your trophy case" end
    elseif not awards.eligible then
        panel.notice = awards.reason
    else
        local boards = awards.boards
        local index = math.min(math.max(1,state.board or 1),math.max(1,#boards))
        local active = boards[index]
        panel.boardIndex,panel.boardCount,panel.active = index,#boards,active
        if active then
            if #boards>1 then
                add(panel,"previousBoard",left+16,top-51,32,30,"‹")
                add(panel,"nextBoard",right-16,top-51,32,30,"›")
            end
            panel.heading = headings[awards.phase]
            panel.headingY,panel.subheadY = top-48,top-70
            firstTop = top-85
            if active.winner and awards.phase=="complete" then
                panel.winner = box("winner",x,firstTop-19,w,38)
                firstTop = firstTop-45
            end
            available = awards.phase == "finalists" and active.finalists or active.rows
        end
        if not available or #available==0 then
            panel.notice = active and active.id == "championship-mvp" and "Available after the championship"
                or "Rankings begin when season results are recorded"
        end
    end
    if not available or #available==0 then return panel end
    local rowHeight = mode=="trophies" and 40 or 35
    local capacity = math.max(1,math.floor((firstTop-bottom-34)/rowHeight))
    local pages = math.ceil(#available/capacity)
    local page = math.min(math.max(1,state.page or 1),pages)
    panel.page,panel.pages = page,pages
    if page>1 then add(panel,"previousPage",left+42,bottom+15,84,29,"Previous") end
    if page<pages then add(panel,"nextPage",right-42,bottom+15,84,29,"Next") end
    local first = (page-1)*capacity+1
    for i=first,math.min(#available,first+capacity-1) do
        panel.rows[#panel.rows+1] = {item=box(nil,x,firstTop-(i-first+.5)*rowHeight,
            w,rowHeight-4),value=available[i]}
    end
    return panel
end

local function label(textValue,x,y,size,tint,maxWidth,leading)
    if not textValue or textValue=="" then return end
    fontSize(size)
    if maxWidth and textSize then
        local width=textSize(textValue)
        if width>maxWidth then fontSize(math.max(9,size*maxWidth/width)) end
    end
    fill(tint)
    if leading then textMode(CORNER) else textMode(CENTER) end
    text(textValue,x,leading and y-size*.5 or y)
    textMode(CENTER)
end

local function teamLabel(id)
    local team = P.TeamUniform and P.TeamUniform.get(id)
    return team and (team.short or team.name) or tostring(id)
end

function UI.draw(panel)
    local style,col = P.Style,P.Style.palette
    pushStyle()
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    for _,item in ipairs(panel.buttons) do
        style.panel(item.x,item.y,item.w,item.h,item.selected,9)
        label(item.label,item.x,item.y,12,item.selected and col.white or col.muted,item.w-9)
    end
    if panel.active then
        local buttonSpace = panel.boardCount>1 and 72 or 12
        label(panel.active.title,panel.x,panel.headingY,17,col.white,panel.w-buttonSpace)
        label(panel.heading,panel.x,panel.subheadY,11,col.glow,panel.w-12)
    end
    local winner = panel.active and panel.active.winner
    local banner = panel.winner
    if winner and banner then
        style.panel(banner.x,banner.y,banner.w,banner.h,true,10)
        label("Winner",panel.left+10,banner.y+8,10,col.amber,55,true)
        label(winner.name.."   "..teamLabel(winner.teamId),panel.left+10,banner.y-8,
            13,col.white,panel.w-24,true)
    end
    if panel.notice then
        label(panel.notice,panel.x,(panel.top+panel.bottom)*.5,13,col.muted,panel.w-12)
    end
    for _,row in ipairs(panel.rows) do
        local item,value = row.item,row.value
        style.panel(item.x,item.y,item.w,item.h,value.career,8)
        if panel.mode=="trophies" then
            label(value.title,panel.left+9,item.y+7,13,col.white,item.w-18,true)
            label("Season "..value.season.."  ·  "..teamLabel(value.teamId),panel.left+9,item.y-9,
                10,col.muted,item.w-18,true)
        else
            label(tostring(value.rank),panel.left+15,item.y,13,col.amber)
            label(value.name,panel.left+32,item.y+6,12,col.white,item.w-93,true)
            local detail = teamLabel(value.teamId).."  ·  "..value.roleLabel
            if value.simulated>0 then detail = detail.."  ·  Sim "..value.simulated.."/"..value.games end
            label(detail,panel.left+32,item.y-8,9,col.muted,item.w-89,true)
            label(string.format("%.1f",value.score),panel.right-26,item.y,13,col.glow,43)
        end
    end
    if panel.pages and panel.pages>1 then
        label(string.format("%d / %d",panel.page,panel.pages),panel.x,panel.bottom+15,11,col.muted)
    end
    popStyle()
end

function UI.touch(panel,state,touch)
    if touch.state~=BEGAN then return false end
    for _,item in ipairs(panel.buttons) do
        if P.UI.hit(item,touch.x,touch.y) then
            local id = item.id
            if id=="race" or id=="trophies" then
                state.mode,state.page = id,1
            elseif id=="previousBoard" or id=="nextBoard" then
                local change = id=="previousBoard" and -1 or 1
                state.board = (panel.boardIndex+change-1)%panel.boardCount+1
                state.page = 1
            else
                state.page = panel.page+(id=="previousPage" and -1 or 1)
            end
            return true
        end
    end
    return false
end
