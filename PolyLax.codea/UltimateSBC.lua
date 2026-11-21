-- PolyLax Ultimate | Squad Building Challenges
PolyLax = PolyLax or {}
local U = assert(PolyLax.Ultimate, "Ultimate.lua required")
local SBC = {}
U.SBC = SBC

SBC.challenges = {
    {id="starter_exchange",name="First Trade",slots=2,repeatable=false,
        reward={coins=250,pack=1},rules={minLeagues=1}},
    {id="field_specialists",name="Field Specialists",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="PLL"}},
    {id="box_experts",name="Box Experts",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="NLL"}},
    {id="heritage",name="Heritage Exchange",slots=3,repeatable=false,
        reward={coins=650,pack=1},rules={league="MLL"}},
    {id="cross_league",name="Cross-League Chemistry",slots=4,repeatable=false,
        reward={coins=1200,pack=2},rules={minLeagues=2}},
    {id="ultimate_mix",name="Ultimate Trio",slots=6,repeatable=false,
        reward={coins=2000,pack=3},rules={minLeagues=3}}
}

local leagueNames = {PLL="PLL",MLL="MLL",NLL="NLL"}

function SBC.find(challengeId)
    for _, challenge in ipairs(SBC.challenges) do
        if challenge.id == challengeId then return challenge end
    end
end

function SBC.requirements(challenge)
    local rules = challenge.rules
    if rules.league then
        return challenge.slots.." "..leagueNames[rules.league].." cards"
    end
    if rules.minLeagues > 1 then
        return challenge.slots.." cards from "..rules.minLeagues.." or more leagues"
    end
    return challenge.slots.." cards from any league"
end

function SBC.isComplete(collection, challenge)
    return not challenge.repeatable and collection.completedSBC
        and collection.completedSBC[challenge.id] == true
end

function SBC.isEquipped(collection, uid)
    for _, id in pairs(collection.squad or {}) do
        if id == uid then return true end
    end
    return false
end

function SBC.allows(challenge, player)
    if not player or not leagueNames[player.league] then return false end
    return not challenge.rules.league or player.league == challenge.rules.league
end

function SBC.validate(collection, challengeId, cardIds)
    local challenge = SBC.find(challengeId)
    if not challenge then return false, "Unknown challenge" end
    if SBC.isComplete(collection, challenge) then return false, "Exchange completed" end
    if type(cardIds) ~= "table" then return false, "Choose "..challenge.slots.." cards" end
    for slot in pairs(cardIds) do
        if type(slot) ~= "number" or slot%1 ~= 0 or slot < 1 or slot > challenge.slots then
            return false, "Invalid card slot"
        end
    end

    local used, leagues, represented = {}, {}, 0
    for slot = 1, challenge.slots do
        local uid = cardIds[slot]
        if type(uid) ~= "string" then return false, "Choose "..challenge.slots.." cards" end
        if used[uid] then return false, "Each card copy can fill one slot" end
        used[uid] = true
        local player = U.resolveCard(collection, uid)
        if not player then return false, "A selected card is no longer owned" end
        if not SBC.allows(challenge, player) then
            return false, "Use "..(challenge.rules.league or "eligible").." cards"
        end
        if not leagues[player.league] then
            represented = represented+1
            leagues[player.league] = true
        end
    end
    if represented < (challenge.rules.minLeagues or 1) then
        return false, "Add cards from more leagues"
    end
    return true, challenge
end

function SBC.submit(collection, challengeId, cardIds)
    return U.transact(collection, function(draft)
        local valid, challenge = SBC.validate(draft, challengeId, cardIds)
        if not valid then return false, challenge end
        for slot = 1, challenge.slots do
            local removed, reason = U.removeCard(draft, cardIds[slot])
            if not removed then return false, reason end
        end
        local coins, packs = challenge.reward.coins, challenge.reward.pack
        draft.coins = (draft.coins or 0)+coins
        draft.unopenedPacks = (draft.unopenedPacks or 0)+packs
        draft.completedSBC = draft.completedSBC or {}
        draft.completedSBC[challengeId] = true
        return true, {coins=coins,packs=packs}
    end)
end

