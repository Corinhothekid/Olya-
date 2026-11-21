-- PolyLax 3.1 | Independent Clubs profile and club storage
PolyLax = PolyLax or {}
local P = PolyLax
local Clubs = {}
P.Clubs = Clubs

local saveKey = "PolyLax.Clubs.1"
local version = 1
Clubs.nameLimit = 28
Clubs.stages = {"highSchool", "college", "professional"}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function replace(fields, candidate)
    for key in pairs(fields) do
        if candidate[key] == nil then fields[key] = nil end
    end
    for key, value in pairs(candidate) do fields[key] = value end
end

local function integer(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(low, math.min(high, math.floor(value)))
end

local function clean(value, maximum)
    if type(value) ~= "string" then return "" end
    local name = value:gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local stop = math.min(#name, maximum)
    while stop < #name and stop > 0 do
        local nextByte = name:byte(stop + 1)
        if nextByte < 128 or nextByte >= 192 then break end
        stop = stop - 1
    end
    name = name:sub(1, stop):gsub("%s+$", "")
    return utf8 and not utf8.len(name) and "" or name
end

local function relayURL(value)
    if type(value) ~= "string" then return end
    value = value:match("^%s*(.-)%s*$"):gsub("/+$", "")
    if #value > 240 then return end
    local authority, path = value:match("^https://([^/]+)(.*)$")
    if not authority or not path:match("^[A-Za-z0-9/_%.%-~]*$") or path:find("%.%.") then return end
    local host, port = authority:match("^([A-Za-z0-9%.%-]+):(%d+)$")
    host = host or authority:match("^([A-Za-z0-9%.%-]+)$")
    if not host or not host:match("^[A-Za-z0-9].*[A-Za-z0-9]$") then return end
    if port and (tonumber(port) < 1 or tonumber(port) > 65535) then return end
    return value
end

function Clubs.teamChoices(stage)
    if stage == "professional" then return P.TeamUniform.teams end
    if stage == "college" then return P.SchoolTeams.college end
    return P.SchoolTeams.highSchool
end

local function teamFor(stage, id)
    for _, team in ipairs(Clubs.teamChoices(stage)) do
        if team.id == id then return id end
    end
end

local function profileID()
    -- A stable local identifier only. A relay must issue its own access token.
    return ("plx_%08x%08x%08x%08x"):format(math.random(0,0x7fffffff),
        math.random(0,0x7fffffff), math.random(0,0x7fffffff), math.random(0,0x7fffffff))
end

local function roomCode(value)
    if type(value) == "string" then
        local code = value:upper()
        if #code == 8 and code:match("^[A-Z0-9]+$") then return code end
    end
end

local function assignedClub(lobby)
    if type(lobby) ~= "table" or not P.Career.stages[lobby.stage] or not teamFor(lobby.stage, lobby.team) then return end
    local code = roomCode(lobby.code)
    local name = clean(lobby.name, Clubs.nameLimit)
    if code and name ~= "" then
        return {code=code, name=name, stage=lobby.stage, team=lobby.team, season=1}
    end
end

local function roomKey(relay, code)
    return relay and code and relay.."|"..code
end

local function restoreRoom(record)
    if type(record) ~= "table" then return end
    local relay, club = relayURL(record.relayURL), assignedClub(record.club)
    local session = record.session
    if not relay or not club or type(session) ~= "table" or roomCode(session.roomCode) ~= club.code
        or not P.ClubsNet or not P.ClubsNet.validSession(session) then return end
    return {relayURL=relay, club=club, host=record.host==true,
        session={roomCode=club.code, token=session.token, playerId=session.playerId}}
end

local function validID(value)
    return type(value) == "string" and #value == 36 and value:match("^plx_[0-9a-f]+$") ~= nil
end

local function restorePlayer(saved)
    local player = P.Career.new()
    player.development = {schema=1,points=36,accountedXP=0,accountedLegacy=0}
    if type(saved) ~= "table" then
        player.id = profileID()
        return player
    end

    local name = clean(saved.name, P.Athlete.nameLimit*2+1)
    if name ~= "" then player.name = name end
    player.id = validID(saved.id) and saved.id or profileID()
    player.position = integer(saved.position, player.position, 1, #P.Career.positions)
    player.attributes = P.Attributes.restore(saved.attributes, player.position)
    if P.Career.stages[saved.stage] then player.stage = saved.stage end
    player.team = teamFor(player.stage, saved.team) or Clubs.teamChoices(player.stage)[1].id
    player.season = integer(saved.season, 1, 1, 10000)
    for _, key in ipairs({"games","wins","losses","ties","xp","championships"}) do
        player[key] = integer(saved[key], 0, 0, 1000000)
    end
    player.spentXP = integer(saved.spentXP, 0, 0, player.xp)
    for _, key in ipairs({"appearance","development","entries","history","trophies","contract"}) do
        if type(saved[key]) == "table" then player[key] = copy(saved[key]) end
    end
    if type(saved.stats) == "table" then
        for key in pairs(player.stats) do
            local value = tonumber(saved.stats[key])
            if value and value == value and math.abs(value) < math.huge then player.stats[key] = value end
        end
    end
    return player
end

function Clubs.save(data)
    if not saveLocalData or not json or not json.encode then return false end
    local stored = {version=version, player=data.player, club=data.club, settings=data.settings,
        online=data.online, rooms=data.rooms, activeRooms=data.activeRooms}
    local encoded, raw = pcall(json.encode, stored)
    if not encoded or type(raw) ~= "string" then return false end
    local written, result = pcall(saveLocalData, saveKey, raw)
    return written and result ~= false
end

function Clubs.load()
    local saved
    if readLocalData and json and json.decode then
        local read, raw = pcall(readLocalData, saveKey)
        if read and type(raw) == "string" then
            local decoded, result = pcall(json.decode, raw)
            if decoded and type(result) == "table" and result.version == version then saved = result end
        end
    end

    local data = {version=version, player=restorePlayer(saved and saved.player), settings={},
        rooms={}, activeRooms={}}
    if saved and type(saved.online) == "table" then
        local online = saved.online
        data.online = {games=integer(online.games, 0, 0, 1000000),
            wins=integer(online.wins, 0, 0, 1000000), losses=integer(online.losses, 0, 0, 1000000),
            ties=integer(online.ties, 0, 0, 1000000),
            history=type(online.history) == "table" and copy(online.history) or {}}
    end
    if saved and type(saved.settings) == "table" then
        data.settings.relayURL = relayURL(saved.settings.relayURL)
    end
    local stored = saved and saved.club
    if type(stored) == "table" then
        local name = clean(stored.name, Clubs.nameLimit)
        local stage = P.Career.stages[stored.stage] and stored.stage
        local team = stage and teamFor(stage, stored.team)
        if name ~= "" and team then
            local season = integer(stored.season, 1, 1, 10000)
            data.club = {name=name, stage=stage, team=team, season=season}
            data.player.stage, data.player.team, data.player.season = stage, team, season
        end
    end
    if saved and type(saved.rooms) == "table" then
        for _, value in pairs(saved.rooms) do
            local room = restoreRoom(value)
            if room then data.rooms[roomKey(room.relayURL,room.club.code)] = room end
        end
    end
    if saved and type(saved.activeRooms) == "table" then
        for relay, code in pairs(saved.activeRooms) do
            if relayURL(relay) and roomCode(code) and data.rooms[roomKey(relay,code)] then
                data.activeRooms[relay] = code
            end
        end
    end
    local room = Clubs.savedRoom(data)
    if room then Clubs.joinedTeam(data,room.club) end
    if not saved or type(saved.player) ~= "table" or not validID(saved.player.id) then Clubs.save(data) end
    return data
end

function Clubs.setRelay(data, value)
    local url = relayURL(value)
    if not url and value ~= nil and (type(value) ~= "string" or value:find("%S")) then
        return false, "Enter an HTTPS relay address without a query or password"
    end
    local candidate = copy(data)
    candidate.settings.relayURL = url
    if not Clubs.save(candidate) then return false, "Could not save the relay address" end
    data.settings.relayURL = url
    local room = Clubs.savedRoom(data)
    Clubs.joinedTeam(data,room and room.club)
    return true
end

function Clubs.savePlayer(data, player)
    if player.id ~= data.player.id then return false end
    local club = data.club
    if club and (player.team ~= club.team or player.stage ~= club.stage or player.season ~= club.season) then
        return false
    end
    local candidate = {player=player, club=club, settings=data.settings, online=data.online,
        rooms=data.rooms, activeRooms=data.activeRooms}
    if not Clubs.save(candidate) then return false end
    replace(data.player, player)
    return true
end

local function placePlayer(data, club, stage, team)
    local player = copy(data.player)
    local season = club and club.season or player.season
    player.stage, player.team, player.season = stage, team, season
    local candidate = {player=player, club=club, settings=data.settings, online=data.online,
        rooms=data.rooms, activeRooms=data.activeRooms}
    if not Clubs.save(candidate) then return false, "Could not save the club" end
    data.club = club
    replace(data.player, player)
    return true
end

function Clubs.create(data, name, stage, team)
    name = clean(name, Clubs.nameLimit)
    if name == "" then return false, "Enter a club name" end
    if data.club then return false, "You already have a local club" end
    stage = stage or data.player.stage
    if not P.Career.stages[stage] then return false, "Choose a competition" end
    team = team or (stage == data.player.stage and data.player.team) or Clubs.teamChoices(stage)[1].id
    if not teamFor(stage, team) then return false, "Choose a team in this competition" end
    local club = {name=name, stage=stage, team=team, season=1}
    return placePlayer(data, club, stage, team)
end

function Clubs.setTeam(data, stage, team)
    if not P.Career.stages[stage] or not teamFor(stage, team) then
        return false, "Choose a team in this competition"
    end
    local club
    if data.club then
        local current = data.club
        local same = current.stage == stage and current.team == team
        club = {name=current.name, stage=stage, team=team, season=same and current.season or 1}
    end
    return placePlayer(data, club, stage, team)
end

function Clubs.activeClub(data)
    return data.joined or data.club
end

function Clubs.savedRoom(data, code)
    local relay = data.settings.relayURL
    local chosen = code and roomCode(code) or not code and data.activeRooms and data.activeRooms[relay]
    local key = roomKey(relay,chosen)
    return key and data.rooms and data.rooms[key] or nil
end

function Clubs.hostedRoom(data)
    local relay = data.settings.relayURL
    for _, room in pairs(data.rooms or {}) do
        if room.host and room.relayURL == relay then return room end
    end
end

function Clubs.storeRoom(data, session, lobby)
    local room = restoreRoom({relayURL=data.settings.relayURL, session=session, club=lobby,
        host=type(session)=="table" and type(lobby)=="table" and lobby.hostId==session.playerId})
    if not room then return false, "The relay did not return valid room credentials" end
    local assigned
    for _, member in ipairs(lobby.players or {}) do
        if member.id == session.playerId and type(member.profile) == "table" and member.profile.id == data.player.id then
            assigned = member
            break
        end
    end
    if not assigned then return false, "This Clubs room is assigned to another athlete" end
    local previous = Clubs.savedRoom(data,room.club.code)
    local active = data.activeRooms and data.activeRooms[room.relayURL]
    if previous and previous.session.token == session.token and previous.session.playerId == session.playerId
        and previous.host == room.host and previous.club.name == room.club.name
        and previous.club.team == room.club.team and previous.club.stage == room.club.stage
        and active == room.club.code then return true end

    local candidate = copy(data)
    candidate.rooms, candidate.activeRooms = candidate.rooms or {}, candidate.activeRooms or {}
    candidate.rooms[roomKey(room.relayURL,room.club.code)] = room
    candidate.activeRooms[room.relayURL] = room.club.code
    if not Clubs.save(candidate) then return false, "Could not save this club's room credentials" end
    data.rooms, data.activeRooms = candidate.rooms,candidate.activeRooms
    return true
end

function Clubs.forgetRoom(data, code)
    local room = Clubs.savedRoom(data,code)
    if not room then return true end
    local candidate = copy(data)
    candidate.rooms[roomKey(room.relayURL,room.club.code)] = nil
    if candidate.activeRooms[room.relayURL] == room.club.code then candidate.activeRooms[room.relayURL] = nil end
    if not Clubs.save(candidate) then return false,"Could not remove the expired room session" end
    data.rooms, data.activeRooms = candidate.rooms,candidate.activeRooms
    if data.joined and data.joined.code==room.club.code then Clubs.joinedTeam(data,nil) end
    return true
end

function Clubs.joinedTeam(data, lobby)
    if lobby == nil then data.joined = nil return true end
    local remote = assignedClub(lobby)
    if not remote then return false, "The relay returned an invalid team" end
    local localClub = data.club
    if localClub and localClub.stage == remote.stage and localClub.team == remote.team then
        remote.season = localClub.season
    end
    -- Joining changes the displayed club. Keep the saved club and athlete intact.
    data.joined = remote
    return true
end

function Clubs.schedule(data)
    local club = Clubs.activeClub(data)
    if not club then return {} end
    -- Preview the league's real fixture ordering with a Club-only season seed.
    return P.CareerSeason.schedule({stage=club.stage, team=club.team, season=club.season, entries={}})
end

local function statValue(key, value)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
    if key == "screenCoachPoints" then return math.max(-1000, math.min(1000, value)) end
    value = math.max(0, math.min(1000, value))
    if key == "minutesPlayed" or key == "penaltyMinutes" then return value end
    if key == "gamesPlayed" or key == "gamesStarted" then return math.min(1, math.floor(value)) end
    return math.floor(value)
end

local function onlineRecord(result, remote, matchId, stats, earned)
    local opponent = result.opponent
    if not teamFor(remote.stage, opponent) then
        local school = P.SchoolTeams.get(opponent)
        if not school or P.League.profile(remote.stage, opponent).id ~= P.League.profile(remote.stage, remote.team).id then
            opponent = nil
        end
    end
    return {id=matchId, label="Clubs match", code=remote.code, name=remote.name, stage=remote.stage,
        team=remote.team, opponentId=opponent, opponent=opponent and P.TeamUniform.get(opponent).name or "Opponent", home=true,
        homeScore=result.homeScore, awayScore=result.awayScore, result=string.format("%d–%d",result.homeScore,result.awayScore),
        xp=earned, stats=stats}
end

function Clubs.results(data)
    local played = data.online and data.online.history or {}
    local results = {}
    for index=#played,1,-1 do results[#results+1] = played[index] end
    return results
end

-- Invoke only with the authenticated final returned by the relay. A repeated
-- result is acknowledged without changing the player, wallet, or record.
function Clubs.recordOnline(data, lobby, result, memberId)
    local remote = assignedClub(lobby)
    if not remote or type(result) ~= "table" then
        return false, "No completed Clubs match"
    end
    local id = result.matchId
    local final = lobby.phase=="final" and id==lobby.matchId or result==lobby.lastResult
    if not final or type(id) ~= "string" or #id > 72 or not id:match("^[A-Za-z0-9_%-]+$") then
        return false, "The result does not match this room"
    end
    local player = data.player
    local member
    if type(memberId) ~= "string" or type(lobby.players) ~= "table" then return false, "Missing Clubs player" end
    for _, row in ipairs(lobby.players) do
        if type(row) == "table" and row.id == memberId and type(row.profile) == "table"
            and row.profile.id == player.id then member = row break end
    end
    if not member then return false, "The result is for another player" end
    local key = "club:"..id
    if player.entries[key] then return true, nil, false end
    local score, opposing = result.homeScore, result.awayScore
    if type(score) ~= "number" or type(opposing) ~= "number" or score % 1 ~= 0 or opposing % 1 ~= 0
        or score < 0 or opposing < 0 or score > 999 or opposing > 999 then
        return false, "The relay returned an invalid score"
    end
    local actual = type(result.stats) == "table" and result.stats[memberId]
    if type(actual) ~= "table" then return false, "Your athlete's statistics are missing" end

    local candidate = copy(data)
    local updated = candidate.player
    local personal = {screenCoachPoints=statValue("screenCoachPoints", actual.screenCoachPoints)}
    for _, stat in ipairs(P.Career.statKeys) do personal[stat] = statValue(stat, actual[stat]) end
    for stat, value in pairs(personal) do updated.stats[stat] = (updated.stats[stat] or 0) + value end
    local bucket = score > opposing and "wins" or score < opposing and "losses" or "ties"
    updated.games, updated[bucket] = updated.games + 1, updated[bucket] + 1
    local earned = 20 + (bucket == "wins" and 10 or 0) + personal.goals * 6 + personal.assists * 5
        + personal.saves * 3 + personal.faceoffs * 4 + personal.groundBalls * 2
        + personal.causedTurnovers * 4 + personal.interceptions * 3
    updated.xp = updated.xp + earned
    P.Development.onMatch(updated, {id=key}, personal, {phase="FINAL",homeScore=score,awayScore=opposing})
    local record = onlineRecord(result, remote, id, personal, earned)
    updated.entries[key] = {home=score, away=opposing, opponent=record.opponentId, stats=personal, xp=earned}
    local online = candidate.online or {games=0,wins=0,losses=0,ties=0,history={}}
    online.games, online[bucket] = online.games + 1, online[bucket] + 1
    online.history[#online.history+1] = record
    candidate.online = online
    if not Clubs.save(candidate) then return false, "Could not save the match result" end
    replace(player, updated)
    data.online = online
    return true, nil, true
end

function Clubs.roster(data)
    if not data.club then return {} end
    local player = data.player
    local position = P.Career.positions[player.position]
    local jersey = P.Athlete.profile(player).NUMBER - 1
    local roster, used = {}, {[jersey]=true}
    local labels = {A="Attack", M="Midfield", D="Defense", G="Goalie"}
    for slot, member in ipairs(P.League.roster(data.club.team)) do
        if slot == position.slot then
            roster[slot] = {slot=slot, id=player.id, name=P.Athlete.name(player),
                position=position.label, number=jersey, kind="local"}
        else
            local number = member.number
            while used[number] do number = (number + 1) % 100 end
            used[number] = true
            roster[slot] = {slot=slot, id=member.playerId, name=member.name, number=number,
                position=member.specialty == "FOGO" and "Faceoff" or labels[member.role], kind="ai"}
        end
    end
    return roster
end
