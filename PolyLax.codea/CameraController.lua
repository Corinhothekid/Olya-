-- PolyLax Build 010 | CameraController
PolyLax = PolyLax or {}
local Camera = {}
PolyLax.CameraController = Camera

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
        tanHalf = math.tan(math.rad(fieldOfView) * .5)
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

function Camera.practice(camera, game, dt)
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

    local focus = vec3((left + right) * .5, 1, (far + near) * .5)
    local spread = (near - far) * .5
    local lateral = ((right - left) * .5 + 1.8) / (camera.tanHalf * WIDTH / HEIGHT * .90)
    local distance = math.max(18, lateral + spread * .62, 10 + spread * 2.2)
    local blend = camera.focus and ease(4, dt) or 1
    camera.focus = camera.focus and camera.focus + (focus - camera.focus) * blend or focus
    camera.distance = camera.distance and
        camera.distance + (distance - camera.distance) * blend or distance
    -- Bring the center closer to the camera so the play sits above the controls.
    local target = camera.focus + vec3(0, 0, camera.distance * .12)
    local eye = target + vec3(0, camera.distance * .77, camera.distance * .64)
    aim(camera, eye, target)
end

-- Use the rendered camera's projection for finger aiming overlays.
function Camera.project(camera, position)
    local view = camera.entity:inverseTransformPoint(position)
    if view.z <= .08 then return end

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

function Camera.match(camera, match, dt, aimTarget)
    local player = match.squad[match.controlled].rig.root.position
    local ball = match.ball.position
    local goal = match.goalsByTeam[1]
    local x, z, spread = player.x, player.z - 3.5, 0

    local distanceToBall = math.sqrt((ball.x - player.x)^2 + (ball.z - player.z)^2)
    if distanceToBall < 18 then
        x = x + (ball.x - player.x) * .28
        z = z + (ball.z - player.z) * .24
    end
    local target = aimTarget or (match.phase == "GOAL" and ball)
    if not target and math.abs(player.z - goal.z) < 16 then
        target = vec3(goal.x or 0, 1, goal.z)
    end
    if target then
        local dx, dz = target.x - x, target.z - z
        spread = math.sqrt(dx * dx + dz * dz)
        x, z = x + dx * .43, z + dz * .43
    end

    local focus = vec3(x, 1, z)
    local side = camera.tanHalf * math.max(.36, WIDTH / HEIGHT)
    local distance = math.min(83, math.max(22, 4.4 / side, 15 + spread * 1.12))
    local blend = camera.focus and ease(5, dt) or 1
    camera.focus = camera.focus and camera.focus + (focus - camera.focus) * blend or focus
    camera.distance = camera.distance and
        camera.distance + (distance - camera.distance) * blend or distance
    local viewTarget = camera.focus + vec3(0, 0, camera.distance * .10)
    aim(camera, viewTarget + vec3(0, camera.distance * .72, camera.distance * .69), viewTarget)
end
