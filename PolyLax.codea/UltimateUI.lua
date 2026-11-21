-- Portrait Ultimate Team hub and collection management.
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.UltimateUI = UI

local ink = {
    deep=color(10,16,18), shadow=color(7,12,14), panel=color(21,29,31),
    elevated=color(27,38,39), muted=color(168,190,180), white=color(246,247,238),
    edge=color(51,71,63), dim=color(101,124,113), gold=color(244,207,124),
    goldDark=color(101,80,47), goldFill=color(48,40,26), green=color(110,225,173),
    greenFill=color(17,52,41), turf=color(14,44,35), stripe=color(17,53,42),
    fieldLine=color(93,141,115), rust=color(213,157,110), blue=color(137,202,225)
}

local sections = {
    {"SQUAD","My Squad","Set your starting ten","squad"},
    {"PACKS","Player Packs","Five players per pack","packs"},
    {"WHEEL","Gold Wheel","Spin for one player","wheel"},
    {"SBC","Squad Building","Challenges · SBC","sbc"},
    {"COLLECTION","My Collection","Browse owned cards","collection"},
    {"VAULT","Jersey Vault","Choose an original kit","jersey"},
    {"RECORD","Club Record","Results and box scores","record"}
}
local titles = {
    DASHBOARD="Ultimate Team", SQUAD="My Squad", PICK="Select Player",
    PACKS="Player Packs", WHEEL="Gold Wheel", COLLECTION="My Collection",
    VAULT="Jersey Vault", RECORD="Club Record", DEV="Developer Testing",
    DEV_CONFIRM="Reset Test Progress"
}
local roleNames = {A="Attack",M="Midfield",D="Defense",G="Goalie"}
local colors = {
    elite={border=ink.gold,base=ink.goldFill,label="Elite"},
    high={border=ink.blue,base=color(22,43,54),label="High"},
    core={border=ink.rust,base=color(47,35,30),label="Core"}
}

local function round(x,y,w,h,r,tint,press)
    P.Style.rounded(x,y,w,h,r,tint,press)
end

local function number(value)
    local raw=tostring(math.max(0,math.floor(tonumber(value) or 0)))
    local reversed=raw:reverse():gsub("(%d%d%d)","%1,")
    return (reversed:reverse():gsub("^,",""))
end

local function label(value,x,y,size,tint,maxWidth,left)
    if not value then return end
    fontSize(size)
    if maxWidth and textSize then
        local width=textSize(value)
        if width and width>maxWidth then
            size=math.max(8,size*maxWidth/width)
            fontSize(size)
        end
    end
    fill(tint)
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.55 or y)
    if left then textMode(CENTER) end
end

local function panel(x,y,w,h,theme,press,rad)
    rad=rad or 12
    round(x,y-2,w,h,rad,ink.shadow,press)
    round(x,y,w,h,rad,theme and theme.border or ink.edge,press)
    round(x,y,w-2,h-2,rad-1,theme and theme.base or ink.panel,press)
end

local function icon(kind,x,y,s,tint)
    fill(tint)
    if kind=="squad" then
        for n=-1,1 do
            ellipse(x+n*s*.3,y+s*.19,s*.18)
            round(x+n*s*.3,y-s*.07,s*.23,s*.2,s*.06,tint)
        end
    elseif kind=="packs" or kind=="collection" then
        round(x+s*.15,y+s*.08,s*.53,s*.69,s*.075,tint)
        local front=kind=="packs" and ink.greenFill or ink.panel
        round(x+s*.03,y+s*.02,s*.51,s*.65,s*.08,front)
        round(x-s*.1,y-s*.045,s*.51,s*.65,s*.08,tint)
        round(x-s*.1,y-s*.045,s*.35,s*.34,s*.05,front)
    elseif kind=="wheel" or kind=="gold" then
        ellipse(x,y,s*.68)
        fill(ink.goldFill)
        ellipse(x,y,s*.51)
        fill(tint)
        ellipse(x,y,s*.16)
        if kind=="wheel" then
            for n=1,6 do
                local a=n*math.pi/3
                ellipse(x+math.cos(a)*s*.26,y+math.sin(a)*s*.26,s*.07)
            end
        end
    elseif kind=="sbc" then
        for row=-1,1,2 do
            for col=-1,1,2 do
                round(x+col*s*.22,y+row*s*.16,s*.34,s*.24,s*.04,tint)
            end
        end
    elseif kind=="jersey" then
        round(x,y,s*.49,s*.61,s*.075,tint)
        round(x-s*.26,y+s*.13,s*.23,s*.29,s*.05,tint)
        round(x+s*.26,y+s*.13,s*.23,s*.29,s*.05,tint)
        fill(ink.panel)
        ellipse(x,y+s*.29,s*.21,s*.125)
    elseif kind=="play" then
        stroke(tint)
        strokeWidth(2)
        line(x-s*.2,y-s*.23,x+s*.27,y)
        line(x+s*.27,y,x-s*.2,y+s*.23)
        line(x-s*.2,y+s*.23,x-s*.2,y-s*.23)
        noStroke()
    elseif kind=="record" or kind=="dev" then
        for n=0,2 do
            local h=s*(.24+n*.15)
            round(x+(n-1)*s*.19,y-s*.29+h*.5,s*.105,h,2,tint)
        end
    elseif kind=="stick" then
        stroke(tint)
        strokeWidth(1.5)
        noFill()
        ellipse(x+s*.13,y+s*.18,s*.43,s*.38)
        line(x+s*.01,y+s*.03,x-s*.26,y-s*.31)
        line(x+s*.11,y+s*.32,x+s*.24,y+s*.09)
        noStroke()
    end
