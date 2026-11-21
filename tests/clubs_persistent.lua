-- From the repository root: lua tests/clubs_persistent.lua [PolyLax.codea]
local testPath = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(testPath.."craft_mock.lua")
for _, tab in ipairs({"SchoolTeams","TeamUniform","Profile","Attributes","League",
    "Athlete","Career","Development","CareerSeason","Clubs","ClubsNet"}) do
    dofile(project.."/"..tab..".lua")
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local encoded = {}
json = {
    encode=function(value) encoded[#encoded+1]=copy(value) return tostring(#encoded) end,
    decode=function(number) return copy(encoded[tonumber(number)]) end
}

local P = PolyLax
local Clubs, Net = P.Clubs, P.ClubsNet
local alpha, beta = "https://alpha.example.test","https://beta.example.test"
local legacy = P.Career.new()
legacy.id, legacy.name, legacy.position, legacy.xp = "plx_"..string.rep("a",32),"Saved Athlete",6,71
saveLocalData("PolyLax.Clubs.1",json.encode({
    version=1,player=legacy,settings={relayURL=alpha},
    club={name="My club",stage="highSchool",team="briarbank",season=2}
}))
local data = Clubs.load()
assert(data.player.id==legacy.id and data.player.position==6 and data.player.xp==71 and data.club.season==2)
assert(not Clubs.savedRoom(data))

local function room(token, who)
    local session = {token=string.rep(token,43),playerId=who,roomCode="MYBC2026"}
    local lobby = {code=session.roomCode,name="My club",stage="highSchool",team="briarbank",
        phase="lobby",hostId=who,revision=3,players={{id=who,profile={id=data.player.id}}}}
    return session,lobby
end

local alphaSession, alphaLobby = room("a","relay-alpha")
local wrongOwner = copy(alphaLobby)
wrongOwner.players[1].profile.id = "other-profile"
assert(not Clubs.storeRoom(data,alphaSession,wrongOwner))
local saved = saveLocalData
saveLocalData = function() return false end
assert(not Clubs.storeRoom(data,alphaSession,alphaLobby) and not Clubs.savedRoom(data))
saveLocalData = saved
assert(Clubs.storeRoom(data,alphaSession,alphaLobby))
assert(Clubs.savePlayer(data,data.player))
data = Clubs.load()
assert(data.player.xp==71 and Clubs.activeClub(data).code==alphaSession.roomCode)
assert(Clubs.hostedRoom(data).session.token==alphaSession.token)

assert(Clubs.setRelay(data,beta) and not Clubs.savedRoom(data,"mybc2026"))
local betaSession, betaLobby = room("b","relay-beta")
assert(Clubs.storeRoom(data,betaSession,betaLobby))
assert(Clubs.setRelay(data,alpha) and Clubs.savedRoom(data).session.token==alphaSession.token)
assert(Clubs.setRelay(data,beta))
data = Clubs.load()
assert(Clubs.savedRoom(data).session.token==betaSession.token)

betaLobby.lastResult = {matchId="saved-final",homeScore=3,awayScore=2,
    stats={[betaSession.playerId]={goals=1}}}
local xp = data.player.xp
assert(not Clubs.recordOnline(data,betaLobby,copy(betaLobby.lastResult),betaSession.playerId))
assert(Clubs.recordOnline(data,betaLobby,betaLobby.lastResult,betaSession.playerId))
local recordedXP = data.player.xp
assert(recordedXP>xp and data.online.games==1)
assert(Clubs.recordOnline(Clubs.load(),betaLobby,betaLobby.lastResult,betaSession.playerId))
assert(Clubs.load().player.xp==recordedXP and Clubs.load().online.games==1)

local calls = {}
local net = Net.new(beta,{json=json,transport=function(url,success,failure,options)
    calls[#calls+1] = {op=url:match("/v1/(%w+)$"),auth=options.headers.Authorization,
        body=json.decode(options.data),success=success,failure=failure}
end})
local profile = {id=data.player.id,position=7}
assert(Net.resume(net,Clubs.savedRoom(data).session,profile))
assert(calls[1].op=="resume" and calls[1].auth=="Bearer "..betaSession.token)
calls[1].failure()
Net.tick(net,.6)
assert(calls[2].op=="resume" and calls[2].body.profile.position==7)
calls[2].success(json.encode({message="Session revoked"}),401)
assert(not net.session and net.revokedRoom==betaSession.roomCode)
assert(Clubs.forgetRoom(data,net.revokedRoom) and not Clubs.savedRoom(Clubs.load()))
assert(Clubs.setRelay(data,alpha))
assert(Clubs.savedRoom(Clubs.load()).session.token==alphaSession.token)
print("Permanent Clubs save migration, relay credential scope, archived results, retry and revocation passed.")
