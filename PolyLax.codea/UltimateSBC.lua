-- PolyLax Ultimate | Squad Building Challenges
PolyLax = PolyLax or {}
local U = assert(PolyLax.Ultimate, "Ultimate.lua required")
local SBC = {}
U.SBC = SBC

SBC.challenges = {
    {id="starter_exchange",name="First Trade",slots=2,repeatable=false,
        reward={coins=250,pack=1},rules={minLeagues=1}},
    {id="field_specialists",name="Field Specialists",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="PLL",positions={"A","M","D"},minOverall=80}},
    {id="box_experts",name="Box Experts",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="NLL",positions={"A","M","G"},minOverall=82}},
    {id="heritage",name="Heritage Exchange",slots=3,repeatable=false,
        reward={coins=650,pack=1},rules={league="MLL",positions={"A","D","G"},minOverall=82}},
    {id="cross_league",name="Cross-League Chemistry",slots=4,repeatable=false,
        reward={coins=1200,pack=2},rules={positions={"A","M","D","G"},
            minLeagues=2,minOverall=82,minChemistry=2}},
    {id="ultimate_mix",name="Ultimate Trio",slots=6,repeatable=false,
        reward={coins=2000,pack=3},rules={positions={"A","A","M","FO","D","G"},
            minLeagues=3,minOverall=85,minChemistry=4}}
}

local leagueNames = {PLL="PLL",MLL="MLL",NLL="NLL"}
local positions = {A="ATT",M="MID",D="DEF",G="G",FO="FOGO",LSM="LSM",SSDM="SSDM"}
local positionAliases = {F="A",T="M",FACEOFF="FO",FOGO="FO"}

local function positionCode(position)
    return positionAliases[position] or position
end

function SBC.find(challengeId)
    for _, challenge in ipairs(SBC.challenges) do
        if challenge.id == challengeId then return challenge end
    end
end

function SBC.requirements(challenge)
    local rules = challenge.rules
    local requirements = {challenge.slots.." cards"}
    if rules.league then
        requirements[1] = challenge.slots.." "..leagueNames[rules.league].." cards"
    elseif (rules.minLeagues or 1) > 1 then
        requirements[#requirements+1] = rules.minLeagues.."+ leagues"
    end
    if rules.minOverall then
        requirements[#requirements+1] = rules.minOverall.."+ Avg OVR"
    end
    return table.concat(requirements," · ")
end

function SBC.positionLabel(position)
    return positions[positionCode(position)] or "ANY"
end

function SBC.positionForSlot(challenge, slot)
    return challenge.rules.positions and challenge.rules.positions[slot]
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

function SBC.allows(challenge, player, slot)
    if not player or player.playable==false or player.verification=="pending" or not leagueNames[player.league] then
        return false,"Only collectible cards can be used"
    end
    local league = challenge.rules.league
    if league and player.league~=league then return false,"Use "..league.." cards" end
    local required = positionCode(SBC.positionForSlot(challenge, slot))
    if required and required~=U.role(player) and required~=positionCode(player.position or player.role) then
        return false,"Slot "..slot.." needs "..SBC.positionLabel(required)
    end
    local rating = U.Economy.rating(player)
    if type(rating)~="number" or rating<0 or rating>99 or rating~=rating then
        return false,"This card has no valid rating"
    end
    return true
end

local function progress(collection, challenge, cardIds)
    local metrics = {cards=0,leagues=0,ratingTotal=0,overall=0,chemistry=0}
    local used, leagueCount = {}, {}
    for slot=1,challenge.slots do
        local uid = cardIds[slot]
        local player = type(uid)=="string" and U.resolveCard(collection,uid)
        if uid~=nil then
            if type(uid)~="string" then
                metrics.issue = metrics.issue or "Invalid card selection"
            elseif used[uid] then
                metrics.issue = metrics.issue or "Each card copy can fill one slot"
            elseif not player then
                metrics.issue = metrics.issue or "A selected card is no longer owned"
            else
                local allowed, reason = SBC.allows(challenge,player,slot)
                if allowed then
                    used[uid] = true
                    local linked = leagueCount[player.league] or 0
                    if linked==0 then metrics.leagues = metrics.leagues+1 end
                    -- This card gains one point per previously placed card from its league.
                    metrics.chemistry = metrics.chemistry+linked
                    leagueCount[player.league] = linked+1
                    metrics.cards = metrics.cards+1
                    metrics.ratingTotal = metrics.ratingTotal+U.Economy.rating(player)
                else
                    metrics.issue = metrics.issue or reason
                end
            end
        end
    end
    if metrics.cards>0 then metrics.overall = metrics.ratingTotal/metrics.cards end
    return metrics
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

    local metrics = progress(collection,challenge,cardIds)
    if metrics.issue then return false,metrics.issue,metrics end
    if metrics.cards<challenge.slots then return false,"Choose "..challenge.slots.." cards",metrics end
    local rules = challenge.rules
    if metrics.leagues<(rules.minLeagues or 1) then
        return false,"Add cards from more leagues",metrics
    end
    if rules.minOverall and metrics.ratingTotal<rules.minOverall*challenge.slots then
        return false,"Raise your squad's average OVR",metrics
    end
    if metrics.chemistry<(rules.minChemistry or 0) then
        return false,"Add more same-league pairs",metrics
    end
    return true,challenge,metrics
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

