-- PolyLax Clubs relay client for Codea's asynchronous http.request API.
PolyLax = PolyLax or {}
local Net = {}
PolyLax.ClubsNet = Net

local requestTimeout, maxBackoff = 8, 8
local matchPoll, lobbyPoll = .15, .65
local maxActions, actionsPerRequest = 24, 8
local maxBody, maxReply = 64 * 1024, 1024 * 1024

local function trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

function Net.validURL(value, allowLoopback)
    local url = trim(value):gsub("/+$", "")
    if #url == 0 then return nil, "Set a Clubs relay URL in Settings." end
    local scheme, authority, path = url:match("^(https?)://([^/]+)(.*)$")
    if not scheme or #url > 240 or path:find("[^%w_./~%-]") or path:find("%.%.") then
        return nil, "Enter a valid HTTPS relay URL."
    end
    local host, port = authority:match("^([%w.%-]+):(%d+)$")
    if not host then host = authority:match("^([%w.%-]+)$") end
    if not host or port and (tonumber(port) < 1 or tonumber(port) > 65535) then
        return nil, "Enter a valid HTTPS relay URL."
    end
    if scheme ~= "https" and not (allowLoopback and (host == "127.0.0.1" or host == "localhost")) then
        return nil, "Online Clubs requires HTTPS."
    end
    return url
end

local function validSession(session)
    return type(session) == "table" and type(session.token) == "string"
        and #session.token >= 16 and #session.token <= 256 and session.token:match("^[%w_%-]+$")
        and type(session.playerId) == "string" and #session.playerId > 0
        and type(session.roomCode) == "string" and #session.roomCode > 0
end

function Net.new(url, options)
    options = options or {}
    local relay, problem = Net.validURL(url, options.allowLoopback)
    local codec = options.json or json
    local transport = options.transport or (http and http.request)
    if relay and (type(transport) ~= "function" or not codec
        or type(codec.encode) ~= "function" or type(codec.decode) ~= "function") then
        relay, problem = nil, "Codea HTTP or JSON is unavailable in this runtime."
    end
    return {url=relay, status=relay and "idle" or "unavailable", error=problem,
        request=transport, codec=codec, clock=0, nextPoll=0, retry=0,
        actions={}, inputs={}, inputSeq=0, after=0, change=0}
end

function Net.isHost(connection)
    return connection.session ~= nil and connection.lobby ~= nil
        and connection.lobby.hostId == connection.session.playerId
end

local function resetMatch(connection)
    connection.snapshot, connection.pendingInput, connection.localInput = nil, nil, nil
    connection.refreshLobby = nil
    connection.inputSeq, connection.after = 0, 0
    connection.actions, connection.inputs = {}, {}
end

local function clearSession(connection)
    connection.session, connection.lobby, connection.command = nil, nil, nil
    resetMatch(connection)
end

local function changed(connection, operation)
    connection.lastOperation = operation
    connection.change = connection.change + 1
end

