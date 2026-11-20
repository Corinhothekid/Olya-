-- Club and connection screens. Gameplay HUD and single-player career have their own layouts.
PolyLax = PolyLax or {}
local P = PolyLax
local ClubsUI = {}
P.ClubsUI = ClubsUI

local heading = {
    CLUBS="PolyLax Clubs", CREATE="Create Club", JOIN="Join Club",
    ROSTER="Club Roster", SCHEDULE="Schedule", LOBBY="Club Lobby", SETTINGS="Settings"
}

local function item(id, title, detail, enabled, primary)
    return {id=id,label=title,detail=detail,enabled=enabled~=false,primary=primary}
end

local function place(layout, box, x, y, width, height)
    box.x,box.y,box.w,box.h=x,y,width,height
    layout.rows[#layout.rows+1]=box
    if box.id then
        layout.buttons[#layout.buttons+1]=box
        layout.byId[box.id]=box
    end
    return box
end

local function stack(layout, rows, ceiling)
    if #rows==0 then return end
    local gap = 7
    local height = math.min(ceiling or 58,(layout.cursor-layout.floor-gap*(#rows-1))/#rows)
    for _, row in ipairs(rows) do
        place(layout,row,layout.x,layout.cursor-height*.5,layout.w,height)
        layout.cursor=layout.cursor-height-gap
    end
end

local function field(options, id, value, placeholder)
    if options.editing==id then
        return (options.draft or "").."▏"
    end
    return (value and value~="" and value) or placeholder
end

local function relayURL(data, options)
    local value=options.relay or data.settings and data.settings.relayURL
    return type(value)=="string" and value~="" and value or nil
end

local function teamName(teamID)
    if teamID==nil then return end
    local team=P.TeamUniform.get(teamID)
    return team and team.name
end

local function clubStamp(layout, title, description, stats)
    local height = stats and 78 or 64
    layout.stamp={title=title,detail=description,stats=stats,
        x=layout.x,y=layout.cursor-height*.5,w=layout.w,h=height}
    layout.cursor=layout.cursor-height-12
end

local function scheduleRow(game)
    local opponent=type(game.opponent)=="table" and game.opponent.name or game.opponent
    local venue=game.home and "Home" or "Away"
    local detail=table.concat({tostring(game.label or "Fixture"),venue,tostring(game.result or game.site or "Scheduled")},"  ·  ")
    return item(nil,tostring(opponent or "Opponent"),detail,nil,game.current==true)
end

local function rosterRow(member)
    local pos=member.position or member.role
    if type(pos)=="number" then
        local definition=P.Career.positions[pos]
        pos=definition and definition.label
    end
    local number=member.number or member.jerseyNumber
    local suffix=number and ("  ·  #"..tostring(number)) or ""
    local owner=member.host and "  ·  HOST" or ""
    local name=tostring(member.name or "Player")..(member.kind=="local" and member.online and " (You)" or "")
    local row=item(nil,name,tostring(pos or "Unassigned")..suffix..owner)
    local source=member.kind
    row.badge=(member.ai or source=="ai") and "AI" or source=="local" and not member.online and "YOU"
        or member.connected==false and "OFFLINE" or member.ready and "READY" or "NOT READY"
    row.badgeActive=member.ready==true
    return row
end

local function pageList(layout, items, convert, fallback, options)
    if #items==0 then
        stack(layout,{item(nil,fallback)},52)
        return
    end
    local count = math.min(10,math.max(1,math.floor((layout.cursor-layout.floor-48)/54)))
    local pages = math.ceil(#items/count)
    local current = math.max(1,math.min(pages,math.floor(tonumber(options.page) or 1)))
    if pages>1 then
        layout.pages,layout.page=pages,current
        local y = layout.floor+19
        place(layout,item("PREV_PAGE","Previous",nil,current>1),layout.x-layout.w*.34,y,layout.w*.31,38)
        place(layout,item("NEXT_PAGE","Next",nil,current<pages),layout.x+layout.w*.34,y,layout.w*.31,38)
        layout.pager={x=layout.x,y=y,label=string.format("%d / %d",current,pages)}
        layout.floor=layout.floor+46
    end
    local rows={}
    for i=(current-1)*count+1,math.min(#items,current*count) do
        rows[#rows+1]=convert(items[i])
    end
    stack(layout,rows,49)
end

local screens = {}

function screens.CLUBS(layout, data, options)
    local club, player = options.lobby or data.club, data.player or {}
    local title = club and club.name or "Your club"
    local identity = P.Athlete.name(player)
    local description = club and (teamName(club.team) or "Local club").."  ·  "..identity
        or identity
    local jersey = P.Athlete.profile(player).NUMBER-1
    local stats = string.format("#%d   ·   %d OVR   ·   %d skill points",jersey,
        P.Attributes.overall(player.attributes,player.position),P.Development.points(player))
    clubStamp(layout,title,description,stats)
    local rows = {
        item("CREATE","Create Club",nil,true,true),
        item("JOIN","Join Club"), item("MY_PLAYER","My Player"),
        item("ROSTER","Club Roster"), item("SCHEDULE","Schedule"),
        item("DEVELOPMENT","Player Development")
    }
    if club or options.lobby then rows[#rows+1]=item("LOBBY","Club Lobby") end
    stack(layout,rows,57)
end

function screens.CREATE(layout, data, options)
    local club = data.club or {}
    local team = options.teamName or teamName(club.team) or "Choose a team"
    local stage = options.stageName or P.Career.stages[club.stage or "highSchool"]
    stack(layout,{
        item("EDIT_NAME","Club name",field(options,"EDIT_NAME",options.name or club.name,"Enter a club name")),
        item("NEXT_STAGE","Competition",stage),
        item("NEXT_TEAM","Team",team),
        item("SAVE_CLUB","Save Club",nil,options.canCreate~=false,true)
    },68)
end

function screens.JOIN(layout, data, options)
    local relay=relayURL(data,options)
    stack(layout,{
        item("EDIT_CODE","Invitation code",field(options,"EDIT_CODE",options.code,"Enter the host's code")),
        item("EDIT_RELAY","Relay server",field(options,"EDIT_RELAY",relay,"Enter the online server address")),
        item("CONNECT","Join Club",nil,options.canConnect==true,true)
    },68)
    if not relay and not options.message then
        layout.message="Set the relay server address to join a room."
    end
end

function screens.SETTINGS(layout, data, options)
    local relay=relayURL(data,options)
    stack(layout,{
        item("CREATOR","Player Creator","Customize the Quick Play athlete"),
        item("EDIT_RELAY","Clubs relay server",field(options,"EDIT_RELAY",relay,"Set the online server address")),
        item("MENU_MUSIC",options.menuMuted and "Menu Music Off" or "Menu Music On",
            options.hasMenuTheme and "Tap to change" or "Optional PolyLaxTheme asset")
    },68)
end

function screens.ROSTER(layout, data, options)
    local roster=options.roster or P.Clubs.roster(data) or {}
    pageList(layout,roster,rosterRow,"Create or join a club to view its roster.",options)
end

function screens.SCHEDULE(layout, data, options)
    local schedule=options.schedule or P.Clubs.schedule(data) or {}
    pageList(layout,schedule,scheduleRow,"Create a club to open a season schedule.",options)
end

function screens.LOBBY(layout, data, options)
    local lobby=options.lobby
    if not lobby then
        clubStamp(layout,data.club and data.club.name or "Club Lobby","This club is saved on this device")
        stack(layout,{item("HOST_ONLINE","Host Online","Open an invitation room on the relay",
            options.hostEnabled==true,true)},62)
        if not options.message and not relayURL(data,options) then
            layout.message="Set a relay server address in Settings to host online."
        end
        return
    end
    local code = lobby.code
    local description = code and code~="" and ("Invitation code   "..code) or "Connecting to the relay"
    if lobby.phase=="final" and lobby.result then
        description=string.format("Final score   %d–%d",lobby.result.homeScore,lobby.result.awayScore)
    end
    clubStamp(layout,lobby.name or data.club and data.club.name or "Club Lobby",description)
    local y = layout.floor+19
    if lobby.phase=="match" then
        place(layout,item("RESUME_MATCH","Return to Match",nil,options.canResume==true,true),layout.x,y,layout.w,38)
    elseif lobby.phase=="final" then
        place(layout,item("LEAVE","Leave Room"),layout.x,y,layout.w,38)
    else
        local width = (layout.w-12)/3
        place(layout,item("READY",options.ready and "Unready" or "Ready",nil,options.canReady==true),
            layout.x-width-6,y,width,38)
        place(layout,item("START","Start Game",nil,options.canStart==true,true),layout.x,y,width,38)
        place(layout,item("LEAVE","Leave"),layout.x+width+6,y,width,38)
    end
    layout.floor=layout.floor+45
    pageList(layout,options.roster or lobby.members or {},rosterRow,"Waiting for players",options)
end

function ClubsUI.layout(view, data, options)
    view=heading[view] and view or "CLUBS"
    options,data=options or {},data or {}
    local safe=P.UI.safeArea()
    local width=math.min(452,WIDTH-safe.left-safe.right-30)
    local x=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-12,safe.bottom+12
    local layout={view=view,title=heading[view],top=top,bottom=bottom,x=x,w=width,
        cursor=top-58,floor=bottom+26,rows={},buttons={},byId={},message=options.message}
    local back=place(layout,item("BACK","Back"),x-width*.5+30,top-21,60,36)
    back.compact=true
    screens[view](layout,data,options)
    return layout
end

local function textAt(value, x, y, size, colorValue, limit, left)
    if not value then return end
    fontSize(size)
    if textSize and limit and limit>0 then
        local width=textSize(value)
        if width>limit then fontSize(math.max(9,size*limit/width)) end
    end
    fill(colorValue)
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.51 or y)
    if left then textMode(CENTER) end
end

local function drawRow(style, row)
    local p = style.palette
    style.panel(row.x,row.y,row.w,row.h,row.primary and row.enabled,11)
    local ink = row.enabled and p.white or p.muted
    if row.compact or row.id=="PREV_PAGE" or row.id=="NEXT_PAGE"
        or row.id=="READY" or row.id=="START" or row.id=="LEAVE" then
        textAt(row.label,row.x,row.y,13,ink,row.w-10)
        return
    end
    local left = row.x-row.w*.5+14
    local hasArrow = row.id and row.enabled
    local room = row.w-29-(row.badge and 76 or hasArrow and 20 or 0)
    textAt(row.label,left,row.y+(row.detail and 9 or 0),row.primary and 18 or 16,ink,room,true)
    textAt(row.detail,left,row.y-11,11,row.enabled and p.muted or p.rim,room,true)
    if row.badge then
        local x=row.x+row.w*.5-43
        style.rounded(x,row.y,64,22,8,p.inset)
        textAt(row.badge,x,row.y,10,row.badgeActive and p.glow or p.muted,59)
    elseif hasArrow then
        local x=row.x+row.w*.5-17
        stroke(p.glow)
        strokeWidth(2)
        line(x-4,row.y+4,x,row.y)
        line(x,row.y,x-4,row.y-4)
        noStroke()
    end
end

function ClubsUI.draw(layout)
    local style=P.Style
    local p=style.palette
    background(p.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CENTER)
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    textAt(layout.title,layout.x-layout.w*.5+76,layout.top-21,23,p.white,layout.w-76,true)
    if layout.stamp then
        local stamp=layout.stamp
        style.panel(stamp.x,stamp.y,stamp.w,stamp.h,false,13)
        local x=stamp.x-stamp.w*.5+29
        style.rounded(x,stamp.y,37,37,10,p.inset)
        style.clubsIcon(x,stamp.y,37,p.glow)
        textAt(stamp.title,x+29,stamp.y+(stamp.stats and 20 or 9),19,p.white,stamp.w-75,true)
        textAt(stamp.detail,x+29,stamp.y+(stamp.stats and 0 or -12),11,p.muted,stamp.w-75,true)
        textAt(stamp.stats,x+29,stamp.y-19,11,p.glow,stamp.w-75,true)
    end
    for _, row in ipairs(layout.rows) do drawRow(style,row) end
    if layout.pager then
        textAt(layout.pager.label,layout.pager.x,layout.pager.y,12,p.muted)
    end
    textAt(layout.message,layout.x,layout.bottom+9,11,p.amber,layout.w)
    popMatrix()
    popStyle()
end

function ClubsUI.touch(layout, touch)
    if touch.state~=BEGAN then return end
    for _, box in ipairs(layout.buttons) do
        if box.enabled and P.UI.hit(box,touch.x,touch.y) then return box.id end
    end
end
