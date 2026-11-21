-- Run from the repository root: lua tests/positions_integration.lua [PolyLax.codea]
local checks = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(checks.."craft_mock.lua")

local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for key,item in pairs(value) do result[key]=copy(item) end
    return result
end
local saved={}
json={
    encode=function(value)
        saved[#saved+1]=copy(value)
        return tostring(#saved)
    end,
    decode=function(raw) return copy(saved[tonumber(raw)]) end
}

local combined = os.getenv("POLYLAX_TEST_DELIVERABLE")
if combined then dofile(combined)
else
    local info=assert(io.open(project.."/Info.plist"))
    for tab in info:read("*a"):gmatch("<string>([%w_]+)</string>") do
        dofile(project.."/"..tab..".lua")
    end
    info:close()
end

local P = PolyLax
local expected = {
    {"A","short",1,"shotPower",68}, {"M","short",5,"stamina",71},
    {"D","long",7,"stickCheck",72}, {"FOGO","short",4,"faceoff",76},
    {"G","goalie",10,"reflexes",75}, {"LSM","long",5,"stickCheck",73},
    {"SSDM","short",6,"bodyCheck",70}
}
local appearance = P.Profile.load()
local fixtures = {}
for id, role in ipairs(expected) do
    local career=P.Career.new()
    local category=P.Athlete.categories(career)[2]
    assert(#category.choices==7 and category.values[id]==id)
    assert(P.Athlete.select(career,appearance,category,id,false))
    assert(career.position==id and career.attributes[role[4]]==role[5])
    assert(P.Attributes.overall(career.attributes,id)==P.Attributes.overall(career.attributes,role[1]))
    career.attributes.acceleration=81
    assert(P.Career.save(career))
    local reloaded=P.Career.load()
    assert(reloaded.position==id and reloaded.attributes.acceleration==81)
    local options=P.Career.matchOptions(reloaded,{home=true,opponent="briarbank"})
    local game=P.FullMatch.new(craft.scene(),appearance,1,2,options)
    local athlete=P.FullMatch.careerAthlete(game)
    assert(athlete.role==role[1] and athlete.slot==role[3] and athlete.stickType==role[2])
    assert(athlete.attributes.acceleration==81 and athlete.attributes[role[4]]==role[5])
    assert(game.faceoff.userTeam==(id==4 and 1 or false))
    fixtures[id]=game

    local clubs=P.Clubs.load()
    category=P.Athlete.categories(clubs.player,true,true)[2]
    assert(#category.choices==7 and category.values[id]==id)
    assert(P.Athlete.select(clubs.player,nil,category,id,true,
        function(candidate) return P.Clubs.savePlayer(clubs,candidate) end,true))
    assert(P.Clubs.load().player.position==id)
    local lineup={
        team=1,opponent=2,matchId="positions-"..id,hostId="host",
        players={
            {id="host",slot=role[3],profile=clubs.player},
            {id="guest",slot=role[3]==2 and 3 or 2,profile={position=1}}
        }
    }
    local localMatch=assert(P.ClubsMatch.new(craft.scene(),lineup,"host"))
    local clubAthlete=localMatch.game.squad[localMatch.localSlot]
    assert(clubAthlete.role==role[1] and clubAthlete.stickType==role[2])
    assert(clubAthlete.attributes[role[4]]==role[5])
end

local practice=P.Gameplay.new(craft.scene(),appearance,P.TeamUniform.get(1).home,2)
assert(practice.goalie.stickType=="goalie")
local keeper=fixtures[5].squad[10]
local outfield=fixtures[5].squad[1]
local function width(mesh)
    local maximum=0
    for _, point in ipairs(mesh.positions) do maximum=math.max(maximum,math.abs(point.x)) end
    return maximum*2
end
assert(width(keeper.rig.stickHead.model)>width(outfield.rig.stickHead.model)*1.45)
assert(practice.goalie.stickHead.model==keeper.rig.stickHead.model)
local original=keeper.rig.stickHead
P.Character.setStickType(keeper.rig,"short")
assert(keeper.rig.stickHead==original and original.model==outfield.rig.stickHead.model)
P.Character.setStickType(keeper.rig,"goalie")
assert(keeper.rig.stickHead==original and original.model==practice.goalie.stickHead.model)
for _=1,30 do P.AnimationController.update(keeper.anim,1/60,{speed=0}) end
assert((keeper.rig.joints.rightWrist.worldPosition-keeper.rig.stickRoot.worldPosition):len()<.04)
assert(keeper.anim.lastPose.crouch>.08)

local function seedShift(game, carrier)
    local player=game.squad[game.careerPlayer]
    player.x,player.z,player.vx,player.vz=game.field.halfWidth-2,2.15,0,0
    player.rig.root.position=vec3(player.x,0,player.z)
    game.careerWaiting=false
    game.phase,game.phaseTime,game.elapsed="LIVE",0,game.specialistShift.ready
    game.carrier,game.lastTouch=carrier,game.squad[carrier].team
    game.pending,game.flight,game.loose,game.tactical=nil,nil,nil,nil
    game.faceoffScramble,game.scoopPlayer=nil,nil
    game.ball.position=game.squad[carrier].rig.pocket.worldPosition
    P.MatchRules.possession(game,carrier,"pass")
    P.AnimationController.reset(player.anim)
    P.Midfield.reset(game)
end

local function exchange(game, onBench)
    local crossed=false
    for _=1,90 do
        P.FullMatch.update(game,.025,0,0)
        crossed = crossed or game.specialistShift.going
        if game.careerOnBench==onBench then break end
    end
    assert(crossed and game.careerOnBench==onBench,"Specialist failed to cross the sideline")
    assert(#game.squad==20 and P.Midfield.counts(game,1).active==10
        and P.Midfield.counts(game,1).valid)
    assert(game.specialistShift.idle.rig.root.position.x>game.field.halfWidth)
end

local fogo=fixtures[4]
local personal=fogo.statistics.entries[fogo.careerPlayer].profile
local reserve=fogo.statistics.entries[fogo.careerPlayer].actor
local originalFogoRig=fogo.squad[fogo.careerPlayer].rig
fogo.faceoff.away.cpuTiming=.95
for _=1,200 do
    P.FullMatch.update(fogo,.025,0,0)
    local draw=fogo.faceoff
    if draw.phase=="DRAW" and draw.meter>=draw.sweetSpot-.02 and not draw.home.action then
        P.FullMatch.command(fogo,"counter",0,0)
    end
    if fogo.phase=="LIVE" then break end
end
assert(fogo.faceoff.home.action=="counter" and personal.stats.faceoffsWon==1)
seedShift(fogo,15)
exchange(fogo,true)
assert(fogo.squad[fogo.careerPlayer].role=="M")
assert(P.FullMatch.careerAthlete(fogo).rig==originalFogoRig)
P.FullMatch.recordStat(fogo,fogo.careerPlayer,"groundBalls")
assert(reserve.stats.groundBalls==1 and not personal.stats.groundBalls
    and personal.stats.faceoffsWon==1 and not reserve.stats.faceoffsWon)
assert(reserve.name=="Shift Midfielder" and personal.role=="FOGO")
assert(not P.UI.action(fogo,{id="pass"}))
fogo.phase,fogo.phaseTime="INTERMISSION",fogo.rules.intermissionTime
P.FullMatch.update(fogo,.025,0,0)
assert(fogo.phase=="FACEOFF" and not fogo.careerOnBench and fogo.squad[4].rig==originalFogoRig)
assert(fogo.faceoff.userTeam==1)

local lsm=fixtures[6]
local originalLsmRig = lsm.squad[5].rig
seedShift(lsm,1)
exchange(lsm,true)
assert(lsm.squad[5].stickType=="short")
seedShift(lsm,15)
exchange(lsm,false)
assert(lsm.squad[5].rig==originalLsmRig and lsm.squad[5].stickType=="long")

print("All seven Career and Clubs position IDs, ratings and kits, goalie geometry, FOGO and LSM live substitutions, and bench statistics passed.")
