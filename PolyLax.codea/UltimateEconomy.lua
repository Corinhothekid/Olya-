-- PolyLax Ultimate | earn-only starter packs, packs, wheel, and match rewards
PolyLax = PolyLax or {}
local U = assert(PolyLax.Ultimate, "Load Ultimate before UltimateEconomy")
local E = {}
U.Economy = E

E.packSize = 5
E.wheelCost = 1200
E.packCost = 3500
E.rates = {
    {tier="elite", minimum=90, maximum=99, weight=20},
    {tier="high", minimum=85, maximum=89, weight=35},
    {tier="core", minimum=75, maximum=84, weight=45}
}
E.matchRewards = {win=450, draw=250, loss=150}
local developerBuild = U.isDeveloperBuild()
local highMinimum = E.rates[2].minimum
local maxHistory = 20

function E.rating(player)
    return player and player.rating
end

local function eligiblePools()
    local pools = {}
    for _, tier in ipairs(E.rates) do
        local pool = {}
        for _, player in ipairs(U.players) do
            local rating = E.rating(player)
            if player.verification ~= "pending" and type(rating) == "number"
                and rating >= tier.minimum and rating <= tier.maximum then
                pool[#pool+1] = player
            end
        end
        if #pool == 0 then return nil, "No eligible " .. tier.tier .. " cards" end
        pools[tier.tier] = pool
    end
    return pools
end

local function draw(pools, rng, minimumRating)
    local total = 0
    for _, tier in ipairs(E.rates) do
        if tier.minimum >= minimumRating then total = total + tier.weight end
    end
    local roll = rng(1, total)
    for _, tier in ipairs(E.rates) do
        if tier.minimum >= minimumRating then
            roll = roll - tier.weight
            if roll <= 0 then
                local pool = pools[tier.tier]
                local player = pool[rng(1, #pool)]
                return {
                    id=player.id, name=U.displayName(player), position=player.position, role=U.role(player),
                    league=player.league, rating=E.rating(player), tier=tier.tier
                }
            end
        end
    end
end

local function mint(draft, results)
    for _, card in ipairs(results) do
        local ok, uid = U.addCard(draft, card.id)
        if not ok then return false, uid end
        card.uid = uid
    end
    return true
end

local function open(collection, starter, rng)
    if starter and collection.starterGranted then return false, "Starter already claimed" end
    if not starter and collection.unopenedPacks < 1 then return false, "No unopened packs" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    local results = {}
    for i = 1, E.packSize do
        local minimum = starter and i == E.packSize and highMinimum or 0
        results[i] = draw(pools, rng or math.random, minimum)
    end
    return U.transact(collection, function(draft)
        local ok, mintError = mint(draft, results)
        if not ok then return false, mintError end
        if starter then
            draft.starterGranted = true
        else
            draft.unopenedPacks = draft.unopenedPacks - 1
        end
        return true, results
    end)
end

function E.grantStarter(collection, rng)
    return open(collection, true, rng)
end

function E.openPack(collection, rng)
    return open(collection, false, rng)
end

function E.buyPack(collection)
    if collection.coins < E.packCost then return false, "Not enough gold" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    return U.transact(collection, function(draft)
        draft.coins = draft.coins - E.packCost
        draft.unopenedPacks = draft.unopenedPacks + 1
        return true
    end)
end

function E.spin(collection, rng)
    if collection.coins < E.wheelCost then return false, "Not enough gold" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    local card = draw(pools, rng or math.random, 0)
    return U.transact(collection, function(draft)
        local ok, mintError = mint(draft, {card})
        if not ok then return false, mintError end
        draft.coins = draft.coins - E.wheelCost
        return true, card
    end)
end

function E.canGrantTestGold(collection)
    return developerBuild and collection and not collection.testGoldGranted and not collection.loadError
end

function E.grantTestGold(collection)
    if not developerBuild then return false, "Developer mode disabled" end
    if collection.testGoldGranted then return false, "Test gold already claimed" end
    return U.transact(collection, function(draft)
        draft.coins = draft.coins + 1000000
        draft.testGoldGranted = true
        return true, draft.coins
    end)
end

function E.beginMatch(collection)
    return U.transact(collection, function(draft)
        local id = draft.nextMatchId
        draft.nextMatchId = id+1
        draft.activeMatch = id
        return true, id
    end)
end

function E.abandonMatch(collection, id)
    if not id or collection.activeMatch ~= id then return false, "Match is no longer active" end
    return U.transact(collection, function(draft)
        draft.activeMatch = nil
        return true
    end)
end

function E.recordMatch(collection, result, id, ownScore, opponentScore)
    local payout = E.matchRewards[result]
    if not payout then return false, "Invalid match result" end
    if not id or collection.activeMatch ~= id then return false, "Match is no longer active" end
    if ownScore ~= nil or opponentScore ~= nil then
        if type(ownScore) ~= "number" or ownScore < 0 or ownScore % 1 ~= 0
            or type(opponentScore) ~= "number" or opponentScore < 0 or opponentScore % 1 ~= 0 then
            return false, "Invalid score"
        end
        local actual = ownScore == opponentScore and "draw" or (ownScore > opponentScore and "win" or "loss")
        if actual ~= result then return false, "Result does not match score" end
    end
    local record = {id=id, result=result, payout=payout, ownScore=ownScore, opponentScore=opponentScore}
    return U.transact(collection, function(draft)
        draft.coins = draft.coins + payout
        draft.matches = draft.matches + 1
        local category = result == "loss" and "losses" or result .. "s"
        draft[category] = draft[category] + 1
        draft.activeMatch = nil
        local history = draft.matchHistory
        history[#history+1] = record
        if #history > maxHistory then table.remove(history, 1) end
        return true, record
    end)
end

