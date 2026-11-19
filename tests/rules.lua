-- Run with Lua 5.4 from the workspace or repository root.
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
for _, tab in ipairs({"Defense", "Midfield", "MatchRules"}) do
    dofile(project.."/"..tab..".lua")
end

local Rules = PolyLax.MatchRules
local function configure(profile)
    return Rules.configure({profile=profile})
end

local default = configure(nil)
assert(default.profile == "arcade" and default.periods == 4 and default.periodLength == 90)
assert(not default.shotClock and not default.clearClock and not default.creaseClock)
assert(default.shotBoundary == "lastTouch")
local highSchool = configure("highSchool")
assert(highSchool.periodLength == 720 and highSchool.clearClock == 20 and highSchool.creaseClock == 4)
assert(highSchool.bodyContact and not highSchool.shotClock and highSchool.shotBoundary == "nearest")
local specialized = Rules.configure({profile="ncaa",ageGroup="12U",bodyContact=false,
    periods=2,periodLength=60,shotClock=false,clearClock=15,faceoff={difficulty="HARD"}})
assert(specialized.periods == 2 and specialized.periodLength == 60 and specialized.clearClock == 15)
assert(not specialized.shotClock and not specialized.bodyContact and specialized.faceoff.difficulty == "HARD")
for _, profile in ipairs({"ncaa", "collegeClub"}) do
    local rule = configure(profile)
    assert(rule.periodLength == 900 and rule.shotClock == 80 and rule.shotRecovery == 60)
end
local pro = configure("professional")
assert(pro.periodLength == 720 and pro.shotClock == 52 and pro.faceoffShotClock == 32)
assert(pro.maxLongPoles == 4 and pro.fieldMetrics.fieldLengthYards == 100 and pro.fieldMetrics.wingFromCenterYards == 19)
local professionalVenue = Rules.configure({profile="professional",fieldMetrics={fieldLengthYards=110}})
assert(professionalVenue.fieldMetrics.fieldLengthYards == 110 and professionalVenue.fieldMetrics.wingFromCenterYards == 19)

local function new(options)
    local game = {
        phase="LIVE", rules=Rules.configure(options), field={midfieldZ=0,creaseRadius=2.75},
        goalsByTeam={{x=0,z=-35,attackSign=-1}, {x=0,z=35,attackSign=1}},
        squad={{id=1,team=1,x=0,z=10}, {id=2,team=2,x=0,z=-10}, {id=3,team=1,x=4,z=-14}},
        ball={position={x=0,z=10}},
    }
    Rules.reset(game)
    return game
end

local function receive(game, index, source)
    game.carrier,game.flight = index,nil
    game.ball.position = {x=game.squad[index].x,z=game.squad[index].z}
    Rules.possession(game,index,source)
end

local function release(game, team)
    game.carrier = nil
    game.flight = {kind="shot",team=team,time=0,duration=2,
        origin=game.ball.position,goal=game.goalsByTeam[team]}
    Rules.shotReleased(game,game.flight)
    return game.flight
end

do
    local game = new({profile="ncaa"})
    receive(game,1)
    assert(Rules.tick(game,8) == nil and game.ruleClock.clear == 12 and game.ruleClock.shot == 72)
    game.phase = "FOUL"
    assert(Rules.tick(game,10) == nil and game.ruleClock.shot == 72)
    game.phase = "LIVE"
    game.carrier, game.flight = nil,{kind="pass",team=1}
    game.ball.position.z = -2
    assert(Rules.tick(game,2) == nil and game.ruleClock.clear == nil and game.ruleClock.shot == 70)
    receive(game,3)
    assert(game.ruleClock.shot == 70)
    game.carrier,game.flight = nil,nil
    assert(Rules.tick(game,1) == nil and game.ruleClock.shot == 69)
    receive(game,2,"restart")
    assert(game.ruleClock.team == 2 and game.ruleClock.shot == 80 and game.ruleClock.clear == 20)
    local expired = assert(Rules.tick(game,20))
    assert(expired.reason == "clearClock" and expired.team == 2 and not Rules.tick(game,1))
    Rules.stop(game)
    assert(not game.ruleClock.team)
end

