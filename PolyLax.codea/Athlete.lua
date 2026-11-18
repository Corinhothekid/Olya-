-- PolyLax 2.0 | Career athlete identity and appearance
PolyLax = PolyLax or {}
local P = PolyLax
local Athlete = {}
P.Athlete = Athlete

local minimumHeight, maximumHeight = 64, 82
local defaultHeights = {70, 72, 72, 79}
Athlete.nameLimit = 18
local appearanceSchema = 1
local heightChoices = {}
for inches = minimumHeight, maximumHeight do
    heightChoices[#heightChoices + 1] = string.format("%d'%d\"", math.floor(inches/12), inches % 12)
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function option(value, count)
    value = tonumber(value)
    if value and value % 1 == 0 and value >= 1 and value <= count then return value end
end

local function cleanName(value)
    if type(value) ~= "string" then return "" end
    value = value:gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local stop = math.min(#value, Athlete.nameLimit)
    while stop > 0 and stop < #value do
        local nextByte = value:byte(stop + 1)
        if nextByte < 128 or nextByte >= 192 then break end
        stop = stop - 1
    end
    local cut = value:sub(1, stop):gsub("%s+$", "")
    if utf8 and not utf8.len(cut) then return "" end
    return cut
end

local function storedAppearance(career)
    return type(career.appearance) == "table" and career.appearance or {}
end

function Athlete.names(career)
    local appearance = storedAppearance(career)
    local legacy = type(career.name) == "string" and career.name or "New Player"
    local first, last = legacy:match("^%s*(%S+)%s*(.-)%s*$")
    local savedFirst = cleanName(appearance.firstName)
    if savedFirst == "" then savedFirst = cleanName(first) end
    local savedLast = type(appearance.lastName) == "string" and appearance.lastName or last
    return savedFirst ~= "" and savedFirst or "New", cleanName(savedLast)
end

function Athlete.name(career)
    local first, last = Athlete.names(career)
    return last == "" and first or first .. " " .. last
end

local function isAppearance(category)
    return category.key ~= "TEAM" and category.key ~= "OPPONENT"
end

function Athlete.profile(career, fallback)
    local saved = storedAppearance(career)
    fallback = fallback or {}
    local profile = {TEAM=career.team}
    for _, category in ipairs(P.Profile.categories) do
        if isAppearance(category) then
            local key, count = category.key, #category.choices
            profile[key] = option(saved[key], count) or option(fallback[key], count) or category.default
        end
    end
    local height = defaultHeights[profile.BODY] or 72
    profile.HEIGHT = option(saved.HEIGHT, #heightChoices) or height - minimumHeight + 1
    return profile
end

function Athlete.heightInches(profile)
    local index = option(profile.HEIGHT, #heightChoices)
    return index and minimumHeight + index - 1
end

function Athlete.heightScale(profile)
    local inches = Athlete.heightInches(profile)
    return inches and inches / 72
end

function Athlete.canChange(career, locked)
    return not locked and career.stage == "highSchool" and (career.games or 0) == 0
end

function Athlete.categories(career, locked)
    local base = {}
    for _, category in ipairs(P.Profile.categories) do base[category.key] = category end
    local positions, positionValues = {}, {}
    local mutable = Athlete.canChange(career, locked)
    for index, position in ipairs(P.Career.positions) do
        if mutable or index == career.position then
            positions[#positions + 1], positionValues[#positionValues + 1] = position.label, index
        end
    end
    local teams, teamValues = {}, {}
    if mutable then
        for _, school in ipairs(P.SchoolTeams.highSchool) do
            teams[#teams + 1], teamValues[#teamValues + 1] = school.name, school.id
        end
    else
        local current = P.TeamUniform.get(career.team)
        teams[1], teamValues[1] = current.name, current.id
    end
    return {
        {key="IDENTITY", choices={"FIRST NAME", "LAST NAME"}, default=1},
        {key="POSITION", choices=positions, values=positionValues, default=1},
        {key="HEIGHT", choices=heightChoices, default=9},
        {key="BODY", label="BUILD", choices={"LEAN", "ATHLETIC", "STOCKY", "SLIM"}, default=2},
        {key="TEAM", label="TEAM", choices=teams, values=teamValues, default=1},
        base.NUMBER, base.FACE, base.HAIR, base.BEARD,
        {key="HELMET", choices={"TEAM","STEEL","DARK","ACCENT","SATIN","MATTE",
            "CHROME","DARK CHROME","BRIGHT CHROME","SATIN CHROME","ACCENT CHROME"},default=1},
        {key="GLOVES", choices={"TEAM","STEEL TRIM","ACCENT","DARK CUFF","SATIN","MATTE"},default=1},
        base.SHORTS,
        base.CLEATS, base.STICK, base.SLEEVES, base.HOODIE
    }
end

function Athlete.choice(career, profile, category)
    if category.values then
        local value = category.key == "POSITION" and career.position or career.team
        for index, available in ipairs(category.values) do
            if value == available then return index end
        end
        return 1
    end
    return option(profile[category.key], #category.choices) or category.default
end

local function draft(career, fallback)
    local candidate = copy(career)
    local saved = copy(storedAppearance(career))
    local profile = Athlete.profile(career, fallback)
    for key, value in pairs(profile) do
        if key ~= "TEAM" then saved[key] = value end
    end
    saved.schema = appearanceSchema
    saved.firstName, saved.lastName = Athlete.names(career)
    candidate.appearance, candidate.name = saved, Athlete.name(career)
    return candidate
end

local function commit(career, candidate)
    if not P.Career.save(candidate) then return false, "Could not save appearance" end
    for key in pairs(career) do
        if candidate[key] == nil then career[key] = nil end
    end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

function Athlete.ensure(career, fallback)
    if storedAppearance(career).schema == appearanceSchema then
        career.name = Athlete.name(career)
        return true
    end
    return commit(career, draft(career, fallback))
end

function Athlete.rename(career, fallback, part, value)
    if part ~= "first" and part ~= "last" then return false end
    local clean = cleanName(value)
    if part == "first" and clean == "" then return false, "Enter a first name" end
    local candidate = draft(career, fallback)
    candidate.appearance[part == "first" and "firstName" or "lastName"] = clean
    candidate.name = Athlete.name(candidate)
    return commit(career, candidate)
end

function Athlete.select(career, fallback, category, index, locked)
    index = option(index, #category.choices)
    if not index or category.key == "IDENTITY" then return false end
    local key = category.key
    local candidate = draft(career, fallback)
    if key == "POSITION" or key == "TEAM" then
        local value = category.values and category.values[index]
        if not value then return false end
        if not Athlete.canChange(career, locked) then
            return false, key == "TEAM" and "Team changes follow recruiting" or "Position is locked"
        end
        if key == "POSITION" then
            if value == career.position then return Athlete.ensure(career, fallback) end
            if not P.Career.setPosition(candidate, value) then return false, "Could not save position" end
            for name, item in pairs(candidate) do career[name] = item end
            return true
        end
        local school = P.SchoolTeams.get(value)
        if not school or school.group ~= "highSchool" then return false, "Choose a high school" end
        if candidate.team ~= school.id then
            candidate.team, candidate.seasonData = school.id, nil
        end
    elseif key == "HEIGHT" or candidate.appearance[key] ~= nil then
        candidate.appearance[key] = index
    else
        return false
    end
    return commit(career, candidate)
end

function Athlete.uniform(career, isAway)
    local team = P.TeamUniform.get(career.team)
    return isAway and team.away or team.home
end
