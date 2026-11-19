-- PolyLax 2.0 | Player attributes
PolyLax = PolyLax or {}
local A = {}
PolyLax.Attributes = A

local descriptors = {
    {key="speed", label="Speed", description="Top running speed", value=61, group="Athletic"},
    {key="acceleration", label="Acceleration", description="How quickly the player reaches speed", value=60, group="Athletic"},
    {key="agility", label="Agility", description="Turning speed and dodge control", value=60, group="Athletic"},
    {key="stamina", label="Stamina", description="Sprint endurance and recovery", value=60, group="Athletic"},
    {key="strength", label="Strength", description="Body-contact leverage and planted pick stability", value=60, group="Athletic"},
    {key="shotPower", label="Shot Power", description="Shot release velocity", value=57, group="Offense"},
    {key="shotAccuracy", label="Shot Accuracy", description="Shot placement under motion and pressure", value=57, group="Offense"},
    {key="passing", label="Passing", description="Pass and outlet pace and placement", value=58, group="Offense"},
    {key="ballControl", label="Ball Control", description="Catch range and stick protection", value=58, group="Offense"},
    {key="groundBalls", label="Ground Balls", description="Scoop reach and timing", value=58, group="Offense"},
    {key="stickCheck", label="Stick Check", description="Poke and slap check timing and effectiveness", value=56, group="Defense"},
    {key="bodyCheck", label="Body Check", description="Effectiveness of legal body checks", value=56, group="Defense"},
    {key="defensiveAwareness", label="Defensive Awareness", description="Reading passing lanes and reacting to interceptions", value=58, group="Defense"},
    {key="lacrosseIQ", label="Lacrosse IQ", description="AI reads, spacing and cut choices", value=60, group="Tactics"},
    {key="faceoff", label="Faceoff", description="Draw timing and clamp strength", value=51, group="Tactics"},
    {key="reflexes", label="Reflexes", description="Goalkeeper response and save speed", value=55, group="Goalkeeping"},
    {key="goaliePositioning", label="Goalie Positioning", description="Goalkeeper arc, coverage and lateral positioning", value=57, group="Goalkeeping"}
}
A.descriptors = descriptors

local keys, descriptorByKey = {}, {}
for index, descriptor in ipairs(descriptors) do
    keys[index] = descriptor.key
    descriptorByKey[descriptor.key] = descriptor
end
A.keys = keys

local aliases = {
    shooting="shotPower", ballSecurity="ballControl",
    reaction="defensiveAwareness", interception="defensiveAwareness",
    handSpeed="reflexes", clearingAccuracy="passing"
}

local legacy = {
    shotPower={"shooting"}, shotAccuracy={"shooting"}, ballControl={"ballSecurity"},
    defensiveAwareness={"interception", "reaction"}, reflexes={"handSpeed"},
    passing={"clearingAccuracy"}
}

local presets = {
    {speed=69, acceleration=65, agility=70, strength=64, shotPower=68, shotAccuracy=68,
        passing=62, ballControl=67, lacrosseIQ=63},
    {speed=72, acceleration=67, agility=65, stamina=71, passing=65, strength=66,
        groundBalls=64, lacrosseIQ=63},
    {agility=64, stickCheck=72, bodyCheck=70, defensiveAwareness=70, strength=73,
        groundBalls=66, lacrosseIQ=65},
    {acceleration=70, faceoff=76, defensiveAwareness=69, stamina=70, strength=70,
        groundBalls=67},
    {reflexes=75, goaliePositioning=74, passing=68, strength=62, lacrosseIQ=64},
    {speed=70, acceleration=67, stamina=70, groundBalls=69, stickCheck=73, defensiveAwareness=71},
    {speed=69, acceleration=68, agility=70, stamina=71, bodyCheck=70, defensiveAwareness=72}
}

local weights = {
    {shotPower=5, shotAccuracy=5, speed=3, acceleration=2, agility=3,
        passing=3, ballControl=4, groundBalls=1, lacrosseIQ=3},
    {speed=4, acceleration=3, agility=3, stamina=5, shotPower=2, shotAccuracy=2,
        passing=4, ballControl=3, groundBalls=3, stickCheck=1, lacrosseIQ=3},
    {speed=2, acceleration=2, agility=3, strength=3, groundBalls=2, stickCheck=5,
        bodyCheck=4, defensiveAwareness=5, lacrosseIQ=3, passing=2},
    {faceoff=8, acceleration=3, stamina=4, strength=4, ballControl=2,
        groundBalls=4, defensiveAwareness=3, lacrosseIQ=2},
    {reflexes=8, goaliePositioning=8, passing=4, agility=2, acceleration=2,
        ballControl=2, strength=1, lacrosseIQ=3},
    {speed=4, acceleration=3, stamina=3, groundBalls=5, stickCheck=5,
        defensiveAwareness=5, passing=2, lacrosseIQ=3},
    {speed=4, agility=4, stamina=4, strength=3, bodyCheck=4,
        defensiveAwareness=5, groundBalls=2, lacrosseIQ=4}
}

