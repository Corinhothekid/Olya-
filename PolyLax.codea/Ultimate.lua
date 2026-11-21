-- PolyLax Ultimate | local collection, squad, and profile persistence
PolyLax = PolyLax or {}
local Ultimate = {}
PolyLax.Ultimate = Ultimate

local Catalog = assert(PolyLax.UltimateCatalog, "Load UltimateCatalog before Ultimate")
Ultimate.version = 3
Ultimate.players = Catalog.players
Ultimate.researchCandidates = Catalog.researchCandidates
Ultimate.realPlayers = Catalog.realPlayers
Ultimate.kits = Catalog.kits
Ultimate.sources = Catalog.sources
Ultimate.releasePolicy = Catalog.releasePolicy
Ultimate.disclaimer = Catalog.disclaimer
Ultimate.slotRoles = {"A","A","A","M","M","M","D","D","D","G"}

-- Only enable in a private source build. It uses a separate save from public builds.
local developerBuild = false
local storageKey = "PolyLax.Ultimate.Collection.3" .. (developerBuild and ".Dev" or "")
local legacyKeys = {"PolyLax.Ultimate.Collection.2", "PolyLax.Ultimate.Collection"}
local maxHistory = 20

function Ultimate.isDeveloperBuild()
    return developerBuild
end

