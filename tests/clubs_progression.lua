-- From the repository root: lua tests/clubs_progression.lua [PolyLax.codea]
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock = dofile(tests.."craft_mock.lua")
local combined = os.getenv("POLYLAX_TEST_DELIVERABLE")
if combined then
    dofile(combined)
else
    for _, tab in ipairs({"SchoolTeams","TeamUniform","Profile","Attributes","League",
        "Athlete","Career","Development","CareerSeason","Clubs"}) do
        dofile(project.."/"..tab..".lua")
    end
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local entries = {}
json = {encode=function(value)
    entries[#entries+1] = copy(value)
    return tostring(#entries)
end, decode=function(id)
    return copy(entries[tonumber(id)])
end}

local P = PolyLax
local Clubs = P.Clubs
local solo = P.Career.new()
solo.name, solo.xp = "Solo Athlete", 93
assert(P.Career.save(solo))
local originalSolo = mock.store["PolyLax.Career.1"]
local data = Clubs.load()
assert(Clubs.create(data,"My Saved Club","professional",4))
local player = data.player
local balance = P.Development.points(player)

local memberId = "8e7b1b7665b39b9655da817c"
local matchId = "a549c78e0cce0fa28b251093"
local lobby = {code="8PRLAX21",name="Lacrosse Friends",team="florida-state",stage="college",
    phase="match",matchId=matchId, players={{id=memberId,profile={id=player.id},slot=5},
    {id="1a0935acd6c0846dcb9b8319",profile={id="another-device"},slot=6}}}
local result = {matchId=matchId,homeScore=7,awayScore=4,opponent="bayhaven-club",stats={
    [memberId]={goals=2,assists=1,minutesPlayed=2.5,groundBalls=-4,gamesPlayed=1,gamesStarted=1,
        screenCoachPoints=-2,unknown=999}}}

assert(Clubs.joinedTeam(data,lobby))
assert(Clubs.activeClub(data).team=="florida-state" and data.club.team==4 and player.team==4)
assert(Clubs.schedule(data)[1].opponent ~= Clubs.schedule(Clubs.load())[1].opponent)
assert(not Clubs.recordOnline(data,lobby,result,memberId))
lobby.phase = "final"
assert(not Clubs.recordOnline(data,lobby,result,lobby.players[2].id))
local wrongMatch = copy(result)
wrongMatch.matchId = "different-match"
assert(not Clubs.recordOnline(data,lobby,wrongMatch,memberId))
local wrongProfile = copy(lobby)
wrongProfile.players[1].profile.id = "another-device"
assert(not Clubs.recordOnline(data,wrongProfile,result,memberId))

local save = saveLocalData
saveLocalData = function() return false end
assert(not Clubs.recordOnline(data,lobby,result,memberId))
assert(data.player==player and player.games==0 and player.xp==0 and not data.online)
assert(P.Development.points(player)==balance and not player.entries["club:"..matchId])
saveLocalData = save

local accepted, message, wrote = Clubs.recordOnline(data,lobby,result,memberId)
assert(accepted and not message and wrote)
assert(player==data.player and player.games==1 and player.wins==1 and player.xp==47)
assert(player.stats.goals==2 and player.stats.assists==1 and player.stats.minutesPlayed==2.5)
assert(player.stats.groundBalls==0 and player.stats.screenCoachPoints==-2 and player.stats.unknown==nil)
assert(P.Development.points(player)>balance+player.xp)
assert(data.online.games==1 and data.online.wins==1 and #Clubs.results(data)==1)
local row = Clubs.results(data)[1]
assert(row.opponent==P.TeamUniform.get("bayhaven-club").name and row.xp==47)
assert(Clubs.joinedTeam(data,nil) and Clubs.activeClub(data).team==4)

local reloaded = Clubs.load()
assert(not reloaded.joined and reloaded.club.name=="My Saved Club")
assert(reloaded.player.id==player.id and reloaded.player.xp==47 and reloaded.online.wins==1)
accepted, message, wrote = Clubs.recordOnline(reloaded,lobby,result,memberId)
assert(accepted and not message and wrote==false and reloaded.player.xp==47)
assert(#Clubs.results(reloaded)==1 and mock.store["PolyLax.Career.1"]==originalSolo)
assert(P.Career.load().name=="Solo Athlete" and P.Career.load().xp==93)
print("Clubs result ownership, save rollback, deduplication, reload, and Be a Pro isolation passed.")
