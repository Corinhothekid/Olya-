-- PolyLax Build 011 | Full-field layout and static rendering
PolyLax = PolyLax or {}
local P = PolyLax
local Field = {}
P.Field = Field

local yard = .9144
local white = color(232, 241, 227)

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

local function createTurf(scene, halfWidth, halfLength)
    local perimeter, light, dark = batch(), batch(), batch()
    rectangle(perimeter, -halfWidth - 25, halfWidth + 25, -halfLength - 20, halfLength + 20, -.034)
    render(scene, perimeter, color(31, 77, 52))
    local stripeLength = 10 * yard
    for stripe = 0, 10 do
        local start = -halfLength + stripe * stripeLength
        rectangle(stripe % 2 == 0 and light or dark, -halfWidth, halfWidth,
            start, start + stripeLength, 0)
    end
    render(scene, light, color(49, 123, 73))
    render(scene, dark, color(44, 113, 68))
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
        lineX(lines, -.9144, .9144, goal, width, y)
    end
    lineX(lines, -x, x, 0, width, y)
    rectangle(square, -.0508, .0508, -.0508, .0508, y + .001)
    -- Dashed outside paint defines the sideline buffer and bench strip.
    local sidelineBuffer = x + 6 * yard
    local interval = 2.5 * yard
    for offset = -22, 21 do
        local start = (offset + .26) * interval
        lineZ(lines, -sidelineBuffer, start, start + interval * .48, width, -.014)
        lineZ(lines, sidelineBuffer + 4 * yard, start, start + interval * .48, width, -.014)
    end
    local outsideEnd = z + 5 * yard
    for offset = -15, 14 do
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
    render(scene, square, color(241, 180, 48))
end

function Field.new(scene)
    -- USA Lacrosse men's diagram uses yards and feet. One game unit is one meter.
    local field = {
        halfWidth = 30 * yard,
        halfLength = 55 * yard,
        goalZ = 40 * yard,
        restrainingZ = 20 * yard,
        wingX = 20 * yard,
        creaseRadius = 2.7432,
        goals = {}
    }
    createTurf(scene, field.halfWidth, field.halfLength)
    createMarkings(scene, field)
    for i, sign in ipairs({-1, 1}) do
        field.goals[i] = P.GoalPhysics.new(scene, {
            x = 0, z = sign * field.goalZ, attackSign = sign,
            halfWidth = .9144, top = 1.8288, radius = .09, postRadius = .055, depth = 1.10
        })
    end
    return field
end
