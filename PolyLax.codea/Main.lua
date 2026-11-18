-- PolyLax 2.0 | Main
PolyLax = PolyLax or {}
local P = PolyLax
local state

local function navigate(page)
    state.page, state.pageAge, state.layout = page, 0, nil
end

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

local function creatorCategories()
    if state.careerCreator then
        return P.Athlete.categories(state.career,state.careerPlay~=nil)
    end
    return P.Profile.categories
end

local function category()
    return creatorCategories()[state.categoryIndex]
end

local function creatorProfile()
    if state.careerCreator then return P.Athlete.profile(state.career,state.profile) end
    return state.profile
end

local function creatorSelection()
    local selected, profile=category(),creatorProfile()
    if state.careerCreator then return P.Athlete.choice(state.career,profile,selected) end
    return profile[selected.key]
end

local function applyCreatorProfile()
    local selected=category().key
    local personalColors=selected=="HELMET" or selected=="GLOVES" or selected=="SHORTS"
    local uniform=selected=="OPPONENT" and P.TeamUniform.opponent(state.uniform,state.profile.OPPONENT)
        or state.uniform
    if state.careerCreator then
        uniform=P.Athlete.uniform(state.career,state.careerKit=="away")
        personalColors=false
    end
    P.Character.apply(state.creator.rig,creatorProfile(),selected,uniform,personalColors)
end

local function clearPlayInput()
    state.joystick, state.aim, state.passAim, state.sprint, state.pick = nil, nil, nil, nil, nil
    state.moveX, state.moveZ, state.nubX, state.nubZ = 0, 0, 0, 0
end

local function openMenu(page)
    clearPlayInput()
    navigate(page)
end

local function openCreator(athlete, section)
    if state.careerCreator~=athlete then state.categoryIndex=4 end
    state.careerCreator=athlete
    state.careerKit="home"
    if section then state.categoryIndex=section end
    if athlete then P.Athlete.ensure(state.career,state.profile) end
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
    navigate("CREATOR")
    state.drag = nil
    clearPlayInput()
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
    navigate(page)
    state.drag = nil
    clearPlayInput()
    state.layout = nil
end

local function openStats(game, backPage)
    local view=P.StatsUI.open(game)
    if not view then return end
    state.statView,state.statReturn=view,backPage
    clearPlayInput()
    navigate("STATS")
end

local function statTouch(touch)
    local view=state.statView
    if P.StatsUI.touch(view,P.StatsUI.layout(view),touch)=="close" then
        navigate(state.statReturn)
        state.statView,state.statReturn=nil,nil
    end
end

local function saveCareerResult(play)
    if play.recorded or play.game.phase ~= "FINAL" then return end
    local saved, reason = P.Career.record(state.career, play.fixture, play.game)
    play.recorded, play.saveAttempted = saved, true
    state.careerMessage = reason or (saved and "Game result saved")
end

local function openCareer()
    P.Athlete.ensure(state.career,state.profile)
    navigate("CAREER")
    state.careerView, state.careerPage = "profile", 1
    clearPlayInput()
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
        options.statistics={fixture=fixture,profileId="career-player",stage=state.career.stage,
            season=state.career.season,postseason=fixture.postseason}
        options.playerName=P.Athlete.name(state.career)
        local appearance=P.Athlete.profile(state.career,state.profile)
        local game = P.FullMatch.new(scene,appearance,state.career.team,fixture.opponent,options)
        state.careerPlay = {scene=scene, camera=camera, game=game, fixture=fixture}
    end
    navigate("CAREER_GAME")
    state.layout = nil
end

local function finishName()
    if not state.careerName then return end
    if state.careerNamePart then
        P.Athlete.rename(state.career,state.profile,state.careerNamePart,state.careerName)
        local play=state.careerPlay
        if play then
            local player=play.game.squad[play.game.careerPlayer]
            player.name=P.Athlete.name(state.career)
        end
    else
        P.Career.rename(state.career,state.careerName)
    end
    state.careerName,state.careerNamePart = nil,nil
    if hideKeyboard then hideKeyboard() end
end

function keyboard(key)
    if not state or not state.careerName then return end
    if key == RETURN or key == "\n" then
        finishName()
    elseif key == BACKSPACE or key == "\b" then
        local last = utf8 and utf8.offset(state.careerName, -1) or #state.careerName
        state.careerName = state.careerName:sub(1, math.max(0, (last or 1)-1))
    elseif type(key) == "string" and not key:match("[%c]") and #state.careerName+#key <= P.Athlete.nameLimit then
        state.careerName = state.careerName..key
    end
