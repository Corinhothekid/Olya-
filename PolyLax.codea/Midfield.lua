-- PolyLax 2.0.3 | Midfield positioning
PolyLax = PolyLax or {}
local Midfield = {}
PolyLax.Midfield = Midfield

local minimum = {offense=3, defense=4}
local lineTolerance, noticeRange = .012, 1.05
local warningTime, offsidesTime = .27, 1.20

local function opposite(side)
    return side == "offense" and "defense" or "offense"
end

local function worldSide(team, z)
    if math.abs(z) <= lineTolerance then return nil end
    local attacksNegative = team == 1
    return (z < 0) == attacksNegative and "offense" or "defense"
end

local function center(match)
    return match.field and match.field.midfieldZ or 0
end

function Midfield.halfAt(match, team, z)
    return worldSide(team, z-center(match))
end

local function active(player)
    return player and player.active ~= false and player.onField ~= false and not player.bench
end

local function playerSide(match, player, previous)
    if player.role == "G" then return "defense" end
    return Midfield.halfAt(match,player.team,player.z)
        or previous
        or (player.homeZ and Midfield.halfAt(match,player.team,player.homeZ))
        or "defense"
end

local function isValid(counts)
    return counts.offense >= minimum.offense and counts.defense >= minimum.defense
        and counts.keepers == 1 and not counts.keeperOut
end

