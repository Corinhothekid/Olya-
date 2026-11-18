-- PolyLax Build 012 | School identity and venue paint
PolyLax = PolyLax or {}
local SchoolTeams = {}
PolyLax.SchoolTeams = SchoolTeams

local white = color(247, 249, 252)
local competition = {ncaa="NCAA DIVISION I", club="MCLA CLUB", highSchool="HIGH SCHOOL"}

local function swatch(value)
    return color(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

local function school(id, name, short, group, colors, labels, source)
    local primary = swatch(colors.primary)
    local secondary = swatch(colors.secondary)
    local accent = colors.accent and swatch(colors.accent) or secondary
    local shell = colors.shell and swatch(colors.shell) or primary
    local number = colors.number and swatch(colors.number) or white
    return {
        id=id, name=name, short=short, group=group, competition=competition[group],
        fictional=group == "highSchool", colorSource=source,
        fieldType=group, ruleset=group == "highSchool" and "highSchool" or "adult",
        home={teamId=id, primary=primary, secondary=secondary, shorts=primary,
            shell=shell, accent=accent, gloves=shell, number=number},
        away={teamId=id, primary=white, secondary=primary, shorts=white,
            shell=shell, accent=accent, gloves=shell, number=colors.number and number or primary},
        field={id=id, wordmark=labels[1], endWordmark=labels[2], centerWordmark=labels[3] or short,
            primary=primary, accent=accent, lettering=colors.number and number or nil}
    }
end

-- Official brand hex values where documented. Kit combinations and lettering
-- are original game designs. The color references contain the real identities.
SchoolTeams.ncaa = {
    school("syracuse", "Syracuse", "SYR", "ncaa",
        {primary=0xF76900, secondary=0x000E54, shell=0x000E54, number=0x000E54},
        {"SYRACUSE", "ORANGE", "SYRACUSE"},
        "https://answers.atlassian.syr.edu/wiki/spaces/SOE/pages/149782933/Quick+Guide+-+SOE+Logos+and+Branded+Materials"),
    school("duke", "Duke", "DUK", "ncaa",
        {primary=0x012169, secondary=0xFFFFFF, accent=0x00539B},
        {"DUKE", "BLUE DEVILS", "DUKE"}, "https://brand.duke.edu/colors/"),
    school("virginia", "Virginia", "UVA", "ncaa",
        {primary=0x232D4B, secondary=0xE57200},
        {"VIRGINIA", "CAVALIERS", "VIRGINIA"}, "https://brand.virginia.edu/design-assets/colors"),
    school("maryland", "Maryland", "UMD", "ncaa",
        {primary=0xE21833, secondary=0xFFD200, shell=0x191D24},
        {"MARYLAND", "TERRAPINS", "MARYLAND"}, "https://brand.umd.edu/visual-identity/colors"),
    school("johns-hopkins", "Johns Hopkins", "JHU", "ncaa",
        {primary=0x002D72, secondary=0x68ACE5, shell=0xFFFFFF},
        {"JOHNS HOPKINS", "BLUE JAYS", "HOPKINS"}, "https://brand.jhu.edu/visual-identity/colors/"),
    school("notre-dame", "Notre Dame", "ND", "ncaa",
        {primary=0x0C2340, secondary=0xC99700, shell=0xC99700},
        {"NOTRE DAME", "FIGHTING IRISH", "NOTRE DAME"}, "https://onmessage.nd.edu/athletics-branding/colors/"),
    school("north-carolina", "North Carolina", "UNC", "ncaa",
        {primary=0x4B9CD3, secondary=0x13294B, shell=0xFFFFFF, number=0x13294B},
        {"NORTH CAROLINA", "TAR HEELS", "CAROLINA"},
        "https://innovate.unc.edu/app/uploads/2024/04/Brand-guide-2024.pdf"),
    school("penn-state", "Penn State", "PSU", "ncaa",
        {primary=0x001E44, secondary=0xFFFFFF, shell=0xFFFFFF},
        {"PENN STATE", "NITTANY LIONS", "PENN STATE"},
        "https://brand.psu.edu/visual-identity-standards/color-and-the-mark"),
    school("cornell", "Cornell", "COR", "ncaa",
        {primary=0xB31B1B, secondary=0xFFFFFF, shell=0xFFFFFF},
        {"CORNELL", "BIG RED", "CORNELL"}, "https://cals.cornell.edu/faculty-staff/marketing-communications/resources/brand-guide/visual-identity/color-typography")
}

SchoolTeams.club = {
    school("florida-state", "Florida State", "FSU", "club",
        {primary=0x782F40, secondary=0xCEB888, shell=0xCEB888},
        {"FLORIDA STATE", "STATE LACROSSE", "FLORIDA STATE"}, "https://brand.fsu.edu/web/colors")
}
SchoolTeams.club[1].teamSource = "https://campusrec.fsu.edu/activities/club-lacrosse-men/"

SchoolTeams.highSchool = {
    school("briarbank", "Briarbank Academy", "BBA", "highSchool",
        {primary=0x244C37, secondary=0xD5B25C}, {"BRIARBANK", "TIMBER OWLS"}),
    school("alderwick", "Alderwick High", "AWK", "highSchool",
        {primary=0x623582, secondary=0xDFC8F4}, {"ALDERWICK", "STORM"}),
    school("stonehaven-ridge", "Stonehaven Ridge High", "SRH", "highSchool",
        {primary=0x283443, secondary=0xE6792F}, {"STONEHAVEN RIDGE", "RIDGEBACKS", "STONEHAVEN"}),
    school("west-fen", "West Fen Academy", "WFA", "highSchool",
        {primary=0x237681, secondary=0xF0D19C}, {"WEST FEN", "HERONS"}),
    school("juniper-reach", "Juniper Reach High", "JRH", "highSchool",
        {primary=0xA94237, secondary=0xFFE0A4}, {"JUNIPER REACH", "COPPERHEADS", "JUNIPER"}),
    school("foxmere", "Foxmere High", "FXM", "highSchool",
        {primary=0x203C72, secondary=0x79D4A2}, {"FOXMERE", "LAKE FOXES"})
}

SchoolTeams.college = {}
local byId, aliases = {}, {uva="virginia", nd="notre-dame"}
for _, group in ipairs({SchoolTeams.ncaa, SchoolTeams.club, SchoolTeams.highSchool}) do
    for _, team in ipairs(group) do
        byId[team.id], aliases[team.short:lower()] = team, team.id
        if team.group ~= "highSchool" then
            SchoolTeams.college[#SchoolTeams.college+1] = team
        end
    end
end

function SchoolTeams.get(id)
    if type(id) ~= "string" then return end
    local key = id:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%s_]+", "-")
    return byId[key] or byId[aliases[key]]
end

function SchoolTeams.defaultOpponent(id)
    local home = SchoolTeams.get(id)
    if not home then return end
    local candidates = home.group == "highSchool" and SchoolTeams.highSchool or SchoolTeams.ncaa
    for _, team in ipairs(candidates) do
        if team.id ~= home.id then return team end
    end
end