end

local function careerLayout()
    return P.CareerUI.layout(state.career, state.careerView, state.careerPlay,
        state.careerSkill, state.careerPage,state.careerStatMode)
end

local function openDevelopment()
    clearPlayInput()
    navigate("DEVELOPMENT")
    state.developmentPage=state.developmentPage or 1
end

local function trainingKey(mode)
    local fixture=P.Career.fixture(state.career)
    return mode..":"..(fixture and fixture.id or (state.career.stage..":"..state.career.season))
end

local function openTraining()
    local key=trainingKey("drill")
    if P.Development.claimed(state.career,key) then
        state.developmentMessage="Drill objective logged this week"
        return
    end
    if not state.training or state.training.rewardKey~=key then
        local scene=configuredScene()
        local profile=P.Athlete.profile(state.career,state.profile)
        local kit=P.Athlete.uniform(state.career,false)
        local game=P.Gameplay.new(scene,profile,kit,state.profile.OPPONENT)
        game.clock=60
        game.squad[1].attributes=P.Attributes.restore(state.career.attributes,state.career.position)
        game.announcement,game.announcementTime="TRAINING · 1 GOAL + 2 PASSES",3
        state.training={scene=scene,game=game,camera=P.CameraController.new(scene,48),rewardKey=key}
    end
    clearPlayInput()
    navigate("TRAINING")
end

local function resetPlaySession(play,controller,page)
    controller.command(play.game,"reset")
    if page=="TRAINING" then play.game.clock=60 end
    play.rewardAttempted=nil
end

local function updateTrainingReward(play,page)
    if play.rewardAttempted or play.game.clock>0 then return end
    play.rewardAttempted=true
    local game=play.game
    if game.goals<1 or game.passes<2 then
        if page=="TRAINING" then state.developmentMessage="Drill goal was 1 goal and 2 passes" end
        return
    end
    local drill=page=="TRAINING"
    local key=drill and play.rewardKey or trainingKey("practice")
    local saved,message=P.Development.reward(state.career,key,drill and 32 or 18,drill and 8 or 3)
    state.developmentMessage=message
    if saved then
        game.announcement,game.announcementTime="DEVELOPMENT REWARD EARNED",4
    end
end

local function developmentTouch(touch)
    if touch.state~=BEGAN then return end
    local l=P.Development.layout(state.career,state.developmentPage)
    local function hit(item) return item and item.enabled~=false and P.UI.hit(item,touch.x,touch.y) end
    if hit(l.back) then openCareer()
    elseif hit(l.previous) then state.developmentPage=l.page-1
    elseif hit(l.next) then state.developmentPage=l.page+1
    elseif hit(l.drill) then openTraining()
    else
        for _,row in ipairs(l.rows) do
            if hit(row.upgrade) then
                local saved,message=P.Development.upgrade(state.career,row.upgrade.id)
                state.developmentMessage=message
                if saved then
                    for _,play in ipairs({state.careerPlay or false,state.training or false}) do
                        if play then
                            local player=play.game.squad[play.game.careerPlayer or 1]
                            player.attributes=P.Attributes.restore(state.career.attributes,state.career.position)
                        end
                    end
                end
                return
            end
        end
    end
end

local function careerTouch(touch)
    if touch.state ~= BEGAN then return end
    local career, hud = state.career, careerLayout()
    local function hit(item) return item and P.UI.hit(item, touch.x, touch.y) end
    if hit(hud.back) then
        finishName()
        openMenu("FRONT")
        return
    end
    for _, button in ipairs(hud.nav) do
        if hit(button) then
            finishName()
            state.careerView, state.careerPage = button.id, 1
            return
        end
    end
    for _,button in ipairs(hud.statModes or {}) do
        if hit(button) then
            state.careerStatMode,state.careerPage=button.id,1
            return
        end
    end
    if state.careerView=="stats" then
        for _,row in ipairs(hud.rows or {}) do
            if row.value.box and hit(row.item) then
                openStats(row.value.box,"CAREER")
                return
            end
        end
    end
    if not state.careerPlay then
        for _, button in ipairs(hud.offerButtons or {}) do
            if hit(button) and P.CareerSeason.accept(career, button.id) then
                state.careerView, state.careerPage = "profile", 1
                state.careerMessage = "Season started"
                return
            end
        end
    end
    if hit(hud.leftPage) then
        state.careerPage = hud.page - 1
    elseif hit(hud.rightPage) then
        state.careerPage = hud.page + 1
    elseif hit(hud.name) then openCreator(true,1)
    elseif hit(hud.position) then openCreator(true,2)
    elseif hit(hud.team) then openCreator(true,5)
    elseif hit(hud.development) then openDevelopment()
    elseif hit(hud.nextSkill) then
        state.careerSkill = (state.careerSkill or 1) % P.CareerSeason.trainingCount(career) + 1
    elseif hit(hud.train) and hud.train.enabled and not state.careerPlay then
        if P.CareerSeason.train(career, hud.train.id) then state.careerMessage = "Attribute improved" end
    elseif hit(hud.advance) and not state.careerPlay then
        if P.CareerSeason.advance(career) then
            state.careerView, state.careerPage = "profile", 1
            state.careerMessage = "Season started"
        end
    elseif hit(hud.play) then
        finishName()
        openCareerPlay()
    end
