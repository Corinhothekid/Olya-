-- Host simulation and guest rendering for the two-player Clubs prototype.
PolyLax = PolyLax or {}
local P = PolyLax
local ClubsMatch = {}
P.ClubsMatch = ClubsMatch

local positions = {
    attack=1, midfield=2, defense=3, faceoff=4, goalie=5, lsm=6, ssdm=7,
    ["long-stick mid"]=6, ["short-stick def mid"]=7
}
local ruleProfiles = {highSchool="highSchool", ncaa="ncaa", club="collegeClub", professional="professional"}
local permitted = {
    faceoff=true, clamp=true, counter=true, pass=true, shoot=true, scoop=true,
    poke=true, slap=true, body=true, dodge=true, setpick=true, releasepick=true
}
local phases = {FACEOFF=true, LIVE=true, FOUL=true, INTERMISSION=true, GOAL=true, FINAL=true}

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<math.huge
end

local function bounded(n, lower, upper, fallback)
    if not finite(n) then return fallback or 0 end
    return math.max(lower,math.min(n,upper))
end

local function movement(x, z)
    x, z = bounded(x,-1,1), bounded(z,-1,1)
    local scale = math.max(1,math.sqrt(x*x+z*z))
    return x/scale,z/scale
end

local function cleanPlayer(profile, name, team)
    profile = type(profile)=="table" and profile or {}
    local position = tonumber(profile.position) or positions[tostring(profile.position):lower()] or 2
    position = math.floor(bounded(position,1,#P.Career.positions,2))
    local raw = type(profile.appearance)=="table" and profile.appearance or {}
    local appearance = P.Athlete.profile({team=team,appearance=raw})
    if finite(profile.number) then appearance.NUMBER = 1+math.floor(bounded(profile.number,0,99)) end
    local nickname = type(profile.name)=="string" and profile.name:sub(1,38) or name
    return {
        name=nickname, role=P.Career.positions[position].role, appearance=appearance,
        attributes=P.Attributes.restore(profile.attributes,position), x=0, z=0
    }
end

local function vector(aim, minY, maxY, xLimit, zLimit)
    if type(aim)~="table" and type(aim)~="userdata" then return end
    if not finite(aim.x) or not finite(aim.y) or not finite(aim.z) then return end
    return {
        x=bounded(aim.x,-xLimit,xLimit), y=bounded(aim.y,minY,maxY),
        z=bounded(aim.z,-zLimit,zLimit)
    }
end

local function cleanAction(game, action, moveX, moveZ, aim)
    if not permitted[action] then return end
    local x,z = movement(moveX,moveZ)
    local input = {action=action,x=x,z=z}
    if action=="shoot" then
        input.aim = vector(aim,.02,5,3.6,game.field.halfLength)
    elseif action=="pass" and type(aim)=="table" then
        if finite(aim.to) then input.to = math.floor(bounded(aim.to,1,20)) end
        if not input.to then
            input.point = vector(aim.point,.09,3,game.field.halfWidth,game.field.halfLength)
        end
    end
    return input
end

local function applyCommand(game, slot, input)
    local aim
    if input.action=="shoot" and input.aim then
        local v = input.aim
        aim = vec3(v.x,v.y,v.z)
    elseif input.action=="pass" then
        if input.to then
            aim = P.Passing.forTarget(game,input.to)
        elseif input.point then
            local point, player = input.point, game.squad[slot]
            local x,z = point.x-player.x,point.z-player.z
            local range = math.sqrt(x*x + z*z)
            local scale = math.min(1,26/math.max(range,.001))
            aim = {point=vec3(player.x+x*scale,point.y,player.z+z*scale)}
        end
    end
    return P.FullMatch.command(game,input.action,input.x,input.z,aim,slot)
end

function ClubsMatch.command(play, action, moveX, moveZ, aim)
    local game = play.game
    if game.phase=="FACEOFF" and play.localSlot~=game.faceoff.home.id then return false end
    if game.phase~="FACEOFF" and game.phase~="LIVE" then return false end
    local input = cleanAction(game,action,moveX,moveZ,aim)
    if not input then return false end
    if play.isHost then return applyCommand(game,play.localSlot,input) end
    if #play.actions >= 8 then return false end
    play.actions[#play.actions+1] = input
    return true
end

function ClubsMatch.takeActions(play)
    local actions = play.actions
    play.actions = {}
    return actions
end

function ClubsMatch.new(scene, lobby, localId)
    if type(lobby)~="table" or type(lobby.players)~="table" or not lobby.matchId then return end
    local home = P.TeamUniform.get(lobby.team)
    local opponent = P.TeamUniform.opponent(home.home,lobby.opponent).teamId
    local humans, members = {}, {}
    local localSlot, humanCount = nil, 0
    for _, member in ipairs(lobby.players) do
        local slot = type(member)=="table" and member.slot
        if finite(slot) and slot%1==0 and slot>=1 and slot<=10 and not humans[slot]
            and type(member.id)=="string" and not members[member.id] then
            humans[slot] = cleanPlayer(member.profile,"Club Player",home.id)
            members[member.id] = {slot=slot,id=member.id,lastSequence=0}
            humanCount = humanCount+1
            if member.id==localId then localSlot = slot end
        end
    end
    if not localSlot or humanCount~=2 then return end
    local rules = {name="Clubs Scrimmage",profile=ruleProfiles[home.fieldType] or "arcade",
        periods=2,periodLength=60,humans=humans,playerId=localSlot,
        statistics={id=lobby.matchId,profileId=tostring(localId),profilePlayer=localSlot,mode="CLUBS"}}
    local game = P.FullMatch.new(scene,humans[localSlot].appearance,home.id,opponent,rules)
    game.clubsPlayer = localSlot
    local play = {scene=scene,game=game,localSlot=localSlot,isHost=localId==lobby.hostId,
        matchId=lobby.matchId,members=members,actions={},elapsed=0,sequence=0}
    play.controller = {
        command=function(_, ...) return ClubsMatch.command(play,...) end,
        canAim=P.FullMatch.canAim, aimContext=P.FullMatch.aimContext,
        passPreview=P.FullMatch.passPreview
    }
    return play
end

local function updateControl(target, input)
    target.x,target.z = movement(input.x,input.z)
    target.sprint = input.sprint==true
end

function ClubsMatch.hostStep(play, dt, localInput, events)
    if not play.isHost then return end
    dt = bounded(dt,0,.1)
    play.elapsed = play.elapsed+dt
    local game = play.game
    updateControl(game.humans[play.localSlot],localInput or {})
    if game.phase=="FINAL" then return end
    for _, event in ipairs(events or {}) do
        local member = play.members[event.playerId]
        local input = event.input
        if member and member.slot~=play.localSlot and member.slot==event.slot
            and type(input)=="table" and finite(input.seq) and input.seq>member.lastSequence then
            member.lastSequence,member.lastSeen = input.seq,play.elapsed
            updateControl(game.humans[member.slot],input)
            for i, item in ipairs(type(input.actions)=="table" and input.actions or {}) do
                if i>8 then break end
                if type(item)=="table" then
                    local aim = item.action=="pass" and {to=item.to,point=item.point} or item.aim
                    local action = cleanAction(game,item.action,item.x,item.z,aim)
                    if action then applyCommand(game,member.slot,action) end
                end
            end
        end
    end
    for _, member in pairs(play.members) do
        if member.slot~=play.localSlot and play.elapsed-(member.lastSeen or 0)>.75 then
            updateControl(game.humans[member.slot],{})
        end
    end
    local localControl = game.humans[play.localSlot]
    P.FullMatch.update(game,dt,localControl.x,localControl.z)
end

local function faceoffState(draw)
    if not draw then return end
    return {
        phase=draw.phase, active=draw.active, meter=draw.meter,
        windowStart=draw.windowStart, windowEnd=draw.windowEnd, sweetSpot=draw.sweetSpot,
        cpuMeter=draw.cpuMeter, userTeam=draw.userTeam, result=draw.result and {loose=draw.result.loose}
    }
end

function ClubsMatch.snapshot(play)
    if not play.isHost then return end
    local game = play.game
    local cached = play.outbound
    if cached and cached.phase==game.phase and play.elapsed-play.lastSnapshot<.083 then return cached end
    play.sequence,play.lastSnapshot = play.sequence+1,play.elapsed
    local players, blocked = {}, {}
    for index, p in ipairs(game.squad) do
        players[index] = {p.x,p.z,p.yaw,p.speed,p.turn,p.anim.action or "",p.anim.actionTime,p.anim.actionSpeed}
        if game.positioning.blocked[index] then blocked[#blocked+1] = index end
    end
    local ball, clock, screen = game.ball.position, game.ruleClock, game.screen
    play.outbound = {
        seq=play.sequence, matchId=play.matchId, players=players, ball={ball.x,ball.y,ball.z},
        phase=game.phase, phaseTime=game.phaseTime, clock=game.clock, period=game.period,
        homeScore=game.homeScore, awayScore=game.awayScore, carrier=game.carrier,
        pending=game.pending and game.pending.kind, flight=game.flight and game.flight.kind, loose=game.loose,
        inNet=game.inNet~=nil, announcement=game.announcement, announcementTime=game.announcementTime,
        ruleClock=clock and {shot=clock.shot,clear=clock.clear,crease=clock.crease},
        faceoff=game.phase=="FACEOFF" and faceoffState(game.faceoff) or nil,
        screen=screen and {screener=screen.screener,phase=screen.phase},
        blocked=blocked
    }
    return play.outbound
end

local function validSnapshot(play, data)
    if type(data)~="table" or data.matchId~=play.matchId or not finite(data.seq)
        or data.seq<=play.sequence or not phases[data.phase] or not finite(data.clock)
        or not finite(data.homeScore) or not finite(data.awayScore) or not finite(data.period)
        or type(data.players)~="table" or #data.players~=#play.game.squad or type(data.ball)~="table" then
        return false
    end
    for _, row in ipairs(data.players) do
        if type(row)~="table" or not finite(row[1]) or not finite(row[2]) or not finite(row[3]) then
            return false
        end
    end
    return finite(data.ball[1]) and finite(data.ball[2]) and finite(data.ball[3])
end

local function acceptSnapshot(play, data)
    local game = play.game
    play.sequence,play.inbound,play.lastSnapshot = data.seq,data,play.elapsed
    game.phase,game.phaseTime,game.clock,game.period = data.phase,data.phaseTime or 0,data.clock,data.period
    game.homeScore,game.awayScore = data.homeScore,data.awayScore
    game.controlled = play.localSlot
    game.carrier = finite(data.carrier) and game.squad[data.carrier] and data.carrier or nil
    game.pending,game.flight = data.pending and {kind=data.pending},data.flight and {kind=data.flight}
    game.loose,game.inNet = data.loose==true,data.inNet and {} or nil
    game.announcement = type(data.announcement)=="string" and data.announcement or ""
    game.announcementTime = bounded(data.announcementTime,0,10)
    game.ruleClock = type(data.ruleClock)=="table" and data.ruleClock or {}
    game.screen = type(data.screen)=="table" and data.screen or nil
    if type(data.blocked)=="table" then
        for _, slot in ipairs(data.blocked) do
            if slot==play.localSlot then
                game.positioning.notice,game.positioning.level,game.positioning.noticeTime = "OFFSIDES","offsides",.45
                break
            end
        end
    end
    if type(data.faceoff)=="table" then
        local draw = game.faceoff
        for _, key in ipairs({"phase","active","meter","windowStart","windowEnd","sweetSpot","cpuMeter","result"}) do
            draw[key] = data.faceoff[key]
        end
        draw.userTeam = play.localSlot==draw.home.id and data.faceoff.userTeam or false
    end
    for index, row in ipairs(data.players) do
        local anim = game.squad[index].anim
        local action = type(row[6])=="string" and P.AnimationController.clips[row[6]] and row[6] or nil
        anim.action,anim.actionTime,anim.actionSpeed = action,bounded(row[7],0,8),bounded(row[8],.5,2,1)
        if not action then anim.entry=nil end
    end
end

function ClubsMatch.guestStep(play, dt, snapshot)
    if play.isHost then return end
    local game = play.game
    dt = bounded(dt,0,.1)
    play.elapsed = play.elapsed+dt
    game.positioning.noticeTime = math.max(0,(game.positioning.noticeTime or 0)-dt)
    if validSnapshot(play,snapshot) then acceptSnapshot(play,snapshot) end
    local data = play.inbound
    if not data then return end
    local stale = play.elapsed-play.lastSnapshot>.6
    local blend = 1-math.exp(-18*dt)
    for index, player in ipairs(game.squad) do
        local row = data.players[index]
        player.x = player.x+(row[1]-player.x)*blend
        player.z = player.z+(row[2]-player.z)*blend
        player.yaw = player.yaw+((row[3]-player.yaw+180)%360-180)*blend
        player.speed = stale and 0 or bounded(row[4],0,20)
        player.turn = bounded(row[5],-1,1)
        player.rig.root.position,player.rig.root.eulerAngles = vec3(player.x,0,player.z),vec3(0,player.yaw,0)
        P.AnimationController.update(player.anim,dt,{speed=player.speed,turn=player.turn,possessed=game.carrier==index})
    end
    local p = game.squad[play.localSlot]
    game.marker.position = p.rig.root.position
    local target = vec3(data.ball[1],data.ball[2],data.ball[3])
    game.ball.position = game.ball.position+(target-game.ball.position)*blend
end

function ClubsMatch.result(play)
    if not play.isHost or play.game.phase~="FINAL" then return end
    local game = play.game
    local summary = P.Statistics.matchSummary(game)
    local stats = {}
    for id, member in pairs(play.members) do
        local entry = game.statistics.entries[member.slot]
        local line = entry.profile or entry.actor
        stats[id] = summary.players[line.playerId].stats
    end
    return {matchId=play.matchId,homeScore=game.homeScore,awayScore=game.awayScore,opponent=game.awayId,stats=stats}
end