function Ultimate.catalog(league, includeResearch)
    local source = includeResearch and Ultimate.researchCandidates or Ultimate.players
    local results = {}
    for _, player in ipairs(source or {}) do
        if not league or player.league == league then results[#results+1] = player end
    end
    return results
end

function Ultimate.find(id)
    return Catalog.find(id)
end

function Ultimate.kit(id)
    return Catalog.kit(id)
end

function Ultimate.displayName(player)
    return player and (player.displayName or player.name) or "Unknown player"
end

function Ultimate.role(player)
    if not player then return nil end
    local position = player.position or player.role
    if position == "F" then return "A" end
    if position == "T" or position == "FO" or position == "FACEOFF" or position == "LSM" or position == "SSDM" then
        return "M"
    end
    return position
end

function Ultimate.defaultCollection()
    return {
        version=Ultimate.version,
        cards={}, nextCardId=1, squad={}, equippedKit="field_violet",
        coins=0, unopenedPacks=0, completedSBC={}, starterGranted=false,
        matches=0, wins=0, draws=0, losses=0, nextMatchId=1, matchHistory={},
        testGoldGranted=false
    }
end

local function nonnegativeInt(value)
    local n = tonumber(value)
    if not n or n ~= n or n < 0 or n >= 9007199254740991 then return 0 end
    return math.floor(n)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function addInstance(collection, id)
    local uid = "card-" .. tostring(collection.nextCardId)
    collection.cards[uid] = id
    collection.nextCardId = collection.nextCardId + 1
    return uid
end

-- Raw inventory operations are used inside Ultimate.transact.
function Ultimate.addCard(collection, id)
    if not Ultimate.find(id) then return false, "Unknown player" end
    return true, addInstance(collection, id)
end

function Ultimate.resolveCard(collection, uid)
    if type(uid) ~= "string" then return nil end
    return Ultimate.find(collection.cards[uid])
end

function Ultimate.ownedCards(collection)
    local cards = {}
    for uid, id in pairs(collection.cards) do
        local player = Ultimate.find(id)
        if player then cards[#cards+1] = {uid=uid, id=id, player=player} end
    end
    table.sort(cards, function(a, b)
        if a.id == b.id then return a.uid < b.uid end
        return a.id < b.id
    end)
    return cards
end

function Ultimate.removeCard(collection, uid)
    if not Ultimate.resolveCard(collection, uid) then return false, "Card not owned" end
    collection.cards[uid] = nil
    for slot, equipped in pairs(collection.squad) do
        if equipped == uid then collection.squad[slot] = nil end
    end
    return true
end

local function restoreCards(collection, raw)
    local firstCopy = {}
    if type(raw.cards) == "table" then
        collection.nextCardId = math.max(1, nonnegativeInt(raw.nextCardId))
        for uid, id in pairs(raw.cards) do
            local sequence = type(uid) == "string" and uid:match("^card%-(%d+)$")
            if sequence and type(id) == "string" then
                collection.cards[uid] = id
                collection.nextCardId = math.max(collection.nextCardId, nonnegativeInt(sequence) + 1)
            end
        end
    elseif type(raw.owned) == "table" then
        local ids = {}
        for id in pairs(raw.owned) do
            if type(id) == "string" then ids[#ids+1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            -- The previous research build represented each player by an ID and quantity.
            -- Keep IDs even if a catalog update temporarily removes a card.
            for _ = 1, nonnegativeInt(raw.owned[id]) do
                local uid = addInstance(collection, id)
                firstCopy[id] = firstCopy[id] or uid
            end
        end
    end
    if type(raw.squad) ~= "table" then return end
    local seen = {}
    for slot, role in ipairs(Ultimate.slotRoles) do
        local saved = raw.squad[tostring(slot)] or raw.squad[slot]
        local uid = firstCopy[saved] or saved
        local player = Ultimate.resolveCard(collection, uid)
        if player and Ultimate.role(player) == role and not seen[player.id] then
            collection.squad[slot] = uid
            seen[player.id] = true
        end
    end
end

local function restoreMatches(collection, raw)
    collection.matches = math.max(collection.matches, collection.wins + collection.draws + collection.losses)
    local nextMatchId = math.max(1, nonnegativeInt(raw.nextMatchId))
    local activeMatch = nonnegativeInt(raw.activeMatch)
    local seen = {}
    if type(raw.matchHistory) == "table" then
        for index = math.max(1, #raw.matchHistory - maxHistory + 1), #raw.matchHistory do
            local entry = raw.matchHistory[index]
            if type(entry) == "table" then
                local id = nonnegativeInt(entry.id)
                local result = entry.result
                if id > 0 and not seen[id] and (result == "win" or result == "draw" or result == "loss") then
                    collection.matchHistory[#collection.matchHistory+1] = {
                        id=id, result=result, payout=nonnegativeInt(entry.payout),
                        ownScore=entry.ownScore and nonnegativeInt(entry.ownScore),
                        opponentScore=entry.opponentScore and nonnegativeInt(entry.opponentScore)
                    }
                    nextMatchId = math.max(nextMatchId, id+1)
                    seen[id] = true
                end
            end
        end
    end
    if activeMatch > 0 and not seen[activeMatch] then
        collection.activeMatch = activeMatch
        nextMatchId = math.max(nextMatchId, activeMatch+1)
    end
    collection.nextMatchId = nextMatchId
end

local function restore(raw)
    local collection = Ultimate.defaultCollection()
    for _, key in ipairs({"coins","unopenedPacks","matches","wins","draws","losses"}) do
        collection[key] = nonnegativeInt(raw[key])
    end
    collection.starterGranted = raw.starterGranted == true
    collection.testGoldGranted = raw.testGoldGranted == true
    if Ultimate.kit(raw.equippedKit) then collection.equippedKit = raw.equippedKit end
    if type(raw.completedSBC) == "table" then
        for id, complete in pairs(raw.completedSBC) do
            if type(id) == "string" and complete == true then collection.completedSBC[id] = true end
        end
    end
    restoreCards(collection, raw)
    restoreMatches(collection, raw)
    return collection
end

local function readCollection(key)
    local read, raw = pcall(readLocalData, key)
    if not read then return nil, "Could not read the Ultimate Team save" end
    if raw == nil then return nil end
    local decoded, data = pcall(function() return json.decode(raw) end)
    if not decoded or type(data) ~= "table" then
        return nil, "Ultimate Team save could not be opened"
    end
    local version = data.version == nil and 2 or tonumber(data.version)
    if not version or version % 1 ~= 0 or version < 2 or version > Ultimate.version then
        return nil, "Ultimate Team save could not be opened"
    end
    return restore(data)
end

function Ultimate.load()
    local collection, err = readCollection(storageKey)
    if not collection and not err and not developerBuild then
        for _, key in ipairs(legacyKeys) do
            collection, err = readCollection(key)
            if collection or err then break end
        end
    end
    if collection then return collection end
    collection = Ultimate.defaultCollection()
    -- Leave an unreadable save intact. Purchases and awards remain blocked until it can be loaded.
    collection.loadError = err
    return collection
end

function Ultimate.save(collection)
    if collection.loadError then return false, collection.loadError end
    local snapshot = copy(collection)
    -- A squad with open slots is a dictionary, not a JSON array with holes.
    snapshot.squad = {}
    for slot, uid in pairs(collection.squad) do snapshot.squad[tostring(slot)] = uid end
    local encoded, raw = pcall(function() return json.encode(snapshot) end)
    if not encoded or type(raw) ~= "string" then return false, "Could not encode the Ultimate Team save" end
    local written, result = pcall(saveLocalData, storageKey, raw)
    if not written or result == false then return false, "Could not save Ultimate Team" end
    return true
end

function Ultimate.transact(collection, change)
    if collection.loadError then return false, collection.loadError end
    local draft = copy(collection)
    local ok, result = change(draft)
    if not ok then return false, result end
    local saved, err = Ultimate.save(draft)
    if not saved then return false, err end
    for key in pairs(collection) do collection[key] = nil end
    for key, value in pairs(draft) do collection[key] = value end
    return true, result
end

function Ultimate.equip(collection, slot, uid)
    if not Ultimate.slotRoles[slot] then return false, "Invalid slot" end
    local player = Ultimate.resolveCard(collection, uid)
    if not player then return false, "Card not owned" end
    if Ultimate.role(player) ~= Ultimate.slotRoles[slot] then return false, "Wrong position" end
    for otherSlot, otherUid in pairs(collection.squad) do
        local other = Ultimate.resolveCard(collection, otherUid)
        if otherSlot ~= slot and other and player.id == other.id then return false, "Already in squad" end
    end
    return Ultimate.transact(collection, function(draft)
        draft.squad[slot] = uid
        return true
    end)
end

function Ultimate.unequip(collection, slot)
    if not Ultimate.slotRoles[slot] then return false, "Invalid slot" end
    return Ultimate.transact(collection, function(draft)
        draft.squad[slot] = nil
        return true
    end)
end

function Ultimate.equipKit(collection, id)
    if not Ultimate.kit(id) then return false, "Unknown jersey" end
    return Ultimate.transact(collection, function(draft)
        draft.equippedKit = id
        return true
    end)
end

