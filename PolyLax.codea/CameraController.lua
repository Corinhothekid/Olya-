-- PolyLax Build 012 | Creator and field cameras
PolyLax = PolyLax or {}
local Camera = {}
PolyLax.CameraController = Camera

local modes = {"DYNAMIC", "BROADCAST", "PLAYER LOCK"}

local function ease(rate, dt)
    return 1 - math.exp(-rate * dt)
end

local function aim(camera, eye, target)
    camera.entity.position = eye
    -- Craft looks along its local +Z axis. Aim directly at the target.
    camera.entity.rotation = quat.lookRotation(
        (target - eye):normalize(), vec3(0, 1, 0)
    )
end

function Camera.new(scene, fieldOfView)
    local entity = scene.camera
    local lens = entity:get(craft.camera)
    lens.fieldOfView = fieldOfView
    lens.nearPlane = .08
    lens.farPlane = 130

    return {
        entity = entity, lens = lens,
        tanHalf = math.tan(math.rad(fieldOfView) * .5), modeIndex = 1, zoomSteps = 0
    }
end

local function previewBounds(rig, category)
    local height = rig.proportions.scale.y
    local width = rig.proportions.scale.x
    if category == "FACE" or category == "HAIR" or
       category == "BEARD" or category == "HELMET" then
        local headY = rig.head.worldPosition.y
        return headY - .37 * height, headY + .79 * height, .68 * width
    elseif category == "GLOVES" then
        return .99 * height, 3.12 * height, 1.29 * width
    end
    return -.05, 3.16 * height, 1.40 * width
end

function Camera.preview(camera, rig, category, frame, dt)
    local low, high, radius = previewBounds(rig, category)
    local t = camera.tanHalf
    local qLow = (2 * frame.bottom / HEIGHT - 1) * t
    local qHigh = (2 * frame.top / HEIGHT - 1) * t

    -- The player can turn through 360 degrees. Reserve the same radius
    -- for both depth and width so the framing survives the turn.
    local distanceY = (high - low + radius * (math.abs(qLow) + math.abs(qHigh))) /
                      (qHigh - qLow)
    local distanceX = radius + radius / (t * WIDTH / HEIGHT * .88)
    local distance = math.max(distanceX, distanceY)
    local lowEye = high - qHigh * distance + radius * math.abs(qHigh)
    local highEye = low - qLow * distance - radius * math.abs(qLow)
    local eyeY = (lowEye + highEye) * .5

    local blend = camera.distance and ease(8, dt) or 1
    camera.distance = camera.distance and
        camera.distance + (distance - camera.distance) * blend or distance
    camera.eyeY = camera.eyeY and camera.eyeY + (eyeY - camera.eyeY) * blend or eyeY
    aim(camera, vec3(0, camera.eyeY, -camera.distance), vec3(0, camera.eyeY, 0))
end

local function practicePose(camera, game, aimTarget)
    local controlled = game.squad[game.controlled].rig.root.position
    local carrier = game.carrier and game.squad[game.carrier].rig.root.position
    local ball = carrier or game.ball.position
    local goal = game.goal
    local left, right = math.min(controlled.x, ball.x, goal.x),
                        math.max(controlled.x, ball.x, goal.x)
    local far, near = math.min(controlled.z, ball.z, goal.z),
                      math.max(controlled.z, ball.z, goal.z)
    for _, player in ipairs(game.squad) do
        local p = player.rig.root.position
        local dx, dz = p.x - ball.x, p.z - ball.z
        if dx * dx + dz * dz < 145 then
            left, right = math.min(left, p.x), math.max(right, p.x)
            far, near = math.min(far, p.z), math.max(near, p.z)
        end
    end
    if aimTarget then
        left, right = math.min(left, aimTarget.x), math.max(right, aimTarget.x)
        far, near = math.min(far, aimTarget.z), math.max(near, aimTarget.z)
    end

    local focus = vec3((left + right) * .5, 1, (far + near) * .5)
    local spread = (near - far) * .5
    local lateral = ((right - left) * .5 + 1.8) / (camera.tanHalf * WIDTH / HEIGHT * .90)
    local distance = math.max(18, lateral + spread * .62, 10 + spread * 2.2)
    distance = distance * 1.16 ^ -camera.zoomSteps
    -- Keep the original practice view and its space above the controls.
    local target = focus + vec3(0, 0, distance * .12)
    return target + vec3(0, distance * .77, distance * .64), target
