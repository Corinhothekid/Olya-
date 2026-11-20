-- Invoked by clubs_loopback.py; two Clubs sessions and two mocked Craft scenes.
local project = assert(os.getenv("POLYLAX_TEST_PROJECT"))
dofile(assert(os.getenv("POLYLAX_TEST_CHECKS")).."craft_mock.lua")
local plist = assert(io.open(project.."/Info.plist"))
local order = plist:read("*a")
plist:close()
for name in order:gmatch("<string>([%w_]+)</string>") do dofile(project.."/"..name..".lua") end

-- Small encoder for test values. Python decodes the actual relay's JSON and
-- passes a safe Lua literal back through the test bridge.
local function encode(value)
    local kind = type(value)
    if kind=="number" or kind=="boolean" then return tostring(value) end
    if kind=="string" then return string.format("%q",value) end
    assert(kind=="table", "The test transport only encodes JSON values")
    local items = {}
    if #value>0 then
        for _, item in ipairs(value) do items[#items+1]=encode(item) end
        return "["..table.concat(items,",").."]"
    end
    for key, item in pairs(value) do items[#items+1]=encode(key)..":"..encode(item) end
    return "{"..table.concat(items,",").."}"
end

local endpoint = assert(os.getenv("POLYLAX_RELAY_TEST_URL"))
local function request(url, success, _, options)
    assert(options.method=="POST" and options.headers["Content-Type"]=="application/json")
    assert(url:sub(1,#endpoint)==endpoint)
    local status, data = relayTestPost(url:sub(#endpoint+1),options.data,options.headers.Authorization or "")
    success(data,status)
end
local options = {transport=request,allowLoopback=true,
    json={encode=encode,decode=function(raw) return assert(load("return "..raw,nil,"t",{}))() end}}
local P = PolyLax
local C, Net = P.ClubsMatch, P.ClubsNet
local hostNet, guestNet = Net.new(endpoint,options),Net.new(endpoint,options)
assert(Net.create(hostNet,{name="Briarbank Club",stage="highSchool",team="briarbank"},
    {id="host-profile",name="Host Athlete",position=1,number=20}))
assert(hostNet.lobby,hostNet.error or "Club create failed")
assert(Net.join(guestNet,hostNet.lobby.code,
    {id="guest-profile",name="Guest Draw",position=4,number=37}))
assert(guestNet.lobby,guestNet.error or "Club join failed")
local hostId, guestId = hostNet.session.playerId,guestNet.session.playerId
assert(hostId~=guestId and hostNet.session.token~=guestNet.session.token)
assert(Net.ready(hostNet,true) and Net.ready(guestNet,true) and Net.start(hostNet))
assert(hostNet.lobby.phase=="match",hostNet.error or "Host could not start")
Net.tick(guestNet,1)
assert(guestNet.lobby.phase=="match",guestNet.error or "Guest could not start")

local host = assert(C.new(craft.scene(),hostNet.lobby,hostId))
local guest = assert(C.new(craft.scene(),guestNet.lobby,guestId))
assert(host.game.controlled==1 and guest.game.controlled==4 and host.game~=guest.game)
assert(guest.game.squad[4].number==37 and host.game.squad[1].name=="Host Athlete")

local dt = 1/30
local function frame(hostX,guestX)
    if guestX~=nil then
        Net.tick(guestNet,dt,{input={x=guestX,z=0,actions=C.takeActions(guest)}})
        assert(guestNet.status=="connected",guestNet.error or "Guest transport failed")
    end
    C.hostStep(host,dt,{x=hostX or 0,z=0},Net.takeInputs(hostNet))
    Net.tick(hostNet,dt,{snapshot=C.snapshot(host)})
    assert(hostNet.status=="connected",hostNet.error or "Host transport failed")
    C.guestStep(guest,dt,guestNet.snapshot)
end

for _=1,26 do frame(0,0) end
assert(host.game.faceoff.phase=="DRAW" and guest.game.faceoff.userTeam==1)
assert(guest.controller.command(guest.game,"faceoff",0,0))
for _=1,100 do
    frame(0,0)
    if host.game.phase=="LIVE" and guest.game.phase=="LIVE" then break end
end
assert(host.game.phase=="LIVE" and guest.game.phase=="LIVE", "Faceoff did not sync")
assert(host.game.faceoff.home.action=="clamp", "The guest did not take the draw")

local game = host.game
local function place(slot,x,z)
    local p = game.squad[slot]
    p.x,p.z,p.vx,p.vz,p.speed,p.yaw=x,z,0,0,0,0
    p.rig.root.position,p.rig.root.eulerAngles=vec3(x,0,z),vec3()
    P.AnimationController.reset(p.anim)
end
local function giveBall(slot)
    game.flight,game.loose,game.pending,game.carrier=nil,nil,nil,slot
    game.ball.position=game.squad[slot].rig.pocket.worldPosition
    P.MatchRules.possession(game,slot,"restart")
end
place(1,-14,-10)
place(4,-6,-10)
giveBall(4)
for _=1,32 do frame(-1,1) end
assert(game.squad[1].x<-16 and game.squad[4].x>-4,"The players lacked independent controls")
assert(guest.game.squad[1].x<-16 and guest.game.squad[4].x>-4,"Guest did not render both movements")
assert(game.carrier==4 and guest.game.carrier==4,"Ball possession did not sync")

local oldSequence = guestNet.inputSeq
local ticket = guestNet.session
Net.disconnect(guestNet)
for _=1,32 do frame(0,nil) end
assert(game.humans[4].x==0 and game.humans[4].z==0,"Host retained a disconnected player's input")
guestNet=Net.new(endpoint,options)
assert(Net.resume(guestNet,ticket) and guestNet.snapshot,guestNet.error or "Guest could not resume")
guest=assert(C.new(craft.scene(),guestNet.lobby,guestId))
C.guestStep(guest,dt,guestNet.snapshot)
assert(guest.game.controlled==4 and guest.game.carrier==4)
for _=1,9 do frame(0,0) end
assert(guestNet.inputSeq>oldSequence,"Reconnected input sequence did not advance")

place(1,-16,-14)
place(4,-13,-14)
giveBall(4)
assert(guest.controller.command(guest.game,"pass",0,0,{to=1}))
local sawPass = false
for _=1,45 do
    frame(0,0)
    sawPass=sawPass or (guest.game.flight and guest.game.flight.kind=="pass")
end
assert(sawPass and game.squad[4].stats.passes==1,"Pass action or trajectory did not sync")

local normalAI = P.MatchAI.update
P.MatchAI.update=function() return {} end
place(4,0,-13.5)
place(12,0,-15)
giveBall(12)
for _=1,8 do frame(0,0) end
assert(guest.controller.command(guest.game,"poke",0,0))
local sawCheck = false
for _=1,21 do
    frame(0,0)
    sawCheck=sawCheck or guest.game.squad[4].anim.action=="pokeCheck"
end
assert(sawCheck,"Guest check animation did not sync")

place(4,0,-30)
place(20,20,-30)
giveBall(4)
for _=1,8 do frame(0,0) end
assert(guest.controller.command(guest.game,"shoot",0,0,vec3(.23,.83,game.goalsByTeam[1].z)))
local sawShot = false
for _=1,75 do
    frame(0,0)
    sawShot=sawShot or (guest.game.flight and guest.game.flight.kind=="shot")
    if guest.game.homeScore==1 then break end
end
P.MatchAI.update=normalAI
assert(sawShot and game.homeScore==1 and guest.game.homeScore==1,"Shot trajectory or score did not sync")

game.phase,game.clock,game.period="LIVE",.01,2
for _=1,14 do frame(0,0) end
local result = assert(C.result(host))
assert(result.stats[guestId].goals==1 and result.stats[guestId].passes==1 and not C.result(guest))
assert(guest.game.phase=="FINAL","Host final snapshot did not sync")
assert(Net.finish(hostNet,result) and hostNet.lobby.phase=="final",hostNet.error or "Host result rejected")
for _=1,4 do
    Net.tick(guestNet,.3)
    if guestNet.lobby.phase=="final" then break end
end
assert(guestNet.lobby.phase=="final" and guestNet.lobby.result.homeScore==1
    and guestNet.lobby.result.stats[guestId].goals==1,"Guest did not receive the committed result")
print("Two Lua sessions passed lobby, faceoff, separate avatar movement, possession, pass, check, shot, reconnect, and host result.")

-- Drive the app's real host menus and draw loop against the same relay.
for _, name in ipairs({"stroke","strokeWidth","noFill","line","textWrapWidth","showKeyboard","hideKeyboard"}) do
    _G[name]=function() end
end
function background(...)
    assert(select('#',...)<3,"Unexpected Codea draw failure")
end
json=options.json
http={request=function(url,success,fail,params)
    local path=assert(url:match("(/v1/%a+)$"))
    return request(endpoint..path,success,fail,params)
end}
local function upvalue(fn, key)
    local i=1
    while true do
        local name,value=debug.getupvalue(fn,i)
        if name==key then return value end
        if not name then return end
        i=i+1
    end
end
setup(); draw()
local app=assert(upvalue(upvalue(draw,"runFrame"),"state"))
local clubLayout=assert(upvalue(upvalue(upvalue(touched,"runTouch"),"clubsTouch"),"clubLayout"))
local function tap(button)
    assert(button and button.enabled~=false,"Unavailable app action")
    touched({state=BEGAN,id=2,x=button.x,y=button.y}); draw()
end
local function clubTap(id)
    tap(clubLayout().byId[id])
end
tap(P.Style.screenLayout("FRONT").byId.CLUBS)
assert(P.Clubs.setRelay(app.clubs,"https://relay.test"))
assert(P.Clubs.create(app.clubs,"Live Club","highSchool","briarbank"))
clubTap("LOBBY"); clubTap("HOST_ONLINE")
local hostConnection=assert(app.clubsNet)
assert(hostConnection.lobby and hostConnection.session and hostConnection.lobby.code)
local testGuest=Net.new(endpoint,options)
assert(Net.join(testGuest,hostConnection.lobby.code,{id="friend",name="Friend",position=4,number=8}))
assert(Net.ready(testGuest,true))
clubTap("READY")
for _=1,60 do draw() end
clubTap("START")
assert(app.page=="CLUB_MATCH" and app.clubPlay.game.controlled==5)
local currentMatch=app.clubPlay
tap(app.layout.pause)
assert(app.page=="CLUBS" and app.clubView=="LOBBY")
clubTap("RESUME_MATCH")
assert(app.page=="CLUB_MATCH" and app.clubPlay==currentMatch)
currentMatch.game.phase,currentMatch.game.period,currentMatch.game.clock="LIVE",2,.01
for _=1,75 do draw() end
assert(hostConnection.lobby.phase=="final" and app.clubs.player.games==1)
assert(Net.resume(testGuest,testGuest.session) and testGuest.lobby.phase=="final")
assert(testGuest.lobby.result.matchId==currentMatch.matchId)
for _=1,60 do draw() end
assert(app.clubs.player.games==1,"The app awarded the same result twice")
print("Clubs Main passed host controls, joining the match, changing views, publishing the final and saving it once.")
