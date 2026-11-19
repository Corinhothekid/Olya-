-- From the repository root: lua tests/match_rules_integration.lua [PolyLax.codea]
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests.."craft_mock.lua")
local info = assert(io.open(project.."/Info.plist"))
local tabs = info:read("*a")
info:close()
for tab in tabs:gmatch("<string>([%w_]+)</string>") do
    dofile(project.."/"..tab..".lua")
end

local P = PolyLax
local Match = P.FullMatch
local profile = P.Profile.load()
local dt = .025
local function place(player, x, z)
    player.x,player.z,player.vx,player.vz=x,z,0,0
    player.rig.root.position=vec3(x,0,z)
end

local function possession(game, carrier)
    game.phase,game.carrier,game.controlled="LIVE",carrier,carrier
    game.ball.position=game.squad[carrier].rig.pocket.worldPosition
    P.MatchRules.possession(game,carrier)
end

local function assertLegal(game)
    for team=1,2 do
        local count = P.Midfield.counts(game,team)
        assert(count.valid and count.active==10 and count.offense>=3 and count.defense>=4)
    end
end

local previousAI = P.MatchAI.update
P.MatchAI.update=function(game)
    local frozen = {}
    for _,player in ipairs(game.squad) do frozen[player.id]={x=player.x,z=player.z} end
    return frozen
end

local function tickUntil(game, predicate)
    for _=1,80 do
        Match.update(game,dt,0,0)
        assertLegal(game)
        if predicate() then return end
    end
    error("Expected rules outcome did not occur")
end

local game = Match.new(craft.scene(),profile,1,2,{profile="ncaa",periodLength=20,shotClock=.2})
possession(game,1)
tickUntil(game,function() return game.announcement=="SHOT CLOCK VIOLATION" end)
assert(game.squad[game.carrier].team==2 and game.stats[1].turnovers==1)

game = Match.new(craft.scene(),profile,1,2,{profile="highSchool",periodLength=20,clearClock=.2})
possession(game,7)
tickUntil(game,function() return game.announcement=="CLEAR CLOCK VIOLATION" end)
assert(game.squad[game.carrier].team==2 and game.ruleClock.team==2)

game = Match.new(craft.scene(),profile,1,2,{profile="ncaa",periodLength=20,creaseClock=.2})
possession(game,10)
tickUntil(game,function() return game.announcement=="CREASE COUNT VIOLATION" end)
assert(game.squad[game.carrier].team==2 and game.squad[game.carrier].role~="G")

game = Match.new(craft.scene(),profile,1,2,{profile="ncaa",periodLength=20})
for _,player in ipairs(game.squad) do
    local side = player.team==1 and -1 or 1
    place(player,player.slot-5,(player.slot<=6 and side or -side)*3)
end
local offender = game.squad[7]
place(offender,0,.035)
P.Midfield.reset(game)
possession(game,7)
for _=1,10 do
    Match.update(game,dt,0,1)
    assertLegal(game)
    if game.announcement=="OFFSIDES" then break end
end
assert(game.announcement=="OFFSIDES" and game.squad[game.carrier].team==2 and game.stats[1].fouls==1)

game = Match.new(craft.scene(),profile,1,2,{profile="ncaa",periodLength=20})
local edge = game.field.halfWidth
place(game.squad[1],edge-.25,-8)
game.phase,game.loose,game.boundaryShot,game.lastTouch="LIVE",true,true,1
game.ball.position,game.ballVelocity=vec3(edge-.1,.12,-8),vec3(8,0,0)
Match.update(game,dt,0,0)
assert(game.announcement=="OUT OF BOUNDS" and game.carrier==1,
    "shot was not awarded to the nearest in-bounds team")
assertLegal(game)

P.MatchAI.update=previousAI
local career = P.Career.new()
local options = P.Career.matchOptions(career,{opponent="foxmere",home=true})
game = Match.new(craft.scene(),profile,career.team,"foxmere",options)
assert(game.rules.profile=="highSchool" and game.rules.periodLength==60 and game.rules.clearClock==20)
assertLegal(game)
print("Full Match and Career clock turnovers, offensive offsides, shot boundary, and legal restarts passed.")