end

-- Use the rendered camera's projection for finger aiming overlays.
function Camera.project(camera, position)
    local view = camera.entity:inverseTransformPoint(position)
    if view.z <= camera.lens.nearPlane then return end

    if camera.lens.worldToScreen then
        local screen = camera.lens:worldToScreen(position)
        if screen and screen.x == screen.x and screen.y == screen.y and
           math.abs(screen.x) < 1e6 and math.abs(screen.y) < 1e6 then
            return screen
        end
    end
    local factor = HEIGHT * .5 / (view.z * camera.tanHalf)
    return vec2(WIDTH * .5 + view.x * factor, HEIGHT * .5 + view.y * factor)
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Camera.mode(camera)
    return modes[camera.modeIndex]
end

function Camera.cycle(camera)
    camera.modeIndex = camera.modeIndex % #modes + 1
    return Camera.mode(camera)
end

function Camera.zoom(camera, delta)
    camera.zoomSteps = clamp(camera.zoomSteps + delta, -3, 3)
    return camera.zoomSteps
end

local function framedPose(camera, box, center, angle, frame, minDistance, fitAll)
    local width, height = math.max(1, WIDTH), math.max(1, HEIGHT)
    local bottom = clamp(frame and frame.bottom or height * .20, 0, height * .70)
    local top = clamp(frame and frame.top or height * .86, bottom + height * .16, height)
    local lowY = (2 * bottom / height - 1) * camera.tanHalf
    local highY = (2 * top / height - 1) * camera.tanHalf
    local sideSlope = .92 * camera.tanHalf * width / height
    local rise, run = math.sin(angle), math.cos(angle)
    local upper = -math.huge
    local lower = math.huge
    local distance = minDistance
    local spanX = math.max(math.abs(box.left - center.x), math.abs(box.right - center.x))

    -- With the lens pointed at a fixed pitch, each corner lies at depth D + dz.
    -- Solve the horizontal bound and the interval of allowed vertical shifts.
    for _, y in ipairs({box.low, box.high}) do
        local dy = y - center.y
        for _, z in ipairs({box.far, box.near}) do
            local dz = z - center.z
            local viewDepth = -rise * dy - run * dz
            local viewY = run * dy - rise * dz
            distance = math.max(distance, spanX / sideSlope - viewDepth, .35 - viewDepth)
            upper = math.max(upper, viewY - highY * viewDepth)
            lower = math.min(lower, viewY - lowY * viewDepth)
        end
    end
    distance = math.max(distance, (upper - lower) / (highY - lowY))
    local zoomDistance = distance * 1.055 * 1.16 ^ -camera.zoomSteps
    distance = fitAll and math.max(distance, zoomDistance) or math.max(minDistance * .72, zoomDistance)
    local shift = (upper + lower - (highY + lowY) * distance) * .5
    local target = center + vec3(0, run * shift, -rise * shift)
    return target + vec3(0, rise * distance, run * distance), target
end

local function applyPlayPose(camera, eye, target, speed, dt)
    if not camera.playEye then
        camera.lens.nearPlane = 1.1
        camera.lens.farPlane = 455
    end
    local blend = camera.playEye and ease(speed, dt) or 1
    camera.playEye = camera.playEye and camera.playEye + (eye - camera.playEye) * blend or eye
    camera.playTarget = camera.playTarget and
        camera.playTarget + (target - camera.playTarget) * blend or target
    aim(camera, camera.playEye, camera.playTarget)
end

local function broadcastPose(camera, game, frame)
    local field = game.field
    local width = field and field.halfWidth or 9
    local length = field and field.halfLength or 17
    local current = camera.broadcast
    local bottom, top = frame and frame.bottom, frame and frame.top
    if current and current.width == WIDTH and current.height == HEIGHT and
        current.fieldWidth == width and current.fieldLength == length and
        current.bottom == bottom and current.top == top and current.zoom == camera.zoomSteps then
        return current.eye, current.target
    end

    local y = 1.7
    local bounds = {
        left = -width - .65, right = width + .65,
        far = -length - .65, near = length + .65,
        low = -.08, high = 4.1
    }
    local eye, target = framedPose(camera, bounds, vec3(0, y, 0), math.rad(72), frame, 15, true)
    camera.broadcast = {
        eye = eye, target = target, width = WIDTH, height = HEIGHT,
        fieldWidth = width, fieldLength = length, bottom = bottom, top = top, zoom = camera.zoomSteps
    }
    return eye, target
