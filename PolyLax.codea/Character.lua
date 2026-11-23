-- PolyLax 011 player rig and procedural equipment
PolyLax = PolyLax or {}
local Character = {}
PolyLax.Character = Character
Character.campusScale = .74
local dimensions = {
    shoulderX=.49, shoulderY=.73, armUpper=.33, armLower=.31,
    hipX=.205, legUpper=.46, legLower=.44, ankle=.14, pelvis=1.04, headY=1.18
}
Character.rigDimensions = dimensions

local white = color(236, 240, 242)
local black = color(34, 39, 48)
local dark = color(23, 29, 38)
local silver = color(174, 191, 205)
local skin = {
    color(247, 208, 174), color(213, 161, 119),
    color(168, 110, 77), color(105, 69, 52)
}
local hair = {
    color(27, 24, 25), color(94, 59, 35), color(190, 140, 69),
    color(132, 66, 46), color(52, 39, 33)
}
local jersey = {
    color(32, 121, 65), color(34, 91, 180), color(164, 48, 64),
    white, black, color(239, 169, 47)
}
local gear = { white, jersey[2], jersey[3], black, jersey[1], jersey[6] }
local chrome = {
    color(188, 208, 228), color(68, 146, 239), color(241, 182, 71),
    color(209, 70, 85), color(77, 89, 110)
}
local defaults = {
    FACE = 2, HAIR = 3, BEARD = 1, BODY = 2, HELMET = 1, JERSEY = 1,
    GLOVES = 1, SHORTS = 4, CLEATS = 1, STICK = 1, NUMBER = 4,
    SLEEVES = 1, HOODIE = 1
}
local bodySizes = {
    {.91, .97}, {1, 1}, {1.13, 1}, {.96, 1.10}
}

local modelCache = {}
local chromeMap
local chromeMapTried = false
local V = vec3

local function entity(scene, parent, x, y, z)
    local result = scene:entity()
    if parent then result.parent = parent end
    result.position = V(x or 0, y or 0, z or 0)
    return result
end

local function material(tint, roughness, metalness)
    local standard = asset and asset.builtin and asset.builtin.Materials
    local mat = craft.material(standard and standard.Standard or "Materials:Standard")
    mat.diffuse = tint
    mat.roughness = roughness or .83
    mat.metalness = metalness or 0
    return mat
end

local function mix(a, b, t)
    local function channel(left, right)
        return math.floor(left + (right - left) * t + .5)
    end
    return color(channel(a.r, b.r), channel(a.g, b.g), channel(a.b, b.b))
end

local function studioEnvironment()
    if chromeMapTried then return chromeMap end
    chromeMapTried = true
    if not craft.cubeTexture or not image then return end

    -- Two softboxes and a cool fill, generated once without external assets.
    local ok, result = pcall(function()
        local maps = {}
        local side = 32
        for face = 1, 6 do
            local map = image(side, side)
            maps[face] = map
            for y = 1, side do
                for x = 1, side do
                    local u = (x - .5) / side
                    local v = (y - .5) / side
                    local key = math.exp(-((u - .34)^2 * 38 + (v - .64)^2 * 8))
                    local fill = math.exp(-((u - .73)^2 * 80 + (v - .35)^2 * 14))
                    local gain = (face == 1 or face == 3 or face == 5) and 161 or 68
                    local level = math.floor(34 + gain * key + 40 * fill + 22 * v)
                    map:set(x, y, math.min(255, level),
                        math.min(255, level + 7), math.min(255, level + 18), 255)
                end
            end
        end
        return craft.cubeTexture(table.unpack(maps))
    end)
    if ok then chromeMap = result end
    return chromeMap
end

-- Mesh parts share geometry across players. A part is one renderer per material
-- and moving parent, so an entire facemask or pocket is one draw rather than
-- one draw per strand or bar.
local function triangle(mesh, a, b, c)
    local n = (b - a):cross(c - a)
    local length = n:len()
    if length < .000001 then return end
    local p = mesh.positions
    local index = #p + 1
    p[index], p[index + 1], p[index + 2] = a, b, c
    n = n / length
    local normals = mesh.normals
    normals[index], normals[index + 1], normals[index + 2] = n, n, n
    local indices = mesh.indices
    local i = #indices + 1
    indices[i], indices[i + 1], indices[i + 2] = index, index + 1, index + 2
    -- The reverse winding keeps both sides of thin equipment visible.
    indices[i + 3], indices[i + 4], indices[i + 5] = index, index + 2, index + 1
end

local function quad(mesh, a, b, c, d)
    triangle(mesh, a, b, c)
    triangle(mesh, a, c, d)
end

local function model(key, build)
    if not modelCache[key] then
        local mesh = { positions = {}, normals = {}, indices = {} }
        build(mesh)
        local colors, uvs = {}, {}
        local uv = vec2(0, 0)
        local neutral = color(255, 255, 255)
        for i = 1, #mesh.positions do
            colors[i], uvs[i] = neutral, uv
        end
        local result = craft.model()
        result.positions = mesh.positions
        result.normals = mesh.normals
        result.colors = colors
        result.uvs = uvs
        result.indices = mesh.indices
        modelCache[key] = result
    end
    return modelCache[key]
end

