-- Swept lacrosse goal contacts, capture and net response.
PolyLax = PolyLax or {}
local GoalPhysics = {}
PolyLax.GoalPhysics = GoalPhysics

local epsilon = 1e-7
local scoreHold = 1.4
GoalPhysics.scoreHold = scoreHold

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function pointAt(start, delta, time)
    return start + delta * time
end

-- Return the first entry of a segment into a sphere or an infinite cylinder
-- after the caller has removed the component along the cylinder's axis.
local function entryTime(offset, delta, radius)
    local a = delta:dot(delta)
    local b = offset:dot(delta)
    local c = offset:dot(offset) - radius * radius
    if a <= epsilon or b >= 0 then return nil end
    if c <= 0 then return 0 end
    local discriminant = b * b - a * c
    if discriminant < 0 then return nil end
    local time = (-b - math.sqrt(discriminant)) / a
    if time >= 0 and time <= 1 then return time end
end

local function sweepCapsule(start, finish, a, b, radius)
    local delta, segment = finish - start, b - a
    local span = segment:len()
    local time = entryTime(start - a, delta, radius)
    if span <= epsilon then return time, a end

    local axis, offset = segment / span, start - a
    local at, along = offset:dot(axis), delta:dot(axis)
    local cylinder = entryTime(offset - axis * at, delta - axis * along, radius)
    local endpoint = entryTime(start - b, delta, radius)
    if endpoint and (not time or endpoint < time) then time = endpoint end
    if cylinder and (not time or cylinder < time)
        and at + along * cylinder >= 0 and at + along * cylinder <= span then
        time = cylinder
    end
    if not time then return nil end
    return time, a + axis * clamp(at + along * time, 0, span)
end

local function meshTriangle(mesh, a, b, c)
    local normal = (b-a):cross(c-a):normalize()
    local index = #mesh.positions+1
    mesh.positions[index], mesh.positions[index+1], mesh.positions[index+2] = a,b,c
    mesh.normals[index], mesh.normals[index+1], mesh.normals[index+2] = normal,normal,normal
    local indices = mesh.indices
    local i = #indices+1
    indices[i], indices[i+1], indices[i+2] = index,index+1,index+2
    indices[i+3], indices[i+4], indices[i+5] = index,index+2,index+1
end

local function meshRod(mesh, a, b, width, sides)
    local axis = (b-a):normalize()
    local up = math.abs(axis.y) < .9 and vec3(0,1,0) or vec3(1,0,0)
    local u = axis:cross(up):normalize()
    local v = axis:cross(u)
    local function edge(i)
        local theta = i*2*math.pi/sides
        return (u*math.cos(theta)+v*math.sin(theta))*(width*.5)
    end
    for i=0,sides-1 do
        local u0, u1 = edge(i), edge(i+1)
        meshTriangle(mesh, a+u0, a+u1, b+u1)
        meshTriangle(mesh, a+u0, b+u1, b+u0)
        meshTriangle(mesh, a, a+u1, a+u0)
        meshTriangle(mesh, b, b+u0, b+u1)
    end
end

