-- PolyLax Build 010. Procedural animation and hand/foot constraints.
PolyLax = PolyLax or {}
local Animation = {}
PolyLax.AnimationController = Animation

local function frame(time, grip, shaft, torso, crouch, roll, freeHand)
    return {
        time = time, grip = grip, shaft = shaft, torso = torso,
        crouch = crouch or 0, roll = roll or 0, freeHand = freeHand or 0
    }
end

Animation.clips = {
    pass = {
        duration = .62, eventTime = .29, event = "release",
        poses = {
            frame(.16, vec3(.35,.84,.12), vec3(.75,.50,.40), vec3(4,-28,-5), .025, -20),
            frame(.29, vec3(.28,.82,-.40), vec3(.71,.53,-.47), vec3(-10,15,4), .035, 9),
            frame(.41, vec3(.19,.52,-.42), vec3(.72,.05,-.69), vec3(-15,25,5), .035, 25)
        }
    },
    shoot = {
        duration = .75, eventTime = .38, event = "release",
        poses = {
            frame(.21, vec3(.45,.91,.18), vec3(.72,.46,.52), vec3(9,-43,-8), .055, -26),
            frame(.38, vec3(.33,.83,-.43), vec3(.69,.38,-.61), vec3(-15,25,6), .070, 12),
            frame(.52, vec3(.14,.44,-.46), vec3(.75,-.24,-.61), vec3(-25,35,9), .080, 35)
        }
    },
    catch = {
        duration = .42, eventTime = .18, event = "catch",
        poses = {
            frame(.18, vec3(.25,.81,-.43), vec3(.57,.79,-.22), vec3(-6,-9,-3), .03, -15),
            frame(.30, vec3(.26,.68,-.23), vec3(.75,.58,.18), vec3(3,-12,-4), .02, 12)
        }
    },
    dodge = {
        duration = .46,
        poses = {
            frame(.09, vec3(.26,.65,-.17), vec3(.86,.48,.11), vec3(-10,-17,-9), .12, -30),
            frame(.23, vec3(.35,.57,-.14), vec3(.91,.34,.11), vec3(-16,-30,-20), .15, -38),
            frame(.34, vec3(.30,.63,-.22), vec3(.83,.54,.08), vec3(-8,-13,-9), .07, -15)
        }
    },
    protect = {
        duration = .42,
        poses = {
            frame(.12, vec3(.36,.65,-.13), vec3(.91,.37,.10), vec3(-5,-23,-9), .08, -28),
            frame(.26, vec3(.36,.64,-.15), vec3(.86,.48,.11), vec3(-5,-20,-8), .06, -26)
        }
    },
    scoop = {
        duration = .60, eventTime = .32, event = "scoop",
        poses = {
            frame(.14, vec3(.39,.39,-.33), vec3(.25,.15,-.95), vec3(-23,-5,-5), .14, -8, .55),
            frame(.32, vec3(.38,.28,-.34), vec3(.08,-.52,-.85), vec3(-30,-4,-6), .31, -3, 1),
            frame(.44, vec3(.27,.49,-.35), vec3(.45,.23,-.86), vec3(-15,-4,-2), .12, 10, .3)
        }
    }
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function smooth(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function blend(a, b, t)
    return a + (b - a) * t
end

local function mixPose(a, b, t)
    t = smooth(t)
    return {
        grip = blend(a.grip, b.grip, t),
        shaft = blend(a.shaft, b.shaft, t),
        torso = blend(a.torso, b.torso, t),
        crouch = blend(a.crouch, b.crouch, t),
        roll = blend(a.roll, b.roll, t),
        freeHand = blend(a.freeHand, b.freeHand, t)
    }
end

-- Rotate a vector without relying on a Craft-specific quaternion-vector operator.
local function rotate(rotation, vector, inverse)
    local axis = vec3(rotation.x, rotation.y, rotation.z)
    if inverse then axis = axis * -1 end
    local twiceCross = axis:cross(vector) * 2
    return vector + twiceCross * rotation.w + axis:cross(twiceCross)
end

local function limited(point, center, radius)
    local offset = point - center
    local distance = offset:len()
    if distance <= radius then return point end
    return center + offset * (radius / distance)
end

-- The elbow or knee is the intersection of the two limb-length spheres.
-- The bend direction chooses its position along that circle.
local function solveLimb(upper, lower, target, firstLength, secondLength, bend)
    local down = vec3(0, -1, 0)
    local offset = target - upper.position
    local reach = offset:len()
    local direction = reach > .0001 and offset / reach or down
    local distance = clamp(reach, math.abs(firstLength - secondLength) + .001,
        firstLength + secondLength - .001)
    local side = bend - direction * bend:dot(direction)
    if side:len() < .001 then
        local alternate = math.abs(direction.x) < .8 and vec3(1,0,0) or vec3(0,0,1)
        side = alternate - direction * alternate:dot(direction)
    end
    local along = (firstLength * firstLength - secondLength * secondLength
        + distance * distance) / (2 * distance)
    local elbow = direction * along + side:normalize() *
        math.sqrt(math.max(0, firstLength * firstLength - along * along))
    local tip = direction * distance
    local upperRotation = quat.fromToRotation(down, elbow / firstLength)
    local secondDirection = rotate(upperRotation, (tip - elbow) / secondLength, true)
    local lowerRotation = quat.fromToRotation(down, secondDirection)
    upper.rotation = upperRotation
    lower.rotation = lowerRotation
    return upperRotation, lowerRotation
end

local function placeArms(rig, pose, pocketTarget, pocketWeight)
    local joints = rig.joints
    local shaft = pose.shaft:normalize()
    local shaftRotation = quat.fromToRotation(vec3(0,1,0), shaft)
    local roll = math.rad(pose.roll)
    local depth = rotate(shaftRotation, vec3(math.sin(roll),0,math.cos(roll)))
    local right = joints.rightShoulder.position
    local reach = rig.armLengthUpper + rig.armLengthLower - .012
    local top = limited(pose.grip, right, reach)
    local stickRotation = quat.lookRotation(depth, shaft)
    if pocketTarget then
        local localPoint = rig.body:inverseTransformPoint(pocketTarget)
        local towardBall = localPoint - right
        local pocket = rotate(stickRotation, rig.pocket.position)
        local distance, stickLength = towardBall:len(), pocket:len()
        local axis = pocket:cross(towardBall)
        -- Keep the scoop's original direction unless the grip would sit
        -- beyond the top hand's reach. Rotate only the excess from that cone.
        if (towardBall - pocket):len() > reach and axis:len() > .001 then
            local cosine = clamp(pocket:dot(towardBall) / (stickLength * distance), -1, 1)
            local reachCosine = clamp((distance * distance + stickLength * stickLength -
                reach * reach) / (2 * stickLength * distance), -1, 1)
            local correction = math.deg(math.acos(cosine) - math.acos(reachCosine))
            local rotation = quat.angleAxis(correction * pocketWeight, axis:normalize())
            stickRotation = quat.lookRotation(rotate(rotation, depth), rotate(rotation, shaft))
        end
        local targetGrip = localPoint - rotate(stickRotation, rig.pocket.position)
        local reachableGrip = limited(limited(targetGrip, top, .58), right, reach)
        top = blend(top, reachableGrip, pocketWeight)
    end
    rig.stickRoot.rotation = stickRotation
    local lowerOffset = rotate(stickRotation, rig.lowerGrip.position)
    local left = joints.leftShoulder.position - lowerOffset

    -- Shift the shaft toward both hands' shared reach before solving their poses.
    -- A scoop lets the bottom hand come off the shaft as the head approaches turf.
    local shared = top
    for _ = 1, 4 do
        shared = limited(limited(shared, left, reach), right, reach)
    end
    if (shared - left):len() > reach + .001 then shared = (right + left) * .5 end
    top = blend(shared, top, pose.freeHand)
    rig.stickRoot.position = top
    local leftHand = blend(top + lowerOffset, vec3(-.49,.19,-.17), pose.freeHand)
    solveLimb(joints.rightShoulder, joints.rightElbow, top,
        rig.armLengthUpper, rig.armLengthLower, vec3(.82,-.82,.40))
    solveLimb(joints.leftShoulder, joints.leftElbow, leftHand,
        rig.armLengthUpper, rig.armLengthLower, vec3(-.82,-.82,.32))
end

local function placeLeg(rig, hip, knee, ankle, target, pitch, yaw)
    local upper, lower = solveLimb(hip, knee, target - rig.pelvis.position,
        rig.legLengthUpper, rig.legLengthLower, vec3(0,0,-1))
    local footRotation = quat.eulerAngles(pitch, yaw, 0)
    local up = rotate(lower, rotate(upper, rotate(footRotation, vec3(0,1,0)), true), true)
    local back = rotate(lower, rotate(upper, rotate(footRotation, vec3(0,0,1)), true), true)
    ankle.rotation = quat.lookRotation(back, up)
end

local function footTarget(controller, foot, hip, phase, duty, movement, stride, weight)
    local rig = controller.rig
    local space = rig.proportions
    local neutral = vec3(hip.position.x, rig.ankleHeight, 0)
    local pitch = 0
    local target = neutral

    if weight > .025 then
        local lead = neutral + movement * stride
        if phase < duty then
            if not foot.plant then foot.plant = foot.previous or space:transformPoint(lead) end
            target = space:inverseTransformPoint(foot.plant)
            foot.swingOrigin = nil
        else
            if not foot.swingOrigin then
                foot.swingOrigin = foot.plant or foot.previous or space:transformPoint(neutral)
            end
            foot.plant = nil
            local progress = (phase - duty) / (1 - duty)
            local origin = space:inverseTransformPoint(foot.swingOrigin)
            local clearance = math.sin(math.pi * progress)
            target = blend(origin, lead, smooth(progress))
            target.y = neutral.y + clearance * (.07 + stride * .19)
            pitch = math.sin(progress * math.pi * 2) * 14
        end
    else
        foot.plant, foot.swingOrigin = nil, nil
    end

    -- Ground contact survives body bob and small turns. Ease feet back under the
    -- hips as speed falls and keep crossed legs out of the neutral stance.
    target.x = hip.position.x < 0 and math.min(target.x, -.08) or math.max(target.x, .08)
    target = blend(neutral, target, weight)
    foot.previous = space:transformPoint(target)
    return target, pitch * weight
end

local function sampleAction(clip, time, base, entry)
    local previous = entry or base
    local previousTime = 0
    for _, pose in ipairs(clip.poses) do
        if time <= pose.time then
            return mixPose(previous, pose, (time - previousTime) / (pose.time - previousTime))
        end
        previous = pose
        previousTime = pose.time
    end
    return mixPose(previous, base, (time - previousTime) / (clip.duration - previousTime))
end

function Animation.new(rig)
    local controller = {rig = rig}
    Animation.reset(controller)
    return controller
end

function Animation.play(controller, action, speedScale)
    if not Animation.clips[action] then return false end
    if controller.action then
        local current = Animation.clips[controller.action]
        local canCatch = action == "catch" and controller.action ~= "catch" and
            controller.actionTime >= (current.eventTime or current.duration * .5)
        if not canCatch then return false end
    end
    controller.entry = controller.action and controller.lastPose or nil
    controller.action = action
    controller.actionTime = 0
    controller.actionSpeed = clamp(speedScale or 1, .5, 2)
    return true
end

function Animation.update(controller, dt, input)
    input = input or {}
    local rig, joints = controller.rig, controller.rig.joints
    local speed = math.max(0, input.speed or 0)
    local turn = clamp(input.turn or 0, -1, 1)
    local rootPosition = rig.root.worldPosition
    local velocity = vec3(0,0,-1)

    if dt > 0 then
        local delta = rig.proportions:inverseTransformPoint(rootPosition)
            - rig.proportions:inverseTransformPoint(controller.lastPosition)
        delta.y = 0
        if delta:len() > .0001 then velocity = delta:normalize() end
    end
    controller.lastPosition = rootPosition
    local speedMix = 1 - math.exp(-dt * (speed > controller.speed and 12 or 9))
    controller.speed = blend(controller.speed, speed, speedMix)
    controller.carry = blend(controller.carry, input.possessed and 1 or 0, 1 - math.exp(-dt * 10))
    controller.turn = blend(controller.turn, turn, 1 - math.exp(-dt * 12))
    controller.time = controller.time + dt

    local gait = smooth(controller.speed / .9)
    local run = smooth((controller.speed - 2) / 4.3)
    local cycle = 1.25 + .37 * math.min(controller.speed, 6.5)
    local duty = blend(.66, .47, run)
    local stride = clamp(controller.speed / (cycle * rig.proportions.scale.z) * duty * .5, 0, .42)
    controller.phase = (controller.phase + dt * cycle * gait) % 1
    controller.locomotion = controller.speed < .12 and "idle" or
        (controller.speed < 2.7 and "walk" or (controller.speed < 5.1 and "jog" or "sprint"))
    local phase = controller.phase * math.pi * 2
    local swing = math.sin(phase) * gait
    local breath = math.sin(controller.time * 2.8)
    local cradle = math.sin(controller.time * (2.5 + gait * 1.2) + swing * .28) * controller.carry
    local base = {
        grip = vec3(.19 + cradle * .027, .66 + breath * .012 + swing * .028,
            -.31 + swing * .061 + cradle * .033),
        shaft = vec3(.78 + cradle * .07, .62 - cradle * .07, -.04 + swing * .22 + cradle * .12),
        torso = vec3(-gait * (3 + run * 9), swing * (3 + run * 4),
            -controller.turn * (4 + gait * 7) + swing * 2),
        crouch = 0, roll = cradle * 21 + swing * 8, freeHand = 0
    }
    local pose, event = base, nil
    local pocketTarget, pocketWeight
    if controller.action then
        local clip = Animation.clips[controller.action]
        local oldTime = controller.actionTime
        local newTime = oldTime + dt * controller.actionSpeed
        local sampleTime = newTime
        if clip.eventTime and oldTime < clip.eventTime and newTime >= clip.eventTime then
            event = clip.event
            sampleTime = clip.eventTime
        end
        pose = sampleAction(clip, math.min(sampleTime, clip.duration), base, controller.entry)
        if controller.action == "scoop" and input.scoopPoint then
            pocketWeight = smooth(1 - math.abs(sampleTime - clip.eventTime) / .14)
            if pocketWeight > 0 then pocketTarget = input.scoopPoint end
        elseif controller.action == "catch" and input.catchPoint then
            pocketWeight = smooth(1 - math.abs(sampleTime - clip.eventTime) / .14)
            if pocketWeight > 0 then pocketTarget = input.catchPoint end
        end
        controller.actionTime = newTime
        if newTime >= clip.duration then
            controller.action, controller.entry = nil, nil
        end
    end
    controller.lastPose = pose

    local left, leftPitch = footTarget(controller, controller.leftFoot, joints.leftHip,
        controller.phase, duty, velocity, stride, gait)
    local right, rightPitch = footTarget(controller, controller.rightFoot, joints.rightHip,
        (controller.phase + .5) % 1, duty, velocity, stride, gait)
    local length = rig.legLengthUpper + rig.legLengthLower
    local function reachableHeight(hip, foot)
        local dx = foot.x - hip.position.x
        return math.sqrt(math.max(.22, length * length - dx * dx - foot.z * foot.z)) + foot.y
    end
    local height = math.min(rig.pelvisHeight, reachableHeight(joints.leftHip, left),
        reachableHeight(joints.rightHip, right))
    rig.pelvis.position = vec3(0, height - .008 - math.abs(swing) * .018 - pose.crouch, 0)
    rig.body.eulerAngles = pose.torso
    joints.head.eulerAngles = vec3(-pose.torso.x * .48, -pose.torso.y * .60, -pose.torso.z * .55)
    placeLeg(rig, joints.leftHip, joints.leftKnee, joints.leftAnkle, left, leftPitch, 6)
    placeLeg(rig, joints.rightHip, joints.rightKnee, joints.rightAnkle, right, rightPitch, -6)
    placeArms(rig, pose, pocketTarget, pocketWeight)
    return event
end

function Animation.reset(controller)
    controller.action, controller.entry = nil, nil
    controller.actionTime, controller.actionSpeed = 0, 1
    controller.time, controller.phase, controller.speed = 0, 0, 0
    controller.turn, controller.carry = 0, 0
    controller.lastPosition = controller.rig.root.worldPosition
    controller.leftFoot, controller.rightFoot = {}, {}
    Animation.update(controller, 0)
end
