-- From the repository root: lua tests/career_playoffs.lua [PolyLax.codea]
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests.."craft_mock.lua")
local standalone = os.getenv("POLYLAX_TEST_DELIVERABLE")
if standalone then
    dofile(standalone)
else
    local plist = assert(io.open(project.."/Info.plist"))
    local tabs = plist:read("*a")
    plist:close()
    for name in tabs:gmatch("<string>([%w_]+)</string>") do
        dofile(project.."/"..name..".lua")
    end
end
local function copy(tableOrValue)
    if type(tableOrValue) ~= "table" then return tableOrValue end
    local result = {}
    for key,value in pairs(tableOrValue) do result[key] = copy(value) end
    return result
end
local saves = {}
json = {
    encode=function(data)
        local key = tostring(#saves + 1)
        saves[#saves + 1] = copy(data)
        return key
    end,
    decode=function(key) return copy(saves[tonumber(key)]) end
}
local Career, Season = PolyLax.Career, PolyLax.CareerSeason
local function final(career, fixture, ours, theirs)
    local match = {phase="FINAL",homeScore=ours,awayScore=theirs,careerPlayer=1,
        squad={{stats={goals=ours,shots=ours+1}}}}
    assert(Career.record(career,fixture,match))
    assert(not Career.record(career,fixture,match))
    assert(Career.load().entries[fixture.id])
end
local career = Career.new()
career.stage, career.team = "professional", 1
career.contract = {length=2,remaining=2,value=25}
local regular, fixture = 0, Career.fixture(career)
while fixture and fixture.week do
    final(career,fixture,9,2)
    regular = regular+1
    fixture = Career.fixture(career)
end
assert(regular==7)
assert(Season.standings(career)[1].id==career.team)
assert(fixture.phase=="semifinal")
local boxes, quarterfinals = Season.boxScores(career), 0
for _,box in pairs(boxes) do
    if box.postseason=="quarterfinal" then
        quarterfinals=quarterfinals+1
        assert(box.homeId~=career.team and box.awayId~=career.team)
    end
end
assert(quarterfinals==2)
local firstFixtureId=fixture.id
final(career,fixture,4,4)
career = Career.load()
fixture=Career.fixture(career)
assert(fixture.phase=="semifinal" and fixture.id~=firstFixtureId and fixture.label=="Semifinal replay")
final(career,fixture,7,3)
fixture=Career.fixture(career)
assert(fixture.phase=="final" and fixture.postseason=="championship")
final(career,fixture,5,2)
career=Career.load()
assert(Career.fixture(career)==nil and Season.status(career).title)
assert(career.championships==1 and career.contract.remaining==1)
assert(Season.advance(career) and career.season==2 and #career.history==1)
assert(Career.fixture(Career.load()).week == 1)
print("Six-team pro playoffs: two byes, simulated quarterfinals, save/reload, semifinal replay, championship and next season passed.")
career = Career.new()
career.stage, career.team = "professional", 1
Career.fixture(career)
local data = career.seasonData
data.week = #data.rounds+1
for _,record in pairs(data.records) do
    record.wins = record.id==1 and 3 or record.id<=3 and 4 or 0
end
fixture=Career.fixture(career)
assert(fixture.phase=="quarterfinal")
final(career,fixture,2,7)
assert(Career.fixture(career)==nil and not Season.status(career).title and career.seasonData.champion~=career.team)
print("Six-team pro playoffs: lower seed quarterfinal, elimination and simulated finish passed.")
career=Career.new()
Career.fixture(career)
data=career.seasonData
data.phase, data.replay, data.otherFinalist = "semifinal", 0, "alderwick"
data.bracket=nil
data.playoffs={{home=false,opponent="foxmere",label="Semifinal"}}
fixture=Career.fixture(career)
assert(fixture.phase=="semifinal")
final(career,fixture,9,4)
fixture=Career.fixture(career)
assert(fixture.phase=="final" and fixture.postseason=="championship")
final(career,fixture,5,2)
assert(Career.fixture(career)==nil and Season.status(career).title)
print("Legacy save: originally opened semifinal and championship still work.")
