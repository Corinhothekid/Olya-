-- PolyLax Build 012 | Main
PolyLax = PolyLax or {}
local P = PolyLax
local state

local function configuredScene()
    local scene = craft.scene()
    scene.ambientColor = color(170, 180, 198)
    scene.sun.rotation = quat.eulerAngles(48, 28, 0)
    return scene
end

local function pedestal(scene, width, height, depth, y, tint)
    local entity = scene:entity()
    entity.position = vec3(0, y, 0)
    entity.model = craft.model.cube()
    entity.scale = vec3(width, height, depth)
    local standard = asset and asset.builtin and asset.builtin.Materials
    entity.material = craft.material(standard and standard.Standard or "Materials:Standard")
    entity.material.diffuse = tint
end

local function category()
    return P.Profile.categories[state.categoryIndex]
end

local function applyCreatorProfile()
    local selected = category().key
    local personalColors = selected == "HELMET" or selected == "GLOVES" or selected == "SHORTS"
    local uniform = selected == "OPPONENT" and
        P.TeamUniform.opponent(state.uniform, state.profile.OPPONENT) or state.uniform
    P.Character.apply(state.creator.rig, state.profile, selected, uniform, personalColors)
end

local function openCreator()
    if not state.creator then
        local scene = configuredScene()
        local rig = P.Character.new(scene)
        state.creator = {
            scene = scene, rig = rig, camera = P.CameraController.new(scene, 34),
            animation = P.AnimationController.new(rig)
        }
        pedestal(scene, 15, .25, 15, -.225, color(7, 28, 60))
        pedestal(scene, 2.8, .15, 2.8, -.075, color(29, 64, 113))
    end
    state.page = "CREATOR"
    state.drag, state.joystick, state.aim, state.sprint = nil, nil, nil, nil
    state.moveX, state.moveZ = 0, 0
    state.yaw, state.targetYaw = 0, 0
    state.layout = nil
    applyCreatorProfile()
end

local function openPlay(page)
    if page == "PRACTICE" and not state.practice then
        local scene = configuredScene()
        state.practice = {
            scene = scene, camera = P.CameraController.new(scene, 48),
            game = P.Gameplay.new(scene, state.profile, state.uniform, state.profile.OPPONENT)
        }
    elseif page == "MATCH" and not state.match then
        local scene = configuredScene()
        state.match = {
            scene = scene, camera = P.CameraController.new(scene, 48),
            game = P.FullMatch.new(scene, state.profile, state.profile.TEAM, state.profile.OPPONENT)
        }
    end
    state.page = page
    state.drag, state.joystick, state.aim, state.sprint = nil, nil, nil, nil
    state.moveX, state.moveZ = 0, 0
    state.layout = nil
end

local function saveCareerResult(play)
    if play.recorded or play.game.phase ~= "FINAL" then return end
    local saved, reason = P.Career.record(state.career, play.fixture, play.game)
    play.recorded, play.saveAttempted = saved, true
    state.careerMessage = reason or (saved and "Game result saved")
end

local function openCareer()
    state.page = "CAREER"
    state.joystick, state.aim, state.sprint = nil, nil, nil
    state.moveX, state.moveZ = 0, 0
    state.layout = nil
    if state.careerPlay and state.careerPlay.recorded then state.careerPlay = nil end
end

local function openCareerPlay()
    if state.careerPlay and state.careerPlay.game.phase == "FINAL" then
        saveCareerResult(state.careerPlay)
        if state.careerPlay.recorded then state.careerPlay = nil end
        return
    end
    if not state.careerPlay then
        local fixture = P.Career.fixture(state.career)
        if not fixture then return end
        local scene = configuredScene()
        local camera = P.CameraController.new(scene, 48)
        P.CameraController.cycle(camera)
        P.CameraController.cycle(camera)
        local options = P.Career.matchOptions(state.career, fixture)
        local game = P.FullMatch.new(scene, state.profile, state.career.team, fixture.opponent, options)
        state.careerPlay = {scene=scene, camera=camera, game=game, fixture=fixture}
    end
    state.page = "CAREER_GAME"
    state.layout = nil
end

local function finishName()
    if not state.careerName then return end
    P.Career.rename(state.career, state.careerName)
    state.careerName = nil
    if hideKeyboard then hideKeyboard() end
end

function keyboard(key)
    if not state or not state.careerName then return end
    if key == RETURN or key == "\n" then
        finishName()
    elseif key == BACKSPACE or key == "\b" then
        local last = utf8 and utf8.offset(state.careerName, -1) or #state.careerName
        state.careerName = state.careerName:sub(1, math.max(0, (last or 1)-1))
    elseif type(key) == "string" and not key:match("[%c]") and #state.careerName+#key <= 24 then
        state.careerName = state.careerName..key
    end