end

local function item(layout,id,labelText,x,y,w,h,options)
    local box=options or {}
    box.id,box.label,box.x,box.y,box.w,box.h=id,labelText,x,y,w,h
    layout.items[#layout.items+1]=box
    layout.byId[id]=box
    return box
end

local function gotoPage(ui,page)
    ui.page=page
    ui.messageText=nil
    ui.messageTime=0
    ui.listPage=1
    ui.press=nil
    ui.reveal=nil
end

function UI.new(profile)
    return {profile=profile,page="DASHBOARD",listPage=1,time=0,messageTime=0}
end

function UI.reset(ui)
    gotoPage(ui,"DASHBOARD")
    ui.sbc=nil
    ui.slot=nil
    if ui.profile.loadError then UI.message(ui,ui.profile.loadError) end
end

function UI.message(ui,message)
    ui.messageText=message and tostring(message)
    ui.messageTime=message and 3.5 or 0
end

local function getFrame()
    local safe=P.UI.safeArea()
    local w=math.min(450,WIDTH-safe.left-safe.right-28)
    local top,bottom=HEIGHT-safe.top-12,safe.bottom+12
    local x=(WIDTH+safe.left-safe.right)*.5
    return {x=x,w=w,top=top,bottom=bottom,body=top-105,floor=bottom+34,items={},byId={}}
end

local function dashboard(ui,l)
    local room=l.body-l.floor
    local hero=math.min(104,room*.26)
    local profile=ui.profile
    local title=ui.pendingResult and "Retry Result" or (ui.activeMatch and "Resume Match" or "Play Match")
    local record=string.format("10v10 vs CPU   ·   %dW  %dD  %dL",profile.wins,profile.draws,profile.losses)
    local detail=ui.pendingResult and "Save your completed result and reward" or record
    local history=profile.matchHistory
    local last=history[#history]
    local latest
    if last and not ui.pendingResult then
        local score=last.ownScore and last.opponentScore and string.format("  %d–%d",last.ownScore,last.opponentScore) or ""
        latest=string.format("Last %s%s  ·  +%s gold",last.result:upper(),score,number(last.payout))
    end
    item(l,"PLAY",title,l.x,l.body-hero*.5,l.w,hero,
        {kind="hero",icon="play",detail=detail,latest=latest})
    local col=(l.w-8)*.5
    local rows=math.ceil(#sections/2)
    local row=math.min(78,(room-hero-12-(rows-1)*8)/rows)
    local function dashboardItem(index,menu)
        local x=l.x+(index%2==1 and -1 or 1)*(col+8)*.5
        local y=l.body-hero-12-row*.5-(math.ceil(index/2)-1)*(row+8)
        item(l,menu[1],menu[2],x,y,col,row,{kind="menu",detail=menu[3],icon=menu[4]})
    end
    for index,menu in ipairs(sections) do dashboardItem(index,menu) end
    if P.Ultimate.isDeveloperBuild() then
        dashboardItem(#sections+1,{"DEV","Developer Testing","Private save","dev"})
    end
end

local function cardTier(rating)
    return rating>=90 and "elite" or rating>=85 and "high" or "core"
end

local function cardData(PU,player)
    local rating=PU.Economy.rating(player)
    return {name=PU.displayName(player),rating=rating,role=player.position or PU.role(player),
        league=player.league,season=player.season,tier=cardTier(rating)}
end

local function formation(ui,l)
    local U=P.Ultimate
    local top=l.body-21
    local fieldH=math.min(420,top-l.floor)
    l.field={x=l.x,y=top-fieldH*.5,w=l.w,h=fieldH}
    l.caption="Tap a position to assign a card"
    local cardW=math.min(103,(l.w-42)/3)
    local cardH=math.min(77,fieldH*.20)
    for slot,role in ipairs(U.slotRoles) do
        local row=math.floor((slot-1)/3)
        local col=(slot-1)%3
        local x=slot==10 and l.x or l.x + (col-1)*(cardW+6)
        local y=top-fieldH*.145-row*fieldH*.23
        local player=U.resolveCard(ui.profile,ui.profile.squad[slot])
        item(l,"SLOT:"..slot,slot==4 and "Faceoff" or roleNames[role],x,y,cardW,cardH,{
            kind="formation",card=player and cardData(U,player),slot=slot,role=slot==4 and "FO" or role
        })
    end
end

local function pageControls(ui,l,total)
    local y=l.floor+18
    item(l,"PREV","‹",l.x-l.w*.35,y,48,36,{enabled=ui.listPage>1})
    item(l,"NEXT","›",l.x+l.w*.35,y,48,36,{enabled=ui.listPage<total})
    l.pageLabel=string.format("%d / %d",ui.listPage,total)
    l.pageY=y
end

local function ownedCards(ui,U)
    if ui.ownedSource~=ui.profile.cards then
        local cards=U.ownedCards(ui.profile)
        table.sort(cards,function(a,b)
            local first,second=U.Economy.rating(a.player),U.Economy.rating(b.player)
            if first~=second then return first>second end
            if a.id~=b.id then return a.id<b.id end
            return a.uid<b.uid
        end)
        ui.ownedSource,ui.owned=ui.profile.cards,cards
    end
    return ui.owned
end

local function listCards(ui,l)
    local U=P.Ultimate
    local picked=ui.page=="PICK"
    local rows={}
    local wanted=picked and U.slotRoles[ui.slot]
    local assigned,assignedPlayers={},{}
    for slot,uid in pairs(ui.profile.squad) do
        assigned[uid]=slot
        local player=U.resolveCard(ui.profile,uid)
        if player then assignedPlayers[U.identity(player)]=slot end
    end
    for _,owned in ipairs(ownedCards(ui,U)) do
        if not wanted or wanted==U.role(owned.player) then
            rows[#rows+1]=owned
        end
    end
    local top=l.body
    if picked then
        l.caption=ui.slot==4 and "Faceoff · Midfield cards" or roleNames[wanted].." · Position "..ui.slot
        top=top-26
        if ui.profile.squad[ui.slot] then
            item(l,"REMOVE","Clear position",l.x,top-19,l.w,38)
            top=top-47
        end
    end
    if #rows==0 then
        l.empty=picked and "Open a pack or spin for this position." or "Open your starter pack to collect players."
        if not picked then
            item(l,"PACKS","Go to Player Packs",l.x,top-58,l.w,43,{primary=true})
        end
        return
    end
    local columns=2
    local rowH=math.min(109,math.max(65,math.floor((top-l.floor)/3)))
    local pageSize=columns*math.max(1,math.floor((top-l.floor-44)/(rowH+8)))
    local pages=math.max(1,math.ceil(#rows/pageSize))
    ui.listPage=math.min(ui.listPage,pages)
    if pages>1 then pageControls(ui,l,pages) end
    local w=(l.w-8)*.5
    for index=1,pageSize do
        local owned=rows[(ui.listPage-1)*pageSize+index]
        if not owned then break end
        local x=l.x+(index%2==1 and -1 or 1)*(w+8)*.5
        local y=top-rowH*.5-math.floor((index-1)/2)*(rowH+8)
        local inSlot=picked and assignedPlayers[U.identity(owned.player)] or assigned[owned.uid]
        local used=inSlot and (picked and inSlot~=ui.slot and "In slot "..inSlot or "Starting ten") or nil
        local data=cardData(U,owned.player)
        item(l,"CARD:"..owned.uid,data.name,x,y,w,rowH,{
            kind="player",uid=owned.uid,card=data,status=used,
            enabled=picked and (not inSlot or inSlot==ui.slot),interactive=picked
        })
    end
end

local function getOdds(e)
    local odds={}
    for _,rarity in ipairs(e.rates) do
        local entry=colors[rarity.tier]
        if entry then
            local range=rarity.tier=="elite" and "90+" or string.format("%d–%d",rarity.minimum,rarity.maximum)
            odds[#odds+1]={tier=rarity.tier,range=range,value=rarity.weight,palette=entry}
        end
    end
    return odds
end

local function packs(ui,l)
    local c,E=ui.profile,P.Ultimate.Economy
    if ui.reveal then
        l.caption="Saved to My Collection"
        local finished=ui.time-ui.reveal.start>=1.7
        item(l,"DONE",finished and "Done" or "Skip Animation",l.x,l.floor+20,l.w,40,{primary=finished})
        return
    end
    local top=l.body-108
    l.caption=number(c.unopenedPacks).." unopened · 5 players in every pack"
    l.odds={rows=getOdds(E),y=l.body-74,title="STANDARD ODDS PER CARD"}
    local rows={}
    if not c.starterGranted then
        rows[#rows+1]={id="STARTER",title="Open Starter Pack",primary=true,detail="Free · One card guaranteed 85+"}
    end
    local hasPacks=(c.unopenedPacks or 0)>0
    rows[#rows+1]={id="OPEN_PACK",title="Open Pack",primary=hasPacks,enabled=hasPacks,
        detail=number(c.unopenedPacks).." available"}
    rows[#rows+1]={id="BUY_PACK",title="Buy Standard Pack",enabled=(c.coins or 0)>=E.packCost,
        detail=number(E.packCost).." gold"}
    local row=math.min(48,(top-l.floor-7*(#rows-1))/#rows)
    for index,data in ipairs(rows) do
        item(l,data.id,data.title,l.x,top-row*.5-(index-1)*(row+7),l.w,row,data)
    end
end

local function wheel(ui,l)
    local E=P.Ultimate.Economy
    l.caption="One player per spin"
    l.wheelRadius=math.max(16,math.min(l.w*.36,(l.body-l.floor-151)*.5,138))
    l.wheelY=l.body-32-l.wheelRadius
    l.odds={rows=getOdds(E),y=l.wheelY-l.wheelRadius-35}
    local spin=ui.reveal
    if spin and ui.time-spin.start>=3 then
        l.winY=l.odds.y
        l.odds=nil
    end
    if spin then
        local finished=ui.time-spin.start>=3
        item(l,"WHEEL_DONE",finished and "Done" or "Skip Animation",l.x,l.floor+20,l.w,40,{primary=finished})
    else
        item(l,"SPIN","Spin for "..number(E.wheelCost).." Gold",l.x,l.floor+20,l.w,40,
            {enabled=(ui.profile.coins or 0)>=E.wheelCost,primary=true})
    end
end

local function vault(ui,l)
    l.caption="Original home and away uniforms"
    local kits=P.Ultimate.kits
    local row=math.min(123,(l.body-20-l.floor-14)/math.ceil(#kits/2))
    local col=(l.w-8)*.5
    for index,k in ipairs(kits) do
        local x=l.x+(index%2==1 and -1 or 1)*(col+8)*.5
        local y=l.body-24-row*.5-math.floor((index-1)/2)*(row+6)
        item(l,"KIT:"..k.id,k.name,x,y,col,row,
            {kind="kit",kit=k,selected=ui.profile.equippedKit==k.id})
    end
end

local function record(ui,l)
    local profile=ui.profile
    l.caption=string.format("%d played  ·  %d wins  ·  %d draws  ·  %d losses",
        profile.matches,profile.wins,profile.draws,profile.losses)
    local history=profile.matchHistory
    if #history==0 then l.empty="Complete a match to see your results here." return end
    local row=52
    local size=math.max(1,math.floor((l.body-24-l.floor-38)/row))
    local pages=math.ceil(#history/size)
    ui.listPage=math.min(pages,ui.listPage)
    if pages>1 then pageControls(ui,l,pages) end
    for i=1,size do
        local entry=history[#history-(ui.listPage-1)*size-i+1]
        if not entry then break end
        local score=entry.ownScore and entry.opponentScore
            and string.format("  %d–%d",entry.ownScore,entry.opponentScore) or ""
        item(l,"RESULT:"..entry.id,entry.result:upper()..score,l.x,l.body-43-(i-1)*row,l.w,row-5,{
            detail="+"..number(entry.payout).." gold  ·  "..(entry.box and "View box score" or "Earlier result"),
            boxScore=entry.box,interactive=entry.box~=nil
        })
    end
end

local function dev(ui,l)
    local E=P.Ultimate.Economy
    l.caption="Private Ultimate Team save"
    item(l,"TEST_GOLD","Grant 1,000,000 Gold",l.x,l.body-54,l.w,54,
        {enabled=E.canGrantTestGold(ui.profile),detail=ui.profile.testGoldGranted and "Already claimed" or "One-time grant"})
    item(l,"DEV_RESET","Reset Test Progress",l.x,l.body-119,l.w,54,
        {enabled=not ui.activeMatch and not ui.pendingResult,detail="One-time grant status is retained"})
end

local function devConfirm(_,l)
    l.caption="Clear this private collection, gold, and records?"
    l.empty="Your one-time gold claim stays recorded."
    item(l,"DEV_CONFIRM","Reset Private Save",l.x,l.body-77,l.w,49)
end

local layouts={
    DASHBOARD=dashboard,SQUAD=formation,PACKS=packs,WHEEL=wheel,
    PICK=listCards,COLLECTION=listCards,VAULT=vault,RECORD=record,DEV=dev,DEV_CONFIRM=devConfirm
}

function UI.layout(ui)
    if ui.page=="SBC" then return end
    local l=getFrame()
    local onDashboard=ui.page=="DASHBOARD"
    item(l,"BACK",onDashboard and "‹ Home" or "‹ Back",l.x-l.w*.5+38,l.top-16,76,32)
    l.gold={x=l.x+l.w*.5-64,y=l.top-16,w=128,h=32}
    l.title=titles[ui.page]
    layouts[ui.page](ui,l)
    return l
end

local borderGreen={border=ink.green,base=ink.greenFill}
local borderGold={border=ink.goldDark,base=ink.goldFill}

local function drawCard(box,selected,progress)
    local x,y,w,h=box.x,box.y,box.w,box.h
    local card=box.card
    local theme=card and colors[card.tier]
    local press=progress or (selected and .965 or 1)
    if card then
        panel(x,y,w,h,theme,press,box.kind=="formation" and 8 or 12)
        if progress and progress<.72 then return end
        local tiny=box.kind=="formation"
        local ratingSize=tiny and 19 or 28
        local top=y+h*.24
        label(tostring(card.rating),x-w*.23,top,ratingSize,theme.border)
        local role = box.slot==4 and "FO" or card.position or card.role
        label(role or "",x+w*.24,top,tiny and 11 or 13,theme.border,w*.40)
        if not tiny and h>=96 then icon("stick",x,y+h*.08,h*.28,theme.border) end
        label(card.name,x,y-h*.09,tiny and 10 or 13,ink.white,w-10)
        local footer=box.status
        if not tiny then
            local edition=card.league or ""
            if card.season then edition=edition.." "..tostring(card.season) end
            local description=edition~="" and edition.." · "..theme.label or theme.label
            label(description,x,y-h*.32,9,theme.border,w-10)
            label(footer,x,y-h*.45,8,ink.muted,w-10)
        end
    else
        panel(x,y,w,h,{border=ink.fieldLine,base=ink.turf},press,8)
        label("+",x,y+h*.13,19,ink.green)
        label((box.role or "").." · AI",x,y-h*.20,9,ink.muted,w-10)
    end
end

local function pitch(area)
    panel(area.x,area.y,area.w,area.h,{border=ink.fieldLine,base=ink.turf},nil,12)
    local x,y,w,h=area.x,area.y,area.w,area.h
    for i=-3,3,2 do
        round(x,y+i*h*.063,w-19,h*.103,3,ink.stripe)
    end
    local left,right=x-w*.46,x+w*.46
    local lower,upper=y-h*.47,y+h*.47
    stroke(ink.fieldLine)
    strokeWidth(1)
    line(left,lower,right,lower)
    line(left,upper,right,upper)
    line(left,lower,left,upper)
    line(right,lower,right,upper)
    line(left,y,right,y)
    noFill()
    ellipse(x,y,math.min(56,w*.24))
    ellipse(x,lower+h*.12,42)
    ellipse(x,upper-h*.12,42)
    noStroke()
end

local function kitColor(rgb) return color(rgb[1],rgb[2],rgb[3]) end

local function garment(x,y,size,base,accent)
    round(x-size*.30,y+size*.12,size*.30,size*.31,size*.045,base)
    round(x+size*.30,y+size*.12,size*.30,size*.31,size*.045,base)
    round(x,y,size*.58,size*.66,size*.065,base)
    round(x,y-size*.10,size*.56,size*.068,1,accent)
    fill(ink.panel)
    ellipse(x,y+size*.31,size*.22,size*.13)
end

local function drawBox(ui,box)
    local selected=ui.press and ui.press.box.id==box.id
    if box.kind=="player" or box.kind=="formation" then
        drawCard(box,selected)
        return
    end
    local x,y,w,h=box.x,box.y,box.w,box.h
    local pressed=selected and .967 or 1
    if box.kind=="kit" then
        panel(x,y,w,h,box.selected and borderGreen,pressed)
        local size=math.min(53,h*.53,w*.33)
        garment(x-w*.22,y+h*.11,size,kitColor(box.kit.home),kitColor(box.kit.accent))
        garment(x+w*.22,y+h*.11,size,kitColor(box.kit.away),kitColor(box.kit.accent))
        label(box.label,x,y-h*.24,12,ink.white,w-10)
        if box.selected then label("Equipped",x,y-h*.40,9,ink.green,w-10) end
    elseif box.kind=="hero" then
        panel(x,y,w,h,borderGreen,pressed,14)
        local glimmer=math.floor(70+32*(1+math.sin(ui.time*2)))
        round(x-w*.5+14,y,3,h*.60,1.5,color(113,241,187,glimmer))
        icon("play",x+w*.5-32,y,33,ink.green)
        local left,width=x-w*.5+26,w-85
        label(box.label,left,y+(box.latest and 18 or 9),21,ink.white,width,true)
        label(box.detail,left,y+(box.latest and -4 or -14),12,ink.green,width,true)
        label(box.latest,left,y-23,10,ink.muted,width,true)
    elseif box.kind=="menu" then
        panel(x,y,w,h,nil,pressed)
        local size=math.min(31,h*.48)
        local ix=x-w*.5+size*.54+9
        round(ix,y,size+4,size+4,9,ink.greenFill)
        icon(box.icon,ix,y,size,ink.gold)
        local left=ix+size*.5+8
        local width=x+w*.5-left-6
        label(box.label,left,y+8,14,ink.white,width,true)
        label(box.detail,left,y-10,10,ink.muted,width,true)
    else
        panel(x,y,w,h,box.primary and box.enabled~=false and borderGreen,pressed)
        local tint=box.enabled==false and ink.dim or ink.white
        label(box.label,x,y+(box.detail and 7 or 0),box.id=="BACK" and 13 or 15,tint,w-10)
        label(box.detail,x,y-11,10,box.enabled==false and ink.dim or ink.muted,w-10)
    end
end

local function oddsStrip(l)
    local o=l.odds
    if not o then return end
    if o.title then label(o.title,l.x,o.y+34,11,ink.gold,l.w) end
    local w=(l.w-12)/3
    for index,entry in ipairs(o.rows) do
        local x=l.x+(index-2)*(w+5)
        panel(x,o.y,w,49,entry.palette,nil,8)
        label(tostring(entry.value).."%",x,o.y+7,16,entry.palette.border,w-6)
        label(entry.palette.label.." "..entry.range,x,o.y-10,9,ink.white,w-6)
    end
end

local function revealPack(ui,l)
    local list=ui.reveal.cards
    local available=l.body-l.floor-79
    local w=math.min(111,(l.w-12)/3)
    local h=math.min(143,available*.47)
    for index,card in ipairs(list) do
        local current=math.max(0,math.min(1,(ui.time-ui.reveal.start-(index-1)*.34)/.27))
        local row=index<=3 and 1 or 2
        local column=index<=3 and index-2 or index-4.5
        local x=l.x+column*(w+5)
        local y=l.body-34-h*.5-(row-1)*(h+10)
        if current>0 then
            drawCard({x=x,y=y,w=w,h=h,card=card},false,1-(1-current)^3*.90)
        else
            panel(x,y,w,h,borderGold,nil,12)
            icon("packs",x,y,46,ink.gold)
        end
    end
end

local wheelShapes = {}

local function wheelSector(entry,elapsed,x,y,r,spin)
    if mesh and rotate and scale then
        local shape=wheelShapes[entry.tier]
        if not shape then
            local vertices={}
            local triangles=math.ceil(entry.value*.44)
            local low,high=elapsed+.42,elapsed+entry.value-.42
            for i=0,triangles-1 do
                local a=(low+(high-low)*i/triangles)*2*math.pi/100
                local b=(low+(high-low)*(i+1)/triangles)*2*math.pi/100
                local n=#vertices
                vertices[n+1],vertices[n+2],vertices[n+3]=vec3(),vec3(math.cos(a),math.sin(a)),vec3(math.cos(b),math.sin(b))
            end
            shape=mesh()
            shape.vertices=vertices
            shape:setColors(entry.palette.base)
            wheelShapes[entry.tier]=shape
        end
        pushMatrix()
        translate(x,y)
        rotate(math.deg(spin))
        scale(r-5)
        shape:draw()
        popMatrix()
        return
    end
    for stripe=elapsed+.45,elapsed+entry.value-.25,.90 do
        local angle=(stripe/100*2*math.pi)+spin
        stroke(entry.palette.base)
        strokeWidth(4)
        line(x+math.cos(angle)*r*.21,y+math.sin(angle)*r*.21,
             x+math.cos(angle)*(r-5),y+math.sin(angle)*(r-5))
    end
end

local function wheelGraphic(ui,l)
    local x,y,r=l.x,l.wheelY,l.wheelRadius
    local foundation=ui.reveal and math.min(1,(ui.time-ui.reveal.start)/3) or 0
    local spin=ui.reveal and ui.reveal.angle*(1-(1-foundation)^3) or 0
    fill(ink.gold)
    ellipse(x,y,r*2)
    fill(ink.shadow)
    ellipse(x,y,r*2-4)
    local elapsed=0
    for _,entry in ipairs(getOdds(P.Ultimate.Economy)) do
        local center=elapsed+entry.value*.5
        wheelSector(entry,elapsed,x,y,r,spin)
        local angle=(center/100*2*math.pi)+spin
        noStroke()
        label(entry.palette.label,x+math.cos(angle)*r*.72,y+math.sin(angle)*r*.72,10,entry.palette.border,50)
        elapsed=elapsed+entry.value
    end
    icon("gold",x,y,r*.76,ink.gold)
    stroke(ink.gold)
    strokeWidth(2)
    line(x-7,y+r+6,x,y+r-5)
    line(x+7,y+r+6,x,y+r-5)
    noStroke()
    if l.winY and ui.reveal then
        drawCard({x=x,y=l.winY,w=math.min(l.w-16,164),h=66,card=ui.reveal.cards[1]},false)
    end
end

function UI.draw(ui,dt)
    ui.time=ui.time+math.max(0,dt or 0)
    ui.messageTime=math.max(0,ui.messageTime-(dt or 0))
    if ui.page=="SBC" then
        P.Ultimate.SBCUI.draw(ui.sbc,dt)
        return
    end
    local l=UI.layout(ui)
    background(ink.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CENTER)
    ellipseMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    round(l.x,l.top-72,l.w,56,11,ink.elevated)
    label(l.title,l.x,l.top-68,ui.page=="DASHBOARD" and 25 or 23,ink.white,l.w-12)
    round(l.x,l.top-91,math.min(l.w*.45,148),2,1,ink.goldDark)
    local coin=l.gold
    panel(coin.x,coin.y,coin.w,coin.h,borderGold,nil,10)
    icon("gold",coin.x-46,coin.y,22,ink.gold)
    label(number(ui.profile.coins).." gold",coin.x+10,coin.y,13,ink.gold,coin.w-35)
    if l.field then pitch(l.field) end
    label(l.caption,l.x,l.body-8,11,ink.muted,l.w)
    label(l.empty,l.x,l.body-34,12,ink.muted,l.w)
    label(l.pageLabel,l.x,l.pageY,11,ink.muted,l.w*.35)
    if ui.page=="PACKS" and ui.reveal then revealPack(ui,l) end
    if ui.page=="WHEEL" then wheelGraphic(ui,l) end
    oddsStrip(l)
    for _,box in ipairs(l.items) do drawBox(ui,box) end
    if ui.page=="PACKS" or ui.page=="WHEEL" or ui.page=="COLLECTION" or ui.page=="PICK" then
        label("Fictional PolyLax ratings",l.x,l.bottom+11,10,ink.muted,l.w)
    end
    if ui.messageTime>0 and ui.messageText then
        panel(l.x,l.bottom+12,l.w,28,borderGold,nil,8)
        label(ui.messageText,l.x,l.bottom+12,11,ink.gold,l.w-11)
    end
    popMatrix()
    popStyle()
end

local function openReveal(ui,data)
    ui.reveal={cards=data,start=ui.time}
end

local function buy(ui)
    local ok,result=P.Ultimate.Economy.buyPack(ui.profile)
    if ok then UI.message(ui,"Pack added. Tap Open Pack to reveal it.")
    else UI.message(ui,result) end
end

local function getPack(ui,operation)
    local ok,result=operation(ui.profile)
    if ok then openReveal(ui,result)
    else UI.message(ui,result) end
end

local function spinWheel(ui)
    local E=P.Ultimate.Economy
    local ok,result=E.spin(ui.profile)
    if not ok then UI.message(ui,result) return end
    openReveal(ui,{result})
    local offset=0
    for _,rarity in ipairs(E.rates) do
        if rarity.tier==result.tier then
            offset=offset+rarity.weight*.5
            break
        end
        offset=offset+rarity.weight
    end
    ui.reveal.angle=math.pi*8+((math.pi/2-offset/100*2*math.pi)%(math.pi*2))
end

local function back(ui)
    if ui.page=="DASHBOARD" then return "HOME" end
    if ui.page=="PICK" then gotoPage(ui,"SQUAD")
    elseif ui.page=="DEV_CONFIRM" then gotoPage(ui,"DEV")
    else gotoPage(ui,"DASHBOARD") end
end

local actions={
    BACK=back,
    PLAY=function() return "PLAY" end,
    PREV=function(ui) ui.listPage=ui.listPage-1 end,
    NEXT=function(ui) ui.listPage=ui.listPage+1 end,
    REMOVE=function(ui)
        local ok,reason=P.Ultimate.unequip(ui.profile,ui.slot)
        if ok then gotoPage(ui,"SQUAD") else UI.message(ui,reason) end
    end,
    STARTER=function(ui) getPack(ui,P.Ultimate.Economy.grantStarter) end,
    OPEN_PACK=function(ui) getPack(ui,P.Ultimate.Economy.openPack) end,
    BUY_PACK=buy,
    SPIN=spinWheel,
    DONE=function(ui)
        if ui.time-ui.reveal.start<1.7 then ui.reveal.start=ui.time-2 else ui.reveal=nil end
    end,
    WHEEL_DONE=function(ui)
        if ui.time-ui.reveal.start<3 then ui.reveal.start=ui.time-3 else ui.reveal=nil end
    end,
    TEST_GOLD=function(ui)
        local ok,reason=P.Ultimate.Economy.grantTestGold(ui.profile)
        UI.message(ui,ok and "Developer gold granted." or reason)
    end,
    DEV_RESET=function(ui) gotoPage(ui,"DEV_CONFIRM") end,
    DEV_CONFIRM=function(ui)
        local ok,reason=P.Ultimate.Economy.resetTestProgress(ui.profile)
        if ok then gotoPage(ui,"DEV") end
        UI.message(ui,ok and "Private progress reset." or reason)
    end,
    SBC=function(ui)
        gotoPage(ui,"SBC")
        ui.sbc=P.Ultimate.SBCUI.new(ui.profile)
    end
}

local function select(ui,box)
    local id=box.id
    if actions[id] then return actions[id](ui) end
    local U=P.Ultimate
    if box.boxScore then
        return "BOX_SCORE",box.boxScore
    elseif box.slot then
        ui.slot=box.slot
        gotoPage(ui,"PICK")
    elseif box.uid then
        local ok,reason=U.equip(ui.profile,ui.slot,box.uid)
        if ok then gotoPage(ui,"SQUAD") else UI.message(ui,reason) end
    elseif box.kit then
        local ok,reason=U.equipKit(ui.profile,box.kit.id)
        UI.message(ui,ok and "Uniform equipped for your next match." or reason)
    elseif layouts[id] then
        gotoPage(ui,id)
    end
end

function UI.touch(ui,t)
    if ui.page=="SBC" then
        local result=P.Ultimate.SBCUI.touch(ui.sbc,t)
        if result=="back" or result=="BACK" then gotoPage(ui,"DASHBOARD") end
        return
    end
    if t.state==BEGAN then
        if ui.press then return end
        for _,box in ipairs(UI.layout(ui).items) do
            if box.enabled~=false and box.interactive~=false and P.UI.hit(box,t.x,t.y) then
                ui.press={id=t.id,box=box}
                return
            end
        end
        return
    end
    local press=ui.press
    if not press or press.id~=t.id then return end
    if t.state==CANCELLED or t.state==MOVING and not P.UI.hit(press.box,t.x,t.y) then
        ui.press=nil
    elseif t.state==ENDED then
        ui.press=nil
        if P.UI.hit(press.box,t.x,t.y) then return select(ui,press.box) end
    end
end