do
    local game = new({profile="highSchool",stateShotClock=true})
    receive(game,1)
    assert(not game.ruleClock.shot and game.ruleClock.clear == 20)
    assert(Rules.tick(game,5) == nil and not game.ruleClock.shot)
    receive(game,3)
    assert(Rules.tick(game,1) == nil and game.ruleClock.shot == 69 and not game.ruleClock.clear)
end

do
    local game = new({profile="ncaa",shotClock=2})
    receive(game,3)
    local flight = release(game,1)
    flight.time = 1
    assert(Rules.tick(game,2) == nil and game.ruleClock.shot == 0)
    Rules.shotContact(game,flight,"POST")
    assert(game.ruleClock.shot == 2 and game.ruleClock.validShot)
    assert(Rules.tick(game,9) == nil and game.ruleClock.shot == 2)
    receive(game,3)
    assert(game.ruleClock.shot == 2 and not game.ruleClock.validShot)
    release(game,1).time = 1
    assert(Rules.tick(game,2) == nil)
    game.flight = nil -- a miss
    local expired = assert(Rules.tick(game,1))
    assert(expired.reason == "shotClock" and expired.team == 1 and not Rules.tick(game,1))
end

do
    local game = new({profile="professional"})
    receive(game,3,"faceoff")
    assert(game.ruleClock.shot == 32)
    Rules.shotContact(game,release(game,1),"SAVE")
    receive(game,3)
    assert(game.ruleClock.shot == 32)
    receive(game,2)
    receive(game,3)
    assert(game.ruleClock.shot == 52)
    local flight = release(game,1)
    flight.time = 1
    Rules.tick(game,1)
    Rules.shotContact(game,flight,"CROSSBAR")
    receive(game,3)
    assert(game.ruleClock.shot == 52)
    game.ruleClock.shot = 31
    Rules.shotContact(game,release(game,1),"POST")
    receive(game,1) -- a valid shot returned to the defensive half
    assert(game.ruleClock.shot == 52 and game.ruleClock.clear == 20)
    game.squad[3].z = -39
    receive(game,3)
    local invalid = release(game,1)
    Rules.shotContact(game,invalid,"POST")
    assert(not game.ruleClock.validShot)
end

do
    local game = new({profile="collegeClub"})
    game.squad[1].z = 35
    receive(game,1)
    assert(Rules.tick(game,2) == nil and game.ruleClock.crease == 2)
    game.carrier, game.flight = nil,{kind="pass",team=1}
    assert(Rules.tick(game,1) == nil and game.ruleClock.crease == 2)
    game.flight = nil
    game.squad[3].x, game.squad[3].z = 1,35
    receive(game,3)
    local expired = assert(Rules.tick(game,2))
    assert(expired.reason == "creaseClock" and expired.team == 1)
end

do
    for _, profile in ipairs({"highSchool","ncaa","collegeClub"}) do
        local game = new({profile=profile})
        receive(game,1)
        assert(not Rules.tick(game,3))
        receive(game,3)
        assert(not Rules.tick(game,3) and not game.ruleClock.clear)
        receive(game,1)
        assert(not Rules.tick(game,3) and game.ruleClock.clear == 11)
        local missedDeadline = assert(Rules.tick(game,11))
        assert(missedDeadline.reason == "clearClock" and missedDeadline.player == 1)
        Rules.reset(game)
        receive(game,3)
        assert(not Rules.tick(game,20))
        game.carrier,game.lastTouch,game.ball.position.z = nil,2,10
        assert(not Rules.tick(game,1) and not game.ruleClock.clear)
        receive(game,3)
        assert(not Rules.tick(game,1))
        receive(game,1)
        local over = assert(Rules.tick(game,1))
        assert(over.reason == "overAndBack" and over.team == 1 and over.player == 1)
    end
end

do
    local game = new({profile="professional"})
    receive(game,3,"faceoff")
    receive(game,1) -- the first possession may return across the line once
    assert(not Rules.tick(game,1))
    receive(game,3)
    assert(not Rules.tick(game,1))
    receive(game,1)
    assert(Rules.tick(game,1).reason == "overAndBack")
end

print("Rules profiles, clear deadline, over-and-back, crease, shot expiry, recovery, faceoff and period pause passed.")
