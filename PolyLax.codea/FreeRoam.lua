-- Local third-person exploration and interaction controller.
PolyLax = PolyLax or {}
local P = PolyLax
local FreeRoam = {}
P.FreeRoam = FreeRoam

local atan2 = math.atan2 or math.atan
local up = vec3(0, 1, 0)
local fadeTime = .22
local walkSpeed, runSpeed = 2.7, 5.7
local defaultFov, fovStep = 49, 4
FreeRoam.minZoom, FreeRoam.maxZoom = -3, 3

local function finite(value, fallback)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
    return fallback
end

local function angleDifference(target, current)
    return (target-current+180)%360-180
end

local function ease(rate, dt)
    return 1-math.exp(-rate*dt)
end

local function clampZoom(steps)
    return math.max(FreeRoam.minZoom,math.min(FreeRoam.maxZoom,math.floor(finite(steps,0))))
end

function FreeRoam.location(roam)
    return {zone=roam.zone,x=roam.x,z=roam.z,yaw=roam.yaw,
        cameraYaw=roam.viewYaw,zoomSteps=roam.zoomSteps}
end

function FreeRoam.checkpoint(roam)
    local location = FreeRoam.location(roam)
    local saved = roam.lastSaved
    if not roam.save or saved and saved.zone == location.zone and saved.x == location.x
        and saved.z == location.z and saved.yaw == location.yaw and saved.cameraYaw == location.cameraYaw
        and saved.zoomSteps == location.zoomSteps then
        return true
    end
    local ok, result, reason = pcall(roam.save, location)
    if not ok or result == false then
        FreeRoam.notice(roam, type(reason) == "string" and reason or "Campus progress could not be saved.")
        return false
    end
    roam.lastSaved, roam.sinceSave = location, 0
    return true
end

function FreeRoam.notice(roam, message, duration)
    roam.noticeText = message
    roam.noticeTime = message and (duration or 3.5) or 0
end

function FreeRoam.release(roam)
    roam.moveTouch, roam.lookTouch, roam.press = nil, nil, nil
    roam.axisX, roam.axisY, roam.vx, roam.vz = 0, 0, 0, 0
    roam.pendingStop = nil
end

local function poseCamera(roam, dt)
    local camera = roam.camera
    local targetFov = defaultFov - fovStep*roam.zoomSteps
    if camera.fieldOfView ~= targetFov then
        local fov = camera.fieldOfView+(targetFov-camera.fieldOfView)*ease(13,dt)
        if math.abs(fov-targetFov)<.02 then fov=targetFov end
        camera.fieldOfView,camera.lens.fieldOfView = fov,fov
        camera.tanHalf = math.tan(math.rad(fov)*.5)
    end
    local turn = angleDifference(roam.viewYaw,roam.cameraYaw)
    roam.cameraYaw = (roam.cameraYaw + turn*ease(10,dt))%360
    local angle = math.rad(roam.cameraYaw)
    local sx, cz = math.sin(angle), math.cos(angle)
    local distance = roam.zone == "campus" and 7.8 or 5.6
    local height = roam.zone == "campus" and 4.6 or 3.45
    local focusX, focusZ = P.FreeRoamWorld.move(roam.world,roam.x,roam.z,-sx*.80,-cz*.80,.16)
    local focus = vec3(focusX,1.59,focusZ)
    local eye = vec3(roam.x+sx*distance, height, roam.z+cz*distance)
    local smooth = camera.target and ease(10,dt) or 1
    camera.target = camera.target and camera.target+(focus-camera.target)*smooth or focus
    eye = camera.entity.position ~= nil and camera.initialized
        and camera.entity.position+(eye-camera.entity.position)*ease(12,dt) or eye
    if P.FreeRoamWorld.camera then
        eye = P.FreeRoamWorld.camera(roam.world,camera.target,eye)
    end
    camera.entity.position = eye
    camera.entity.rotation = quat.lookRotation((camera.target-eye):normalize(),up)
    camera.initialized = true
end

local function place(roam)
    roam.rig.root.position = vec3(roam.x,roam.animation.bob,roam.z)
    roam.rig.root.eulerAngles = vec3(0,roam.yaw,0)
end