end

local function playerPosition(game, reference)
    local player = type(reference) == "table" and reference or game.squad[reference]
    return player and player.rig.root.position
end

local function area(position, sideways, length)
    return {
        left = position.x - sideways, right = position.x + sideways,
        far = position.z - length, near = position.z + length,
        low = -.04, high = math.max(3.45, position.y + .3)
    }
end

local function include(bounds, x, y, z, padding)
    bounds.left = math.min(bounds.left, x - padding)
    bounds.right = math.max(bounds.right, x + padding)
    bounds.far = math.min(bounds.far, z - padding)
    bounds.near = math.max(bounds.near, z + padding)
    bounds.high = math.max(bounds.high, y + padding)
end

local function nearbyGoal(game, ball)
    if not game.goalsByTeam then return game.goal end
    local nearest, best
    for _, goal in ipairs(game.goalsByTeam) do
        local score = (goal.x - ball.x)^2 + (goal.z - ball.z)^2
        if not best or score < best then nearest, best = goal, score end
    end
    return nearest
end

local function dynamicPose(camera, match, aimTarget, frame)
    local ball = match.ball.position
    local controlled = match.squad[match.controlled]
    local bounds = area(ball, 4.6, 5.4)
    for _, player in ipairs(match.squad) do
        local position = player.rig.root.position
        local dx, dz = position.x - ball.x, position.z - ball.z
        if dx * dx + dz * dz < (player == controlled and 215 or 96) then
            include(bounds, position.x, 2.15, position.z, 1.1)
        end
    end

    local goal = nearbyGoal(match, ball)
    if goal and (goal.x - ball.x)^2 + (goal.z - ball.z)^2 < 15^2 then
        include(bounds, goal.x, goal.top or 1.83, goal.z, 1.5)
    end
    if aimTarget then
        local position = controlled.rig.root.position
        include(bounds, position.x, 2.15, position.z, 1.1)
        include(bounds, aimTarget.x, aimTarget.y, aimTarget.z, 1.4)
    end
    local center = vec3((bounds.left + bounds.right) * .5, 1.25, (bounds.far + bounds.near) * .5)
    return framedPose(camera, bounds, center, math.rad(49), frame, 18, aimTarget ~= nil)
end

local function playerLockPose(camera, game, aimTarget, frame)
    local position = playerPosition(game, game.careerPlayer) or playerPosition(game, game.controlled)
    local bounds = area(position, 3.9, 5.1)
    if aimTarget then include(bounds, aimTarget.x, aimTarget.y, aimTarget.z, .85) end
    local center = vec3(position.x, 1.18, position.z)
    return framedPose(camera, bounds, center, math.rad(45), frame, 14, aimTarget ~= nil)
end

function Camera.practice(camera, game, dt, aimTarget, frame)
    local mode = Camera.mode(camera)
    local eye, target
    if mode == "BROADCAST" then
        eye, target = broadcastPose(camera, game, frame)
    elseif mode == "PLAYER LOCK" then
        eye, target = playerLockPose(camera, game, aimTarget, frame)
    else
        eye, target = practicePose(camera, game, aimTarget)
    end
    applyPlayPose(camera, eye, target, mode == "DYNAMIC" and 4 or 5.5, dt)
end

function Camera.match(camera, match, dt, aimTarget, frame)
    local mode = Camera.mode(camera)
    local eye, target
    if mode == "BROADCAST" then
        eye, target = broadcastPose(camera, match, frame)
    elseif mode == "PLAYER LOCK" then
        eye, target = playerLockPose(camera, match, aimTarget, frame)
    else
        eye, target = dynamicPose(camera, match, aimTarget, frame)
    end
    applyPlayPose(camera, eye, target, mode == "DYNAMIC" and 5 or 5.5, dt)
end