end

local function activePlay(page)
    page = page or state.page
    if page == "TRAINING" then return state.training,P.Gameplay end
    if page == "MATCH" then return state.match, P.FullMatch end
    if page == "CAREER_GAME" then return state.careerPlay, P.FullMatch end
    return state.practice, P.Gameplay
end

local function isMenu(page)
    return page=="FRONT" or page=="MODES" or page=="PAUSE"
end

local function menuLayout()
    local play = state.resumePage and activePlay(state.resumePage)
    return P.Style.screenLayout(state.page,{resetEnabled=not (play and play.recorded),
        statsEnabled=play and play.game.statistics~=nil})
end

local function menuTouch(touch)
    if touch.state ~= BEGAN then return end
    for _,button in ipairs(menuLayout().buttons) do
        if button.enabled~=false and P.UI.hit(button,touch.x,touch.y) then
            local id = button.id
            if id=="CREATOR" then openCreator(state.page=="PAUSE" and state.resumePage=="CAREER_GAME" or nil)
            elseif id=="CAREER" then openCareer()
            elseif id=="PRACTICE" or id=="MATCH" then openPlay(id)
            elseif id=="MODES" or id=="HOME" then openMenu(id=="HOME" and "FRONT" or id)
            elseif id=="RESUME" and state.resumePage then navigate(state.resumePage)
            elseif id=="STATS" and state.resumePage then
                local play=activePlay(state.resumePage)
                if play then openStats(play.game,"PAUSE") end
            elseif id=="RESET" and state.resumePage then
                local play,controller=activePlay(state.resumePage)
                if play and not play.recorded then resetPlaySession(play,controller,state.resumePage) end
                navigate(state.resumePage)
            end
            return
        end
    end
end

local function updateAnalog(touch, joystick)
    local dx,dy = (touch.x-joystick.x)/joystick.radius,(touch.y-joystick.y)/joystick.radius
    local distance = math.sqrt(dx*dx+dy*dy)
    local deadZone = .14
    if distance <= deadZone then
        state.moveX,state.moveZ=0,0
        return
    end
    local force = math.min(1,(distance-deadZone)/(1-deadZone)) / distance
    state.moveX,state.moveZ=dx*force,dy*force
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
    game.sprinting = live and offense and not game.careerWaiting
        and state.sprint ~= nil and moving and energy > (game.sprinting and .01 or .08)
    for _, player in ipairs(game.squad) do
        local effort = game.sprinting and player == controlled
        local endurance = (player.attributes and player.attributes.stamina or 60)/100
        local rate = effort and (-.36 + endurance*.1) or live and (.11+endurance*.1) or .32
        player.stamina = math.max(0, math.min(1, (player.stamina or 1) + dt * rate))
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

local function passPlan(play, controller)
    local aim = state.passAim
    if aim and aim.owner ~= play.game.carrier then return end
    local x, z = worldMoveX(play), -state.moveZ
    if aim then x, z = aim.dx, aim.dz end
    return controller.passPreview(play.game, x, z)
end

local function passGuide(play, controller, hud)
    if state.aim then return end
    local plan = passPlan(play,controller)
    if not plan then return end
    local mark = P.CameraController.project(play.camera, plan.point)
    if not mark or mark.x < hud.leftX or mark.x > hud.rightX
        or mark.y < hud.frame.bottom or mark.y > hud.frame.top then return end
    local teammate = plan.to and play.game.squad[plan.to]
    return {x=mark.x, y=mark.y, name=teammate and teammate.name or "OPEN SPACE",
        manual=not teammate}
end

