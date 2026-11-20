-- Two independent Craft scenes exercise the same host/guest payloads as the relay.
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local checks = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(checks.."craft_mock.lua")
local plist = assert(io.open(project.."/Info.plist"))
local order = plist:read("*a")
plist:close()
for name in order:gmatch("<string>([%w_]+)</string>") do dofile(project.."/"..name..".lua") end
if not PolyLax.ClubsMatch then dofile(project.."/ClubsMatch.lua") end

local P = PolyLax
local C = P.ClubsMatch
local function copy(source)
    if type(source)~="table" then return source end
    local result = {}
    for key, value in pairs(source) do result[key]=copy(value) end
    return result
end

local lobby = {matchId="mock-match",hostId="host",team="briarbank",opponent="foxmere",players={
    {id="host",slot=1,profile={name="Host Athlete",position=1,number=20}},
    {id="guest",slot=4,profile={name="Guest Draw",position=4,number=37}}
}}
local host = assert(C.new(craft.scene(),lobby,"host"))
local guest = assert(C.new(craft.scene(),lobby,"guest"))
assert(host.isHost and not guest.isHost and host.game~=guest.game)
assert(host.game.controlled==1 and guest.game.controlled==4)
assert(host.game.squad[1].name=="Host Athlete" and guest.game.squad[4].number==37)

local dt = 1/30
local seq = 0
local function frame(hostX, guestX, queued)
    local events = {}
    if guestX~=nil or queued then
        seq=seq+1
        events[1]={id=seq,playerId="guest",slot=4,input={seq=seq,x=guestX or 0,z=0,
            sprint=false,actions=C.takeActions(guest)}}
    end
    C.hostStep(host,dt,{x=hostX or 0,z=0},events)
    C.guestStep(guest,dt,copy(C.snapshot(host)))
end

assert(not host.controller.command(host.game,"faceoff",0,0))
assert(host.game.faceoff.home.human and host.game.faceoff.home.id==4)
for _=1,25 do frame(0,0) end
assert(host.game.faceoff.phase=="DRAW" and guest.game.faceoff.userTeam==1)
assert(guest.controller.command(guest.game,"faceoff",0,0))
frame(0,0,true)
assert(host.game.faceoff.home.action=="clamp","guest was not allowed to take the faceoff")
for _=1,90 do
    frame(0,0)
    if host.game.phase=="LIVE" then break end
end
assert(host.game.phase=="LIVE" and guest.game.phase=="LIVE")
assert(host.game.controlled==1 and guest.game.controlled==4)

-- Give the two avatars clean lanes to verify their independent controls.
local function place(game, slot, x, z)
    local p=game.squad[slot]
    p.x,p.z,p.yaw,p.vx,p.vz,p.speed=x,z,0,0,0,0
    p.rig.root.position=vec3(x,0,z)
    p.rig.root.eulerAngles=vec3()
    P.AnimationController.reset(p.anim)
end
local game = host.game
game.flight,game.loose,game.pending,game.carrier=nil,nil,nil,4
place(game,1,-14,-10)
place(game,4,-6,-10)
game.ball.position=game.squad[4].rig.pocket.worldPosition
P.MatchRules.possession(game,4,"restart")
for _=1,24 do frame(-1,1) end
assert(game.squad[1].x<-16 and game.squad[4].x>-4,"controls moved the wrong athlete")
assert(guest.game.squad[1].x<-16 and guest.game.squad[4].x>-4,"other handset did not render the movement")
assert(game.carrier==4 and guest.game.carrier==4,"possession did not replicate")
assert(not guest.controller.command(guest.game,"reset",0,0))

for _=1,32 do frame(0,nil) end
assert(game.humans[4].x==0 and game.humans[4].z==0,"disconnected input was not neutralized")
local staleX=game.humans[4].x
C.hostStep(host,dt,{x=0,z=0},{{playerId="guest",slot=4,input={seq=seq,x=1,z=1,sprint=true}}})
C.hostStep(host,dt,{x=0,z=0},{{playerId="guest",slot=1,input={seq=seq+1,x=1,z=1,sprint=true}}})
assert(game.humans[4].x==staleX,"stale or wrong-slot input was replayed")

-- The guest submits a pass and the host advances its animation and ball flight.
place(game,1,-16,-14)
place(game,4,-13,-14)
game.ball.position=game.squad[4].rig.pocket.worldPosition
assert(guest.controller.command(guest.game,"pass",0,0,{to=1}))
local sawPass = false
for _=1,35 do
    frame(0,0,true)
    if guest.game.flight and guest.game.flight.kind=="pass" then sawPass=true end
end
assert(sawPass and game.squad[4].stats.passes==1)

-- A poke and a shot from the guest use the normal host animations and ball physics.
local normalAI = P.MatchAI.update
P.MatchAI.update = function() return {} end
place(game,4,0,-13.5)
place(game,12,0,-15)
game.flight,game.loose,game.pending,game.carrier=nil,nil,nil,12
game.ball.position=game.squad[12].rig.pocket.worldPosition
P.MatchRules.possession(game,12,"restart")
for _=1,4 do frame(0,0) end
assert(guest.controller.command(guest.game,"poke",0,0))
local sawCheck = false
for _=1,15 do
    frame(0,0)
    if guest.game.squad[4].anim.action=="pokeCheck" then sawCheck=true end
end
assert(sawCheck,"guest check pose was not replicated")

place(game,4,0,-30)
place(game,20,20,-30)
game.flight,game.loose,game.pending,game.carrier=nil,nil,nil,4
game.ball.position=game.squad[4].rig.pocket.worldPosition
P.MatchRules.possession(game,4,"restart")
local goal = game.goalsByTeam[1]
for _=1,4 do frame(0,0) end
assert(guest.controller.command(guest.game,"shoot",0,0,vec3(.23,.83,goal.z)))
local sawShot = false
for _=1,55 do
    frame(0,0)
    if guest.game.flight and guest.game.flight.kind=="shot" then sawShot=true end
    if guest.game.phase=="GOAL" then break end
end
P.MatchAI.update = normalAI
assert(sawShot and guest.game.homeScore==1 and game.homeScore==1,
    "shot flight or host goal did not replicate")

-- Rejoining on a new guest scene restores the same slot and latest world.
local resumed = assert(C.new(craft.scene(),lobby,"guest"))
local packet = copy(C.snapshot(host))
C.guestStep(resumed,dt,packet)
assert(resumed.game.controlled==4 and resumed.game.clock==packet.clock and resumed.game.carrier==packet.carrier)
local staleWorld = copy(packet)
staleWorld.seq,staleWorld.homeScore = packet.seq-1,99
C.guestStep(resumed,dt,staleWorld)
assert(resumed.game.homeScore~=99)

-- The summary uses real host stats and never writes the single-player ledger.
game.phase,game.clock = "LIVE",.01
frame(0,0)
if game.phase=="INTERMISSION" then
    game.phase,game.clock,game.period = "LIVE",.01,2
    frame(0,0)
end
local result = assert(C.result(host))
assert(game.phase=="FINAL" and guest.game.phase=="FINAL" and not C.result(guest))
assert(result.matchId==lobby.matchId and result.stats.guest.passes==1 and result.stats.guest.goals==1)
assert(result.stats.host and readLocalData("PolyLax.Statistics.2.career-player")==nil)
print("Clubs host/guest: faceoff, pass, check, shot/goal, independent movement, reconnect, and host-only result passed.")
