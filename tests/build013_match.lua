-- Run from the repository root with Lua 5.4:
--   lua tests/build013_match.lua
-- An optional first argument selects the Codea project directory.
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local tests = arg and arg[0] and arg[0]:match("^(.*[/])")
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests.."craft_mock.lua")

local tabs = {"SchoolTeams","TeamUniform","Profile","Character","AnimationController",
    "GoalPhysics","Attributes","Passing","Tactics","Screens","Field","League","Statistics","Defense","Midfield","MatchAI","Faceoff","FullMatch"}
for _, name in ipairs(tabs) do dofile(project.."/"..name..".lua") end

local P=PolyLax
local M=P.FullMatch
local oldUpdate=P.MatchAI.update
local function place(p,x,z,yaw)
    p.x,p.z,p.vx,p.vz,p.speed,p.yaw=x,z,0,0,0,yaw or 0
    p.rig.root.position,p.rig.root.eulerAngles=vec3(x,0,z),vec3(0,p.yaw,0)
end
local m=M.new(craft.scene(),P.Profile.load(),1,2)
local function open(id,who)
    P.MatchAI.update=oldUpdate
    M.command(m,'reset')
    m.phase,m.carrier,m.controlled='LIVE',id,who or id
    for i,p in ipairs(m.squad) do
        if p.team==1 then place(p,(i%2==0 and 1 or -1)*(10+i*.2),14+i)
        else place(p,(i%2==0 and 1 or -1)*(19+i*.15),34+i*.4,180) end
    end
    m.ball.position=m.squad[id].rig.pocket.worldPosition
end
local function advance(frames,x,z,stop)
    for i=1,frames do
        if stop and stop() then return i end
        M.update(m,.025,x or 0,z or 0)
    end
end
local function pin()
    local frozen={}
    for i,p in ipairs(m.squad) do frozen[i]={x=p.x,z=p.z} end
    P.MatchAI.update=function() return frozen end
    return frozen
end

open(4)
place(m.squad[4],4,-10)
place(m.squad[5],6,-11)
place(m.squad[2],4,-21)
local plan=assert(M.passPreview(m,0,-1))
assert(plan.to==2,'closest player overrode passing intent')
local frozen=pin()
assert(M.command(m,'pass',0,0,plan) and m.pending.to==2 and m.carrier==4)
advance(80,nil,nil,function() return m.flight~=nil end)
assert(m.flight and m.flight.to==2 and m.flight.velocity:len()>5)
local frozenPoint=m.flight.point
local sample=P.Passing.sample(m,m.flight,m.flight.duration)
assert((sample-frozenPoint):len()<.0001)
advance(80,nil,nil,function() return m.carrier==2 end)
assert(m.carrier==2 and m.stats[1].completions==1,'directed pass did not connect')

open(4)
place(m.squad[4],4,-10)
local manual=assert(M.passPreview(m,-1,-1))
assert(not manual.to and manual.point.x<4 and manual.point.z<-10)
pin()
assert(M.command(m,'pass',0,0,manual))
advance(100,nil,nil,function() return m.loose end)
assert(m.loose and not m.carrier and m.ball.position.y<=.11)

local function wing(blockLeft,blockRight)
    open(4)
    place(m.squad[4],0,-8)
    place(m.squad[1],-8,-21)
    place(m.squad[2],8,-21)
    place(m.squad[3],7,-34) -- player who starts at X
    for i=5,10 do place(m.squad[i],i*.08,-14+i*.1) end
    if blockLeft then place(m.squad[17],-8.4,-21) end
    if blockRight then place(m.squad[18],8.4,-21) end
end
wing(false,true)
assert(M.command(m,'clear') and m.pending.to==1)
wing(true,false)
assert(M.command(m,'clear') and m.pending.to==2)
wing(true,true)
assert(not M.command(m,'clear') and not m.pending and m.carrier==4 and m.mode=='CLEAR')
wing(false,false)
assert(M.command(m,'swing') and m.pending.to~=4)
wing(false,true)
place(m.squad[4],-5,-10)
local bx,bz=m.squad[4].x,m.squad[4].z
pin()
assert(M.command(m,'passdown') and m.pending.to==1)
advance(24)
assert((m.squad[4].x-bx)^2 + (m.squad[4].z-bz)^2 > .06,'passer did not cut')
wing(false,false)
place(m.squad[17],.15,-11)
place(m.squad[5],2,-8)
assert(M.command(m,'pickdown') and m.screen and m.screen.screener~=4)
pin()
advance(180,nil,nil,function() return m.screen and m.screen.phase=='HOLD' end)
assert(m.screen and m.screen.phase=='HOLD','pickdown never established a screen')

local function manualScreen()
    open(1,4)
    place(m.squad[4],0,-15)
    place(m.squad[1],1.4,-15)
    place(m.squad[12],-2,-15)
    assert(M.command(m,'setpick'))
    return m.squad[4],m.squad[12]
end
local screener,mark=manualScreen()
local pinned=pin()
advance(9)
assert(m.screen.phase=='HOLD')
place(mark,-.47,-15)
pinned[12]={x=mark.x,z=mark.z}
advance(1)
assert(m.screen and m.screen.contact and screener.stats.screens==1)
assert(#screener.screenCoachEvents==1 and screener.screenCoachEvents[1].points==2)
assert(M.command(m,'releasepick',0,1) and m.screen.style=='roll')

screener,mark=manualScreen()
pinned=pin()
place(mark,-.47,-15)
pinned[12]={x=mark.x,z=mark.z}
advance(1)
assert(m.phase=='FOUL' and screener.stats.illegalScreens==1 and screener.stats.screenCoachPoints==-4)
advance(73,nil,nil,function() return m.phase=='LIVE' end)
assert(m.phase=='LIVE' and m.carrier==12)

screener,mark=manualScreen()
advance(32,nil,nil,function()
    return m.ai.intents[1] and m.ai.intents[1].role=='USE PICK'
end)
assert(m.ai.intents[1] and m.ai.intents[1].role=='USE PICK','AI carrier did not choose the screen')
P.MatchAI.update=oldUpdate
print('Full Match aimed drop/catch, both CLEAR outlets, covered-lane hold, swing, pass-down cut, pick-down stance, human screens, coach points, offensive foul restart and AI use passed.')
