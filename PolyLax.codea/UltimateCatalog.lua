-- Original cards, collectible season editions, and lacrosse research.
PolyLax = PolyLax or {}
local Catalog = {}
PolyLax.UltimateCatalog = Catalog

Catalog.releasePolicy = {
    publicNames=true,
    officialLogos=false,
    playerPhotos=false,
    authenticUniformArt=false,
    paidPacks=false
}
Catalog.disclaimer = "Original artwork and unaffiliated season editions."
Catalog.ratingDisclosure = "PolyLax game ratings are fictional."
Catalog.ratingVersion = 1

Catalog.sources = {
    pll = "https://stats.premierlacrosseleague.com/player-table",
    pllAwards2025 = "https://premierlacrosseleague.com/articles/pll-end-of-season-awards",
    pllAwards2026 = "https://www.premierlacrosseleague.com/articles/cj-kirst-wins-2026-pll-jim-brown-most-valuable-player-award",
    pllAwards2022 = "https://www.premierlacrosseleague.com/articles/baptiste-wins-first-career-mvp-at-2022-pll-awards",
    pllAwards2021 = "https://www.usalacrosse.com/magazine/blaze-riorden-wins-pll-mvp-others-honored-league-awards-night",
    pllChampionship2023 = "https://premierlacrosseleague.com/articles/archers-lc-wins-2023-pll-cash-app-championship",
    pllTeat2024 = "https://premierlacrosseleague.com/articles/2024-players-top-50-nos-10-1-atlas-archers-dominate-top-10",
    pllTeat = "https://premierlacrosseleague.com/articles/jeff-teat-expected-to-miss-2026-pll-season",
    mll = "https://www.usalacrosse.com/national-teams/2014-us-mens-team-roster",
    mllAllStar2017 = "https://www.usalacrosse.com/magazine/mll-all-star-game-rosters-announced",
    mllPoskay = "https://virginiasports.com/news/2010/08/20/former-uva-all-american-poskay-named-mll-mvp",
    mllHall = "https://www.usalacrosse.com/magazine/pll-announces-inaugural-class-professional-lacrosse-hall-fame",
    mllCannons2017 = "https://www.usalacrosse.com/magazine/mll-preview-bostons-fleet-long-poles-key-its-success",
    mllOutlaws2016 = "https://www.premierlacrosseleague.com/articles/its-all-i-know-how-to-do-how-matt-kavanagh-stepped-up-in-big-moments",
    mllMvp2015 = "https://www.premierlacrosseleague.com/articles/how-hard-time-and-resiliency-built-greg-gurenlians-professional-lacrosse-hall-of-fame-career",
    mllMvp2017 = "https://www.usalacrosse.com/magazine/us-national-team-continues-training-weekend-rain-soaked-practices",
    mllMvp2019 = "https://www.oursportscentral.com/services/releases/lyle-thompson-wins-coca-cola-most-valuable-player-and-warrior-offensive-player-of-the-year/n-5559160",
    mllAwards2020 = "https://www.usalacrosse.com/magazine/dialed-your-lacrosse-fix-monday-aug-24",
    mllGoodrich2020 = "https://www.usalacrosse.com/magazine/zach-goodrich-named-major-league-lacrosse-defensive-player-year",
    mllDraftReview2021 = "https://www.usalacrosse.com/magazine/phil-shores-premier-lacrosse-league-entry-draft-big-board",
    nll = "https://www.nll.com/stats/all-player-stats/",
    nllAwards2025 = "https://www.nll.com/news/nll-announces-2024-25-award-winners-3/",
    nllPositionAwards2025 = "https://www.nll.com/news/nll-announces-2024-25-offensive-defensive-transition-goaltender-of-the-year-winners/",
    nllAwards2026 = "https://www.nll.com/news/national-lacrosse-league-announces-2025-26-regular-season-award-winners/",
    nllHall = "https://www.nll.com/nll-hall-of-fame/",
    nllAwards2024 = "https://www.nll.com/news/buffalos-byrne-vancouvers-dilks-halifaxs-withers-and-torontos-rose-take-nll-positional-player-of-the-year-awards/",
    nllAwards2023 = "https://www.nll.com/news/del-bianco-becomes-second-goaltender-to-win-mvp-donville-fourth-straight-number-one-overall-selection-to-win-rookie-of-the-year/",
    nllAwards2019 = "https://www.nll.com/news/nll-announces-2018-19-season-award-winners/",
    nllAwards2017 = "https://www.nll.com/news/2017-nll-season-award-winners/",
    nllHistory = "https://www.nll.com/about/history/",
    nllSchreiber2017 = "https://www.nll.com/news/the-most-notable-free-agent-signings-in-recent-memory/",
    nllWard = "https://www.nll.com/players/13412/dillon-ward/"
}

