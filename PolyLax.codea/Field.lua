-- PolyLax Build 012 | Full-field layout and school field paint
PolyLax = PolyLax or {}
local P = PolyLax
local Field = {}
P.Field = Field

local yard = .9144
local foot = .3048
local white = color(232, 241, 227)
local perimeterColor = color(31, 77, 52)
local turfLight = color(49, 123, 73)
local turfDark = color(44, 113, 68)
local faceoffColor = color(241, 180, 48)

-- Geometry lettering keeps venue paint self-contained, with one mesh for all words.
local letters = {
    A={14,17,17,31,17,17,17}, B={30,17,17,30,17,17,30},
    C={15,16,16,16,16,16,15}, D={30,17,17,17,17,17,30},
    E={31,16,16,30,16,16,31}, F={31,16,16,30,16,16,16},
    G={15,16,16,23,17,17,15}, H={17,17,17,31,17,17,17},
    I={31,4,4,4,4,4,31}, J={7,2,2,2,2,18,12},
    K={17,18,20,24,20,18,17}, L={16,16,16,16,16,16,31},
    M={17,27,21,21,17,17,17}, N={17,25,21,19,17,17,17},
    O={14,17,17,17,17,17,14}, P={30,17,17,30,16,16,16},
    Q={14,17,17,17,21,18,13}, R={30,17,17,30,20,18,17},
    S={15,16,16,14,1,1,30}, T={31,4,4,4,4,4,4},
    U={17,17,17,17,17,17,14}, V={17,17,17,17,17,10,4},
    W={17,17,17,21,21,27,17}, X={17,17,10,4,10,17,17},
    Y={17,17,10,4,4,4,4}, Z={31,1,2,4,8,16,31}
}

local function batch()
    return {positions = {}, indices = {}, normals = {}, uvs = {}, colors = {}}
end

local function quad(mesh, a, b, c, d)
    local start = #mesh.positions + 1
    mesh.positions[start], mesh.positions[start + 1] = a, b
    mesh.positions[start + 2], mesh.positions[start + 3] = c, d
    local normal = vec3(0, 1, 0)
    local uv, neutral = vec2(0, 0), color(255, 255, 255)
    for i = start, start + 3 do
        mesh.normals[i], mesh.uvs[i], mesh.colors[i] = normal, uv, neutral
    end
    -- Supply both windings so the pitch is supported by legacy Craft renderers.
    local i = #mesh.indices + 1
    local x, y, z = start + 1, start + 2, start + 3
    local indices = mesh.indices
    indices[i], indices[i+1], indices[i+2] = start, x, y
    indices[i+3], indices[i+4], indices[i+5] = start, y, z
    indices[i+6], indices[i+7], indices[i+8] = start, y, x
    indices[i+9], indices[i+10], indices[i+11] = start, z, y
end

local function rectangle(mesh, minX, maxX, minZ, maxZ, height)
    quad(mesh, vec3(minX, height, minZ), vec3(minX, height, maxZ),
        vec3(maxX, height, maxZ), vec3(maxX, height, minZ))
end

local function render(scene, mesh, tint)
    local model = craft.model()
    model.positions, model.normals, model.colors = mesh.positions, mesh.normals, mesh.colors
    model.uvs, model.indices = mesh.uvs, mesh.indices
    local e = scene:entity()
    e.model = model
    local standard = asset and asset.builtin and asset.builtin.Materials
    e.material = craft.material(standard and standard.Standard or "Materials:Standard")
    e.material.diffuse = tint
    e.material.roughness = .96
    return e
end

local function lineX(mesh, x0, x1, z, width, y)
    rectangle(mesh, x0, x1, z - width * .5, z + width * .5, y)
end

local function lineZ(mesh, x, z0, z1, width, y)
    rectangle(mesh, x - width * .5, x + width * .5, z0, z1, y)
end

local function crease(mesh, z, radius, width, y)
    local segments = 48
    local function point(angle, r)
        return vec3(math.cos(angle) * r, y, z + math.sin(angle) * r)
    end
    local inner, outer = radius - width, radius
    for segment = 0, segments - 1 do
        local a, b = segment * (2 * math.pi / segments), (segment + 1) * (2 * math.pi / segments)
        quad(mesh, point(a, inner), point(b, inner), point(b, outer), point(a, outer))
    end