local function part(r, parent, key, mat, build, group)
    local e = entity(r.scene, parent)
    e.model = model(key, build)
    e.material = mat
    if group then group[#group + 1] = e end
    return e
end

local function show(parts, visible)
    for _, e in ipairs(parts) do e.active = visible end
end

-- Rings list y, x radius, z radius, z offset, and optional x offset.
local function loft(mesh, rings, sides, phase, square)
    local sections = {}
    for k, ring in ipairs(rings) do
        local points = {}
        for i = 1, sides do
            local theta = (i - 1) * math.pi * 2 / sides + (phase or 0)
            local x, z = math.cos(theta), math.sin(theta)
            if square then
                local factor = math.max(math.abs(x), math.abs(z))
                x, z = x / factor, z / factor
            end
            points[i] = V(x * ring[2] + (ring[5] or 0), ring[1],
                z * ring[3] + (ring[4] or 0))
        end
        sections[k] = points
    end
    for i = 1, sides do
        local j = i % sides + 1
        for k = 1, #sections - 1 do
            local low, high = sections[k], sections[k + 1]
            quad(mesh, low[i], high[i], high[j], low[j])
        end
        local first, last = rings[1], rings[#rings]
        local bottom, top = sections[1], sections[#sections]
        triangle(mesh, V(first[5] or 0, first[1], first[4] or 0), bottom[i], bottom[j])
        triangle(mesh, V(last[5] or 0, last[1], last[4] or 0), top[j], top[i])
    end
end

local function box(mesh, x, y, z, w, h, d)
    loft(mesh, {
        {y - h * .5, w * .5, d * .5, z, x},
        {y + h * .5, w * .5, d * .5, z, x}
    }, 4, math.pi * .25, true)
end

local function bevel(mesh, x, y, z, w, h, d)
    loft(mesh, {
        {y - h * .5, w * .38, d * .38, z, x},
        {y - h * .30, w * .5, d * .5, z, x},
        {y + h * .30, w * .5, d * .5, z, x},
        {y + h * .5, w * .38, d * .38, z, x}
    }, 8, math.pi / 8, true)
end

local function bar(mesh, a, b, radius, sides, endRadius)
    local axis = b - a
    local n = axis / axis:len()
    local up = math.abs(n.y) > .9 and V(1, 0, 0) or V(0, 1, 0)
    local u = n:cross(up)
    u = u / u:len()
    local v = n:cross(u)
    local lastRadius = endRadius or radius
    local first, second = {}, {}
    for i = 1, sides do
        local angle = (i - 1) * math.pi * 2 / sides
        local d = u * math.cos(angle) + v * math.sin(angle)
        first[i], second[i] = a + d * radius, b + d * lastRadius
    end
    for i = 1, sides do
        local j = i % sides + 1
        quad(mesh, first[i], first[j], second[j], second[i])
        triangle(mesh, a, first[j], first[i])
        triangle(mesh, b, second[i], second[j])
    end
end

local function rail(mesh, radius, points, sides)
    for i = 1, #points - 1 do
        bar(mesh, points[i], points[i + 1], radius, sides or 6)
    end
end

local function athleteNeck(mesh)
    bevel(mesh, 0, .98, .006, .24, .35, .26)
end

local function jerseyExterior(mesh)
    -- Keep the hem seated at the hip even when the upper body twists.
    loft(mesh, {
        {.035, .237, .149}, {.075, .278, .164}, {.136, .303, .190}, {.228, .325, .208},
        {.32, .35, .22}, {.66, .39, .226}, {.78, .40, .207}, {.87, .25, .15}
    }, 8, math.pi / 8, true)
end

local function hoodieExterior(mesh)
    loft(mesh, {
        {.040, .251, .160}, {.085, .294, .180}, {.154, .328, .204}, {.240, .355, .225},
        {.31, .373, .236}, {.66, .404, .239},
        {.79, .405, .228}, {.88, .255, .17}
    }, 8, math.pi / 8, true)
    loft(mesh, {
        {.695, .13, .105, .24}, {.785, .225, .165, .25},
        {.92, .24, .164, .226}, {1.045, .201, .108, .208},
        {1.095, .12, .059, .188}
    }, 8, math.pi / 8)
end

local function hoodieTrim(mesh)
    rail(mesh, .015, {V(-.171, 1.01, .11), V(-.12, 1.075, .129),
        V(0, 1.09, .124), V(.12, 1.075, .129), V(.171, 1.01, .11)})
    rail(mesh, .011, {V(-.23, .298, -.232), V(-.181, .32, -.245),
        V(-.112, .405, -.247), V(.112, .405, -.247),
        V(.181, .32, -.245), V(.23, .298, -.232)})
    rail(mesh, .009, {V(-.11, .833, -.205), V(-.084, .765, -.231), V(-.101, .675, -.241)})
    rail(mesh, .009, {V(.11, .833, -.205), V(.102, .76, -.234), V(.094, .655, -.242)})
end

local function dressTorso(r)
    local m = r.materials
    part(r, r.body, "jersey", m.jersey, jerseyExterior, r.campusHidden)
    part(r, r.body, "neck", m.skin, athleteNeck)
    part(r, r.body, "collar", m.jerseyTrim, function(mesh)
        rail(mesh, .019, {V(-.15, .863, -.155), V(0, .80, -.208), V(.15, .863, -.155)})
    end, r.campusHidden)
    part(r, r.pelvis, "shorts waist", m.shorts, function(mesh)
        bevel(mesh, 0, .104, .01, .764, .33, .46)
    end, r.campusHidden)
    r.numberMark = entity(r.scene, r.body)

    part(r, r.body, "hoodie exterior", m.hoodie, hoodieExterior, r.hoodieParts)
    part(r, r.body, "hoodie trim", m.hoodTrim, hoodieTrim, r.hoodieParts)
end

local function gloveShell(mesh)
    bevel(mesh, 0, .047, .008, .245, .293, .237)
    bevel(mesh, 0, .128, .001, .267, .101, .234)
end

function Character.gloveModel()
    return model("glove shell",gloveShell)
end

local function hoodieUpperSleeve(mesh)
    bevel(mesh, 0, -.111, .002, .293, .444, .355)
end

local function hoodieLowerSleeve(mesh)
    bevel(mesh, 0, -.123, 0, .217, .326, .246)
end

function Character.campusApparel(part)
    if part=="hoodie" then
        return model("hoodie exterior",hoodieExterior),model("hoodie trim",hoodieTrim)
    elseif part=="jersey" then
        return model("jersey",jerseyExterior)
    elseif part=="upperArm" then
        return model("hoodie upper sleeve",hoodieUpperSleeve)
    elseif part=="forearm" then
        return model("hoodie lower sleeve",hoodieLowerSleeve)
    end
end

local function arm(r, sign, name)
    local m = r.materials
    local shoulder = entity(r.scene, r.body, sign * dimensions.shoulderX, dimensions.shoulderY, 0)
    local elbow = entity(r.scene, shoulder, 0, -r.armLengthUpper, 0)
    local wrist = entity(r.scene, elbow, 0, -r.armLengthLower, 0)
    r.joints[name .. "Shoulder"] = shoulder
    r.joints[name .. "Elbow"] = elbow
    r.joints[name .. "Wrist"] = wrist
    r.arms[name] = { shoulder = shoulder, elbow = elbow, wrist = wrist }

    part(r, shoulder, "upper arm", m.skin, function(mesh)
        bevel(mesh, 0, -.186, 0, .212, .372, .213)
    end)
    part(r, elbow, "forearm", m.skin, function(mesh)
        bevel(mesh, 0, -.145, 0, .192, .34, .212)
    end)
    part(r, shoulder, "jersey sleeve", m.jersey, function(mesh)
        bevel(mesh, 0, -.047, .002, .28, .265, .352)
    end, r.campusHidden)
    part(r, shoulder, "jersey cuff", m.jerseyTrim, function(mesh)
        box(mesh, 0, -.131, -.171, .21, .034, .025)
    end, r.campusHidden)
    part(r, shoulder, "hoodie upper sleeve", m.hoodie, hoodieUpperSleeve, r.hoodieParts)
    part(r, elbow, "hoodie lower sleeve", m.hoodie, hoodieLowerSleeve, r.hoodieParts)
    part(r, elbow, "elbow pads", m.silver, function(mesh)
        bevel(mesh, 0, -.049, -.105, .231, .20, .107)
        bevel(mesh, 0, -.052, .1, .196, .139, .067)
    end, r.campusHidden)
    r.arms[name].glove = part(r, wrist, "glove shell", m.gloves, gloveShell, r.campusHidden)
    part(r, wrist, "glove joints", m.gloveTrim, function(mesh)
        for i = -1, 1 do
            bevel(mesh, i * .066, -.025, -.089, .054, .118, .068)
        end
        bevel(mesh, 0, .065, -.09, .181, .038, .067)
        bevel(mesh, 0, .122, -.112, .212, .021, .033)
    end, r.campusHidden)
end

local function leg(r, sign, name)
    local m = r.materials
    local hip = entity(r.scene, r.pelvis, sign * dimensions.hipX, 0, 0)
    local knee = entity(r.scene, hip, 0, -r.legLengthUpper, 0)
    local ankle = entity(r.scene, knee, 0, -r.legLengthLower, 0)
    r.joints[name .. "Hip"] = hip
    r.joints[name .. "Knee"] = knee
    r.joints[name .. "Ankle"] = ankle
    r.legs[name] = { hip = hip, knee = knee, ankle = ankle }
    local sleeve = r.sleeveParts[name]
    local exposedLeg = r.exposedLegParts[name]

    part(r, hip, "shorts leg", m.shorts, function(mesh)
        loft(mesh, {
            {-.232, .144, .187, -.002}, {-.177, .177, .218},
            {.025, .182, .221}, {.066, .154, .20}
        }, 8, math.pi / 8, true)
    end, r.campusHidden)
    part(r, hip, "thigh", m.skin, function(mesh)
        bevel(mesh, 0, -.319, -.006, .235, .346, .239)
    end, exposedLeg)
    part(r, knee, "shin", m.skin, function(mesh)
        bevel(mesh, 0, -.191, .002, .208, .450, .233)
    end, exposedLeg)
    part(r, hip, "thigh sleeve", m.sleeves, function(mesh)
        loft(mesh, {{-.485, .109, .116}, {-.444, .127, .122},
            {-.234, .129, .132}, {-.191, .13, .134}}, 8, math.pi / 8, true)
    end, sleeve)
    part(r, knee, "compression sleeve", m.sleeves, function(mesh)
        loft(mesh, {{-.388, .106, .117}, {-.31, .117, .126},
            {-.149, .119, .135}, {-.025, .123, .136}, {.04, .104, .114}}, 8, math.pi / 8, true)
    end, sleeve)
    part(r, knee, "sock", m.white, function(mesh)
        bevel(mesh, 0, -.382, .002, .219, .174, .24)
    end, r.campusHidden)
    part(r, ankle, "cleat", m.cleats, function(mesh)
        loft(mesh, {{-.106, .145, .231, -.092}, {-.04, .151, .23, -.092},
            {.04, .124, .168, -.044}, {.092, .104, .116, .013}},
            8, math.pi / 8, true)
    end, r.campusHidden)
    part(r, ankle, "cleat sole", m.dark, function(mesh)
        bevel(mesh, 0, -.113, -.093, .305, .039, .476)
        for _, x in ipairs({-.085, .085}) do
            for _, z in ipairs({-.245, -.105, .049}) do
                box(mesh, x, -.129, z, .039, .022, .046)
            end
        end
    end, r.campusHidden)
    part(r, ankle, "cleat lace", m.white, function(mesh)
        for i = 0, 2 do
            local y, z = .044 + .016 * i, -.186 + .046 * i
            bar(mesh, V(-.065, y, z), V(.065, y, z), .008, 4)
        end
    end, r.campusHidden)
end

local sharedHead

local function headGeometry()
    if sharedHead then return sharedHead end
    local geometry={face={},hair={},beard={}}
    geometry.shell = model("head",function(mesh)
        loft(mesh, {
            {-.269, .105, .113, -.067}, {-.21, .204, .191, -.037},
            {-.079, .265, .240, -.024}, {.116, .283, .251, -.015},
            {.261, .262, .246, .002}, {.338, .206, .171, .016},
            {.369, .093, .10, .021}
        }, 10, -math.pi * .5)
        for _, s in ipairs({-1, 1}) do
            bevel(mesh, s * .274, .016, .015, .080, .155, .125)
        end
    end)
    local faceDetails = {
        { eyes = .112, brow = .180, gap = .132, nose = .070, mouth = .119 },
        { eyes = .111, brow = .186, gap = .148, nose = .085, mouth = .145 },
        { eyes = .097, brow = .182, gap = .139, nose = .091, mouth = .153 },
        { eyes = .127, brow = .198, gap = .145, nose = .073, mouth = .125 }
    }
    for i, face in ipairs(faceDetails) do
        local group = {}
        geometry.face[i] = group
        group[1]=model("face nose " .. i,function(mesh)
            loft(mesh, {{-.036, face.nose * .51, .041, -.259},
                {.002, face.nose * .55, .060, -.271},
                {.093, face.nose * .34, .033, -.254},
                {.15, face.nose * .29, .011, -.241}}, 6)
        end)
        group[2]=model("eye flats " .. i,function(mesh)
            for _, s in ipairs({-1, 1}) do
                bevel(mesh, s * face.gap, face.eyes, -.244, .095, .045, .035)
            end
        end)
        group[3]=model("face expression " .. i,function(mesh)
            for _, s in ipairs({-1, 1}) do
                bevel(mesh, s * (face.gap - .009), face.eyes, -.259, .038, .041, .02)
                rail(mesh, .011, {V(s * (face.gap - .053), face.brow - .008, -.257),
                    V(s * face.gap, face.brow, -.254),
                    V(s * (face.gap + .058), face.brow - .012, -.221)}, 5)
            end
            rail(mesh, .009, {V(-face.mouth * .5, -.113, -.251), V(0, -.12, -.268),
                V(face.mouth * .5, -.113, -.251)}, 4)
        end)
    end

    for i = 2, 6 do
        geometry.hair[i]=model("hair " .. i,function(mesh)
            local back = i == 6 and -.016 or .118
            loft(mesh, {{back, .255, .128, .123}, {.226, .278, .226, .056},
                {.31, .273, .254, .008}, {.369, .227, .216, .016},
                {.396, .114, .136, .023}}, 10, -math.pi * .5)
            if i == 2 then
                loft(mesh, {{.316, .253, .166, -.091}, {.39, .232, .177, -.064},
                    {.432, .169, .14, -.034}}, 8)
            elseif i == 3 then
                loft(mesh, {{.318, .237, .179, -.096, -.024}, {.404, .229, .161, -.081, -.034},
                    {.472, .137, .124, -.046, -.083}, {.482, .064, .06, -.05, -.146}}, 9)
            elseif i == 4 then
                for k = -2, 2 do
                    local x = k * .098
                    bar(mesh, V(x, .338, -.143), V(x + .047, .475 - math.abs(k) * .024, -.117),
                        .073, 6, .009)
                end
            elseif i == 5 then
                for row = 0, 1 do
                    for k = -2, 2 do
                        local x, z = k * .093, -.125 + row * .174
                        loft(mesh, {{.334, .074, .071, z, x},
                            {.401, .076, .074, z, x}, {.458, .039, .038, z - .01, x}}, 7)
                    end
                end
            else
                for _, s in ipairs({-1, 1}) do
                    loft(mesh, {{-.12, .039, .072, .129, s * .236},
                        {.033, .06, .103, .104, s * .25}, {.265, .072, .17, .062, s * .239},
                        {.369, .062, .139, .025, s * .195}}, 6)
                end
                loft(mesh, {{.295, .235, .161, -.071, .029}, {.393, .205, .15, -.071, .054},
                    {.429, .109, .117, -.041, .097}}, 8)
            end
        end)
    end
    for i = 2, 6 do
        geometry.beard[i]=model("beard " .. i,function(mesh)
            if i == 3 or i == 4 or i >= 5 then
                for _, s in ipairs({-1, 1}) do
                    rail(mesh, i == 3 and .021 or .015, {V(s * .012, -.066, -.279),
                        V(s * .075, -.058, -.265), V(s * .113, -.086, -.253)}, 6)
                end
            end
            if i ~= 3 then
                local width = ({ .13, 0, .084, .171, .199 })[i - 1]
                local depth = ({ .018, 0, .035, .064, .087 })[i - 1]
                local height = ({ .054, 0, .115, .14, .19 })[i - 1]
                bevel(mesh, 0, -.203, -.232, width * 2, height, depth + .05)
                if i >= 5 then
                    for _, s in ipairs({-1, 1}) do
                        rail(mesh, i == 6 and .051 or .035, {V(s * .251, -.024, -.114),
                            V(s * .22, -.114, -.175), V(s * .138, -.196, -.215)}, 6)
                    end
                end
            end
        end)
    end
    sharedHead=geometry
    return geometry
end

local function bind(part,geometry,material)
    part.model=geometry
    part.material=material
end

local function headPart(r,parent,geometry,material)
    local e=entity(r.scene,parent)
    bind(e,geometry,material)
    return e
end

local function makeHead(r)
    local m,geometry=r.materials,headGeometry()
    r.head=entity(r.scene,r.body,0,dimensions.headY,0)
    r.joints.head=r.head
    r.headShell=headPart(r,r.head,geometry.shell,m.skin)
    r.faceParts={}
    for i,face in ipairs(geometry.face) do
        r.faceParts[i]={headPart(r,r.head,face[1],m.skin),headPart(r,r.head,face[2],m.white),
            headPart(r,r.head,face[3],m.dark)}
    end
    r.hairRoot,r.beardRoot=entity(r.scene,r.head),entity(r.scene,r.head)
    r.hairParts,r.beardParts={},{}
    for i=2,6 do
        r.hairParts[i]=headPart(r,r.hairRoot,geometry.hair[i],m.hair)
        r.beardParts[i]=headPart(r,r.beardRoot,geometry.beard[i],m.beard)
    end
end

local campusFaces={oval=1,angular=2,round=3,long=4}
local campusHair={none=1,crop=2,neat=2,sweep=3,curls=5,bun=6,bob=6,braids=6}
local portraitWhite,portraitInk,portraitGold

local function glassesMesh(mesh)
    for _,side in ipairs({-1,1}) do
        rail(mesh,.008,{V(side*.058,.147,-.294),V(side*.211,.147,-.272),
            V(side*.211,.064,-.272),V(side*.058,.064,-.289),V(side*.058,.147,-.294)},4)
        bar(mesh,V(side*.211,.144,-.272),V(side*.288,.130,.010),.008,4)
    end
    bar(mesh,V(-.058,.129,-.294),V(.058,.129,-.294),.008,4)
end

local function earringsMesh(mesh)
    for _,side in ipairs({-1,1}) do
        bevel(mesh,side*.300,-.041,-.017,.023,.036,.022)
    end
end

-- The campus uses the same selected head meshes as the creator and match,
-- with its own joints and lighting so no helmet or inactive variants are needed.
function Character.applyCampusHead(r,look)
    local geometry=headGeometry()
    if not r.campusPortrait then
        portraitWhite=portraitWhite or material(white)
        portraitInk=portraitInk or material(dark)
        r.campusPortrait={skin=material(skin[2]),hair=material(hair[2]),beard=material(hair[2])}
        r.faceParts={entity(r.scene,r.head),entity(r.scene,r.head),entity(r.scene,r.head)}
        r.hairPart=entity(r.scene,r.head)
        r.beardPart=entity(r.scene,r.head)
    end
    local m=r.campusPortrait
    local complexion,tint=color(table.unpack(look.skin)),color(table.unpack(look.hair))
    local face=look.faceIndex or campusFaces[look.headShape] or 1
    local haircut=look.hairIndex or campusHair[look.haircut] or 1
    local beard=look.beardStyle or (look.beard and 5 or 1)
    r.faceIndex,r.hairIndex,r.beardIndex=face,haircut,beard
    m.skin.diffuse,m.hair.diffuse=complexion,tint
    m.beard.diffuse=mix(tint,complexion,beard==2 and .62 or .12)
    bind(r.face,geometry.shell,m.skin)
    bind(r.neck,model("neck",athleteNeck),m.skin)
    bind(r.faceParts[1],geometry.face[face][1],m.skin)
    bind(r.faceParts[2],geometry.face[face][2],portraitWhite)
    bind(r.faceParts[3],geometry.face[face][3],portraitInk)
    r.hairPart.active=haircut>1
    r.beardPart.active=beard>1
    if r.hairPart.active then bind(r.hairPart,geometry.hair[haircut],m.hair) end
    if r.beardPart.active then bind(r.beardPart,geometry.beard[beard],m.beard) end

    if look.glasses and not r.glasses then
        r.glasses=headPart(r,r.head,model("campus glasses",glassesMesh),portraitInk)
    end
    if look.earrings and not r.earrings then
        portraitGold=portraitGold or material(color(226,173,61),.44)
        r.earrings=headPart(r,r.head,model("campus earrings",earringsMesh),portraitGold)
    end
    if r.glasses then r.glasses.active=look.glasses==true end
    if r.earrings then r.earrings.active=look.earrings==true end
end

-- Half contours go from the nose of the molded visor around each ear to the nape.
local helmetLower = {
    {0,.203,-.393}, {.102,.208,-.372}, {.197,.224,-.327}, {.267,.241,-.265},
    {.310,.211,-.189}, {.338,.100,-.116}, {.350,-.044,-.047}, {.326,-.119,.077},
    {.285,-.166,.158}, {.228,-.192,.218}, {.155,-.209,.254}, {.079,-.217,.276},
    {0,-.221,.286}
}
local helmetBrow = {
    {0,.249,-.413}, {.107,.254,-.392}, {.205,.266,-.340}, {.277,.284,-.270},
    {.322,.287,-.190}, {.347,.244,-.111}, {.363,.189,-.026}, {.343,.157,.085},
    {.306,.132,.168}, {.252,.118,.240}, {.177,.112,.282}, {.091,.112,.310},
    {0,.119,.324}
}
local helmetSides = (#helmetLower - 1) * 2

local function helmetRings()
    local rows = {{}, {}}
    local crown = {
        -- height, lateral width, depth, center, front rake, rear lip
        {.314,.355,.294,.016,.013,.006},
        {.386,.297,.253,.024,.022,.014},
        {.437,.216,.186,.045,.022,.036},
        {.463,.119,.108,.069,.010,.017}
    }
    for i = 1, #crown do rows[i + 2] = {} end
    for side = 0, helmetSides - 1 do
        local mirrored = side > helmetSides * .5
        local index = (mirrored and helmetSides - side or side) + 1
        local sign = mirrored and -1 or 1
        local lower, brow = helmetLower[index], helmetBrow[index]
        rows[1][side+1] = V(sign * lower[1], lower[2], lower[3])
        rows[2][side+1] = V(sign * brow[1], brow[2], brow[3])
        local angle = side * math.pi * 2 / helmetSides
        local sin, cos = math.sin(angle), math.cos(angle)
        local rear = math.max(0, -cos)^5
        for i, ring in ipairs(crown) do
            rows[i+2][side+1] = V(ring[2] * sin,
                ring[1] - ring[5] * cos + rear * ring[6] * .38,
                ring[4] - ring[3] * cos + rear * ring[6])
        end
    end
    return rows
end

local function helmetVent(row, side)
    if row == 1 then return side == 5 or side == 10 or side == 11 end
    if row == 3 then return side == 6 or side == 7 or side == 11 end
    return row == 4 and (side == 5 or side == 6)
end

local function ventPanel(mesh, a, b, c, d, back)
    local function sample(u, v)
        return a + (b - a) * u + (d - a) * v + (c - b - d + a) * (u * v)
    end
    local opening = {sample(.12,.35), sample(.89,.47), sample(.85,.72), sample(.17,.63)}
    local normal = (d - a):cross(b - a):normalize()
    local center = (opening[1] + opening[2] + opening[3] + opening[4]) * .25
    local corners, inset = {a,b,c,d}, {}
    for i, point in ipairs(opening) do
        inset[i] = center + (point - center) * .74 - normal * .016
    end
    if back then
        quad(mesh, inset[1], inset[4], inset[3], inset[2])
    else
        for i = 1, 4 do
            local next = i % 4 + 1
            quad(mesh, corners[i], opening[i], opening[next], corners[next])
            quad(mesh, opening[i], inset[i], inset[next], opening[next])
        end
    end
end

local function buildHelmetShell(mesh, section)
    local rows = helmetRings()
    for i = 1, helmetSides do
        local next = i % helmetSides + 1
        local side = math.min(i, helmetSides + 1 - i)
        local visor = side <= 4
        for row = 1, #rows - 1 do
            local a, b, c, d = rows[row][i], rows[row][next],
                rows[row+1][next], rows[row+1][i]
            local opening = helmetVent(row, side)
            if section == "recess" then
                if opening then ventPanel(mesh, a, b, c, d, true) end
            elseif section == "shell" and (row > 1 or not visor) then
                if opening then ventPanel(mesh, a, b, c, d, false)
                else quad(mesh, a, d, c, b) end
            elseif section == "visor" and row == 1 and visor then
                quad(mesh, a, d, c, b)
            end
        end
        if section == "shell" then
            local top = rows[#rows]
            triangle(mesh, top[i], V(0,.483,.088), top[next])
        elseif section == "recess" then
            local a, b = rows[1][i], rows[1][next]
            local function lining(p)
                return V(p.x * .95, p.y + .014, p.z * .95 + .004)
            end
            quad(mesh, a, b, lining(b), lining(a))
        end
    end
end

local function makeHelmet(r)
    local m = r.materials
    local root = entity(r.scene, r.head)
    r.helmetRoot = root
    local parts = r.helmetParts

    part(r, root, "fitted helmet shell", m.helmet, function(mesh)
        buildHelmetShell(mesh, "shell")
    end, parts)
    part(r, root, "fitted helmet visor edge", m.brow, function(mesh)
        buildHelmetShell(mesh, "visor")
        for _, sign in ipairs({-1,1}) do
            local function p(x, y, z) return V(sign*x, y, z) end
            local back, middle, front = p(.334,.071,-.064), p(.328,.018,-.166), p(.273,-.139,-.301)
            bar(mesh,back,middle,.039,7,.034)
            bar(mesh,middle,front,.034,7,.025)

            -- Taper the cheek accent upward along the shell toward the nape.
            local stripe = {{.47,.10},{.69,.087},{.83,.066},
                {.91,.044},{.95,.025},{.96,.008}}
            local low, high = back - V(0,.018,0), back + V(0,.018,0)
            for i, section in ipairs(stripe) do
                local index = i + 6
                local lower, upper = helmetLower[index], helmetBrow[index]
                local function edge(t)
                    return p(lower[1] + (upper[1] - lower[1]) * t + .008,
                        lower[2] + (upper[2] - lower[2]) * t,
                        lower[3] + (upper[3] - lower[3]) * t + i*.001)
                end
                local nextLow = edge(section[1] - section[2])
                local nextHigh = edge(section[1] + section[2])
                if sign > 0 then quad(mesh,low,high,nextHigh,nextLow)
                else quad(mesh,low,nextLow,nextHigh,high) end
                low, high = nextLow, nextHigh
            end
        end
    end, parts)
    part(r, root, "fitted helmet ventilation and lining", m.vent, function(mesh)
        buildHelmetShell(mesh, "recess")
        for _, sign in ipairs({-1,1}) do
            local function p(x, y, z) return V(sign*x, y, z) end
            -- The lower cheek stays hollow on the side. A recessed lining gives
            -- the opening depth while keeping the helmet interior in shadow.
            local a,b,c,d = p(.310,.043,-.096), p(.309,-.022,-.196),
                p(.279,-.156,-.297), p(.305,-.148,-.159)
            if sign > 0 then quad(mesh,a,d,c,b) else quad(mesh,a,b,c,d) end
            bevel(mesh, sign * .341, .062, -.099, .046, .086, .066)
            bevel(mesh, sign * .316, -.086, -.170, .042, .073, .069)
        end
        bevel(mesh, 0, -.188, .280, .122, .056, .040)
    end, parts)
    part(r, root, "fitted helmet jaw rails and chin cup", m.liner, function(mesh)
        for _, sign in ipairs({-1,1}) do
            local function p(x, y, z) return V(sign*x, y, z) end
            rail(mesh,.024,{p(.327,-.023,-.085),p(.323,-.122,-.171),p(.270,-.200,-.290),
                p(.193,-.232,-.321)},7)
            rail(mesh,.028,{p(.273,-.139,-.301),p(.249,-.184,-.317),p(.193,-.232,-.321)},7)
        end
        rail(mesh,.027,{V(-.193,-.232,-.321),V(-.104,-.247,-.343),
            V(.104,-.247,-.343),V(.193,-.232,-.321)},7)
        bevel(mesh,0,-.245,-.322,.212,.076,.081)
    end, parts)
    part(r, root, "fitted helmet sightline cage", m.cage, function(mesh)
        local upper = {V(-.341,.077,-.109),V(-.322,.067,-.231),V(-.239,.051,-.348),
            V(-.110,.041,-.422),V(.110,.041,-.422),V(.239,.051,-.348),
            V(.322,.067,-.231),V(.341,.077,-.109)}
        local middle = {V(-.333,-.023,-.116),V(-.306,-.039,-.234),V(-.225,-.065,-.342),
            V(-.103,-.072,-.408),V(.103,-.072,-.408),V(.225,-.065,-.342),
            V(.306,-.039,-.234),V(.333,-.023,-.116)}
        local lower = {V(-.315,-.109,-.144),V(-.284,-.129,-.232),V(-.199,-.161,-.311),
            V(-.091,-.175,-.376),V(.091,-.175,-.376),V(.199,-.161,-.311),
            V(.284,-.129,-.232),V(.315,-.109,-.144)}
        rail(mesh,.013,upper,7)
        rail(mesh,.012,middle,7)
        rail(mesh,.014,lower,7)
        for _, edge in ipairs({1,#upper}) do
            local sign = edge == 1 and -1 or 1
            local front = edge - sign*3
            rail(mesh,.013,{upper[edge],middle[edge],lower[edge]},7)
            rail(mesh,.011,{V(sign*.109,.227,-.381),V(sign*.109,.126,-.407),
                upper[front],middle[front],lower[front],
                V(sign*.089,-.224,-.350)},7)
            bar(mesh,V(sign*.353,.062,-.099),V(sign*.366,.062,-.099),.012,7)
            bar(mesh,V(sign*.331,-.086,-.170),V(sign*.344,-.086,-.170),.011,7)
        end
    end, parts)
end

local stickSizes = {
    short = {extension=0, butt=-.923, lowerGrip=-.37},
    long = {extension=.46, butt=-1.36, lowerGrip=-.48},
    goalie = {extension=.05, butt=-.95, lowerGrip=-.39, pocketY=.85, pocketZ=-.123}
}

local function shaft(mesh, size)
    bar(mesh, V(0, size.butt, 0), V(0, .419 + size.extension, 0), .029, 8)
end

local function shaftTape(mesh, size)
    bar(mesh, V(0, size.butt - .020, 0), V(0, size.butt + .163, 0), .034, 8)
    bar(mesh, V(0, size.lowerGrip - .098, 0), V(0, size.lowerGrip + .064, 0), .032, 8)
    bar(mesh, V(0, -.069, 0), V(0, .118, 0), .032, 8)
    bar(mesh, V(0, size.butt - .036, 0), V(0, size.butt - .001, 0), .043, 8)
end

local goalieRim = {
    {.46,.064,-.02}, {.55,.168,-.04}, {.69,.276,-.059},
    {.86,.347,-.084}, {1.02,.352,-.112}, {1.14,.249,-.135}, {1.20,.116,-.149}
}

local function goalieHead(mesh)
    loft(mesh, {{.394,.040,.037},{.461,.055,.044},{.521,.069,.049,-.030}}, 8)
    for _, side in ipairs({-1,1}) do
        local outer, inner = {}, {}
        for _, point in ipairs(goalieRim) do
            local y, x, z = point[1], point[2], point[3]
            outer[#outer+1], inner[#inner+1] = V(side*x,y,z), V(side*(x-.019),y+.004,z+.040)
            bar(mesh,outer[#outer],inner[#inner],.014,6)
        end
        rail(mesh,.025,outer,7)
        rail(mesh,.015,inner,6)
    end
    rail(mesh,.024,{V(-.116,1.20,-.149),V(0,1.223,-.156),V(.116,1.20,-.149)},7)
end

local function goaliePocket(mesh)
    local function knot(row, fraction)
        return V(row[2]*fraction,row[1],row[3]+.122*(1-fraction*fraction))
    end
    for band=1,#goalieRim-1 do
        for i=-4,4 do
            local point = knot(goalieRim[band],i/4)
            for _, step in ipairs({-1,1}) do
                if math.abs(i+step)<=4 then
                    bar(mesh,point,knot(goalieRim[band+1],(i+step)/4),.005,4)
                end
            end
        end
    end
    for band=4,5 do
        rail(mesh,.009,{knot(goalieRim[band],-1),knot(goalieRim[band],-.5),
            knot(goalieRim[band],0),knot(goalieRim[band],.5),knot(goalieRim[band],1)},5)
    end
end

local function makeStick(r)
    local m = r.materials
    local root = entity(r.scene, r.body, .19, .66, -.31)
    r.stickRoot = root
    r.pocket = entity(r.scene, root, 0, .70, -.10)
    r.lowerGrip = entity(r.scene, root, 0, -.37, 0)
    local parts = r.stickParts
    r.stickType, r.stickReachExtension = "short", 0
    r.stickShaft = part(r, root, "stick alloy short", m.shaft, function(mesh)
        shaft(mesh, stickSizes.short)
    end, parts)
    r.stickTape = part(r, root, "stick tape short", m.dark, function(mesh)
        shaftTape(mesh, stickSizes.short)
    end, parts)
    r.stickHead = part(r, root, "stick scoop and sidewalls", m.stick, function(mesh)
        loft(mesh, {{.345, .042, .034}, {.409, .048, .047},
            {.448, .076, .045, -.016}, {.482, .076, .046, -.027}}, 8)
        for _, s in ipairs({-1, 1}) do
            rail(mesh, .022, {V(s * .043, .45, -.023), V(s * .096, .546, -.041),
                V(s * .165, .662, -.048), V(s * .215, .787, -.067),
                V(s * .219, .892, -.097), V(s * .175, .962, -.132)}, 7)
            rail(mesh, .016, {V(s * .073, .473, .013), V(s * .116, .558, .018),
                V(s * .169, .667, .015), V(s * .205, .787, -.005),
                V(s * .213, .884, -.039), V(s * .175, .958, -.108)}, 6)
            for _, joint in ipairs({{.10,.55,-.035,.115,.018}, {.164,.665,-.045,.169,.015},
                {.214,.785,-.065,.205,-.005}, {.219,.888,-.096,.213,-.04}}) do
                bar(mesh, V(s * joint[1], joint[2], joint[3]),
                    V(s * joint[4], joint[2] + .002, joint[5]), .014, 6)
            end
        end
        rail(mesh, .026, {V(-.175, .962, -.132), V(-.096, .991, -.145),
            V(0, 1.004, -.152), V(.096, .991, -.145), V(.175, .962, -.132)}, 7)
    end, parts)
    r.stickMesh = part(r, root, "stick woven pocket", m.mesh, function(mesh)
        local rows = {
            {.485, .057, -.018, -.008}, {.56, .106, -.018, .029},
            {.642, .149, -.021, .062}, {.723, .182, -.026, .068},
            {.805, .196, -.046, .061}, {.877, .204, -.074, .029},
            {.943, .173, -.105, .012}, {.983, .101, -.142, 0}
        }
        local function knot(row, fraction)
            return V(row[2] * fraction, row[1], row[3] + row[4] * (1 - fraction^2))
        end
        for i = 1, #rows - 1 do
            for j = -4, 4 do
                local fraction = j / 4
                local a = knot(rows[i], fraction)
                for _, step in ipairs({-1, 1}) do
                    if j + step >= -4 and j + step <= 4 then
                        bar(mesh, a, knot(rows[i + 1], (j + step) / 4), .0055, 4)
                    end
                end
            end
        end
        for _, i in ipairs({5, 6}) do
            local points = {}
            for j = -4, 4 do points[#points + 1] = knot(rows[i], j / 4) end
            rail(mesh, .009, points, 5)
        end
    end, parts)
    r.fieldStickHeadModel, r.fieldStickPocketModel = r.stickHead.model, r.stickMesh.model
end

-- A campus humanoid can carry the exact match stick without creating a second athlete.
function Character.addEquipmentStick(rig)
    rig.materials = {
        shaft=material(silver,.25,.55), dark=material(dark),
        stick=material(white,.56), mesh=material(color(204,212,209),.86)
    }
    rig.stickParts = {}
    makeStick(rig)
end

-- Keep the upper grip at the stick origin. Move the pocket, head and mesh
-- together so possessions and release points follow the visible equipment.
function Character.setStickType(rig, kind)
    if not stickSizes[kind] then kind = "short" end
    if kind == rig.stickType then return end
    local size = stickSizes[kind]
    local goalie = kind == "goalie"
    rig.stickType, rig.stickReachExtension = kind, goalie and 0 or size.extension
    rig.stickShaft.model = model("stick alloy "..kind, function(mesh) shaft(mesh,size) end)
    rig.stickTape.model = model("stick tape "..kind, function(mesh) shaftTape(mesh,size) end)
    rig.stickHead.model = goalie and model("goalie stick scoop",goalieHead) or rig.fieldStickHeadModel
    rig.stickMesh.model = goalie and model("goalie deep pocket",goaliePocket) or rig.fieldStickPocketModel
    local offset = goalie and 0 or size.extension
    rig.stickHead.position, rig.stickMesh.position = V(0,offset,0), V(0,offset,0)
    rig.pocket.position = V(0,size.pocketY or .70+size.extension,size.pocketZ or -.10)
    rig.lowerGrip.position = V(0,size.lowerGrip,0)
end

function Character.stickSegment(rig)
    return rig.stickRoot:transformPoint(V(0,.10,0)), rig.pocket.worldPosition
end

local glyphs = {
    [0] = {1,2,3,4,5,6}, {2,3}, {1,2,7,5,4}, {1,2,3,4,7},
    {6,7,2,3}, {1,6,7,3,4}, {1,6,5,7,3,4},
    {1,2,3}, {1,2,3,4,5,6,7}, {1,2,3,4,6,7}
}
local segments = {
    {-.048,.094,.048,.094}, {.063,.083,.063,.009},
    {.063,-.009,.063,-.083}, {-.048,-.094,.048,-.094},
    {-.063,-.009,-.063,-.083}, {-.063,.083,-.063,.009},
    {-.048,0,.048,0}
}

local function numberModel(value, front)
    return model((front and "number front " or "number back ") .. value, function(mesh)
        local text = tostring(value)
        local flip = front and -1 or 1
        local z = front and -.249 or .248
        for i = 1, #text do
            local offset = (i - (#text + 1) * .5) * .16
            local glyph = glyphs[tonumber(text:sub(i, i))]
            for _, segment in ipairs(glyph) do
                local p = segments[segment]
                bar(mesh, V((p[1] + offset) * flip, .558 + p[2], z),
                    V((p[3] + offset) * flip, .558 + p[4], z), .013, 4)
            end
        end
    end)
end

function Character.new(scene)
    local r = {
        scene = scene,
        joints = {}, arms = {}, legs = {},
        armLengthUpper = dimensions.armUpper, armLengthLower = dimensions.armLower,
        legLengthUpper = dimensions.legUpper, legLengthLower = dimensions.legLower,
        ankleHeight = dimensions.ankle, pelvisHeight = dimensions.pelvis,
        hoodieParts = {}, helmetParts = {}, stickParts = {}, campusHidden = {},
        sleeveParts = {left = {}, right = {}}, exposedLegParts = {left = {}, right = {}}
    }
    r.root = entity(scene)
    r.proportions = entity(scene, r.root)
    r.pelvis = entity(scene, r.proportions, 0, r.pelvisHeight, 0)
    r.body = entity(scene, r.pelvis)
    r.joints.torso = r.body
    r.materials = {
        skin = material(skin[2], .90), hair = material(hair[2], .89),
        beard = material(hair[2], .96), white = material(white), dark = material(dark),
        silver = material(silver, .35, .48), jersey = material(jersey[1], .91),
        jerseyTrim = material(white, .91),
        shorts = material(gear[4], .90), sleeves = material(black, .93),
        gloves = material(white, .44), gloveTrim = material(silver, .61),
        cleats = material(white, .51), shaft = material(silver, .25, .55),
        stick = material(white, .56), mesh = material(color(204, 212, 209), .86),
        hoodie = material(jersey[1], .95), hoodTrim = material(silver, .92),
        helmet = material(white, .33), brow = material(white, .41),
        vent = material(dark, .58), liner = material(white, .62),
        cage = material(silver, .25, .62), number = material(white, .96)
    }
    dressTorso(r)
    arm(r, -1, "left")
    arm(r, 1, "right")
    leg(r, -1, "left")
    leg(r, 1, "right")
    makeHead(r)
    makeHelmet(r)
    makeStick(r)
    r.numberFront = entity(scene, r.numberMark)
    r.numberBack = entity(scene, r.numberMark)
    Character.apply(r, defaults)
    return r
end

local function option(profile, key, max)
    return math.min(max, math.max(1, math.floor(tonumber(profile[key]) or defaults[key])))
end

function Character.bodyScale(profile)
    profile=profile or defaults
    local size=bodySizes[option(profile,"BODY",#bodySizes)]
    local athlete=PolyLax.Athlete
    return V(size[1],athlete and athlete.heightScale(profile) or size[2],size[1])
end

function Character.setCampusMode(rig, campus)
    rig.campus = campus == true
    show(rig.campusHidden, not rig.campus)
    rig.numberMark.active = not rig.campus
    if not rig.campus then
        rig.stickRoot.parent = rig.body
        return
    end
    show(rig.helmetParts,false)
    show(rig.hoodieParts,true)
    show(rig.stickParts,true)
    local haircut = option(rig.profile or defaults,"HAIR",6)
    for i=2,6 do rig.hairParts[i].active = i==haircut end
    for _, side in ipairs({"left","right"}) do
        show(rig.sleeveParts[side],false)
        show(rig.exposedLegParts[side],false)
    end
end

function Character.equipmentEnvironment()
    return studioEnvironment()
end

local function applyHelmetFinish(r, chromeFinish)
    if r.chromeFinish == chromeFinish then return end
    local m = r.materials
    local env = chromeFinish and studioEnvironment() or nil
    m.helmet.roughness = chromeFinish and .14 or .32
    m.brow.roughness = chromeFinish and .18 or .37

    local hasEnvironment = false
    if env or r.chromeEnvironment then
        local applied = pcall(function()
            m.helmet.envMap = env
            m.brow.envMap = env
        end)
        hasEnvironment = applied and env ~= nil
    end
    local metallic = chromeFinish and (hasEnvironment and .82 or .56) or .05
    m.helmet.metalness = metallic
    m.brow.metalness = metallic
    r.chromeEnvironment = hasEnvironment
    r.chromeFinish = chromeFinish
end

-- Team colors affect materials only. A custom kit retains the colors and
-- finish selected for that player's helmet, gloves and shorts.
function Character.applyUniform(r, uniform, personalKit)
    local m = r.materials
    local profile = r.profile or defaults
    local sharedGear = personalKit == false and uniform
    local kit = uniform and uniform.primary or jersey[option(profile, "JERSEY", 6)]
    local shellIndex = option(profile, "HELMET", 11)
    local chromeFinish = shellIndex > 6
    local personalShell = chromeFinish and chrome[shellIndex - 6] or gear[shellIndex]
    local shell = sharedGear and sharedGear.shell or personalShell
    local accent = uniform and uniform.accent
    local glove = sharedGear and sharedGear.gloves or gear[option(profile, "GLOVES", 6)]

    m.jersey.diffuse = kit
    m.jerseyTrim.diffuse = uniform and uniform.secondary or white
    m.shorts.diffuse = sharedGear and sharedGear.shorts or gear[option(profile, "SHORTS", 6)]
    m.gloves.diffuse = glove
    m.gloveTrim.diffuse = mix(glove, dark, .42)
    m.gloves.roughness = .47
    m.helmet.diffuse = shell
    if profile.HEIGHT and sharedGear then
        local gloves=option(profile,"GLOVES",6)
        local trim={m.gloveTrim.diffuse,silver,sharedGear.accent,dark,
            mix(glove,silver,.23),mix(glove,dark,.52)}
        m.gloveTrim.diffuse=trim[gloves]
        m.gloves.roughness=({.47,.38,.45,.55,.31,.68})[gloves]
        local brow={accent,silver,dark,sharedGear.secondary,mix(accent,silver,.28),
            mix(accent,dark,.35),accent,dark,silver,mix(accent,silver,.36),sharedGear.secondary}
        accent=brow[shellIndex]
    end
    if accent and personalKit and chromeFinish then
        accent = mix(shell, accent, .35)
    end
    m.brow.diffuse = accent or mix(shell, dark, chromeFinish and .14 or .10)
    applyHelmetFinish(r, chromeFinish)

    local sleeveChoice = option(profile, "SLEEVES", 8)
    m.sleeves.diffuse = ({ black, white, black, kit, white, white, black, black })[sleeveChoice]

    local hoodieChoice = option(profile, "HOODIE", 4)
    local hoodie = ({ kit, kit, white, black })[hoodieChoice]
    m.hoodie.diffuse = hoodie
    m.hoodTrim.diffuse = hoodieChoice == 4 and mix(hoodie, silver, .33) or mix(hoodie, dark, .42)
    local brightness = hoodie.r * .30 + hoodie.g * .59 + hoodie.b * .11
    m.number.diffuse = uniform and hoodieChoice <= 2 and uniform.number or (brightness > 145 and dark or white)
end

function Character.apply(r, profile, category, uniform, personalKit)
    profile = profile or defaults
    r.profile = profile
    local m = r.materials
    local face, haircut, beard = option(profile, "FACE", 4), option(profile, "HAIR", 6),
        option(profile, "BEARD", 6)
    local hairTint = hair[math.max(1, haircut - 1)]
    m.skin.diffuse = skin[face]
    m.hair.diffuse = hairTint
    m.beard.diffuse = mix(hairTint, skin[face], beard == 2 and .62 or .12)
    for i, group in ipairs(r.faceParts) do show(group, i == face) end
    local hasHelmet = category ~= "FACE" and category ~= "HAIR" and category ~= "BEARD"
    for i = 2, 6 do
        r.hairParts[i].active = i == haircut and not hasHelmet
        r.beardParts[i].active = i == beard
    end
    show(r.helmetParts, hasHelmet)
    show(r.stickParts, not (category == "FACE" or category == "HAIR"
        or category == "BEARD" or category == "HELMET"))

    m.cleats.diffuse = gear[option(profile, "CLEATS", 6)]
    m.stick.diffuse = gear[option(profile, "STICK", 6)]

    local sleeveChoice = option(profile, "SLEEVES", 8)
    local both = sleeveChoice >= 2 and sleeveChoice <= 4
    local left = both or sleeveChoice == 5 or sleeveChoice == 7
    local right = both or sleeveChoice == 6 or sleeveChoice == 8
    show(r.sleeveParts.left, left)
    show(r.sleeveParts.right, right)
    show(r.exposedLegParts.left, not left)
    show(r.exposedLegParts.right, not right)
    show(r.hoodieParts, option(profile, "HOODIE", 4) > 1)

    Character.applyUniform(r, uniform, personalKit)
    local value = option(profile, "NUMBER", 100) - 1
    if r.numberValue ~= value then
        r.numberFront.model = numberModel(value, true)
        r.numberBack.model = numberModel(value, false)
        r.numberFront.material = m.number
        r.numberBack.material = m.number
        r.numberValue = value
    end

    r.proportions.scale = Character.bodyScale(profile)
end
