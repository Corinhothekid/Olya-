local project = os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(project.."/UltimateCatalog.lua")
local Catalog = assert(PolyLax.UltimateCatalog)
local legacyIds = {
    pll_sowers_2026=82, pll_holman_2026=89, pll_oneill_2026=96, pll_carroll_2026=81,
    pll_kavanagh_2026=88, pll_molloy_2026=95, pll_king_2026=80, pll_malone_2026=87
}
local kitIds = {"field_violet","field_coastal","heritage_navy","heritage_crimson","box_midnight","box_ice"}
local affiliations = {PLL={}, MLL={}, NLL={}}
local ids = {}
for _,card in ipairs(Catalog.players) do
    assert(not ids[card.id] and card.fictional and card.playable and card.ratingStatus=="placeholder")
    assert(card.rating>=75 and card.rating<=99 and card.rating==math.floor(card.rating))
    assert(type(card.name)=="string" and #card.name>0 and Catalog.find(card.id)==card)
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
local realKeys={}
for _,record in ipairs(records) do
    assert(not ids[record.id] and not Catalog.find(record.id) and not record.playable)
    assert(record.verification=="verified" and record.ratingStatus=="placeholder")
    assert(record.source:match("^https://"),"Missing evidence for "..record.id)
    ids[record.id]=true
    realKeys[record.league.."/"..record.name]=true
end
for league in pairs(affiliations) do assert(#Catalog.verified(league)>=15) end
for _,record in ipairs(Catalog.researchCandidates) do
    assert(record.verification=="pending" and not record.playable and not Catalog.find(record.id))
    assert(not realKeys[record.league.."/"..record.name],"Verified identity still pending")
end
assert(not Catalog.releasePolicy.publicNames and not Catalog.releasePolicy.officialLogos)
assert(not Catalog.releasePolicy.playerPhotos and not Catalog.releasePolicy.authenticUniformArt)
print(string.format("Catalog passed: %d playable originals, %d verified research records, %d pending entries and %d original kits.",
    #Catalog.players,#records,#Catalog.researchCandidates,#Catalog.kits))
