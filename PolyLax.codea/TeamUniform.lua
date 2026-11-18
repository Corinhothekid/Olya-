-- PolyLax Build 012 | Shared team uniforms
PolyLax = PolyLax or {}
local P = PolyLax
local TeamUniform = {}
P.TeamUniform = TeamUniform

local white = color(240, 243, 245)
local dark = color(26, 29, 37)
local orange = color(239, 103, 32)
local navy = color(22, 43, 77)
local atlasBlue = color(143, 198, 230)
local red = color(204, 36, 55)
local green = color(23, 77, 65)
local gold = color(223, 174, 62)
local violet = color(109, 70, 161)
local lavender = color(186, 165, 218)
local teal = color(70, 169, 164)

local function kit(primary, secondary, shorts, shell, accent, gloves, number)
    return {
        primary = primary, secondary = secondary, shorts = shorts, shell = shell,
        accent = accent, gloves = gloves, number = number
    }
end

-- PLL Shop's 2026 replicas verify the named home and away jersey colors.
-- RGB swatches and gameplay equipment pairings are visual approximations.
local function team(id, name, short, shopSlug, homeColor, home, away)
    home.teamId, away.teamId = id, id
    return {
        id = id, name = name, short = short,
        namedHomeColor = homeColor, namedAwayColor = "White",
        colorSource = "https://shop.premierlacrosseleague.com/products/" ..
            shopSlug .. "-2026-nike-replica-player-jersey",
        approximateRGB = true,
        fieldType = "professional", ruleset = "adult",
        field = {id=id, wordmark=name:match(" (%S+)$"), endWordmark=name:match("^(.*) %S+$"),
            centerWordmark=short, primary=home.primary, secondary=home.secondary,
            accent=home.accent, lettering=home.number},
        home = home, away = away
    }
end

TeamUniform.teams = {
    team(1, "Utah Archers", "ARC", "utah-archers", "Orange",
        kit(orange, navy, navy, navy, orange, navy, white),
        kit(white, navy, white, navy, orange, white, navy)),
    team(2, "New York Atlas", "ATL", "new-york-atlas", "Light Blue",
        kit(atlasBlue, navy, atlasBlue, navy, atlasBlue, navy, navy),
        kit(white, atlasBlue, white, navy, atlasBlue, white, navy)),
    team(3, "Boston Cannons", "CAN", "boston-cannons", "Navy",
        kit(navy, red, navy, navy, red, navy, white),
        kit(white, navy, white, navy, red, white, navy)),
    team(4, "Carolina Chaos", "CHA", "carolina-chaos", "Red",
        kit(red, dark, dark, dark, red, red, white),
        kit(white, red, white, dark, red, white, dark)),
    team(5, "Denver Outlaws", "OUT", "denver-outlaws", "Black",
        kit(dark, orange, dark, dark, orange, dark, white),
        kit(white, orange, white, dark, orange, white, dark)),
    team(6, "California Redwoods", "RED", "california-redwoods", "Dark Green",
        kit(green, gold, green, green, gold, green, gold),
        kit(white, green, white, green, gold, white, green)),
    team(7, "Philadelphia Waterdogs", "WAT", "philadelphia-waterdogs", "Purple",
        kit(violet, lavender, violet, dark, lavender, lavender, white),
        kit(white, violet, white, dark, lavender, white, violet)),
    team(8, "Maryland Whipsnakes", "WHI", "maryland-whipsnakes", "Black",
        kit(dark, red, dark, dark, teal, white, white),
        kit(white, red, white, dark, teal, white, dark))
}

-- Stored jersey indices were green, blue, red, white, black, and gold.
local priorJerseyTeams = {6, 3, 4, 2, 5, 1}

local function findTeam(id)
    return TeamUniform.teams[tonumber(id)] or (P.SchoolTeams and P.SchoolTeams.get(id))
end

function TeamUniform.get(id)
    return findTeam(id) or TeamUniform.teams[1]
end

function TeamUniform.legacyTeam(jersey)
    return priorJerseyTeams[tonumber(jersey)] or 1
end

function TeamUniform.fromProfile(profile)
    profile = profile or {}
    if profile.TEAM then return TeamUniform.get(profile.TEAM).home end
    return TeamUniform.get(TeamUniform.legacyTeam(profile.JERSEY)).home
end

local function contrast(a, b)
    local dr, dg, db = a.r - b.r, a.g - b.g, a.b - b.b
    return 2 * dr * dr + 4 * dg * dg + 3 * db * db
end

function TeamUniform.opponent(homeKit, opponentId)
    local homeId = homeKit.teamId
    local opponent = findTeam(opponentId)
    if not opponent or opponent.id == homeId then
        local school = P.SchoolTeams and P.SchoolTeams.defaultOpponent(homeId)
        local number = tonumber(homeId)
        if school then
            opponent = school
        elseif number and opponent then
            opponent = TeamUniform.teams[number % #TeamUniform.teams + 1]
        else
            opponent = TeamUniform.teams[number == 2 and 3 or 2]
        end
    end
    local away, home = opponent.away, opponent.home
    -- The away club may use its colored jersey if white would clash.
    if contrast(homeKit.primary, away.primary) < 30000
        and contrast(homeKit.primary, home.primary) > contrast(homeKit.primary, away.primary) then
        return home
    end
    return away
end

function TeamUniform.matchKits(homeId, awayId)
    local home = TeamUniform.get(homeId)
    local awayKit = TeamUniform.opponent(home.home, awayId)
    return home.home, awayKit, home, TeamUniform.get(awayKit.teamId)
end

function TeamUniform.forKeeper(uniform, role, opponentId)
    if role == "friendly" then return uniform end
    return TeamUniform.opponent(uniform, opponentId)
end

if P.Profile then P.Profile.setTeamOptions(TeamUniform.teams) end
