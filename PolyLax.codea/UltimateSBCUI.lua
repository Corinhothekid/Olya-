-- PolyLax Ultimate | challenge field, collection picker, and exchange review
PolyLax = PolyLax or {}
local P = PolyLax
local U = assert(P.Ultimate, "Ultimate.lua required")
local SBC = assert(U.SBC, "UltimateSBC.lua required")
local UI = {}
U.SBCUI = UI

local ink = color(243,241,229)
local muted = color(165,183,174)
local gold = color(247,209,119)
local green = color(104,210,155)
local red = color(236,150,134)
local backgroundInk = color(11,17,20)
local panelInk = color(24,34,35)
local panelBorder = color(49,67,62)
local goldPanel = color(91,73,32)
local fieldBase = color(19,56,45)
local fieldStripe = color(24,64,48)
local fieldLine = color(113,151,121,155)
local shadow = color(4,10,9,175)
local cardInk = color(13,23,24)
local tierColors = {
    elite=color(239,193,101), high=color(131,193,170), core=color(170,179,165)
}

-- The smallest exchanges use an attacking pattern. Six cards make a 2-3-1.
local formations = {
    [2]={{.30,.60},{.70,.60}},
    [3]={{.25,.56},{.50,.76},{.75,.56}},
    [4]={{.50,.81},{.24,.56},{.76,.56},{.50,.29}},
    [6]={{.33,.79},{.67,.79},{.21,.53},{.50,.53},{.79,.53},{.50,.26}}
}

local function box(x, y, w, h)
    return {x=x,y=y,w=w,h=h}
end

local function surface(b, tint, radius)
    P.Style.rounded(b.x,b.y,b.w,b.h,radius or 10,tint)
end

local function outlined(b, tint, border, radius)
    radius = radius or 10
    surface(b,border,radius)
    surface(box(b.x,b.y,b.w-2,b.h-2),tint,radius-1)
end

local function label(value, x, y, size, tint, width)
    fontSize(size)
    if width and textSize then
        local used = textSize(value)
        if used > width then fontSize(math.max(8,size*width/used)) end
    end
    fill(tint or ink)
    text(value,x,y)
end

local function leftLabel(value, x, y, size, tint, width)
    textMode(CORNER)
    label(value,x,y-size*.56,size,tint,width)
    textMode(CENTER)
end

local function button(b, value, active)
    surface(box(b.x,b.y-2,b.w,b.h),shadow)
    outlined(b,active and goldPanel or panelInk,active and gold or panelBorder)
    label(value,b.x,b.y,12,active and gold or muted,b.w-10)
end

local function hit(b, touch)
    return P.UI.hit(b,touch.x,touch.y)
end

local function challenge(state)
    return SBC.challenges[state.challenge]
end

function UI.new(collection)
    return {collection=collection,challenge=1,entries={},drafts={},selected=1,
        page=1,view="field",time=0}
end

