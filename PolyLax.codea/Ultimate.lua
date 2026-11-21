-- PolyLax Ultimate | real-world research catalog and original preview kits
-- Data is editorial research, NOT licensed player likenesses, league assets or official ratings.
PolyLax = PolyLax or {}
local Ultimate = {}
PolyLax.Ultimate = Ultimate

Ultimate.version = 1
Ultimate.sources = {
    pll = "https://stats.premierlacrosseleague.com/player-table",
    nll = "https://www.nll.com/stats/",
    mll = "Historical archive: verify season and club before publishing"
}
Ultimate.disclaimer = "Unofficial fan research preview. Not affiliated with or endorsed by PLL, MLL or NLL."
Ultimate.releasePolicy = {
    publicNames = false, -- switch only after rights/editorial review
    officialLogos = false,
    playerPhotos = false,
    authenticUniformArt = false,
    paidPacks = false
}
-- Source-backed 2026 PLL season entries. In-game attributes are intentionally unassigned.
Ultimate.players = {
    {id="pll_sowers_2026",name="Michael Sowers",league="PLL",season=2026,team="Waterdogs",position="A",stats={games=12,points=51,goals=29,assists=22}},
    {id="pll_holman_2026",name="Marcus Holman",league="PLL",season=2026,team="Cannons",position="A",stats={games=12,points=41,goals=28,assists=7}},
    {id="pll_oneill_2026",name="Brennan O'Neill",league="PLL",season=2026,team="Outlaws",position="A",stats={games=11,points=35,goals=13,assists=19}},
    {id="pll_carroll_2026",name="Aidan Carroll",league="PLL",season=2026,team="Whipsnakes",position="M",stats={games=12,points=34,goals=28,assists=6}},
    {id="pll_kavanagh_2026",name="Chris Kavanagh",league="PLL",season=2026,team="Redwoods",position="A",stats={games=10,points=34,goals=23,assists=10}},
    {id="pll_molloy_2026",name="Dylan Molloy",league="PLL",season=2026,team="Redwoods",position="A",stats={games=12,points=34,goals=25,assists=9}},
    {id="pll_king_2026",name="Sam King",league="PLL",season=2026,team="Archers",position="M",stats={games=12,points=33,goals=23,assists=10}},
    {id="pll_malone_2026",name="TJ Malone",league="PLL",season=2026,team="Whipsnakes",position="A",stats={games=12,points=32,goals=24,assists=8}}
}
-- League/club metadata for kit previews; colors are ORIGINAL game design, not replicas.
Ultimate.kits = {
    {id="field_violet",name="Violet Field",league="PLL",era="modern",home={34,30,73},away={228,222,241},accent={202,158,64}},
    {id="field_coastal",name="Coastal Field",league="PLL",era="modern",home={17,77,92},away={229,238,237},accent={94,194,177}},
    {id="heritage_navy",name="Heritage Navy",league="MLL",era="throwback",home={28,44,71},away={232,235,241},accent={191,143,65}},
    {id="heritage_crimson",name="Heritage Crimson",league="MLL",era="throwback",home={107,31,49},away={244,231,229},accent={217,171,94}},
    {id="box_midnight",name="Midnight Box",league="NLL",era="indoor",home={27,28,37},away={222,223,231},accent={221,114,47}},
    {id="box_ice",name="Ice Box",league="NLL",era="indoor",home={23,67,113},away={225,241,250},accent={97,188,226}}
}
function Ultimate.catalog(league)
    local out={}
    for _,p in ipairs(Ultimate.players) do
        if not league or p.league==league then out[#out+1]=p end
    end
    return out
end
function Ultimate.find(id)
    for _,p in ipairs(Ultimate.players) do if p.id==id then return p end end
end
function Ultimate.kit(id)
    for _,k in ipairs(Ultimate.kits) do if k.id==id then return k end end
end
function Ultimate.defaultCollection()
    return {version=1,owned={},squad={},equippedKit="field_violet",coins=0}
end
function Ultimate.addCard(collection,id)
    if not Ultimate.find(id) then return false,"unknown player" end
    collection.owned=collection.owned or {}
    collection.owned[id]=(collection.owned[id] or 0)+1
    return true
end
function Ultimate.equip(collection,slot,id)
    if type(slot)~="number" or slot<1 or slot>10 or slot%1~=0 then return false,"invalid slot" end
    if not Ultimate.find(id) then return false,"unknown player" end
    if not collection.owned or (collection.owned[id] or 0)<1 then return false,"card not owned" end
    collection.squad=collection.squad or {}
    for key,value in pairs(collection.squad) do if value==id and key~=slot then return false,"already in lineup" end end
    collection.squad[slot]=id
    return true
end
function Ultimate.equipKit(collection,id)
    if not Ultimate.kit(id) then return false,"unknown kit" end
    collection.equippedKit=id
    return true
end
return Ultimate