end

local function createTurf(scene, halfWidth, halfLength, theme)
    local perimeter, light, dark = batch(), batch(), batch()
    rectangle(perimeter, -halfWidth - 25, halfWidth + 25, -halfLength - 20, halfLength + 20, -.034)
    local apron = theme and theme.apron or perimeterColor
    if theme and theme.secondary and not theme.apron then
        local tint = theme.secondary
        apron = color(perimeterColor.r*.82+tint.r*.18,
            perimeterColor.g*.82+tint.g*.18, perimeterColor.b*.82+tint.b*.18)
    end
    render(scene, perimeter, apron)
    local stripeLength = 10 * yard
    local count = math.ceil(halfLength * 2 / stripeLength)
    for stripe = 0, count - 1 do
        local start = -halfLength + stripe * stripeLength
        rectangle(stripe % 2 == 0 and light or dark, -halfWidth, halfWidth,
            start, math.min(halfLength, start + stripeLength), 0)
    end
    render(scene, light, theme and theme.turfLight or turfLight)
    if #dark.positions > 0 then render(scene, dark, theme and theme.turfDark or turfDark) end
end

local function createMarkings(scene, field)
    local lines, square = batch(), batch()
    local x, z = field.halfWidth, field.halfLength
    local y, width = .018, .1016
    for _, sign in ipairs({-1, 1}) do
        lineX(lines, -x, x, sign * z, width, y)
        lineZ(lines, sign * x, -z, z, width, y)
        lineX(lines, -x, x, sign * field.restrainingZ, width, y)
        lineZ(lines, sign * field.wingX, -10 * yard, 10 * yard, width, y)
        local z0, z1 = sign * field.restrainingZ, sign * z
        for _, edge in ipairs({-1, 1}) do
            lineZ(lines, edge * field.wingX, math.min(z0,z1), math.max(z0,z1), width, y)
        end
        local goal = sign * field.goalZ
        crease(lines, goal, field.creaseRadius, width, y)
        lineX(lines, -field.goalHalfWidth, field.goalHalfWidth, goal, width, y)
    end
    -- A brighter silhouette at midfield remains legible in Broadcast view.
    -- Split the paint at the contrasting faceoff mark so the surfaces never fight.
    local midfield, middleWidth, spot = field.midfieldZ, .22, .0508
    lineX(lines, -x, -spot, midfield, middleWidth, y)
    lineX(lines, spot, x, midfield, middleWidth, y)
    rectangle(square, -spot, spot, midfield - spot, midfield + spot, y)
    lineX(square, -x - .72, -x - .14, midfield, .28, -.014)
    lineX(square, x + .14, x + .72, midfield, .28, -.014)
    -- Dashed outside paint defines the sideline buffer and bench strip.
    local sidelineBuffer = x + 6 * yard
    local interval = 2.5 * yard
    local sidelineCount = math.floor(z / interval)
    for offset = -sidelineCount, sidelineCount - 1 do
        local start = (offset + .26) * interval
        lineZ(lines, -sidelineBuffer, start, start + interval * .48, width, -.014)
        lineZ(lines, sidelineBuffer + 4 * yard, start, start + interval * .48, width, -.014)
    end
    local outsideEnd = z + 5 * yard
    local endlineCount = math.floor((x + 7 * yard) / interval)
    for offset = -endlineCount, endlineCount - 1 do
        local start = (offset + .26) * interval
        lineX(lines, start, start + interval * .48, -outsideEnd, width, -.014)
        lineX(lines, start, start + interval * .48, outsideEnd, width, -.014)
    end
    for _, sign in ipairs({-1, 1}) do
        local outsideInner, outsideOuter = x + 2 * yard, x + 6 * yard
        lineX(lines, outsideInner, outsideOuter, sign * 5 * yard, width, -.014)
        lineX(lines, outsideInner, outsideOuter, sign * 25 * yard, width, -.014)
        local low, high = sign * 5 * yard, sign * 25 * yard
        lineZ(lines, outsideOuter, math.min(low,high), math.max(low,high), width, -.014)
    end
    render(scene, lines, white)
    render(scene, square, faceoffColor)
end