local function updateReply(connection, operation, reply, sent)
    local lobby = reply.lobby
    if operation == "leave" then
        clearSession(connection)
    elseif type(lobby) == "table" and type(lobby.players) == "table"
        and type(lobby.code) == "string" and type(lobby.phase) == "string" then
        if lobby.matchId ~= (connection.lobby and connection.lobby.matchId) then resetMatch(connection) end
        connection.lobby = lobby
        if validSession(reply.session) then connection.session = reply.session end
    else
        return false
    end
    if operation ~= "leave" and not connection.session then return false end
    if type(reply.inputSeq) == "number" then
        connection.inputSeq = math.max(connection.inputSeq, reply.inputSeq)
    end
    local snapshot = reply.snapshot
    if type(snapshot) == "table" and type(snapshot.seq) == "number"
        and (not connection.snapshot or snapshot.seq > connection.snapshot.seq) then
        connection.snapshot = snapshot
    end
    if connection.pendingInput and sent.input == connection.pendingInput then
        connection.pendingInput = nil
    end
    if type(reply.inputs) == "table" then
        for _, event in ipairs(reply.inputs) do
            if type(event) == "table" and type(event.id) == "number" and event.id > connection.after then
                connection.after = event.id
                connection.inputs[#connection.inputs+1] = event
            end
        end
    end
    return true
end

local function retryLater(connection, transaction, message)
    if connection.inFlight ~= transaction then return end
    connection.inFlight, connection.busy = nil, false
    connection.retry = math.min(maxBackoff, math.max(.5, connection.retry * 2))
    connection.nextPoll = connection.clock + connection.retry
    connection.status = connection.session and "reconnecting" or "idle"
    connection.error = message
    changed(connection, transaction.operation)
end

local function request(connection, operation, payload)
    local ok, body = true, "{}"
    if next(payload) then ok, body = pcall(connection.codec.encode, payload) end
    if not ok or type(body) ~= "string" or #body > maxBody then
        connection.error = "Could not encode this Clubs request."
        connection.nextPoll = connection.clock + lobbyPoll
        return false, connection.error
    end
    local transaction = {operation=operation, deadline=connection.clock + requestTimeout}
    connection.inFlight, connection.busy = transaction, true
    if not connection.lobby then connection.status = "connecting" end
    local headers = {["Content-Type"]="application/json", Accept="application/json"}
    if connection.session then headers.Authorization = "Bearer "..connection.session.token end

    local function success(raw, status)
        if connection.inFlight ~= transaction then return end
        if type(status) ~= "number" or status >= 500 or status == 429 then
            retryLater(connection, transaction, "The Clubs relay is temporarily unavailable.")
            return
        end
        local decoded, reply = false, nil
        if type(raw) == "string" and #raw <= maxReply then
            decoded, reply = pcall(connection.codec.decode, raw)
        end
        if not decoded or type(reply) ~= "table" then
            retryLater(connection, transaction, "The relay returned an unreadable response.")
            return
        end
        connection.inFlight, connection.busy = nil, false
        if status < 200 or status >= 300 then
            if status == 401 then clearSession(connection) end
            if operation == "sync" then
                connection.pendingInput = nil
                -- A playing client may still have input in flight when the
                -- host finishes. Fetch the new phase without stale match data.
                connection.refreshLobby = status == 409 and payload.input ~= nil
            end
            local message = type(reply.message) == "string" and reply.message
                or type(reply.error) == "string" and reply.error or "The relay declined this request."
            connection.error = message:gsub("%c", " "):sub(1, 140)
            connection.status = connection.lobby and "connected" or "idle"
            connection.nextPoll = connection.clock + (connection.refreshLobby and 0 or lobbyPoll)
        elseif not updateReply(connection, operation, reply, payload) then
            connection.error = "The relay response is incomplete."
            connection.status = connection.session and "reconnecting" or "idle"
            connection.nextPoll = connection.clock + lobbyPoll
        else
            connection.error, connection.retry = nil, 0
            connection.status = connection.lobby and "connected" or "idle"
            local interval = connection.lobby and connection.lobby.phase == "match" and matchPoll or lobbyPoll
            connection.nextPoll = connection.clock + interval
        end
        changed(connection, operation)
    end

    local function failed()
        retryLater(connection, transaction, "Could not reach the Clubs relay.")
    end
    local sent = pcall(connection.request, connection.url.."/v1/"..operation, success, failed,
        {method="POST", headers=headers, data=body})
    if not sent then failed() end
    return sent
end

local function command(connection, operation, payload, authenticated)
    if not connection.url then return false, connection.error end
    if authenticated and not validSession(connection.session) then return false, "Join a room first." end
    if connection.command then return false, "Wait for the current request." end
    if connection.inFlight then
        if connection.inFlight.operation ~= "sync" then return false, "Wait for the current request." end
        connection.command = {operation=operation, payload=payload}
        return true
    end
    return request(connection, operation, payload)
end

function Net.create(connection, club, profile)
    if connection.session then return false, "Leave your current room first." end
    if type(club) ~= "table" or type(profile) ~= "table" then return false, "Create a club and a player first." end
    return command(connection, "create", {name=club.name, team=club.team, stage=club.stage, profile=profile})
end

function Net.join(connection, roomCode, profile)
    if connection.session then return false, "Leave your current room first." end
    local code = trim(roomCode):upper()
    if not code:match("^%w+$") or #code > 16 then return false, "Enter the invitation code." end
    if type(profile) ~= "table" then return false, "Create a Clubs player first." end
    return command(connection, "join", {roomCode=code, profile=profile})
end

function Net.resume(connection, session)
    if not connection.url then return false, connection.error end
    if not validSession(session) then return false, "No saved Clubs room." end
    if connection.inFlight or connection.command then return false, "Wait for the current request." end
    if not connection.session or session.token ~= connection.session.token then clearSession(connection) end
    connection.session = {token=session.token, playerId=session.playerId, roomCode=session.roomCode}
    return command(connection, "resume", {}, true)
end

function Net.ready(connection, ready)
    return command(connection, "ready", {ready=ready == true}, true)
end

function Net.start(connection)
    return command(connection, "start", {}, true)
end

function Net.leave(connection)
    return command(connection, "leave", {}, true)
end

function Net.finish(connection, result)
    if type(result) ~= "table" then return false, "A final score is required." end
    return command(connection, "finish", {result=result}, true)
end

function Net.disconnect(connection)
    connection.inFlight, connection.busy = nil, false
    connection.status = connection.url and "idle" or "unavailable"
    clearSession(connection)
    changed(connection, "disconnect")
end

local function axis(value)
    return type(value) == "number" and value == value and math.max(-1, math.min(1, value)) or 0
end

function Net.queueAction(connection, action)
    if type(action) ~= "table" or #connection.actions >= maxActions then return false end
    connection.actions[#connection.actions+1] = action
    return true
end

function Net.takeInputs(connection)
    local inputs = connection.inputs
    connection.inputs = {}
    return inputs
end

local function buildInput(connection)
    if not connection.localInput then return end
    if connection.pendingInput then return connection.pendingInput end
    connection.inputSeq = connection.inputSeq + 1
    local control = connection.localInput
    local pending = {seq=connection.inputSeq, x=control.x, z=control.z, sprint=control.sprint}
    if #connection.actions > 0 then
        pending.actions = {}
        for _ = 1, math.min(actionsPerRequest, #connection.actions) do
            pending.actions[#pending.actions+1] = table.remove(connection.actions, 1)
        end
    end
    connection.pendingInput = pending
    return pending
end

-- Pass one frame of controls to tick. `actions` holds only new events from
-- that frame, and movement is sampled at the request rate for guests.
function Net.tick(connection, dt, exchange)
    if not connection.url then return end
    connection.clock = connection.clock + math.max(dt or 0, 0)
    exchange = exchange or {}
    local control = exchange.input
    local playing = connection.lobby and connection.lobby.phase == "match"
    if playing and not Net.isHost(connection) then
        if control then
            connection.localInput = {x=axis(control.x), z=axis(control.z), sprint=control.sprint == true}
            for _, action in ipairs(control.actions or {}) do Net.queueAction(connection, action) end
        else
            connection.localInput = {x=0, z=0, sprint=false}
        end
    end
    local transaction = connection.inFlight
    if transaction and connection.clock >= transaction.deadline then
        retryLater(connection, transaction, "The Clubs request timed out.")
    end
    if connection.inFlight then return end
    local pending = connection.command
    if pending then
        connection.command = nil
        if connection.session then request(connection, pending.operation, pending.payload) end
    elseif connection.session and connection.clock >= connection.nextPoll then
        local payload = {}
        if Net.isHost(connection) then
            payload.after = connection.after
            if playing then payload.snapshot = exchange.snapshot end
        elseif playing and not connection.refreshLobby then
            payload.input = buildInput(connection)
        end
        connection.refreshLobby = nil
        request(connection, "sync", payload)
    end
end