end

local function careerTouch(touch)
    if touch.state ~= BEGAN then return end
    local hud = P.CareerUI.layout(state.career)
    local function hit(item) return P.UI.hit(item, touch.x, touch.y) end
    if hit(hud.back) then
        finishName()
        openCreator()
    elseif hit(hud.name) and showKeyboard then
        state.careerName = state.career.name
        showKeyboard()
    elseif hit(hud.position) and not state.careerPlay then
        P.Career.setPosition(state.career, state.career.position % #P.Career.positions+1)
    elseif hit(hud.play) then
        finishName()
        openCareerPlay()
    end
end

local function activePlay()
    if state.page == "MATCH" then return state.match, P.FullMatch end
    if state.page == "CAREER_GAME" then return state.careerPlay, P.FullMatch end
    return state.practice, P.Gameplay
end

local function worldMoveX(play)
    return state.moveX * (play.horizontal or -1)
end

local function updateSprint(game, dt)
    local moving = state.moveX^2 + state.moveZ^2 > .06
    local live = game.phase == nil or game.phase == "LIVE"
    local holder = game.carrier and game.squad[game.carrier]
    local offense = game.homeScore == nil or holder and holder.team == 1
    local controlled = game.squad[game.controlled]
    local energy = controlled.stamina or 1
    game.sprinting = live and offense and state.sprint ~= nil and moving
        and energy > (game.sprinting and .01 or .08)
    for _, player in ipairs(game.squad) do
        local effort = game.sprinting and player == controlled
        player.stamina = math.max(0, math.min(1, (player.stamina or 1)
            + dt * (effort and -.30 or live and .17 or .32)))
    end
end

local function aimGuide(play, controller, dt)
    local aim = state.aim
    if not aim then return end
    if not controller.canAim(play.game) then
        state.aim = nil
        return
    end
    local launch = controller.aimContext(play.game)
    if not launch then return end
    local blend = 1 - math.exp(-20 * dt)
    aim.shown = aim.shown + (aim.target - aim.shown) * blend
    local a = P.CameraController.project(play.camera, launch)
    local b = P.CameraController.project(play.camera, aim.shown)
    if a and b then return {from=a, target=b} end
end

local function currentHUDLayout()
    if not state.layout or state.width ~= WIDTH or state.height ~= HEIGHT then
        state.width, state.height = WIDTH, HEIGHT
        state.layout = state.page == "CREATOR" and
            P.UI.creatorLayout(P.Profile.categories) or P.UI.practiceLayout()
    end
    return state.layout
end

function setup()
    if supportedOrientations and PORTRAIT then supportedOrientations(PORTRAIT) end
    if viewer then
        viewer.mode = FULLSCREEN
    else
        displayMode(FULLSCREEN)
    end
    local profile = P.Profile.load()
    state = {profile=profile, uniform=P.TeamUniform.fromProfile(profile),
        categoryIndex=4, career=P.Career.load()}
    openCreator()
end

function draw()
    local dt = math.max(0, math.min(DeltaTime or 1/60, .05))
    if state.page == "CAREER" then
        P.CareerUI.draw(state.career, P.CareerUI.layout(state.career), state.careerPlay,
            state.careerName ~= nil, state.careerName, state.careerMessage)
        return
    end
    local hud = currentHUDLayout()
    if state.page == "CREATOR" then
        local selection = category()
        local creator = state.creator
        P.AnimationController.update(creator.animation, dt, {speed=0, possessed=false})
        state.yaw = state.yaw + (state.targetYaw - state.yaw) * (1 - math.exp(-14 * dt))
        creator.rig.root.eulerAngles = vec3(0, state.yaw, 0)
        P.CameraController.preview(creator.camera, creator.rig, selection.key, hud.frame, dt)
        creator.scene:update(dt)
        creator.scene:draw()
        local selected = state.profile[selection.key]
        P.UI.creator(hud, selection, state.categoryIndex, selected,
            P.UI.firstOption(selection, selected), true)
    else
        local play, controller = activePlay()
        P.UI.step(hud, dt)
        updateSprint(play.game, dt)
        controller.update(play.game, dt, worldMoveX(play), state.moveZ)
        if state.page == "CAREER_GAME" and not play.saveAttempted then
            saveCareerResult(play)
        end
        if state.page ~= "PRACTICE" then
            P.CameraController.match(play.camera, play.game, dt, state.aim and state.aim.shown, hud.frame)
        else
            P.CameraController.practice(play.camera, play.game, dt, state.aim and state.aim.shown, hud.frame)
        end
        play.scene:update(dt)
        play.scene:draw()
        local position = play.game.squad[play.game.controlled].rig.root.position
        local a = P.CameraController.project(play.camera, position)
        local b = P.CameraController.project(play.camera, position + vec3(.35, 0, 0))
        if a and b and a.x ~= b.x then play.horizontal = b.x < a.x and -1 or 1 end
        P.UI.practice(hud, play.game, state.moveX, state.moveZ,
            aimGuide(play, controller, dt), P.CameraController.mode(play.camera))
    end
end

local function updateChoice(index)
    local selection = category()
    P.Profile.select(state.profile, selection, index)
    if selection.key == "TEAM" then
        state.uniform = P.TeamUniform.fromProfile(state.profile)
    end
    applyCreatorProfile()
    if state.practice then
        P.Gameplay.applyProfile(state.practice.game, state.profile, state.uniform, state.profile.OPPONENT)
    end
    if state.match then
        P.FullMatch.applyProfile(state.match.game, state.profile, state.profile.TEAM, state.profile.OPPONENT)
    end
    if state.careerPlay then
        P.FullMatch.applyProfile(state.careerPlay.game, state.profile)
    end
end

local function creatorTouch(touch, hud)
    if touch.state == BEGAN then
        if P.UI.hit(hud.career, touch.x, touch.y) then
            openCareer()
            return
        end
        if P.UI.hit(hud.done, touch.x, touch.y) then
            openPlay("PRACTICE")
            return
        end
        if P.UI.hit(hud.fullGame, touch.x, touch.y) then
            openPlay("MATCH")
            return
        end
        if P.UI.hit(hud.reset, touch.x, touch.y) then
            state.categoryIndex = 4
            state.targetYaw = 0
            state.yaw = (state.yaw + 180) % 360 - 180
            state.drag = nil
            applyCreatorProfile()
            return
        end
        for _, item in ipairs(hud.categories) do
            if P.UI.hit(item, touch.x, touch.y) then
                state.categoryIndex = item.id
                applyCreatorProfile()
                return
            end
        end
        local selection = category()
        local selected = state.profile[selection.key]
        if P.UI.hit(hud.left, touch.x, touch.y) then
            updateChoice((selected - 2) % #selection.choices + 1)
            return
        end
        if P.UI.hit(hud.right, touch.x, touch.y) then
            updateChoice(selected % #selection.choices + 1)
            return
        end
        local first = P.UI.firstOption(selection, selected)
        for index = 1, math.min(#selection.choices, #hud.options) do
            if P.UI.hit(hud.options[index], touch.x, touch.y) then
                updateChoice(first + index - 1)
                return
            end
        end
        if not state.drag and touch.y > hud.panelHeight and touch.y < HEIGHT-hud.topBar then
            state.drag = {id=touch.id, x=touch.x}
        end
    elseif state.drag and touch.id == state.drag.id then
        if touch.state == MOVING then
            state.targetYaw = state.targetYaw + (touch.x - state.drag.x) * .55
            state.drag.x = touch.x
        elseif touch.state == ENDED or touch.state == CANCELLED then
            state.drag = nil
        end
    end
end

local function beginAim(touch, play, controller)
    local game = play.game
    if not controller.canAim(game) then return false end
    local _, goal = controller.aimContext(game)
    if not goal then return false end
    local center = vec3(goal.x or 0, goal.top * .56, goal.z)
    local a = P.CameraController.project(play.camera, center)
    local b = P.CameraController.project(play.camera, center + vec3(.35, 0, 0))
    local horizontal = a and b and a.x ~= b.x and (b.x < a.x and -1 or 1) or play.horizontal or -1
    state.aim = {
        id=touch.id, x=touch.x, y=touch.y, goal=goal,
        target=center, shown=center, horizontal=horizontal
    }
    return true
end

local function playTouch(touch, hud)
    local play, controller = activePlay()
    local game = play.game
    local finished = touch.state == ENDED or touch.state == CANCELLED
    if finished then
        P.UI.release(hud, touch.id)
        if state.sprint == touch.id then state.sprint = nil end
    end
    local aim = state.aim
    if aim and touch.id == aim.id then
        if touch.state == MOVING then
            local goal = aim.goal
            local halfWidth = goal.halfWidth
            local x = aim.target.x + (touch.x - aim.x) * aim.horizontal * halfWidth / 48
            local y = aim.target.y + (touch.y - aim.y) * goal.top / 95
            aim.target = vec3(
                math.max((goal.x or 0) - 1.65 * halfWidth, math.min((goal.x or 0) + 1.65 * halfWidth, x)),
                math.max(.04, math.min(goal.top * 1.45, y)), goal.z
            )
            aim.x, aim.y = touch.x, touch.y
        elseif touch.state == ENDED or touch.state == CANCELLED then
            state.aim = nil
            if touch.state == ENDED and controller.canAim(game) then
                controller.command(game, "shoot", worldMoveX(play), state.moveZ, aim.target)
            end
        end
        return
    end

    if touch.state == BEGAN then
        if P.UI.hit(hud.edit, touch.x, touch.y) then
            if state.page == "CAREER_GAME" then openCareer() else openCreator() end
            return
        end
        if P.UI.hit(hud.reset, touch.x, touch.y) then
            if state.page == "CAREER_GAME" and play.recorded then return end
            P.UI.press(hud, hud.reset, touch.id)
            state.aim, state.sprint = nil, nil
            controller.command(game, "reset")
            return
        end
        if P.UI.hit(hud.camera, touch.x, touch.y) then
            P.UI.press(hud, hud.camera, touch.id)
            P.CameraController.cycle(play.camera)
            return
        end
        for _, item in ipairs({hud.zoomOut, hud.zoomIn}) do
            if P.UI.hit(item, touch.x, touch.y) then
                P.UI.press(hud, item, touch.id)
                P.CameraController.zoom(play.camera, item == hud.zoomIn and 1 or -1)
                return
            end
        end
        if not state.sprint and P.UI.hit(hud.sprint, touch.x, touch.y)
            and P.UI.action(game, hud.sprint) == "sprint" then
            state.sprint = touch.id
            P.UI.press(hud, hud.sprint, touch.id)
            return
        end
        for _, item in ipairs(hud.commands) do
            local action = P.UI.action(game, item)
            if action and P.UI.hit(item, touch.x, touch.y) then
                P.UI.press(hud, item, touch.id)
                if action == "shoot" then
                    if not state.aim then beginAim(touch, play, controller) end
                else
                    controller.command(game, action, worldMoveX(play), state.moveZ)
                end
                return
            end
        end
        if not state.joystick and touch.x < hud.joyMaxX
            and touch.y < hud.panelHeight then
            state.joystick = {id=touch.id, x=touch.x, y=touch.y, radius=hud.joyRadius}
        end
    elseif state.joystick and touch.id == state.joystick.id then
        if touch.state == MOVING then
            local dx = touch.x - state.joystick.x
            local dy = touch.y - state.joystick.y
            local length = math.max(state.joystick.radius, math.sqrt(dx*dx + dy*dy))
            state.moveX, state.moveZ = dx / length, dy / length
        elseif touch.state == ENDED or touch.state == CANCELLED then
            state.joystick = nil
            state.moveX, state.moveZ = 0, 0
        end
    end
end

function touched(touch)
    if not state then return end
    if state.page == "CREATOR" then
        creatorTouch(touch, currentHUDLayout())
    elseif state.page == "CAREER" then
        careerTouch(touch)
    else
        playTouch(touch, currentHUDLayout())
    end
end

-- Keep the startup and rendering diagnostics at the end of Main.
local runSetup, runFrame, runTouch = setup, draw, touched
local startupError

local function runChecked(stage, callback, ...)
    local ok, message = pcall(callback, ...)
    if not ok then
        startupError = stage .. "\n" .. tostring(message)
        print(startupError)
    end
end

function setup()
    startupError = nil
    runChecked("PolyLax could not start", function()
        assert(type(runSetup) == "function" and type(runFrame) == "function",
            "Install the complete Build 012 Main tab.")
        local modules = PolyLax or {}
        local missing = {}
        for _, name in ipairs({
            "Profile", "TeamUniform", "Character", "AnimationController",
            "CameraController", "GoalPhysics", "Gameplay", "Field", "MatchAI", "FullMatch",
            "Defense", "Faceoff", "UI", "Career", "CareerUI"
        }) do
            if type(modules[name]) ~= "table" then
                missing[#missing + 1] = name
            end
        end
        assert(#missing == 0, "Missing Codea tabs: " .. table.concat(missing, ", "))
        assert(craft and craft.scene, "Open PolyLax in Codea's Legacy Craft runtime.")
        runSetup()
    end)
end

function draw()
    if not startupError then
        runChecked("PolyLax could not draw a frame", runFrame)
    end
    if startupError then
        background(7, 28, 60)
        resetMatrix()
        ortho()
        viewMatrix(matrix())
        fill(255)
        fontSize(16)
        textMode(CENTER)
        textAlign(CENTER)
        textWrapWidth(WIDTH - 32)
        text(startupError, WIDTH * .5, HEIGHT * .5)
    end
end

function touched(touch)
    if not startupError then
        runChecked("PolyLax could not handle a touch", runTouch, touch)
    end
end
