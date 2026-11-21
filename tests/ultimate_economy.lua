-- From the repo root: lua tests/ultimate_economy.lua [PolyLax.codea]
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local storage, snapshots = {}, {}
local failSave = false

local function copy(value)
    if type(value) ~= "table" then return value end
    local clone = {}
    for key, item in pairs(value) do clone[key] = copy(item) end
    return clone
end

function readLocalData(key) return storage[key] end
function saveLocalData(key, raw)
    if failSave then return false end
    storage[key] = raw
end
json = {
    encode=function(data)
        snapshots[#snapshots+1] = copy(data)
        return tostring(#snapshots)
    end,
    decode=function(raw) return copy(snapshots[tonumber(raw)]) end
}
local function loadUltimate(development)
    PolyLax = nil
    dofile(project.."/UltimateCatalog.lua")
    if development then
        local sourceFile = assert(io.open(project.."/Ultimate.lua"))
        local source, matched = sourceFile:read("*a"):gsub("local developerBuild = false", "local developerBuild = true", 1)
        sourceFile:close()
        assert(matched == 1)
        assert(load(source))()
    else
        dofile(project.."/Ultimate.lua")
    end
    dofile(project.."/UltimateEconomy.lua")
    return PolyLax.Ultimate, PolyLax.Ultimate.Economy
end

local key = "PolyLax.Ultimate.Collection.3"
local U, E = loadUltimate(false)
local collection = U.load()
assert(not collection.loadError and #U.ownedCards(collection) == 0 and collection.coins == 0)

local function maxRoll(_, maximum) return maximum end
failSave = true
assert(not E.grantStarter(collection, maxRoll))
assert(#U.ownedCards(collection) == 0 and not collection.starterGranted and not storage[key])
failSave = false
local opened, starter = E.grantStarter(collection, maxRoll)
assert(opened and #starter == 5 and starter[5].rating >= 85)
local ownedUids = {}
for index, card in ipairs(starter) do
    assert(U.resolveCard(collection, card.uid).id == card.id)
    assert(not ownedUids[card.uid])
    ownedUids[card.uid] = true
    assert(index == 5 or card.rating < 85)
end
collection = U.load()
assert(#U.ownedCards(collection) == 5 and not E.grantStarter(collection, maxRoll))
assert(not E.spin(collection) and not E.buyPack(collection) and not E.openPack(collection))

-- Exercise all normal tier rolls exactly once, in addition to wheel charges and persistence.
assert(U.transact(collection, function(draft)
    draft.coins = 100 * E.wheelCost + E.packCost
    return true
end))
local counts = {elite=0,high=0,core=0}
for roll = 1, 100 do
    local nextRoll = roll
    local spun, card = E.spin(collection, function(_, maximum)
        local value = nextRoll or 1
        assert(value <= maximum)
        nextRoll = nil
        return value
    end)
    assert(spun and card and not ownedUids[card.uid])
    ownedUids[card.uid] = true
    counts[card.tier] = counts[card.tier]+1
end
assert(counts.elite == 20 and counts.high == 35 and counts.core == 45)
collection = U.load()
assert(#U.ownedCards(collection) == 105 and collection.coins == E.packCost)
local originalPool = U.players
U.players = {U.find("pll_sowers_2026")}
assert(not E.spin(collection) and not E.buyPack(collection) and collection.coins == E.packCost)
U.players = originalPool

failSave = true
assert(not E.spin(collection) and not E.buyPack(collection) and collection.coins == E.packCost)
assert(collection.unopenedPacks == 0 and #U.ownedCards(collection) == 105)
failSave = false
assert(E.buyPack(collection) and collection.coins == 0 and collection.unopenedPacks == 1)
assert(U.load().unopenedPacks == 1)
failSave = true
assert(not E.openPack(collection, maxRoll) and #U.ownedCards(collection) == 105 and collection.unopenedPacks == 1)
failSave = false
local redeemed, standard = E.openPack(collection, maxRoll)
assert(redeemed and #standard == 5 and standard[5].rating < 85)
assert(#U.ownedCards(U.load()) == 110 and U.load().unopenedPacks == 0)

-- Results need a persisted live match, genuine scores, and a one-time active ID.
assert(not E.recordMatch(collection, "win", 123, 2, 1))
local started, abandoned = E.beginMatch(collection)
assert(started)
local began, current = E.beginMatch(collection)
assert(began and current > abandoned)
collection = U.load()
assert(not E.recordMatch(collection, "win", abandoned, 2, 1))
assert(not E.recordMatch(collection, "win", current, 1, 2))
failSave = true
assert(not E.recordMatch(collection, "win", current, 2, 1))
assert(collection.activeMatch == current and collection.coins == 0)
failSave = false
local paid, reward = E.recordMatch(collection, "win", current, 2, 1)
assert(paid and reward.payout == 450 and reward.ownScore == 2 and reward.opponentScore == 1)
collection = U.load()
assert(not E.recordMatch(collection, "win", current, 2, 1))
for _, outcome in ipairs({{"draw",0,0,250},{"loss",1,3,150}}) do
    local ok, id = E.beginMatch(collection)
    assert(ok)
    local scored, record = E.recordMatch(collection, outcome[1], id, outcome[2], outcome[3])
    assert(scored and record.payout == outcome[4])
end
collection = U.load()
assert(collection.coins == 850 and collection.matches == 3 and #collection.matchHistory == 3)
assert(collection.wins == 1 and collection.draws == 1 and collection.losses == 1)

-- A compile-time private build unlocks its own independent one-time developer grant.
U.devMode = true
assert(not E.canGrantTestGold(collection) and not E.grantTestGold(collection))
U,E = loadUltimate(true)
local dev = U.load()
assert(dev.coins == 0 and E.canGrantTestGold(dev))
assert(E.grantTestGold(dev) and dev.coins == 1000000)
assert(not E.grantTestGold(dev) and not E.canGrantTestGold(dev))
assert(not E.canGrantTestGold(U.load()))
U,E = loadUltimate(false)
assert(U.load().coins == 850 and not E.grantTestGold(U.load()))

-- Migrate counts to unique instances and retain saved kit, squad, balance, and starter state.
storage[key] = nil
storage["PolyLax.Ultimate.Collection.2"] = json.encode({
    version=2, owned={pll_sowers_2026=2, pll_carroll_2026=1},
    squad={["1"]="pll_sowers_2026",["4"]="pll_carroll_2026"},
    coins=123, equippedKit="box_ice", unopenedPacks=1, starterGranted=true, matches=4, wins=2
})
collection = U.load()
assert(#U.ownedCards(collection) == 3 and collection.coins == 123 and collection.unopenedPacks == 1)
assert(collection.starterGranted and not E.grantStarter(collection))
assert(collection.matches == 4 and collection.wins == 2 and collection.losses == 0)
assert(collection.equippedKit == "box_ice" and U.resolveCard(collection, collection.squad[4]).id == "pll_carroll_2026")
local attack = collection.squad[1]
assert(U.resolveCard(collection, attack).id == "pll_sowers_2026")
assert(not U.equip(collection, 2, attack) and not U.equip(collection, 7, attack))
assert(U.unequip(collection, 1) and U.equip(collection, 2, attack))
assert(U.equipKit(collection, "field_violet") and U.load().squad[2] == attack)

-- Out-of-date or unreadable data stays intact.
storage[key] = json.encode({version=4})
local before = storage[key]
collection = U.load()
assert(collection.loadError and not E.grantStarter(collection) and storage[key] == before)
storage[key] = "corrupt JSON"
collection = U.load()
assert(collection.loadError and not E.grantStarter(collection) and storage[key] == "corrupt JSON")

print("Ultimate starter guarantee, wallet, exact 20/35/45 wheel odds, pack reveal data, private developer gate, record rewards, and save rollback/migration passed.")