local function openZone(roam, location)
    local world = P.FreeRoamWorld
    local zone,x,z = world.sanitize(location.zone,location.x,location.z)
    local scene = craft.scene()
    scene.ambientColor = color(166,176,188)
    scene.sun.rotation = quat.eulerAngles(47,31,0)
    roam.zone, roam.x, roam.z = zone, x, z
    roam.yaw = finite(location.yaw,0)%360
    roam.viewYaw = finite(location.cameraYaw,0)%360
    roam.cameraYaw = roam.viewYaw
    roam.zoomSteps = clampZoom(location.zoomSteps)
    roam.scene = scene
    roam.world = world.new(scene,zone)
    local fov = defaultFov-fovStep*roam.zoomSteps
    roam.camera = P.CameraController.new(scene,fov)
    roam.camera.fieldOfView = fov
    roam.rig = P.RoadEquipment.newCasual(scene,roam.profile,roam.equipment,roam.stickType)
    roam.animation = P.CampusMotion.new(roam.rig,"player",0)
    place(roam)
    poseCamera(roam,0)
    roam.point = world.interaction(roam.world,x,z)
end

function FreeRoam.new(options)
    local roam = {
        profile=options.profile, career=options.career, equipment=options.equipment,
        stickType=options.stickType,
        objective=options.objective, schedule=options.schedule, onInteract=options.interact,
        onAction=options.action, save=options.save, sinceSave=0, noticeTime=0
    }
    FreeRoam.release(roam)
    openZone(roam,options.location or {})
    roam.lastSaved = FreeRoam.location(roam)
    return roam
end

function FreeRoam.appearance(roam, profile, equipment, stickType)
    roam.profile, roam.equipment = profile or roam.profile, equipment or roam.equipment
    roam.stickType = stickType or roam.stickType
    P.RoadEquipment.applyCasual(roam.rig,roam.profile,roam.equipment,roam.stickType)
end

function FreeRoam.speak(roam, dialogue, actorId)
    FreeRoam.release(roam)
    roam.dialogue = dialogue
    roam.dialogueActor = dialogue and (actorId or roam.dialogueActor) or nil
    if dialogue then roam.paused = false end
end

function FreeRoam.interact(roam)
    if roam.dialogue or roam.paused or roam.transition then return false end
    local point = P.FreeRoamWorld.interaction(roam.world,roam.x,roam.z)
    if not point then return false end
    FreeRoam.release(roam)
    if point.zone then
        roam.transition = {
            elapsed=0, moved=false, location={zone=point.zone,x=point.spawnX,z=point.spawnZ,
                yaw=point.spawnYaw or point.yaw,cameraYaw=point.cameraYaw or point.spawnYaw,
                zoomSteps=roam.zoomSteps}
        }
    else
        FreeRoam.checkpoint(roam)
        if roam.onInteract then
            local dialogue = roam.onInteract(point,roam)
            if type(dialogue) == "table" then FreeRoam.speak(roam,dialogue,point.id) end
        end
    end
    return true
end

local function movement(roam, dt)
    local x,y = roam.axisX, roam.axisY
    local intensity = math.sqrt(x*x+y*y)
    local cruise = walkSpeed + (runSpeed-walkSpeed)*math.max(0,(intensity-.53)/.47)
    local angle = math.rad(roam.cameraYaw)
    local s,c = math.sin(angle), math.cos(angle)
    local vx,vz = (c*x-s*y)*cruise,(-s*x-c*y)*cruise
    local blend = ease(intensity>.01 and 9 or 12,dt)
    roam.vx = roam.vx+(vx-roam.vx)*blend
    roam.vz = roam.vz+(vz-roam.vz)*blend
    if intensity==0 and math.abs(roam.vx)+math.abs(roam.vz)<.05 then
        roam.vx,roam.vz = 0,0
    end
    local x0,z0 = roam.x,roam.z
    roam.x,roam.z = P.FreeRoamWorld.move(roam.world,x0,z0,roam.vx*dt,roam.vz*dt,.35)
    local dx,dz = roam.x-x0,roam.z-z0
    local speed = math.sqrt(dx*dx+dz*dz)/math.max(dt,.0001)
    local turn = 0
    if speed > .035 then
        turn = angleDifference(math.deg(atan2(-dx,-dz)),roam.yaw)
        roam.yaw = (roam.yaw+turn*ease(10,dt))%360
    end
    return speed,math.max(-1,math.min(1,turn/95))
end

