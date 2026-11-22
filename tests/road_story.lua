-- Run from the repo root: lua tests/road_story.lua [PolyLax.codea]
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock=(arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(mock.."craft_mock.lua")
for _,tab in ipairs({"SchoolTeams","TeamUniform","Attributes","Career","StoryChapters","Story"}) do
    dofile(project.."/"..tab..".lua")
end

local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for k,v in pairs(value) do result[k]=copy(v) end
    return result
end

local persisted={}
json={
    encode=function(value) persisted[#persisted+1]=copy(value) return tostring(#persisted) end,
    decode=function(value) return copy(persisted[tonumber(value)]) end
}

local P=PolyLax
local Story=P.Story
local legacy=P.Career.new()
legacy.name="My Previous Career"
legacy.position=3
legacy.xp=713
assert(P.Career.save(legacy))
local legacyBytes=readLocalData("PolyLax.Career.1")
local story=Story.load()
story.equipment.credits=240
assert(story.athlete.name~=legacy.name and story.athlete.xp==0)
assert(Story.updateAthlete(story,{name="Taylor Lane",position=5,team="briarbank"}))
local locate={zone="drip",x=-7.75,z=4.5,yaw=285,cameraYaw=-26.5}
assert(Story.saveLocation(story,locate))
local kit=story.equipment
assert(Story.saveEquipment(story,{credits=210,stick={pattern="zebra"}}))
assert(story.equipment==kit and kit.stick.pattern=="zebra")
assert(Story.load().location.x==locate.x and Story.load().location.yaw==locate.yaw)
assert(Story.load().location.cameraYaw==locate.cameraYaw)
assert(Story.load().athlete.position==5)
local drill={stats={saves=1},homeScore=1,awayScore=0,elapsed=30}
assert(Story.recordActivity(story,"practice",drill))
assert(story.equipment.credits==225 and story.mission=="arrival")

local function prompt(id, node)
    local event=assert(Story.interact(story,id))
    assert(event.kind=="dialogue" and event.node==node and #event.choices>0)
    return event
end
local function choose(event,id)
    local nextEvent,reason=Story.choose(story,event,id)
    assert(not reason,reason)
    return nextEvent
end

local first=prompt("ethan","arrival")
local after=choose(first,"race")
assert(after and story.relationships.ethan==50 and after.text:find("half a second late",1,true))
assert(not Story.choose(story,first,"promise") and story.relationships.ethan==50)
story=Story.load()
assert(story.node=="arrival_plan" and story.flags.bond=="rivalry")
assert(prompt("ethan","arrival_plan").text:find("carries the balls",1,true))
choose(prompt("ethan","arrival_plan"),"find_coach")
assert(story.timeOfDay=="afternoon" and story.mission=="coach")
local second=choose(prompt("coach","coach"),"outlet")
local realWrite=saveLocalData
saveLocalData=function() return false end
local _, rejected=Story.choose(story,second,"outside")
assert(rejected and story.mission=="coach" and story.node=="coach_next")
saveLocalData=realWrite
choose(second,"outside")
assert(prompt("jace","rival").text:find("your unit",1,true))
choose(prompt("jace","rival"),"read")
assert(story.relationships.jace==34)
assert(choose(prompt("drip","equipment"),"browse").kind=="shop")
assert(Story.interact(story,"drip").kind=="shop")
choose(choose(prompt("tryout","locker"),"warmup"),"ready")
assert(story.timeOfDay=="practice" and story.mission=="practice")
assert(Story.interact(story,"practice").activity=="practice")
assert(Story.recordActivity(story,"practice",drill))
assert(story.completed.practice and story.mission=="tryout" and story.equipment.credits==225)
assert(Story.interact(story,"tryout").activity=="tryout")
assert(not Story.recordActivity(story,"tryout",{stats={},homeScore=0,awayScore=0,elapsed=0}))

local result={stats={saves=3,completions=2,goalsAllowed=1},ethanStats={turnovers=2},
    homeScore=2,awayScore=1,elapsed=35}
saveLocalData=function() return false end
assert(not Story.recordActivity(story,"tryout",result))
assert(not story.results.tryout and story.mission=="tryout" and story.equipment.credits==225)
saveLocalData=realWrite
local ok,receipt=Story.recordActivity(story,"tryout",result)
assert(ok and receipt.placement=="Varsity rotation" and receipt.focus:find("3 saves",1,true))
assert(story.ethan.depth~="Varsity rotation" and story.ethan.health=="managed strain")
assert(not Story.recordActivity(story,"tryout",result) and story.equipment.credits==265)
assert(not Story.updateAthlete(story,{name="Taylor Lane",position=2,team="briarbank"}))
story=Story.load()
assert(story.athlete.position==5 and story.results.tryout.placement==receipt.placement)
local feedback=choose(prompt("coach","debrief"),"feedback")
assert(feedback.text:find("Make the save",1,true))
choose(feedback,"understood")
assert(story.mission=="promise" and story.timeOfDay=="evening")
choose(prompt("ethan","promise"),"partners")
assert(story.day==2 and story.mission=="debut")
assert(Story.interact(story,"practice").activity=="debut")
assert(Story.recordActivity(story,"debut",{
    stats={saves=2,gamesPlayed=1},ethanStats={assists=1,groundBalls=2},
    homeScore=1,awayScore=5,elapsed=42
}))
assert(story.athlete.stats.saves==2 and story.athlete.losses==1 and story.athlete.games==1)
assert(story.ethan.statTotals.assists==1 and story.ethan.statTotals.groundBalls==2)
assert(story.mission=="complete" and story.completed.tryout and story.completed.debut)
assert(Story.interact(story,"clubs").kind=="clubs")
assert(Story.interact(story,"ethan").text:find("extra reps",1,true))
assert(Story.load().mission=="complete" and readLocalData("PolyLax.Career.1")==legacyBytes)

local function roleGrade(position,stats)
    local fresh=Story.new()
    fresh.athlete.position=position
    fresh.mission="tryout"
    local ok, report=Story.recordActivity(fresh,"tryout",{stats=stats,homeScore=0,awayScore=0,elapsed=35})
    assert(ok,report)
    return report.grade
end
assert(roleGrade(5,{goals=3})<roleGrade(5,{saves=3}))
assert(roleGrade(3,{goals=2})<roleGrade(3,{causedTurnovers=2,interceptions=1}))
assert(roleGrade(4,{faceoffsWon=2,faceoffAttempts=2})>roleGrade(4,{faceoffsWon=0,faceoffAttempts=2}))

local malformed="malformed content"
saveLocalData("PolyLax.RoadToGlory.1",malformed)
local recover=Story.load()
assert(recover.saveError and not Story.save(recover))
assert(readLocalData("PolyLax.RoadToGlory.1")==malformed)
print("Road to Glory branching, tryout and debut stats, Ethan outcomes, saves, duplicate protection, and legacy isolation passed.")
