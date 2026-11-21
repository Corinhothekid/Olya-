-- PolyLax Ultimate | real-world research catalog and original preview kits
-- Data is editorial research, NOT licensed player likenesses, league assets or official ratings.
PolyLax = PolyLax or {}
local Ultimate = {}
PolyLax.Ultimate = Ultimate

Ultimate.version = 2
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
-- Research candidates, NOT verified season roster entries. No current affiliation implied.
Ultimate.researchCandidates = {
    {id="research_pll_1",name="Jeff Teat",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_2",name="Lyle Thompson",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_3",name="Asher Nolting",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_4",name="Connor Fields",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_5",name="Matt Rambo",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_6",name="Grant Ament",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_7",name="Zed Williams",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_8",name="Rob Pannell",league="PLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_pll_9",name="Tom Schreiber",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_10",name="Romar Dennis",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_11",name="Ryan Conrad",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_12",name="Dox Aitken",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_13",name="Trevor Baptiste",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_14",name="TD Ierlan",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_15",name="Mike Sisselberger",league="PLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_pll_16",name="JT Giles-Harris",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_17",name="Gavin Adler",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_18",name="Matt Dunn",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_19",name="Jack Rowlett",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_20",name="Michael Ehrhardt",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_21",name="Graeme Hossack",league="PLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_pll_22",name="Blaze Riorden",league="PLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_pll_23",name="Jack Kelly",league="PLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_pll_24",name="Colin Kirst",league="PLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_pll_25",name="Brett Dobson",league="PLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_mll_26",name="Paul Rabil",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_27",name="John Grant Jr.",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_28",name="Casey Powell",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_29",name="Ryan Powell",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_30",name="Mikey Powell",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_31",name="John Tavares",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_32",name="Matt Poskay",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_33",name="Kevin Leveille",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_34",name="Brendan Mundorf",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_35",name="Steele Stanwick",league="MLL",position="A",verification="pending",team=nil,season=nil},
    {id="research_mll_36",name="Kyle Harrison",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_37",name="Matt Striebel",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_38",name="Max Seibald",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_39",name="Paul Gait",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_40",name="Gary Gait",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_41",name="Joe Walters",league="MLL",position="M",verification="pending",team=nil,season=nil},
    {id="research_mll_42",name="Brodie Merrill",league="MLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_mll_43",name="Nicky Polanco",league="MLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_mll_44",name="Kyle Hartzell",league="MLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_mll_45",name="Lee Zink",league="MLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_mll_46",name="Jesse Schwartzman",league="MLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_mll_47",name="Drew Adams",league="MLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_mll_48",name="Brian Dougherty",league="MLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_49",name="Dhane Smith",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_50",name="Josh Byrne",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_51",name="Chris Cloutier",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_52",name="Ryan Smith",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_53",name="Shayne Jackson",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_54",name="Randy Staats",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_55",name="Austin Staats",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_56",name="Curtis Dickson",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_57",name="Cody Jamieson",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_58",name="Mark Matthews",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_59",name="Callum Crawford",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_60",name="Rob Hellyer",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_61",name="Tom Schreiber",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_62",name="Lyle Thompson",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_63",name="Jeff Teat",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_64",name="John Tavares",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_65",name="Dan Dawson",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_66",name="Shawn Evans",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_67",name="Colin Doyle",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_68",name="John Grant Jr.",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_69",name="Gary Gait",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_70",name="Paul Gait",league="NLL",position="F",verification="pending",team=nil,season=nil},
    {id="research_nll_71",name="Zach Currier",league="NLL",position="T",verification="pending",team=nil,season=nil},
    {id="research_nll_72",name="Tyler Pace",league="NLL",position="T",verification="pending",team=nil,season=nil},
    {id="research_nll_73",name="Graeme Hossack",league="NLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_nll_74",name="Brodie Merrill",league="NLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_nll_75",name="Steve Priolo",league="NLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_nll_76",name="Matt Beers",league="NLL",position="D",verification="pending",team=nil,season=nil},
    {id="research_nll_77",name="Matt Vinc",league="NLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_78",name="Christian Del Bianco",league="NLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_79",name="Dillon Ward",league="NLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_80",name="Nick Rose",league="NLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_81",name="Doug Jamieson",league="NLL",position="G",verification="pending",team=nil,season=nil},
    {id="research_nll_82",name="Mike Poulin",league="NLL",position="G",verification="pending",team=nil,season=nil},
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
function Ultimate.catalog(league, includeResearch)
    local source=includeResearch and Ultimate.researchCandidates or Ultimate.players
    local out={}
    for _,p in ipairs(source) do
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
    return {version=2,owned={},squad={},equippedKit="field_violet",coins=0,unopenedPacks=0,completedSBC={}}
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
