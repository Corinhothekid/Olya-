-- Ultimate Team uses the existing full-field simulation with a local squad snapshot.
PolyLax = PolyLax or {}
local P = PolyLax
local Match = {}
P.UltimateMatch = Match

local roles = {"A","A","A","M","M","M","D","D","D","G"}
local slots = {"A1","A2","A3","FO","M2","M3","D1","D2","D3","G"}
local specialist = {FO="FO",FACEOFF="FO",LSM="LSM",SSDM="SSDM"}
local shortNames = {"UT","GLD"}

local function ratings(role, overall)
    local attrs = P.Attributes.forPosition(role)
    local boost = overall - P.Attributes.overall(attrs,role)
    for key, value in pairs(attrs) do
        attrs[key] = math.max(30,math.min(99,value+boost))
    end
    return attrs
end

local function nextNumber(numbers, preferred)
    local number = math.max(0,math.min(99,math.floor(preferred)))
    while numbers[number] do number = (number+1)%100 end
    numbers[number] = true
    return number
end

local function buildLineups(collection)
    local ultimate = P.Ultimate
    local own, opponent, used, numbers, awayNumbers = {}, {}, {}, {}, {}
    for slot, role in ipairs(roles) do
        local uid = collection.squad[slot]
        local card = uid and ultimate.resolveCard(collection,uid)
        if card and (used[card.id] or ultimate.role(card) ~= role) then card = nil end
        local fallbackRole = slot==4 and "FO" or role
        local cardRole = card and specialist[tostring(card.position):upper()] or nil
        if card then
            used[card.id] = true
            own[slot] = {
                name=ultimate.displayName(card), role=cardRole or fallbackRole,
                number=nextNumber(numbers,tonumber(card.number) or slot+8),
                cardUID=uid, statId="ultimate:card:"..tostring(uid),
                attributes=ratings(cardRole or fallbackRole,ultimate.Economy.rating(card))
            }
        else
            own[slot] = {
                name="Reserve "..slots[slot], role=fallbackRole, temporaryAI=true,
                number=nextNumber(numbers,slot+28), statId="ultimate:reserve:"..slot,
                attributes=ratings(fallbackRole,72)
            }
        end
        opponent[slot] = {
            name="Gold "..slots[slot], role=fallbackRole,
            number=nextNumber(awayNumbers,slot+18), statId="ultimate:opponent:"..slot,
            attributes=ratings(fallbackRole,78+(slot%5))
        }
    end
    return {own,opponent}
end

local function makeTeam(index, name, palette, away)
    local id = "ultimate-"..index
    local dark, light = color(table.unpack(palette.home)), color(table.unpack(palette.away))
    local accent = color(table.unpack(palette.accent))
    return {
        id=id,name=name,short=shortNames[index],
        kit={teamId=id,primary=away and light or dark,secondary=accent,shorts=dark,
            shell=dark,accent=accent,gloves=dark,number=away and dark or light}
    }
end

function Match.new(scene, collection, profile)
    if collection.loadError then return nil,collection.loadError end
    local ultimate = P.Ultimate
    local palette = ultimate.kit(collection.equippedKit) or ultimate.kits[1]
    local rival = {home={38,36,22},away={242,233,196},accent={180,135,44}}
    local home, away = makeTeam(1,"Ultimate Squad",palette), makeTeam(2,"Gold Scouts",rival,true)
    local kit = home.kit
    local game = P.FullMatch.new(scene,profile,nil,nil,{
        profile="professional",periodLength=45,
        lineups=buildLineups(collection),teams={home,away},
        fieldTheme={id="ultimate-arena",wordmark="ULTIMATE",endWordmark="POLYLAX",
            centerWordmark="UT",primary=kit.primary,secondary=kit.secondary,
            accent=kit.accent,lettering=kit.number},
        statistics={mode="ULTIMATE TEAM",useMatchRoster=true,persist=false}
    })
    local ok, id = ultimate.Economy.beginMatch(collection)
    if not ok then return nil,id end
    local statId = "ultimate:match:"..id
    game.statisticsOptions.id, game.statistics.id = statId,statId
    return game,id
end

function Match.settle(collection, game, id)
    if game.phase ~= "FINAL" then return false,"Finish the match to earn gold" end
    local own, away = game.homeScore,game.awayScore
    local result = own>away and "win" or own<away and "loss" or "draw"
    return P.Ultimate.Economy.recordMatch(collection,result,id,own,away)
end