local function countTeam(match, team, previous)
    local counts = {offense=0, defense=0, active=0, keepers=0, keeperOut=false}
    local sides, players = {}, {}
    for _, index in ipairs(match.teams[team] or {}) do
        local player = match.squad[index]
        if active(player) and player.team == team then
            local id = player.id
            local side = playerSide(match,player,previous[id])
            sides[id] = side
            players[#players+1] = player
            counts[side], counts.active = counts[side]+1, counts.active+1
            if player.role == "G" then
                counts.keepers = counts.keepers+1
                counts.keeperOut = counts.keeperOut or Midfield.halfAt(match,team,player.z) == "offense"
            end
        end
    end
    counts.valid = isValid(counts)
    return counts, sides, players
end

function Midfield.reset(match)
    local previous = match.positioning and match.positioning.sides or {}
    local state = {counts={}, sides={}, blocked={}, noticeTime=0}
    for team = 1, 2 do
        local counts, sides = countTeam(match,team,previous)
        state.counts[team] = counts
        for id, side in pairs(sides) do state.sides[id] = side end
    end
    state.invalid = not (state.counts[1].valid and state.counts[2].valid)
    match.positioning = state
    return state
end

function Midfield.side(match, player)
    local sides = match.positioning and match.positioning.sides
    return playerSide(match,player,sides and sides[player.id])
end

function Midfield.counts(match, team)
    local state = match.positioning
    if state and state.counts[team] then return state.counts[team] end
    local counts = countTeam(match,team,{})
    return counts
end

local function prioritize(candidates, humanID)
    table.sort(candidates, function(a,b)
        if a.id == humanID then return b.id ~= humanID end
        if b.id == humanID then return false end
        if a.progress ~= b.progress then return a.progress > b.progress end
        return a.id < b.id
    end)
end

local function deny(state, id, side, proposal, z, reason)
    proposal.z = z
    state.blocked[id] = {side=side, reason=reason}
end

local function resolveTeam(match, team, proposals, humanID, state, nextSides)
    local counts, sides, players = countTeam(match,team,state.sides)
    local floor = {
        offense=math.min(counts.offense,minimum.offense),
        defense=math.min(counts.defense,minimum.defense)
    }
    local crossing = {offense={}, defense={}}
    local keeperOut = false
    local midfield = center(match)
    for _, player in ipairs(players) do
        local id = player.id
        local side = sides[id]
        local proposal = proposals[id]
        nextSides[id] = side
        if state.sides[id] and state.sides[id] ~= side then state.externalEdit = true end

        local target = proposal and Midfield.halfAt(match,team,proposal.z)
        if player.role == "G" then
            local existing = Midfield.halfAt(match,team,player.z)
            if existing == "offense" then
                -- An externally displaced keeper can walk back. Do not teleport it.
                state.externalEdit = true
                if target == "offense" and math.abs(proposal.z-midfield) > math.abs(player.z-midfield) then
                    deny(state,id,side,proposal,player.z,"keeper")
                end
                local resolved = Midfield.halfAt(match,team,proposal and proposal.z or player.z)
                keeperOut = keeperOut or resolved == "offense"
            elseif target == "offense" then
                deny(state,id,side,proposal,midfield,"keeper")
            end
        elseif target and target ~= side then
            local list = crossing[side]
            list[#list+1] = {id=id, progress=math.abs(proposal.z-midfield)}
            counts[side], counts[target] = counts[side]-1, counts[target]+1
        end
    end

    -- Resolve net movement first so opposite crossings in the same frame can
    -- trade sides without either one depending on roster iteration order.
    for _, side in ipairs({"offense","defense"}) do
        local list = crossing[side]
        local deniedCount = math.max(0,floor[side]-counts[side])
        if deniedCount > 0 then prioritize(list,humanID) end
        local target = opposite(side)
        local allowedCount = #list-deniedCount
        for index, candidate in ipairs(list) do
            if index <= allowedCount then
                nextSides[candidate.id] = target
            else
                deny(state,candidate.id,side,proposals[candidate.id],midfield,"minimum")
                counts[side], counts[target] = counts[side]+1, counts[target]-1
            end
        end
    end
    counts.keeperOut = keeperOut
    counts.valid = isValid(counts)
    state.counts[team] = counts
end

local function notice(state, text, level, duration)
    state.notice, state.level, state.noticeTime = text, level, duration
end

local function showHumanNotice(match, state, proposals, humanID)
    local player = humanID and match.squad[humanID]
    local proposal = player and proposals[humanID]
    if not active(player) or not proposal then return end
    local team = player.team
    local side = state.sides[humanID]
    if not side then return end
    local blocked = state.blocked[humanID]
    if blocked then
        notice(state,"OFFSIDES","offsides",offsidesTime)
        return
    end
    if state.level == "offsides" or math.abs(proposal.z-center(match)) > noticeRange then return end
    local wanted = worldSide(team,proposal.intentZ or 0)
    local full = state.counts[team]
    if wanted and wanted ~= side and (player.role == "G" or full[side] <= minimum[side]) then
        local text = player.role == "G" and "GOALKEEPER STAYS BACK"
            or (side == "offense" and "KEEP 3 IN OFFENSE" or "KEEP 4 IN DEFENSE")
        notice(state,text,"warning",warningTime)
    end
end

function Midfield.resolve(match, proposals, humanID, dt)
    local state = match.positioning or Midfield.reset(match)
    state.noticeTime = math.max(0,state.noticeTime-math.max(0,dt or 0))
    if state.noticeTime == 0 then state.notice,state.level = nil,nil end
    state.blocked, state.externalEdit = {}, false

    local nextSides = {}
    for team = 1, 2 do resolveTeam(match,team,proposals,humanID,state,nextSides) end
    state.sides = nextSides
    state.invalid = not (state.counts[1].valid and state.counts[2].valid)
    if state.invalid then
        local side = not state.counts[1].valid and not state.counts[2].valid and "BOTH TEAMS"
            or not state.counts[1].valid and "HOME" or "AWAY"
        notice(state,side.." OFFSIDES","offsides",offsidesTime)
    else
        showHumanNotice(match,state,proposals,humanID)
    end
    return state
end

-- A substitution is an atomic exchange at a proposed field location. This
-- preview does not change the count cache, positions, lineup, or active flags.
function Midfield.canSubstitute(match, team, outgoingID, incoming, z)
    local former = match.squad[outgoingID]
    if type(incoming) == "number" then incoming = match.squad[incoming] end
    local previous = match.positioning and match.positioning.sides or {}
    local counts, sides, players = countTeam(match,team,previous)
    if not former or not sides[outgoingID] then
        return false,counts,"outgoing player is not active on this team"
    end
    if not incoming or incoming.team ~= team or incoming == former then
        return false,counts,"incoming player is not an eligible teammate"
    end
    for _, player in ipairs(players) do
        if player == incoming or incoming.id and player.id == incoming.id then
            return false,counts,"incoming player is already active"
        end
    end

    local formerSide = sides[outgoingID]
    local target = Midfield.halfAt(match,team,z or incoming.z or former.z) or formerSide
    if incoming.role == "G" and target ~= "defense" then
        counts.valid, counts.keeperOut = false, true
        return false,counts,"goalkeeper must enter on defense"
    end
    if formerSide ~= target then
        counts[formerSide], counts[target] = counts[formerSide]-1, counts[target]+1
    end
    counts.keepers = counts.keepers - (former.role == "G" and 1 or 0) + (incoming.role == "G" and 1 or 0)
    counts.keeperOut = false
    for _, player in ipairs(players) do
        if player ~= former and player.role == "G" and Midfield.halfAt(match,team,player.z) == "offense" then
            counts.keeperOut = true
        end
    end
    counts.valid = isValid(counts)
    if counts.valid then return true,counts end
    if counts.keepers ~= 1 then return false,counts,"exactly one goalkeeper must remain active" end
    if counts.keeperOut then return false,counts,"goalkeeper is over midfield" end
    if counts.offense < minimum.offense then return false,counts,"fewer than 3 players in offense" end
    return false,counts,"fewer than 4 players in defense"
end
