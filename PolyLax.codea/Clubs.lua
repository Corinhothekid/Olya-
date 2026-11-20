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
    if #value > 256 then return end
    local authority, path = value:match("^https://([^/]+)(.*)$")
    if not authority or not path:match("^[A-Za-z0-9/_%.%-~]*$") then return end
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
    local encoded, raw = pcall(json.encode, data)
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

    local data = {version=version, player=restorePlayer(saved and saved.player), settings={}}
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
    return true
end

function Clubs.savePlayer(data, player)
    if player.id ~= data.player.id then return false end
    local club = data.club
    if club and (player.team ~= club.team or player.stage ~= club.stage or player.season ~= club.season) then
        return false
    end
    local candidate = {version=version, player=player, club=club, settings=data.settings}
    if not Clubs.save(candidate) then return false end
    replace(data.player, player)
    return true
end

local function placePlayer(data, club, stage, team)
    local player = copy(data.player)
    local season = club and club.season or player.season
    player.stage, player.team, player.season = stage, team, season
    local candidate = {version=version, player=player, club=club, settings=data.settings}
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

function Clubs.schedule(data)
    if not data.club then return {} end
    local club = data.club
    -- Preview the league's real fixture ordering with a Club-only season seed.
    return P.CareerSeason.schedule({stage=club.stage, team=club.team, season=club.season, entries={}})
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