local function currentHUDLayout()
    if not state.layout or state.width ~= WIDTH or state.height ~= HEIGHT then
        state.width, state.height = WIDTH, HEIGHT
        state.layout = state.page == "CREATOR" and
            P.UI.creatorLayout(creatorCategories(), {athlete=state.careerCreator,kit=state.careerKit})
            or P.UI.practiceLayout()
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
    openMenu("FRONT")
end

function draw()
    local dt = math.max(0, math.min(DeltaTime or 1/60, .05))
    state.pageAge = state.pageAge + dt
    if isMenu(state.page) then
        P.Style.screen(state.page,menuLayout(),state.pageAge)
        return
    end
    if state.page=="STATS" then
        P.StatsUI.draw(P.StatsUI.layout(state.statView))
        return
    end
    if state.page=="DEVELOPMENT" then
        local l=P.Development.layout(state.career,state.developmentPage)
        P.Development.draw(state.career,l,state.developmentMessage)
        return
    end
    if state.page == "CAREER" then
        P.CareerUI.draw(state.career, careerLayout(), state.careerPlay,
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
        local selected=creatorSelection()
        local options
        if state.careerCreator then
            local first,last=P.Athlete.names(state.career)
            options={athlete=true,kit=state.careerKit,first=first,last=last,
                draft=state.careerName,part=state.careerNamePart,team=P.TeamUniform.get(state.career.team),
                uniform=P.Athlete.uniform(state.career,state.careerKit=="away")}
        end
        P.UI.creator(hud,selection,state.categoryIndex,selected,
            P.UI.firstOption(selection,selected),true,options)
    else
        local play, controller = activePlay()
        P.UI.step(hud, dt)
        updateSprint(play.game, dt)
        controller.update(play.game, dt, worldMoveX(play), state.moveZ)
        if state.page == "CAREER_GAME" and not play.saveAttempted then
            saveCareerResult(play)
        end
        if controller==P.Gameplay then updateTrainingReward(play,state.page) end
        if controller==P.FullMatch then
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
        local mode = P.CameraController.mode(play.camera)
        local ballEdge
        if mode == "PLAYER LOCK" and (play.game.phase == nil or play.game.phase == "LIVE") then
            ballEdge = P.CameraController.ballEdge(play.camera, play.game.ball.position,
                hud.frame, hud.leftX, hud.rightX)
        end
        local nubBlend=1-math.exp(-dt*24)
        state.nubX=state.nubX+(state.moveX-state.nubX)*nubBlend
        state.nubZ=state.nubZ+(state.moveZ-state.nubZ)*nubBlend
        P.UI.practice(hud, play.game, state.nubX, state.nubZ,
            aimGuide(play, controller, dt), mode, ballEdge, passGuide(play,controller,hud))
        P.StatsUI.drawEntry(hud,play.game)
    end
end

local function updateChoice(index)
    local selection = category()
    if state.careerCreator then
        if selection.key=="IDENTITY" then
            if not showKeyboard then return end
            finishName()
            local first,last=P.Athlete.names(state.career)
            state.careerNamePart=index==1 and "first" or "last"
            state.careerName=index==1 and first or last
            showKeyboard()
            return
        end
        P.Athlete.select(state.career,state.profile,selection,index,state.careerPlay~=nil)
        applyCreatorProfile()
        if state.careerPlay then
            P.FullMatch.applyProfile(state.careerPlay.game,P.Athlete.profile(state.career,state.profile))
        end
        return
    end
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
end

local function creatorTouch(touch, hud)
    if touch.state == BEGAN then
        if hud.home and P.UI.hit(hud.home,touch.x,touch.y) then
            finishName()
            if state.careerCreator then openCareer() else openMenu("FRONT") end
            return
        end
        if not state.careerCreator and P.UI.hit(hud.career, touch.x, touch.y) then
            openCareer()
            return
        end
        local homeKit=P.UI.hit(hud.done,touch.x,touch.y)
        local awayKit=P.UI.hit(hud.fullGame,touch.x,touch.y)
        if homeKit or awayKit then
            finishName()
            if state.careerCreator then
                state.careerKit=homeKit and "home" or "away"
                applyCreatorProfile()
            else openPlay(homeKit and "PRACTICE" or "MATCH") end
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
                finishName()
                state.categoryIndex = item.id
                applyCreatorProfile()
                return
            end
        end
        local selection = category()
        local selected=creatorSelection()
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
        if state.pick == touch.id then
            state.pick = nil
            controller.command(game,"releasepick",worldMoveX(play),state.moveZ)
            return
        end
    end
    local passing = state.passAim
    if passing and touch.id == passing.id then
        if touch.state == MOVING or touch.state == ENDED then
            local dx, dy = touch.x-passing.x, touch.y-passing.y
            if dx*dx+dy*dy >= 36 then
                passing.dx, passing.dz = dx*(play.horizontal or -1)/44, -dy/44
            end
        end
        if finished then
            local plan = touch.state == ENDED and passPlan(play,controller)
            state.passAim = nil
            if plan then controller.command(game,"pass",worldMoveX(play),state.moveZ,plan) end
        end
        return
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
        local stats=P.StatsUI.entry(hud,game)
        if stats and P.UI.hit(stats,touch.x,touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            openStats(game,state.page)
            return
        end
        if hud.pause and P.UI.hit(hud.pause,touch.x,touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            state.resumePage = state.page
            openMenu("PAUSE")
            return
        end
        if P.UI.hit(hud.edit, touch.x, touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            if state.page=="TRAINING" then openDevelopment()
            elseif state.page=="CAREER_GAME" then openCareer() else openCreator() end
            return
        end
        if P.UI.hit(hud.reset, touch.x, touch.y) then
            if state.page == "CAREER_GAME" and play.recorded then return end
            P.UI.press(hud, hud.reset, touch.id)
            clearPlayInput()
            resetPlaySession(play,controller,state.page)
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
        if hud.sprint and P.UI.hit(hud.sprint,touch.x,touch.y) then
            if not state.sprint and P.UI.action(game,hud.sprint) == "sprint" then
                state.sprint = touch.id
                P.UI.press(hud,hud.sprint,touch.id)
            end
            return
        end
        for _, item in ipairs(hud.commands) do
            local action = P.UI.action(game, item)
            if action and P.UI.hit(item, touch.x, touch.y) then
                P.UI.press(hud, item, touch.id)
                if action == "shoot" then
                    if not state.aim and not state.passAim then beginAim(touch, play, controller) end
                elseif action == "pass" then
                    if state.passAim or state.aim then return end
                    local dx, dz = worldMoveX(play), -state.moveZ
                    if controller.passPreview(game,dx,dz) then
                        state.passAim = {id=touch.id,x=touch.x,y=touch.y,owner=game.carrier,dx=dx,dz=dz}
                    else
                        controller.command(game,"pass",dx,state.moveZ)
                    end
                elseif action == "setpick" then
                    if not state.pick and controller.command(game,action,worldMoveX(play),state.moveZ) then
                        state.pick = touch.id
                    end
                else
                    controller.command(game, action, worldMoveX(play), state.moveZ)
                end
                return
            end
        end
        if not state.joystick and touch.x >= hud.leftX and touch.x < hud.joyMaxX
            and touch.y >= hud.joyMinY and touch.y < hud.panelHeight then
            local x,z=touch.x-hud.joyX,touch.y-hud.joyY
            if x*x+z*z <= (hud.joyRadius*1.28)^2 then
                state.joystick = {id=touch.id,x=hud.joyX,y=hud.joyY,radius=hud.joyRadius}
                updateAnalog(touch,state.joystick)
            end
        end
    elseif state.joystick and touch.id == state.joystick.id then
        if touch.state == MOVING then
            updateAnalog(touch,state.joystick)
        elseif touch.state == ENDED or touch.state == CANCELLED then
            state.joystick = nil
            state.moveX, state.moveZ = 0, 0
        end
    end
end

function touched(touch)
    if not state then return end
    if isMenu(state.page) then
        menuTouch(touch)
    elseif state.page == "CREATOR" then
        creatorTouch(touch, currentHUDLayout())
    elseif state.page == "CAREER" then
        careerTouch(touch)
    elseif state.page=="DEVELOPMENT" then
        developmentTouch(touch)
    elseif state.page=="STATS" then
        statTouch(touch)
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
            "Install the complete PolyLax 2.0 Main tab.")
        local modules = PolyLax or {}
        local missing = {}
        for _, name in ipairs({
            "Profile", "TeamUniform", "Character", "AnimationController",
            "CameraController", "GoalPhysics", "Gameplay", "Field", "MatchAI", "FullMatch",
            "Defense", "Faceoff", "UI", "Career", "CareerUI", "SchoolTeams", "CareerSeason",
            "Passing", "Tactics", "Screens", "Style", "Athlete", "Attributes", "Development", "Statistics", "StatsUI"
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