function FreeRoam.update(roam, dt)
    dt = math.max(0,math.min(.05,finite(dt,0)))
    local speed,turn = 0,0
    local transition = roam.transition
    if transition then
        transition.elapsed = transition.elapsed+dt
        if transition.elapsed>=fadeTime and not transition.moved then
            openZone(roam,transition.location)
            transition.moved = true
            FreeRoam.checkpoint(roam)
        end
        if transition.elapsed>=fadeTime*2 then roam.transition = nil end
    elseif not (roam.dialogue or roam.paused) then
        speed,turn = movement(roam,dt)
        roam.point = P.FreeRoamWorld.interaction(roam.world,roam.x,roam.z)
        roam.sinceSave = roam.sinceSave+dt
        if roam.sinceSave>=3 then
            roam.sinceSave = 0
            FreeRoam.checkpoint(roam)
        end
        if roam.pendingStop and roam.vx==0 and roam.vz==0 then
            roam.pendingStop = nil
            FreeRoam.checkpoint(roam)
        end
    end
    roam.timeOfDay = roam.schedule and roam.schedule()
    if P.FreeRoamWorld.update and not roam.paused then
        P.FreeRoamWorld.update(roam.world,dt,roam.timeOfDay,roam.x,roam.z,roam.dialogueActor)
    end
    local mode=speed>.04 and "walk" or roam.dialogue and "listen" or "idle"
    P.CampusMotion.update(roam.animation,dt,mode,speed,turn)
    place(roam)
    poseCamera(roam,dt)
    roam.noticeTime = math.max(0,roam.noticeTime-dt)
    return dt
end

function FreeRoam.draw(roam, dt)
    dt = FreeRoam.update(roam,dt)
    roam.scene:update(dt)
    roam.scene:draw()
    local transition = roam.transition
    local fade = transition and 1-math.abs(transition.elapsed/fadeTime-1) or 0
    P.FreeRoamUI.draw(roam,fade)
end

local function analog(roam, joystick, touch)
    local x,y = (touch.x-joystick.x)/joystick.radius,(touch.y-joystick.y)/joystick.radius
    local distance = math.sqrt(x*x+y*y)
    local force = distance>.13 and math.min(1,(distance-.13)/.87)/distance or 0
    roam.axisX,roam.axisY = x*force,y*force
end

local function handleAction(roam, item)
    if item.choice then
        local dialogue = roam.dialogue
        local choice = dialogue and dialogue.choices and dialogue.choices[item.choice]
        local nextDialogue = choice and choice.select and choice.select()
        if roam.dialogue==dialogue or nextDialogue then FreeRoam.speak(roam,nextDialogue) end
        return
    end
    local id = item.id
    if id == "interact" then
        FreeRoam.interact(roam)
    elseif id == "orbitLeft" or id == "orbitRight" then
        roam.viewYaw = (roam.viewYaw+(id=="orbitLeft" and -30 or 30))%360
    elseif id == "zoomIn" or id == "zoomOut" then
        roam.zoomSteps = clampZoom(roam.zoomSteps+(id=="zoomIn" and 1 or -1))
        FreeRoam.checkpoint(roam)
    elseif id == "pause" or id == "resume" then
        roam.paused = id=="pause"
        FreeRoam.release(roam)
        FreeRoam.checkpoint(roam)
    elseif roam.onAction then
        roam.paused = false
        FreeRoam.release(roam)
        FreeRoam.checkpoint(roam)
        roam.onAction(id,roam)
    end
end

function FreeRoam.touch(roam, touch)
    if roam.transition then return end
    local hud = P.FreeRoamUI.layout(roam)
    local joint = hud.joystick
    if touch.id == roam.moveTouch then
        if touch.state == MOVING then analog(roam,joint,touch)
        elseif touch.state == ENDED or touch.state == CANCELLED then
            roam.moveTouch,roam.axisX,roam.axisY,roam.pendingStop = nil,0,0,true
        end
        return
    end
    if touch.id == roam.lookTouch then
        if touch.state == MOVING then
            roam.viewYaw = (roam.viewYaw+(touch.x-roam.lookX)*.42)%360
            roam.lookX = touch.x
        elseif touch.state == ENDED or touch.state == CANCELLED then
            roam.lookTouch = nil
            FreeRoam.checkpoint(roam)
        end
        return
    end
    if touch.state == BEGAN then
        if roam.press then return end
        for _, item in ipairs(hud.buttons) do
            if item.enabled~=false and P.UI.hit(item,touch.x,touch.y) then
                roam.press = {id=touch.id,item=item}
                return
            end
        end
        if roam.dialogue or roam.paused then return end
        local x,y = touch.x-joint.x,touch.y-joint.y
        if not roam.moveTouch and x*x+y*y <= (joint.radius+10)^2 then
            roam.moveTouch = touch.id
            analog(roam,joint,touch)
        elseif not roam.lookTouch and touch.x>hud.center and touch.y>hud.lookBottom and touch.y<hud.lookTop then
            roam.lookTouch,roam.lookX = touch.id,touch.x
        end
    elseif roam.press and touch.id == roam.press.id and (touch.state == ENDED or touch.state == CANCELLED) then
        local item = roam.press.item
        roam.press = nil
        if touch.state == ENDED and P.UI.hit(item,touch.x,touch.y) then handleAction(roam,item) end
    end
end