local function buildNet(scene, goal)
    local standard = asset and asset.builtin and asset.builtin.Materials
    local function material(tint)
        local m = craft.material(standard and standard.Standard or "Materials:Standard")
        m.diffuse = tint
        return m
    end
    local frame = material(color(246, 113, 31))
    local thread = material(color(197, 213, 223))
    local cube = craft.model.cube(vec3(1, 1, 1))
    local rear = goal.z + goal.attackSign * goal.depth
    local meshFor = {
        [frame]={positions={},normals={},indices={}},
        [thread]={positions={},normals={},indices={}}
    }

    local function rod(a, b, width, tint, moves)
        if not moves then
            meshRod(meshFor[tint], a, b, width, tint == frame and 8 or 4)
            return
        end
        local e, span = scene:entity(), b - a
        local center = (a + b) * .5
        e.model, e.material = cube, tint
        e.position, e.scale = center, vec3(width, span:len(), width)
        e.rotation = quat.fromToRotation(vec3(0, 1, 0), span:normalize())
        goal.net[#goal.net+1] = {entity=e, rest=center}
    end

    for _, piece in ipairs(goal.frame) do
        rod(piece.a, piece.b, goal.postRadius * 2, frame)
    end
    for _, side in ipairs({-1, 1}) do
        local x = goal.x + side * (goal.halfWidth + goal.postRadius)
        rod(vec3(x, .032, goal.z), vec3(x, .032, rear), .064, frame)
        rod(vec3(x, .032, rear), vec3(x, goal.top, rear), .045, thread)
        for i=1, 6 do
            local y = goal.top * i / 7
            rod(vec3(x, y, goal.z), vec3(x, y, rear), .011, thread)
        end
        for i=1, 3 do
            local z = goal.z + (rear - goal.z) * i / 4
            rod(vec3(x, .04, z), vec3(x, goal.top, z), .010, thread)
        end
    end
    for i=0, 9 do
        local x = goal.x - goal.halfWidth + goal.halfWidth * 2 * i / 9
        rod(vec3(x, .042, rear), vec3(x, goal.top, rear), .013, thread, true)
        rod(vec3(x, goal.top, goal.z), vec3(x, goal.top, rear), .012, thread)
    end
    for i=0, 8 do
        local y = .04 + (goal.top - .04) * i / 8
        rod(vec3(goal.x - goal.halfWidth, y, rear),
            vec3(goal.x + goal.halfWidth, y, rear), .013, thread, true)
    end
    for i=1, 3 do
        local z = goal.z + (rear - goal.z) * i / 4
        rod(vec3(goal.x - goal.halfWidth, goal.top, z),
            vec3(goal.x + goal.halfWidth, goal.top, z), .011, thread)
    end
    for _, tint in ipairs({frame,thread}) do
        local mesh = meshFor[tint]
        local model = craft.model()
        local colors, uvs, white, origin = {}, {}, color(255,255,255), vec2(0,0)
        for index=1,#mesh.positions do
            colors[index], uvs[index] = white, origin
        end
        model.positions, model.normals = mesh.positions, mesh.normals
        model.colors, model.uvs, model.indices = colors, uvs, mesh.indices
        local e = scene:entity()
        e.model, e.material = model, tint
    end
end

function GoalPhysics.new(scene, config)
    local goal = {
        x=config.x or 0, z=config.z, attackSign=config.attackSign or -1,
        halfWidth=config.halfWidth or .9144, top=config.top or 1.8288,
        radius=config.radius or .09, postRadius=config.postRadius or .055,
        depth=config.depth or 1.10, net={}
    }
    local x, y, z = goal.x, goal.top + goal.postRadius, goal.z
    local width = goal.halfWidth + goal.postRadius
    local left, right = vec3(x-width,y,z), vec3(x+width,y,z)
    goal.frame = {
        {kind="POST", a=vec3(x-width,0,z), b=left},
        {kind="POST", a=vec3(x+width,0,z), b=right},
        {kind="CROSSBAR", a=left, b=right}
    }
    if scene then buildNet(scene, goal) end
    return goal
end

local function collision(kind, time, position, center, velocity)
    local normal = position - center
    if normal:len() < epsilon then normal = velocity * -1 end
    if normal:len() < epsilon then normal = vec3(0, 1, 0) end
    normal = normal:normalize()
    local restitution = kind == "SAVE" and .28 or .48
    local impulse = math.min(0, velocity:dot(normal)) * (1 + restitution)
    return {
        kind=kind, time=time, position=position, normal=normal, velocity=velocity-normal*impulse
    }
end

-- Check all possible contacts before returning the earliest. Goal detection
-- uses the trailing edge of the ball and works in either attacking direction.
function GoalPhysics.step(goal, from, to, velocity, keeper)
    local delta = to - from
    local hit
    for _, piece in ipairs(goal.frame) do
        local time, center = sweepCapsule(from, to, piece.a, piece.b, goal.radius + goal.postRadius)
        if time and (not hit or time < hit.time) then
            hit = collision(piece.kind, time, pointAt(from, delta, time), center, velocity)
        end
    end

    local advancing = delta.z * goal.attackSign > 0
    if advancing and keeper then
        local width = keeper.halfWidth or .37
        local centerX, centerZ = keeper.prevX or keeper.x, keeper.prevZ or keeper.z
        local movement = vec3(keeper.x - centerX, 0, keeper.z - centerZ)
        local low, high = keeper.low or .24, keeper.high or 1.72
        local mid = (low + high) * .5
        local a = vec3(centerX, math.min(low + width, mid), centerZ)
        local b = vec3(centerX, math.max(high - width, mid), centerZ)
        local time, center = sweepCapsule(from, to-movement, a, b, width+goal.radius)
        if time and (not hit or time <= hit.time) then
            hit = collision("SAVE", time, pointAt(from, delta, time),
                center+movement*time, velocity)
        end
    end

    local depth = (from.z - goal.z) * goal.attackSign
    local finishDepth = (to.z - goal.z) * goal.attackSign
    if advancing and depth < goal.radius and finishDepth >= goal.radius then
        local time = (goal.radius-depth) / (finishDepth-depth)
        if not hit or time < hit.time then
            local pos = pointAt(from, delta, time)
            local kind = "GOAL"
            if math.abs(pos.x-goal.x) > goal.halfWidth-goal.radius then
                kind = "WIDE"
            elseif pos.y > goal.top-goal.radius then
                kind = "HIGH"
            elseif pos.y < goal.radius-epsilon then
                kind = "LOW"
            end
            hit = {kind=kind, time=time, position=pos, velocity=velocity}
        end
    end
    return hit
end

function GoalPhysics.capture(goal, position)
    local radius = goal.radius
    local inside = vec3(
        clamp(position.x, goal.x-goal.halfWidth+radius, goal.x+goal.halfWidth-radius),
        clamp(position.y, radius, goal.top-radius),
        goal.z + goal.attackSign * (goal.depth-radius-.025)
    )
    goal.impact, goal.netTime = inside, 0
    return inside
end

function GoalPhysics.reset(goal)
    for _, strand in ipairs(goal.net) do strand.entity.position = strand.rest end
    goal.impact, goal.netTime = nil, nil
end

function GoalPhysics.update(goal, dt)
    if not goal.impact then return end
    goal.netTime = goal.netTime + dt
    if goal.netTime >= .54 then
        GoalPhysics.reset(goal)
        return
    end
    local t = goal.netTime - .06
    if t < 0 then return end
    local spring = math.sin(t * 24) * .18 * math.exp(-t * 8)
    for _, strand in ipairs(goal.net) do
        local rest = strand.rest
        local dx, dy = rest.x-goal.impact.x, rest.y-goal.impact.y
        local influence = math.exp(-(dx*dx + dy*dy)*2)
        strand.entity.position = vec3(rest.x, rest.y, rest.z+goal.attackSign*spring*influence)
    end
end
