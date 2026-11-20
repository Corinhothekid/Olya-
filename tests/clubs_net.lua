-- Run with Lua 5.4. This checks the Codea request boundary using a fake transport.
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(project.."/ClubsNet.lua")
local Net = PolyLax.ClubsNet

assert(Net.validURL(" https://club.example.com/path/ ")=="https://club.example.com/path")
assert(not Net.validURL("http://club.example.com"))
assert(not Net.validURL("https://player:secret@club.example.com"))
assert(not Net.validURL("https://club.example.com?token=secret"))
assert(not Net.validURL("https://club.example.com:65536"))
assert(Net.validURL("http://127.0.0.1:8000",true))
assert(not Net.validURL("http://127.0.0.1.evil.example:8000",true))

local jsonTable = {}
local codec = {
    encode=function(value)
        local key = tostring(#jsonTable+1)
        jsonTable[#jsonTable+1] = value
        return key
    end,
    decode=function(key) return jsonTable[tonumber(key)] end,
}
local function fakeConnection()
    local calls = {}
    local function request(url, success, failure, options)
        assert(options.method=="POST" and options.headers["Content-Type"]=="application/json")
        calls[#calls+1] = {op=url:match("/v1/(%w+)$"), success=success, failure=failure,
            auth=options.headers.Authorization, body=codec.decode(options.data) or {}}
    end
    return Net.new("https://clubs.example.test",{transport=request,json=codec}), calls
end

local guest, guestCalls = fakeConnection()
local host, hostCalls = fakeConnection()
local function reply(call,payload,status)
    call.success(codec.encode(payload),status or 200)
end
local alice = {id="local-alice", name="Alice", position=1}
local sam = {id="local-sam", name="Sam", position=2}
local hostSession = {token=string.rep("0",32),playerId="a1",roomCode="ABCDEFG"}
local guestSession = {token=string.rep("1",32),playerId="b2",roomCode="ABCDEFG"}
local function lobby(phase, bothReady)
    return {code="ABCDEFG",name="Aces", team="briarbank", stage="highschool", phase=phase, hostId="a1",
        matchId=phase=="match" and "match-1" or nil,
        players={{id="a1",slot=1,ready=bothReady,connected=true,profile=alice},
            {id="b2",slot=4,ready=bothReady,connected=true,profile=sam}}}
end

assert(Net.create(host,{name="Aces",team="briarbank",stage="highschool"},alice))
assert(host.busy and hostCalls[1].op=="create" and hostCalls[1].body.profile==alice)
Net.tick(host,.2)
assert(#hostCalls==1)
reply(hostCalls[1],{lobby=lobby("lobby",false),session=hostSession})
assert(Net.isHost(host) and host.status=="connected")

assert(Net.join(guest," abcdefg ",sam))
assert(guestCalls[1].body.roomCode=="ABCDEFG" and guestCalls[1].auth==nil)
reply(guestCalls[1],{lobby=lobby("lobby",false),session=guestSession})
assert(not Net.isHost(guest))
Net.tick(guest,1)
assert(guestCalls[2].op=="sync" and guestCalls[2].auth=="Bearer "..guestSession.token)
assert(Net.ready(guest,true) and #guestCalls==2) -- Queue behind a lobby poll.
reply(guestCalls[2],{lobby=lobby("lobby",false)})
Net.tick(guest,.01)
assert(guestCalls[3].op=="ready" and guestCalls[3].body.ready)
reply(guestCalls[3],{lobby=lobby("lobby",true)})
assert(Net.start(host) and hostCalls[2].op=="start")
reply(hostCalls[2],{lobby=lobby("match",true)})
Net.tick(guest,1)
reply(guestCalls[4],{lobby=lobby("match",true)})

Net.tick(guest,.16,{input={x=.3,z=-.7,sprint=true,actions={{name="shoot",x=.4}}}})
local firstInput = guestCalls[5].body.input
assert(firstInput.seq==1 and firstInput.z==-.7 and firstInput.sprint and #firstInput.actions==1)
guestCalls[5].failure("connection lost")
assert(guest.status=="reconnecting")
Net.tick(guest,.23,{input={x=.8,z=0}})
assert(#guestCalls==5)
Net.tick(guest,.3,{input={x=.8,z=0}})
assert(guestCalls[6].body.input==firstInput) -- Same sequence and event through loss.
reply(guestCalls[6],{lobby=lobby("match",true), inputSeq=1, snapshot={seq=4,clock=118}})
assert(guest.snapshot.seq==4 and not guest.pendingInput)
Net.tick(guest,.16,{input={x=.8,z=0}})
assert(guestCalls[7].body.input.seq==2 and not guestCalls[7].body.input.actions)
reply(guestCalls[7],{lobby=lobby("match",true),snapshot={seq=3}})
assert(guest.snapshot.seq==4) -- Late world snapshots must never rewind play.

Net.tick(guest,.16)
assert(guestCalls[8].body.input)
reply(guestCalls[8],{error="Inputs are accepted only during a match."},409)
Net.tick(guest,.02)
assert(guestCalls[9].op=="sync" and not guestCalls[9].body.input)
reply(guestCalls[9],{lobby=lobby("final",true)})
assert(guest.lobby.phase=="final") -- Fetch the result even when match input is stale.

Net.tick(host,.17,{snapshot={seq=5,clock=114}})
assert(hostCalls[3].body.snapshot.seq==5 and hostCalls[3].body.after==0)
reply(hostCalls[3],{lobby=lobby("match",true), inputs={{id=3,playerId="b2",slot=4,input=firstInput}}})
assert(Net.takeInputs(host)[1].input.seq==1 and #Net.takeInputs(host)==0)
Net.tick(host,.17,{snapshot={seq=6,clock=113}})
assert(hostCalls[4].body.after==3)
reply(hostCalls[4],{lobby=lobby("match",true),inputs={{id=3,playerId="b2",slot=4,input=firstInput}}})
assert(#Net.takeInputs(host)==0)

local reloaded, resumeCalls = fakeConnection()
assert(Net.resume(reloaded,guestSession) and resumeCalls[1].auth=="Bearer "..guestSession.token)
reply(resumeCalls[1],{lobby=lobby("match",true),inputSeq=12,snapshot={seq=6}})
Net.tick(reloaded,.17,{input={x=.1,z=.5}})
assert(resumeCalls[2].body.input.seq==13)
Net.tick(reloaded,9,{input={x=.1,z=.5}})
assert(not reloaded.busy and reloaded.status=="reconnecting")
reply(resumeCalls[2],{lobby=lobby("match",true),snapshot={seq=90}})
assert(reloaded.snapshot.seq==6) -- Stale callback after timeout.
Net.tick(reloaded,1,{input={x=.1,z=.5}})
assert(resumeCalls[3].body.input.seq==13)
reply(resumeCalls[3],{error="Session expired."},401)
assert(not reloaded.session and not reloaded.snapshot)

assert(Net.leave(host))
reply(hostCalls[5],{ok=true})
assert(not host.session and not host.lobby and not host.busy)
print("Clubs transport passed URL checks, async lobby commands, input retry/de-duplication, snapshots, resume, timeout, and leave.")