Catalog.players = {}
Catalog.editions = {}
Catalog.realPlayers = {}
Catalog.researchCandidates = {}
local playableById = {}
local verifiedIdentities = {}
local verifiedById = {}

-- The IDs and ratings of the eight original economy cards are kept for older saves.
-- Fictional group codes make the existing league-themed challenges consistent.
local function addOriginals(league, rows)
    for _,row in ipairs(rows) do
        local card = {
            id=row[1], name=row[2], position=row[3], rating=row[4],
            team=row[5], number=row[6], league=league, fictional=true,
            ratingStatus="placeholder", playable=true
        }
        Catalog.players[#Catalog.players+1] = card
        playableById[card.id] = card
    end
end

addOriginals("PLL", {
    {"pll_sowers_2026", "Miles Rowan", "A", 82, "Juniper Field", 9},
    {"pll_holman_2026", "Rafe Calder", "A", 89, "Violet Field", 18},
    {"pll_oneill_2026", "Taylor Vale", "A", 96, "Sundown Field", 27},
    {"pll_carroll_2026", "Adrian Ford", "M", 81, "Coastal Field", 12},
    {"pll_kavanagh_2026", "Cal Keane", "A", 88, "Juniper Field", 20},
    {"pll_molloy_2026", "Rory Shaw", "A", 95, "Juniper Field", 4},
    {"pll_king_2026", "Cam Keyes", "M", 80, "Sundown Field", 16},
    {"pll_malone_2026", "Theo Mercer", "A", 87, "Coastal Field", 7},

    {"field_aria_santos", "Aria Santos", "D", 93, "Coastal Field", 33},
    {"field_des_banks", "Des Banks", "D", 86, "Violet Field", 23},
    {"field_rex_kerr", "Rex Kerr", "D", 79, "Juniper Field", 36},
    {"field_hugo_moreno", "Hugo Moreno", "D", 83, "Sundown Field", 44},
    {"field_kai_hollis", "Kai Hollis", "G", 91, "Juniper Field", 14},
    {"field_jay_navarro", "Jay Navarro", "G", 77, "Coastal Field", 39},
    {"field_sage_chen", "Sage Chen", "FO", 90, "Violet Field", 54},
    {"field_emil_shaw", "Emil Shaw", "LSM", 85, "Juniper Field", 4},
    {"field_eli_cross", "Eli Cross", "M", 86, "Coastal Field", 11},
    {"field_jules_nash", "Jules Nash", "SSDM", 78, "Sundown Field", 55}
})

addOriginals("MLL", {
    {"heritage_trey_bishop", "Trey Bishop", "A", 94, "Heritage Navy", 14},
    {"heritage_wes_roux", "Wes Roux", "A", 86, "Heritage Crimson", 5},
    {"heritage_noah_dane", "Noah Dane", "A", 79, "Copper Heritage", 18},
    {"heritage_tate_ochoa", "Tate Ochoa", "M", 92, "Copper Heritage", 21},
    {"heritage_dev_wilder", "Dev Wilder", "M", 85, "Heritage Navy", 24},
    {"heritage_gael_price", "Gael Price", "FO", 82, "Heritage Crimson", 14},
    {"heritage_leo_guerrero", "Leo Guerrero", "LSM", 88, "Heritage Navy", 8},
    {"heritage_milo_doucet", "Milo Doucet", "D", 91, "Copper Heritage", 3},
    {"heritage_tal_bennett", "Tal Bennett", "D", 84, "Heritage Navy", 36},
    {"heritage_owen_bridge", "Owen Bridge", "D", 77, "Heritage Crimson", 55},
    {"heritage_jude_cantu", "Jude Cantu", "G", 89, "Heritage Crimson", 12},
    {"heritage_ronan_blair", "Ronan Blair", "G", 75, "Copper Heritage", 2},
    {"heritage_luca_dawes", "Luca Dawes", "M", 83, "Heritage Navy", 50},
    {"heritage_aziz_cortez", "Aziz Cortez", "SSDM", 80, "Copper Heritage", 44}
})

addOriginals("NLL", {
    {"box_ari_beck", "Ari Beck", "A", 96, "Midnight Box", 26},
    {"box_remy_march", "Remy March", "A", 88, "Ice Box", 35},
    {"box_silas_voss", "Silas Voss", "A", 80, "Ember Box", 11},
    {"box_luc_renaud", "Luc Renaud", "M", 93, "Ice Box", 25},
    {"box_arden_west", "Arden West", "M", 89, "Midnight Box", 15},
    {"box_dane_costa", "Dane Costa", "M", 78, "Ember Box", 42},
    {"box_cian_frost", "Cian Frost", "D", 92, "Ember Box", 6},
    {"box_ryan_harrow", "Ryan Harrow", "D", 85, "Ice Box", 47},
    {"box_finn_park", "Finn Park", "D", 81, "Midnight Box", 38},
    {"box_mikael_dunn", "Mikael Dunn", "G", 90, "Midnight Box", 1},
    {"box_elio_tremblay", "Elio Tremblay", "G", 83, "Ice Box", 30},
    {"box_dalen_varga", "Dalen Varga", "SSDM", 87, "Ember Box", 24},
    {"box_cade_kim", "Cade Kim", "FO", 84, "Ember Box", 71},
    {"box_anton_desai", "Anton Desai", "LSM", 79, "Ice Box", 64}
})

-- Evidence records preserve the club and competition in the cited season.
-- Ratings are game design placeholders and never sourced facts.
local function addVerified(league,season,source,rows)
    for _,row in ipairs(rows) do
        local legacyCardId = playableById[row[1]] and row[1]
        local player = {
            id=legacyCardId and "record_"..legacyCardId or row[1], legacyCardId=legacyCardId,
            name=row[2], position=row[3], team=row[4], rating=row[5],
            stats=row[6], league=league, season=season, source=Catalog.sources[source],
            verification="verified", ratingStatus="placeholder", playable=false
        }
        Catalog.realPlayers[#Catalog.realPlayers+1] = player
        verifiedIdentities[league.."/"..player.name] = true
        verifiedById[row[1]] = player
    end
end

addVerified("PLL",2026,"pll",{
    {"pll_sowers_2026","Michael Sowers","A","Philadelphia Waterdogs",82,{games=12,points=51,goals=29,assists=22}},
    {"pll_holman_2026","Marcus Holman","A","Boston Cannons",89,{games=12,points=41,goals=28,assists=7}},
    {"pll_oneill_2026","Brennan O'Neill","A","Denver Outlaws",96,{games=11,points=35,goals=13,assists=19}},
    {"pll_carroll_2026","Aidan Carroll","M","Maryland Whipsnakes",81,{games=12,points=34,goals=28,assists=6}},
    {"pll_kavanagh_2026","Chris Kavanagh","A","California Redwoods",88,{games=10,points=34,goals=23,assists=10}},
    {"pll_molloy_2026","Dylan Molloy","A","California Redwoods",95,{games=12,points=34,goals=25,assists=9}},
    {"pll_king_2026","Sam King","M","Utah Archers",80,{games=12,points=33,goals=23,assists=10}},
    {"pll_malone_2026","TJ Malone","A","Maryland Whipsnakes",87,{games=12,points=32,goals=24,assists=8}}
})

addVerified("PLL",2026,"pllAwards2026",{
    {"pll_kirst_2026","CJ Kirst","A","Philadelphia Waterdogs",95,{goals=34}},
    {"pll_dobson_2026","Brett Dobson","G","Utah Archers",93,{savePct=59}},
    {"pll_lavelle_2026","Brendan Lavelle","D","Utah Archers"},
    {"pll_tevlin_2026","Brian Tevlin","SSDM","California Redwoods",nil,
        {causedTurnovers=9,points=13,goals=7,assists=6}},
    {"pll_mcmeekin_2026","Andrew McMeekin","FO","Boston Cannons",nil,{faceoffPct=62.5}},
    {"pll_currier_2026","Zach Currier","M","Philadelphia Waterdogs",nil,{groundBalls=68}},
    {"pll_rall_2026","Ethan Rall","LSM","Boston Cannons"},
    {"pll_spallina_2026","Joey Spallina","A","Maryland Whipsnakes",nil,{points=36,goals=16,assists=18}}
})

addVerified("PLL",2025,"pllAwards2025",{
    {"pll_shellenberger_2025","Connor Shellenberger","A","New York Atlas",94,{points=46,goals=23,assists=23}},
    {"pll_campbell_2025","Matt Campbell","M","Boston Cannons",89,{points=28,goals=18,assists=8}},
    {"pll_adler_2025","Gavin Adler","D","New York Atlas",91,{causedTurnovers=13}},
    {"pll_rowlett_2025","Jack Rowlett","D","Carolina Chaos",86},
    {"pll_giles_harris_2025","JT Giles-Harris","D","Denver Outlaws",89},
    {"pll_hossack_2025","Graeme Hossack","D","Utah Archers",87},
    {"pll_mcnaney_2025","Logan McNaney","G","Denver Outlaws",90,{savePct=58.3}},
    {"pll_riorden_2025","Blaze Riorden","G","Carolina Chaos",91},
    {"pll_entenmann_2025","Liam Entenmann","G","New York Atlas",86},
    {"pll_ierlan_2025","TD Ierlan","FO","California Redwoods",88,{faceoffPct=60.5,groundBalls=74}},
    {"pll_baptiste_2025","Trevor Baptiste","FO","New York Atlas",92},
    {"pll_piseno_2025","Jake Piseno","LSM","Denver Outlaws",91,{causedTurnovers=12,groundBalls=36}},
    {"pll_terefenko_2025","Ryan Terefenko","SSDM","Denver Outlaws",89,{causedTurnovers=2,groundBalls=18}}
})

addVerified("PLL",2025,"pllTeat",{
    {"pll_teat_2025","Jeff Teat","A","New York Atlas",93,{points=40,goals=17,assists=23}}
})

addVerified("PLL",2024,"pllTeat2024",{
    {"pll_teat_2024","Jeff Teat","A","New York Atlas",nil,{points=64,goals=28,assists=36}}
})

addVerified("PLL",2023,"pllChampionship2023",{
    {"pll_dobson_2023","Brett Dobson","G","Archers Lacrosse Club"}
})

addVerified("PLL",2022,"pllAwards2022",{
    {"pll_schreiber_2022","Tom Schreiber","M","Archers Lacrosse Club",nil,{games=10,points=35,goals=17,assists=14}},
    {"pll_baptiste_2022","Trevor Baptiste","FO","Atlas Lacrosse Club"}
})

addVerified("PLL",2021,"pllAwards2021",{
    {"pll_riorden_2021","Blaze Riorden","G","Chaos Lacrosse Club",nil,{games=9,saves=149,savePct=61}}
})

addVerified("MLL",2014,"mll",{
    {"mll_rabil_2014","Paul Rabil","M","Boston Cannons",95},
    {"mll_pannell_2014","Rob Pannell","A","New York Lizards",93},
    {"mll_leveille_2014","Kevin Leveille","A","Rochester Rattlers",87},
    {"mll_harrison_2014","Kyle Harrison","M","Ohio Machine",90},
    {"mll_seibald_2014","Max Seibald","M","New York Lizards",86},
    {"mll_zink_2014","Lee Zink","D","Denver Outlaws",91},
    {"mll_durkin_2014","Tucker Durkin","D","Florida Launch",89},
    {"mll_hartzell_2014","Kyle Hartzell","D","New York Lizards",87},
    {"mll_schwartzman_2014","Jesse Schwartzman","G","Denver Outlaws",90},
    {"mll_galloway_2014","John Galloway","G","Rochester Rattlers",85},
    {"mll_gurenlian_2014","Greg Gurenlian","FO","New York Lizards",92},
    {"mll_stanwick_2014","Steele Stanwick","A","Ohio Machine",85}
})

addVerified("MLL",2017,"mllAllStar2017",{
    {"mll_adams_2017","Drew Adams","G","New York Lizards",89},
    {"mll_walters_2017","Joe Walters","M","New York Lizards",89},
    {"mll_dunn_2017","Matt Dunn","D","Rochester Rattlers",85}
})

addVerified("MLL",2017,"mllMvp2017",{
    {"mll_schreiber_2017","Tom Schreiber","M","Ohio Machine",93,{goals=18,assists=26}}
})

addVerified("MLL",2010,"mllPoskay",{
    {"mll_poskay_2010","Matt Poskay","A","Boston Cannons",90,{games=12,points=52,goals=45}}
})

addVerified("MLL",2015,"mllMvp2015",{
    {"mll_gurenlian_2015","Greg Gurenlian","FO","New York Lizards",nil,{groundBalls=175}}
})

addVerified("MLL",2019,"mllMvp2019",{
    {"mll_thompson_2019","Lyle Thompson","A","Chesapeake Bayhawks",nil,{games=15,points=73,goals=46,assists=27}}
})

addVerified("MLL",2020,"mllAwards2020",{
    {"mll_wasserman_2020","Bryce Wasserman","A","Boston Cannons",nil,{games=5,goals=14}},
    {"mll_sconone_2020","Sean Sconone","G","Connecticut Hammerheads"},
    {"mll_adler_2020","Max Adler","FO","Denver Outlaws"},
    {"mll_costabile_2020","CJ Costabile","LSM","Chesapeake Bayhawks"}
})

addVerified("MLL",2020,"mllGoodrich2020",{
    {"mll_goodrich_2020","Zach Goodrich","SSDM","Boston Cannons",nil,{games=5,groundBalls=9,causedTurnovers=3}}
})

addVerified("MLL",2014,"mllHall",{
    {"mll_powell_2014","Casey Powell","A","Florida Launch",94}
})

addVerified("MLL",2007,"mllHall",{
    {"mll_striebel_2007","Matt Striebel","M","Philadelphia Barrage",90}
})

addVerified("MLL",2017,"mllCannons2017",{
    {"mll_merrill_2017","Brodie Merrill","D","Boston Cannons",92}
})

addVerified("MLL",2016,"mllOutlaws2016",{
    {"mll_grant_2016","John Grant Jr.","A","Ohio Machine",94}
})

addVerified("NLL","2024-25","nllAwards2025",{
    {"nll_fields_2025","Connor Fields","F","Rochester Knighthawks",94},
    {"nll_smith_2025","Dhane Smith","F","Buffalo Bandits",95},
    {"nll_byrne_2025","Josh Byrne","F","Buffalo Bandits",93},
    {"nll_teat_2025","Jeff Teat","F","Ottawa Black Bears",93},
    {"nll_dilks_2025","Ryan Dilks","D","Vancouver Warriors",87},
    {"nll_de_snoo_2025","Mitch de Snoo","D","Philadelphia Wings",86},
    {"nll_hossack_2025","Graeme Hossack","D","Halifax Thunderbirds",89},
    {"nll_terefenko_2025","Ryan Terefenko","T","Halifax Thunderbirds",88},
    {"nll_vinc_2025","Matt Vinc","G","Buffalo Bandits",93}
})

addVerified("NLL","2024-25","nllPositionAwards2025",{
    {"nll_scigliano_2025","Frank Scigliano","G","Saskatchewan Rush",91,{savePct=79.5}},
    {"nll_matt_hossack_2025","Matt Hossack","D","Saskatchewan Rush",nil,{causedTurnovers=34,looseBalls=129}},
    {"nll_grant_2025","Owen Grant","T","Vancouver Warriors",nil,{causedTurnovers=28,looseBalls=103,points=24,goals=15,assists=9}}
})

addVerified("NLL","2025-26","nllAwards2026",{
    {"nll_bal_2026","Keegan Bal","F","Vancouver Warriors",91,{points=124,goals=45,assists=79}},
    {"nll_currier_2026","Zach Currier","T","San Diego Seals",90,{points=57,goals=22,assists=35,looseBalls=200}},
    {"nll_del_bianco_2026","Christian Del Bianco","G","Vancouver Warriors",92},
    {"nll_dobson_2026","Brett Dobson","G","Georgia Swarm",92,{savePct=84.7}},
    {"nll_jones_2026","Callum Jones","D","Ottawa Black Bears",nil,{causedTurnovers=32,looseBalls=173}}
})

addVerified("NLL","2022-23","nllAwards2023",{
    {"nll_del_bianco_2023","Christian Del Bianco","G","Calgary Roughnecks"}
})

addVerified("NLL","2018-19","nllAwards2019",{
    {"nll_dobbie_2019","Dane Dobbie","F","Calgary Roughnecks",nil,{points=115,goals=47,assists=68,looseBalls=69}},
    {"nll_hossack_2019","Graeme Hossack","D","Rochester Knighthawks"},
    {"nll_rogers_2019","Challen Rogers","T","Toronto Rock"},
    {"nll_vinc_2019","Matt Vinc","G","Buffalo Bandits"},
    {"nll_baptiste_2019","Trevor Baptiste","T","Philadelphia Wings"}
})

addVerified("NLL",2017,"nllAwards2017",{
    {"nll_thompson_2017","Lyle Thompson","F","Georgia Swarm",nil,{points=116,goals=45,assists=71}}
})

addVerified("NLL",2017,"nllSchreiber2017",{
    {"nll_schreiber_2017","Tom Schreiber","F","Toronto Rock",nil,{points=94}}
})

addVerified("NLL","2000-01","nllHistory",{
    {"nll_tavares_2001","John Tavares","F","Buffalo Bandits"}
})

addVerified("NLL","2024-25","nllWard",{
    {"nll_ward_2025","Dillon Ward","G","Colorado Mammoth",90}
})

addVerified("NLL","2023-24","nllAwards2024",{
    {"nll_rose_2024","Nick Rose","G","Toronto Rock",90}
})

-- The Hall of Fame source verifies participation, not a single season affiliation.
addVerified("NLL",nil,"nllHall",{
    {"nll_hall_tavares","John Tavares","F",nil,96},
    {"nll_hall_grant","John Grant Jr.","F",nil,95},
    {"nll_hall_gary_gait","Gary Gait","F",nil,96},
    {"nll_hall_paul_gait","Paul Gait","F",nil,92}
})

-- Review is explicit. A sourced identity alone does not grant pack eligibility.
local recognition = {
    season={label="Regular season statistics",rating=77},
    allStar={label="All-Star selection",rating=84},
    secondTeam={label="Second-team season honors",rating=85},
    finalist={label="Position award finalist",rating=86},
    firstTeam={label="First-team season honors",rating=88},
    rookie={label="Rookie of the Year",rating=86},
    position={label="Position award winner",rating=90},
    championship={label="Championship MVP",rating=90},
    mvp={label="Season MVP",rating=93}
}

local editionsByEvidence = {
    {"season","pll_holman_2026","pll_oneill_2026","pll_carroll_2026","pll_kavanagh_2026",
        "pll_molloy_2026","pll_king_2026","pll_malone_2026","pll_teat_2025"},
    {"allStar","mll_adams_2017","mll_walters_2017","mll_dunn_2017"},
    {"secondTeam","nll_byrne_2025","nll_teat_2025","nll_de_snoo_2025",
        "nll_hossack_2025","nll_terefenko_2025","nll_vinc_2025","nll_del_bianco_2026"},
    {"finalist","pll_rowlett_2025","pll_giles_harris_2025","pll_hossack_2025",
        "pll_riorden_2025","pll_entenmann_2025","pll_baptiste_2025"},
    {"firstTeam","nll_smith_2025","nll_dilks_2025"},
    {"rookie","pll_spallina_2026","nll_schreiber_2017"},
    {"position","pll_sowers_2026","pll_dobson_2026","pll_lavelle_2026","pll_tevlin_2026",
        "pll_mcmeekin_2026","pll_currier_2026","pll_rall_2026","pll_campbell_2025",
        "pll_adler_2025","pll_mcnaney_2025","pll_ierlan_2025","pll_piseno_2025",
        "pll_terefenko_2025","pll_schreiber_2022","mll_sconone_2020","mll_adler_2020",
        "mll_costabile_2020","mll_goodrich_2020","nll_scigliano_2025","nll_matt_hossack_2025","nll_grant_2025","nll_bal_2026",
        "nll_currier_2026","nll_jones_2026","nll_hossack_2019","nll_rogers_2019","nll_vinc_2019"},
    {"championship","pll_dobson_2023"},
    {"mvp","pll_kirst_2026","pll_shellenberger_2025","pll_teat_2024","pll_baptiste_2022",
        "pll_riorden_2021","mll_poskay_2010","mll_gurenlian_2015","mll_schreiber_2017",
        "mll_thompson_2019","mll_wasserman_2020","nll_fields_2025","nll_dobson_2026",
        "nll_del_bianco_2023","nll_dobbie_2019","nll_thompson_2017","nll_tavares_2001"}
}

local extraEvidence = {
    pll_sowers_2026=Catalog.sources.pllAwards2026,
    mll_wasserman_2020=Catalog.sources.mllDraftReview2021,
    nll_schreiber_2017=Catalog.sources.nllAwards2017
}

-- Produce small role-specific tuning offsets even when a source gives an honor only.
local function gameProfile(record)
    local s = record.stats or {}
    local position = record.position
    local box = record.league == "NLL"
    local ground = math.min(3,math.floor((s.groundBalls or s.looseBalls or 0)/(box and 60 or 20)))
    if position == "FO" then
        local impact = math.min(5,math.max(0,math.floor(((s.faceoffPct or 50)-50)/3)))
        return math.max(impact,ground),{faceoff=3+impact,groundBalls=2+ground}
    elseif position == "G" then
        local typical = box and 76 or 51
        local impact = math.min(5,math.max(0,math.floor(((s.savePct or typical)-typical)/1.5)))
        return impact,{reflexes=3+impact,goaliePositioning=3,passing=1}
    elseif position == "D" or position == "LSM" or position == "SSDM" then
        local impact = math.min(5,math.floor((s.causedTurnovers or 0)/(box and 6 or 3)))
        return math.max(impact,ground),{
            stickCheck=2+impact,defensiveAwareness=3,groundBalls=1+ground,
            speed=position~="D" and 2 or 0
        }
    end
    local impact = math.min(5,math.floor((s.points or s.goals or 0)/(box and 23 or 10)))
    local creator = (s.assists or 0) > (s.goals or 0)
    if position == "M" or position == "T" then
        return math.max(impact,ground),{
            passing=creator and 4 or 2,stamina=3,groundBalls=1+ground,shotAccuracy=1+impact
        }
    end
    return impact,{passing=creator and 3+impact or 1,shotAccuracy=creator and 2 or 3+impact,ballControl=2}
end

local included = {}
for _,group in ipairs(editionsByEvidence) do
    local reason = recognition[group[1]]
    for index=2,#group do
        local recordId = group[index]
        local record = assert(verifiedById[recordId],"Missing verified edition: "..recordId)
        assert(record.season and record.team and record.source,"Incomplete verified edition: "..recordId)
        local impact, attributes = gameProfile(record)
        local edition = {
            id="edition_"..recordId, recordId=record.id,
            identity="player:"..record.name:lower():gsub("[^%w]",""),
            name=record.name, league=record.league, team=record.team,
            season=record.season, position=record.position, source=record.source,
            stats=record.stats, evidence={kind=group[1],description=reason.label,source=record.source,
                corroboration=extraEvidence[recordId]},
            rating=math.min(98,reason.rating+impact), ratingVersion=Catalog.ratingVersion, attributes=attributes,
            verification="verified", ratingStatus="fictional", playable=true
        }
        assert(not included[recordId],"Duplicate verified edition: "..recordId)
        included[recordId] = true
        Catalog.players[#Catalog.players+1] = edition
        Catalog.editions[#Catalog.editions+1] = edition
        playableById[edition.id] = edition
    end
end

-- Names carried over from the earlier editorial queue. Unresolved season and
-- club identities stay here. These IDs are never minted as playable cards.
local candidates = {
    {"research_pll_1","Jeff Teat","PLL","A"},
    {"research_pll_2","Lyle Thompson","PLL","A"},
    {"research_pll_3","Asher Nolting","PLL","A"},
    {"research_pll_4","Connor Fields","PLL","A"},
    {"research_pll_5","Matt Rambo","PLL","A"},
    {"research_pll_6","Grant Ament","PLL","A"},
    {"research_pll_7","Zed Williams","PLL","A"},
    {"research_pll_8","Rob Pannell","PLL","A"},
    {"research_pll_9","Tom Schreiber","PLL","M"},
    {"research_pll_10","Romar Dennis","PLL","M"},
    {"research_pll_11","Ryan Conrad","PLL","M"},
    {"research_pll_12","Dox Aitken","PLL","M"},
    {"research_pll_13","Trevor Baptiste","PLL","M"},
    {"research_pll_14","TD Ierlan","PLL","M"},
    {"research_pll_15","Mike Sisselberger","PLL","M"},
    {"research_pll_16","JT Giles-Harris","PLL","D"},
    {"research_pll_17","Gavin Adler","PLL","D"},
    {"research_pll_18","Matt Dunn","PLL","D"},
    {"research_pll_19","Jack Rowlett","PLL","D"},
    {"research_pll_20","Michael Ehrhardt","PLL","D"},
    {"research_pll_21","Graeme Hossack","PLL","D"},
    {"research_pll_22","Blaze Riorden","PLL","G"},
    {"research_pll_23","Jack Kelly","PLL","G"},
    {"research_pll_24","Colin Kirst","PLL","G"},
    {"research_pll_25","Brett Dobson","PLL","G"},
    {"research_mll_26","Paul Rabil","MLL","M"},
    {"research_mll_27","John Grant Jr.","MLL","A"},
    {"research_mll_28","Casey Powell","MLL","A"},
    {"research_mll_29","Ryan Powell","MLL","A"},
    {"research_mll_30","Mikey Powell","MLL","A"},
    {"research_mll_31","John Tavares","MLL","A"},
    {"research_mll_32","Matt Poskay","MLL","A"},
    {"research_mll_33","Kevin Leveille","MLL","A"},
    {"research_mll_34","Brendan Mundorf","MLL","A"},
    {"research_mll_35","Steele Stanwick","MLL","A"},
    {"research_mll_36","Kyle Harrison","MLL","M"},
    {"research_mll_37","Matt Striebel","MLL","M"},
    {"research_mll_38","Max Seibald","MLL","M"},
    {"research_mll_39","Paul Gait","MLL","M"},
    {"research_mll_40","Gary Gait","MLL","M"},
    {"research_mll_41","Joe Walters","MLL","M"},
    {"research_mll_42","Brodie Merrill","MLL","D"},
    {"research_mll_43","Nicky Polanco","MLL","D"},
    {"research_mll_44","Kyle Hartzell","MLL","D"},
    {"research_mll_45","Lee Zink","MLL","D"},
    {"research_mll_46","Jesse Schwartzman","MLL","G"},
    {"research_mll_47","Drew Adams","MLL","G"},
    {"research_mll_48","Brian Dougherty","MLL","G"},
    {"research_nll_49","Dhane Smith","NLL","F"},
    {"research_nll_50","Josh Byrne","NLL","F"},
    {"research_nll_51","Chris Cloutier","NLL","F"},
    {"research_nll_52","Ryan Smith","NLL","F"},
    {"research_nll_53","Shayne Jackson","NLL","F"},
    {"research_nll_54","Randy Staats","NLL","F"},
    {"research_nll_55","Austin Staats","NLL","F"},
    {"research_nll_56","Curtis Dickson","NLL","F"},
    {"research_nll_57","Cody Jamieson","NLL","F"},
    {"research_nll_58","Mark Matthews","NLL","F"},
    {"research_nll_59","Callum Crawford","NLL","F"},
    {"research_nll_60","Rob Hellyer","NLL","F"},
    {"research_nll_61","Tom Schreiber","NLL","F"},
    {"research_nll_62","Lyle Thompson","NLL","F"},
    {"research_nll_63","Jeff Teat","NLL","F"},
    {"research_nll_64","John Tavares","NLL","F"},
    {"research_nll_65","Dan Dawson","NLL","F"},
    {"research_nll_66","Shawn Evans","NLL","F"},
    {"research_nll_67","Colin Doyle","NLL","F"},
    {"research_nll_68","John Grant Jr.","NLL","F"},
    {"research_nll_69","Gary Gait","NLL","F"},
    {"research_nll_70","Paul Gait","NLL","F"},
    {"research_nll_71","Zach Currier","NLL","T"},
    {"research_nll_72","Tyler Pace","NLL","T"},
    {"research_nll_73","Graeme Hossack","NLL","D"},
    {"research_nll_74","Brodie Merrill","NLL","D"},
    {"research_nll_75","Steve Priolo","NLL","D"},
    {"research_nll_76","Matt Beers","NLL","D"},
    {"research_nll_77","Matt Vinc","NLL","G"},
    {"research_nll_78","Christian Del Bianco","NLL","G"},
    {"research_nll_79","Dillon Ward","NLL","G"},
    {"research_nll_80","Nick Rose","NLL","G"},
    {"research_nll_81","Doug Jamieson","NLL","G"},
    {"research_nll_82","Mike Poulin","NLL","G"},
}
for _,row in ipairs(candidates) do
    if not verifiedIdentities[row[3].."/"..row[2]] then
        Catalog.researchCandidates[#Catalog.researchCandidates+1] = {
            id=row[1], name=row[2], league=row[3], position=row[4],
            verification="pending", playable=false
        }
    end
end

-- Hand-picked game colors and generic designs. No badge, team mark or jersey goes here.
Catalog.kits = {
    {id="field_violet",name="Violet Field",league="PLL",era="modern",home={34,30,73},away={228,222,241},accent={202,158,64}},
    {id="field_coastal",name="Coastal Field",league="PLL",era="modern",home={17,77,92},away={229,238,237},accent={94,194,177}},
    {id="heritage_navy",name="Heritage Navy",league="MLL",era="throwback",home={28,44,71},away={232,235,241},accent={191,143,65}},
    {id="heritage_crimson",name="Heritage Crimson",league="MLL",era="throwback",home={107,31,49},away={244,231,229},accent={217,171,94}},
    {id="box_midnight",name="Midnight Box",league="NLL",era="indoor",home={27,28,37},away={222,223,231},accent={221,114,47}},
    {id="box_ice",name="Ice Box",league="NLL",era="indoor",home={23,67,113},away={225,241,250},accent={97,188,226}}
}

local kitsById = {}
for _,kit in ipairs(Catalog.kits) do
    kitsById[kit.id] = kit
end

function Catalog.find(id)
    return playableById[id]
end

function Catalog.kit(id)
    return kitsById[id]
end

function Catalog.verified(league)
    local records = {}
    for _,player in ipairs(Catalog.realPlayers) do
        if not league or player.league == league then
            records[#records+1] = player
        end
    end
    return records
end

