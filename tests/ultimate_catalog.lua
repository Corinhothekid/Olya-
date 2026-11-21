local project = os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(project.."/UltimateCatalog.lua")
dofile(project.."/Attributes.lua")
local Catalog = assert(PolyLax.UltimateCatalog)
local legacyIds = {
    pll_sowers_2026=82, pll_holman_2026=89, pll_oneill_2026=96, pll_carroll_2026=81,
    pll_kavanagh_2026=88, pll_molloy_2026=95, pll_king_2026=80, pll_malone_2026=87
}
local kitIds = {"field_violet","field_coastal","heritage_navy","heritage_crimson","box_midnight","box_ice"}
local affiliations = {PLL={}, MLL={}, NLL={}}
local ids = {}
local editions, originals = {}, 0
local attributeKeys = {}
for _,key in ipairs(PolyLax.Attributes.keys) do attributeKeys[key]=true end
for _,card in ipairs(Catalog.players) do
    assert(not ids[card.id] and card.playable)
    assert(card.rating>=75 and card.rating<=99 and card.rating==math.floor(card.rating))
    assert(type(card.name)=="string" and #card.name>0 and Catalog.find(card.id)==card)
    if card.fictional then
        assert(card.ratingStatus=="placeholder" and not card.verification)
        originals=originals+1
    else
        assert(card.verification=="verified" and card.ratingStatus=="fictional")
        assert(card.season and card.team and card.source and card.identity)
        assert(card.evidence.kind and card.evidence.description and card.source:match("^https://"))
        assert(card.evidence.source==card.source and card.ratingVersion==1)
        assert(card.attributes and next(card.attributes))
        for key,bonus in pairs(card.attributes) do
            assert(attributeKeys[key] and bonus>=0 and bonus<=8 and bonus==math.floor(bonus))
        end
        local byEdition=editions[card.identity] or {}
        local season=card.league.."/"..tostring(card.season)
        assert(not byEdition[season],"Duplicate season edition")
        byEdition[season]=card
        editions[card.identity]=byEdition
    end
    local availability = assert(affiliations[card.league])
    availability[card.position]=true
    local tier = card.rating>=90 and "elite" or (card.rating>=85 and "high" or "core")
    availability[tier]=true
    ids[card.id]=true
end
for id,rating in pairs(legacyIds) do assert(Catalog.find(id).rating==rating) end
for _,availability in pairs(affiliations) do
    for _,role in ipairs({"A","M","D","G","FO","LSM","SSDM","elite","high","core"}) do
        assert(availability[role],"Missing "..role)
    end
end
for _,id in ipairs(kitIds) do assert(Catalog.kit(id) and #Catalog.kit(id).accent==3) end

local records=Catalog.verified()
assert(#records==#Catalog.realPlayers)
local realKeys, referenceIds={}, {}
for _,record in ipairs(records) do
    assert(not ids[record.id] and not Catalog.find(record.id) and not record.playable)
    assert(record.verification=="verified" and record.ratingStatus=="placeholder")
    assert(record.source:match("^https://"),"Missing evidence for "..record.id)
    ids[record.id]=true
    referenceIds[record.id]=record
    realKeys[record.league.."/"..record.name]=true
end
local reviewedPosition={}
for _,edition in ipairs(Catalog.editions) do
    local record=assert(referenceIds[edition.recordId],edition.id.." has no verified record")
    assert(edition.name==record.name and edition.position==record.position)
    assert(edition.league==record.league and edition.season==record.season)
    reviewedPosition[edition.position]=true
end
for _,position in ipairs({"A","M","D","G","FO","LSM","SSDM","F","T"}) do
    assert(reviewedPosition[position], "Missing reviewed "..position.." edition")
end
local schreiber=assert(editions["player:tomschreiber"])
assert(schreiber["PLL/2022"] and schreiber["MLL/2017"] and schreiber["NLL/2017"])
local teat=assert(editions["player:jeffteat"])
assert(teat["PLL/2024"].rating>teat["PLL/2025"].rating and teat["NLL/2024-25"].id~=teat["PLL/2025"].id)
assert(Catalog.find("edition_pll_mcmeekin_2026").attributes.faceoff>=6)
assert(Catalog.find("edition_nll_dobson_2026").attributes.reflexes>=6)
assert(Catalog.find("edition_nll_jones_2026").attributes.stickCheck>=6)
assert(Catalog.find("edition_mll_thompson_2019").attributes.shotAccuracy>=6)
assert(Catalog.find("edition_nll_bal_2026").attributes.passing>=6)
for league in pairs(affiliations) do assert(#Catalog.verified(league)>=15) end
for _,record in ipairs(Catalog.researchCandidates) do
    assert(record.verification=="pending" and not record.playable and not Catalog.find(record.id))
    assert(not realKeys[record.league.."/"..record.name],"Verified identity still pending")
end
assert(Catalog.releasePolicy.publicNames and not Catalog.releasePolicy.officialLogos)
assert(not Catalog.releasePolicy.playerPhotos and not Catalog.releasePolicy.authenticUniformArt)
assert(originals==46 and #Catalog.players==originals+#Catalog.editions and #Catalog.editions>=40)
print(string.format("Catalog passed: %d originals, %d collectible verified editions, %d sourced records, %d pending entries, %d original kits.",
    originals,#Catalog.editions,#records,#Catalog.researchCandidates,#Catalog.kits))