local roleIndex = {
    A=1, ATTACK=1, M=2, MIDFIELD=2, D=3, DEFENSE=3,
    F=4, FO=4, FACEOFF=4, G=5, GOALIE=5, KEEPER=5, LSM=6, SSDM=7
}

local function position(role)
    local index = tonumber(role) or roleIndex[tostring(role):upper()]
    return presets[index] and index or 2
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function number(value)
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then return value end
end

local function points(value)
    value = number(value)
    if not value then return end
    if value > 0 and value < 1 then value = value * 100 end
    return clamp(math.floor(value + .5), 0, 99)
end

local function raw(values, key)
    if type(values) ~= "table" then return end
    local canonical = aliases[key] or key
    local value = number(values[canonical]) or number(values[key])
    if value then return value end
    local previousKeys = legacy[canonical]
    if previousKeys then
        for _, old in ipairs(previousKeys) do
            value = number(values[old])
            if value then return value end
        end
    end
end

function A.forPosition(role)
    local custom = presets[position(role)]
    local values = {}
    for _, descriptor in ipairs(descriptors) do
        values[descriptor.key] = custom[descriptor.key] or descriptor.value
    end
    return values
end

function A.restore(saved, role)
    local values = A.forPosition(role)
    if type(saved) ~= "table" then return values end
    local specialization = position(role)
    local isLegacy = saved.shotPower == nil and saved.shotAccuracy == nil
        and saved.ballControl == nil and saved.defensiveAwareness == nil
    for _, key in ipairs(keys) do
        local value = raw(saved, key)
        if isLegacy then
            if specialization == 5 and key == "passing" then
                value = number(saved.clearingAccuracy) or value
            elseif specialization == 5 and key == "goaliePositioning" then
                value = value or number(saved.handSpeed)
            elseif specialization == 4 and key == "defensiveAwareness" then
                value = number(saved.reaction) or value
            end
        end
        if value then values[key] = points(value) end
    end
    return values
end

function A.overall(values, role)
    local normal = A.restore(values, role)
    local score, total = 0, 0
    for key, weight in pairs(weights[position(role)]) do
        score, total = score + normal[key]*weight, total + weight
    end
    return math.floor(score / total + .5)
end

function A.cost(values, key, role)
    local descriptor = descriptorByKey[key]
    if not descriptor then return nil end
    local value = points(raw(values,key)) or A.forPosition(role)[key]
    if value >= 99 then return nil end
    return 12 + math.max(0,value-50) + math.max(0,value-75)*2 + math.max(0,value-90)*3
end

function A.advance(values, key, role)
    local cost = A.cost(values,key,role)
    if not cost then return false end
    local value = points(raw(values,key)) or A.forPosition(role)[key]
    return value+1, cost
end

-- Actor stats can also be supplied by older modules as fractional attributes.
local function ratingsOf(player)
    if not player then return end
    if player.rig or player.anim or player.id then return player.attributes end
    return player.attributes or player
end

function A.rating(player, key, fallback)
    return points(raw(ratingsOf(player),key)) or fallback
end

function A.unit(player, key, fallback)
    local value = raw(ratingsOf(player),key)
    if not value then return fallback end
    if value > 0 and value < 1 then return math.min(value,.99) end
    return clamp(value/100, 0, .99)
end

function A.updateFatigue(player, dt)
    local stamina = A.unit(player,"stamina")
    if not stamina then return end
    local exertion = clamp(((player.speed or 0)-4)/5, 0, 1)
    local rate = exertion > .08 and exertion*(.104-.061*stamina)
        or -(.13+.16*stamina)
    player.runningFatigue = clamp((player.runningFatigue or 0) + dt*rate, 0, 1)
end

function A.pace(player, base)
    return (base + (A.rating(player,"speed",62)-62)*.034)
        * (1 - (player.runningFatigue or 0)*.26)
end

function A.shotSpread(game, player, range)
    local accuracy = A.unit(player,"shotAccuracy")
    if not accuracy then return 0, 0 end
    local pressure = 0
    for _, defender in ipairs(game.squad) do
        if defender.team ~= player.team then
            local dx, dz = player.x-defender.x, player.z-defender.z
            pressure = math.max(pressure, 1-math.sqrt(dx*dx+dz*dz)/2.8)
        end
    end
    local motion = math.min(1, (player.speed or 0)/9)
    local error = (1-accuracy) * clamp(range/18,.36,1.35) * (.55 + .35*motion + .48*pressure)
    game.shotSerial = (game.shotSerial or 0)+1
    local phase = game.shotSerial*2.399963 + (player.id or 1)*.731
    return math.sin(phase)*error, math.cos(phase)*error*.58
end
