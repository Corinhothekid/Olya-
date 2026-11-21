-- From the repository root: lua tests/equipment_integration.lua [PolyLax.codea]
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
local Match, Defense = P.FullMatch, P.Defense
local profile = P.Profile.load()
local function poleCount(game, team)
    local count = 0
    for _, id in ipairs(game.teams[team]) do
        local player = game.squad[id]
        assert(player.stickType == player.rig.stickType)
        if player.stickType == "long" then count = count+1 end
    end
    return count
end

local function careerGame(position)
    local career = P.Career.new()
    career.position = position
    career.attributes = P.Attributes.forPosition(position)
    local rules = P.Career.matchOptions(career,{opponent="foxmere",home=true})
    return Match.new(craft.scene(),profile,career.team,"foxmere",rules)
end

local lsm = careerGame(6)
local specialist = lsm.squad[lsm.careerPlayer]
assert(specialist.role=="LSM" and specialist.stickType=="long")
assert(poleCount(lsm,1)==4 and poleCount(lsm,2)==3)
local shortCareer = careerGame(7)
specialist = shortCareer.squad[shortCareer.careerPlayer]
assert(specialist.role=="SSDM" and specialist.stickType=="short")
assert(poleCount(shortCareer,1)==3 and poleCount(shortCareer,2)==3)
local capped = Match.new(craft.scene(),profile,1,2,{profile="ncaa",maxLongPoles=2})
assert(poleCount(capped,1)==2 and poleCount(capped,2)==2)
assert(capped.squad[10].stickType=="goalie" and capped.squad[20].stickType=="goalie")

local function stick(base, tip, length)
    return {stickType=length>0 and "long" or "short",stickReachExtension=length,
        stickRoot={transformPoint=function() return base end},pocket={worldPosition=tip}}
end
local function actor(id, team, z, yaw, rig)
    return {id=id,team=team,role="D",x=0,z=z,yaw=yaw,vx=0,vz=0,speed=0,
        checkCooldown=0,attributes={ballControl=65,stickCheck=80},rig=rig,anim={}}
end

local short = stick(vec3(0,1.5,-.5),vec3(0,1.5,-1.45),0)
local long = stick(vec3(0,1.5,-.5),vec3(0,1.5,-1.91),.46)
local target = actor(2,2,-2,180,stick(vec3(0,1.5,-1.90),vec3(0,1.5,-2.70),0))
local checker = actor(1,1,0,0,long)
local game = {carrier=2,squad={checker,target},rules={bodyContact=true}}
local request = {style="poke",target=2,skill=.80}
assert(Defense.contact(game,checker,request)=="loose","contact on the longer segment should dislodge")
checker.rig=short
assert(Defense.contact(game,checker,request)=="miss","short stick should be out of range")
checker.rig=long
target.rig=stick(vec3(1.3,1.5,-1.9),vec3(1.3,1.5,-2.7),0)
assert(Defense.contact(game,checker,request)=="miss","legal range alone must not cause a turnover")
target.rig=stick(vec3(.27,1.5,-1.9),vec3(.27,1.5,-2.7),0)
target.anim.action="dodge"
assert(Defense.contact(game,checker,request)=="miss","protected stick should resist marginal contact")
print("Specialist loadouts, both team pole limits, and contact-based reach passed.")
