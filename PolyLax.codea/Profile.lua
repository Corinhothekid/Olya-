-- PolyLax Build 011 Gameplay | Profile
PolyLax = PolyLax or {}
local Profile = {}
PolyLax.Profile = Profile

local gear = {"WHITE", "BLUE", "RED", "BLACK", "GREEN", "GOLD"}
local teamChoices = {}

Profile.categories = {
    {key="FACE", choices={"FACE 1", "FACE 2", "FACE 3", "FACE 4"}, default=2},
    {key="HAIR", choices={"NONE", "CLASSIC 1", "CLASSIC 2", "CLASSIC 3", "CLASSIC 4", "CLASSIC 5"}, default=3},
    {key="BEARD", choices={"CLEAN", "STUBBLE", "MUSTACHE", "GOATEE", "SHORT", "FULL"}, default=1},
    {key="BODY", choices={"LEAN", "ATHLETIC", "STOCKY", "TALL"}, default=2},
    {key="HELMET", choices={
        "WHITE", "BLUE", "RED", "BLACK", "GREEN", "GOLD", "SILVER CHROME",
        "BLUE CHROME", "GOLD CHROME", "RED CHROME", "BLACK CHROME"
    }, default=1},
    {key="TEAM", choices=teamChoices, default=1},
    {key="GLOVES", choices=gear, default=1},
    {key="SHORTS", choices=gear, default=4},
    {key="CLEATS", choices=gear, default=1},
    {key="STICK", choices=gear, default=1},
    {key="NUMBER", choices={}, default=4},
    {key="SLEEVES", label="LEG SLEEVES", choices={
        "OFF", "WHITE", "BLACK", "TEAM", "WHITE LEFT", "WHITE RIGHT", "BLACK LEFT", "BLACK RIGHT"
    }, default=1},
    {key="HOODIE", choices={"OFF", "TEAM", "WHITE", "BLACK"}, default=1},
    {key="OPPONENT", label="OPPONENT", choices=teamChoices, default=2}
}

local numberChoices = Profile.categories[11].choices
for number = 0, 99 do
    numberChoices[number + 1] = tostring(number)
end

local function storageKey(category)
    return "PolyLax.Profile." .. category.key
end

function Profile.setTeamOptions(teams)
    for _, team in ipairs(teams) do teamChoices[team.id] = team.name end
end

if PolyLax.TeamUniform then Profile.setTeamOptions(PolyLax.TeamUniform.teams) end

local function nextTeam(index, direction)
    return (index - 1 + direction) % #teamChoices + 1
end

local function saveChoice(profile, key, index)
    profile[key] = index
    saveLocalData("PolyLax.Profile." .. key, index)
end

function Profile.load()
    local profile = {}
    for _, category in ipairs(Profile.categories) do
        local index = tonumber(readLocalData(storageKey(category)))
        if not index and category.key == "TEAM" then
            local previousJersey = readLocalData("PolyLax.Profile.JERSEY")
            index = PolyLax.TeamUniform.legacyTeam(previousJersey)
        end
        if not index or index % 1 ~= 0 or index < 1 or index > #category.choices then
            index = category.default
        end
        profile[category.key] = index
    end
    if profile.OPPONENT == profile.TEAM then
        profile.OPPONENT = nextTeam(profile.TEAM, 1)
    end
    return profile
end

function Profile.select(profile, category, index)
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #category.choices then
        return
    end
    local key = category.key
    if key == "TEAM" and index == profile.OPPONENT then
        saveChoice(profile, "OPPONENT", profile.TEAM)
    elseif key == "OPPONENT" and index == profile.TEAM then
        local direction = profile.OPPONENT == nextTeam(index, 1) and -1 or 1
        index = nextTeam(index, direction)
    end
    saveChoice(profile, key, index)
end