local function word(mesh, label, centerZ, maxWidth, maxHeight, y)
    label = label:upper()
    local columns = #label * 6 - 1
    if columns < 1 then return end
    local cell = math.min(maxWidth / columns, maxHeight / 7)
    local startX = columns * cell * .5
    local startZ = centerZ - cell * 3.5
    for index = 1, #label do
        local shape = letters[label:sub(index, index)]
        if shape then
            local letterX = startX - (index - 1) * cell * 6
            for row, mask in ipairs(shape) do
                local first
                for column = 0, 5 do
                    local solid = column < 5 and math.floor(mask / 2^(4-column)) % 2 == 1
                    if solid then
                        first = first or column
                    elseif first then
                        local lz = startZ + (row - 1) * cell
                        rectangle(mesh, letterX - column * cell, letterX - first * cell,
                            lz, lz + cell, y)
                        first = nil
                    end
                end
            end
        end
    end
end

local function createBranding(scene, field, theme)
    local panels, accents, paint, midfield = batch(), batch(), batch(), batch()
    local x, z = field.halfWidth, field.halfLength
    local outerWidth = x + 1.85
    local panelY, edgeY, wordY = -.025, -.020, -.015
    for _, side in ipairs({-1, 1}) do
        local stripCenter = side * (x + .85)
        lineZ(panels, stripCenter, -z, z, .82, panelY)
        lineZ(accents, side * (x + 1.43), -z, z, .19, edgeY)
        local bandCenter = side * (z + 2.5)
        lineX(panels, -outerWidth, outerWidth, bandCenter, 3.75, panelY)
        lineX(accents, -outerWidth, outerWidth, bandCenter + side * 1.79, .24, edgeY)
        lineX(accents, -outerWidth, outerWidth, bandCenter - side * 1.79, .16, edgeY)
        word(paint, side == -1 and theme.wordmark or theme.endWordmark or theme.wordmark,
            bandCenter, 1.56 * x, 2.35, wordY)
    end

    -- Center lettering is offset from the white midfield line and faceoff spot.
    local midPaint = theme.lettering and midfield or paint
    word(midPaint, theme.centerWordmark or theme.wordmark, -3.15, .65 * x, 1.62, .012)
    render(scene, panels, theme.primary)
    render(scene, accents, theme.accent or theme.secondary or white)
    if #paint.positions > 0 then render(scene, paint, theme.lettering or white) end
    if #midfield.positions > 0 then render(scene, midfield, white) end
end

local function resolveTheme(theme)
    if tonumber(theme) and P.TeamUniform then
        return P.TeamUniform.get(theme).field
    end
    if type(theme) == "string" and P.SchoolTeams then
        local team = P.SchoolTeams.get(theme)
        return team and team.field
    end
    if type(theme) == "table" then return theme.field or theme end
end

function Field.new(scene, theme, metrics)
    -- USA Lacrosse men's diagram uses yards and feet. One game unit is one meter.
    theme = resolveTheme(theme)
    metrics = metrics or {}
    local halfLength = (metrics.fieldLengthYards or 110) * yard * .5
    local field = {
        halfWidth = (metrics.fieldWidthYards or 60) * yard * .5,
        halfLength = halfLength,
        midfieldZ = 0,
        goalZ = halfLength - (metrics.goalFromEndlineYards or 15) * yard,
        restrainingZ = (metrics.restrainingFromMidfieldYards or 20) * yard,
        wingX = (metrics.wingFromCenterYards or 20) * yard,
        creaseRadius = (metrics.creaseRadiusFeet or 9) * foot,
        goalHalfWidth = (metrics.goalWidthFeet or 6) * foot * .5,
        goalHeight = (metrics.goalHeightFeet or 6) * foot,
        theme = theme,
        goals = {}
    }
    createTurf(scene, field.halfWidth, field.halfLength, theme)
    createMarkings(scene, field)
    if theme then createBranding(scene, field, theme) end
    for i, sign in ipairs({-1, 1}) do
        field.goals[i] = P.GoalPhysics.new(scene, {
            x = 0, z = sign * field.goalZ, attackSign = sign,
            halfWidth = field.goalHalfWidth, top = field.goalHeight,
            radius = .09, postRadius = .055, depth = 1.10
        })
    end
    return field
end