local function refreshChoices(state)
    local used = {}
    for index, uid in pairs(state.entries) do
        if index ~= state.selected then used[uid] = true end
    end
    local list, ch = {}, challenge(state)
    for _, owned in ipairs(U.ownedCards(state.collection)) do
        if not used[owned.uid] and SBC.allows(ch,owned.player) then
            list[#list+1] = owned
        end
    end
    table.sort(list,function(a,b)
        local ra, rb = U.Economy.rating(a.player), U.Economy.rating(b.player)
        if ra ~= rb then return ra > rb end
        local na, nb = U.displayName(a.player), U.displayName(b.player)
        if na ~= nb then return na < nb end
        return a.uid < b.uid
    end)
    state.options = list
end

local function changeChallenge(state, direction)
    state.drafts[challenge(state).id] = state.entries
    state.challenge = (state.challenge-1+direction)%#SBC.challenges+1
    state.entries = state.drafts[challenge(state).id] or {}
    state.selected, state.message = 1, nil
end

function UI.layout(state)
    local safe = P.UI.safeArea()
    local width = math.min(460,WIDTH-safe.left-safe.right-26)
    local cx = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-9, safe.bottom+11
    local left, right = cx-width*.5,cx+width*.5
    local fieldTop, fieldBottom = top-126,bottom+98
    local fieldHeight = fieldTop-fieldBottom
    local f = box(cx,fieldBottom+fieldHeight*.5,width,fieldHeight)
    local slots, ch = {},challenge(state)
    for i, point in ipairs(formations[ch.slots]) do
        slots[i] = box(left+point[1]*width,fieldBottom+point[2]*fieldHeight,
            math.min(77,width*.216),math.min(83,fieldHeight*.235))
    end

    local rowH = math.min(53,math.max(35,(top-bottom-168)/6))
    local count = math.floor((top-bottom-154)/(rowH+5))
    local rows = math.max(1,math.min(8,count))
    local pageItems = {}
    if state.view == "picker" then
        local start = (state.page-1)*rows
        for i=1,rows do
            if state.options[start+i] then
                pageItems[i] = box(cx,top-99-(i-1)*(rowH+5),width,rowH)
            end
        end
    end
    local review = box(cx,bottom+28,math.min(154,width*.5),43)
    local confirmWidth = math.min(100,(width-review.w-14)*.5)
    local confirm = box(right-confirmWidth*.5,bottom+28,confirmWidth,43)
    local cancel = box(left+confirmWidth*.5,bottom+28,confirmWidth,43)
    return {left=left,right=right,width=width,x=cx,top=top,bottom=bottom,field=f,slots=slots,
        back=box(left+32,top-22,64,37),review=review,confirm=confirm,cancel=cancel,
        previous=box(left+19,top-72,38,40),next=box(right-19,top-72,38,40),
        pickerPrev=box(left+22,bottom+24,44,37),pickerNext=box(right-22,bottom+24,44,37),
        remove=box(cx,bottom+25,130,38),rows=rows,pageItems=pageItems,
        exchangeRow=math.min(42,(top-bottom-170)/ch.slots)}
end

local function tierOf(player)
    local rating = U.Economy.rating(player)
    return rating, rating >= 90 and tierColors.elite or rating >= 85 and tierColors.high or tierColors.core
end

local function pitch(l)
    local f = l.field
    surface(f,fieldBase,12)
    rectMode(CENTER)
    for i=1,4 do
        fill(fieldStripe)
        rect(f.x,f.y-f.h*.5+(i*2-.5)*f.h/8,f.w-12,f.h/8-1)
    end
    stroke(fieldLine)
    strokeWidth(1)
    noFill()
    rect(f.x,f.y,f.w-14,f.h-13)
    line(f.x-f.w*.5+7,f.y,f.x+f.w*.5-7,f.y)
    ellipseMode(CENTER)
    ellipse(f.x,f.y,math.min(67,f.h*.27))
    for _, side in ipairs({-1,1}) do
        local goalY = f.y+f.h*.39*side
        line(f.x-f.w*.5+7,f.y+f.h*.263*side,f.x+f.w*.5-7,f.y+f.h*.263*side)
        ellipse(f.x,goalY,math.min(29,f.h*.13))
        rect(f.x,goalY,14,6)
    end
    noStroke()
end

local function drawCard(b, player, current)
    surface(box(b.x,b.y-2,b.w,b.h),shadow,8)
    if not player then
        outlined(b,cardInk,current and gold or panelBorder,8)
        label("+",b.x,b.y+2,23,current and gold or green)
        label("ADD",b.x,b.y-b.h*.3,9,muted)
        return
    end
    local rating, tier = tierOf(player)
    outlined(b,tier,current and gold or cardInk,8)
    local name = U.displayName(player)
    label(tostring(rating),b.x,b.y+b.h*.26,17,cardInk)
    label(name:match("([^ ]+)$") or name,b.x,b.y-1,11,cardInk,b.w-5)
    label(player.league.." · "..U.role(player),b.x,b.y-b.h*.31,9,cardInk,b.w-5)
end

local function drawField(state, l, ch)
    surface(box(l.x,l.top-72,l.width,48),panelInk)
    label(ch.name,l.x,l.top-66,16,gold,l.width-88)
    label(state.challenge.." / "..#SBC.challenges,l.x,l.top-83,10,muted)
    button(l.previous,"‹")
    button(l.next,"›")
    label(SBC.requirements(ch),l.x,l.top-109,13,ink,l.width-10)
    pitch(l)
    for index, slot in ipairs(l.slots) do
        drawCard(slot,U.resolveCard(state.collection,state.entries[index]),index==state.selected)
    end
    label("REWARD   "..ch.reward.coins.." GOLD   +   "..ch.reward.pack..
        (ch.reward.pack==1 and " PACK" or " PACKS"),l.x,l.bottom+82,11,gold,l.width)
    local complete = SBC.isComplete(state.collection,ch)
    local valid, detail = SBC.validate(state.collection,ch.id,state.entries)
    label(state.message or (valid and "Squad ready" or detail),l.x,l.bottom+61,11,
        state.message and (complete and green or red) or muted,l.width)
    if valid then
        local pulse = math.floor(35+30*(1+math.sin(state.time*3)))
        surface(box(l.review.x,l.review.y,l.review.w+5,l.review.h+4),
            color(247,209,119,pulse))
    end
    button(l.review,complete and "Completed" or "Review exchange",valid)
end

local function cardRow(item, player, equipped, selected)
    outlined(item,panelInk,selected and gold or panelBorder,8)
    local rating,tier = tierOf(player)
    local cx = item.x-item.w*.5+24
    surface(box(cx,item.y,31,30),tier,7)
    label(tostring(rating),cx,item.y,12,cardInk)
    leftLabel(U.displayName(player),cx+24,item.y+7,13,ink,item.w-67)
    local info = player.league.." · "..U.role(player)..(equipped and " · In squad" or "")
    leftLabel(info,cx+24,item.y-10,10,equipped and gold or muted,item.w-67)
end

local function drawPicker(state, l)
    label("Slot "..state.selected.." · "..SBC.requirements(challenge(state)),
        l.x,l.top-57,13,muted,l.width)
    if #state.options == 0 then
        label("No eligible cards are available.",l.x,l.field.y,15,muted,l.width)
    end
    local start = (state.page-1)*l.rows
    for index, item in ipairs(l.pageItems) do
        local owned = state.options[start+index]
        cardRow(item,owned.player,SBC.isEquipped(state.collection,owned.uid),
            state.entries[state.selected]==owned.uid)
    end
    local pages = math.max(1,math.ceil(#state.options/l.rows))
    label(state.page.." / "..pages,l.x,l.bottom+58,12,muted)
    button(l.pickerPrev,"‹",state.page>1)
    button(l.pickerNext,"›",state.page<pages)
    button(l.remove,"Remove card",state.entries[state.selected]~=nil)
end

local function drawReview(state, l, ch)
    label(ch.name,l.x,l.top-65,17,gold,l.width)
    label("These cards will leave your collection.",l.x,l.top-89,13,ink,l.width)
    local equipped = false
    for index, uid in ipairs(state.entries) do
        if index > ch.slots then break end
        local player = U.resolveCard(state.collection,uid)
        if player then
            local inSquad = SBC.isEquipped(state.collection,uid)
            equipped = equipped or inSquad
            cardRow(box(l.x,l.top-119-(index-1)*(l.exchangeRow+3),l.width,l.exchangeRow),
                player,inSquad,false)
        end
    end
    if equipped then label("Cards in your active lineup will be unequipped.",l.x,l.bottom+82,11,red,l.width) end
    label("Receive "..ch.reward.coins.." gold and "..ch.reward.pack..
        (ch.reward.pack==1 and " pack" or " packs"),l.x,l.bottom+61,12,gold,l.width)
    button(l.cancel,"Cancel")
    button(l.confirm,"Submit",true)
end

function UI.draw(state, dt)
    state.time = (state.time+math.min(dt or 0,.05))%1000
    local l, ch = UI.layout(state),challenge(state)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    background(backgroundInk)
    noStroke()
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    button(l.back,"‹ Back")
    local title = state.view=="picker" and "Choose a card"
        or state.view=="review" and "Confirm exchange" or "Squad Challenges"
    label(title,l.x+23,l.top-22,19,ink,l.width-110)
    if state.view=="picker" then
        drawPicker(state,l)
    elseif state.view=="review" then
        drawReview(state,l,ch)
    else
        drawField(state,l,ch)
    end
    popMatrix()
    popStyle()
    return l
end

function UI.touch(state, touch)
    if touch.state ~= BEGAN then return nil end
    local l, ch = UI.layout(state),challenge(state)
    if hit(l.back,touch) then
        if state.view=="field" then return "back" end
        state.view = "field"
        return "field"
    end
    if state.view=="picker" then
        local pages = math.max(1,math.ceil(#state.options/l.rows))
        if hit(l.pickerPrev,touch) then state.page=math.max(1,state.page-1);return "page" end
        if hit(l.pickerNext,touch) then state.page=math.min(pages,state.page+1);return "page" end
        if hit(l.remove,touch) then
            state.entries[state.selected],state.view = nil,"field"
            return "removed"
        end
        for index, item in ipairs(l.pageItems) do
            if hit(item,touch) then
                local owned = state.options[(state.page-1)*l.rows+index]
                state.entries[state.selected],state.view = owned.uid,"field"
                return "selected"
            end
        end
        return nil
    end
    if state.view=="review" then
        if hit(l.cancel,touch) then state.view="field";return "field" end
        if hit(l.confirm,touch) then
            local valid, result = SBC.submit(state.collection,ch.id,state.entries)
            state.view = "field"
            if valid then
                state.drafts[ch.id],state.entries,state.selected = nil,{},1
                state.message = "Exchange complete"
                return "completed"
            end
            state.message = result
            return "invalid"
        end
        return nil
    end
    if hit(l.previous,touch) then changeChallenge(state,-1);return "previous" end
    if hit(l.next,touch) then changeChallenge(state,1);return "next" end
    if SBC.isComplete(state.collection,ch) then return nil end
    for index, slot in ipairs(l.slots) do
        if hit(slot,touch) then
            state.selected,state.page,state.view,state.message = index,1,"picker",nil
            refreshChoices(state)
            return "picker"
        end
    end
    if hit(l.review,touch) then
        local valid, reason = SBC.validate(state.collection,ch.id,state.entries)
        if valid then state.view="review";return "review" end
        state.message = reason
        return "invalid"
    end
end

