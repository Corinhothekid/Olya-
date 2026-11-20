-- PolyLax 3.1 | Complete single-tab edition
-- Paste into Main in a Legacy Craft project with a single tab.

-- Main
do
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

local function editingAthlete()
    if state.clubsCreator then return state.clubs.player end
    if state.careerCreator then return state.career end
end

local function saveClubPlayer(candidate)
    return P.Clubs.savePlayer(state.clubs,candidate)
end

local function creatorFallback()
    if state.clubsCreator then return nil end
    return state.profile
end

local function creatorTeam(athlete)
    local club = state.clubsCreator and P.Clubs.activeClub(state.clubs)
    return P.TeamUniform.get(club and club.team or athlete.team)
end

local function clubPositionMutable()
    return not (state.clubsNet and state.clubsNet.session)
end

local function creatorCategories()
    local athlete = editingAthlete()
    if state.clubsCreator then
        return P.Athlete.categories(athlete,true,clubPositionMutable())
    elseif athlete then
        return P.Athlete.categories(athlete,state.careerPlay~=nil)
    end
    return P.Profile.categories
end

local function category()
    return creatorCategories()[state.categoryIndex]
end

local function creatorProfile()
    local athlete = editingAthlete()
    if athlete then return P.Athlete.profile(athlete,creatorFallback()) end
    return state.profile
end

local function creatorSelection()
    local selected, profile=category(),creatorProfile()
    local athlete = editingAthlete()
    if athlete then return P.Athlete.choice(athlete,profile,selected) end
    return profile[selected.key]
end

local function applyCreatorProfile()
    local selected=category().key
    local personalColors=selected=="HELMET" or selected=="GLOVES" or selected=="SHORTS"
    local uniform=selected=="OPPONENT" and P.TeamUniform.opponent(state.uniform,state.profile.OPPONENT)
        or state.uniform
    local athlete = editingAthlete()
    if athlete then
        local team = creatorTeam(athlete)
        uniform=state.careerKit=="away" and team.away or team.home
        personalColors=false
    end
    local careerPosition = athlete and P.Career.positions[athlete.position]
    local long = careerPosition and (careerPosition.slot == 7 or careerPosition.role == "LSM")
    P.Character.setStickType(state.creator.rig,long and "long" or "short")
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

local function openClubs(view)
    state.clubs = state.clubs or P.Clubs.load()
    state.clubView, state.clubPage = view or "CLUBS", 1
    state.clubEdit, state.clubMessage = nil, nil
    openMenu("CLUBS")
end

local function openCreator(athlete, section)
    if state.creatorMode~=athlete then state.categoryIndex=4 end
    state.creatorMode = athlete
    state.careerCreator, state.clubsCreator = athlete == true, athlete == "clubs"
    state.careerKit="home"
    if section then state.categoryIndex=section end
    local profile = editingAthlete()
    if profile then
        P.Athlete.ensure(profile,creatorFallback(),state.clubsCreator and saveClubPlayer or nil)
    end
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

local function beginPresentation(play,kind,options)
    options=options or {}
    options.frame=P.UI.practiceLayout(play.game.positioning ~= nil).frame
    return P.Presentation.start(play,kind,options)
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
        beginPresentation(state.match,"pregame")
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
        local competition=P.CareerSeason.competition(state.career)
        options.statistics={fixture=fixture,profileId="career-player",stage=state.career.stage,
            season=state.career.season,postseason=fixture.postseason,competition=competition.id,
            venueId=fixture.venueId,venueHomeId=fixture.homeId}
        options.playerName=P.Athlete.name(state.career)
        local appearance=P.Athlete.profile(state.career,state.profile)
        local game = P.FullMatch.new(scene,appearance,state.career.team,fixture.opponent,options)
        state.careerPlay = {scene=scene,camera=camera,game=game,fixture=fixture}
        beginPresentation(state.careerPlay,"pregame")
    end
    navigate("CAREER_GAME")
    state.layout = nil
end

local function finishName()
    if not state.careerName then return end
    if state.careerNamePart then
        P.Athlete.rename(editingAthlete(),creatorFallback(),state.careerNamePart,state.careerName,
            state.clubsCreator and saveClubPlayer or nil)
        local play=state.careerCreator and state.careerPlay
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

local function finishClubEdit()
    local field, value = state.clubEdit, state.clubDraft
    if not field then return end
    state.clubEdit, state.clubDraft = nil, nil
    if field == "EDIT_NAME" then state.clubName = value
    elseif field == "EDIT_CODE" then state.clubCode = value:upper():gsub("%s+", "")
    elseif field == "EDIT_RELAY" then
        local ok, message = P.Clubs.setRelay(state.clubs,value)
        if ok then state.clubsNet = nil end
        state.clubMessage = message or (ok and "Relay address saved")
    end
    if hideKeyboard then hideKeyboard() end
end

function keyboard(key)
    if not state then return end
    if state.clubEdit then
        if key == RETURN or key == "\n" then
            finishClubEdit()
        elseif key == BACKSPACE or key == "\b" then
            local value = state.clubDraft
            local last = utf8 and utf8.offset(value,-1) or #value
            state.clubDraft = value:sub(1,math.max(0,(last or 1)-1))
        elseif type(key) == "string" and not key:match("[%c]") then
            local limit = state.clubEdit == "EDIT_RELAY" and 160 or state.clubEdit == "EDIT_CODE" and 12 or 40
            if #state.clubDraft+#key <= limit then state.clubDraft = state.clubDraft..key end
        end
        return
    end
    if not state.careerName then return end
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
        state.careerSkill,state.careerPage,state.careerStatMode,state.awardState)
end

local function openDevelopment(clubs)
    clearPlayInput()
    if clubs then
        navigate("CLUB_DEVELOPMENT")
        state.clubDevelopmentPage=state.clubDevelopmentPage or 1
    else
        navigate("DEVELOPMENT")
        state.developmentPage=state.developmentPage or 1
    end
end

local function developmentLayout()
    if state.page == "CLUB_DEVELOPMENT" then
        local profile = state.clubs.player
        local layout = P.Development.layout(profile,state.clubDevelopmentPage)
        layout.drill = nil
        return layout, profile, state.clubDevelopmentMessage
    end
    return P.Development.layout(state.career,state.developmentPage), state.career, state.developmentMessage
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
    if play.presentation then P.Presentation.skip(play) end
    controller.command(play.game,"reset")
    play.presentedGoal,play.presentedFinal=nil,nil
    if controller==P.FullMatch then beginPresentation(play,"pregame") end
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
    local l, player=developmentLayout()
    local clubs = state.page=="CLUB_DEVELOPMENT"
    local pageKey = clubs and "clubDevelopmentPage" or "developmentPage"
    local function hit(item) return item and item.enabled~=false and P.UI.hit(item,touch.x,touch.y) end
    if hit(l.back) then
        if clubs then openClubs() else openCareer() end
    elseif hit(l.previous) then state[pageKey]=l.page-1
    elseif hit(l.next) then state[pageKey]=l.page+1
    elseif hit(l.drill) then openTraining()
    else
        for _,row in ipairs(l.rows) do
            if hit(row.upgrade) then
                local saved,message=P.Development.upgrade(player,row.upgrade.id,clubs and saveClubPlayer or nil)
                if clubs then
                    state.clubDevelopmentMessage = message
                    return
                end
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
    if hud.awards and P.AwardUI.touch(hud.awards,state.awardState,touch) then return end
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
    if page == "CLUB_MATCH" then return state.clubPlay, state.clubPlay.controller end
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

local clubStages = {"highSchool", "college", "professional"}

local function clubConnection()
    local connection = state.clubsNet
    local url = state.clubs.settings.relayURL
    if not connection and url then
        connection = P.ClubsNet.new(url)
        state.clubsNet = connection
    end
    return connection
end

local function clubMember(lobby, id)
    for _, member in ipairs(lobby.players) do
        if member.id == id then return member end
    end
end

local function clubOnlineRoster(connection, lobby, includeAI)
    local rows = {}
    local localId = connection.session.playerId
    if includeAI then
        local team = P.TeamUniform.get(lobby.team)
        for slot, player in ipairs(P.League.roster(team.id)) do
            rows[slot] = {name=player.name, number=player.number, role=player.role, kind="ai"}
        end
    end
    for _, member in ipairs(lobby.players) do
        local p = member.profile
        rows[includeAI and member.slot or #rows+1] = {name=p.name,number=p.number,position=p.position,
            connected=member.connected,ready=member.ready,host=member.id==lobby.hostId,online=true,
            kind=member.id==localId and "local" or "remote"}
    end
    return rows
end

local function clubLayout()
    local stage = clubStages[state.clubStage or 1]
    local teams = P.Clubs.teamChoices(stage)
    local team = teams[state.clubTeam or 1]
    local net = clubConnection()
    local lobby = net and net.session and net.lobby
    local canRequest = net and net.url and not net.command
        and (not net.inFlight or net.inFlight.operation=="sync")
    local member = lobby and clubMember(lobby,net.session.playerId)
    local waiting = lobby and lobby.phase == "lobby"
    local canStart = canRequest and waiting and P.ClubsNet.isHost(net) and #lobby.players==2
    if canStart then
        for _, p in ipairs(lobby.players) do canStart = canStart and p.ready and p.connected end
    end
    local message = state.clubMessage or net and net.error
    if not message and net and net.busy and not lobby then message = "Contacting the relay" end
    local roster = lobby and clubOnlineRoster(net,lobby,state.clubView=="ROSTER")
    local schedule
    if state.clubView=="SCHEDULE" then
        schedule = P.Clubs.results(state.clubs)
        for _, fixture in ipairs(P.Clubs.schedule(state.clubs)) do schedule[#schedule+1] = fixture end
    end
    return P.ClubsUI.layout(state.clubView,state.clubs,{
        editing=state.clubEdit,draft=state.clubDraft,name=state.clubName,code=state.clubCode,
        relay=state.clubs.settings.relayURL,stageName=P.Career.stages[stage],teamName=team and team.name,
        page=state.clubPage,message=message,lobby=lobby,roster=roster,schedule=schedule,
        canCreate=not lobby,hostEnabled=canRequest and not lobby and state.clubs.club~=nil,
        canConnect=canRequest and not lobby and #(state.clubCode or "")==8,
        canReady=canRequest and waiting and member~=nil,ready=member and member.ready,canStart=canStart,
        canResume=lobby and lobby.phase=="match" and state.clubPlay~=nil
    })
end

local function clubOnlineAction(id)
    local net = clubConnection()
    if not net then return end
    local result, message
    if id == "HOST_ONLINE" or id == "CONNECT" then
        local player = state.clubs.player
        local appearance = P.Athlete.profile(player)
        local profile = {id=player.id,name=P.Athlete.name(player),position=player.position,
            appearance=appearance,attributes=player.attributes,number=appearance.NUMBER-1}
        if id == "HOST_ONLINE" then result,message = P.ClubsNet.create(net,state.clubs.club,profile)
        else result,message = P.ClubsNet.join(net,state.clubCode,profile) end
    elseif id == "READY" then
        local member = clubMember(net.lobby,net.session.playerId)
        result,message = P.ClubsNet.ready(net,not member.ready)
    elseif id == "START" then result,message = P.ClubsNet.start(net)
    elseif id == "LEAVE" then result,message = P.ClubsNet.leave(net)
    elseif id == "RESUME_MATCH" then
        clearPlayInput()
        navigate("CLUB_MATCH")
        return
    end
    state.clubMessage = not result and message or nil
end

local function clubsTouch(touch)
    local id = P.ClubsUI.touch(clubLayout(),touch)
    if not id then return end
    local view = state.clubView
    finishClubEdit()
    if id == "BACK" then
        if view == "CLUBS" or view == "SETTINGS" then openMenu("FRONT") else openClubs() end
    elseif id == "CREATE" then
        local saved = state.clubs.club
        state.clubName = saved and saved.name or ""
        state.clubStage, state.clubTeam = 1, 1
        if saved then
            for i, stage in ipairs(clubStages) do
                if stage == saved.stage then state.clubStage = i end
            end
            for i, team in ipairs(P.Clubs.teamChoices(clubStages[state.clubStage])) do
                if team.id == saved.team then state.clubTeam = i end
            end
        end
        openClubs("CREATE")
    elseif id == "JOIN" or id == "ROSTER" or id == "SCHEDULE" or id == "LOBBY" then
        openClubs(id)
    elseif id == "MY_PLAYER" then
        openCreator("clubs",1)
    elseif id == "CREATOR" then
        openCreator()
    elseif id == "DEVELOPMENT" then
        openDevelopment(true)
    elseif id == "EDIT_NAME" or id == "EDIT_CODE" or id == "EDIT_RELAY" then
        if not showKeyboard then return end
        if id=="EDIT_RELAY" and state.clubsNet and state.clubsNet.session then
            state.clubMessage="Leave your room before changing relay servers"
            return
        end
        local value = id=="EDIT_NAME" and state.clubName or id=="EDIT_CODE" and state.clubCode
            or id=="EDIT_RELAY" and state.clubs.settings.relayURL
        state.clubEdit, state.clubDraft = id, value or ""
        showKeyboard()
    elseif id == "NEXT_STAGE" then
        state.clubStage, state.clubTeam = (state.clubStage or 1)%#clubStages+1,1
    elseif id == "NEXT_TEAM" then
        local count = #P.Clubs.teamChoices(clubStages[state.clubStage or 1])
        if count > 0 then state.clubTeam = (state.clubTeam or 1)%count+1 end
    elseif id == "SAVE_CLUB" then
        local stage = clubStages[state.clubStage or 1]
        local team = P.Clubs.teamChoices(stage)[state.clubTeam or 1]
        local saved, message = P.Clubs.create(state.clubs,state.clubName,stage,team and team.id)
        if saved then openClubs("LOBBY") end
        state.clubMessage = message
    elseif id == "PREV_PAGE" then state.clubPage = math.max(1,state.clubPage-1)
    elseif id == "NEXT_PAGE" then state.clubPage = state.clubPage+1
    else clubOnlineAction(id) end
end

local function menuTouch(touch)
    if touch.state ~= BEGAN then return end
    for _,button in ipairs(menuLayout().buttons) do
        if button.enabled~=false and P.UI.hit(button,touch.x,touch.y) then
            local id = button.id
            if id=="CREATOR" then openCreator(state.page=="PAUSE" and state.resumePage=="CAREER_GAME" or nil)
            elseif id=="CAREER" then openCareer()
            elseif id=="CLUBS" then openClubs()
            elseif id=="SETTINGS" then openClubs("SETTINGS")
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

local function updateClubs(dt)
    local net = state.clubsNet
    if not net then return end
    local play, lobby = state.clubPlay, net.lobby
    if not net.session or not lobby then
        if state.clubs.joined then P.Clubs.joinedTeam(state.clubs,nil) end
        state.clubPlay, state.clubResultID = nil,nil
        if state.page=="CLUB_MATCH" then openClubs("LOBBY") end
        P.ClubsNet.tick(net,dt)
        return
    end
    if not state.clubs.joined or state.clubs.joined.code~=lobby.code then
        local joined,message = P.Clubs.joinedTeam(state.clubs,lobby)
        if not joined then
            state.clubMessage=message
            P.ClubsNet.disconnect(net)
            return
        end
        if state.page=="CLUBS" and state.clubView=="JOIN" then openClubs("LOBBY") end
    end

    if lobby.phase=="match" and (not play or play.matchId~=lobby.matchId) then
        play=P.ClubsMatch.new(configuredScene(),lobby,net.session.playerId)
        if not play then
            state.clubMessage="The relay did not assign two playable positions"
            P.ClubsNet.disconnect(net)
            return
        end
        play.camera=P.CameraController.new(play.scene,48)
        P.CameraController.cycle(play.camera)
        P.CameraController.cycle(play.camera)
        state.clubPlay=play
        if state.page=="CLUBS" and state.clubView=="LOBBY" then
            clearPlayInput()
            navigate("CLUB_MATCH")
        end
    end

    local exchange
    if lobby.phase=="match" and play then
        play.game.clubsStatus = net.status=="reconnecting" and "RECONNECTING TO RELAY" or nil
        local visible = state.page=="CLUB_MATCH"
        local control = {x=visible and worldMoveX(play) or 0,z=visible and state.moveZ or 0,
            sprint=visible and state.sprint~=nil}
        if play.isHost then
            if net.status=="connected" then
                P.ClubsMatch.hostStep(play,dt,control,P.ClubsNet.takeInputs(net))
            end
            exchange={snapshot=P.ClubsMatch.snapshot(play)}
            if net.snapshot and net.snapshot.phase=="FINAL" and net.status=="connected"
                and (not play.nextFinish or net.clock>=play.nextFinish) then
                local result=P.ClubsMatch.result(play)
                if result then
                    P.ClubsNet.finish(net,result)
                    play.nextFinish=net.clock+1
                end
            end
        else
            P.ClubsMatch.guestStep(play,dt,net.snapshot)
            if not net.snapshot and not play.game.clubsStatus then play.game.clubsStatus="WAITING FOR HOST" end
            control.actions=P.ClubsMatch.takeActions(play)
            exchange={input=control}
        end
    elseif lobby.phase=="final" and lobby.result then
        if play and not play.isHost then P.ClubsMatch.guestStep(play,dt,net.snapshot) end
        if state.clubResultID~=lobby.matchId and state.clubCheckedResultChange~=net.change then
            state.clubCheckedResultChange=net.change
            local ok,message=P.Clubs.recordOnline(state.clubs,lobby,lobby.result,net.session.playerId)
            if ok then state.clubResultID=lobby.matchId end
            state.clubMessage=message
        end
    end
    P.ClubsNet.tick(net,dt,exchange)
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
        local play = state.page ~= "CREATOR" and activePlay()
        state.layout = state.page == "CREATOR" and
            P.UI.creatorLayout(creatorCategories(), {athlete=editingAthlete()~=nil,kit=state.careerKit})
            or P.UI.practiceLayout(play and play.game.positioning ~= nil)
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
        categoryIndex=4,career=P.Career.load(),awardState={}}
    openMenu("FRONT")
end

local function finishPresentation(play,kind)
    if kind=="postgame" or kind=="championship" then
        openStats(play.game,state.page)
        return true
    end
end

local function drawPresentation(play,dt)
    local cinematic=play.presentation
    if not cinematic then return false end
    if not P.Presentation.update(play,dt) then
        return finishPresentation(play,cinematic.kind)
    end
    play.scene:update(dt)
    play.scene:draw()
    P.Presentation.draw(play)
    return true
end

local function matchPresentation(play)
    local game=play.game
    if game.phase=="GOAL" then
        local total=game.homeScore+game.awayScore
        if total~=play.presentedGoal then
            play.presentedGoal=total
            beginPresentation(play,"goal",{scorer=game.lastGoalScorer,team=game.lastGoalTeam})
        end
    elseif game.phase=="FINAL" and not play.presentedFinal then
        play.presentedFinal=true
        local summary=P.Statistics.matchSummary(game)
        local best=summary and P.Statistics.playerOfGame(summary)
        local won=game.homeScore>game.awayScore
        local title=play.fixture and play.fixture.postseason=="championship" and won
        beginPresentation(play,"postgame",{championship=title,playerOfGame=best and best.name})
    end
end

function draw()
    local dt = math.max(0, math.min(DeltaTime or 1/60, .05))
    state.pageAge = state.pageAge + dt
    updateClubs(dt)
    if isMenu(state.page) then
        P.Style.screen(state.page,menuLayout(),state.pageAge)
        return
    end
    if state.page=="CLUBS" then
        P.ClubsUI.draw(clubLayout())
        P.Style.fade(state.pageAge)
        return
    end
    if state.page=="STATS" then
        P.StatsUI.draw(P.StatsUI.layout(state.statView))
        P.Style.fade(state.pageAge)
        return
    end
    if state.page=="DEVELOPMENT" or state.page=="CLUB_DEVELOPMENT" then
        local l, player, message = developmentLayout()
        P.Development.draw(player,l,message)
        P.Style.fade(state.pageAge)
        return
    end
    if state.page == "CAREER" then
        P.CareerUI.draw(state.career, careerLayout(), state.careerPlay,
            state.careerName ~= nil,state.careerName,state.careerMessage)
        P.Style.fade(state.pageAge)
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
        local athlete = editingAthlete()
        if athlete then
            local first,last=P.Athlete.names(athlete)
            local team=creatorTeam(athlete)
            options={athlete=true,kit=state.careerKit,first=first,last=last,
                draft=state.careerName,part=state.careerNamePart,team=team,
                uniform=state.careerKit=="away" and team.away or team.home}
        end
        P.UI.creator(hud,selection,state.categoryIndex,selected,
            P.UI.firstOption(selection,selected),true,options)
        P.Style.fade(state.pageAge)
    else
        local play,controller=activePlay()
        local online=state.page=="CLUB_MATCH"
        if play.presentation and drawPresentation(play,dt) then return end
        P.UI.step(hud, dt)
        if not online then
            updateSprint(play.game, dt)
            controller.update(play.game, dt, worldMoveX(play), state.moveZ)
        end
        if state.page == "CAREER_GAME" and not play.saveAttempted then
            saveCareerResult(play)
        end
        if controller==P.Gameplay then updateTrainingReward(play,state.page) end
        if controller==P.FullMatch or online then
            if not online then
                matchPresentation(play)
                if play.presentation and drawPresentation(play,0) then return end
            end
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
        if not online then P.StatsUI.drawEntry(hud,play.game) end
    end
end

local function updateChoice(index)
    local selection = category()
    local athlete = editingAthlete()
    if athlete then
        if selection.key=="IDENTITY" then
            if not showKeyboard then return end
            finishName()
            local first,last=P.Athlete.names(athlete)
            state.careerNamePart=index==1 and "first" or "last"
            state.careerName=index==1 and first or last
            showKeyboard()
            return
        end
        if state.clubsCreator then
            P.Athlete.select(athlete,nil,selection,index,true,saveClubPlayer,clubPositionMutable())
        else
            P.Athlete.select(athlete,state.profile,selection,index,state.careerPlay~=nil)
        end
        applyCreatorProfile()
        if state.careerCreator and state.careerPlay then
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
            if state.clubsCreator then openClubs()
            elseif state.careerCreator then openCareer()
            else openMenu("FRONT") end
            return
        end
        if not editingAthlete() and P.UI.hit(hud.career, touch.x, touch.y) then
            openCareer()
            return
        end
        local homeKit=P.UI.hit(hud.done,touch.x,touch.y)
        local awayKit=P.UI.hit(hud.fullGame,touch.x,touch.y)
        if homeKit or awayKit then
            finishName()
            if editingAthlete() then
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
    local play,controller=activePlay()
    local game=play.game
    if play.presentation then
        local kind=play.presentation.kind
        P.Presentation.touch(play,touch)
        if not play.presentation then finishPresentation(play,kind) end
        return
    end
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
        local online=state.page=="CLUB_MATCH"
        local stats=not online and P.StatsUI.entry(hud,game)
        if stats and P.UI.hit(stats,touch.x,touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            openStats(game,state.page)
            return
        end
        if hud.pause and P.UI.hit(hud.pause,touch.x,touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            if online then openClubs("LOBBY") return end
            state.resumePage = state.page
            openMenu("PAUSE")
            return
        end
        if not online and P.UI.hit(hud.edit, touch.x, touch.y) then
            if state.pick then controller.command(game,"releasepick",0,0) end
            if state.page=="TRAINING" then openDevelopment()
            elseif state.page=="CAREER_GAME" then openCareer() else openCreator() end
            return
        end
        if not online and P.UI.hit(hud.reset, touch.x, touch.y) then
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
    elseif state.page == "CLUBS" then
        clubsTouch(touch)
    elseif state.page == "CREATOR" then
        creatorTouch(touch, currentHUDLayout())
    elseif state.page == "CAREER" then
        careerTouch(touch)
    elseif state.page=="DEVELOPMENT" or state.page=="CLUB_DEVELOPMENT" then
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
            "Install the complete PolyLax 3.1 Main tab.")
        local modules = PolyLax or {}
        local missing = {}
        for _, name in ipairs({
            "Profile", "TeamUniform", "Character", "AnimationController",
            "CameraController", "GoalPhysics", "Gameplay", "Field", "Midfield", "MatchAI", "FullMatch",
            "Defense", "Faceoff", "MatchRules", "UI", "Career", "CareerUI", "SchoolTeams", "CareerSeason",
            "Passing", "Tactics", "Screens", "Style", "Athlete", "Attributes", "Development", "Statistics", "StatsUI", "League", "Awards", "AwardUI", "Presentation", "Clubs", "ClubsUI", "ClubsMatch", "ClubsNet"
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
end

-- SchoolTeams
do
-- PolyLax Build 012 | School identity and venue paint
PolyLax = PolyLax or {}
local SchoolTeams = {}
PolyLax.SchoolTeams = SchoolTeams

local white = color(247, 249, 252)
local competition = {ncaa="NCAA DIVISION I", club="MCLA CLUB", highSchool="HIGH SCHOOL"}

local function swatch(value)
    return color(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

local function school(id, name, short, group, colors, labels, source)
    local primary = swatch(colors.primary)
    local secondary = swatch(colors.secondary)
    local accent = colors.accent and swatch(colors.accent) or secondary
    local shell = colors.shell and swatch(colors.shell) or primary
    local number = colors.number and swatch(colors.number) or white
    return {
        id=id, name=name, short=short, group=group, competition=competition[group],
        fictional=group == "highSchool", colorSource=source,
        fieldType=group, ruleset=group == "highSchool" and "highSchool" or "adult",
        home={teamId=id, primary=primary, secondary=secondary, shorts=primary,
            shell=shell, accent=accent, gloves=shell, number=number},
        away={teamId=id, primary=white, secondary=primary, shorts=white,
            shell=shell, accent=accent, gloves=shell, number=colors.number and number or primary},
        field={id=id, wordmark=labels[1], endWordmark=labels[2], centerWordmark=labels[3] or short,
            primary=primary, secondary=secondary, accent=accent, lettering=colors.number and number or nil}
    }
end

-- Official brand hex values where documented. Kit combinations and lettering
-- are original game designs. The color references contain the real identities.
SchoolTeams.ncaa = {
    school("syracuse", "Syracuse", "SYR", "ncaa",
        {primary=0xF76900, secondary=0x000E54, shell=0x000E54, number=0x000E54},
        {"SYRACUSE", "ORANGE", "SYRACUSE"},
        "https://answers.atlassian.syr.edu/wiki/spaces/SOE/pages/149782933/Quick+Guide+-+SOE+Logos+and+Branded+Materials"),
    school("duke", "Duke", "DUK", "ncaa",
        {primary=0x012169, secondary=0xFFFFFF, accent=0x00539B},
        {"DUKE", "BLUE DEVILS", "DUKE"}, "https://brand.duke.edu/colors/"),
    school("virginia", "Virginia", "UVA", "ncaa",
        {primary=0x232D4B, secondary=0xE57200},
        {"VIRGINIA", "CAVALIERS", "VIRGINIA"}, "https://brand.virginia.edu/design-assets/colors"),
    school("maryland", "Maryland", "UMD", "ncaa",
        {primary=0xE21833, secondary=0xFFD200, shell=0x191D24},
        {"MARYLAND", "TERRAPINS", "MARYLAND"}, "https://brand.umd.edu/visual-identity/colors"),
    school("johns-hopkins", "Johns Hopkins", "JHU", "ncaa",
        {primary=0x002D72, secondary=0x68ACE5, shell=0xFFFFFF},
        {"JOHNS HOPKINS", "BLUE JAYS", "HOPKINS"}, "https://brand.jhu.edu/visual-identity/colors/"),
    school("notre-dame", "Notre Dame", "ND", "ncaa",
        {primary=0x0C2340, secondary=0xC99700, shell=0xC99700},
        {"NOTRE DAME", "FIGHTING IRISH", "NOTRE DAME"}, "https://onmessage.nd.edu/athletics-branding/colors/"),
    school("north-carolina", "North Carolina", "UNC", "ncaa",
        {primary=0x4B9CD3, secondary=0x13294B, shell=0xFFFFFF, number=0x13294B},
        {"NORTH CAROLINA", "TAR HEELS", "CAROLINA"},
        "https://innovate.unc.edu/app/uploads/2024/04/Brand-guide-2024.pdf"),
    school("penn-state", "Penn State", "PSU", "ncaa",
        {primary=0x001E44, secondary=0xFFFFFF, shell=0xFFFFFF},
        {"PENN STATE", "NITTANY LIONS", "PENN STATE"},
        "https://brand.psu.edu/visual-identity-standards/color-and-the-mark"),
    school("cornell", "Cornell", "COR", "ncaa",
        {primary=0xB31B1B, secondary=0xFFFFFF, shell=0xFFFFFF},
        {"CORNELL", "BIG RED", "CORNELL"}, "https://cals.cornell.edu/faculty-staff/marketing-communications/resources/brand-guide/visual-identity/color-typography")
}

SchoolTeams.club = {
    school("florida-state", "Florida State", "FSU", "club",
        {primary=0x782F40, secondary=0xCEB888, shell=0xCEB888},
        {"FLORIDA STATE", "STATE LACROSSE", "FLORIDA STATE"}, "https://brand.fsu.edu/web/colors")
}
SchoolTeams.club[1].teamSource = "https://campusrec.fsu.edu/activities/club-lacrosse-men/"

SchoolTeams.highSchool = {
    school("briarbank", "Briarbank Academy", "BBA", "highSchool",
        {primary=0x244C37, secondary=0xD5B25C}, {"BRIARBANK", "TIMBER OWLS"}),
    school("alderwick", "Alderwick High", "AWK", "highSchool",
        {primary=0x623582, secondary=0xDFC8F4}, {"ALDERWICK", "STORM"}),
    school("stonehaven-ridge", "Stonehaven Ridge High", "SRH", "highSchool",
        {primary=0x283443, secondary=0xE6792F}, {"STONEHAVEN RIDGE", "RIDGEBACKS", "STONEHAVEN"}),
    school("west-fen", "West Fen Academy", "WFA", "highSchool",
        {primary=0x237681, secondary=0xF0D19C}, {"WEST FEN", "HERONS"}),
    school("juniper-reach", "Juniper Reach High", "JRH", "highSchool",
        {primary=0xA94237, secondary=0xFFE0A4}, {"JUNIPER REACH", "COPPERHEADS", "JUNIPER"}),
    school("foxmere", "Foxmere High", "FXM", "highSchool",
        {primary=0x203C72, secondary=0x79D4A2}, {"FOXMERE", "LAKE FOXES"})
}

-- Fictional club opponents keep the Florida State schedule within club competition.
SchoolTeams.clubLeague = {SchoolTeams.club[1],
    school("bayhaven-club", "Bayhaven State Club", "BSC", "club",
        {primary=0x144E78, secondary=0xF1B846}, {"BAYHAVEN", "STATE CLUB"}),
    school("coastal-tech-club", "Coastal Tech Club", "CTC", "club",
        {primary=0x087F74, secondary=0xCDF1DB}, {"COASTAL TECH", "LACROSSE CLUB"}),
    school("north-gulf-club", "North Gulf Club", "NGC", "club",
        {primary=0x752754, secondary=0xEFBCC8}, {"NORTH GULF", "LACROSSE CLUB"}),
    school("pine-coast-club", "Pine Coast Club", "PCC", "club",
        {primary=0x285039, secondary=0xECBD57}, {"PINE COAST", "LACROSSE CLUB"})
}

SchoolTeams.college = {}
local byId, aliases = {}, {uva="virginia", nd="notre-dame"}
for _, group in ipairs({SchoolTeams.ncaa, SchoolTeams.club, SchoolTeams.highSchool}) do
    for _, team in ipairs(group) do
        byId[team.id], aliases[team.short:lower()] = team, team.id
        if team.group ~= "highSchool" then
            SchoolTeams.college[#SchoolTeams.college+1] = team
        end
    end
end

for _, team in ipairs(SchoolTeams.clubLeague) do
    byId[team.id] = team
    if team.id ~= "florida-state" then team.fictional = true end
end

function SchoolTeams.get(id)
    if type(id) ~= "string" then return end
    local key = id:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%s_]+", "-")
    return byId[key] or byId[aliases[key]]
end

function SchoolTeams.defaultOpponent(id)
    local home = SchoolTeams.get(id)
    if not home then return end
    local candidates = home.group == "highSchool" and SchoolTeams.highSchool
        or home.group == "club" and SchoolTeams.clubLeague or SchoolTeams.ncaa
    for _, team in ipairs(candidates) do
        if team.id ~= home.id then return team end
    end
end
end

-- TeamUniform
do
-- PolyLax Build 012 | Shared team uniforms
PolyLax = PolyLax or {}
local P = PolyLax
local TeamUniform = {}
P.TeamUniform = TeamUniform

local white = color(240, 243, 245)
local dark = color(26, 29, 37)
local orange = color(239, 103, 32)
local navy = color(22, 43, 77)
local atlasBlue = color(143, 198, 230)
local red = color(204, 36, 55)
local green = color(23, 77, 65)
local gold = color(223, 174, 62)
local violet = color(109, 70, 161)
local lavender = color(186, 165, 218)
local teal = color(70, 169, 164)

local function kit(primary, secondary, shorts, shell, accent, gloves, number)
    return {
        primary = primary, secondary = secondary, shorts = shorts, shell = shell,
        accent = accent, gloves = gloves, number = number
    }
end

-- PLL Shop's 2026 replicas verify the named home and away jersey colors.
-- RGB swatches and gameplay equipment pairings are visual approximations.
local function team(id, name, short, shopSlug, homeColor, home, away)
    home.teamId, away.teamId = id, id
    return {
        id = id, name = name, short = short,
        namedHomeColor = homeColor, namedAwayColor = "White",
        colorSource = "https://shop.premierlacrosseleague.com/products/" ..
            shopSlug .. "-2026-nike-replica-player-jersey",
        approximateRGB = true,
        fieldType = "professional", ruleset = "adult",
        field = {id=id, wordmark=name:match(" (%S+)$"), endWordmark=name:match("^(.*) %S+$"),
            centerWordmark=short, primary=home.primary, secondary=home.secondary,
            accent=home.accent, lettering=home.number},
        home = home, away = away
    }
end

TeamUniform.teams = {
    team(1, "Utah Archers", "ARC", "utah-archers", "Orange",
        kit(orange, navy, navy, navy, orange, navy, white),
        kit(white, navy, white, navy, orange, white, navy)),
    team(2, "New York Atlas", "ATL", "new-york-atlas", "Light Blue",
        kit(atlasBlue, navy, atlasBlue, navy, atlasBlue, navy, navy),
        kit(white, atlasBlue, white, navy, atlasBlue, white, navy)),
    team(3, "Boston Cannons", "CAN", "boston-cannons", "Navy",
        kit(navy, red, navy, navy, red, navy, white),
        kit(white, navy, white, navy, red, white, navy)),
    team(4, "Carolina Chaos", "CHA", "carolina-chaos", "Red",
        kit(red, dark, dark, dark, red, red, white),
        kit(white, red, white, dark, red, white, dark)),
    team(5, "Denver Outlaws", "OUT", "denver-outlaws", "Black",
        kit(dark, orange, dark, dark, orange, dark, white),
        kit(white, orange, white, dark, orange, white, dark)),
    team(6, "California Redwoods", "RED", "california-redwoods", "Dark Green",
        kit(green, gold, green, green, gold, green, gold),
        kit(white, green, white, green, gold, white, green)),
    team(7, "Philadelphia Waterdogs", "WAT", "philadelphia-waterdogs", "Purple",
        kit(violet, lavender, violet, dark, lavender, lavender, white),
        kit(white, violet, white, dark, lavender, white, violet)),
    team(8, "Maryland Whipsnakes", "WHI", "maryland-whipsnakes", "Black",
        kit(dark, red, dark, dark, teal, white, white),
        kit(white, red, white, dark, teal, white, dark))
}

-- Stored jersey indices were green, blue, red, white, black, and gold.
local priorJerseyTeams = {6, 3, 4, 2, 5, 1}

local function findTeam(id)
    return TeamUniform.teams[tonumber(id)] or (P.SchoolTeams and P.SchoolTeams.get(id))
end

function TeamUniform.get(id)
    return findTeam(id) or TeamUniform.teams[1]
end

function TeamUniform.legacyTeam(jersey)
    return priorJerseyTeams[tonumber(jersey)] or 1
end

function TeamUniform.fromProfile(profile)
    profile = profile or {}
    if profile.TEAM then return TeamUniform.get(profile.TEAM).home end
    return TeamUniform.get(TeamUniform.legacyTeam(profile.JERSEY)).home
end

local function contrast(a, b)
    local dr, dg, db = a.r - b.r, a.g - b.g, a.b - b.b
    return 2 * dr * dr + 4 * dg * dg + 3 * db * db
end

function TeamUniform.opponent(homeKit, opponentId)
    local homeId = homeKit.teamId
    local opponent = findTeam(opponentId)
    if not opponent or opponent.id == homeId then
        local school = P.SchoolTeams and P.SchoolTeams.defaultOpponent(homeId)
        local number = tonumber(homeId)
        if school then
            opponent = school
        elseif number and opponent then
            opponent = TeamUniform.teams[number % #TeamUniform.teams + 1]
        else
            opponent = TeamUniform.teams[number == 2 and 3 or 2]
        end
    end
    local away, home = opponent.away, opponent.home
    -- The away club may use its colored jersey if white would clash.
    if contrast(homeKit.primary, away.primary) < 30000
        and contrast(homeKit.primary, home.primary) > contrast(homeKit.primary, away.primary) then
        return home
    end
    return away
end

function TeamUniform.matchKits(homeId, awayId)
    local home = TeamUniform.get(homeId)
    local awayKit = TeamUniform.opponent(home.home, awayId)
    return home.home, awayKit, home, TeamUniform.get(awayKit.teamId)
end

function TeamUniform.forKeeper(uniform, role, opponentId)
    if role == "friendly" then return uniform end
    return TeamUniform.opponent(uniform, opponentId)
end

if P.Profile then P.Profile.setTeamOptions(TeamUniform.teams) end
end

-- Profile
do
-- PolyLax Build 011 Gameplay | Profile
PolyLax = PolyLax or {}
local Profile = {}
PolyLax.Profile = Profile

local gear = {"WHITE", "BLUE", "RED", "BLACK", "GREEN", "GOLD"}
local teamChoices = {}

Profile.categories = {
    {key="FACE", choices={"FACE 1", "FACE 2", "FACE 3", "FACE 4"}, default=2},
    {key="HAIR", choices={"NONE", "CLASSIC 1", "CLASSIC 2", "CLASSIC 3", "CLASSIC 4", "CLASSIC 5"}, default=3},
    {key="BEARD", choices={"CLEAN", "STUBBLE", "MUSTACHE", "GOATEE", "SHORT", "FULL"}, default=1},
    {key="BODY", choices={"LEAN", "ATHLETIC", "STOCKY", "TALL"}, default=2},
    {key="HELMET", choices={
        "WHITE", "BLUE", "RED", "BLACK", "GREEN", "GOLD", "SILVER CHROME",
        "BLUE CHROME", "GOLD CHROME", "RED CHROME", "BLACK CHROME"
    }, default=1},
    {key="TEAM", choices=teamChoices, default=1},
    {key="GLOVES", choices=gear, default=1},
    {key="SHORTS", choices=gear, default=4},
    {key="CLEATS", choices=gear, default=1},
    {key="STICK", choices=gear, default=1},
    {key="NUMBER", choices={}, default=4},
    {key="SLEEVES", label="LEG SLEEVES", choices={
        "OFF", "WHITE", "BLACK", "TEAM", "WHITE LEFT", "WHITE RIGHT", "BLACK LEFT", "BLACK RIGHT"
    }, default=1},
    {key="HOODIE", choices={"OFF", "TEAM", "WHITE", "BLACK"}, default=1},
    {key="OPPONENT", label="OPPONENT", choices=teamChoices, default=2}
}

local numberChoices = Profile.categories[11].choices
for number = 0, 99 do
    numberChoices[number + 1] = tostring(number)
end

local function storageKey(category)
    return "PolyLax.Profile." .. category.key
end

function Profile.setTeamOptions(teams)
    for _, team in ipairs(teams) do teamChoices[team.id] = team.name end
end

if PolyLax.TeamUniform then Profile.setTeamOptions(PolyLax.TeamUniform.teams) end

local function nextTeam(index, direction)
    return (index - 1 + direction) % #teamChoices + 1
end

local function saveChoice(profile, key, index)
    profile[key] = index
    saveLocalData("PolyLax.Profile." .. key, index)
end

function Profile.load()
    local profile = {}
    for _, category in ipairs(Profile.categories) do
        local index = tonumber(readLocalData(storageKey(category)))
        if not index and category.key == "TEAM" then
            local previousJersey = readLocalData("PolyLax.Profile.JERSEY")
            index = PolyLax.TeamUniform.legacyTeam(previousJersey)
        end
        if not index or index % 1 ~= 0 or index < 1 or index > #category.choices then
            index = category.default
        end
        profile[category.key] = index
    end
    if profile.OPPONENT == profile.TEAM then
        profile.OPPONENT = nextTeam(profile.TEAM, 1)
    end
    return profile
end

function Profile.select(profile, category, index)
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #category.choices then
        return
    end
    local key = category.key
    if key == "TEAM" and index == profile.OPPONENT then
        saveChoice(profile, "OPPONENT", profile.TEAM)
    elseif key == "OPPONENT" and index == profile.TEAM then
        local direction = profile.OPPONENT == nextTeam(index, 1) and -1 or 1
        index = nextTeam(index, direction)
    end
    saveChoice(profile, key, index)
end
end

-- Character
do
-- PolyLax 011 player rig and procedural equipment
PolyLax = PolyLax or {}
local Character = {}
PolyLax.Character = Character

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

local function dressTorso(r)
    local m = r.materials
    part(r, r.body, "jersey", m.jersey, function(mesh)
        loft(mesh, {
            {.19, .30, .185}, {.32, .35, .22}, {.66, .39, .226},
            {.78, .40, .207}, {.87, .25, .15}
        }, 8, math.pi / 8, true)
    end)
    part(r, r.body, "neck", m.skin, function(mesh)
        bevel(mesh, 0, .98, .006, .24, .35, .26)
    end)
    part(r, r.body, "collar", m.jerseyTrim, function(mesh)
        rail(mesh, .019, {V(-.15, .863, -.155), V(0, .80, -.208), V(.15, .863, -.155)})
    end)
    part(r, r.pelvis, "shorts waist", m.shorts, function(mesh)
        bevel(mesh, 0, .104, .01, .764, .33, .46)
    end)
    r.numberMark = entity(r.scene, r.body)

    part(r, r.body, "hoodie exterior", m.hoodie, function(mesh)
        loft(mesh, {
            {.23, .301, .205}, {.31, .373, .236}, {.66, .404, .239},
            {.79, .405, .228}, {.88, .255, .17}
        }, 8, math.pi / 8, true)
        loft(mesh, {
            {.695, .13, .105, .24}, {.785, .225, .165, .25},
            {.92, .24, .164, .226}, {1.045, .201, .108, .208},
            {1.095, .12, .059, .188}
        }, 8, math.pi / 8)
    end, r.hoodieParts)
    part(r, r.body, "hoodie trim", m.hoodTrim, function(mesh)
        rail(mesh, .015, {V(-.171, 1.01, .11), V(-.12, 1.075, .129),
            V(0, 1.09, .124), V(.12, 1.075, .129), V(.171, 1.01, .11)})
        rail(mesh, .011, {V(-.23, .298, -.232), V(-.181, .32, -.245),
            V(-.112, .405, -.247), V(.112, .405, -.247),
            V(.181, .32, -.245), V(.23, .298, -.232)})
        rail(mesh, .009, {V(-.11, .833, -.205), V(-.084, .765, -.231), V(-.101, .675, -.241)})
        rail(mesh, .009, {V(.11, .833, -.205), V(.102, .76, -.234), V(.094, .655, -.242)})
    end, r.hoodieParts)
end

local function arm(r, sign, name)
    local m = r.materials
    local shoulder = entity(r.scene, r.body, sign * .49, .73, 0)
    local elbow = entity(r.scene, shoulder, 0, -.33, 0)
    local wrist = entity(r.scene, elbow, 0, -.31, 0)
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
    end)
    part(r, shoulder, "jersey cuff", m.jerseyTrim, function(mesh)
        box(mesh, 0, -.131, -.171, .21, .034, .025)
    end)
    part(r, shoulder, "hoodie upper sleeve", m.hoodie, function(mesh)
        bevel(mesh, 0, -.111, .002, .293, .444, .355)
    end, r.hoodieParts)
    part(r, elbow, "hoodie lower sleeve", m.hoodie, function(mesh)
        bevel(mesh, 0, -.123, 0, .217, .326, .246)
    end, r.hoodieParts)
    part(r, elbow, "elbow pads", m.silver, function(mesh)
        bevel(mesh, 0, -.049, -.105, .231, .20, .107)
        bevel(mesh, 0, -.052, .1, .196, .139, .067)
    end)
    part(r, wrist, "glove shell", m.gloves, function(mesh)
        bevel(mesh, 0, .047, .008, .245, .293, .237)
        bevel(mesh, 0, .128, .001, .267, .101, .234)
    end)
    part(r, wrist, "glove joints", m.gloveTrim, function(mesh)
        for i = -1, 1 do
            bevel(mesh, i * .066, -.025, -.089, .054, .118, .068)
        end
        bevel(mesh, 0, .065, -.09, .181, .038, .067)
        bevel(mesh, 0, .122, -.112, .212, .021, .033)
    end)
end

local function leg(r, sign, name)
    local m = r.materials
    local hip = entity(r.scene, r.pelvis, sign * .205, 0, 0)
    local knee = entity(r.scene, hip, 0, -.46, 0)
    local ankle = entity(r.scene, knee, 0, -.44, 0)
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
    end)
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
    end)
    part(r, ankle, "cleat", m.cleats, function(mesh)
        loft(mesh, {{-.106, .145, .231, -.092}, {-.04, .151, .23, -.092},
            {.04, .124, .168, -.044}, {.092, .104, .116, .013}},
            8, math.pi / 8, true)
    end)
    part(r, ankle, "cleat sole", m.dark, function(mesh)
        bevel(mesh, 0, -.113, -.093, .305, .039, .476)
        for _, x in ipairs({-.085, .085}) do
            for _, z in ipairs({-.245, -.105, .049}) do
                box(mesh, x, -.129, z, .039, .022, .046)
            end
        end
    end)
    part(r, ankle, "cleat lace", m.white, function(mesh)
        for i = 0, 2 do
            local y, z = .044 + .016 * i, -.186 + .046 * i
            bar(mesh, V(-.065, y, z), V(.065, y, z), .008, 4)
        end
    end)
end

local function makeHead(r)
    local m = r.materials
    r.head = entity(r.scene, r.body, 0, 1.18, 0)
    r.joints.head = r.head
    part(r, r.head, "head", m.skin, function(mesh)
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
    r.faceParts = {}
    local faceDetails = {
        { eyes = .112, brow = .180, gap = .132, nose = .070, mouth = .119 },
        { eyes = .111, brow = .186, gap = .148, nose = .085, mouth = .145 },
        { eyes = .097, brow = .182, gap = .139, nose = .091, mouth = .153 },
        { eyes = .127, brow = .198, gap = .145, nose = .073, mouth = .125 }
    }
    for i, face in ipairs(faceDetails) do
        local group = {}
        r.faceParts[i] = group
        part(r, r.head, "face nose " .. i, m.skin, function(mesh)
            loft(mesh, {{-.036, face.nose * .51, .041, -.259},
                {.002, face.nose * .55, .060, -.271},
                {.093, face.nose * .34, .033, -.254},
                {.15, face.nose * .29, .011, -.241}}, 6)
        end, group)
        part(r, r.head, "eye flats " .. i, m.white, function(mesh)
            for _, s in ipairs({-1, 1}) do
                bevel(mesh, s * face.gap, face.eyes, -.244, .095, .045, .035)
            end
        end, group)
        part(r, r.head, "face expression " .. i, m.dark, function(mesh)
            for _, s in ipairs({-1, 1}) do
                bevel(mesh, s * (face.gap - .009), face.eyes, -.259, .038, .041, .02)
                rail(mesh, .011, {V(s * (face.gap - .053), face.brow - .008, -.257),
                    V(s * face.gap, face.brow, -.254),
                    V(s * (face.gap + .058), face.brow - .012, -.221)}, 5)
            end
            rail(mesh, .009, {V(-face.mouth * .5, -.113, -.251), V(0, -.12, -.268),
                V(face.mouth * .5, -.113, -.251)}, 4)
        end, group)
    end

    r.hairRoot = entity(r.scene, r.head)
    r.hairParts = {}
    for i = 2, 6 do
        r.hairParts[i] = part(r, r.hairRoot, "hair " .. i, m.hair, function(mesh)
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
    r.beardRoot = entity(r.scene, r.head)
    r.beardParts = {}
    for i = 2, 6 do
        r.beardParts[i] = part(r, r.beardRoot, "beard " .. i, m.beard, function(mesh)
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
    long = {extension=.46, butt=-1.36, lowerGrip=-.48}
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
end

-- Keep the upper grip at the stick origin. Move the pocket, head and mesh
-- together so possessions and release points follow the visible equipment.
function Character.setStickType(rig, kind)
    if kind ~= "long" then kind = "short" end
    if kind == rig.stickType then return end
    local size = stickSizes[kind]
    rig.stickType, rig.stickReachExtension = kind, size.extension
    rig.stickShaft.model = model("stick alloy "..kind, function(mesh) shaft(mesh,size) end)
    rig.stickTape.model = model("stick tape "..kind, function(mesh) shaftTape(mesh,size) end)
    rig.stickHead.position = V(0,size.extension,0)
    rig.stickMesh.position = V(0,size.extension,0)
    rig.pocket.position = V(0,.70+size.extension,-.10)
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
        armLengthUpper = .33, armLengthLower = .31,
        legLengthUpper = .46, legLengthLower = .44,
        ankleHeight = .14, pelvisHeight = 1.04,
        hoodieParts = {}, helmetParts = {}, stickParts = {},
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

    local size = bodySizes[option(profile, "BODY", #bodySizes)]
    local athlete = PolyLax.Athlete
    local chosenHeight = athlete and athlete.heightScale(profile)
    r.proportions.scale = V(size[1], chosenHeight or size[2], size[1])
end
end

-- AnimationController
do
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
    },
    pokeCheckLong = {
        duration = .42, eventTime = .16, event = "check",
        poses = {
            frame(.07,vec3(.57,.69,-.40),vec3(.14,.98,.05),vec3(-5,-12,-6),.07,-17,.89),
            frame(.16,vec3(.56,.65,-.46),vec3(.11,.16,-.98),vec3(-13,5,4),.10,4,.94),
            frame(.28,vec3(.58,.61,-.41),vec3(.12,.55,-.81),vec3(-7,7,4),.07,10,.90),
            frame(.36,vec3(.53,.66,-.40),vec3(.14,.98,.09),vec3(-5,2,1),.035,5,.59)
        }
    },
    slapCheckLong = {
        duration = .58, eventTime = .23, event = "check",
        poses = {
            frame(.10,vec3(.58,.75,-.40),vec3(.72,.67,.10),vec3(3,-30,-9),.05,-27,.68),
            frame(.15,vec3(.60,.73,-.44),vec3(.17,.97,.09),vec3(-3,-12,0),.07,-16,.89),
            frame(.23,vec3(.61,.67,-.48),vec3(.19,.15,-.97),vec3(-10,19,8),.10,16,.94),
            frame(.38,vec3(.61,.53,-.48),vec3(.20,.35,-.91),vec3(-8,24,8),.06,30,.94),
            frame(.48,vec3(.57,.62,-.42),vec3(.14,.98,.09),vec3(-5,14,5),.03,13,.71)
        }
    }
}

-- Keep the release and catch events at the existing times. A long shaft
-- needs a more forward windup and a shallower approach to the ground.
local function longVariant(action, poses)
    local clip = Animation.clips[action]
    return {duration=clip.duration,eventTime=clip.eventTime,event=clip.event,poses=poses}
end

local longVariants = {
    pass = longVariant("pass", {
        frame(.16,vec3(.37,.81,-.37),vec3(.69,.66,.26),vec3(4,-28,-5),.025,-20),
        frame(.29,vec3(.39,.83,-.49),vec3(.76,.62,-.17),vec3(-10,15,4),.035,9,.21),
        frame(.41,vec3(.30,.56,-.47),vec3(.91,.37,-.14),vec3(-15,25,5),.035,25)
    }),
    shoot = longVariant("shoot", {
        frame(.21,vec3(.46,.92,-.39),vec3(.74,.59,.32),vec3(9,-43,-8),.055,-26,.17),
        frame(.38,vec3(.42,.84,-.50),vec3(.75,.63,-.21),vec3(-15,25,6),.07,12,.24),
        frame(.52,vec3(.30,.49,-.48),vec3(.96,-.18,-.18),vec3(-25,35,9),.08,35,.13)
    }),
    catch = longVariant("catch", {
        Animation.clips.catch.poses[1],
        frame(.30,vec3(.34,.70,-.35),vec3(.58,.80,.13),vec3(3,-12,-4),.02,12)
    }),
    scoop = longVariant("scoop", {
        frame(.08,vec3(.54,.53,-.39),vec3(.12,.97,.05),vec3(-11,-4,-2),.08,-5,.84),
        frame(.14,vec3(.55,.48,-.38),vec3(.11,.43,-.89),vec3(-17,-6,-4),.12,-7,.93),
        frame(.32,vec3(.52,.29,-.36),vec3(.10,-.10,-.99),vec3(-21,-4,-4),.25,-3,1),
        frame(.44,vec3(.55,.52,-.39),vec3(.12,.60,-.79),vec3(-14,-4,-3),.11,10,.93),
        frame(.52,vec3(.52,.60,-.39),vec3(.13,.98,.09),vec3(-9,-2,-1),.05,5,.64)
    }),
    dodge = longVariant("dodge", {
        frame(.09,vec3(.31,.66,-.35),vec3(.62,.74,.10),vec3(-10,-17,-9),.12,-23),
        frame(.23,vec3(.38,.58,-.37),vec3(.71,.68,.10),vec3(-16,-30,-20),.15,-27),
        frame(.34,vec3(.34,.65,-.36),vec3(.61,.77,.10),vec3(-8,-13,-9),.07,-11)
    }),
    protect = longVariant("protect", {
        frame(.12,vec3(.35,.67,-.35),vec3(.66,.73,.10),vec3(-5,-23,-9),.08,-24),
        frame(.26,vec3(.35,.65,-.36),vec3(.62,.77,.10),vec3(-5,-20,-8),.06,-24)
    })
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
    if rig.stickType == "long" then
        base.grip = vec3(.30 + cradle * .031, .68 + breath * .012 + swing * .025,
            -.38 + swing * .053 + cradle * .028)
        base.shaft = vec3(.52 + cradle * .09, .85 - cradle * .06,
            .11 + swing * .067 + cradle * .036)
        base.roll = cradle * 15 + swing * 6
    end
    local pose, event = base, nil
    local pocketTarget, pocketWeight
    if controller.action then
        local clip = Animation.clips[controller.action]
        if rig.stickType == "long" then clip = longVariants[controller.action] or clip end
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
end

-- CameraController
do
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
    if category == "HELMET" then
        local headY = rig.head.worldPosition.y
        -- Allow for the jaw, visor, and head motion as the fitted helmet turns.
        return headY - .34 * height, headY + .55 * height, .53 * width
    elseif category == "FACE" or category == "HAIR" or category == "BEARD" then
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

-- Keep the ball's direction readable when a locked player is away from play.
function Camera.ballEdge(camera, ball, frame, left, right)
    local screen = Camera.project(camera, ball)
    local low, high = frame.bottom+16, frame.top-16
    left, right = left+16, right-16
    if screen and screen.x >= left and screen.x <= right
        and screen.y >= low and screen.y <= high then return end
    local x, y = (left+right)*.5, (low+high)*.5
    local dx, dy
    if screen then
        dx, dy = screen.x-x, screen.y-y
    else
        local view = camera.entity:inverseTransformPoint(ball)
        dx, dy = view.x, math.min(-.25,view.y)
    end
    local scale = math.min((right-x)/math.max(.001,math.abs(dx)),
        (high-y)/math.max(.001,math.abs(dy)))
    local length = math.sqrt(dx*dx+dy*dy)
    if length > .001 then
        return {x=x+dx*scale,y=y+dy*scale,dx=dx/length,dy=dy/length}
    end
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
end

-- GoalPhysics
do
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
end

-- Attributes
do
-- PolyLax 2.0 | Player attributes
PolyLax = PolyLax or {}
local A = {}
PolyLax.Attributes = A

local descriptors = {
    {key="speed", label="Speed", description="Top running speed", value=61, group="Athletic"},
    {key="acceleration", label="Acceleration", description="How quickly the player reaches speed", value=60, group="Athletic"},
    {key="agility", label="Agility", description="Turning speed and dodge control", value=60, group="Athletic"},
    {key="stamina", label="Stamina", description="Sprint endurance and recovery", value=60, group="Athletic"},
    {key="strength", label="Strength", description="Body-contact leverage and planted pick stability", value=60, group="Athletic"},
    {key="shotPower", label="Shot Power", description="Shot release velocity", value=57, group="Offense"},
    {key="shotAccuracy", label="Shot Accuracy", description="Shot placement under motion and pressure", value=57, group="Offense"},
    {key="passing", label="Passing", description="Pass and outlet pace and placement", value=58, group="Offense"},
    {key="ballControl", label="Ball Control", description="Catch range and stick protection", value=58, group="Offense"},
    {key="groundBalls", label="Ground Balls", description="Scoop reach and timing", value=58, group="Offense"},
    {key="stickCheck", label="Stick Check", description="Poke and slap check timing and effectiveness", value=56, group="Defense"},
    {key="bodyCheck", label="Body Check", description="Effectiveness of legal body checks", value=56, group="Defense"},
    {key="defensiveAwareness", label="Defensive Awareness", description="Reading passing lanes and reacting to interceptions", value=58, group="Defense"},
    {key="lacrosseIQ", label="Lacrosse IQ", description="AI reads, spacing and cut choices", value=60, group="Tactics"},
    {key="faceoff", label="Faceoff", description="Draw timing and clamp strength", value=51, group="Tactics"},
    {key="reflexes", label="Reflexes", description="Goalkeeper response and save speed", value=55, group="Goalkeeping"},
    {key="goaliePositioning", label="Goalie Positioning", description="Goalkeeper arc, coverage and lateral positioning", value=57, group="Goalkeeping"}
}
A.descriptors = descriptors

local keys, descriptorByKey = {}, {}
for index, descriptor in ipairs(descriptors) do
    keys[index] = descriptor.key
    descriptorByKey[descriptor.key] = descriptor
end
A.keys = keys

local aliases = {
    shooting="shotPower", ballSecurity="ballControl",
    reaction="defensiveAwareness", interception="defensiveAwareness",
    handSpeed="reflexes", clearingAccuracy="passing"
}

local legacy = {
    shotPower={"shooting"}, shotAccuracy={"shooting"}, ballControl={"ballSecurity"},
    defensiveAwareness={"interception", "reaction"}, reflexes={"handSpeed"},
    passing={"clearingAccuracy"}
}

local presets = {
    {speed=69, acceleration=65, agility=70, strength=64, shotPower=68, shotAccuracy=68,
        passing=62, ballControl=67, lacrosseIQ=63},
    {speed=72, acceleration=67, agility=65, stamina=71, passing=65, strength=66,
        groundBalls=64, lacrosseIQ=63},
    {agility=64, stickCheck=72, bodyCheck=70, defensiveAwareness=70, strength=73,
        groundBalls=66, lacrosseIQ=65},
    {acceleration=70, faceoff=76, defensiveAwareness=69, stamina=70, strength=70,
        groundBalls=67},
    {reflexes=75, goaliePositioning=74, passing=68, strength=62, lacrosseIQ=64},
    {speed=70, acceleration=67, stamina=70, groundBalls=69, stickCheck=73, defensiveAwareness=71},
    {speed=69, acceleration=68, agility=70, stamina=71, bodyCheck=70, defensiveAwareness=72}
}

local weights = {
    {shotPower=5, shotAccuracy=5, speed=3, acceleration=2, agility=3,
        passing=3, ballControl=4, groundBalls=1, lacrosseIQ=3},
    {speed=4, acceleration=3, agility=3, stamina=5, shotPower=2, shotAccuracy=2,
        passing=4, ballControl=3, groundBalls=3, stickCheck=1, lacrosseIQ=3},
    {speed=2, acceleration=2, agility=3, strength=3, groundBalls=2, stickCheck=5,
        bodyCheck=4, defensiveAwareness=5, lacrosseIQ=3, passing=2},
    {faceoff=8, acceleration=3, stamina=4, strength=4, ballControl=2,
        groundBalls=4, defensiveAwareness=3, lacrosseIQ=2},
    {reflexes=8, goaliePositioning=8, passing=4, agility=2, acceleration=2,
        ballControl=2, strength=1, lacrosseIQ=3},
    {speed=4, acceleration=3, stamina=3, groundBalls=5, stickCheck=5,
        defensiveAwareness=5, passing=2, lacrosseIQ=3},
    {speed=4, agility=4, stamina=4, strength=3, bodyCheck=4,
        defensiveAwareness=5, groundBalls=2, lacrosseIQ=4}
}

local roleIndex = {
    A=1, ATTACK=1, M=2, MIDFIELD=2, D=3, DEFENSE=3,
    F=4, FO=4, FACEOFF=4, G=5, GOALIE=5, KEEPER=5, LSM=6, SSDM=7
}

local function position(role)
    local index = tonumber(role) or roleIndex[tostring(role):upper()]
    return presets[index] and index or 2
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function number(value)
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then return value end
end

local function points(value)
    value = number(value)
    if not value then return end
    if value > 0 and value < 1 then value = value * 100 end
    return clamp(math.floor(value + .5), 0, 99)
end

local function raw(values, key)
    if type(values) ~= "table" then return end
    local canonical = aliases[key] or key
    local value = number(values[canonical]) or number(values[key])
    if value then return value end
    local previousKeys = legacy[canonical]
    if previousKeys then
        for _, old in ipairs(previousKeys) do
            value = number(values[old])
            if value then return value end
        end
    end
end

function A.forPosition(role)
    local custom = presets[position(role)]
    local values = {}
    for _, descriptor in ipairs(descriptors) do
        values[descriptor.key] = custom[descriptor.key] or descriptor.value
    end
    return values
end

function A.restore(saved, role)
    local values = A.forPosition(role)
    if type(saved) ~= "table" then return values end
    local specialization = position(role)
    local isLegacy = saved.shotPower == nil and saved.shotAccuracy == nil
        and saved.ballControl == nil and saved.defensiveAwareness == nil
    for _, key in ipairs(keys) do
        local value = raw(saved, key)
        if isLegacy then
            if specialization == 5 and key == "passing" then
                value = number(saved.clearingAccuracy) or value
            elseif specialization == 5 and key == "goaliePositioning" then
                value = value or number(saved.handSpeed)
            elseif specialization == 4 and key == "defensiveAwareness" then
                value = number(saved.reaction) or value
            end
        end
        if value then values[key] = points(value) end
    end
    return values
end

function A.overall(values, role)
    local normal = A.restore(values, role)
    local score, total = 0, 0
    for key, weight in pairs(weights[position(role)]) do
        score, total = score + normal[key]*weight, total + weight
    end
    return math.floor(score / total + .5)
end

function A.cost(values, key, role)
    local descriptor = descriptorByKey[key]
    if not descriptor then return nil end
    local value = points(raw(values,key)) or A.forPosition(role)[key]
    if value >= 99 then return nil end
    return 12 + math.max(0,value-50) + math.max(0,value-75)*2 + math.max(0,value-90)*3
end

function A.advance(values, key, role)
    local cost = A.cost(values,key,role)
    if not cost then return false end
    local value = points(raw(values,key)) or A.forPosition(role)[key]
    return value+1, cost
end

-- Actor stats can also be supplied by older modules as fractional attributes.
local function ratingsOf(player)
    if not player then return end
    if player.rig or player.anim or player.id then return player.attributes end
    return player.attributes or player
end

function A.rating(player, key, fallback)
    return points(raw(ratingsOf(player),key)) or fallback
end

function A.unit(player, key, fallback)
    local value = raw(ratingsOf(player),key)
    if not value then return fallback end
    if value > 0 and value < 1 then return math.min(value,.99) end
    return clamp(value/100, 0, .99)
end

function A.updateFatigue(player, dt)
    local stamina = A.unit(player,"stamina")
    if not stamina then return end
    local exertion = clamp(((player.speed or 0)-4)/5, 0, 1)
    local rate = exertion > .08 and exertion*(.104-.061*stamina)
        or -(.13+.16*stamina)
    player.runningFatigue = clamp((player.runningFatigue or 0) + dt*rate, 0, 1)
end

function A.pace(player, base)
    return (base + (A.rating(player,"speed",62)-62)*.034)
        * (1 - (player.runningFatigue or 0)*.26)
end

function A.shotSpread(game, player, range)
    local accuracy = A.unit(player,"shotAccuracy")
    if not accuracy then return 0, 0 end
    local pressure = 0
    for _, defender in ipairs(game.squad) do
        if defender.team ~= player.team then
            local dx, dz = player.x-defender.x, player.z-defender.z
            pressure = math.max(pressure, 1-math.sqrt(dx*dx+dz*dz)/2.8)
        end
    end
    local motion = math.min(1, (player.speed or 0)/9)
    local error = (1-accuracy) * clamp(range/18,.36,1.35) * (.55 + .35*motion + .48*pressure)
    game.shotSerial = (game.shotSerial or 0)+1
    local phase = game.shotSerial*2.399963 + (player.id or 1)*.731
    return math.sin(phase)*error, math.cos(phase)*error*.58
end
end

-- Passing
do
-- PolyLax Build 013 | Passing
PolyLax = PolyLax or {}
local P = PolyLax
local Passing = {}
P.Passing = Passing

local cone = math.cos(math.rad(34))
local deadzone = .12
local ballRadius = .09

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x*x + z*z)
end

local function teammate(from, player)
    return player ~= from and player.team == from.team
end

function Passing.forTarget(game, id)
    local player = id and game.squad[id]
    if player then
        return {to=id, point=player.rig.pocket.worldPosition}
    end
end

function Passing.select(game, fromID, dx, dz)
    local from = fromID and game.squad[fromID]
    if not from then return end
    dx, dz = dx or 0, dz or 0
    local input = length(dx, dz)
    if input >= deadzone then
        dx, dz = dx/input, dz/input
    else
        local yaw = math.rad(from.yaw or 0)
        dx, dz = -math.sin(yaw), -math.cos(yaw)
    end

    local target, score = nil, -math.huge
    for index, player in ipairs(game.squad) do
        if teammate(from, player) then
            local x, z = player.x-from.x, player.z-from.z
            local range = length(x, z)
            if range > .28 then
                local alignment = (dx*x + dz*z) / range
                if alignment >= cone then
                    -- Aim direction wins. Distance breaks ties within the cone.
                    local rank = alignment - math.min(range,36)*.0002
                    if rank > score then target, score = index, rank end
                end
            end
        end
    end
    if target then
        local plan = Passing.forTarget(game, target)
        plan.from = fromID
        return plan
    end

    local maxRange = game.field and 26 or 16
    local range = 7 + (maxRange-7) * math.min(1,input)
    return {from=fromID, point=vec3(from.x+dx*range,ballRadius,from.z+dz*range), dx=dx, dz=dz}
end

-- The authored catch pose holds the pocket ahead and to the player's right.
-- Use the incoming direction and profile proportions to predict that position
-- without advancing the actual receiving animation before the ball launches.
local function catchOffset(receiver, source, x, z)
    local dx, dz = source.x-x, source.z-z
    local range = length(dx, dz)
    if range < .05 then
        local yaw = math.rad(receiver.yaw or 0)
        dx, dz, range = -math.sin(yaw), -math.cos(yaw), 1
    end
    dx, dz = dx/range, dz/range
    local scale = receiver.rig.proportions.scale
    local extension = receiver.rig.stickReachExtension or 0
    -- The catch pose's tilted shaft places the long pocket farther to the right and higher.
    local forward, lateral = .67 + .22*extension, .82 + .70*extension
    return vec3((forward*dx-lateral*dz)*scale.x, (2.23+.714*extension)*scale.y,
        (forward*dz+lateral*dx)*scale.z)
end

local function dispersion(game, pending, sender, origin, point, range)
    local clear = sender.role == "G" or pending.call == "CLEAR"
    local skill = P.Attributes.unit(sender, clear and "clearingAccuracy" or "passing", .66)

    local pressure = 0
    for _, player in ipairs(game.squad) do
        if player.team ~= sender.team then
            local gap = length(sender.x-player.x,sender.z-player.z)
            pressure = math.max(pressure, 1-gap/2.6)
        end
    end
    local motion = clamp((sender.speed or 0)/9, 0, 1)
    local error = clamp(range/17,.34,1.5) * (.11+.59*(1-skill)+.42*pressure+.32*motion)
    local seed = (game.passSerial or 0)*2.399963 + pending.from*.731
    game.passSerial = (game.passSerial or 0)+1
    local x, z = point.x-origin.x, point.z-origin.z
    local span = math.max(.25,length(x,z))
    local sideways, forward = math.sin(seed)*error, math.cos(seed*1.63)*error*.28
    return vec3((-z*sideways+x*forward)/span, 0, (x*sideways+z*forward)/span)
end

function Passing.launch(game, pending, options, speedOverride)
    options = options or {}
    local sender = game.squad[pending.from]
    local receiver = pending.to and game.squad[pending.to]
    local origin = sender.rig.pocket.worldPosition
    local point = receiver and receiver.rig.pocket.worldPosition or pending.point
    local speed = speedOverride or options.speed or 20
    local distance = length(point.x-origin.x, point.z-origin.z)
    local duration = clamp(distance / speed, options.minDuration or .34, options.maxDuration or 2.4)

    if receiver then
        local lead = math.min(.42, duration*.7)
        local x, z = receiver.x + (receiver.vx or 0)*lead, receiver.z + (receiver.vz or 0)*lead
        point = vec3(x,0,z) + catchOffset(receiver, origin, x, z)
    end
    point = point + dispersion(game,pending,sender,origin,point,distance)

    local arc = clamp(distance * (options.arcRate or .060), options.minArc or .18, options.maxArc or 1.25)
    local offset = point-origin
    return {
        kind="pass", from=pending.from, to=pending.to, team=sender.team,
        origin=origin, point=point, time=0, duration=duration, arc=arc,
        velocity=offset/duration + vec3(0,4*arc/duration,0)
    }
end

function Passing.sample(game, flight, time)
    local fraction = clamp(time / flight.duration, 0, 1)
    return flight.origin + (flight.point-flight.origin)*fraction
        + vec3(0, 4*flight.arc*fraction*(1-fraction), 0)
end

function Passing.endVelocity(game, flight)
    local speed = (Passing.sample(game,flight,flight.duration)
        - Passing.sample(game,flight,math.max(0,flight.duration-.025))) / .025
    return speed * (flight.to and .17 or .31)
end

function Passing.receiveTarget(game, index)
    local flight = game.flight
    if not flight or flight.kind ~= "pass" or not flight.point
        or flight.to ~= index then return end
    local receiver = game.squad[index]
    local readTime = .85+(P.Attributes.rating(receiver,"lacrosseIQ",60)-60)*.006
    if flight.duration-flight.time > readTime then return end
    local offset = catchOffset(receiver, flight.origin, receiver.x, receiver.z)
    return flight.point.x-offset.x, flight.point.z-offset.z
end

function Passing.scheduleCatch(game, flight, dt)
    if not flight or not flight.to or flight.catchStarted then return end
    local contact = P.AnimationController.clips.catch.eventTime
    local remaining = flight.duration-flight.time
    if remaining <= contact+dt then
        local scale = contact / math.max(dt, remaining-.001)
        flight.catchStarted = P.AnimationController.play(game.squad[flight.to].anim, "catch", scale)
    end
end

function Passing.catchPoint(game, index)
    local flight = game.flight
    if flight and flight.kind == "pass" and flight.to == index and flight.catchStarted then
        return flight.point
    end
end

function Passing.canCatch(game, flight, index, position)
    if not index or index ~= flight.to then return false end
    local receiver = game.squad[index]
    local gap = position - receiver.rig.pocket.worldPosition
    local control = receiver.attributes and receiver.attributes.ballControl
    local reach = .82+(control and P.Attributes.rating(receiver,"ballControl",65)-65 or 0)*.004
    return gap:len() <= reach
end
end

-- Tactics
do
-- PolyLax Build 013 | Positional lacrosse calls shared by practice and matches
PolyLax = PolyLax or {}
local Tactics = {}
PolyLax.Tactics = Tactics

local atan2 = math.atan2 or math.atan
local turn = 2 * math.pi

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function unit(x, z)
    local distance = length(x, z)
    if distance < .001 then return 0, 0 end
    return x / distance, z / distance
end

local function sign(value)
    return value < 0 and -1 or 1
end

local function attackGoal(game, team, options)
    return options and options.goal or game.goalsByTeam and game.goalsByTeam[team]
        or game.goalPhysics or game.goal
end

local function homeTeam(player)
    return player.team or 1
end

local function opposition(game, player)
    return game.teams and game.teams[3 - homeTeam(player)] or {}
end

local function teamIDs(game, player, options)
    return options and options.ids or game.teams and game.teams[homeTeam(player)]
end

local function wideThreshold(game)
    return game.field and math.max(4.4, game.field.halfWidth * .20) or 3.15
end

local function behindGoalSlot(game, player)
    if player.role == "X" or player.name == "X" then return true end
    local goal = game.goalsByTeam and game.goalsByTeam[homeTeam(player)]
    return goal and player.homeZ and (player.homeZ - goal.z) * (goal.attackSign or sign(goal.z)) > .65
end

local function usableTarget(game, from, to, options)
    return to and from ~= to and homeTeam(from) == homeTeam(to) and to.role ~= "G"
        and (not options.excluded or not options.excluded[to.id])
end

function Tactics.opponentSpace(game, player)
    local distance, nearest = math.huge, nil
    for _, id in ipairs(opposition(game, player)) do
        local defender = game.squad[id]
        if defender.role ~= "G" then
            local gap = length(defender.x - player.x, defender.z - player.z)
            if gap < distance then distance, nearest = gap, id end
        end
    end
    return distance, nearest
end

function Tactics.defender(game, userID)
    local player = game.squad[userID]
    if not player then return nil end
    local gap, nearest = Tactics.opponentSpace(game, player)
    local tactics = game.ai and game.ai.tactics
    local defense = tactics and tactics[3 - homeTeam(player)]
    local primary = defense and defense.primary and game.squad[defense.primary]
    if primary then
        local assignedGap = length(primary.x - player.x, primary.z - player.z)
        if assignedGap <= gap + 1.15 then return primary.id, assignedGap end
    end
    return nearest, gap
end

function Tactics.laneRisk(game, from, to)
    local x, z = to.x - from.x, to.z - from.z
    local span = x * x + z * z
    if span < .001 then return math.huge end
    local risk = 0
    for _, id in ipairs(opposition(game, from)) do
        local defender = game.squad[id]
        local fraction = clamp(((defender.x - from.x) * x + (defender.z - from.z) * z) / span, 0, 1)
        if fraction > .07 then
            local anticipation = fraction * .24
            local dx = defender.x + (defender.vx or 0) * anticipation - (from.x + fraction * x)
            local dz = defender.z + (defender.vz or 0) * anticipation - (from.z + fraction * z)
            risk = math.max(risk, (2.3 - length(dx, dz)) * (fraction > .9 and .85 or 1))
        end
    end
    return risk
end

local function phaseTime(game, detail)
    return (game.elapsed or 0) <= (detail.untilTime or detail.expires or 0)
end

local function cutDetails(game, detail, from, goal, front, width, fromID, ids)
    local target = game.squad[detail.target]
    local gx = goal.x or 0
    local half = game.field and game.field.halfWidth - 1 or 7.6
    if detail.call == "PASS DOWN" then
        local targetDepth = (target.z - goal.z) * front
        local fromDepth = (from.z - goal.z) * front
        local crease = game.field and game.field.creaseRadius or 2.1
        detail.cutID = fromID
        detail.cutX = gx + detail.side * math.min(1.9, width * .39)
        detail.cutZ = goal.z + clamp(targetDepth + 1.25, crease + .95, math.max(crease + .95, fromDepth - .8)) * front
    elseif detail.call == "CLEAR" then
        local cut, best = nil, math.huge
        for i = 1, #ids do
            local id = ids[i]
            local player = game.squad[id]
            local depth = (player.z - goal.z) * front
            local offset = math.abs(player.x - gx)
            if id ~= detail.target and id ~= fromID and player.role ~= "G"
                    and not behindGoalSlot(game, player) and depth > .65 and offset < width then
                local score = offset + depth * .28
                if score < best then cut, best = id, score end
            end
        end
        if cut then
            local player = game.squad[cut]
            local depth = (player.z - goal.z) * front
            local crease = game.field and game.field.creaseRadius or 2.1
            detail.cutID = cut
            detail.cutX = gx - detail.side * math.min(half, width * 1.45)
            detail.cutZ = goal.z + math.max(crease + .7, depth - 1.65) * front
        end
    end
end

local function candidateIDs(game, from, options)
    local ids = teamIDs(game, from, options)
    if ids then return ids end
    ids = {}
    for id in ipairs(game.squad) do ids[#ids + 1] = id end
    return ids
end

function Tactics.choose(game, fromID, call, options)
    options = options or {}
    local from = game.squad[fromID]
    if not from then return nil end
    call = tostring(call or "SAFE"):upper():gsub("_", " ")
    if call == "PICK DOWN" then
        local pick = Tactics.pick(game, fromID, options.defender, options)
        return pick and pick.screener, pick
    end
    local goal = attackGoal(game, homeTeam(from), options)
    if not goal then return nil end
    local gx = goal.x or 0
    local front = goal.attackSign and -goal.attackSign or goal.z < 0 and 1 or -1
    local fromDepth, fromX = (from.z - goal.z) * front, from.x - gx
    local width = options.minWidth or wideThreshold(game)
    local side = options.side or (math.abs(fromX) > width * .48 and sign(fromX) or nil)
    local swing = game.tactical
    local continuation = call == "SWING" and swing and swing.call == "SWING"
        and swing.target == fromID and phaseTime(game, swing)
    local previous = options.previous or continuation and swing.from
    local direction = options.direction or continuation and swing.swingDirection or (fromX > 0 and -1 or 1)
    local angle = atan2(fromX, fromDepth)
    local ids = candidateIDs(game, from, options)
    local best, detail, rating = nil, nil, -math.huge
    for _, id in ipairs(ids) do
        local to = game.squad[id]
        if id ~= fromID and id ~= previous and usableTarget(game, from, to, options) then
            local offset, depth = to.x - gx, (to.z - goal.z) * front
            local distance = length(to.x - from.x, to.z - from.z)
            local gain = fromDepth - depth
            local outside = math.abs(offset) >= width and depth > .65 and not behindGoalSlot(game, to)
            local eligible = distance >= (call == "NEAREST" and .01 or 1.35)
                and distance <= (options.maxDistance or (game.field and 36 or 17))
            if call == "CLEAR" then
                eligible = eligible and outside and (not options.side or offset * options.side > 0)
            elseif call == "PASS DOWN" then
                eligible = eligible and outside and gain >= 1.2 and fromDepth > 1
                    and (not side or offset * side > 0)
            elseif call == "SWING" then
                local aroundX = depth < -.6 and behindGoalSlot(game, to)
                eligible = eligible and (math.abs(offset) >= width * .70 or aroundX)
            end
            if eligible then
                local space = Tactics.opponentSpace(game, to)
                local risk = Tactics.laneRisk(game, from, to)
                local score = 5.8 - math.abs(distance - 10) * .12 - risk * 2.6
                    + math.min(space, 7) * .38 + clamp(gain, -9, 15) * .12
                if call == "CLEAR" then
                    eligible = space >= 2.1 and risk < 1.10
                    score = score + math.min(math.abs(offset), 14) * .11
                    if from.role == "G" then score = score + clamp(gain, -12, 24) * .16 end
                elseif call == "PASS DOWN" then
                    eligible = space >= 1.5 and risk < 1.35
                    score = score + math.min(gain, 13) * .19
                elseif call == "SWING" then
                    local step = (atan2(offset, depth) - angle) * direction % turn
                    eligible = step >= .13 and step <= math.pi * 1.02 and risk < 1.65
                    score = 8.15 - step * 2.9 - math.abs(distance - 10) * .10
                        + math.min(space, 7) * .26 - risk * 2.9
                elseif call == "NEAREST" then
                    score = -distance
                else
                    local goalDistance = length(offset, depth)
                    if from.role == "G" then
                        score = score + math.min(math.abs(offset), 15) * .08 + clamp(gain, -12, 24) * .16
                    elseif goalDistance < 14 then
                        score = score + 1.5 - goalDistance * .06
                    end
                end
                if eligible and score > rating then
                    best, rating = id, score
                    detail = {target=id, from=fromID, side=sign(offset), downfield=gain,
                        laneRisk=risk, space=space, score=score, call=call, team=homeTeam(from)}
                end
            end
        end
    end
    if detail then
        if call == "SWING" then detail.swingDirection = direction end
        cutDetails(game, detail, from, goal, front, width, fromID, ids)
        local delay = call == "CLEAR" and 2.6 or call == "PASS DOWN" and 2.4 or 3.2
        detail.untilTime = (game.elapsed or 0) + (options.duration or delay)
    end
    return best, detail
end

function Tactics.activate(game, detail, call, team, seconds)
    if not detail then return end
    detail.call, detail.team = call or detail.call, team or detail.team
    if seconds then detail.untilTime = (game.elapsed or 0) + seconds end
    game.tactical = detail
    return detail
end

function Tactics.activeCut(game)
    local detail = game.tactical or game.cut
    if not detail then return nil end
    local carrier = game.carrier and game.squad[game.carrier]
    local flight = game.flight
    local passer = flight and flight.kind == "pass" and game.squad[flight.from]
    local team = carrier and homeTeam(carrier) or passer and homeTeam(passer)
    if not phaseTime(game, detail) or game.loose or (team and team ~= detail.team)
            or game.phase and game.phase ~= "LIVE" then
        if game.tactical == detail then game.tactical = nil end
        if game.cut == detail then game.cut = nil end
        if game.mode == detail.call then game.mode = "SET" end
        return nil
    end
    if not detail.cutID or detail.cutID == game.carrier or detail.cutID == (game.flight and flight.to) then
        return nil
    end
    return detail
end

function Tactics.pick(game, userID, defenderID, options)
    options = options or {}
    local user = game.squad[userID]
    if not user or user.role == "G" then return nil end
    local goal = attackGoal(game, homeTeam(user), options)
    if not goal then return nil end
    defenderID = defenderID or Tactics.defender(game, userID)
    local defender = defenderID and game.squad[defenderID]
    if defender and homeTeam(defender) == homeTeam(user) then return nil end
    local goalX = goal.x or 0
    local fx, fz = unit(goalX - user.x, goal.z - user.z)
    if fx == 0 and fz == 0 then return nil end
    local side = options.side or (user.x > goalX and -1 or 1)
    local px, pz
    if defender then
        local ux, uz = unit(user.x - defender.x, user.z - defender.z)
        if ux == 0 and uz == 0 then ux, uz = -fx, -fz end
        px, pz = defender.x + ux * 1.22 - uz * side * .52,
            defender.z + uz * 1.22 + ux * side * .52
    else
        px, pz = user.x + fx * 1.55 - fz * side * .95, user.z + fz * 1.55 + fx * side * .95
    end
    if game.field then
        px = clamp(px, -game.field.halfWidth + 1.2, game.field.halfWidth - 1.2)
        pz = clamp(pz, -game.field.halfLength + 1.2, game.field.halfLength - 1.2)
    else
        px, pz = clamp(px, -7.7, 7.7), clamp(pz, -15.8, 14.8)
    end
    local ids = candidateIDs(game, user, options)
    local selected, best = nil, math.huge
    for _, id in ipairs(ids) do
        local player = game.squad[id]
        if id ~= userID and usableTarget(game, user, player, options)
                and (not options.screener or id == options.screener) and (id ~= game.controlled or options.screener) then
            local distance = length(player.x - px, player.z - pz)
            local limit = options.screener and 12 or game.field and 8.4 or 7.4
            if distance <= limit then
                local roleCost = player.role == "D" and 2.5 or 0
                if distance + roleCost < best then selected, best = id, distance + roleCost end
            end
        end
    end
    if not selected then return nil end
    return {
        screener=selected, user=userID, defender=defenderID, x=px, z=pz, side=side,
        release=options.release or (length(px - goalX, pz - goal.z) >= 13 and "pop" or "roll"),
        goalX=goalX, goalZ=goal.z, call="PICK DOWN", team=homeTeam(user),
        untilTime=(game.elapsed or 0) + 3.3
    }
end
end

-- Screens
do
-- PolyLax Build 013 | Planted screens and roll/pop releases
PolyLax = PolyLax or {}
local P = PolyLax
local Screens = {}
P.Screens = Screens

local minPlant, stopSpeed = .14, .24
local approvalWindow = 2.8

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function direction(x, z, fallbackX, fallbackZ)
    local span = length(x, z)
    if span < .001 then return fallbackX or 0, fallbackZ or -1 end
    return x / span, z / span
end

local function speed(actor)
    return math.max(actor.speed or 0, length(actor.vx or 0, actor.vz or 0))
end

local function attribute(player, key, fallback)
    return clamp(P.Attributes.unit(player,key,fallback),.05,1)
end

local function frame(time, grip, shaft, torso, crouch, roll)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll or 0, freeHand=0}
end

function Screens.registerAnimations()
    local clips = P.AnimationController.clips
    if clips.screenPlant then return end
    local function plant(time, bend)
        return frame(time, vec3(.042,.67,-.29), vec3(.021,.99,-.085),
            vec3(bend,0,0), .075, 0)
    end
    clips.screenPlant = {duration=2.45, poses={plant(.13,-3), plant(.27,-1), plant(2.32,-1)}}
    clips.screenRoll = {
        duration=.36, eventTime=.12, event="screenRelease",
        poses={frame(.11,vec3(.12,.60,-.29),vec3(.25,.94,-.10),vec3(-5,16,5),.048,8),
            frame(.24,vec3(.27,.69,-.22),vec3(.65,.73,-.10),vec3(-8,-9,0),.015,-8)}
    }
    clips.screenPop = {
        duration=.36, eventTime=.12, event="screenRelease",
        poses={frame(.12,vec3(.13,.74,-.33),vec3(.25,.96,-.07),vec3(-3,-10,-4),.030,-9),
            frame(.24,vec3(.29,.79,-.29),vec3(.57,.78,-.09),vec3(1,7,3),.012,8)}
    }
end

local function limitPoint(game, x, z)
    local field = game.field
    local width = field and field.halfWidth or 9
    local lengthZ = field and field.halfLength or 17
    return clamp(x, -width + .65, width - .65), clamp(z, -lengthZ + .75, lengthZ - .75)
end

local function goalCoordinates(game, player, options)
    local goal = game.goalsByTeam and game.goalsByTeam[player.team] or game.goal
    return options.goalX or (goal and goal.x) or 0, options.goalZ or (goal and goal.z) or -13
end

local function releasePose(game, screen, player, moveX, moveZ)
    local style = screen.style
    local forwardX, forwardZ = direction(screen.goalX - player.x, screen.goalZ - player.z)
    local x, z
    if length(moveX or 0, moveZ or 0) > .25 then
        local ux, uz = direction(moveX, moveZ)
        style = ux * forwardX + uz * forwardZ > .36 and "roll" or "pop"
        local span = style == "roll" and 4.7 or 4.0
        x, z = player.x + ux * span, player.z + uz * span
    elseif style == "pop" then
        x = player.x - forwardX * 1.12 - forwardZ * screen.side * 3.8
        z = player.z - forwardZ * 1.12 + forwardX * screen.side * 3.8
    else
        x = player.x + forwardX * 4.9 - forwardZ * screen.side * 1.0
        z = player.z + forwardZ * 4.9 + forwardX * screen.side * 1.0
    end
    x, z = limitPoint(game, x, z)
    return x, z, style
end

local function stopPlant(player)
    local anim = player and player.anim
    if anim and anim.action == "screenPlant" then
        anim.action, anim.entry = nil, nil
    end
end

function Screens.reset(game)
    if game.screen then stopPlant(game.squad[game.screen.screener]) end
    game.screen, game.screenCredit, game.screenShotCredit = nil, nil, nil
end

function Screens.request(game, screenerId, userId, defenderId, options)
    if game.screen or game.phase and game.phase ~= "LIVE" then return nil, "busy" end
    options = options or {}
    if game.humans and game.humans[screenerId] and not options.manual then
        return nil, "human screener must set the pick"
    end
    local screener, user = game.squad[screenerId], game.squad[userId]
    local defender = defenderId and game.squad[defenderId]
    if not screener or not user or screener == user or screener.role == "G"
        or game.carrier == screenerId or screener.team and user.team and screener.team ~= user.team then
        return nil, "invalid screener"
    end
    if defenderId and (not defender or defender == user or defender == screener
        or defender.role == "G" or user.team and defender.team == user.team) then
        return nil, "invalid defender"
    end
    local goalX, goalZ = goalCoordinates(game, user, options)
    local fx, fz = direction(goalX - user.x, goalZ - user.z)
    local side = options.side or (screener.x < user.x and -1 or 1)
    side = side >= 0 and 1 or -1
    local x, z
    if defender then
        local ux, uz = direction(user.x - defender.x, user.z - defender.z, -fx, -fz)
        x = defender.x + ux * 1.22 - uz * side * .52
        z = defender.z + uz * 1.22 + ux * side * .52
    else
        x, z = user.x + fx * 1.9 - fz * side * 1.35, user.z + fz * 1.9 + fx * side * 1.35
    end
    x, z = limitPoint(game, options.x or x, options.z or z)
    local faceX, faceZ = direction(user.x - x, user.z - z, -fx, -fz)
    local screen = {
        screener=screenerId, user=userId, defender=defenderId, team=user.team,
        x=x, z=z, faceX=faceX, faceZ=faceZ, goalX=goalX, goalZ=goalZ,
        side=side, style=options.release == "pop" and "pop" or "roll",
        phase="APPROACH", age=0, phaseTime=0, planted=0, unpossessed=0,
        contact=false, effective=false, realDefender=defender ~= nil,
        manual=options.manual == true
    }
    if defender then
        screen.previous = {sx=screener.x,sz=screener.z,dx=defender.x,dz=defender.z}
    end
    game.screen = screen
    return screen
end

function Screens.release(game, id, moveX, moveZ)
    local screen = game.screen
    if not screen or screen.screener ~= id or screen.phase == "RELEASE" then return false end
    local player = game.squad[id]
    local lastPose = player.anim and player.anim.lastPose
    stopPlant(player)
    screen.releaseX, screen.releaseZ, screen.style = releasePose(game, screen, player, moveX, moveZ)
    screen.phase, screen.phaseTime = "RELEASE", 0
    if player.anim then
        local clip = screen.style == "roll" and "screenRoll" or "screenPop"
        if P.AnimationController.play(player.anim, clip) then player.anim.entry = lastPose end
    end
    return true
end

-- A quick button tap queues a complete plant. A hold gives the player
-- direct control over when the planted athlete rolls or pops.
function Screens.endHold(game,id,moveX,moveZ)
    local screen = game.screen
    if screen and screen.screener==id and screen.manual
        and (screen.phase=="APPROACH" or screen.phase=="PLANT") then
        screen.manual = false
        screen.exitX,screen.exitZ = moveX,moveZ
        return true
    end
    return Screens.release(game,id,moveX,moveZ)
end

local function manualMovement(game, id)
    local input = game.humans and game.humans[id]
    if input then return length(input.x or 0,input.z or 0)>.25 end
    return game.controlled == id and length(game.moveX or 0, game.moveZ or 0) > .25
end

local function copyIntent(intent)
    local copy = {}
    for key, value in pairs(intent or {}) do copy[key] = value end
    return copy
end

function Screens.intent(game, playerId, intent)
    local screen = game.screen
    if not screen then return intent end
    if playerId == screen.screener then
        if (screen.phase == "PLANT" or screen.phase == "HOLD") and manualMovement(game, playerId) then
            return intent
        end
        intent = copyIntent(intent)
        intent.screenControl = true
        if screen.phase == "RELEASE" then
            intent.x, intent.z, intent.speed = screen.releaseX, screen.releaseZ,
                screen.style == "roll" and 6.4 or 5.6
            local user = game.squad[screen.user]
            if screen.style == "pop" then intent.lookX, intent.lookZ = user.x, user.z
            else intent.lookX, intent.lookZ = screen.releaseX, screen.releaseZ end
        else
            intent.x, intent.z = screen.x, screen.z
            intent.speed = screen.phase == "APPROACH" and 4.8 or 0
            local player = game.squad[playerId]
            intent.lookX, intent.lookZ = player.x + screen.faceX, player.z + screen.faceZ
        end
        return intent
    end
    if playerId == screen.defender and (screen.dragTime or 0) > 0 then
        intent = copyIntent(intent)
        local strength = math.min(1, screen.dragTime / .20)
        intent.screenDrag = 1 - screen.dragStrength * strength
        if game.controlled ~= playerId and not (game.humans and game.humans[playerId]) then
            if screen.escapeX then intent.x, intent.z = screen.escapeX, screen.escapeZ end
            intent.speed = (intent.speed or 7.2) * intent.screenDrag
        end
        return intent
    end
    return intent
end

local function actorShape(player)
    local scale = player.rig and player.rig.proportions and player.rig.proportions.scale
    return scale and scale.x or 1
end

local function approachContact(screen, player, guard)
    local prev = screen.previous
    local x0, z0 = prev.dx - prev.sx, prev.dz - prev.sz
    local x1, z1 = guard.x - player.x, guard.z - player.z
    local vx, vz = x1 - x0, z1 - z0
    local fraction = clamp(-(x0*vx + z0*vz) / math.max(vx*vx + vz*vz,.000001), 0, 1)
    local x, z = x0 + vx * fraction, z0 + vz * fraction
    local span = length(x, z)
    local yaw = math.rad(player.yaw or 0)
    local ux, uz = direction(x, z, 1, 0)
    local lateral = math.cos(yaw) * ux - math.sin(yaw) * uz
    local depth = math.sin(yaw) * ux + math.cos(yaw) * uz
    local width = actorShape(player) * math.sqrt((.405*lateral)^2 + (.25*depth)^2)
    local close = span <= width + actorShape(guard) * .31
    local previousGap, currentGap = length(x0,z0), length(x1,z1)
    local closing = previousGap - span > .003 or currentGap < previousGap - .003
    local initiator = (player.x-prev.sx)*ux + (player.z-prev.sz)*uz > .009
    prev.sx, prev.sz, prev.dx, prev.dz = player.x, player.z, guard.x, guard.z
    return close, closing, initiator
end

local function stanceIssue(actor, guard)
    local anim, rig = actor.anim, actor.rig
    local pose = anim and anim.lastPose
    if pose and (math.abs(pose.torso.x) > 13 or math.abs(pose.torso.z) > 11) then
        return "leaning into the defender"
    end
    if not rig or not rig.body or not rig.joints or not rig.stickRoot then return end
    local body, joints = rig.body, rig.joints
    local left, right = joints.leftAnkle.worldPosition, joints.rightAnkle.worldPosition
    local span = length(left.x - right.x, left.z - right.z)
    local shoulder = joints.rightShoulder.position.x - joints.leftShoulder.position.x
    if span > (shoulder + .05) * actorShape(actor) then return "wide stance" end
    local function outside(point, radius)
        local localPoint = body:inverseTransformPoint(point)
        if math.abs(localPoint.x) > shoulder * .57 or math.abs(localPoint.z) > .67 then
            local near = length(point.x - guard.x, point.z - guard.z)
            return near < radius and point.y > .32 and point.y < 2.38
        end
    end
    for _, ordinate in ipairs({-.82, 0, .79, 1.02}) do
        if outside(rig.stickRoot:transformPoint(vec3(0, ordinate, 0)), .48) then
            return "stick outside the body frame"
        end
    end
    if outside(joints.leftWrist.worldPosition, .44) or outside(joints.rightWrist.worldPosition, .44) then
        return "arms outside the body frame"
    end
end

local function meta(screen, reason)
    return {screener=screen.screener, user=screen.user, defender=screen.defender,
        release=screen.style, reason=reason}
end

local function record(callbacks, screen, key, reason)
    if callbacks and callbacks.stat then callbacks.stat(screen.screener, key, meta(screen, reason)) end
end

local function registerContact(game, screen, screener, user, defender, callbacks, mature)
    local close, closing, initiator = approachContact(screen, screener, defender)
    local issue
    if close or length(defender.x-screener.x,defender.z-screener.z) < 1.48 then
        issue = stanceIssue(screener, defender)
    end
    local gearHit = issue == "stick outside the body frame" or issue == "arms outside the body frame"
    local firstGearHit = gearHit and not screen.gearTouching
    local alreadyTouching = screen.touching
    screen.gearTouching, screen.touching = gearHit, close
    if not close and not gearHit then return end
    local moving = speed(screener) > stopSpeed or screener.dodge or screener.check
    if screen.phase == "RELEASE" and (alreadyTouching or not initiator) then return end
    if screen.contact and not (initiator and moving) and not firstGearHit then return end
    if not closing and not initiator and not firstGearHit then return end
    if moving or not mature or issue then
        local reason = moving and "moving pick" or issue or "contact before the plant"
        record(callbacks, screen, "illegalScreens", reason)
        stopPlant(screener)
        game.screen, game.screenCredit = nil, nil
        if callbacks and callbacks.foul then callbacks.foul(screen.screener, screen.defender, meta(screen, reason)) end
        return
    end

    screen.contact = true
    screen.contactTime = screen.age
    screen.dragTime = .10 + .82 * clamp(.42 + .56 * (attribute(screener,"strength",.64)
        - attribute(defender,"reaction",.67)), .05, .87)
    screen.dragStrength = clamp(.52 + .60 * (attribute(screener,"strength",.64)
        - attribute(defender,"strength",.60)), .24, .80)
    if defender.vx and defender.vz then
        local retention = 1 - screen.dragStrength * .48
        defender.vx, defender.vz = defender.vx * retention, defender.vz * retention
        defender.speed = length(defender.vx, defender.vz)
    end
    screen.contactGap = length(user.x-defender.x,user.z-defender.z)
    screen.userX, screen.userZ = user.x, user.z
    local ux, uz = direction(user.x-defender.x,user.z-defender.z)
    screen.escapeX, screen.escapeZ = limitPoint(game, screener.x - uz * screen.side * 1.55 + ux * .65,
        screener.z + ux * screen.side * 1.55 + uz * .65)
    record(callbacks, screen, "screens", "legal planted contact")
end

local function samePossession(game, screen)
    local owner = game.carrier and game.squad[game.carrier]
    if owner then
        if screen.team and owner.team then return owner.team == screen.team end
        return game.carrier ~= screen.screener
    end
    return game.flight ~= nil and not game.loose
        and (not screen.team or not game.flight.team or game.flight.team == screen.team)
end

local function updateCredit(game, dt)
    local credit = game.screenCredit
    if credit then
        local holder = game.carrier and game.squad[game.carrier]
        credit.time = credit.time - dt
        if credit.time <= 0 or (holder and credit.team and holder.team ~= credit.team) then
            game.screenCredit = nil
        end
    end
    local shot = game.screenShotCredit
    if shot then
        shot.time = shot.time - dt
        if shot.time <= 0 then game.screenShotCredit = nil end
    end
end

function Screens.update(game, dt, callbacks)
    updateCredit(game, dt)
    local screen = game.screen
    if not screen then return end
    local actor, user = game.squad[screen.screener], game.squad[screen.user]
    if game.carrier == screen.screener then
        stopPlant(actor)
        game.screen = nil
        return
    end
    screen.age, screen.phaseTime = screen.age + dt, screen.phaseTime + dt
    screen.unpossessed = samePossession(game, screen) and 0 or screen.unpossessed + dt
    if screen.unpossessed > .21 or screen.age > 5.25 then
        stopPlant(actor)
        game.screen = nil
        return
    end

    local drift = length(actor.x-screen.x,actor.z-screen.z)
    local mature = screen.phase == "HOLD" and screen.planted >= minPlant
    if screen.phase == "APPROACH" and drift <= .28 and speed(actor) <= .65 then
        screen.phase, screen.phaseTime = "PLANT", 0
        if actor.anim then P.AnimationController.play(actor.anim, "screenPlant") end
    end
    if screen.phase == "PLANT" or screen.phase == "HOLD" then
        local set = speed(actor) <= stopSpeed and drift <= .31 and not actor.dodge and not actor.check
        if actor.anim and actor.anim.action ~= "screenPlant" then
            set = set and P.AnimationController.play(actor.anim, "screenPlant")
        end
        screen.planted = set and screen.planted + dt or 0
        if screen.phase == "PLANT" and screen.planted >= minPlant then
            screen.phase, screen.phaseTime = "HOLD", 0
        end
        mature = mature and set
    end

    local defender = screen.defender and game.squad[screen.defender]
    if defender then
        if screen.dragTime then screen.dragTime = math.max(0, screen.dragTime - dt) end
        registerContact(game, screen, actor, user, defender, callbacks, mature)
        if game.screen ~= screen then return end
        if screen.contact and not screen.effective and screen.age - screen.contactTime <= .76 then
            local separation = length(user.x-defender.x,user.z-defender.z)
            if separation >= math.max(1.42, screen.contactGap + .38)
                and length(user.x-screen.userX,user.z-screen.userZ) >= .32 then
                screen.effective = true
                game.screenCredit = {screener=screen.screener,user=screen.user,defender=screen.defender,
                    team=screen.team,time=approvalWindow,metadata=meta(screen,"screen opened a lane")}
            end
        end
    end

    local automatic = not screen.manual and (screen.phaseTime >= .82
        or screen.effective and screen.phaseTime >= .27)
    local receiving = game.pending and game.pending.to == screen.screener
        or game.flight and game.flight.to == screen.screener
    if screen.phase ~= "RELEASE" and receiving then
        Screens.release(game, screen.screener)
    elseif screen.phase == "HOLD" and (automatic or screen.phaseTime >= 1.8) then
        Screens.release(game,screen.screener,screen.exitX,screen.exitZ)
    elseif screen.phase == "RELEASE" and (screen.phaseTime >= 1.15
        or length(actor.x-screen.releaseX,actor.z-screen.releaseZ) < .30) then
        game.screen = nil
    elseif screen.phase == "APPROACH" and screen.phaseTime >= 3.9 then
        game.screen = nil
    end
end

local function nearestPressure(game, shooter)
    local nearest = math.huge
    for _, player in ipairs(game.squad) do
        if player.team ~= shooter.team and player.role ~= "G" then
            nearest = math.min(nearest, length(player.x-shooter.x,player.z-shooter.z))
        end
    end
    return nearest
end

function Screens.creditShot(game, shooterId, stat, flight)
    local credit = game.screenCredit
    if not credit or credit.user ~= shooterId or credit.time <= 0 then return false end
    if nearestPressure(game, game.squad[shooterId]) < 1.42 then return false end
    game.screenCredit = nil
    game.screenShotCredit = {screener=credit.screener,user=shooterId,time=2.9,
        metadata=credit.metadata,flight=flight}
    if stat then stat(credit.screener, "screenOpenShots", credit.metadata) end
    return true
end

function Screens.creditGoal(game, shooterId, stat, flight)
    local shot = game.screenShotCredit
    if not shot or shot.user ~= shooterId or shot.time <= 0 or (shot.flight and shot.flight ~= flight) then
        return false
    end
    game.screenShotCredit = nil
    if stat then stat(shot.screener, "screenAssists", shot.metadata) end
    return true
end
end

-- League
do
-- PolyLax 2.0 | Competition profiles, stable rosters, schedules, and CPU box scores
PolyLax = PolyLax or {}
local P = PolyLax
local League = {}
P.League = League

-- Each competition is a condensed PolyLax format. School/PLL identities do not
-- imply that the game uses the organization's official fixtures or tournament rules.
League.profiles = {
    highSchool={id="high-school", name="High School", conference="PolyLax Scholastic League",
        rosterGroup="highSchool", qualified=4, periods=4, minutes=12, pace=30},
    ncaa={id="ncaa-d1", name="NCAA Division I", conference="PolyLax D1 Pool",
        rosterGroup="ncaa", qualified=8, periods=4, minutes=15, pace=38},
    club={id="mcla-club", name="College Club", conference="PolyLax Club League",
        rosterGroup="clubLeague", qualified=2, periods=4, minutes=15, pace=35},
    professional={id="pro", name="Professional", conference="PolyLax Pro League",
        rosterGroup="pll", qualified=6, periods=4, minutes=12, pace=41}
}

function League.profile(stage, teamId)
    if stage == "college" then
        local team = P.SchoolTeams.get(teamId)
        return team and team.group == "club" and League.profiles.club or League.profiles.ncaa
    end
    return League.profiles[stage] or League.profiles.highSchool
end

function League.teams(profile)
    if profile.rosterGroup == "pll" then return P.TeamUniform.teams end
    return P.SchoolTeams[profile.rosterGroup]
end

local givenNames = {"Avery","Blake","Brooks","Cameron","Casey","Cole","Drew","Eli","Emmett",
    "Finn","Hayden","Jaden","Jordan","Jules","Kai","Logan","Luca","Miles","Morgan","Nico",
    "Owen","Quinn","Reed","Remy","Rory","Sam","Shay","Tate","Theo","Wes"}
local familyNames = {"Alden","Archer","Avery","Bennett","Blaine","Byrne","Carter","Chen","Clarke",
    "Collins","Corbett","Dawson","Ellis","Foster","Grant","Han","Hayes","Holt","Keller","Kim",
    "Lane","Lowe","Marin","Mercer","Nolan","Parks","Patel","Quill","Reyes","Sato","Shaw",
    "Sloan","Stone","Vega","Wells","Wong","Young","Yu"}
local slots = {{"A",11},{"A",12},{"A",13},{"M",20,"FOGO"},{"M",21},{"M",22},
    {"D",30},{"D",31},{"D",32},{"G",1}}
local rosters = {}

local function hash(text)
    local state = 137
    for index=1,#text do state = (state*257 + text:byte(index)) % 2147483647 end
    return math.max(1,state)
end

local function randomSource(text)
    local state = hash(text)
    return function()
        state = state * 48271 % 2147483647
        return state / 2147483647
    end
end

function League.teamKey(teamId)
    local team = P.TeamUniform.get(teamId)
    return type(team.id) == "number" and ("pll-"..team.id) or team.id
end

function League.playerId(teamId, slot)
    return League.teamKey(teamId)..":"..slot
end

function League.roster(teamId)
    local team = P.TeamUniform.get(teamId)
    local key = League.teamKey(team.id)
    if rosters[key] then return rosters[key] end
    local roster, usedNames = {}, {}
    for slot, spec in ipairs(slots) do
        local id = League.playerId(team.id,slot)
        local roll = randomSource(id)
        local name
        repeat
            name = givenNames[math.floor(roll()*#givenNames)+1].." "..
                familyNames[math.floor(roll()*#familyNames)+1]
        until not usedNames[name]
        usedNames[name] = true
        roster[slot] = {playerId=id, name=name, number=spec[2], role=spec[1], specialty=spec[3],
            teamId=team.id, slot=slot, rating=58+math.floor(roll()*28),
            debutSeason=type(team.id) == "number" and (3+hash(id..":entry")%5) or nil}
    end
    rosters[key] = roster
    return roster
end

function League.venue(teamId)
    local team = P.TeamUniform.get(teamId)
    return {id=League.teamKey(team.id)..":home", name=team.name.." Home Field", teamId=team.id,
        theme=team.field}
end

function League.team(teamId)
    local team = P.TeamUniform.get(teamId)
    local stage = type(team.id) == "number" and "professional"
        or team.group == "highSchool" and "highSchool" or "college"
    local competition = League.profile(stage,team.id)
    return {id=team.id, key=League.teamKey(team.id), name=team.name, short=team.short,
        competition=competition.id, conference=competition.conference, home=team.home, away=team.away,
        venue=League.venue(team.id), roster=League.roster(team.id)}
end

function League.schedule(profile, season)
    local wheel, ranks, rounds = {}, {}, {}
    for index, team in ipairs(League.teams(profile)) do
        wheel[index], ranks[team.id] = team.id, index
    end
    local size = #wheel
    if size % 2 > 0 then wheel[#wheel+1] = false end
    for week=1,#wheel-1 do
        local games = {}
        for index=1,math.floor(#wheel*.5) do
            local home, away = wheel[index], wheel[#wheel+1-index]
            if home and away then
                local gap = (ranks[away]-ranks[home]) % size
                local swap = gap > math.floor(size/2)
                    or size % 2 == 0 and gap == size/2 and ranks[home] > ranks[away]
                if swap == (season % 2 == 1) then home, away = away, home end
                games[#games+1] = {home=home,away=away}
            end
        end
        rounds[week] = games
        table.insert(wheel,2,table.remove(wheel))
    end
    return rounds
end

local function increment(line, key, amount)
    line[key] = (line[key] or 0) + (amount or 1)
end

local offense = {1,2,3,5,6,1,2,3,5,6,1,2,3,4,7}
local attack = {1,1,1,2,2,2,3,3,3,5,5,6,6,4,7}
local defense = {7,7,8,8,9,9,5,6,4}

local function pick(roll, pool)
    return pool[math.floor(roll()*#pool)+1]
end

local function makeSide(box, profile, teamId, season)
    local side = {id=teamId, lines={}, roster={}, score=0}
    local clock = profile.minutes * profile.periods * 60
    for index, player in ipairs(League.roster(teamId)) do
        local time = player.role == "G" and clock or math.floor(clock * (.55 + player.rating*.004))
        local line = {playerId=player.playerId, teamId=teamId, role=player.role, name=player.name,
            number=player.number, slot=index, stats={gamesPlayed=1,gamesStarted=1,secondsPlayed=time,
                minutesPlayed=time/60}, rookie=player.debutSeason and player.debutSeason == season or nil}
        box.players[player.playerId] = line
        side.lines[index], side.roster[index] = line.stats, player.playerId
    end
    return side
end

local function possession(roll, side, opposing, efficiency)
    local facilitator, shooter = pick(roll,offense), pick(roll,attack)
    local pass = side.lines[facilitator]
    local shot, goalie = side.lines[shooter], opposing.lines[10]
    local defenders = opposing.lines[pick(roll,defense)]
    increment(pass,"passes")
    if roll() < .18 - efficiency*.1 then
        increment(pass,"turnovers")
        if roll() < .68 then
            increment(pass,"committedForcedTurnovers")
            increment(defenders,"causedTurnovers")
            increment(defenders,"checks")
            if roll() < .35 then increment(defenders,"interceptions") end
        else
            increment(pass,"unforcedTurnovers")
        end
        increment(defenders,"groundBalls")
        return
    end
    increment(pass,"completions")
    if roll() < .30 then increment(side.lines[pick(roll,offense)],"groundBalls") end
    if roll() < .21 then return end
    increment(shot,"shots")
    if roll() > .66 + efficiency*.36 then return end
    increment(shot,"shotsOnGoal")
    increment(goalie,"shotsFaced")
    if roll() > .54 + efficiency*.56 then
        increment(goalie,"saves")
        increment(goalie,"clearsAttempted")
        if roll() < .83 then increment(goalie,"clearsCompleted") end
        return
    end
    side.score = side.score + 1
    increment(shot,"goals")
    increment(goalie,"goalsAllowed")
    if facilitator ~= shooter and roll() < .76 then increment(pass,"assists") end
end

local function sumSide(box, side, opponent)
    local decision = side.score == opponent.score and "ties" or side.score > opponent.score and "wins" or "losses"
    side.lines[10][decision] = 1
    local totals = {}
    local rates = P.Statistics and P.Statistics.rates
    for index, line in ipairs(side.lines) do
        local points = (line.goals or 0) + (line.assists or 0)
        if points > 0 then line.points = points end
        for key,value in pairs(line) do increment(totals,key,value) end
        if rates then box.players[side.roster[index]].rates = rates(line) end
    end
    totals.secondsPlayed,totals.minutesPlayed = box.elapsed,box.elapsed/60
    box.teams[tostring(side.id)] = totals
    return {id=side.id,name=P.TeamUniform.get(side.id).name,roster=side.roster,stats=totals,
        rates=rates and rates(totals)}
end

function League.simulate(profile, game)
    local id, homeId, awayId = game.id, game.homeId, game.awayId
    assert(homeId ~= awayId and id, "Simulated fixtures require distinct teams and a stable ID")
    local roll = randomSource(id.."/"..tostring(homeId).."/"..tostring(awayId))
    local box = {id=id, source="simulated", mode="LEAGUE", final=true,
        elapsed=profile.minutes*profile.periods*60, competition=profile.id, season=game.season,
        stage=game.stage, week=game.week, postseason=game.postseason, venueId=League.venue(homeId).id,
        homeId=homeId, awayId=awayId, players={}, teams={}}
    local home, away = makeSide(box,profile,homeId,game.season), makeSide(box,profile,awayId,game.season)
    local efficiency = (League.roster(homeId)[1].rating-League.roster(awayId)[1].rating)*.006
    local turns = profile.pace + math.floor(roll()*9) - 4
    for _=1,turns do
        possession(roll,home,away,efficiency+.045)
        possession(roll,away,home,-efficiency)
    end
    if game.postseason and home.score == away.score then
        local leading, other = home, away
        if roll() < .48 then leading, other = away, home end
        -- Use a scoring shot and shot-faced event for the deciding goal.
        local scorer = leading.lines[pick(roll,attack)]
        increment(scorer,"shots")
        increment(scorer,"shotsOnGoal")
        increment(scorer,"goals")
        increment(other.lines[10],"shotsFaced")
        increment(other.lines[10],"goalsAllowed")
        leading.score = leading.score+1
    end
    local drawEdge = (League.roster(homeId)[4].rating-League.roster(awayId)[4].rating)*.005
    for _=1,home.score+away.score+profile.periods do
        increment(home.lines[4],"faceoffAttempts")
        increment(away.lines[4],"faceoffAttempts")
        local winner = roll() < .5+drawEdge and home or away
        increment(winner.lines[4],"faceoffsWon")
        increment(winner.lines[4],"groundBalls")
    end
    box.homeScore, box.awayScore = home.score, away.score
    box.sides = {sumSide(box,home,away),sumSide(box,away,home)}
    return box
end
end

-- Statistics
do
-- PolyLax 2.0 | Match and player statistics
PolyLax = PolyLax or {}
local P = PolyLax
local Statistics = {}
P.Statistics = Statistics

local profileKey = "PolyLax.Statistics.2."
local serialKey = profileKey .. "MatchSerial"
local matchSerial
local storedProfiles = {}

local aliases = {faceoffs="faceoffsWon", forcedTurnovers="causedTurnovers"}
local measured = {
    goals=true, assists=true, shots=true, shotsOnGoal=true, saves=true, goalsAllowed=true,
    shotsFaced=true, groundBalls=true, passes=true, completions=true, turnovers=true,
    unforcedTurnovers=true, committedForcedTurnovers=true, causedTurnovers=true,
    interceptions=true, checks=true, pokes=true, slaps=true, bodyChecks=true,
    faceoffAttempts=true, faceoffsWon=true, faceoffViolations=true, faceoffScrambles=true,
    fouls=true, penalties=true, technicalFouls=true, personalFouls=true, penaltySeconds=true,
    clearsAttempted=true, clearsCompleted=true, screens=true, screenAssists=true,
    screenOpenShots=true, illegalScreens=true, screenCoachPoints=true,
    pipeHits=true, blockedShots=true, shotsWide=true, shotsHigh=true, shotsLow=true
}

local function copy(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function increment(values, key, amount)
    values[key] = (values[key] or 0) + amount
end

local function ratio(numerator, denominator)
    if denominator > 0 then return numerator / denominator end
end

local function value(stats, key)
    return stats[key] or 0
end

function Statistics.rates(stats)
    return {
        shootingPct=ratio(value(stats,"goals"),value(stats,"shots")),
        onTargetPct=ratio(value(stats,"shotsOnGoal"),value(stats,"shots")),
        savePct=ratio(value(stats,"saves"),value(stats,"shotsFaced")),
        faceoffPct=ratio(value(stats,"faceoffsWon"),value(stats,"faceoffAttempts")),
        completionPct=ratio(value(stats,"completions"),value(stats,"passes")),
        clearPct=ratio(value(stats,"clearsCompleted"),value(stats,"clearsAttempted")),
        goalsAgainstAvg=ratio(value(stats,"goalsAllowed") * 3600,value(stats,"secondsPlayed"))
    }
end

local function nextId()
    if not matchSerial then
        matchSerial = tonumber(readLocalData and readLocalData(serialKey)) or 0
    end
    matchSerial = matchSerial + 1
    if saveLocalData then pcall(saveLocalData,serialKey,matchSerial) end
    return ("played:%d:%d"):format(os.time(), matchSerial)
end

local function stablePlayerId(teamId, slot, practice)
    if practice then return ("practice:%s:%s"):format(tostring(teamId), tostring(slot)) end
    if P.League and P.League.playerId then return P.League.playerId(teamId, slot) end
    local key = type(teamId) == "number" and ("pll-" .. teamId) or tostring(teamId)
    return ("%s:%s"):format(key, tostring(slot))
end

local function newSide(team, id)
    return {id=id, name=team and team.name or tostring(id), stats={}, roster={}}
end

local function register(statistics, side, id, player, profile)
    local line = {
        playerId=id, teamId=side.id, role=player.role, name=player.name,
        number=player.number or player.rig and player.rig.numberValue, slot=player.slot,
        profile=profile or nil, stats={}
    }
    statistics.players[id] = line
    side.roster[#side.roster+1] = id
    return line
end

function Statistics.new(game, options)
    options = options or {}
    local practice = options.mode == "PRACTICE" or game.homeScore == nil
    local home = game.homeTeam
    local away = game.awayTeam
    local homeId = game.homeId or home and home.id or game.uniform and game.uniform.teamId or options.homeId or "practice"
    local awayId = game.awayId or away and away.id or game.opponentId or options.awayId or "practice-keeper"
    if practice and P.TeamUniform and game.uniform then
        home = P.TeamUniform.get(homeId)
        local keeperKit = P.TeamUniform.forKeeper(game.uniform,game.goalieRole,awayId)
        awayId = keeperKit.teamId
        away = P.TeamUniform.get(awayId)
    end
    local fixture = options.fixture or {}
    local profileId = tostring(options.profileId or "career-player")
    local created = options.profilePlayer or game.careerPlayer or (practice and 1) or 4
    local calendarId = options.fixtureId or fixture.id
    local identity = options.id or calendarId or nextId()
    local statistics = {
        id=identity, mode=options.mode or (practice and "PRACTICE" or game.careerPlayer and "CAREER" or "FULL GAME"),
        source="played", createdAt=os.time(), elapsed=0, players={}, entries={}, events={},
        homeId=homeId, awayId=awayId, sides={newSide(home,homeId),newSide(away,awayId)},
        profileId=profileId, profilePlayer=created, practice=practice,
        fixtureId=calendarId, season=options.season or fixture.season,
        stage=options.stage or fixture.stage, week=options.week or fixture.week,
        postseason=options.postseason or fixture.postseason,
        venueHomeId=fixture.homeId or options.venueHomeId,
        competition=options.competition, venueId=options.venueId
    }
    game.statistics, game.statSummary = statistics, nil
    local rosters
    if not practice and P.League and P.League.roster then
        rosters = {P.League.roster(homeId),P.League.roster(awayId)}
    end
    for i, player in ipairs(game.squad) do
        local side = statistics.sides[player.team or 1]
        local id = stablePlayerId(side.id, player.slot or i, practice)
        local rosterPlayer = rosters and rosters[player.team or 1][player.slot or i] or player
        local line = register(statistics,side,id,rosterPlayer)
        line.number = player.number or line.number
        statistics.entries[i] = {actor=line, team=player.team or 1}
        if i == created then
            local personal = register(statistics,side,profileId,player,true)
            if not game.careerPlayer then
                -- Exhibition and practice use the creator for the whole slot.
                side.roster[#side.roster-1] = personal.playerId
                side.roster[#side.roster] = nil
                statistics.players[line.playerId] = nil
                statistics.entries[i].actor = personal
            end
            statistics.entries[i].profile = personal
        end
    end
    if practice and game.goalie then
        local side = statistics.sides[2]
        local id = stablePlayerId(side.id, "G", true)
        local line = register(statistics,side,id,{name="Practice goalkeeper",role="G",slot=10,
            number=game.goalie.numberValue})
        local index = #game.squad + 1
        statistics.entries[index] = {actor=line,team=2}
        statistics.practiceKeeper = index
    end
    return statistics
end

local function participant(game, playerIndex)
    local statistics = game.statistics
    local entry = statistics and statistics.entries[playerIndex]
    if not entry then return nil end
    if entry.profile and not game.careerWaiting then return entry.profile, entry.team end
    return entry.actor, entry.team
end

function Statistics.tick(game, dt)
    local statistics = game.statistics
    if not statistics or statistics.summary or dt <= 0 then return end
    local opening = statistics.elapsed == 0
    statistics.elapsed = statistics.elapsed + dt
    for i, entry in ipairs(statistics.entries) do
        local line = participant(game,i)
        local athlete = game.squad[i]
        if line and entry and (not athlete or athlete.active ~= false and not athlete.suspended) then
            local stats = line.stats
            stats.gamesPlayed = 1
            if opening then stats.gamesStarted = 1 end
            increment(stats,"secondsPlayed",dt)
        end
    end
end

local function safeMetadata(game, metadata)
    if type(metadata) ~= "table" then return nil end
    local detail = {}
    for key, value in pairs(metadata) do
        local kind = type(value)
        if type(key) == "string" and (kind == "boolean" or kind == "string" or kind == "number"
            and value == value and math.abs(value) < math.huge) then
            if key == "other" or key == "target" or key == "user" or key == "defender" then
                local actor = participant(game,value)
                detail[key] = actor and actor.playerId or value
            else
                detail[key] = value
            end
        end
    end
    return detail
end

local function recordFor(game, line, team, key, amount, metadata)
    local statistics = game.statistics
    if not statistics or statistics.summary or key == "score" then return false end
    key = aliases[key] or key
    amount = tonumber(amount) or 1
    if not line or not measured[key] or amount == 0 or amount ~= amount or math.abs(amount) == math.huge then
        return false
    end
    if amount < 0 and key ~= "screenCoachPoints" then return false end
    increment(line.stats,key,amount)
    increment(statistics.sides[team].stats,key,amount)
    line.stats.gamesPlayed = 1
    local events = statistics.events
    events[#events+1] = {event=key, playerId=line.playerId, teamId=line.teamId, amount=amount,
        time=statistics.elapsed, detail=safeMetadata(game,metadata)}
    return true
end

function Statistics.record(game, playerIndex, key, amount, metadata)
    local player, team = participant(game,playerIndex)
    return recordFor(game,player,team,key,amount,metadata)
end

function Statistics.penalty(game, playerIndex, kind, seconds, metadata)
    local detail = copy(metadata)
    detail.foulType = kind
    Statistics.record(game,playerIndex,"penalties",1,detail)
    if kind == "technical" then Statistics.record(game,playerIndex,"technicalFouls")
    elseif kind == "personal" then Statistics.record(game,playerIndex,"personalFouls") end
    if seconds and seconds > 0 then Statistics.record(game,playerIndex,"penaltySeconds",seconds) end
end

local function recordTurnover(game, line, team, reason, by, byTeam)
    if not line then return end
    local detail = {reason=reason,other=by and by.playerId}
    recordFor(game,line,team,"turnovers",1,detail)
    recordFor(game,line,team,by and "committedForcedTurnovers" or "unforcedTurnovers",1,detail)
    if by then recordFor(game,by,byTeam,"causedTurnovers",1,{reason=reason,other=line.playerId}) end
end

function Statistics.turnover(game, playerIndex, reason, forcedBy)
    local line, team = participant(game,playerIndex)
    local by, byTeam = participant(game,forcedBy)
    recordTurnover(game,line,team,reason,by,byTeam)
end

function Statistics.deferTurnover(game, playerIndex, reason, forcedBy)
    local statistics = game.statistics
    local line, team = participant(game,playerIndex)
    if statistics and not statistics.summary and line then
        local by, byTeam = participant(game,forcedBy)
        statistics.turnover = {line=line,team=team,reason=reason,by=by,byTeam=byTeam}
    end
end

function Statistics.possession(game, playerIndex)
    local statistics = game.statistics
    if not statistics then return end
    local pending = statistics.turnover
    local _, team = participant(game,playerIndex)
    if pending and team and team ~= pending.team then
        recordTurnover(game,pending.line,pending.team,pending.reason,pending.by,pending.byTeam)
    end
    statistics.turnover = nil
end

function Statistics.resetPossession(game)
    if game.statistics then game.statistics.turnover = nil end
end

function Statistics.goalkeeper(game, playerIndex, result, other)
    local detail = {other=other,result=result}
    if result == "save" or result == "goal" then
        Statistics.record(game,playerIndex,"shotsFaced",1,detail)
        Statistics.record(game,playerIndex,result == "save" and "saves" or "goalsAllowed",1,detail)
    elseif result == "block" then
        Statistics.record(game,playerIndex,"blockedShots",1,detail)
    end
end

local function exported(values)
    local stats = copy(values)
    stats.faceoffs = stats.faceoffsWon or 0
    stats.forcedTurnovers = stats.causedTurnovers or 0
    stats.points = (stats.goals or 0) + (stats.assists or 0)
    stats.minutesPlayed = (stats.secondsPlayed or 0) / 60
    stats.penaltyMinutes = (stats.penaltySeconds or 0) / 60
    return stats
end

function Statistics.playerOfGame(summary)
    local best, bestScore = nil, -math.huge
    for _, player in pairs(summary.players) do
        local stats = player.stats
        if value(stats,"gamesPlayed") > 0 then
            local score = value(stats,"goals")*5 + value(stats,"assists")*3.5
                + value(stats,"saves")*1.7 - value(stats,"goalsAllowed")*.8
                + value(stats,"groundBalls")*.88 + value(stats,"causedTurnovers")*2.4
                + value(stats,"faceoffsWon")*1.65 - value(stats,"faceoffAttempts")*.5
                + value(stats,"screenAssists")*.85 - value(stats,"turnovers")*.95
                - value(stats,"penaltySeconds")/90
            if score > bestScore or score == bestScore and player.playerId < best.playerId then
                best, bestScore = player, score
            end
        end
    end
    return best
end

local function snapshot(game, options, final)
    local data = game.statistics
    options = options or {}
    local fixture = options.fixture or {}
    local result = {final=final or nil, competition=options.competition or data.competition,
        venueId=options.venueId or data.venueId}
    result.id, result.source, result.mode = data.id, data.source, data.mode
    result.profileId, result.date, result.elapsed = data.profileId, data.createdAt, data.elapsed
    result.homeId, result.awayId = data.homeId, data.awayId
    result.homeScore = game.homeScore or game.goals or 0
    result.awayScore = game.awayScore or 0
    result.result = data.practice and "PRACTICE" or result.homeScore > result.awayScore and "WIN"
        or result.homeScore < result.awayScore and "LOSS" or "DRAW"
    result.fixtureId = options.fixtureId or fixture.id or data.fixtureId
    result.season = options.season or fixture.season or data.season
    result.stage = options.stage or fixture.stage or data.stage
    result.week = options.week or fixture.week or data.week
    result.postseason = options.postseason or fixture.postseason or data.postseason
    result.events, result.players, result.teams, result.sides = copy(data.events), {}, {}, {}
    for id, line in pairs(data.players) do
        local player = copy(line)
        player.stats = exported(line.stats)
        player.rates = Statistics.rates(player.stats)
        result.players[id] = player
    end
    for index, line in ipairs(data.sides) do
        local team = copy(line)
        team.roster = copy(line.roster)
        team.stats = exported(line.stats)
        team.stats.secondsPlayed = data.elapsed
        team.stats.minutesPlayed = data.elapsed / 60
        team.rates = Statistics.rates(team.stats)
        result.teams[tostring(team.id)] = team.stats
        result.sides[index] = team
    end
    if final and not data.practice then
        for index, team in ipairs(result.sides) do
            local won = (index == 1 and result.homeScore > result.awayScore)
                or (index == 2 and result.awayScore > result.homeScore)
            local decision = result.homeScore == result.awayScore and "ties" or won and "wins" or "losses"
            team.stats[decision] = 1
            local keeper, minutes = nil, 0
            for _, id in ipairs(team.roster) do
                local line = result.players[id]
                local played = line.stats.secondsPlayed or 0
                if line.role == "G" and played > minutes then keeper, minutes = line, played end
            end
            if keeper then keeper.stats[decision] = 1 end
        end
    end
    local venueHome = options.venueHomeId or fixture.homeId or data.venueHomeId
    if venueHome == result.awayId and venueHome ~= result.homeId then
        result.homeId, result.awayId = result.awayId, result.homeId
        result.homeScore, result.awayScore = result.awayScore, result.homeScore
        result.sides[1], result.sides[2] = result.sides[2], result.sides[1]
    end
    local player = final and not data.practice and Statistics.playerOfGame(result)
    result.playerOfGame = player and player.playerId
    return result
end

function Statistics.matchSummary(game, options)
    local data = game and game.statistics
    if not data then return nil end
    if type(options) == "string" then options = {fixtureId=options} end
    return data.summary or snapshot(game,options)
end

function Statistics.profile(id)
    id = tostring(id or "career-player")
    if storedProfiles[id] then return storedProfiles[id] end
    local key = profileKey .. id
    local payload = readLocalData and readLocalData(key)
    local profile
    if type(payload) == "string" and json and json.decode then
        local okay, value = pcall(json.decode,payload)
        if okay and type(value) == "table" and type(value.matches) == "table"
            and type(value.order) == "table" then profile = value end
    end
    profile = profile or {id=id,matches={},order={}}
    storedProfiles[id] = profile
    return profile
end

function Statistics.saveSummary(summary)
    local profile = Statistics.profile(summary.profileId)
    if profile.matches[summary.id] then return true end
    local entry = copy(summary)
    entry.events = nil
    local nextProfile = {id=profile.id,matches=copy(profile.matches),order=copy(profile.order)}
    nextProfile.matches[entry.id] = entry
    nextProfile.order[#nextProfile.order+1] = entry.id
    if saveLocalData and json and json.encode then
        local ok, bytes = pcall(json.encode,nextProfile)
        if not ok then return false end
        local saved, returned = pcall(saveLocalData,profileKey .. profile.id,bytes)
        if not saved or returned == false then return false end
    end
    profile.matches, profile.order = nextProfile.matches, nextProfile.order
    return true
end

function Statistics.finalize(game, options)
    local data = game and game.statistics
    if not data then return nil end
    if not data.summary then
        data.summary = snapshot(game,options,true)
        game.statSummary = data.summary
    end
    if not data.saved and not (options and options.persist == false) then
        data.saved = Statistics.saveSummary(data.summary)
    end
    return data.summary
end
end

-- Gameplay
do
PolyLax = PolyLax or {}
local P = PolyLax
local Gameplay = {}
P.Gameplay = Gameplay

local formations = {
    {x = -4.6, z = 1.2, name = "M1"},
    {x = 4.6, z = 1.2, name = "M2"},
    {x = 0, z = -9.8, name = "M3"},
    {x = -6.3, z = -8.2, name = "A1"},
    {x = 6.3, z = -8.2, name = "A2"},
    {x = 0, z = -16, name = "X"}
}

local calls = {clear="CLEAR", swing="SWING", passdown="PASS DOWN"}
local passFlight = {speed=18,minDuration=.34,maxDuration=1.10,arcRate=.073,maxArc=.75}
local goalZ, goalieZ = -13, -12.3
local ballRadius, goalHalfWidth, goalTop = .09, .995, 1.745
local minX, maxX, minZ, maxZ = -8.4, 8.4, -16.5, 15.5
local gravity = 9.8
local atan2 = math.atan2 or math.atan

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function length(x, z)
    return math.sqrt(x * x + z * z)
end

local function facing(x, z)
    return math.deg(atan2(-x, -z))
end

local function angleDifference(target, current)
    return (target - current + 180) % 360 - 180
end

local function makeField(scene)
    local cube = craft.model.cube()
    local function material(tint)
        local standard = asset and asset.builtin and asset.builtin.Materials
        local m = craft.material(standard and standard.Standard or "Materials:Standard")
        m.diffuse = tint
        return m
    end

    local ground = material(color(27, 77, 47))
    local stripe = {material(color(44, 121, 72)), material(color(36, 105, 61))}
    local white = material(color(240, 244, 247))
    local blue = material(color(43, 166, 255))

    local function block(parent, x, y, z, width, height, depth, tint)
        local entity = scene:entity()
        if parent then entity.parent = parent end
        entity.model, entity.material = cube, tint
        entity.position, entity.scale = vec3(x, y, z), vec3(width, height, depth)
        return entity
    end

    block(nil, 0, -.14, 0, 34, .25, 50, ground)
    for i = 0, 9 do
        block(nil, 0, .015, -17 + (i + .5) * 3.4, 18, .025, 3.4, stripe[i % 2 + 1])
    end
    for _, x in ipairs({-9, 9}) do
        block(nil, x, .045, 0, .07, .026, 34, white)
    end
    for _, z in ipairs({-17, -8, 0, 8, 17}) do
        block(nil, 0, .045, z, 18, .026, .07, white)
    end

    local function ring(parent, z, radius, pieces, tint)
        local chord = 2 * radius * math.sin(math.pi / pieces)
        local centerRadius = radius * math.cos(math.pi / pieces)
        for i = 1, pieces do
            local angle = i * 2 * math.pi / pieces
            local segment = block(parent, math.sin(angle) * centerRadius, .057,
                z + math.cos(angle) * centerRadius, chord, .012, .035, tint)
            segment.eulerAngles = vec3(0, math.deg(angle), 0)
        end
    end
    ring(nil, goalZ, 2.1, 28, white)

    local marker = scene:entity()
    ring(marker, 0, .65, 14, blue)

    local ball = scene:entity()
    ball.model = craft.model.icosphere(ballRadius, 1, true)
    ball.material = material(color(255, 211, 66))
    return ball, marker
end

local function announce(game, message, seconds)
    game.announcement, game.announcementTime = message, seconds or 1.1
end

local function pocket(player)
    return player.rig.pocket.worldPosition
end

local function resetPlay(game)
    P.Statistics.resetPossession(game)
    game.statAssist = nil
    game.carrier, game.controlled = 1, 1
    game.mode, game.clearTime = "SET", 0
    game.pending, game.flight, game.loose = nil, nil, nil
    game.scoopPlayer, game.goalDelay, game.inNet = nil, nil, nil
    game.tactical, game.passSerial = nil, 0
    P.Screens.reset(game)
    P.GoalPhysics.reset(game.goalPhysics)
    for i, player in ipairs(game.squad) do
        local anchor = formations[i]
        player.x, player.z = anchor.x, anchor.z
        player.vx, player.vz, player.dodge = 0, 0, nil
        player.yaw = facing(-player.x, goalZ - player.z)
        player.rig.root.position = vec3(player.x, 0, player.z)
        player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
        P.AnimationController.reset(player.anim)
    end
    game.goalieX, game.goaliePreviousX = 0, 0
    game.goalie.root.position = vec3(0, 0, goalieZ)
    P.AnimationController.reset(game.goalieAnim)
    game.ball.position = pocket(game.squad[1])
    game.marker.position = game.squad[1].rig.root.position
end

function Gameplay.applyUniform(game, uniform)
    for _, player in ipairs(game.squad) do
        P.Character.applyUniform(player.rig, uniform, false)
    end
    P.Character.applyUniform(game.goalie,
        P.TeamUniform.forKeeper(uniform, game.goalieRole, game.opponentId), false)
    game.uniform = uniform
end

function Gameplay.applyProfile(game, profile, uniform, opponentId)
    uniform = uniform or P.TeamUniform.fromProfile(profile)
    opponentId = opponentId or profile and profile.OPPONENT
    if uniform ~= game.uniform or opponentId ~= game.opponentId then
        game.opponentId = opponentId
        Gameplay.applyUniform(game, uniform)
    end
    P.Character.apply(game.squad[1].rig, profile, nil, uniform, false)
end

function Gameplay.new(scene, profile, uniform, opponentId, statisticsOptions)
    local Character, Animation = P.Character, P.AnimationController
    uniform = uniform or P.TeamUniform.fromProfile(profile)
    local ball, marker = makeField(scene)
    local game = {
        squad = {}, teams = {{1, 2, 3, 4, 5, 6}}, ball = ball, marker = marker, goal = vec3(0, .9, goalZ),
        goalPhysics = P.GoalPhysics.new(scene, {
            z=goalZ, attackSign=-1, halfWidth=goalHalfWidth, top=goalTop, radius=ballRadius
        }),
        goals = 0, passes = 0, clock = 180, elapsed = 0,
        announcement = "", announcementTime = 0, moveX = 0, moveZ = 0,
        uniform = uniform, goalieRole = "opponent", opponentId = opponentId or profile and profile.OPPONENT
    }
    P.Screens.registerAnimations()

    for i, anchor in ipairs(formations) do
        local rig = Character.new(scene)
        Character.apply(rig, i == 1 and profile or {
            FACE = (i - 1) % 4 + 1, HAIR = 2, BEARD = 1, BODY = 2, HELMET = 4,
            JERSEY = 2, GLOVES = 1, SHORTS = 4, CLEATS = 1, STICK = 4, NUMBER = i + 8
        }, nil, uniform, false)
        game.squad[i] = {
            id=i, team=1, role=i <= 3 and "M" or "A", slot=i,
            homeX=anchor.x, homeZ=anchor.z, rig=rig, anim=Animation.new(rig), name=anchor.name,
            attributes=i == 1 and profile and profile.attributes or nil
        }
    end

    game.goalie = Character.new(scene)
    Character.apply(game.goalie, {
        FACE = 2, HAIR = 2, BODY = 3, HELMET = 3, JERSEY = 6,
        GLOVES = 4, SHORTS = 4, CLEATS = 4, STICK = 4, NUMBER = 1
    }, nil, P.TeamUniform.forKeeper(uniform, game.goalieRole, game.opponentId), false)
    game.goalie.root.eulerAngles = vec3(0, 180, 0)
    game.goalieAnim = Animation.new(game.goalie)
    game.statisticsOptions = statisticsOptions
    game.screenStat = function(id,key,detail)
        P.Statistics.record(game,id,key,1,detail)
        if key=="illegalScreens" then
            P.Statistics.record(game,id,"fouls")
            P.Statistics.penalty(game,id,"technical",0,detail)
        end
    end
    game.screenCallbacks = {stat=game.screenStat}
    P.Statistics.new(game,statisticsOptions)
    resetPlay(game)
    return game
end

local function startPass(game, plan, mode)
    local from = game.carrier
    if not from or not plan or not (plan.to or plan.point) or (plan.from and plan.from ~= from)
        or (plan.to and not game.squad[plan.to])
        or from == plan.to or game.pending or game.flight then return end
    if P.AnimationController.play(game.squad[from].anim, "pass") then
        game.pending = {kind="pass", from=from, to=plan.to, point=plan.point, call=mode}
        game.mode = mode
        game.clearTime = mode == "SET" and 0 or 3.5
        return true
    end
end

function Gameplay.passPreview(game, dx, dz)
    local from = game.carrier
    if game.clock <= 0 or game.goalDelay or not from or game.pending or game.flight
        or game.squad[from].anim.action then return end
    if from ~= game.controlled and length(dx or 0, dz or 0) < .12 then
        local plan = P.Passing.forTarget(game, game.controlled)
        plan.from = from
        return plan
    end
    return P.Passing.select(game, from, dx, dz)
end

local function tacticalPass(game, call)
    local from = game.carrier
    if not from or game.pending or game.flight then return end
    local to, detail = P.Tactics.choose(game, from, call)
    if not to then
        announce(game, "NO OPEN " .. (call == "PASS DOWN" and "DOWNFIELD" or call) .. " LANE")
        return
    end
    if startPass(game, P.Passing.forTarget(game, to), call) then
        P.Tactics.activate(game, detail, call, 1)
        return true
    end
end

local function playPick(game, manual)
    local holder = game.carrier
    if not holder or game.pending or game.flight or game.screen
        or (manual and game.controlled == holder) then return end
    local screener, detail
    if manual then
        screener = game.controlled
        local actor = game.squad[screener]
        detail = {x=actor.x, z=actor.z, manual=true}
    else
        detail = P.Tactics.pick(game, holder)
        if not detail then
            announce(game, "NO PICK AVAILABLE")
            return
        end
        screener = detail.screener
    end
    if P.Screens.request(game, screener, holder, nil, detail) then
        game.mode, game.clearTime = "PICK DOWN", 3.5
        return true
    end
end

local function startDodge(game, moveX, moveZ)
    local player = game.squad[game.controlled]
    local agility = P.Attributes.rating(player,"agility",60)-60
    if not P.AnimationController.play(player.anim, "dodge", 1+agility*.004) then return end

    local dx, dz = moveX, -moveZ
    local magnitude = length(dx, dz)
    if magnitude < .12 then
        local yaw = math.rad(player.yaw)
        local direction = player.x > 0 and 1 or -1
        dx, dz = direction * math.cos(yaw), -direction * math.sin(yaw)
        magnitude = 1
    end
    player.dodge = {x=dx/magnitude, z=dz/magnitude, time=.31, agility=agility}
end

local function startScoop(game, index, reach)
    if not game.loose or game.scoopPlayer or game.goalDelay then return false end
    local position = game.ball.position
    local velocity = game.loose.velocity
    local player = game.squad[index]
    local ground = P.Attributes.rating(player,"groundBalls",65)-65
    if position.y > .26 or length(velocity.x, velocity.z) > 2.7
        or length(position.x - player.x, position.z - player.z) > reach+ground*.005 then return false end
    if not P.AnimationController.play(player.anim, "scoop", 1+ground*.0038) then return false end
    game.scoopPlayer = index
    return true
end

function Gameplay.canAim(game)
    return game.clock > 0 and not game.goalDelay and game.carrier == game.controlled
        and not game.pending and not game.flight and not game.squad[game.controlled].anim.action
end

function Gameplay.aimContext(game)
    if not Gameplay.canAim(game) then return nil end
    return pocket(game.squad[game.carrier]), game.goalPhysics
end

function Gameplay.command(game, command, moveX, moveZ, aim)
    if command == "reset" then
        resetPlay(game)
        for _, player in ipairs(game.squad) do player.runningFatigue = 0 end
        game.goals, game.passes, game.clock, game.elapsed = 0, 0, 180, 0
        P.Statistics.new(game,game.statisticsOptions)
        announce(game, "PRACTICE RESET")
        return
    end
    if game.clock <= 0 or game.goalDelay then return end

    if command == "switch" then
        game.controlled = game.controlled % #game.squad + 1
    elseif calls[command] then
        return tacticalPass(game, calls[command])
    elseif command == "pickdown" then
        return playPick(game, false)
    elseif command == "setpick" then
        return playPick(game, true)
    elseif command == "releasepick" then
        local screen = game.screen
        if screen and screen.manual then
            return P.Screens.endHold(game,screen.screener,moveX or game.moveX,-(moveZ or game.moveZ))
        end
    elseif command == "pass" then
        return startPass(game, aim or Gameplay.passPreview(game,
            moveX or game.moveX, -(moveZ or game.moveZ)), "SET")
    elseif command == "shoot" then
        if game.loose then
            announce(game, "RECOVER THE BALL")
        elseif game.carrier and game.carrier ~= game.controlled then
            announce(game, "PASS TO THE SHOOTER")
        elseif Gameplay.canAim(game)
            and P.AnimationController.play(game.squad[game.carrier].anim, "shoot") then
            local goal = game.goalPhysics
            local target = aim and vec3(
                clamp(aim.x, goal.x-goal.halfWidth-.75, goal.x+goal.halfWidth+.75),
                clamp(aim.y, 0, goal.top+.65), goal.z)
            game.pending = {kind="shot", from=game.carrier, aim=moveX or game.moveX, target=target}
            return true
        end
    elseif command == "dodge" then
        startDodge(game, moveX or game.moveX, moveZ or game.moveZ)
    elseif command == "scoop" and game.loose then
        if not game.scoopPlayer and not startScoop(game, game.controlled, 1.12) then
            announce(game, "MOVE TO THE BALL")
        end
    end
end

local function spacing(game, index)
    local player = game.squad[index]
    local x, z = 0, 0
    for i, other in ipairs(game.squad) do
        if i ~= index then
            local dx, dz = player.x - other.x, player.z - other.z
            local distance = length(dx, dz)
            if distance < .001 then
                dx, distance = index < i and -1 or 1, 1
            end
            if distance < 2 then
                local pressure = (2 - distance) / distance
                x, z = x + dx * pressure, z + dz * pressure
            end
        end
    end
    return x, z
end

local function offBallTarget(game, index, carrierX, carrierZ)
    local anchor = formations[index]
    local x, z = anchor.x, anchor.z
    if index ~= 6 then
        x = x + carrierX * .16
        z = z + clamp((carrierZ + 5) * .20, -1.6, 1.6)
        -- One off-ball player fills the middle at a time.
        local cutSlot = math.floor(game.elapsed / 2.7)
        if index == cutSlot % 5 + 1 and math.abs(carrierX - x) > 2.6 then
            local progress = game.elapsed / 2.7 - cutSlot
            local cut = math.sin(math.pi * progress)
            x = x * (1 - .45 * cut)
            z = z + (index < 3 and -2.7 or 1.8) * cut
        end
    end
    local sx, sz = spacing(game, index)
    return clamp(x + sx, minX, maxX), clamp(z + sz, minZ, maxZ)
end

local function nearestLoosePlayer(game)
    if not game.loose then return nil end
    local best, distance = nil, math.huge
    local ball = game.ball.position
    for i, player in ipairs(game.squad) do
        local d = length(ball.x - player.x, ball.z - player.z)
        if d < distance then best, distance = i, d end
    end
    return best, distance
end

local function movePlayers(game, dt)
    local holder = game.carrier and game.squad[game.carrier]
    local carrierX, carrierZ = holder and holder.x or 0, holder and holder.z or -5
    local chase = nearestLoosePlayer(game)
    local ball = game.ball.position
    local cut = P.Tactics.activeCut(game)
    local manual = length(game.moveX, game.moveZ) > .08

    for index, player in ipairs(game.squad) do
        local vx, vz = 0, 0
        local screen = game.screen and P.Screens.intent(game, index)
        local receiveX, receiveZ = P.Passing.receiveTarget(game, index)
        local cutting = cut and cut.cutID == index
        local screenControl = screen and screen.screenControl
        player.screenIntent = screen
        if index == game.controlled and not screenControl and (manual or not (cutting or receiveX)) then
            local speed = P.Attributes.pace(player,game.sprinting and 8.3 or 6.1)
            vx, vz = game.moveX * speed, -game.moveZ * speed
        elseif index ~= game.carrier or screenControl then
            local tx, tz = offBallTarget(game, index, carrierX, carrierZ)
            local limit = 4.4
            if index == chase then
                local dx, dz = player.x - ball.x, player.z - ball.z
                local distance = length(dx, dz)
                if distance < .05 then
                    local yaw = math.rad(player.yaw)
                    dx, dz, distance = math.sin(yaw), math.cos(yaw), 1
                end
                tx, tz = ball.x + dx * .65 / distance, ball.z + dz * .65 / distance
                limit = 5.3
            elseif receiveX then
                tx, tz, limit = receiveX, receiveZ, 5.8
            elseif cutting then
                tx, tz, limit = cut.cutX, cut.cutZ, 5.6
            elseif screenControl then
                tx, tz, limit = screen.x, screen.z, screen.speed
            end
            local dx, dz = tx - player.x, tz - player.z
            local distance = length(dx, dz)
            if distance > .08 then
                local speed = math.min(distance*3, limit > 0 and P.Attributes.pace(player,limit) or 0)
                vx, vz = dx * speed / distance, dz * speed / distance
            end
        end

        local dodge = player.dodge
        if dodge then
            local burst = 6.8+3*dodge.time/.31+(dodge.agility or 0)*.033
            vx, vz = dodge.x * burst, dodge.z * burst
            dodge.time = dodge.time - dt
            if dodge.time <= 0 then player.dodge = nil end
        end

        local dvx, dvz = vx - player.vx, vz - player.vz
        local acceleration = dodge and 43 or 19+(P.Attributes.rating(player,"acceleration",60)-60)*.16
        local accel = math.min(1, acceleration*dt/math.max(.001,length(dvx,dvz)))
        local oldX, oldZ = player.x, player.z
        player.x = clamp(oldX + (player.vx + accel * dvx) * dt, minX, maxX)
        player.z = clamp(oldZ + (player.vz + accel * dvz) * dt, minZ, maxZ)
        player.vx, player.vz = (player.x - oldX) / dt, (player.z - oldZ) / dt
        player.speed = length(player.vx, player.vz)
        P.Attributes.updateFatigue(player,dt)
    end

    for index, player in ipairs(game.squad) do
        local lookX, lookZ = player.vx, player.vz
        local pending, flight = game.pending, game.flight
        if pending and pending.from == index then
            local target = pending.to and game.squad[pending.to] or pending.point or pending.target or game.goal
            lookX, lookZ = target.x-player.x, target.z-player.z
        elseif player.screenIntent and player.screenIntent.lookX then
            lookX, lookZ = player.screenIntent.lookX-player.x, player.screenIntent.lookZ-player.z
        elseif flight and flight.to == index and flight.duration - flight.time < .43 then
            lookX, lookZ = flight.origin.x-player.x, flight.origin.z-player.z
        elseif game.scoopPlayer == index then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        elseif player.speed < .25 then
            lookX, lookZ = (holder and holder ~= player and carrierX or 0) - player.x,
                (holder and holder ~= player and carrierZ or goalZ) - player.z
        end
        local rotation = 0
        local turnRate = 540+(P.Attributes.rating(player,"agility",60)-60)*3.1
        if length(lookX, lookZ) > .04 then
            rotation = clamp(angleDifference(facing(lookX, lookZ), player.yaw), -turnRate*dt, turnRate*dt)
        end
        player.yaw = (player.yaw + rotation) % 360
        player.turn = rotation / (turnRate*dt)
        player.rig.root.position = vec3(player.x, 0, player.z)
        player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
    end

    local goalieTarget = clamp(carrierX, -.9, .9)
    local flight = game.flight
    if flight and flight.kind == "shot" then
        goalieTarget = game.goalieX
        if ball.z > goalieZ and ball.z < goalieZ + 3 then
            goalieTarget = clamp(ball.x, -.9, .9)
        end
    end
    local shift = clamp(goalieTarget - game.goalieX, -3 * dt, 3 * dt)
    game.goaliePreviousX = game.goalieX
    game.goalieX = game.goalieX + shift
    game.goalie.root.position = vec3(game.goalieX, 0, goalieZ)
    P.AnimationController.update(game.goalieAnim, dt, {speed = math.abs(shift / dt)})
end

local function makeLoose(game, position, velocity)
    game.carrier, game.flight, game.pending = nil, nil, nil
    game.loose = {velocity = velocity}
    game.ball.position = position
    if game.mode == "SWING" then game.mode = "SET" end
end

local function finishShotStats(game, flight, scored)
    if not flight or flight.statsFinished then return end
    flight.statsFinished = true
    local keeper = game.statistics.practiceKeeper
    if scored then
        P.Statistics.record(game,flight.from,"goals")
        P.Statistics.record(game,flight.from,"shotsOnGoal")
        P.Statistics.goalkeeper(game,keeper,"goal",flight.from)
        local assist = game.statAssist
        if assist and assist.to==flight.from and game.elapsed-assist.at<=8 then
            P.Statistics.record(game,assist.from,"assists",1,{other=flight.from})
        end
        P.Screens.creditGoal(game,flight.from,game.screenStat,flight)
    elseif flight.keeperContact then
        if flight.onTarget then P.Statistics.record(game,flight.from,"shotsOnGoal") end
        P.Statistics.goalkeeper(game,keeper,flight.onTarget and "save" or "block",flight.from)
    end
    game.statAssist = nil
end

local function beginGoal(game, contact, flight)
    if game.inNet then return end
    finishShotStats(game,flight,true)
    local fixed = P.GoalPhysics.capture(game.goalPhysics, contact.position)
    game.carrier, game.flight, game.pending, game.loose = nil, nil, nil, nil
    game.scoopPlayer = nil
    game.inNet = {state="IN_NET", entrance=contact.position, fixed=fixed, age=0}
    game.goalDelay = P.GoalPhysics.scoreHold
    game.ball.position = contact.position
    game.goals = game.goals + 1
    announce(game, "GOAL", game.goalDelay)
end

local function release(game, pending)
    local flight
    local from = game.squad[pending.from]
    if pending.kind == "pass" then
        local speed = 18+(P.Attributes.rating(from,"passing",60)-60)*.12
        flight = P.Passing.launch(game, pending, passFlight, speed)
        game.passes = game.passes + 1
        P.Statistics.record(game,pending.from,"passes",1,{target=flight.to,call=pending.play})
    else
        local launch = pocket(from)
        flight = {kind="shot", from=pending.from, origin=launch, time=0}
        local aim = (pending.aim + game.moveX) * .5
        local goal = game.goalPhysics
        local targetX = game.goalieX <= goal.x and goal.x+.69 or goal.x-.69
        if math.abs(aim) > .16 then targetX = goal.x + aim * 1.45 end
        local target = pending.target or vec3(targetX, 1.12 + from.speed*.018, goal.z)
        local span = length(target.x-launch.x,target.z-launch.z)
        local spreadX,spreadY = P.Attributes.shotSpread(game,from,span)
        target = target+vec3(spreadX,spreadY,0)
        local velocity = 23+(P.Attributes.rating(from,"shotPower",60)-60)*.15
        local crossingTime = clamp(span/velocity,.15,1.05)
        flight.duration = crossingTime + .32
        flight.velocity = (target-launch)/crossingTime + vec3(0, .5*gravity*crossingTime, 0)
        if pending.target then
            flight.velocity = flight.velocity + vec3(from.vx*.10, 0, from.vz*.10)
        end
        flight.canScore = (launch.z-goal.z)*goal.attackSign <= 0
        local y = math.max(0, launch.y-ballRadius)
        local vy = flight.velocity.y
        flight.groundTime = (vy+math.sqrt(vy*vy+2*gravity*y))/gravity
        local time = (goal.z-launch.z) / flight.velocity.z
        if time>0 and time<=flight.duration and time<=flight.groundTime and flight.canScore then
            local at = launch + flight.velocity*time - vec3(0,.5*gravity*time*time,0)
            flight.onTarget = math.abs(at.x-goal.x)<goal.halfWidth-ballRadius
                and at.y>=ballRadius and at.y<goal.top-ballRadius
        end
        P.Statistics.record(game,pending.from,"shots")
        P.Screens.creditShot(game,pending.from,game.screenStat,flight)
    end

    game.pending, game.carrier, game.flight = nil, nil, flight
    game.ball.position = flight.origin
end

local function planScoop(game)
    if not game.loose or game.scoopPlayer or game.goalDelay then return end
    local index = nearestLoosePlayer(game)
    if index then startScoop(game, index, .84) end
end

local function attach(game, index)
    P.Statistics.possession(game,index)
    if game.loose then finishShotStats(game,game.loose.shot,false) end
    game.statAssist = nil
    game.carrier, game.controlled = index, index
    game.scoopPlayer, game.loose, game.flight = nil, nil, nil
    game.ball.position = pocket(game.squad[index])
    if game.mode == "SWING" then game.mode = "SET" end
end

local function rebound(game, contact, canScore, flight)
    local position = contact.position + contact.normal * .003
    local y = math.max(ballRadius, position.y)
    makeLoose(game, vec3(position.x,y,position.z), contact.velocity * .65)
    game.loose.canScore,game.loose.shot = canScore,flight
    if flight then
        if contact.kind=="SAVE" then flight.keeperContact=true
        else P.Statistics.record(game,flight.from,"pipeHits",1,{reason=contact.kind}) end
    end
    announce(game, contact.kind)
end

local function updateShot(game, flight, dt)
    local endTime = math.min(flight.time+dt, flight.duration, flight.groundTime)
    local goal = game.goalPhysics
    local frameStart = flight.time
    while flight.time < endTime do
        -- Chord sweeps over short ballistic steps preserve contact order
        -- through a frame spike and follow a moving keeper's body.
        local t = math.min(flight.time+.018, endTime)
        local previous = game.ball.position
        local position = flight.origin + flight.velocity*t - vec3(0,.5*gravity*t*t,0)
        local velocity = flight.velocity - vec3(0,gravity*t,0)
        local keeperDelta = game.goalieX - game.goaliePreviousX
        local keeper = {
            z=goalieZ, x=game.goaliePreviousX+keeperDelta*((t-frameStart)/dt),
            prevX=game.goaliePreviousX+keeperDelta*((flight.time-frameStart)/dt)
        }
        local contact = P.GoalPhysics.step(goal, previous, position, velocity, keeper)
        if contact then
            local kind = contact.kind
            if kind == "GOAL" and flight.canScore then
                beginGoal(game, contact,flight)
                return
            elseif kind == "POST" or kind == "CROSSBAR" or kind == "SAVE" then
                rebound(game, contact, flight.canScore,flight)
                return
            elseif kind ~= "GOAL" and flight.canScore then
                local misses = {WIDE="shotsWide",HIGH="shotsHigh",LOW="shotsLow"}
                if not flight.miss and misses[kind] then P.Statistics.record(game,flight.from,misses[kind]) end
                flight.miss = kind
                announce(game, kind)
            end
        end
        flight.time, game.ball.position = t, position
    end

    if flight.time >= flight.duration or flight.time >= flight.groundTime then
        if not flight.miss then
            if not flight.canScore then
                announce(game, "BEHIND THE GOAL LINE")
            elseif (game.ball.position.z-goal.z)*goal.attackSign < goal.radius then
                announce(game, "SHOT FELL SHORT")
            end
        end
        local position = game.ball.position
        local velocity = flight.velocity - vec3(0,gravity*flight.time,0)
        makeLoose(game, vec3(position.x,math.max(ballRadius,position.y),position.z), velocity*.26)
        game.loose.canScore,game.loose.shot = flight.canScore,flight
    end
end

local function updateFlight(game, dt, catchIndex)
    local flight = game.flight
    if flight.kind == "shot" then
        updateShot(game, flight, dt)
        return
    end
    flight.time = math.min(flight.time + dt, flight.duration)
    game.ball.position = P.Passing.sample(game, flight, flight.time)
    if P.Passing.canCatch(game, flight, catchIndex, game.ball.position) then
        local autoSelect = game.controlled == flight.from
        local controlled = game.controlled
        attach(game, flight.to)
        P.Statistics.record(game,flight.from,"completions",1,{other=flight.to})
        game.statAssist = {from=flight.from,to=flight.to,at=game.elapsed}
        if not autoSelect then game.controlled = controlled end
    elseif flight.time >= flight.duration then
        makeLoose(game, game.ball.position, P.Passing.endVelocity(game, flight))
        game.statAssist = nil
        P.Statistics.deferTurnover(game,flight.from,flight.to and "droppedPass" or "passToSpace")
        announce(game, flight.to and "PASS DROPPED" or "BALL TO SPACE")
    end
end

local function updateLoose(game, dt, scoopIndex)
    local loose = game.loose
    local v = loose.velocity
    local position = game.ball.position + v * dt
    local x, y, z = position.x, position.y, position.z
    local vx, vy, vz = v.x, v.y - gravity * dt, v.z

    if y < ballRadius then
        y = ballRadius
        vy = math.abs(vy) > .85 and math.abs(vy) * .28 or 0
        local drag = math.max(0, 1 - 4 * dt)
        vx, vz = vx * drag, vz * drag
    end
    if x < minX or x > maxX then
        x, vx = clamp(x, minX, maxX), -vx * .45
    end
    if z < minZ or z > maxZ then
        z, vz = clamp(z, minZ, maxZ), -vz * .45
    end

    local nextPosition = vec3(x,y,z)
    local frame = P.GoalPhysics.step(game.goalPhysics, game.ball.position, nextPosition, v)
    if frame then
        if frame.kind == "GOAL" and loose.canScore then
            beginGoal(game, frame,loose.shot)
            return
        elseif frame.kind == "POST" or frame.kind == "CROSSBAR" then
            rebound(game, frame, loose.canScore,loose.shot)
            return
        end
    end
    game.ball.position = nextPosition
    loose.velocity = vec3(vx, vy, vz)

    if scoopIndex and scoopIndex == game.scoopPlayer then
        local player = game.squad[scoopIndex]
        game.scoopPlayer = nil
        local contact = pocket(player)
        local ground = P.Attributes.rating(player,"groundBalls",65)-65
        if y <= .32 and contact.y <= .72 and length(x-contact.x,z-contact.z) <= .73+ground*.004 then
            attach(game, scoopIndex)
            P.Statistics.record(game,scoopIndex,"groundBalls")
            announce(game, "GROUND BALL")
        end
    end
end

function Gameplay.update(game, dt, moveX, moveZ)
    if dt <= 0 then return end
    game.announcementTime = math.max(0, game.announcementTime - dt)
    P.GoalPhysics.update(game.goalPhysics, dt)
    if game.inNet then
        local net = game.inNet
        net.age = net.age + dt
        game.goalDelay = math.max(0, P.GoalPhysics.scoreHold - net.age)
        local progress = math.min(1,net.age/.18)
        local travel = 1-(1-progress)^2
        game.ball.position = net.entrance + (net.fixed-net.entrance)*travel
        if game.goalDelay == 0 then
            resetPlay(game)
            if game.clock <= 0 then
                P.Statistics.finalize(game)
                announce(game, "PRACTICE COMPLETE", 2)
            end
        end
    end
    if game.clock <= 0 then return end
    local liveTime = math.min(dt,game.clock)
    game.clock = math.max(0, game.clock - dt)
    game.elapsed = game.elapsed + liveTime
    P.Statistics.tick(game,liveTime)
    local magnitude = math.max(1, length(moveX, moveZ))
    game.moveX, game.moveZ = moveX / magnitude, moveZ / magnitude

    if game.clearTime > 0 then
        game.clearTime = math.max(0, game.clearTime - dt)
        if game.clearTime == 0 then game.mode = "SET" end
    end

    movePlayers(game, dt)
    P.Passing.scheduleCatch(game, game.flight, dt)
    planScoop(game)

    local flight, loose = game.flight, game.loose
    local catchIndex, scoopIndex
    for index, player in ipairs(game.squad) do
        local event = P.AnimationController.update(player.anim, dt, {
            speed = player.speed, possessed = game.carrier == index, turn = player.turn,
            scoopPoint = game.scoopPlayer == index and game.ball.position or nil,
            catchPoint = P.Passing.catchPoint(game, index)
        })
        if event == "release" and game.pending and game.pending.from == index then
            release(game, game.pending)
        elseif event == "catch" then
            catchIndex = index
        elseif event == "scoop" then
            scoopIndex = index
        end
    end
    if game.scoopPlayer and not game.squad[game.scoopPlayer].anim.action and not scoopIndex then
        game.scoopPlayer = nil
    end

    if flight then
        updateFlight(game, dt, catchIndex)
    elseif loose then
        updateLoose(game, dt, scoopIndex)
    elseif game.carrier then
        game.ball.position = pocket(game.squad[game.carrier])
    end

    P.Screens.update(game,dt,game.screenCallbacks)
    game.marker.position = game.squad[game.controlled].rig.root.position
    if game.clock == 0 and not game.inNet then
        finishShotStats(game,game.loose and game.loose.shot,false)
        P.Statistics.finalize(game)
        announce(game, "PRACTICE COMPLETE", 2)
    end
end
end

-- Field
do
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
end

-- Defense
do
-- PolyLax Build 012 | Defense
PolyLax = PolyLax or {}
local P = PolyLax
local Defense = {}
P.Defense = Defense

local checks = {
    poke = {clip="pokeCheck", reach=1.78, cooldown=.64, impact=.16, force=3.0, stat="pokes", name="POKE CHECK"},
    slap = {clip="slapCheck", reach=1.50, cooldown=.86, impact=.23, force=4.2, stat="slaps", name="SLAP CHECK"},
    body = {clip="bodyCheck", reach=1.16, cooldown=1.15, impact=.21, force=5.0, stat="bodyChecks", name="BODY CHECK"}
}
Defense.checks = checks

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distance(x, z)
    return math.sqrt(x*x + z*z)
end

function Defense.reach(player, style)
    local check = checks[style]
    local extension = style ~= "body" and player.rig.stickReachExtension or 0
    return check.reach + (extension or 0)
end

local function forwardDot(player, x, z, length)
    local yaw = math.rad(player.yaw)
    return (-math.sin(yaw)*x - math.cos(yaw)*z) / math.max(length, .001)
end

function Defense.configure(options)
    local group = options.ageGroup or "adult"
    local bodyAllowed = options.bodyContact
    if bodyAllowed == nil then
        local age = tonumber(tostring(group):match("%d+"))
        bodyAllowed = group == "adult" or group == "open" or (age and age >= 14) or false
    end
    return group, bodyAllowed == true
end

function Defense.attributes(role)
    local closeDefense = role == "D"
    local specialist = role == "LSM" or role == "SSDM"
    return {
        stickCheck = (closeDefense or role == "LSM") and .77 or .62,
        bodyCheck = (closeDefense or role == "SSDM") and .75 or .60,
        interception = (closeDefense or specialist) and .76 or .65,
        reaction = role == "G" and .80 or (closeDefense or specialist) and .74 or .65,
        ballSecurity = role == "A" and .75 or .65
    }
end

local function stat(player, key, fallback)
    return clamp(P.Attributes.unit(player,key,fallback),.05,1)
end

local function frame(time, grip, shaft, torso, crouch, roll, freeHand)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand or 0}
end

function Defense.registerAnimations()
    local clips = P.AnimationController.clips
    if clips.pokeCheck then return end
    clips.pokeCheck = {
        duration=.36, eventTime=checks.poke.impact, event="check",
        poses={
            frame(.07,vec3(.36,.67,-.13),vec3(.71,.40,.34),vec3(-6,-10,-5),.08,-12),
            frame(.16,vec3(.29,.64,-.53),vec3(.24,.13,-.96),vec3(-16,8,2),.12,6,.28),
            frame(.25,vec3(.33,.61,-.29),vec3(.65,.38,-.55),vec3(-7,4,3),.07,2)
        }
    }
    clips.slapCheck = {
        duration=.51, eventTime=checks.slap.impact, event="check",
        poses={
            frame(.11,vec3(.39,.71,.01),vec3(.94,.31,.16),vec3(1,-29,-12),.05,-24,.19),
            frame(.23,vec3(.23,.66,-.37),vec3(.53,.11,-.84),vec3(-13,23,9),.12,18,.38),
            frame(.34,vec3(.15,.49,-.29),vec3(.89,-.08,-.44),vec3(-9,28,8),.06,34)
        }
    }
    clips.bodyCheck = {
        duration=.52, eventTime=checks.body.impact, event="check",
        poses={
            frame(.09,vec3(.31,.64,-.18),vec3(.86,.43,.07),vec3(-10,-15,-13),.18,-21),
            frame(.21,vec3(.38,.58,-.13),vec3(.90,.40,.06),vec3(-26,21,-24),.24,-25),
            frame(.34,vec3(.33,.57,-.16),vec3(.88,.42,-.08),vec3(-14,16,-12),.11,-11)
        }
    }
    clips.intercept = {
        duration=.44, eventTime=.18, event="intercept",
        poses={
            frame(.09,vec3(.24,.81,-.36),vec3(.48,.81,-.18),vec3(-9,-12,-3),.05,-18,.40),
            frame(.18,vec3(.16,.91,-.52),vec3(.39,.90,-.18),vec3(-13,-5,3),.06,-9,.55),
            frame(.30,vec3(.23,.67,-.30),vec3(.63,.72,.08),vec3(-4,-17,-4),.02,12,.20)
        }
    }
end

local function geometry(checker, target)
    local x, z = target.x - checker.x, target.z - checker.z
    local length = distance(x, z)
    return x, z, length, forwardDot(checker, x, z, length), forwardDot(target, -x, -z, length)
end

local function bodyLegal(match, target, victimFacing)
    return match.rules.bodyContact and match.carrier == target.id and target.role ~= "G"
        and victimFacing >= -.36
end

local function nearestContact(match, checker)
    local closest, reach = nil, checks.body.reach + .25
    for _, index in ipairs(match.teams[3-checker.team]) do
        local player = match.squad[index]
        local length = distance(checker.x - player.x, checker.z - player.z)
        if length < reach then closest, reach = player, length end
    end
    return closest
end

function Defense.request(match, checker, name)
    if name == "check" then name = "poke" end
    local check = checks[name]
    if not check or checker.role == "G" or checker.checkCooldown > 0 then return end
    local target = match.carrier and match.squad[match.carrier]
    if target and target.team == checker.team then target = nil end
    if not target and name == "body" then target = nearestContact(match, checker) end
    if not target then return end
    local _, _, length = geometry(checker, target)
    if length > Defense.reach(checker,name) + .40 then return end
    local skill = stat(checker, name == "body" and "bodyCheck" or "stickCheck", .63)
    local isPole = name ~= "body" and checker.rig.stickType == "long"
    local clip = isPole and check.clip.."Long" or check.clip
    local cadence = isPole and .92 or 1
    if P.AnimationController.play(checker.anim, clip, (.86 + skill * .22)*cadence) then
        checker.checkCooldown = check.cooldown/cadence
        return {style=name, target=target.id, skill=skill, clip=clip}
    end
end

function Defense.aiChoice(match, checker, target)
    if checker.role == "G" or target.role == "G" or checker.checkCooldown > 0 then return end
    local _, _, length, facing, victimFacing = geometry(checker, target)
    if bodyLegal(match, target, victimFacing) and length < .93 and facing >= .63
        and checker.role == "D" and target.speed >= 2.8 then return "body" end
    if facing < .06 or victimFacing < -.64 then return end
    if length < Defense.reach(checker,"slap")-.32
        and (target.speed < 3.2 or target.anim.action == "pass") then return "slap" end
    if length < Defense.reach(checker,"poke")-.13 then return "poke" end
end

local function stickGap(checker, target)
    local base, tip = P.Character.stickSegment(checker.rig)
    local targetBase, targetTip = P.Character.stickSegment(target.rig)
    local axis, targetAxis, between = tip-base, targetTip-targetBase, base-targetBase
    local aa, ab, bb = axis:dot(axis), axis:dot(targetAxis), targetAxis:dot(targetAxis)
    local aq, bq = axis:dot(between), targetAxis:dot(between)
    local determinant = aa*bb - ab*ab
    local first = determinant > .000001 and clamp((ab*bq-bb*aq)/determinant,0,1) or 0
    local second = (ab*first+bq)/math.max(bb,.000001)
    if second < 0 or second > 1 then
        second = clamp(second,0,1)
        first = clamp((ab*second-aq)/math.max(aa,.000001),0,1)
    end
    return (between+axis*first-targetAxis*second):len()
end

function Defense.contact(match, checker, request)
    local target = match.squad[request.target]
    local check = checks[request.style]
    local dx, dz, length, facing, victimFacing = geometry(checker, target)
    local body = request.style == "body"
    local reach = Defense.reach(checker,request.style) + (request.skill - .65) * .20
    if length > reach or facing < (body and .32 or -.12) then return "miss" end
    if body and not bodyLegal(match, target, victimFacing) then return "foul" end
    if match.carrier ~= target.id or target.role == "G" then return "miss" end
    if not body and victimFacing < -.70 then return "miss" end

    local gap = body and length or stickGap(checker, target)
    local security = stat(target, "ballControl", .65)
    local protect = target.anim.action == "protect" or target.anim.action == "dodge"
    local ready = target.anim.action ~= "pass" and target.anim.action ~= "shoot"
    local impact = request.skill + (body and .21 or .05) + .22 * facing
        + .12 * math.max(0, victimFacing) - .13 * length / reach
    local leverage = body and (stat(checker,"strength",.60)-stat(target,"strength",.60)) or 0
    impact = impact+leverage*.18
    local stability = security * .63 + (protect and .30 or 0) + (ready and .13 or 0)
    if not body then
        local contactRange = .34+request.skill*.12
        if gap >= contactRange then return "miss" end
        local quality = 1-gap/contactRange
        impact = request.skill*.48 + quality*.36 + math.max(0,facing)*.20
            + math.max(0,victimFacing)*.10 - .12*length/reach - (checker.runningFatigue or 0)*.09
        stability = .23 + security*.37 + (protect and .20 or 0) + (ready and .07 or 0)
    end
    if impact < stability then return "miss" end

    local range = math.max(.28, length)
    local force = check.force*(1+leverage*.28)
    local velocity = vec3(target.vx*.23 + dx*force/range,
        body and .78 or .48, target.vz*.23 + dz*force/range)
    return "loose", target.rig.pocket.worldPosition, velocity
end

function Defense.passPoint(match, flight, time)
    if flight.point then return P.Passing.sample(match,flight,time) end
    local fraction = clamp(time / flight.duration, 0, 1)
    local endPoint = match.squad[flight.to].rig.pocket.worldPosition
    return flight.origin + (endPoint-flight.origin)*fraction
        + vec3(0, math.sin(fraction*math.pi)*flight.arc, 0)
end

function Defense.prepareIntercept(match, flight)
    if flight.kind ~= "pass" or flight.interceptor then return end
    local eventTime = P.AnimationController.clips.intercept.eventTime
    if flight.duration - flight.time < eventTime + .08 then return end
    local target = Defense.passPoint(match, flight, flight.time + eventTime)
    local previous = match.ball.position
    if target.y < .44 or target.y > 3.05 then return end
    local best, player = math.huge, nil
    for _, id in ipairs(match.teams[3-flight.team]) do
        local candidate = match.squad[id]
        local reaction = stat(candidate, "reaction", .67)
        local savvy = stat(candidate, "interception", .63)
        local lead = .11 + .18 * (1-reaction)
        local dx, dz = previous.x - candidate.x, previous.z - candidate.z
        local gap = distance(target.x-candidate.x-candidate.vx*eventTime*.55,
            target.z-candidate.z-candidate.vz*eventTime*.55)
        if flight.time >= lead and gap < 1.14 + savvy*.34 and gap < best
            and forwardDot(candidate, dx, dz, distance(dx,dz)) > -.36
            and not candidate.anim.action then best, player = gap, candidate end
    end
    if player and P.AnimationController.play(player.anim, "intercept") then
        flight.interceptor = {id=player.id, pocket=player.rig.pocket.worldPosition}
    end
end

function Defense.intercept(match, flight, from, to)
    local contest = flight.interceptor
    if not contest then return end
    local player = match.squad[contest.id]
    local current = player.rig.pocket.worldPosition
    local previous = contest.pocket
    contest.pocket = current
    local event = P.AnimationController.clips.intercept.eventTime
    if player.anim.action ~= "intercept" or math.abs(player.anim.actionTime - event) > .074 then return end

    -- Sweep the ball relative to the moving pocket so a fast pass can cross it
    -- cleanly within a single frame without tunneling or snapping from afar.
    local start, finish = from - previous, to - current
    local travel = finish - start
    local time = clamp(-start:dot(travel) / math.max(.001, travel:dot(travel)), 0, 1)
    local offset = start + travel * time
    local run = stat(player, "interception", .65)
    local reach = .25 + run*.25
    if offset:dot(offset) <= reach*reach then return player.id end
end
end

-- Midfield
do
-- PolyLax 2.0.3 | Midfield positioning
PolyLax = PolyLax or {}
local Midfield = {}
PolyLax.Midfield = Midfield

local minimum = {offense=3, defense=4}
local lineTolerance, noticeRange = .012, 1.05
local warningTime, offsidesTime = .27, 1.20

local function opposite(side)
    return side == "offense" and "defense" or "offense"
end

local function worldSide(team, z)
    if math.abs(z) <= lineTolerance then return nil end
    local attacksNegative = team == 1
    return (z < 0) == attacksNegative and "offense" or "defense"
end

local function center(match)
    return match.field and match.field.midfieldZ or 0
end

function Midfield.halfAt(match, team, z)
    return worldSide(team, z-center(match))
end

local function active(player)
    return player and player.active ~= false and player.onField ~= false and not player.bench
end

local function playerSide(match, player, previous)
    if player.role == "G" then return "defense" end
    return Midfield.halfAt(match,player.team,player.z)
        or previous
        or (player.homeZ and Midfield.halfAt(match,player.team,player.homeZ))
        or "defense"
end

local function isValid(counts)
    return counts.offense >= minimum.offense and counts.defense >= minimum.defense
        and counts.keepers == 1 and not counts.keeperOut
end

local function countTeam(match, team, previous)
    local counts = {offense=0, defense=0, active=0, keepers=0, keeperOut=false}
    local sides, players = {}, {}
    for _, index in ipairs(match.teams[team] or {}) do
        local player = match.squad[index]
        if active(player) and player.team == team then
            local id = player.id
            local side = playerSide(match,player,previous[id])
            sides[id] = side
            players[#players+1] = player
            counts[side], counts.active = counts[side]+1, counts.active+1
            if player.role == "G" then
                counts.keepers = counts.keepers+1
                counts.keeperOut = counts.keeperOut or Midfield.halfAt(match,team,player.z) == "offense"
            end
        end
    end
    counts.valid = isValid(counts)
    return counts, sides, players
end

function Midfield.reset(match)
    local previous = match.positioning and match.positioning.sides or {}
    local state = {counts={}, sides={}, blocked={}, noticeTime=0}
    for team = 1, 2 do
        local counts, sides = countTeam(match,team,previous)
        state.counts[team] = counts
        for id, side in pairs(sides) do state.sides[id] = side end
    end
    state.invalid = not (state.counts[1].valid and state.counts[2].valid)
    match.positioning = state
    return state
end

function Midfield.side(match, player)
    local sides = match.positioning and match.positioning.sides
    return playerSide(match,player,sides and sides[player.id])
end

function Midfield.counts(match, team)
    local state = match.positioning
    if state and state.counts[team] then return state.counts[team] end
    local counts = countTeam(match,team,{})
    return counts
end

local function prioritize(candidates, humanID)
    table.sort(candidates, function(a,b)
        if a.id == humanID then return b.id ~= humanID end
        if b.id == humanID then return false end
        if a.progress ~= b.progress then return a.progress > b.progress end
        return a.id < b.id
    end)
end

local function deny(state, id, side, proposal, z, reason)
    proposal.z = z
    state.blocked[id] = {side=side, reason=reason}
end

local function resolveTeam(match, team, proposals, humanID, state, nextSides)
    local counts, sides, players = countTeam(match,team,state.sides)
    local floor = {
        offense=math.min(counts.offense,minimum.offense),
        defense=math.min(counts.defense,minimum.defense)
    }
    local crossing = {offense={}, defense={}}
    local keeperOut = false
    local midfield = center(match)
    for _, player in ipairs(players) do
        local id = player.id
        local side = sides[id]
        local proposal = proposals[id]
        nextSides[id] = side
        if state.sides[id] and state.sides[id] ~= side then state.externalEdit = true end

        local target = proposal and Midfield.halfAt(match,team,proposal.z)
        if player.role == "G" then
            local existing = Midfield.halfAt(match,team,player.z)
            if existing == "offense" then
                -- An externally displaced keeper can walk back. Do not teleport it.
                state.externalEdit = true
                if target == "offense" and math.abs(proposal.z-midfield) > math.abs(player.z-midfield) then
                    deny(state,id,side,proposal,player.z,"keeper")
                end
                local resolved = Midfield.halfAt(match,team,proposal and proposal.z or player.z)
                keeperOut = keeperOut or resolved == "offense"
            elseif target == "offense" then
                deny(state,id,side,proposal,midfield,"keeper")
            end
        elseif target and target ~= side then
            local list = crossing[side]
            list[#list+1] = {id=id, progress=math.abs(proposal.z-midfield)}
            counts[side], counts[target] = counts[side]-1, counts[target]+1
        end
    end

    -- Resolve net movement first so opposite crossings in the same frame can
    -- trade sides without either one depending on roster iteration order.
    for _, side in ipairs({"offense","defense"}) do
        local list = crossing[side]
        local deniedCount = math.max(0,floor[side]-counts[side])
        if deniedCount > 0 then prioritize(list,humanID) end
        local target = opposite(side)
        local allowedCount = #list-deniedCount
        for index, candidate in ipairs(list) do
            if index <= allowedCount then
                nextSides[candidate.id] = target
            else
                deny(state,candidate.id,side,proposals[candidate.id],midfield,"minimum")
                counts[side], counts[target] = counts[side]+1, counts[target]-1
            end
        end
    end
    counts.keeperOut = keeperOut
    counts.valid = isValid(counts)
    state.counts[team] = counts
end

local function notice(state, text, level, duration)
    state.notice, state.level, state.noticeTime = text, level, duration
end

local function showHumanNotice(match, state, proposals, humanID)
    local player = humanID and match.squad[humanID]
    local proposal = player and proposals[humanID]
    if not active(player) or not proposal then return end
    local team = player.team
    local side = state.sides[humanID]
    if not side then return end
    local blocked = state.blocked[humanID]
    if blocked then
        notice(state,"OFFSIDES","offsides",offsidesTime)
        return
    end
    if state.level == "offsides" or math.abs(proposal.z-center(match)) > noticeRange then return end
    local wanted = worldSide(team,proposal.intentZ or 0)
    local full = state.counts[team]
    if wanted and wanted ~= side and (player.role == "G" or full[side] <= minimum[side]) then
        local text = player.role == "G" and "GOALKEEPER STAYS BACK"
            or (side == "offense" and "KEEP 3 IN OFFENSE" or "KEEP 4 IN DEFENSE")
        notice(state,text,"warning",warningTime)
    end
end

function Midfield.resolve(match, proposals, humanID, dt)
    local state = match.positioning or Midfield.reset(match)
    state.noticeTime = math.max(0,state.noticeTime-math.max(0,dt or 0))
    if state.noticeTime == 0 then state.notice,state.level = nil,nil end
    state.blocked, state.externalEdit = {}, false

    local nextSides = {}
    for team = 1, 2 do resolveTeam(match,team,proposals,humanID,state,nextSides) end
    state.sides = nextSides
    state.invalid = not (state.counts[1].valid and state.counts[2].valid)
    if state.invalid then
        local side = not state.counts[1].valid and not state.counts[2].valid and "BOTH TEAMS"
            or not state.counts[1].valid and "HOME" or "AWAY"
        notice(state,side.." OFFSIDES","offsides",offsidesTime)
    else
        showHumanNotice(match,state,proposals,humanID)
    end
    return state
end

-- A substitution is an atomic exchange at a proposed field location. This
-- preview does not change the count cache, positions, lineup, or active flags.
function Midfield.canSubstitute(match, team, outgoingID, incoming, z)
    local former = match.squad[outgoingID]
    if type(incoming) == "number" then incoming = match.squad[incoming] end
    local previous = match.positioning and match.positioning.sides or {}
    local counts, sides, players = countTeam(match,team,previous)
    if not former or not sides[outgoingID] then
        return false,counts,"outgoing player is not active on this team"
    end
    if not incoming or incoming.team ~= team or incoming == former then
        return false,counts,"incoming player is not an eligible teammate"
    end
    for _, player in ipairs(players) do
        if player == incoming or incoming.id and player.id == incoming.id then
            return false,counts,"incoming player is already active"
        end
    end

    local formerSide = sides[outgoingID]
    local target = Midfield.halfAt(match,team,z or incoming.z or former.z) or formerSide
    if incoming.role == "G" and target ~= "defense" then
        counts.valid, counts.keeperOut = false, true
        return false,counts,"goalkeeper must enter on defense"
    end
    if formerSide ~= target then
        counts[formerSide], counts[target] = counts[formerSide]-1, counts[target]+1
    end
    counts.keepers = counts.keepers - (former.role == "G" and 1 or 0) + (incoming.role == "G" and 1 or 0)
    counts.keeperOut = false
    for _, player in ipairs(players) do
        if player ~= former and player.role == "G" and Midfield.halfAt(match,team,player.z) == "offense" then
            counts.keeperOut = true
        end
    end
    counts.valid = isValid(counts)
    if counts.valid then return true,counts end
    if counts.keepers ~= 1 then return false,counts,"exactly one goalkeeper must remain active" end
    if counts.keeperOut then return false,counts,"goalkeeper is over midfield" end
    if counts.offense < minimum.offense then return false,counts,"fewer than 3 players in offense" end
    return false,counts,"fewer than 4 players in defense"
end
end

-- MatchAI
do
-- PolyLax 2.0.3 | MatchAI
PolyLax = PolyLax or {}
local P = PolyLax
local AI = {}
PolyLax.MatchAI = AI

local TACTICAL_INTERVAL = .16
local BALL_RADIUS = .09
local GRAVITY = 9.8
local atan2 = math.atan2 or math.atan

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distanceSquared(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx*dx + dz*dz
end

local function planDistance(ax, az, bx, bz)
    return math.sqrt(distanceSquared(ax, az, bx, bz))
end

local function unit(dx, dz, fallbackZ)
    local length = math.sqrt(dx*dx + dz*dz)
    if length < .0001 then return 0, fallbackZ or 0 end
    return dx / length, dz / length
end

local function goalX(goal)
    return goal.x or 0
end

local function goalHeight(goal)
    return goal.height or goal.top or goal.crossbar or 1.83
end

local function midfielder(player)
    return player.role == "M" or player.role == "LSM" or player.role == "SSDM"
end

local function humanControls(match, id)
    if match.humans then return match.humans[id] ~= nil end
    return id == match.controlled and not match.careerWaiting
end

local function attackingSign(match, team)
    local goal = match.goalsByTeam[team]
    return goal.attackSign or (goal.z < 0 and -1 or 1)
end

local function acrossMidfield(match, player, sign)
    local z = player.z * sign
    if math.abs(z) > .0001 then return z > 0 end
    local side = P.Midfield and P.Midfield.side and P.Midfield.side(match,player)
    if side == "offense" or side == "OFFENSE" then return true end
    if side == "defense" or side == "DEFENSE" then return false end
    if type(side) == "number" then return side * sign > 0 end
    if type(side) == "boolean" then return side end
    return (player.homeZ or 0) * sign > 0
end

local function numbers(match,team,sign)
    if P.Midfield and P.Midfield.counts then return P.Midfield.counts(match,team) end
    local attack, defense = 0, 0
    for _, id in ipairs(match.teams[team]) do
        if acrossMidfield(match,match.squad[id],sign) then attack = attack + 1
        else defense = defense + 1 end
    end
    return {offense=attack,defense=defense}
end

function AI.new()
    return {
        elapsed=0, nextTick=0, phase=nil, lastTeam=nil,
        intents={}, players={}, goalies={},
        tactics={{mark={}}, {mark={}}},
        awareness={}
    }
end

local function ballTeam(match)
    if match.carrier then return match.squad[match.carrier].team end
    if match.flight and match.flight.kind == "pass" then
        return match.squad[match.flight.from].team
    end
end

local function updateAwareness(match, ai)
    local snapshot = ai.awareness
    snapshot.ball = match.ball.position
    snapshot.velocity = match.ballVelocity
    snapshot.carrier = match.carrier
    snapshot.possessionTeam = ballTeam(match)
    snapshot.phase = match.phase
    snapshot.flight = match.flight
    snapshot.loose = match.loose ~= nil
    snapshot.teams = match.teams
    snapshot.players = ai.players
    for id, player in ipairs(match.squad) do
        local entry = ai.players[id] or {}
        ai.players[id] = entry
        entry.id, entry.team, entry.role = id, player.team, player.role
        entry.x, entry.z = player.x, player.z
        entry.teammates, entry.opponents = match.teams[player.team], match.teams[3 - player.team]
        local goal = match.goalsByTeam[player.team]
        entry.distanceToGoal = planDistance(player.x, player.z, goalX(goal), goal.z)
        entry.distanceToBall = planDistance(player.x, player.z, snapshot.ball.x, snapshot.ball.z)
        entry.phase = snapshot.phase
    end
    return snapshot
end

local function move(intent, x, z)
    intent.x, intent.z = x, z
end

local function restrict(match, intent)
    local field = match.field
    intent.x = clamp(intent.x, -field.halfWidth + .5, field.halfWidth - .5)
    intent.z = clamp(intent.z, -field.halfLength + .5, field.halfLength - .5)
end

local function nearestOpponent(match, player)
    local best, bestDistance = nil, math.huge
    for _, id in ipairs(match.teams[3 - player.team]) do
        local opponent = match.squad[id]
        if opponent.role ~= "G" then
            local distance = distanceSquared(player.x, player.z, opponent.x, opponent.z)
            if distance < bestDistance then best, bestDistance = opponent, distance end
        end
    end
    return best, math.sqrt(bestDistance)
end

function AI.passTarget(match, fromID, swing)
    local target, detail = P.Tactics.choose(match, fromID, swing and "SWING" or "SAFE")
    return target, detail and detail.score
end

local function moveKeeper(match, keeper, intent, ball, sightTime)
    local goal = match.goalsByTeam[3 - keeper.team]
    local cx = goalX(goal)
    local inside = goal.z < 0 and 1 or -1
    local depth = (ball.z - goal.z) * inside
    local lateral = ball.x - cx
    local angle = atan2(lateral, math.max(2.5, depth))
    local positioning = P.Attributes.unit(keeper,"goaliePositioning",keeper.positioning or .78)
    local arc = 1.08+(positioning-.5)*.34
    local px = cx + math.sin(angle) * arc
    local pz = goal.z + math.cos(angle) * arc * inside
    if depth < .4 then
        px = cx + clamp(lateral * .18, -.86, .86)
        pz = goal.z + .34 * inside
    end
    if sightTime then
        px = cx + clamp(lateral, -.98, .98) * .83
        pz = goal.z + .76 * inside
    end
    move(intent, px, pz)
    intent.lookX, intent.lookZ = ball.x, ball.z
    intent.role = sightTime and "SHOT" or "GOAL ARC"
    local footwork = P.Attributes.unit(keeper,"goaliePositioning",keeper.footwork or .73)
    intent.speed = 2.7+footwork*(sightTime and 4.1 or 2.5)
end

local function useScreen(match, ai, tactic, carrier, defender, pressure, depth, goal, intent)
    local screens = P.Screens
    if not screens then return false end
    local now = ai.elapsed
    local screen = match.screen
    if not screen and defender and pressure > 1.15 and pressure < 4.2
        and depth > 7 and depth < 23 and not carrier.anim.action
        and now >= (tactic.nextPick or 0) then
        local plan = P.Tactics.pick(match, carrier.id, defender.id)
        if plan and not (match.humans and humanControls(match,plan.screener)) then
            screen = screens.request(match, plan.screener, carrier.id, defender.id, plan)
            if screen then tactic.nextPick = now + 5 end
        end
    end
    if not screen or screen.user ~= carrier.id then return false end

    local towardX, towardZ = unit(goalX(goal) - screen.x, goal.z - screen.z)
    if screen.phase == "APPROACH" or screen.phase == "PLANT" then
        -- Stay on the entry side while the screener gets both feet set.
        move(intent, screen.x - towardX*1.65 - towardZ*screen.side*.65,
            screen.z - towardZ*1.65 + towardX*screen.side*.65)
        intent.speed, intent.role = 2.9, "WAIT FOR PICK"
        return true
    end
    if screen.phase == "HOLD" then
        local tangentX, tangentZ = -towardZ*screen.side, towardX*screen.side
        local vx, vz = unit(screen.x + towardX*2.7 + tangentX*1.06 - carrier.x,
            screen.z + towardZ*2.7 + tangentZ*1.06 - carrier.z)
        move(intent, carrier.x + vx*3.6, carrier.z + vz*3.6)
        intent.speed, intent.role = 7.7, "USE PICK"
        if not match.pending and not carrier.anim.action and (screen.contact or pressure < 2.6)
            and now >= (tactic.nextDodge or 0) then
            intent.action, intent.moveX, intent.moveZ = "dodge", vx, -vz
            tactic.nextDodge = now + 1.4
        end
        return true
    end
    if screen.phase == "RELEASE" and not match.pending and not carrier.anim.action then
        local receiver = match.squad[screen.screener]
        local gap = planDistance(carrier.x, carrier.z, receiver.x, receiver.z)
        if gap > 2.1 and gap < 14 and P.Tactics.opponentSpace(match, receiver) > 1.7
            and P.Tactics.laneRisk(match, carrier, receiver) < 1.25
            and now >= (tactic.nextAction or 0) then
            intent.action, intent.target = "pass", receiver.id
            intent.tactic = {call="PICK DOWN", from=carrier.id, target=receiver.id,
                team=carrier.team, untilTime=(match.elapsed or 0) + 2}
            tactic.nextAction = now + .9
            return true
        end
    end
    return false
end

local function tacticalPass(match, tactic, carrierID, pressure, depth, now)
    local call
    if match.mode == "SWING" or match.mode == "CLEAR" or match.mode == "PASS DOWN" then
        call = match.mode
    elseif now >= (tactic.nextCall or 0) then
        if pressure < 2 and depth > 9 then call = "CLEAR"
        elseif depth > 8 and depth < 25 and pressure < 4.1 then call = "PASS DOWN"
        elseif depth < 26 then call = "SWING" end
    end
    if not call then return nil end
    local target, detail = P.Tactics.choose(match, carrierID, call)
    if target then tactic.nextCall = now + 2.2 end
    return target, detail
end

local function midfieldOutlet(slot,ball,progress)
    local firstWing = ball.x < 0 and 4 or 5
    local order = slot == firstWing and 1 or slot == 6 and 3 or 2
    local leaders = progress >= -1 and 3 or progress > -11 and 2 or progress > -24 and 1 or 0
    if order <= leaders then return nil, 2.8 + order * 1.4 end
    local width = slot == 4 and -12.4 or slot == 5 and 12.4 or ball.x * .22
    local depth = clamp(-progress * (.18 + order * .10) + order,3.6,22)
    return width, -depth
end

local function offBallAttack(match, ai, snapshot, team)
    local goal = match.goalsByTeam[team]
    local cx = goalX(goal)
    local inside = goal.z < 0 and 1 or -1
    local ball = snapshot.ball
    local distance = (ball.z - goal.z) * inside
    local advance = clamp((distance - 24) * .78, 0, match.field.halfLength * 1.45)
    local spread = clamp(math.abs(ball.x - cx) * .18, 0, 3.5)
    local sides, depths = {-8.8, 8.8, 0, -6.4, 6.4, 0}, {10.4, 10.4, -4, 18.5, 18.5, 7}
    local tactic = ai.tactics[team]
    local cut = P.Tactics.activeCut(match)
    local carrierID = match.carrier
    local carrier = carrierID and match.squad[carrierID]
    local sign = attackingSign(match,team)
    local progress = (carrier and carrier.z or ball.z) * sign
    local attackSlot, midSlot = 0, 3
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local intent = ai.intents[identifier]
        if player.role == "G" then
            moveKeeper(match, player, intent, ball)
        elseif player.role == "A" or midfielder(player) then
            if player.role == "A" then attackSlot = attackSlot + 1 else midSlot = midSlot + 1 end
            local slot = player.role == "A" and math.min(attackSlot,3) or math.min(midSlot,6)
            local x, z = sides[slot], depths[slot] + advance
            if match.mode == "CLEAR" and advance < 2 then
                if slot < 3 then x, z = x * 1.46, 2 end
                if slot == 6 then x, z = ball.x > 0 and -5.6 or 5.6, 14 end
            elseif slot == 3 then
                x = x - ball.x * .11
            else
                x = x + (x < 0 and -spread or spread) + ball.x*.08
            end
            if tactic.cut == identifier and advance < 3 and slot ~= 3 then
                x, z = -ball.x * .10, 6.1
            end
            local fieldX, fieldZ = cx+x, (goal.z+z*inside)*sign
            if player.role == "A" then
                fieldZ = math.max(fieldZ, slot == 3 and 13 or 6.0)
            else
                local outlet, depth = midfieldOutlet(slot,ball,progress)
                if outlet then fieldX,fieldZ = cx+outlet,depth
                else fieldZ = math.max(fieldZ,depth) end
            end
            move(intent, fieldX, fieldZ*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = fieldZ < 0 and "MIDFIELD OUTLET" or tactic.cut == identifier and "CUT"
                or advance > 8 and "TRANSITION" or "2-3-1"
        else
            local ownGoal = match.goalsByTeam[3 - team]
            local depthFromOwn = (ball.z - ownGoal.z) * -inside
            local reserve = clamp(depthFromOwn * .42 + 7, 8, 34)
            local z = math.min(-2.4,(ownGoal.z-reserve*inside)*sign)
            move(intent, player.homeX + ball.x*.08, z*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = "RELEASE SUPPORT"
        end
        if cut and cut.team == team and cut.cutID == identifier then
            move(intent, cut.cutX, cut.cutZ)
            intent.lookX, intent.lookZ, intent.speed = ball.x, ball.z, 7.4
            intent.role = cut.call == "CLEAR" and "CLEAR THROUGH" or "PASS DOWN CUT"
        end
    end

    if not carrier or carrier.team ~= team or carrier.role == "G" then
        return
    end
    local defender, pressure = nearestOpponent(match, carrier)
    local intent = ai.intents[carrierID]
    local approachX, approachZ = unit(cx - carrier.x, goal.z - carrier.z, -inside)
    if distance < 5.2 then
        local side = carrier.x >= 0 and 1 or -1
        move(intent, cx + 4.4 * side, goal.z + 6 * inside)
    else
        move(intent, carrier.x + approachX*7, carrier.z + approachZ*7)
    end
    intent.lookX, intent.lookZ = cx, goal.z
    intent.role = "BALL"

    local now = ai.elapsed
    if now >= (tactic.nextCut or 0) and distance < 22 then
        local best, bestSpace = nil, -math.huge
        for _, identifier in ipairs(match.teams[team]) do
            local player = match.squad[identifier]
            if player.role == "A" and identifier ~= carrierID and player.x * ball.x <= 0 then
                local _, space = nearestOpponent(match, player)
                local score = space - planDistance(player.x, player.z, cx, goal.z) * .15
                if score > bestSpace then best, bestSpace = identifier, score end
            end
        end
        tactic.cut, tactic.nextCut = best, now + 2.1
    elseif now >= (tactic.nextCut or 0) or distance > 25 then
        tactic.cut = nil
    end

    if humanControls(match,carrierID) then return end
    if not match.pending and not match.flight
        and useScreen(match, ai, tactic, carrier, defender, pressure, distance, goal, intent) then return end

    if match.pending or match.flight or carrier.anim and carrier.anim.action then return end
    if now < (tactic.nextAction or 0) then return end
    local shotRange = planDistance(carrier.x, carrier.z, cx, goal.z)
    local keeper = match.squad[match.keepers[3 - team]]
    local shotSide = keeper.x >= cx and -1 or 1
    local shootingAngle = distance / math.max(1, shotRange)
    local read = P.Attributes.unit(carrier,"lacrosseIQ",.60)-.60
    local decisionDelay = 1-read*.42
    if shotRange < 15 and distance > 2.6 and shootingAngle > .49+read*.11
            and (pressure > 2.15 or shotRange < 7.4) then
        intent.action = "shoot"
        intent.aim = vec3(cx + goal.halfWidth*.66*shotSide, goalHeight(goal)*.66, goal.z)
        tactic.nextAction = now+.72*decisionDelay
    elseif defender and pressure < 2.6 and distance < 23 then
        local side = defender.x <= carrier.x and 1 or -1
        local nextX = carrier.x + side * 3.1
        local nextZ = carrier.z + approachZ * 3.3
        if match.mode ~= "SWING" and math.abs(nextX) < match.field.halfWidth - 1.5
                and now >= (tactic.nextDodge or 0) then
            move(intent, nextX, nextZ)
            intent.action, intent.moveX, intent.moveZ = "dodge", side*.79, -approachZ*.61
            tactic.nextDodge, tactic.nextAction = now+1.4,now+.38*decisionDelay
        end
    end
    if not intent.action and (pressure < 3.8 or distance < 25 or match.mode == "SWING") then
        local target, detail = tacticalPass(match, tactic, carrierID, pressure, distance, now)
        local score = detail and detail.score
        if not target and match.mode ~= "CLEAR" then
            target, score = AI.passTarget(match, carrierID, false)
        end
        if target and score > 2.5+read*.58 then
            intent.action, intent.target = "pass", target
            intent.tactic = detail
            tactic.nextAction = now+.68*decisionDelay
        end
    end
end

function AI.canCheck(match, checkerID, carrierID)
    local checker, carrier = match.squad[checkerID], match.squad[carrierID]
    if not checker or not carrier or checker.team == carrier.team
            or match.carrier ~= carrierID or match.flight
            or match.phase ~= "LIVE" then return false end
    local style = PolyLax.Defense.aiChoice(match, checker, carrier)
    return style ~= nil, style
end

local function chooseMatchups(match, ai, team, ownGoal, carrier)
    local tactic = ai.tactics[team]
    local marks, used = {}, {}
    local opposition = match.teams[3 - team]
    local gx = goalX(ownGoal)
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        if player.role == "D" or midfielder(player) then
            local best, score = nil, math.huge
            for _, otherID in ipairs(opposition) do
                local other = match.squad[otherID]
                if not used[otherID] and other.role ~= "G" and other.role ~= "D" then
                    local candidate = planDistance(player.x, player.z, other.x, other.z)
                        + planDistance(other.x, other.z, gx, ownGoal.z)*.16
                    if tactic.mark[identifier] == otherID then candidate = candidate - 2 end
                    if player.role == "D" and midfielder(other) then candidate = candidate + 2.8 end
                    if candidate < score then best, score = otherID, candidate end
                end
            end
            if best then marks[identifier], used[best] = best, true end
        end
    end
    -- Preserve the settled matchup on routine passes, but orient on the ball.
    local primary, primaryScore = nil, math.huge
    if carrier and carrier.role ~= "G" then
        for identifier, mark in pairs(marks) do
            local defender = match.squad[identifier]
            local candidate = planDistance(defender.x, defender.z, carrier.x, carrier.z)
            if mark == carrier.id then candidate = candidate - 2.4 end
            if tactic.primary == identifier then candidate = candidate - .85 end
            if candidate == primaryScore and identifier < primary then candidate = candidate - .001 end
            if candidate < primaryScore then primary, primaryScore = identifier, candidate end
        end
    end
    tactic.mark, tactic.primary = marks, primary
    return tactic
end

local function coordinateSlide(match, tactic, goal, carrier)
    local primary = tactic.primary and match.squad[tactic.primary]
    local gx = goalX(goal)
    if not carrier or not primary then
        tactic.firstSlide, tactic.secondSlide = nil, nil
        return
    end
    local distance = planDistance(carrier.x, carrier.z, gx, goal.z)
    local fx, fz = unit(gx-carrier.x, goal.z-carrier.z)
    local defenderX, defenderZ = primary.x-carrier.x, primary.z-carrier.z
    local goalSide = defenderX*fx + defenderZ*fz
    local miss = math.abs(defenderX*fz - defenderZ*fx)
    local danger = distance < 13 and (goalSide < .35 or miss > 1.8) and (carrier.speed > .9 or distance < 8)
    if not danger then
        tactic.firstSlide, tactic.secondSlide = nil, nil
        return
    end

    local first, firstScore = nil, math.huge
    for identifier in pairs(tactic.mark) do
        local defender = match.squad[identifier]
        if identifier ~= primary.id then
            local cost = planDistance(defender.x, defender.z, carrier.x + fx*1.4, carrier.z + fz*1.4)
            cost = cost + planDistance(defender.x, defender.z, gx, goal.z)*.22
            if identifier == tactic.firstSlide then cost = cost - 1.35 end
            if cost < firstScore or cost == firstScore and identifier < first then
                first, firstScore = identifier, cost
            end
        end
    end
    tactic.firstSlide = first

    local second, secondScore = nil, math.huge
    local vacated = first and match.squad[tactic.mark[first]]
    if vacated then
        for identifier in pairs(tactic.mark) do
            if identifier ~= primary.id and identifier ~= first then
                local defender = match.squad[identifier]
                local cost = planDistance(defender.x, defender.z, vacated.x, vacated.z)
                if identifier == tactic.secondSlide then cost = cost - .65 end
                if cost < secondScore or cost == secondScore and identifier < second then
                    second, secondScore = identifier, cost
                end
            end
        end
    end
    tactic.secondSlide = second
end

local function swapMark(marks, defender, assignment)
    local old = marks[defender]
    for id, other in pairs(marks) do
        if id ~= defender and other == assignment then
            marks[id] = old
            break
        end
    end
    marks[defender] = assignment
end

local function obstructed(screen, x, z, tx, tz)
    local fx, fz = tx - x, tz - z
    local span = fx*fx + fz*fz
    if span < .01 then return false end
    local at = ((screen.x-x)*fx + (screen.z-z)*fz) / span
    return at >= -.04 and at <= 1.18
        and planDistance(screen.x, screen.z, x + fx*at, z + fz*at) < 1.02
end

local function defendScreen(match, ai, tactic, team, carrier)
    local swap = tactic.screenSwitch
    if swap and (ai.elapsed >= swap.untilTime or not carrier
        or (carrier.id ~= swap.user and carrier.id ~= swap.screener)) then
        tactic.screenSwitch, swap = nil, nil
    end
    local screen = match.screen
    if not swap and screen and screen.team ~= team and carrier and carrier.id == screen.user
        and screen.defender and tactic.mark[screen.defender] and screen.phase == "HOLD" then
        local held = match.squad[screen.defender]
        if screen.contact or obstructed(screen, held.x, held.z, carrier.x, carrier.z) then
            local gap = planDistance(held.x, held.z, carrier.x, carrier.z)
            local helper, best = nil, math.huge
            for _, id in ipairs(match.teams[team]) do
                local assignment = tactic.mark[id]
                if id ~= held.id and assignment then
                    local help = match.squad[id]
                    local cover = planDistance(help.x, help.z, carrier.x, carrier.z)
                    local partner = assignment == screen.screener
                    if cover < 4.6 and (partner or screen.contact and cover < gap - .25)
                        and cover < gap + (screen.contact and 1.15 or .15) then
                        local score = cover - (partner and .95 or 0)
                        if score < best then helper, best = id, score end
                    end
                end
            end
            if helper then
                swap = {user=screen.user, screener=screen.screener, on=helper,
                    off=held.id, untilTime=ai.elapsed + 1.25}
                tactic.screenSwitch = swap
            end
        end
    end
    if swap then
        swapMark(tactic.mark, swap.on, swap.user)
        swapMark(tactic.mark, swap.off, swap.screener)
        tactic.primary = carrier.id == swap.user and swap.on or swap.off
    end
    return swap
end

local function routeAroundScreen(screen, player, intent, goal)
    if not screen or screen.phase ~= "HOLD" or screen.defender ~= player.id then return false end
    local ux, uz = unit(intent.x - player.x, intent.z - player.z)
    local gap = planDistance(player.x, player.z, screen.x, screen.z)
    if gap > 3.3 or not obstructed(screen, player.x, player.z, intent.x, intent.z) then return false end
    -- Pick the goal side when available. Lead the waypoint past the obstacle so
    -- the next decision resumes the assignment instead of aiming at its edge.
    local goalDx, goalDz = goalX(goal) - screen.x, goal.z - screen.z
    local over = -uz*goalDx + ux*goalDz >= 0 and 1 or -1
    local clearance = screen.contact and 1.48 or 1.22
    move(intent, screen.x - uz*over*clearance + ux*.83, screen.z + ux*over*clearance + uz*.83)
    intent.speed = screen.contact and 4.4 or 5.7
    intent.role = screen.contact and "SCREEN RECOVERY" or gap < 1.65 and "FIGHT OVER" or "GO AROUND"
    return true
end

local function defend(match, ai, snapshot, team)
    local goal = match.goalsByTeam[3 - team]
    local gx = goalX(goal)
    local ball = snapshot.ball
    local carrierID = match.carrier
    local carrier = carrierID and match.squad[carrierID]
    local sign = attackingSign(match,team)
    local inRide = (carrier and carrier.z or ball.z)*sign > 2
    local tactic = chooseMatchups(match, ai, team, goal, carrier)
    local switching = defendScreen(match, ai, tactic, team, carrier)
    coordinateSlide(match, tactic, goal, carrier)
    local onBall = tactic.firstSlide or tactic.primary
    local inside = goal.z < 0 and 1 or -1
    if inRide then
        onBall = nil
        if carrier then
            local best = math.huge
            for _, id in ipairs(match.teams[team]) do
                local player = match.squad[id]
                if player.role == "A" and not humanControls(match,id) then
                    local gap = distanceSquared(player.x,player.z,carrier.x,carrier.z)
                    if gap < best then onBall,best=id,gap end
                end
            end
        end
    end

    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local intent = ai.intents[identifier]
        local mark = tactic.mark[identifier]
        if player.role == "G" then
            moveKeeper(match, player, intent, ball)
        elseif carrier and identifier == onBall then
            local fx, fz = unit(gx-carrier.x, goal.z-carrier.z, -inside)
            local spacing = identifier == tactic.firstSlide and 1.48 or 1.26
            local z = carrier.z+fz*spacing
            if inRide then z = math.max(1.25,z*sign)*sign
            else z = math.min(-1.25,z*sign)*sign end
            move(intent, carrier.x + fx*spacing,z)
            intent.lookX, intent.lookZ = carrier.x, carrier.z
            intent.role = inRide and "RIDE PRESSURE" or identifier == tactic.firstSlide and "FIRST SLIDE"
                or switching and "SCREEN SWITCH" or "BALL PRESSURE"
            local gap = planDistance(player.x, player.z, carrier.x, carrier.z)
            intent.speed = gap < 3.4 and 4.4 or 7.2
            if not routeAroundScreen(match.screen, player, intent, goal) then
                local canCheck, style = AI.canCheck(match, identifier, carrierID)
                if canCheck and ai.elapsed >= (tactic.nextCheck or 0) then
                    intent.action, intent.target = style, carrierID
                    tactic.nextCheck = ai.elapsed + .72
                end
            end
        elseif player.role == "A" then
            local depth = clamp(ball.z*sign+12,6,math.max(7,math.abs(player.homeZ)-3))
            move(intent, player.homeX + ball.x*.16, depth*sign)
            intent.lookX,intent.lookZ = ball.x,ball.z
            intent.role = inRide and "RIDE SUPPORT" or "HIGH OUTLET"
        elseif inRide then
            local depth = midfielder(player) and -clamp(math.abs(player.homeX)*.21+3,3,8)
                or -math.max(10,math.abs(player.homeZ)*.68)
            move(intent, player.homeX + ball.x*.12,depth*sign)
            intent.lookX,intent.lookZ = ball.x,ball.z
            intent.role = midfielder(player) and "MIDFIELD RECOVERY" or "DEFENSIVE SHAPE"
        elseif mark then
            if identifier == tactic.secondSlide then mark = tactic.mark[tactic.firstSlide] end
            if identifier == tactic.primary and tactic.firstSlide and tactic.secondSlide then
                mark = tactic.mark[tactic.secondSlide]
            end
            local assignment = match.squad[mark]
            local towardX, towardZ = unit(gx-assignment.x, goal.z-assignment.z)
            local gap = identifier == tactic.secondSlide and .94 or 1.76
            local help = (assignment.x * ball.x < 0) and .20 or .1
            local x = assignment.x + towardX*gap + (ball.x-assignment.x) * help
            local z = assignment.z + towardZ*gap
            if match.flight and match.flight.kind == "pass" and match.flight.to == mark then
                x, z = x + (ball.x-x)*.31, z + (ball.z-z)*.31
                intent.role = "DENY PASS"
            else
                intent.role = identifier == tactic.secondSlide and "SECOND SLIDE"
                    or identifier == tactic.primary and "RECOVER" or "MATCHUP"
            end
            move(intent, x, math.min(-1.5,z*sign)*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            routeAroundScreen(match.screen, player, intent, goal)
        else
            local support = clamp((ball.z-goal.z)*inside + 9, 32, match.field.halfLength*1.48)
            move(intent, player.homeX + ball.x*.13, math.min(-1.5,(goal.z+support*inside)*sign)*sign)
            intent.lookX, intent.lookZ = ball.x, ball.z
            intent.role = "RIDE"
        end
    end
end

local function assignLoose(match, ai, snapshot, team)
    local ball = snapshot.ball
    local velocity = snapshot.velocity or vec3()
    local x, z = ball.x + velocity.x*.16, ball.z + velocity.z*.16
    local sign = attackingSign(match,team)
    local limits = numbers(match,team,sign)
    local onAttack = z*sign > 0
    local best, second, d1, d2 = nil, nil, math.huge, math.huge
    for _, identifier in ipairs(match.teams[team]) do
        local player = match.squad[identifier]
        local distance = distanceSquared(player.x, player.z, x, z)
        if player.role == "G" then
            local ownGoal = match.goalsByTeam[3 - team]
            if distanceSquared(goalX(ownGoal), ownGoal.z, x, z) > 6.4 then distance = math.huge end
        end
        if math.abs(z) > .65 and acrossMidfield(match,player,sign) ~= onAttack
            and (onAttack and limits.offense >= 6 or not onAttack and limits.defense >= 7) then
            distance = math.huge
        end
        if distance < d1 then
            second, d2 = best, d1
            best, d1 = identifier, distance
        elseif distance < d2 then
            second, d2 = identifier, distance
        end
    end
    if best then
        local chaser = match.squad[best]
        local intent = ai.intents[best]
        local dx, dz = unit(x-chaser.x, z-chaser.z, 1)
        move(intent, x-dx*.37, z-dz*.37)
        intent.lookX, intent.lookZ = x, z
        intent.role = "GROUND BALL"
        if ball.y < .34 and distanceSquared(chaser.x,chaser.z,ball.x,ball.z) < 1.35^2 then
            intent.action = "scoop"
        end
    end
    if second and d2 < 80 and match.squad[second].role ~= "G" then
        local support = match.squad[second]
        local sx, sz = unit(support.x-x, support.z-z, 1)
        local intent = ai.intents[second]
        move(intent, x + sx*3, z + sz*3)
        intent.role = "GROUND COVER"
    end
end

local function humanCrossing(match, human, team, sign, moveZ)
    if human and human.team == team and math.abs(human.z) <= 10 then
        local advance = -(moveZ or 0)*sign
        if math.abs(advance) < .14 then advance = (human.vz or 0)*sign*.16 end
        if math.abs(advance) >= .14 and (advance > 0) ~= acrossMidfield(match,human,sign) then
            return human,advance > 0
        end
    end
end

local function requestCrossing(match,ai,team,sign)
    if match.humans then
        for _, id in ipairs(match.teams[team]) do
            local input = match.humans[id]
            if input then
                local player, heading = humanCrossing(match,match.squad[id],team,sign,input.z)
                if player then return player,heading end
            end
        end
    else
        local human = not match.careerWaiting and match.squad[match.controlled]
        local player, heading = humanCrossing(match,human,team,sign,match.moveZ)
        if player then return player,heading end
    end
    local carrier = match.carrier and match.squad[match.carrier]
    if carrier and not humanControls(match,carrier.id) and carrier.team == team and carrier.role ~= "G"
        and math.abs(carrier.z) <= 9 then
        local target = ai.intents[carrier.id].z*sign
        if math.abs(target) > .65 and (target > 0) ~= acrossMidfield(match,carrier,sign) then
            return carrier,target > 0
        end
    end
end

local function exchangeAtMidfield(match,ai,snapshot,team,sign)
    local tactic = ai.tactics[team]
    local exchange = tactic.exchange
    local mover,toAttack = requestCrossing(match,ai,team,sign)
    if exchange then
        local player = match.squad[exchange.mover]
        if acrossMidfield(match,player,sign) == exchange.toAttack then
            exchange = nil
        elseif mover and mover.id == exchange.mover and toAttack == exchange.toAttack then
            exchange.untilTime = ai.elapsed + .55
        elseif ai.elapsed >= exchange.untilTime then
            exchange = nil
        end
    end
    if not exchange and mover then
        local count = numbers(match,team,sign)
        if toAttack and count.offense >= 6 or not toAttack and count.defense >= 7 then
            local best,bestCost
            for _, id in ipairs(match.teams[team]) do
                local player = match.squad[id]
                local screen = match.screen
                if id ~= mover.id and id ~= match.carrier and player.role ~= "G"
                    and not humanControls(match,id)
                    and acrossMidfield(match,player,sign) == toAttack
                    and not (screen and (screen.screener == id or screen.user == id)) then
                    local cost = math.abs(player.z) + math.abs(player.x-mover.x)*.13
                    if not midfielder(player) then
                        cost = cost + ((toAttack and player.role == "A"
                            or not toAttack and player.role == "D") and 44 or 25)
                    end
                    if not bestCost or cost < bestCost then best,bestCost=id,cost end
                end
            end
            if best then
                exchange = {mover=mover.id,reserve=best,toAttack=toAttack,untilTime=ai.elapsed+.55}
            end
        end
    end
    tactic.exchange = exchange
    return exchange
end

local function balanceMidfield(match,ai,snapshot,team)
    local sign = attackingSign(match,team)
    local exchange = exchangeAtMidfield(match,ai,snapshot,team,sign)
    local midfielders,nonMidAttack,wanted = {},0,0
    for _, id in ipairs(match.teams[team]) do
        local player,intent = match.squad[id],ai.intents[id]
        local attacking = acrossMidfield(match,player,sign)
        if midfielder(player) then
            local desire = intent.z*sign > 0
            if humanControls(match,id) or id == match.carrier then
                desire = attacking
            end
            if exchange and id == exchange.mover then desire = exchange.toAttack
            elseif exchange and id == exchange.reserve then desire = not exchange.toAttack end
            if desire then wanted = wanted + 1 end
            local priority = (desire and 100 or 0) + (attacking and 6 or 0) - math.abs(player.z)*.27
            if humanControls(match,id) or id == match.carrier then priority = priority + (desire and 180 or -180) end
            if exchange and id == exchange.reserve then priority = priority + (desire and 400 or -400) end
            midfielders[#midfielders+1] = {id=id,priority=priority}
        elseif attacking then
            nonMidAttack = nonMidAttack + 1
        end
    end
    local duringExchange = nonMidAttack
    if exchange then
        local mover = match.squad[exchange.mover]
        local reserve = match.squad[exchange.reserve]
        if exchange.toAttack and not midfielder(mover) then duringExchange = duringExchange + 1 end
        if not exchange.toAttack and not midfielder(reserve)
            and not acrossMidfield(match,reserve,sign) then duringExchange = duringExchange + 1 end
    end
    local maximum = clamp(6-duringExchange,0,#midfielders)
    local minimum = clamp(3-nonMidAttack,0,maximum)
    local selected = clamp(wanted,minimum,maximum)
    table.sort(midfielders,function(a,b)
        return a.priority == b.priority and a.id < b.id or a.priority > b.priority
    end)
    for rank, entry in ipairs(midfielders) do
        local id = entry.id
        local player,intent = match.squad[id],ai.intents[id]
        local front = rank <= selected
        if id ~= match.carrier and not humanControls(match,id) and (intent.z*sign > 0) ~= front then
            local depth = front and (3.3+rank*1.3) or -(3.6+rank*.8)
            local width = math.abs(player.homeX) > 1 and player.homeX*.78 or snapshot.ball.x*.35
            move(intent,width,depth*sign)
            intent.speed = 6.4
            intent.role = front and "MIDFIELD REPLACEMENT" or "MIDFIELD COVER"
            intent.action,intent.target = nil,nil
        end
    end
    if exchange then
        local reserve = match.squad[exchange.reserve]
        local intent = ai.intents[reserve.id]
        local depth = exchange.toAttack and -2.8 or 2.8
        move(intent,reserve.x,depth*sign)
        intent.speed,intent.role = 7.8,"MIDFIELD EXCHANGE"
        intent.lookX,intent.lookZ = snapshot.ball.x,snapshot.ball.z
        intent.action,intent.target = nil,nil
    end
end

local function gait(time, grip, shaft, torso, crouch, roll, freeHand)
    return {
        time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand or 0
    }
end

function AI.registerAnimations()
    local clips = PolyLax.AnimationController.clips
    if clips.saveHighLeft then return end
    for _, side in ipairs({-1,1}) do
        local sideName = side < 0 and "Left" or "Right"
        clips["saveHigh"..sideName] = {
            duration=.46,
            poses={
                gait(.09, vec3(.20*side,.76,-.29), vec3(.68*side,.79,-.14), vec3(-4,11*side,-5*side), .07, -12*side, .15),
                gait(.17, vec3(.37*side,.93,-.38), vec3(.72*side,.73,-.08), vec3(-8,16*side,-11*side), .10, -20*side, .28),
                gait(.30, vec3(.27*side,.72,-.30), vec3(.67*side,.74,-.13), vec3(-2,9*side,-5*side), .04, -6*side, .12)
            }
        }
        clips["saveLow"..sideName] = {
            duration=.50,
            poses={
                gait(.08, vec3(.24*side,.52,-.24), vec3(.73*side,.14,-.45), vec3(-12,9*side,-9*side), .15, -19*side, .20),
                gait(.17, vec3(.39*side,.35,-.38), vec3(.80*side,-.53,-.30), vec3(-23,12*side,-19*side), .35, -19*side, .45),
                gait(.34, vec3(.25*side,.60,-.32), vec3(.82*side,.54,-.03), vec3(-8,6*side,-7*side), .12, -11*side, .13)
            }
        }
    end
end

local function saveStyle(keeper, sample)
    local relative = keeper.rig.body:inverseTransformPoint(sample)
    local side = relative.x < 0 and "Left" or "Right"
    local level = sample.y < .91 and "Low" or "High"
    return "save" .. level .. side
end

local function watchShot(match, ai)
    local flight = match.flight
    if not flight or flight.kind ~= "shot" then
        for _, index in ipairs(match.keepers) do ai.goalies[index] = nil end
        return
    end
    local shooter = match.squad[flight.from]
    local keeperID = match.keepers[3 - shooter.team]
    local keeper = match.squad[keeperID]
    local goal = match.goalsByTeam[shooter.team]
    local ball, velocity = match.ball.position, match.ballVelocity
    if not velocity or math.abs(velocity.z) < 1 then return end
    local travelTime = (keeper.z - ball.z) / velocity.z
    if travelTime < -.08 or travelTime > 1.8 then return end
    local memory = ai.goalies[keeperID]
    if not memory or memory.flight ~= flight then
        local reflexes = P.Attributes.unit(keeper,"reflexes",keeper.reflexes or .76)
        local anticipation = P.Attributes.unit(keeper,"goaliePositioning",keeper.anticipation or .72)
        local distance = math.abs(goal.z-ball.z)
        local delay = clamp(.29 - reflexes*.18 - anticipation*.025 + distance*.002, .085, .31)
        memory = {flight=flight, ready=ai.elapsed+delay}
        ai.goalies[keeperID] = memory
    end
    local wait = math.max(0, travelTime)
    local intercept = vec3(ball.x + velocity.x*wait,
        ball.y + velocity.y*wait - GRAVITY*.5*wait*wait, keeper.z)
    if math.abs(intercept.x-goalX(goal)) > goal.halfWidth + .85
            or intercept.y > goalHeight(goal) + .65 or intercept.y < -.15 then return end
    local intent = ai.intents[keeperID]
    if ai.elapsed >= memory.ready then
        moveKeeper(match, keeper, intent, intercept, wait)
        intent.lookX, intent.lookZ = ball.x, ball.z
        if not memory.actionSent and wait < .42 then
            memory.style = saveStyle(keeper, intercept)
            memory.actionSent = true
            intent.action, intent.style = "save", memory.style
        end
    end
end

local function segmentSphere(a, b, center, radius)
    local difference, offset = b-a, a-center
    local squaredRadius = radius*radius
    if offset:dot(offset) <= squaredRadius then return 0 end
    local lengthSquared = difference:dot(difference)
    if lengthSquared < 1e-10 then return nil end
    local projection = offset:dot(difference)
    if projection >= 0 then return nil end
    local discriminant = projection*projection - lengthSquared*(offset:dot(offset)-squaredRadius)
    if discriminant < 0 then return nil end
    local t = (-projection - math.sqrt(discriminant))/lengthSquared
    if t >= 0 and t <= 1 then return t end
end

function AI.sweepKeeper(match, keeperID, from, to, velocity)
    local keeper = match.squad[keeperID]
    if not keeper then return nil end
    local rate = P.Attributes.unit(keeper,"goaliePositioning",keeper.positioning or .78)
    local hands = P.Attributes.unit(keeper,"handSpeed",keeper.handSpeed or .75)
    local memory = match.ai and match.ai.goalies[keeperID]
    local ready = memory and match.ai.elapsed >= memory.ready
    local best, caught, center = nil, false, nil

    local function consider(point, radius, canCatch)
        local time = segmentSphere(from, to, point, radius + BALL_RADIUS)
        if time and (not best or time < best) then
            best, caught, center = time, canCatch, point
        end
    end

    if ready and keeper.rig.pocket then
        local head = keeper.rig.pocket.worldPosition
        local gap = memory.style and .26 or .18
        local maxCatchSpeed = 14.5 + hands*10 + rate*3
        consider(head, gap + hands*.09, velocity:len() <= maxCatchSpeed)
        local stick = keeper.rig.stickRoot
        if stick then
            consider(stick:transformPoint(vec3(0,.35,0)), .08, false)
            consider(stick:transformPoint(vec3(0,.01,0)), .08, false)
        end
    end
    local block = .33 + rate*.10
    for _, y in ipairs({.55, .92, 1.27, 1.61}) do
        consider(vec3(keeper.x,y,keeper.z), block, false)
    end
    if not best then return nil end
    local point = from + (to-from)*best
    local normal = (point-center):normalize()
    local outward = keeper.team == 1 and -1 or 1
    local rebound = vec3(
        velocity.x*.18 + normal.x*2.8,
        clamp(math.abs(velocity.y)*.24 + .9, .65, 3.6),
        outward*math.max(2.6, math.abs(velocity.z)*.28)
    )
    return {
        t=best, time=best, position=point, caught=caught, velocity=rebound,
        style=memory and memory.style or saveStyle(keeper, point)
    }
end

local function keepOutlet(match, ai)
    local id = match.carrier
    local holder = id and match.squad[id]
    if not holder or holder.role ~= "G" or match.pending or match.flight then return end
    local intent = ai.intents[id]
    local tactic = ai.tactics[holder.team]
    intent.role = "OUTLET"
    if ai.elapsed < (tactic.nextOutlet or 0) then return end
    local target = AI.passTarget(match, id, false)
    if target then
        intent.action, intent.target = "pass", target
        tactic.nextOutlet = ai.elapsed + .9
    else
        local goal = match.goalsByTeam[3 - holder.team]
        local inside = goal.z < 0 and 1 or -1
        move(intent, holder.x < 0 and -3.6 or 3.6, goal.z + inside*3.8)
    end
end

function AI.update(match, dt)
    local ai = match.ai or AI.new()
    match.ai = ai
    ai.elapsed = ai.elapsed + dt
    AI.registerAnimations()
    for id, player in ipairs(match.squad) do
        if not ai.intents[id] then ai.intents[id] = {x=player.x, z=player.z} end
        local intent = ai.intents[id]
        intent.action, intent.target, intent.aim, intent.style = nil, nil, nil, nil
        intent.tactic, intent.moveX, intent.moveZ = nil, nil, nil
    end
    if match.phase ~= "LIVE" then
        ai.nextTick = ai.elapsed
        if ai.phase == "LIVE" then ai.goalies = {} end
        ai.phase = match.phase
        return ai.intents
    end
    if ai.elapsed >= ai.nextTick or ai.phase ~= match.phase then
        local snapshot = updateAwareness(match, ai)
        for _, intent in ipairs(ai.intents) do intent.speed = nil end
        ai.phase = match.phase
        ai.nextTick = ai.elapsed + TACTICAL_INTERVAL
        local attacking = snapshot.possessionTeam
        if attacking then ai.lastTeam = attacking end
        attacking = attacking or ai.lastTeam or 1
        offBallAttack(match, ai, snapshot, attacking)
        defend(match, ai, snapshot, 3-attacking)
        if snapshot.loose then
            assignLoose(match, ai, snapshot, 1)
            assignLoose(match, ai, snapshot, 2)
        elseif snapshot.possessionTeam then
            keepOutlet(match, ai)
        end
        balanceMidfield(match,ai,snapshot,1)
        balanceMidfield(match,ai,snapshot,2)
        for _, intent in ipairs(ai.intents) do restrict(match, intent) end
    end
    watchShot(match, ai)
    return ai.intents
end
end

-- Faceoff
do
-- PolyLax Build 012 | Timing, clamp counters, and draw exits
PolyLax = PolyLax or {}
local P = PolyLax
local Faceoff = {}
P.Faceoff = Faceoff

local difficulties = {
    EASY = {center = .28, spread = .26, technique = -.09, counter = .24},
    NORMAL = {center = .38, spread = .21, technique = 0, counter = .37},
    HARD = {center = .45, spread = .15, technique = .04, counter = .45},
    EXPERT = {center = .46, spread = .09, technique = .08, counter = .50}
}

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function roll(draw)
    draw.randomState = draw.randomState * 48271 % 2147483647
    return draw.randomState / 2147483647
end

local function normalized(value, default)
    value = tonumber(value)
    if not value then return default end
    if value > 1 then value = value / 100 end
    return clamp(value, 0, 1)
end

local function contestant(player, human)
    local rating = normalized(player and player.faceoffRating,P.Attributes.unit(player,"faceoff",.65))
    local stamina = normalized(player and player.stamina,P.Attributes.unit(player,"stamina",1))
    local fatigue = player and player.faceoffFatigue
    return {
        id = player and player.id,
        rating = rating,
        stamina = clamp(stamina-normalized(fatigue,0),0,1),
        human = human
    }
end

local function scheduleCPU(draw, athlete, difficulty)
    if athlete.human then return end
    local variation = roll(draw) + roll(draw) - 1
    local edge = (athlete.rating - .65) * .15 + (athlete.stamina - 1) * .12
    athlete.cpuTiming = clamp(difficulty.center + variation * difficulty.spread + edge, .06, .96)
    athlete.cpuAction = roll(draw) < difficulty.counter and "counter" or "clamp"
    athlete.technique = difficulty.technique
end

function Faceoff.new(options, homePlayer, awayPlayer, serial, userTeam)
    options = options or {}
    if userTeam == nil then userTeam = 1 end
    local difficultyName = tostring(options.difficulty or "NORMAL"):upper()
    local difficulty = difficulties[difficultyName] or difficulties.NORMAL
    local setTime = clamp(tonumber(options.setTime) or .64, .20, 2.0)
    local duration = clamp(tonumber(options.duration) or .54, .26, 1.6)
    local draw = {
        active = true, phase = "SET", elapsed = 0, phaseTime = 0,
        meter = 0, windowStart = .23, windowEnd = .69, sweetSpot = .46,
        cpuMeter = 0, userTeam = userTeam,
        setTime = setTime, duration = duration,
        exitTime = clamp(tonumber(options.exitTime) or .30, .12, .80),
        randomState = (math.floor(tonumber(serial) or 1) * 12648430 + 38047) % 2147483646 + 1,
        home = contestant(homePlayer, userTeam == 1),
        away = contestant(awayPlayer, userTeam == 2)
    }
    scheduleCPU(draw, draw.home, difficulty)
    scheduleCPU(draw, draw.away, difficulty)
    return draw
end

function Faceoff.input(draw, action)
    if not draw.active or not draw.userTeam then return false end
    if draw.phase ~= "SET" and draw.phase ~= "DRAW" then return false end
    if action == "faceoff" then action = "clamp" end
    if action ~= "clamp" and action ~= "counter" then return false end
    local athlete = draw.userTeam == 1 and draw.home or draw.away
    if athlete.action then return false end
    athlete.action = action
    athlete.timing = (draw.elapsed - draw.setTime) / draw.duration
    return true
end

local function performCPU(athlete, meter)
    if not athlete.human and not athlete.action and meter >= athlete.cpuTiming then
        athlete.action, athlete.timing = athlete.cpuAction, athlete.cpuTiming
    end
end

local function timingQuality(draw, athlete)
    if not athlete.action or athlete.timing < 0 then return 0 end
    local error = math.abs(athlete.timing - draw.sweetSpot)
    return clamp(1 - error * 1.7, 0, 1)
end

local function score(athlete, opponent, quality)
    if quality == 0 then return 0 end
    local counterAdvantage = 0
    if athlete.action == "counter" and opponent.action == "clamp" then
        counterAdvantage = .14 * quality - .027
    elseif athlete.action == "counter" then
        counterAdvantage = -.035
    end
    return quality * .72 + athlete.rating * .18 + athlete.stamina * .10
        + counterAdvantage + (athlete.technique or 0)
end

local function resolve(draw)
    local home, away = draw.home, draw.away
    local homeQuality, awayQuality = timingQuality(draw, home), timingQuality(draw, away)
    local homeScore, awayScore = score(home, away, homeQuality), score(away, home, awayQuality)
    local homeViolation = home.action ~= nil and home.timing < 0
    local awayViolation = away.action ~= nil and away.timing < 0
    local advantage = homeScore - awayScore
    local winner, cause
    if homeViolation ~= awayViolation then
        winner, cause = homeViolation and 2 or 1, "FALSE_START"
    elseif homeScore == 0 and awayScore == 0 then
        cause = "CONTESTED"
    elseif math.abs(advantage) < .083 then
        cause = "CONTESTED"
    else
        winner, cause = advantage > 0 and 1 or 2, "CLEAN"
    end
    draw.result = {
        winner = winner, loose = winner == nil, cause = cause,
        homeId = home.id, awayId = away.id,
        homeAction = home.action, awayAction = away.action,
        homeTiming = home.timing, awayTiming = away.timing,
        homeQuality = homeQuality, awayQuality = awayQuality,
        homeScore = homeScore, awayScore = awayScore
    }
    draw.phase = "EXIT"
end

local function readExit(draw, moveX, moveZ)
    -- Store the latest deliberate direction during the steering window.
    local x, z = moveX or 0, moveZ or 0
    local magnitude = math.sqrt(x * x + z * z)
    if draw.result.winner == draw.userTeam and magnitude > .17 then
        local scale = math.max(1, magnitude)
        draw.moveX, draw.moveZ = x / scale, z / scale
    end
end

local function complete(draw)
    local result = draw.result
    local flank = roll(draw) < .5 and -1 or 1
    result.moveX, result.moveZ = draw.moveX, draw.moveZ
    if result.loose then
        -- An even clamp squirts sideways for a contested wing pickup.
        result.exitX, result.exitZ = flank, (roll(draw) - .5) * .48
    elseif draw.moveX then
        result.exitX, result.exitZ = draw.moveX, -draw.moveZ
    else
        -- Unsteered exits progress a little into the attacking half.
        result.exitX, result.exitZ = flank * .56, result.winner == 1 and -.72 or .72
    end
    draw.active, draw.phase, draw.phaseTime = false, "COMPLETE", 0
    return result
end

function Faceoff.update(draw, dt, moveX, moveZ)
    if not draw.active or dt <= 0 then return end
    draw.elapsed = draw.elapsed + dt
    if draw.phase == "SET" then
        draw.phaseTime = draw.elapsed
        if draw.elapsed < draw.setTime then return end
        draw.phase = "DRAW"
    end
    if draw.phase == "DRAW" then
        draw.phaseTime = draw.elapsed - draw.setTime
        draw.meter = clamp(draw.phaseTime / draw.duration, 0, 1)
        performCPU(draw.home, draw.meter)
        performCPU(draw.away, draw.meter)
        local cpu = draw.userTeam == 2 and draw.home or draw.away
        draw.cpuMeter = math.min(draw.meter, cpu.cpuTiming or 1)
        if draw.phaseTime < draw.duration then return end
        resolve(draw)
    end
    draw.phaseTime = draw.elapsed - draw.setTime - draw.duration
    readExit(draw, moveX, moveZ)
    if draw.phaseTime >= draw.exitTime then return complete(draw) end
end

function Faceoff.cancel(draw)
    draw.active, draw.phase, draw.phaseTime, draw.result = false, "CANCELLED", 0, nil
end

local function frame(time, grip, shaft, torso, crouch, roll, freeHand)
    return {time=time, grip=grip, shaft=shaft, torso=torso,
        crouch=crouch, roll=roll, freeHand=freeHand}
end

function Faceoff.registerAnimations(animation)
    local clips = animation.clips
    if clips.faceoffClamp then return end
    clips.faceoffClamp = {
        duration = .23,
        poses = {
            frame(.075, vec3(.35,.32,-.31), vec3(.23,-.32,-.92), vec3(-23,-5,-6), .19,-5,.45),
            frame(.145, vec3(.38,.27,-.34), vec3(.09,-.43,-.90), vec3(-30,-4,-8), .30,22,.57)
        }
    }
    clips.faceoffCounter = {
        duration = .24,
        poses = {
            frame(.070, vec3(.34,.35,-.26), vec3(.30,-.24,-.92), vec3(-22,-12,-9), .17,-14,.38),
            frame(.165, vec3(.20,.40,-.32), vec3(-.36,-.30,-.88), vec3(-26,17,9), .25,-37,.64)
        }
    }
end
end

-- MatchRules
do
-- PolyLax 3.0 | Men's field match rules and live ball clocks
PolyLax = PolyLax or {}
local P = PolyLax
local Rules = {}
P.MatchRules = Rules

local profiles = {
    arcade = {name="Arcade testing",periodLength=90},
    highSchool = {name="High school (NFHS 2027)",periodLength=720,ageGroup="highSchool",
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClockStartsAfterClear=true,optionalShotClock=70},
    ncaa = {name="NCAA men's field",periodLength=900,
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClock=80,shotRecovery=60},
    collegeClub = {name="MCLA college club",periodLength=900,
        clearClock=20,clearAtDeadline=true,creaseClock=4,shotClock=80,shotRecovery=60},
    professional = {name="Professional men's field",periodLength=720,
        clearClock=20,creaseClock=4,shotClock=52,faceoffShotClock=32,shotRecovery=32,recoveryThreshold=32,
        fieldMetrics={fieldLengthYards=100,wingFromCenterYards=19}},
}

local function limit(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.max(low, math.min(high, value))
end

local function seconds(value, fallback)
    if value == false or tonumber(value) == 0 then return nil end
    if value == nil and fallback == nil then return nil end
    if not tonumber(value) and fallback == nil then return nil end
    return limit(value, fallback, .1, 120)
end

function Rules.configure(options)
    options = options or {}
    local id = options.profile or options.ruleset
    if not profiles[id] then id = "arcade" end
    local defaults = profiles[id]
    local age = options.ageGroup or defaults.ageGroup
    local body = options.bodyContact
    if body == nil and age == "highSchool" and id == "highSchool" then body = true end
    local ageGroup, bodyContact = P.Defense.configure({ageGroup=age,bodyContact=body})
    local faceoff = type(options.faceoff) == "table" and options.faceoff or {}
    local shotClock = defaults.shotClock
    if options.stateShotClock == true then shotClock = defaults.optionalShotClock or shotClock end
    local startsAfterClear = options.shotClockStartsAfterClear
    if startsAfterClear == nil then startsAfterClear = defaults.shotClockStartsAfterClear end
    local fieldMetrics = {}
    for key, value in pairs(defaults.fieldMetrics or {}) do fieldMetrics[key] = value end
    for key, value in pairs(options.fieldMetrics or {}) do fieldMetrics[key] = value end
    return {
        profile=id, name=options.name or defaults.name,
        periods=math.floor(limit(options.periods, 4, 1, 8)),
        periodLength=limit(options.periodLength, defaults.periodLength, 1, 900),
        intermissionTime=limit(options.intermissionTime, 2.4, .4, 12),
        goalTime=limit(options.goalTime, 1.7, .6, 5),
        foulTime=limit(options.foulTime, 1.05, .4, 5),
        ageGroup=ageGroup, bodyContact=bodyContact,
        shotClock=seconds(options.shotClock, shotClock),
        clearClock=seconds(options.clearClock, defaults.clearClock),
        clearAtDeadline=defaults.clearAtDeadline == true,
        creaseClock=seconds(options.creaseClock, defaults.creaseClock),
        shotClockStartsAfterClear=startsAfterClear == true,
        faceoffShotClock=seconds(options.faceoffShotClock, defaults.faceoffShotClock),
        shotRecovery=seconds(options.shotRecovery, defaults.shotRecovery),
        recoveryThreshold=seconds(options.recoveryThreshold, defaults.recoveryThreshold),
        overAndBack=id ~= "arcade" and options.overAndBack ~= false,
        shotBoundary=options.shotBoundary or (id == "arcade" and "lastTouch" or "nearest"),
        maxLongPoles=math.floor(limit(options.maxLongPoles, 4, 0, 4)),
        fieldMetrics=fieldMetrics,
        faceoff={difficulty=faceoff.difficulty or options.faceoffDifficulty,
            setTime=faceoff.setTime, duration=faceoff.duration, exitTime=faceoff.exitTime},
    }
end

function Rules.reset(match)
    match.ruleClock = {}
end

function Rules.stop(match)
    Rules.reset(match)
end

local function inOffensiveHalf(match, team, z)
    return P.Midfield.halfAt(match, team, z) == "offense"
end

local function insideOwnCrease(match, team, x, z)
    local goal = match.goalsByTeam and match.goalsByTeam[3-team]
    local radius = match.field and match.field.creaseRadius
    return goal and radius and (x-goal.x)^2 + (z-goal.z)^2 < radius^2
end

local function start(match, holder, shot, source)
    local rules = match.rules
    local team = holder.team
    local needsClear = not inOffensiveHalf(match,team,holder.z)
    local clearing = needsClear or rules.clearAtDeadline and source ~= "rebound"
    match.ruleClock = {
        team=team, shot=shot, clear=needsClear and rules.clearClock or nil,
        advanceTime=clearing and rules.clearClock or nil, ballOver=not needsClear,
        waitingForClear=needsClear and rules.shotClockStartsAfterClear or nil,
        faceoffReturn=not needsClear and rules.profile == "professional"
            and source == "faceoff" and holder.id or nil,
        lastHolder=holder.id,
    }
    if match.ruleClock.waitingForClear then match.ruleClock.shot = nil end
end

function Rules.possession(match, index, source)
    local holder = match.squad[index]
    local clock, rules = match.ruleClock or {}, match.rules
    local team = holder.team
    if clock.team ~= team or clock.expired or source == "faceoff" then
        local initialShot = rules.shotClock
        if initialShot and source == "faceoff" then
            initialShot = math.min(initialShot, rules.faceoffShotClock or initialShot)
        end
        start(match,holder,initialShot,source)
    elseif clock.validShot then
        local shot = rules.shotClock
        if shot and inOffensiveHalf(match,team,holder.z) then
            shot = clock.recoveryShot
        end
        start(match,holder,shot,"rebound")
    else
        if clock.crease and not insideOwnCrease(match,team,holder.x,holder.z) then clock.crease = nil end
        if clock.faceoffReturn ~= holder.id and inOffensiveHalf(match,team,holder.z) then
            clock.faceoffReturn = nil
        end
        if source == "restart" then clock.ballOver = inOffensiveHalf(match,team,holder.z) end
        clock.lastHolder = holder.id
    end
end

function Rules.shotReleased(match, flight)
    local clock = match.ruleClock
    if clock and clock.team == flight.team and flight.kind == "shot" then
        flight.ruleShotTime = clock.shot
    end
end

function Rules.shotContact(match, flight, kind)
    local clock, rules = match.ruleClock, match.rules
    if not clock or clock.team ~= flight.team or clock.expired or not clock.shot
        or flight.kind ~= "shot" or (kind ~= "SAVE" and kind ~= "POST" and kind ~= "CROSSBAR") then
        return
    end
    -- An attempt from behind the goal line does not reset the timer.
    local goal = flight.goal
    if goal and (flight.origin.z-goal.z)*goal.attackSign > 0 then return end
    local shotAt = flight.ruleShotTime or clock.shot + (flight.time or 0)
    local reset = rules.shotRecovery or rules.shotClock
    if rules.recoveryThreshold and shotAt > rules.recoveryThreshold then reset = rules.shotClock end
    clock.validShot, clock.recoveryShot = true, math.min(reset, rules.shotClock)
    clock.shot = clock.recoveryShot
end

local function expire(clock, reason)
    clock.expired = true
    return {reason=reason,team=clock.team,player=clock.lastHolder}
end

local function advance(match, clock, rules, holder, ball, flight, dt)
    local side = P.Midfield.halfAt(match,clock.team,holder and holder.z or ball.z)
    local inOffense = side == "offense"
    if clock.advanceTime then
        clock.advanceTime = math.max(0,clock.advanceTime-dt)
        if clock.advanceTime == 0 or inOffense and not rules.clearAtDeadline then
            if not inOffense then return "clearClock" end
            clock.advanceTime = nil
        end
        clock.clear = not inOffense and clock.advanceTime or nil
    end
    if inOffense then
        clock.ballOver = true
        if clock.waitingForClear then clock.shot = rules.shotClock end
        clock.waitingForClear = nil
    elseif side == "defense" and clock.ballOver then
        clock.ballOver = false
        local ownAction = holder or flight and flight.team == clock.team or match.lastTouch == clock.team
        local fromShot = match.boundaryShot or flight and flight.kind == "shot"
        if rules.overAndBack and not clock.advanceTime and ownAction and not fromShot then
            if clock.faceoffReturn then clock.faceoffReturn = nil
            else return "overAndBack" end
        end
    end
end

function Rules.tick(match, dt)
    if match.phase ~= "LIVE" or dt <= 0 then return end
    local holder = match.carrier and match.squad[match.carrier]
    local clock, rules = match.ruleClock, match.rules
    -- Synchronize when explicit simulation setup supplied the first carrier.
    if holder and (not clock or clock.team ~= holder.team) then
        Rules.possession(match,holder.id)
        clock = match.ruleClock
    end
    if not clock or not clock.team or clock.expired or clock.validShot then return end

    local ball = match.ball.position
    local flight = match.flight
    local violation = advance(match,clock,rules,holder,ball,flight,dt)
    if violation then return expire(clock,violation) end

    if rules.creaseClock then
        if holder and insideOwnCrease(match,clock.team,holder.x,holder.z) then
            clock.crease = math.max(0,(clock.crease or rules.creaseClock)-dt)
            if clock.crease == 0 then return expire(clock,"creaseClock") end
        elseif holder or not (flight and flight.kind == "pass" and flight.team == clock.team
            and insideOwnCrease(match,clock.team,ball.x,ball.z)) then
            clock.crease = nil
        end
    end

    if clock.shot then
        clock.shot = math.max(0,clock.shot-dt)
        if clock.shot == 0 then
            -- Let a released attempt reach the goal or keeper before ruling it late.
            if flight and flight.kind == "shot" and flight.team == clock.team
                and (flight.ruleShotTime or 0) > 0 and flight.time < flight.duration then return end
            return expire(clock,"shotClock")
        end
    end
end
end

-- FullMatch
do
-- PolyLax Build 013 | FullMatch
PolyLax = PolyLax or {}
local P = PolyLax
local Match = {}
P.FullMatch = Match

local ballRadius, gravity = .09, 9.8
local userPlayer = 4
local atan2 = math.atan2 or math.atan
local formation = {
    {"A", 1, -13, 29}, {"A", 2, 13, 29}, {"A", 3, 0, 43},
    {"M", 1, 0, 0}, {"M", 2, -18.288, 3}, {"M", 3, 18.288, 3},
    {"D", 1, -12, -24}, {"D", 2, 12, -24}, {"D", 3, 0, -29},
    {"G", 1, 0, -35.2}
}

local function clamp(value, low, high)
    return math.max(low, math.min(value, high))
end

local function distance(x, z)
    return math.sqrt(x * x + z * z)
end

local function directionFor(team)
    return team == 1 and -1 or 1
end

local function yawFor(x, z)
    return math.deg(atan2(-x, -z))
end

local function announce(match, text, seconds)
    match.announcement, match.announcementTime = text, seconds or 1.3
end

local function pocket(player)
    return player.rig.pocket.worldPosition
end

local function newStats()
    return {goals=0, score=0, shots=0, shotsOnGoal=0, saves=0, passes=0,
        completions=0, groundBalls=0, faceoffs=0, checks=0, turnovers=0,
        pokes=0, slaps=0, bodyChecks=0, interceptions=0, forcedTurnovers=0, fouls=0,
        faceoffAttempts=0, faceoffViolations=0, faceoffScrambles=0}
end

function Match.recordStat(match, index, key, amount, detail)
    local player = match.squad[index]
    if not player then return end
    local team = match.stats[player.team]
    local increment = amount or 1
    if not (match.careerWaiting and index == match.careerPlayer) then
        player.stats[key] = (player.stats[key] or 0) + increment
    end
    team[key] = (team[key] or 0) + increment
    -- These outcomes use possession/keeper classification at their sources.
    if key ~= "turnovers" and key ~= "forcedTurnovers" and key ~= "saves" then
        P.Statistics.record(match,index,key,increment,detail)
    end
end

local screenEvaluation = {screens=2, screenAssists=3, screenOpenShots=2, illegalScreens=-4}

local function screenStat(match, index, key, detail)
    Match.recordStat(match,index,key,1,detail)
    local points = screenEvaluation[key]
    if not points then return end
    Match.recordStat(match,index,"screenCoachPoints",points)
    if match.careerWaiting and index==match.careerPlayer then return end
    local events = match.squad[index].screenCoachEvents
    events[#events+1] = {kind=key,points=points,time=match.elapsed,
        user=detail and detail.user,defender=detail and detail.defender}
end

local screenFoul

local function makeBall(scene)
    local ball = scene:entity()
    ball.model = craft.model.icosphere(ballRadius, 1, true)
    local materials = asset and asset.builtin and asset.builtin.Materials
    ball.material = craft.material(materials and materials.Standard or "Materials:Standard")
    ball.material.diffuse = color(255, 211, 66)
    return ball
end

local function makeMarker(scene)
    local marker = scene:entity()
    local cube = craft.model.cube()
    local materials = asset and asset.builtin and asset.builtin.Materials
    local tint = craft.material(materials and materials.Standard or "Materials:Standard")
    tint.diffuse = color(43, 166, 255)
    for side = 1, 14 do
        local angle = side * math.pi / 7
        local part = scene:entity()
        part.parent = marker
        part.model, part.material = cube, tint
        part.position = vec3(.68 * math.sin(angle), .025, .68 * math.cos(angle))
        part.scale = vec3(.31, .014, .045)
        part.eulerAngles = vec3(0, math.deg(angle), 0)
    end
    return marker
end

local function playerProfile(team, slot)
    return {
        FACE = (slot + team - 2) % 4 + 1, HAIR = (slot + team) % 5 + 1,
        BODY = slot == 10 and 3 or slot % 4 + 1, HELMET = 1, STICK = 4,
        NUMBER = slot + (team == 1 and 8 or 18), SHORTS = 4, CLEATS = 1
    }
end

local function place(player)
    player.rig.root.position = vec3(player.x, 0, player.z)
    player.rig.root.eulerAngles = vec3(0, player.yaw, 0)
end

local function careerLock(match)
    local id = match.playerId or match.careerPlayer
    if type(id) == "table" then id = id.id end
    if type(id) == "number" and match.squad[id] then return id end
end

local function humanControls(match, index)
    if match.humans then return match.humans[index] ~= nil end
    return index == match.controlled and not match.careerWaiting
end

local function attach(match, index, select, source)
    local player = match.squad[index]
    P.Statistics.possession(match,index)
    local draw = match.faceoffScramble
    if draw then
        local contestant = player.team == 1 and draw.homeId or draw.awayId
        Match.recordStat(match, contestant, "faceoffs")
        match.faceoffScramble = nil
        source = "faceoff"
    end
    match.carrier, match.lastTouch, match.assist = index, player.team, nil
    match.flight, match.loose, match.pending = nil, nil, nil
    match.scoopPlayer, match.boundaryShot = nil, nil
    match.ball.position = pocket(player)
    match.ballVelocity = vec3()
    P.MatchRules.possession(match,index,source)
    if select and player.team == 1 and not careerLock(match) then match.controlled = index end
    if match.mode == "SWING" then match.mode = "SET" end
end

local function freeBall(match, position, velocity, lastTouch, fromShot)
    match.carrier, match.flight, match.pending, match.scoopPlayer = nil, nil, nil, nil
    match.loose, match.lastTouch, match.assist = true, lastTouch, nil
    match.boundaryShot = fromShot or nil
    match.ball.position, match.ballVelocity = position, velocity
    if match.mode == "SWING" then match.mode = "SET" end
end

local function startFaceoff(match)
    P.Statistics.resetPossession(match)
    P.MatchRules.stop(match)
    local afterPeriod = match.phase == "INTERMISSION"
    P.Screens.reset(match)
    match.tactical, match.cut, match.swingDirection = nil, nil, nil
    match.assist = nil
    match.phase, match.phaseTime = "FACEOFF", 0
    match.mode, match.clearTime = "SET", 0
    match.pending, match.flight, match.loose, match.carrier = nil, nil, nil, nil
    match.scoopPlayer, match.lastTouch, match.inNet, match.boundaryShot = nil, nil, nil, nil
    match.foul = nil
    match.faceoffScramble = nil
    local first = match.squad[match.teams[1][4]]
    local second = match.squad[match.teams[2][4]]
    local locked = careerLock(match)
    match.controlled = locked or first.id
    match.faceoffSerial = match.faceoffSerial + 1
    if afterPeriod then
        first.faceoffFatigue = math.max(0, first.faceoffFatigue - .15)
        second.faceoffFatigue = math.max(0, second.faceoffFatigue - .15)
    end
    local humanDraw = not locked or locked == first.id and not match.careerWaiting
    if match.humans then humanDraw = humanControls(match,first.id) end
    match.faceoff = P.Faceoff.new(match.rules.faceoff, first, second, match.faceoffSerial,
        humanDraw and 1 or false)
    local reset = P.AnimationController.reset
    for _, player in ipairs(match.squad) do
        player.x, player.z = player.homeX, player.homeZ
        player.vx, player.vz, player.speed, player.turn = 0, 0, 0, 0
        player.dodge, player.check, player.checkCooldown = nil, nil, 0
        player.faceoffExit = nil
        player.yaw = player.team == 1 and 0 or 180
        if player.role == "G" then player.yaw = (player.yaw + 180) % 360 end
        if player.slot == 4 then player.z = -.62 * directionFor(player.team) end
        place(player)
        reset(player.anim)
    end
    P.Midfield.reset(match)
    match.ball.position, match.ballVelocity = vec3(0, ballRadius, 0), vec3()
    for _, goal in ipairs(match.goalsByTeam) do P.GoalPhysics.reset(goal) end
    match.marker.position = match.squad[match.controlled].rig.root.position
    announce(match, "FACEOFF", match.faceoff.setTime)
end

local function resetMatch(match)
    match.homeScore, match.awayScore = 0, 0
    match.lastGoalScorer,match.lastGoalTeam=nil,nil
    match.period, match.clock, match.elapsed = 1, match.rules.periodLength, 0
    match.stats = {newStats(), newStats()}
    match.faceoffSerial = 0
    match.careerWaiting = match.careerEntryDelay and match.careerEntryDelay > 0
    for _, player in ipairs(match.squad) do
        player.stats, player.screenCoachEvents = newStats(), {}
        player.runningFatigue = 0
        player.faceoffFatigue = 0
    end
    match.ai = P.MatchAI.new()
    P.Statistics.new(match,match.statisticsOptions)
    P.MatchRules.reset(match)
    startFaceoff(match)
end

local function applyTeamKits(match, homeId, awayId)
    local homeKit, awayKit, homeTeam, awayTeam
    if match.venueAway then
        awayKit, homeKit, awayTeam, homeTeam = P.TeamUniform.matchKits(awayId, homeId)
    else
        homeKit, awayKit, homeTeam, awayTeam = P.TeamUniform.matchKits(homeId, awayId)
    end
    match.homeTeam, match.awayTeam = homeTeam, awayTeam
    match.homeId, match.awayId = homeTeam.id, awayTeam.id
    match.kits = {homeKit, awayKit}
end

function Match.applyProfile(match, profile, homeId, awayId)
    applyTeamKits(match, homeId or match.homeId, awayId or match.awayId)
    for index, player in ipairs(match.squad) do
        local kit = match.kits[player.team]
        if index == (match.careerPlayer or userPlayer) then
            P.Character.apply(player.rig, profile, nil, kit, false)
            player.number = player.rig.numberValue
        else
            P.Character.applyUniform(player.rig, kit, false)
        end
    end
end

function Match.new(scene, profile, homeId, awayId, rules)
    rules = rules or {}
    local settings = P.MatchRules.configure(rules)
    local venue = P.TeamUniform.get(rules.fieldTeam or homeId)
    local field = P.Field.new(scene, venue.field, settings.fieldMetrics)
    local homeGoal = field.goals[1]
    local match = {
        field=field, venueAway=rules.venueAway == true, goalsByTeam=field.goals, goal=vec3(homeGoal.x, homeGoal.top * .5, homeGoal.z),
        ball=makeBall(scene), marker=makeMarker(scene), squad={}, teams={{},{}}, keepers={}, rules=settings
    }
    match.humans, match.playerId = rules.humans, rules.playerId
    match.statisticsOptions = rules.statistics
    match.movementProposals = {}
    local slot = rules and tonumber(rules.careerPlayerSlot)
    if slot then
        match.careerPlayer = clamp(math.floor(slot), 1, 10)
        match.careerEntryDelay = clamp(tonumber(rules.careerEntryDelay) or 0, 0,
            math.min(10,match.rules.periodLength*.3))
    end
    P.MatchAI.registerAnimations()
    P.Defense.registerAnimations()
    P.Screens.registerAnimations()
    P.Faceoff.registerAnimations(P.AnimationController)
    applyTeamKits(match, homeId, awayId)
    for team = 1, 2 do
        local side = directionFor(team)
        local roster=P.League and P.League.roster(team==1 and match.homeId or match.awayId)
        for slot, spec in ipairs(formation) do
            local index = #match.squad + 1
            local rig = P.Character.new(scene)
            local human = match.humans and match.humans[index]
            local custom = human or not match.humans and index==(match.careerPlayer or userPlayer)
            local appearance = human and human.appearance or custom and profile or playerProfile(team,slot)
            local member = roster and roster[slot]
            local role = spec[1]
            local chosenRole = human and human.role or index == match.careerPlayer and rules.careerPlayerRole
            if role == "M" and (chosenRole == "LSM" or chosenRole == "SSDM") then
                role = chosenRole
            end
            local long = role == "D" and slot-6 <= settings.maxLongPoles
                or role == "LSM" and settings.maxLongPoles >= 4
            P.Character.setStickType(rig, long and "long" or "short")
            if member and not custom then appearance.NUMBER=member.number+1 end
            P.Character.apply(rig, appearance, nil, match.kits[team], false)
            local homeDepth = spec[1] == "G" and -(field.goalZ-1.4) or spec[4]
            local homeX = (slot == 5 and -field.wingX) or (slot == 6 and field.wingX) or spec[3]
            local player = {
                id=index, team=team, slot=slot, role=role, stickType=rig.stickType,
                name=member and not custom and member.name or spec[1]..spec[2],
                rig=rig, anim=P.AnimationController.new(rig), number=rig.numberValue,
                homeX=homeX * -side, homeZ=clamp(homeDepth,-field.halfLength*.96,field.halfLength*.96) * side,
                attributes=P.Defense.attributes(role)
            }
            if slot == 4 then player.attributes.faceoff = .68 end
            if human then
                player.name = human.name or player.name
                for key, value in pairs(human.attributes or {}) do
                    if type(value) == "number" then player.attributes[key] = value end
                end
            end
            if index == match.careerPlayer then
                player.name = rules.playerName or player.name
                for key, value in pairs(rules.playerAttributes or {}) do
                    if type(value) == "number" then player.attributes[key] = value end
                end
            end
            match.squad[index] = player
            match.movementProposals[index] = {}
            match.teams[team][slot] = index
            if player.role == "G" then match.keepers[team] = index end
        end
    end
    match.screenStat = function(id,key,detail) screenStat(match,id,key,detail) end
    match.screenCallbacks = {stat=match.screenStat,
        foul=function(id,defender) screenFoul(match,id,defender) end}
    resetMatch(match)
    return match
end

local function startPass(match, player, plan, mode)
    if type(plan) == "number" then plan = P.Passing.forTarget(match,plan) end
    if player.id ~= match.carrier or match.pending or not plan or not plan.point then return false end
    if plan.from and plan.from ~= player.id then return false end
    if plan.to then
        local teammate = match.squad[plan.to]
        if not teammate or teammate == player or teammate.team ~= player.team then return false end
    end
    if not P.AnimationController.play(player.anim,"pass") then return false end
    match.pending = {kind="pass",from=player.id,to=plan.to,point=plan.point,play=mode}
    match.mode = mode or "SET"
    return true
end

local function startShot(match, player, aim)
    if player.id == match.carrier and not match.pending
        and P.AnimationController.play(player.anim, "shoot") then
        match.pending = {kind="shot", from=player.id, aim=aim}
    end
end

local function startDodge(player, moveX, moveZ)
    local agility = P.Attributes.rating(player,"agility",60)-60
    if not P.AnimationController.play(player.anim, "dodge", 1+agility*.004) then return end
    local x, z = moveX or 0, -(moveZ or 0)
    local length = distance(x, z)
    if length < .12 then
        local yaw = math.rad(player.yaw)
        x, z, length = math.cos(yaw), -math.sin(yaw), 1
    end
    player.dodge = {x=x / length, z=z / length, time=.29, agility=agility}
end

local function startCheck(match, player, style)
    if player.check then return end
    player.check = P.Defense.request(match, player, style)
end

local function startScoop(match, player)
    if match.scoopPlayer or not match.loose then return end
    local ball = match.ball.position
    local ground = P.Attributes.rating(player,"groundBalls",65)-65
    if ball.y <= .28 and distance(ball.x - player.x, ball.z - player.z) <= 1.12+ground*.005
        and distance(match.ballVelocity.x, match.ballVelocity.z) <= 4
        and P.AnimationController.play(player.anim, "scoop", 1+ground*.0038) then
        match.scoopPlayer = player.id
    end
end

function Match.canAim(match)
    return not match.careerWaiting and match.phase == "LIVE" and match.carrier == match.controlled
        and not match.pending and not match.squad[match.controlled].anim.action
end

function Match.aimContext(match)
    if not Match.canAim(match) then return nil end
    return pocket(match.squad[match.controlled]), match.goalsByTeam[1]
end

function Match.passPreview(match, dx, dz)
    if Match.canAim(match) then return P.Passing.select(match,match.carrier,dx,dz) end
end

local calls = {swing="SWING",clear="CLEAR",passdown="PASS DOWN",pickdown="PICK DOWN"}

local function startPick(match, holder, screener)
    local defender = P.Tactics.defender(match,holder.id)
    if screener then
        if screener == holder or screener.role == "G" then return false end
        local mark = defender and match.squad[defender]
        if not mark or distance(mark.x-screener.x,mark.z-screener.z) > 3.4 then
            announce(match,"MOVE NEAR A DEFENDER")
            return false
        end
        local screen = P.Screens.request(match,screener.id,holder.id,defender,
            {x=screener.x,z=screener.z,manual=true})
        if screen then announce(match,"SET YOUR FEET") end
        return screen ~= nil
    end

    local detail = P.Tactics.pick(match,holder.id,defender)
    if detail and P.Screens.request(match,detail.screener,holder.id,defender,detail) then
        P.Tactics.activate(match,detail,"PICK DOWN",holder.team)
        match.mode = "PICK DOWN"
        announce(match,"PICK DOWN")
        return true
    end
    announce(match,"NO SCREEN AVAILABLE")
    return false
end

local function callTactic(match, holder, call)
    if call == "PICK DOWN" then return startPick(match,holder) end
    if match.pending or match.flight then return false end
    local receiver, detail = P.Tactics.choose(match,holder.id,call)
    if receiver and startPass(match,holder,receiver,call) then
        P.Tactics.activate(match,detail,call,holder.team)
        announce(match,call)
        return true
    end
    if call == "CLEAR" then
        match.mode, match.clearTime = "CLEAR", 3.5
        P.Tactics.activate(match,{},"CLEAR",holder.team,3.5)
        announce(match,"CLEAR · OUTLETS COVERED")
    else
        announce(match,call .. " · LANE COVERED")
    end
    return false
end

local function nextPlayer(match)
    local selected, closest = match.controlled, math.huge
    local ball = match.ball.position
    local holder = match.carrier and match.squad[match.carrier]
    if holder and holder.team == 1 and holder.id ~= selected then return holder.id end
    for _, index in ipairs(match.teams[1]) do
        local player = match.squad[index]
        if index ~= match.controlled then
            local length = distance(player.x - ball.x, player.z - ball.z)
            if length < closest then selected, closest = index, length end
        end
    end
    return selected
end

function Match.command(match, action, moveX, moveZ, aim, actorId)
    if action == "reset" then
        resetMatch(match)
        return
    end
    if match.careerWaiting then return end
    local controlled = actorId or match.controlled
    if match.phase == "FACEOFF" then
        if match.humans and controlled ~= match.faceoff.home.id then return end
        if action == "pass" or action == "shoot" then action = "clamp" end
        if P.Faceoff.input(match.faceoff, action) and match.faceoff.phase == "SET" then
            announce(match, "FALSE START")
        end
        return
    end
    if match.phase ~= "LIVE" then return end

    local player = match.squad[controlled]
    local holder = match.carrier and match.squad[match.carrier]
    if action == "switch" then
        if not careerLock(match) then match.controlled = nextPlayer(match) end
    elseif calls[action] then
        if holder and holder.team==1 then return callTactic(match,holder,calls[action]) end
    elseif action == "setpick" then
        if holder and holder.team==1 then return startPick(match,holder,player) end
    elseif action == "releasepick" then
        return P.Screens.endHold(match,player.id,moveX or 0,-(moveZ or 0))
    elseif action == "dodge" then
        if holder and holder.team ~= 1 then startCheck(match, player, "poke")
        else startDodge(player, moveX, moveZ) end
    elseif action == "check" or P.Defense.checks[action] then
        startCheck(match, player, action)
    elseif action == "scoop" then
        startScoop(match, player)
    elseif action == "shoot" then
        if holder == player then startShot(match, player, aim) end
    elseif action == "pass" then
        if not holder or holder.team ~= 1 then return end
        if player ~= holder then
            if match.humans and humanControls(match,holder.id) then
                if not aim then announce(match,player.name .. " CALLS FOR PASS") end
                return
            end
            if not aim then return startPass(match,holder,player.id) end
            return
        end
        local plan = aim or P.Passing.select(match,holder.id,moveX or 0,-(moveZ or 0))
        return startPass(match,holder,plan)
    end
end

local function proposeMovement(match, player, vx, vz, dt, proposal)
    local dodge = player.dodge
    local acceleration = 24+(P.Attributes.rating(player,"acceleration",60)-60)*.18
    local exit = player.faceoffExit
    if exit then
        exit.remaining = exit.remaining - dt
        local speed = 4.5 + 2 * math.max(0, exit.remaining) / .25
        vx, vz = exit.x * speed, exit.z * speed
        acceleration = 36
        if exit.remaining <= 0 then player.faceoffExit = nil end
    end
    if dodge then
        local burst = 8.6 + 3.1*dodge.time/.29 + (dodge.agility or 0)*.033
        vx, vz, acceleration = dodge.x * burst, dodge.z * burst, 52
        dodge.time = dodge.time - dt
        if dodge.time <= 0 then player.dodge = nil end
    end
    local dx, dz = vx - player.vx, vz - player.vz
    local speedup = math.min(1, acceleration * dt / math.max(distance(dx, dz), .001))
    local x, z = player.x, player.z
    local field = match.field
    local targetX = clamp(x + (player.vx + dx * speedup) * dt, -.987 * field.halfWidth, .987 * field.halfWidth)
    local targetZ = clamp(z + (player.vz + dz * speedup) * dt, -.991 * field.halfLength, .991 * field.halfLength)
    -- Keep opposing field players out of the defending crease.
    if player.role ~= "G" then
        local goal = match.goalsByTeam[player.team]
        local gx, gz = targetX - goal.x, targetZ - goal.z
        local length = distance(gx, gz)
        local crease = field.creaseRadius + .18
        if length < crease then
            if length < .01 then gx, gz, length = 1, 0, 1 end
            targetX, targetZ = goal.x + crease * gx / length, goal.z + crease * gz / length
        end
    end
    proposal.x, proposal.z, proposal.intentZ = targetX, targetZ, vz
end

local function applyMovement(player, proposal, dt)
    player.vx, player.vz = (proposal.x - player.x) / dt, (proposal.z - player.z) / dt
    player.x, player.z = proposal.x, proposal.z
    player.speed = distance(player.vx, player.vz)
    P.Attributes.updateFatigue(player,dt)
    if player.slot == 4 then
        local effort = (player.speed - 4.2) * .005
        player.faceoffFatigue = clamp(player.faceoffFatigue + effort * dt, 0, .55)
    end
end

local function movePlayers(match, dt, moveX, moveZ, intents)
    local goal = match.goalsByTeam
    local cut = P.Tactics.activeCut(match)
    local movementIntents = {}
    local proposals = match.movementProposals
    local humanID = not match.careerWaiting and match.controlled
    for _, player in ipairs(match.squad) do
        local intent = P.Screens.intent(match,player.id,intents[player.id] or {})
        movementIntents[player.id] = intent
        local human = humanControls(match,player.id)
        local control = match.humans and match.humans[player.id]
        local inputX,inputZ = moveX,moveZ
        local sprint = match.sprinting
        if control then inputX,inputZ,sprint = control.x or 0,control.z or 0,control.sprint end
        local tx,tz = intent.x,intent.z
        local receiveX,receiveZ = P.Passing.receiveTarget(match,player.id)
        if not intent.screenControl then
            if receiveX then
                tx,tz = receiveX,receiveZ
            elseif cut and cut.cutID==player.id and not match.pending then
                tx,tz = cut.cutX,cut.cutZ
            end
        end
        local guided = not match.humans and (receiveX or (cut and cut.cutID==player.id and not match.pending))
        local vx,vz = 0,0
        if human and not intent.screenControl and (not guided or distance(inputX,inputZ)>.12) then
            local rate = sprint and 1.18 or 1
            local pace = P.Attributes.pace(player,8.8) * (intent.screenDrag or 1)
            vx,vz = inputX*pace*rate,-inputZ*pace*rate
        elseif tx and tz then
            local dx,dz = tx-player.x,tz-player.z
            local gap = distance(dx,dz)
            if gap > .045 then
                local limit = intent.speed or (player.role=="G" and 4.8 or 7.2)
                local speed = math.min(gap*3.7,limit > 0 and P.Attributes.pace(player,limit) or 0)
                vx,vz = speed*dx/gap,speed*dz/gap
            end
        end
        proposeMovement(match,player,vx,vz,dt,proposals[player.id])
    end

    -- Apply both teams' steps together so a legal midfield exchange does not
    -- depend on the order of players in the squad.
    P.Midfield.resolve(match, proposals, humanID, dt)
    for _, player in ipairs(match.squad) do
        applyMovement(player, proposals[player.id], dt)
    end

    local ball = match.ball.position
    local flight = match.flight
    for _, player in ipairs(match.squad) do
        local lookX, lookZ = player.vx, player.vz
        local intent = movementIntents[player.id]
        local pending = match.pending
        if pending and pending.from == player.id then
            local target = pending.to and match.squad[pending.to] or pending.point or goal[player.team]
            lookX, lookZ = target.x - player.x, target.z - player.z
        elseif match.scoopPlayer == player.id or
            flight and (flight.to == player.id and flight.catchStarted or
                flight.interceptor and flight.interceptor.id == player.id) then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        elseif player.check then
            local target = match.squad[player.check.target]
            lookX, lookZ = target.x - player.x, target.z - player.z
        elseif intent and intent.lookX and intent.lookZ then
            lookX, lookZ = intent.lookX - player.x, intent.lookZ - player.z
        elseif player.speed < .21 then
            lookX, lookZ = ball.x - player.x, ball.z - player.z
        end
        local rotate = 0
        local turnRate = 530+(P.Attributes.rating(player,"agility",60)-60)*3.1
        if distance(lookX, lookZ) > .04 then
            local angle = (yawFor(lookX, lookZ) - player.yaw + 180) % 360 - 180
            rotate = clamp(angle, -turnRate*dt, turnRate*dt)
        end
        player.yaw, player.turn = (player.yaw + rotate) % 360, rotate / (turnRate*dt)
        player.checkCooldown = math.max(0, player.checkCooldown - dt)
        place(player)
    end
end

local function aimPoint(match, shot, player)
    local goal = match.goalsByTeam[player.team]
    local aim = shot.aim
    if aim and type(aim) ~= "number" and aim.x and aim.y then
        return clamp(aim.x, goal.x - 2.6, goal.x + 2.6), clamp(aim.y, .02, goal.top + 1.6)
    end
    local keeper = match.squad[match.keepers[3 - player.team]]
    local x = goal.x + (keeper.x <= goal.x and .57 or -.57)
    if type(aim) == "number" then x = goal.x + clamp(aim,-1,1) * .72 end
    return x, goal.top * .64
end

local function release(match, pending)
    local player = match.squad[pending.from]
    local origin = pocket(player)
    local flight = {kind=pending.kind, from=pending.from, team=player.team, origin=origin, time=0}
    if flight.kind == "pass" then
        local skill = player.role == "G" and P.Attributes.rating(player,"clearingAccuracy") or nil
        local velocity = 23+((skill or P.Attributes.rating(player,"passing",60))-60)*.12
        flight = P.Passing.launch(match,pending,{speed=velocity,minDuration=.35})
        Match.recordStat(match,player.id,"passes",1,{target=flight.to,call=pending.play})
        if player.role == "G" then
            flight.keeperOutlet = true
            P.Statistics.record(match,player.id,"clearsAttempted",1,{target=flight.to})
        end
        match.ballVelocity = flight.velocity
    else
        local goal = match.goalsByTeam[player.team]
        local x, y = aimPoint(match, pending, player)
        local span = math.sqrt((x - origin.x)^2 + (goal.z - origin.z)^2)
        local spreadX,spreadY = P.Attributes.shotSpread(match,player,span)
        x,y = x+spreadX,y+spreadY
        local velocity = 32+(P.Attributes.rating(player,"shotPower",60)-60)*.15
        local time = clamp(span / velocity, .11, 2.1)
        flight.duration = time + .29
        flight.velocity = vec3((x - origin.x) / time, (y - origin.y) / time + .5 * gravity * time,
            (goal.z - origin.z) / time)
        flight.goal = goal
        flight.onTarget = math.abs(x - goal.x) < goal.halfWidth - ballRadius
            and y >= ballRadius and y < goal.top - ballRadius
        Match.recordStat(match, player.id, "shots")
        P.Screens.creditShot(match,player.id,match.screenStat,flight)
        P.MatchRules.shotReleased(match,flight)
        match.ballVelocity = flight.velocity
    end
    match.lastTouch, match.carrier = player.team, nil
    match.pending, match.flight = nil, flight
    match.ball.position = origin
end

screenFoul = function(match, screenerID, defenderID)
    if match.phase~="LIVE" then return end
    local holder = match.carrier
    if holder then
        Match.recordStat(match,holder,"turnovers")
        P.Statistics.turnover(match,holder,"illegalScreen")
    end
    Match.recordStat(match,screenerID,"fouls")
    P.Statistics.penalty(match,screenerID,"technical",0,{reason="illegalScreen",other=defenderID})
    match.pending,match.flight,match.loose,match.scoopPlayer = nil,nil,nil,nil
    match.assist,match.tactical,match.cut = nil,nil,nil
    match.mode = "SET"
    match.foul = {recipient=defenderID,oldHolder=holder}
    match.phase,match.phaseTime = "FOUL",0
    match.ballVelocity = vec3()
    announce(match,"ILLEGAL SCREEN",match.rules.foulTime)
end

local function completeCheck(match, player)
    local request = player.check
    player.check = nil
    local result, position, velocity = P.Defense.contact(match, player, request)
    local target = match.squad[request.target]
    if result == "loose" then
        freeBall(match, position, velocity, player.team)
        Match.recordStat(match, player.id, "checks")
        Match.recordStat(match, player.id, P.Defense.checks[request.style].stat)
        Match.recordStat(match, player.id, "forcedTurnovers")
        Match.recordStat(match, target.id, "turnovers")
        P.Statistics.deferTurnover(match,target.id,request.style,player.id)
        announce(match, P.Defense.checks[request.style].name .. " · BALL LOOSE")
    elseif result == "foul" then
        local oldHolder = match.carrier
        if oldHolder and match.squad[oldHolder].team == player.team then
            Match.recordStat(match, oldHolder, "turnovers")
            P.Statistics.turnover(match,oldHolder,"illegalBodyCheck")
        end
        Match.recordStat(match, player.id, "fouls")
        -- Assessed time for the arcade box score. The existing foul pause is unchanged.
        P.Statistics.penalty(match,player.id,"personal",60,{reason="illegalBodyCheck",other=target.id})
        match.pending, match.flight, match.loose, match.scoopPlayer = nil, nil, nil, nil
        local recipient = oldHolder and match.squad[oldHolder].team == target.team and oldHolder or target.id
        match.foul = {recipient=recipient, oldHolder=oldHolder}
        match.phase, match.phaseTime = "FOUL", 0
        match.ballVelocity = vec3()
        announce(match, "ILLEGAL BODY CHECK", match.rules.foulTime)
    end
end

local function act(match, intents)
    for index, intent in pairs(intents) do
        if not humanControls(match,index)
            or intent.action == "save" and (match.humans or index == match.careerPlayer) then
            local player = match.squad[index]
            local action = intent.action
            if action == "pass" then
                local call = intent.tactic and intent.tactic.call
                if startPass(match,player,intent.target,call) and call then
                    P.Tactics.activate(match,intent.tactic,call,player.team)
                end
            elseif action == "shoot" then startShot(match, player, intent.aim)
            elseif action == "dodge" then startDodge(player, intent.moveX, intent.moveZ)
            elseif action == "check" or P.Defense.checks[action] then
                startCheck(match, player, action)
            elseif action == "scoop" then startScoop(match, player)
            elseif action == "save" and intent.style then
                P.AnimationController.play(player.anim, intent.style)
            end
        end
    end
end

local function trySave(match, flight, previous, position, velocity, hit)
    local goal = flight.goal
    local id = match.keepers[3 - flight.team]
    local keeper = match.squad[id]
    local range = (goal.z - keeper.z) * goal.attackSign
    if range < .08 or range > match.field.creaseRadius + .6
        or (position.z - previous.z) * goal.attackSign <= 0 then return false end
    local save = P.MatchAI.sweepKeeper(match, id, previous, position, velocity)
    if not save or hit and hit.time < save.t then return false end
    if flight.onTarget then
        Match.recordStat(match, keeper.id, "saves")
        Match.recordStat(match, flight.from, "shotsOnGoal")
    end
    P.Statistics.goalkeeper(match,keeper.id,flight.onTarget and "save" or "block",flight.from)
    P.MatchRules.shotContact(match,flight,"SAVE")
    if save.style then P.AnimationController.play(keeper.anim, save.style) end
    if save.caught then
        attach(match, keeper.id, false)
        announce(match, flight.onTarget and "SAVE" or "SHOT BLOCKED")
    else
        freeBall(match, save.position, save.velocity, keeper.team, true)
        announce(match, flight.onTarget and "SAVE · REBOUND" or "SHOT BLOCKED")
    end
    return true
end

local function score(match, flight, hit)
    local team = flight.team
    match.lastGoalScorer,match.lastGoalTeam=flight.from,team
    Match.recordStat(match, flight.from, "goals")
    Match.recordStat(match, flight.from, "shotsOnGoal")
    P.Statistics.goalkeeper(match,match.keepers[3-team],"goal",flight.from)
    Match.recordStat(match, flight.from, "score")
    P.Screens.creditGoal(match,flight.from,match.screenStat,flight)
    P.Screens.reset(match)
    local assist = match.assist
    if assist and assist.to==flight.from and match.elapsed-assist.at<=4.8
        and (not assist.received or (flight.origin-assist.received):len()<=12) then
        Match.recordStat(match, assist.from, "assists",1,{other=flight.from})
    end
    match.assist = nil
    match.homeScore, match.awayScore = match.stats[1].goals, match.stats[2].goals
    match.flight, match.loose, match.carrier = nil, nil, nil
    local fixed = P.GoalPhysics.capture(flight.goal, hit.position)
    match.inNet = {state="IN_NET", position=fixed}
    match.ball.position = fixed
    match.ballVelocity = vec3()
    match.phase, match.phaseTime = "GOAL", 0
    local scorer = team == 1 and match.homeTeam or match.awayTeam
    announce(match, scorer.name .. " GOAL", match.rules.goalTime)
end

local function updateFlight(match, dt, catchIndex)
    local flight = match.flight
    flight.time = math.min(flight.time + dt, flight.duration)
    local previous = match.ball.position
    if flight.kind == "pass" then
        local progress = flight.time / flight.duration
        local position = P.Defense.passPoint(match, flight, flight.time)
        match.ball.position, match.ballVelocity = position, (position - previous) / dt
        local intercepted = P.Defense.intercept(match, flight, previous, position)
        if intercepted then
            attach(match, intercepted, true)
            Match.recordStat(match, intercepted, "interceptions")
            Match.recordStat(match, intercepted, "forcedTurnovers")
            Match.recordStat(match, flight.from, "turnovers")
            P.Statistics.turnover(match,flight.from,"interception",intercepted)
            announce(match, "INTERCEPTION")
        elseif P.Passing.canCatch(match,flight,catchIndex,position) then
            attach(match, flight.to, match.controlled == flight.from)
            Match.recordStat(match, flight.from, "completions",1,{other=flight.to})
            if flight.keeperOutlet then
                P.Statistics.record(match,flight.from,"clearsCompleted",1,{other=flight.to})
            end
            match.assist = {from=flight.from,to=flight.to,at=match.elapsed,received=position}
        elseif progress >= 1 then
            local velocity = P.Passing.endVelocity(match,flight)
            if not flight.to then position.y = ballRadius end
            freeBall(match, position, velocity, flight.team)
            P.Statistics.deferTurnover(match,flight.from,flight.to and "droppedPass" or "passToSpace")
            announce(match,flight.to and "PASS DROPPED" or "BALL LOOSE")
        end
        return
    end

    local time = flight.time
    local position = flight.origin + flight.velocity * time - vec3(0, .5 * gravity * time^2, 0)
    local velocity = flight.velocity - vec3(0, gravity * time, 0)
    local goal = flight.goal
    local hit = P.GoalPhysics.step(goal, previous, position, velocity)
    if trySave(match, flight, previous, position, velocity, hit) then return end
    if hit then
        if hit.kind == "GOAL" and (flight.origin.z - goal.z) * goal.attackSign <= 0 then
            score(match, flight, hit)
            return
        elseif hit.kind == "POST" or hit.kind == "CROSSBAR" then
            P.MatchRules.shotContact(match,flight,hit.kind)
            freeBall(match, hit.position, hit.velocity, flight.team, true)
            P.Statistics.record(match,flight.from,"pipeHits",1,{reason=hit.kind})
            announce(match, hit.kind == "POST" and "OFF THE POST" or "OFF THE BAR")
            return
        elseif hit.kind == "WIDE" or hit.kind == "HIGH" or hit.kind == "LOW" then
            local misses = {WIDE="shotsWide",HIGH="shotsHigh",LOW="shotsLow"}
            if not flight.missRecorded then
                P.Statistics.record(match,flight.from,misses[hit.kind])
                flight.missRecorded = true
            end
            announce(match, hit.kind)
        end
    end

    if position.y <= ballRadius or time >= flight.duration then
        position.y = math.max(ballRadius, position.y)
        freeBall(match, position, velocity * .36, flight.team, true)
    else
        match.ball.position, match.ballVelocity = position, velocity
    end
end

local function restartPossession(match, team, position, fromBoundary)
    local field = match.field
    local selected, best = nil, math.huge
    local fallback, fallbackDistance = nil, math.huge
    local margin = fromBoundary and .9 or 1.4
    local x = clamp(position.x, -field.halfWidth + margin, field.halfWidth - margin)
    local z = clamp(position.z, -field.halfLength + margin, field.halfLength - margin)
    local opponentGoal = match.goalsByTeam[team]
    local gx, gz = x-opponentGoal.x, z-opponentGoal.z
    local crease = field.creaseRadius + .45
    local goalDistance = distance(gx,gz)
    if goalDistance < crease then
        if goalDistance < .01 then gx, gz, goalDistance = 1, 0, 1 end
        x, z = opponentGoal.x+gx*crease/goalDistance, opponentGoal.z+gz*crease/goalDistance
    end
    local half = P.Midfield.halfAt(match, team, z)
    for _, index in ipairs(match.teams[team]) do
        local player = match.squad[index]
        if player.role ~= "G" and player.onField ~= false and player.active ~= false and not player.bench then
            local length = distance(player.x - x, player.z - z)
            if not half or P.Midfield.side(match, player) == half then
                if length < best then selected, best = player, length end
            elseif length < fallbackDistance then
                fallback, fallbackDistance = player, length
            end
        end
    end
    -- Restart at the same depth if an incomplete lineup has no one in this half.
    if not selected and fallback then selected, z = fallback, fallback.z end
    if not selected then return end
    selected.x, selected.z, selected.vx, selected.vz = x, z, 0, 0
    place(selected)
    P.AnimationController.reset(selected.anim)
    attach(match, selected.id, true, "restart")
    return selected
end

local function outOfBounds(match, position)
    local team = 3 - (match.lastTouch or 2)
    local shot = match.boundaryShot or match.flight and match.flight.kind == "shot"
    if shot and match.rules.shotBoundary == "nearest" then
        local closest = math.huge
        for _, player in ipairs(match.squad) do
            if player.onField ~= false and player.active ~= false and not player.bench then
                local gap = distance(player.x-position.x,player.z-position.z)
                if gap < closest then team, closest = player.team, gap end
            end
        end
    end
    if restartPossession(match,team,position,true) then announce(match,"OUT OF BOUNDS") end
end

local function updateLoose(match, dt, scoopIndex)
    local previous, velocity = match.ball.position, match.ballVelocity
    local position = previous + velocity * dt
    velocity.y = velocity.y - gravity * dt
    if position.y <= ballRadius then
        position.y = ballRadius
        velocity.y = math.abs(velocity.y) > 1.05 and math.abs(velocity.y) * .29 or 0
        local drag = math.max(0, 1 - dt * 2.7)
        velocity.x, velocity.z = velocity.x * drag, velocity.z * drag
    end
    match.ball.position, match.ballVelocity = position, velocity
    if scoopIndex and scoopIndex == match.scoopPlayer then
        local player = match.squad[scoopIndex]
        local contact = pocket(player)
        match.scoopPlayer = nil
        local ground = P.Attributes.rating(player,"groundBalls",65)-65
        if position.y <= .34 and contact.y <= .75
            and distance(position.x - contact.x, position.z - contact.z) <= .79+ground*.004 then
            attach(match, scoopIndex, match.controlled == scoopIndex)
            Match.recordStat(match, player.id, "groundBalls")
            announce(match, "GROUND BALL")
        end
    end
end

local function settlePossession(match, dt, flight, loose, catchIndex, scoopIndex)
    local previous = match.ball.position
    if flight and match.flight == flight then
        updateFlight(match, dt, catchIndex)
    elseif loose and match.loose then
        updateLoose(match, dt, scoopIndex)
    elseif match.carrier then
        local position = pocket(match.squad[match.carrier])
        match.ballVelocity = (position - match.ball.position) / dt
        match.ball.position = position
    end
    if match.phase ~= "LIVE" then return end
    local position = match.ball.position
    local field = match.field
    local outsideX, outsideZ = math.abs(position.x)>field.halfWidth, math.abs(position.z)>field.halfLength
    if not match.carrier and (outsideX or outsideZ) then
        local travel = position-previous
        local edgeTime = 1
        if outsideX and math.abs(travel.x)>.0001 then
            local edge = position.x>0 and field.halfWidth or -field.halfWidth
            edgeTime = math.min(edgeTime,(edge-previous.x)/travel.x)
        end
        if outsideZ and math.abs(travel.z)>.0001 then
            local edge = position.z>0 and field.halfLength or -field.halfLength
            edgeTime = math.min(edgeTime,(edge-previous.z)/travel.z)
        end
        outOfBounds(match,previous+travel*clamp(edgeTime,0,1))
    end
end

local function finishPeriod(match)
    P.Screens.reset(match)
    match.phaseTime = 0
    if match.period >= match.rules.periods then
        match.phase = "FINAL"
        P.Statistics.finalize(match,match.humans and {persist=false} or nil)
        local winner = match.homeScore > match.awayScore and match.homeTeam
            or match.awayScore > match.homeScore and match.awayTeam
        announce(match, winner and winner.name .. " WIN" or "DRAW", 3)
    else
        match.phase = "INTERMISSION"
        announce(match, "END OF PERIOD " .. match.period, match.rules.intermissionTime)
    end
end

local function updateDrawActor(player, entry, dt, ballPosition, collecting)
    local animation = P.AnimationController
    if entry.action and not entry.animated then
        local clip = entry.action == "counter" and "faceoffCounter" or "faceoffClamp"
        entry.animated = animation.play(player.anim, clip)
    end
    if collecting and not entry.collecting then
        entry.collecting = animation.play(player.anim, "scoop")
    end
    return animation.update(player.anim, dt, {
        scoopPoint = entry.collecting and ballPosition or nil
    })
end

local function faceoff(match, dt, moveX, moveZ)
    local draw = match.faceoff
    local previous = draw.phase
    match.phaseTime = match.phaseTime + dt
    P.Faceoff.update(draw, dt, moveX, moveZ)
    if previous == "SET" and draw.phase == "DRAW" and draw.userTeam and not draw.home.action then
        announce(match, "TIME YOUR CLAMP", .44)
    end
    local first, second = match.squad[draw.home.id], match.squad[draw.away.id]
    local result = draw.result
    local winner = result and result.winner
    local ballPosition = match.ball.position
    local firstEvent = updateDrawActor(first, draw.home, dt, ballPosition, winner == 1)
    local secondEvent = updateDrawActor(second, draw.away, dt, ballPosition, winner == 2)
    if winner == 1 and firstEvent == "scoop" or winner == 2 and secondEvent == "scoop" then
        draw.contact = true
    end

    if previous ~= "EXIT" and draw.phase == "EXIT" then
        if result.loose then announce(match, "CONTESTED DRAW")
        elseif winner == draw.userTeam then announce(match, "STEER THE EXIT", draw.exitTime + .20) end
    end
    if draw.active then return end
    if winner and not draw.contact
        and match.phaseTime < draw.setTime + draw.duration + draw.exitTime + .65 then return end

    Match.recordStat(match, first.id, "faceoffAttempts")
    Match.recordStat(match, second.id, "faceoffAttempts")
    if result.cause == "FALSE_START" then
        local offender = winner == 1 and second or first
        Match.recordStat(match, offender.id, "faceoffViolations")
    end
    if result.loose then
        Match.recordStat(match, first.id, "faceoffScrambles")
        Match.recordStat(match, second.id, "faceoffScrambles")
        local x, z = result.exitX, result.exitZ
        local wingSlot = x < 0 and 5 or 6
        match.faceoffScramble = {
            homeId=first.id, awayId=second.id, time=2.4,
            wings={match.teams[1][wingSlot], match.teams[2][11 - wingSlot]}
        }
        freeBall(match, vec3(x * .16, ballRadius, z * .16), vec3(x * 5.6, .42, z * 5.6))
        announce(match, "LOOSE DRAW")
    else
        local player = winner == 1 and first or second
        attach(match, player.id, not careerLock(match), "faceoff")
        player.faceoffExit = {x=result.exitX, z=result.exitZ, remaining=.25}
        Match.recordStat(match, player.id, "faceoffs")
        local team = winner == 1 and match.homeTeam or match.awayTeam
        announce(match, team.short .. " FACEOFF WIN")
    end
    match.phase, match.phaseTime = "LIVE", 0
end

local function pursueDraw(match, intents, dt)
    local draw = match.faceoffScramble
    if not draw or draw.time <= 0 or not match.loose then return end
    draw.time = draw.time - dt
    local ball, velocity = match.ball.position, match.ballVelocity
    for _, index in ipairs(draw.wings) do
        local wing = match.squad[index]
        local sign = wing.homeX >= 0 and 1 or -1
        local intent = intents[index]
        if intent then
            -- Enter from the flank so both wings leave a lane for the faceoff players.
            intent.x, intent.z = ball.x + velocity.x * .3 + sign * .8, ball.z + velocity.z * .3
            intent.lookX, intent.lookZ, intent.speed = ball.x, ball.z, 7.8
        end
    end
end

local function live(match, dt, moveX, moveZ)
    local violation = P.MatchRules.tick(match,dt)
    if violation then
        local holder = match.carrier or (match.flight and match.flight.from) or violation.player
        if holder and match.squad[holder].team == violation.team then
            Match.recordStat(match,holder,"turnovers")
            P.Statistics.turnover(match,holder,violation.reason)
        end
        local messages = {clearClock="CLEAR CLOCK VIOLATION", shotClock="SHOT CLOCK VIOLATION",
            creaseClock="CREASE COUNT VIOLATION", overAndBack="OVER AND BACK"}
        P.Screens.reset(match)
        match.tactical, match.cut, match.swingDirection = nil, nil, nil
        match.mode, match.clearTime = "SET", 0
        local restart = restartPossession(match,3-violation.team,match.ball.position,false)
        if restart then announce(match,messages[violation.reason] or "POSSESSION AWARDED") end
        return
    end
    if match.careerWaiting and match.elapsed >= match.careerEntryDelay then
        match.careerWaiting = false
        announce(match, "YOUR SHIFT", 1.7)
    end
    local length = math.max(distance(moveX, moveZ), 1)
    moveX, moveZ = moveX / length, moveZ / length
    match.moveX, match.moveZ = moveX, moveZ
    if match.clearTime > 0 then
        match.clearTime = math.max(0, match.clearTime - dt)
        if match.clearTime == 0 and match.mode == "CLEAR" then match.mode = "SET" end
    end
    local intents = P.MatchAI.update(match, dt)
    pursueDraw(match, intents, dt)
    act(match, intents)
    P.Passing.scheduleCatch(match,match.flight,dt)
    if match.flight then P.Defense.prepareIntercept(match, match.flight) end
    if match.loose and not match.careerWaiting then
        if match.humans then
            for _, player in ipairs(match.squad) do
                if humanControls(match,player.id) then startScoop(match,player) end
            end
        else
            startScoop(match, match.squad[match.controlled])
        end
    end
    movePlayers(match, dt, moveX, moveZ, intents)
    local holder, offender = match.squad[match.carrier], match.squad[match.controlled]
    if match.humans then
        for _, player in ipairs(match.squad) do
            local blocked = match.positioning.blocked[player.id]
            if humanControls(match,player.id) and blocked and blocked.reason == "minimum" then
                offender = player
                break
            end
        end
    end
    local crossing = match.positioning.blocked[offender.id]
    if match.rules.profile ~= "arcade" and crossing and crossing.reason == "minimum"
        and holder and offender.team == holder.team and not match.careerWaiting then
        Match.recordStat(match,holder.id,"turnovers")
        P.Statistics.turnover(match,holder.id,"offsides")
        Match.recordStat(match,offender.id,"fouls")
        P.Statistics.penalty(match,offender.id,"technical",0,{reason="offsides"})
        P.Screens.reset(match)
        match.tactical, match.cut, match.swingDirection = nil, nil, nil
        match.mode, match.clearTime = "SET", 0
        restartPossession(match,3-offender.team,pocket(holder),false)
        announce(match,"OFFSIDES")
        return
    end
    P.Screens.update(match,dt,match.screenCallbacks)
    if match.phase~="LIVE" then return end
    local animation = P.AnimationController
    local flight, loose = match.flight, match.loose
    local catchIndex, scoopIndex
    for index, player in ipairs(match.squad) do
        local event = animation.update(player.anim, dt, {
            speed=player.speed, turn=player.turn, possessed=match.carrier==index,
            scoopPoint=match.scoopPlayer==index and match.ball.position or nil,
            catchPoint=P.Passing.catchPoint(match,index)
        })
        if player.check then
            if event == "check" then completeCheck(match, player)
            elseif player.anim.action ~= player.check.clip then player.check = nil end
        end
        if match.phase ~= "LIVE" then return end
        if event == "release" and match.pending and match.pending.from == index then
            release(match, match.pending)
        elseif event == "catch" then
            catchIndex = index
        elseif event == "scoop" then
            scoopIndex = index
        end
    end
    if match.scoopPlayer and not match.squad[match.scoopPlayer].anim.action and not scoopIndex then
        match.scoopPlayer = nil
    end
    settlePossession(match, dt, flight, loose, catchIndex, scoopIndex)
    match.marker.position = match.squad[match.controlled].rig.root.position
end

function Match.update(match, dt, moveX, moveZ)
    if dt <= 0 then return end
    match.announcementTime = math.max(0, match.announcementTime - dt)
    for _, goal in ipairs(match.goalsByTeam) do P.GoalPhysics.update(goal, dt) end
    if match.phase == "FACEOFF" then
        if match.humans then
            local input = match.humans[match.faceoff.home.id]
            moveX, moveZ = input and input.x or 0, input and input.z or 0
        end
        faceoff(match, dt, moveX, moveZ)
    elseif match.phase == "LIVE" then
        local liveTime = math.min(dt, match.clock)
        match.clock = math.max(0, match.clock - liveTime)
        match.elapsed = match.elapsed + liveTime
        P.Statistics.tick(match,liveTime)
        if liveTime > 0 then live(match, liveTime, moveX or 0, moveZ or 0) end
        if match.clock <= 0 and match.phase == "LIVE" then finishPeriod(match) end
    elseif match.phase == "FOUL" then
        match.phaseTime = match.phaseTime + dt
        if match.phaseTime >= match.rules.foulTime then
            local foul, animation = match.foul, P.AnimationController
            match.foul = nil
            if foul.oldHolder and foul.oldHolder ~= foul.recipient then
                animation.reset(match.squad[foul.oldHolder].anim)
            end
            animation.reset(match.squad[foul.recipient].anim)
            attach(match, foul.recipient, true)
            match.phase, match.phaseTime = "LIVE", 0
            if match.clock <= 0 then finishPeriod(match)
            else announce(match, "POSSESSION AWARDED") end
        end
    elseif match.phase == "INTERMISSION" or match.phase == "GOAL" then
        match.phaseTime = match.phaseTime + dt
        if match.phase == "GOAL" and match.phaseTime >= match.rules.goalTime then
            if match.clock <= 0 then finishPeriod(match)
            else startFaceoff(match) end
        elseif match.phase == "INTERMISSION" and match.phaseTime >= match.rules.intermissionTime then
            match.period, match.clock = match.period + 1, match.rules.periodLength
            startFaceoff(match)
        end
    end
end
end

-- Style
do
-- PolyLax 2.0 | Shared treatments, navigation and pause overlays
PolyLax = PolyLax or {}
local Style = {}
PolyLax.Style = Style

local palette = {
    deep=color(9,13,19), graphite=color(21,28,38), body=color(26,34,46),
    inset=color(15,21,29), steel=color(57,73,91), rim=color(80,98,117),
    muted=color(164,180,197), white=color(245,249,254), blue=color(42,119,239),
    glow=color(109,188,255), red=color(235,73,93), amber=color(253,206,100)
}
Style.palette = palette

local meshes = {}

function Style.rounded(x, y, w, h, radius, tint, press)
    if w <= 0 or h <= 0 then return end
    radius = math.min(radius,w*.5,h*.5)
    if not mesh then
        rectMode(CENTER)
        fill(tint)
        rect(x,y,w*(press or 1),h*(press or 1))
        return
    end
    local key = string.format("%.2f,%.2f,%.2f",w,h,radius)
    local shape = meshes[key]
    if not shape then
        local perimeter = {}
        for corner=0,3 do
            local cx = (corner == 0 or corner == 3) and w*.5-radius or radius-w*.5
            local cy = corner < 2 and h*.5-radius or radius-h*.5
            for sub=0,4 do
                local angle = (corner+sub*.25)*math.pi*.5
                perimeter[#perimeter+1] = vec3(cx+math.cos(angle)*radius,cy+math.sin(angle)*radius,0)
            end
        end
        local vertices, center = {}, vec3(0,0,0)
        for index, point in ipairs(perimeter) do
            local start = #vertices+1
            vertices[start],vertices[start+1],vertices[start+2] = center,point,perimeter[index % #perimeter+1]
        end
        shape = mesh()
        shape.vertices = vertices
        if (meshes.count or 0) >= 160 then meshes = {} end
        meshes[key],meshes.count = shape,(meshes.count or 0)+1
    end
    shape:setColors(tint)
    pushMatrix()
    translate(x,y)
    if press then scale(press) end
    shape:draw()
    popMatrix()
end

local panelShadow = color(5,9,14,173)
local panelActive = color(27,85,172)
function Style.panel(x, y, w, h, active, radius)
    radius = radius or 12
    Style.rounded(x,y-2,w,h,radius,panelShadow)
    Style.rounded(x,y,w,h,radius,active and palette.blue or palette.steel)
    Style.rounded(x,y,w-2,h-2,math.max(0,radius-1),active and panelActive or palette.body)
end

local choices = {
    FRONT = {
        {id="MODES", title="Quick Play", detail="Practice or play a full match", prominent=true},
        {id="CAREER", title="Be a Pro", detail="Develop your single-player career"},
        {id="CLUBS", title="PolyLax Clubs", detail="Manage your club and athlete", icon="clubs"},
        {id="SETTINGS", title="Settings", detail="Player Creator and online connection"}
    },
    MODES = {
        {id="PRACTICE", title="Practice", detail="Six-player offense and shooting", prominent=true},
        {id="MATCH", title="Full Match", detail="Twenty-player field lacrosse"},
        {id="CAREER", title="Be a Pro", detail="Continue your career"},
        {id="HOME", title="Home"}
    },
    PAUSE = {
        {id="RESUME", title="Resume", prominent=true},
        {id="RESET", title="Restart"},
        {id="STATS", title="Stats"},
        {id="CREATOR", title="Player Creator"},
        {id="HOME", title="Home"}
    }
}

local function hitbox(id, x, y, w, h, choice, enabled)
    return {id=id,x=x,y=y,w=w,h=h,label=choice.title,detail=choice.detail,
        prominent=choice.prominent,icon=choice.icon,enabled=enabled}
end

function Style.screenLayout(page, options)
    page = tostring(page or "FRONT"):upper()
    if not choices[page] then page = "FRONT" end
    local safe = PolyLax.UI.safeArea()
    local w = math.min(452,WIDTH-safe.left-safe.right-36)
    local x = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-12,safe.bottom+12
    local room = top-bottom
    local list = choices[page]
    local pause = page == "PAUSE"
    local dashboard = {
        page=page,x=x,w=w,top=top,bottom=bottom,buttons={},byId={},
        touches={},motion={}
    }
    local row = pause and math.min(49,room*.109) or math.min(68,room*.133)
    local gap = pause and 8 or 11
    local stack = #list*row + (#list-1)*gap
    local firstTop
    if pause then
        local paneHeight = stack+87
        dashboard.overlay = {x=x,y=(top+bottom)*.5,w=w+16,h=paneHeight}
        dashboard.titleY = dashboard.overlay.y+paneHeight*.5-34
        firstTop = dashboard.titleY-31
    else
        local reserve = page == "FRONT" and math.min(183,room*.37) or math.min(147,room*.30)
        firstTop = math.max(bottom+stack+20,top-reserve)
        dashboard.titleY = (top+firstTop)*.5
    end
    for index, choice in ipairs(list) do
        local enabled = choice.id ~= "STATS" or options and options.statsEnabled == true
        local y = firstTop-row*.5-(index-1)*(row+gap)
        local item = hitbox(choice.id,x,y,w,row,choice,enabled == true)
        dashboard.buttons[index],dashboard.byId[item.id] = item,item
    end
    return dashboard
end

local function label(value, x, y, size, tint, corner, maxWidth)
    if not value then return end
    fontSize(size)
    if textSize and maxWidth then
        local used = textSize(value)
        if used > maxWidth then fontSize(math.max(9,size*maxWidth/used)) end
    end
    fill(tint)
    if corner then textMode(CORNER) end
    text(value,x,corner and y-size*.53 or y)
    if corner then textMode(CENTER) end
end

local lineInk = color(72,108,143,83)
local banner = color(22,32,46,239)
local overlayInk = color(6,10,16,191)
local cardShadow = color(7,10,15,221)
local blueTop = color(34,92,182)
local disabled = color(122,136,152)
local disabledCard = color(21,28,38,228)

local function fieldMarks(l)
    local cx, cy = l.x,l.titleY
    local extent = l.w*.49
    stroke(lineInk)
    strokeWidth(1)
    line(cx-extent,cy-63,cx-extent*.75,cy+67)
    line(cx+extent,cy-63,cx+extent*.75,cy+67)
    line(cx-extent*.92,cy-25,cx+extent*.92,cy-25)
    line(cx-extent*.81,cy+27,cx+extent*.81,cy+27)
    noFill()
    ellipseMode(CENTER)
    ellipse(cx,cy-25,87,29)
    ellipse(cx,cy+27,51,21)
    noStroke()
end

function Style.clubsIcon(x, y, size, tint)
    local radius = size * .095
    ellipseMode(CENTER)
    fill(tint)
    noStroke()
    ellipse(x, y+size*.16, radius*2.2)
    ellipse(x-size*.21, y+size*.08, radius*2)
    ellipse(x+size*.21, y+size*.08, radius*2)
    Style.rounded(x, y-size*.12, size*.27, size*.22, size*.065, tint)
    Style.rounded(x-size*.22, y-size*.17, size*.14, size*.16, size*.046, tint)
    Style.rounded(x+size*.22, y-size*.17, size*.14, size*.16, size*.046, tint)
end

local function drawButton(l, item)
    local motion = l.motion[item]
    local s = 1-.035*(motion and motion.amount or 0)
    local colorTop = item.prominent and blueTop or item.enabled and palette.body or disabledCard
    local colorRim = item.prominent and palette.glow or item.icon and palette.rim
        or item.enabled and palette.steel or palette.inset
    local x,y,w,h = item.x,item.y,item.w,item.h
    Style.rounded(x,y-3,w,h,13,cardShadow,s)
    Style.rounded(x,y,w,h,13,colorRim,s)
    Style.rounded(x,y,w-2,h-2,12,colorTop,s)
    if item.prominent then Style.rounded(x-w*.5+12,y,3,h*.54,1.5,palette.glow) end
    local left = x-w*.5+23
    local maxLabelWidth = w-75
    if item.icon == "clubs" then
        Style.rounded(left+6,y,37,37,10,palette.inset)
        Style.clubsIcon(left+6,y,36,palette.glow)
        left,maxLabelWidth = left+33,maxLabelWidth-33
    end
    local fg = item.enabled and palette.white or disabled
    label(item.label,left,y+(item.detail and 9 or 0),item.prominent and 19 or 16,fg,true,maxLabelWidth)
    if item.detail then label(item.detail,left,y-12,11,item.prominent and palette.white or palette.muted,true,maxLabelWidth) end
    if item.enabled then
        local arrowX = x+w*.5-18
        stroke(item.prominent and palette.white or palette.glow)
        strokeWidth(2)
        line(arrowX-4,y+4,arrowX,y)
        line(arrowX,y,arrowX-4,y-4)
        noStroke()
    end
end

function Style.screen(page, l, elapsed)
    page = l.page or page
    if page ~= "PAUSE" then background(palette.deep) end
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    if page == "PAUSE" then
        fill(overlayInk)
        rect(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT)
        local panel = l.overlay
        Style.rounded(panel.x,panel.y,panel.w,panel.h,20,banner)
        label("Paused",l.x,l.titleY,28,palette.white)
    else
        fieldMarks(l)
        local tempo = .5+.5*math.sin((elapsed or 0)*1.6)
        local title = page == "FRONT" and "POLYLAX 3.1" or "Play Modes"
        local size = page == "FRONT" and math.min(48,l.w*.164) or 30
        font("AvenirNext-HeavyItalic")
        label(title,l.x,l.titleY+9,size,palette.white,false,l.w)
        font("AvenirNext-DemiBold")
        Style.rounded(l.x,l.titleY-25,41+tempo*7,2,1,palette.glow)
    end
    for _,item in ipairs(l.buttons) do drawButton(l,item) end
    popMatrix()
    popStyle()
end


function Style.fade(age)
    local alpha=math.floor(118*math.max(0,1-age/.18))
    if alpha==0 then return end
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CORNER)
    fill(8,15,26,alpha)
    rect(0,0,WIDTH,HEIGHT)
    popMatrix()
    popStyle()
end
end

-- UI
do
-- PolyLax 2.0 | Creator and match HUD
PolyLax = PolyLax or {}
local UI = {}
PolyLax.UI = UI

local navy = color(12, 18, 28)
local panel = color(17, 25, 36)
local blue = color(54, 133, 240)
local white = color(240, 244, 247)
local silver = color(174, 191, 205)

local function box(x, y, width, height, label, id)
    return {x=x, y=y, w=width, h=height, label=label, id=id}
end

function UI.hit(item, x, y)
    return item ~= nil and math.abs(x - item.x) <= item.w * .5 and
           math.abs(y - item.y) <= item.h * .5
end

local function beginHud()
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    font("AvenirNext-DemiBold")
    textMode(CENTER)
    textAlign(CENTER)
end

local function endHud()
    popMatrix()
    popStyle()
end

local function label(textValue, x, y, size, tint)
    fill(tint)
    fontSize(size)
    text(textValue, x, y)
end

local function leftLabel(textValue, x, y, size, tint)
    textMode(CORNER)
    label(textValue, x, y - size * .55, size, tint)
    textMode(CENTER)
end

local function fillRect(x, y, width, height, tint)
    rectMode(CORNER)
    fill(tint)
    rect(x, y, width, height)
end

local function button(item, selected, size)
    PolyLax.Style.panel(item.x, item.y, item.w, item.h, selected, 7)
    label(item.label, item.x, item.y, size or 12, white)
end

function UI.safeArea()
    local source = _ENV.layout
    local kind = type(source)
    local safe = (kind == "table" or kind == "userdata") and source.safeArea
    return {
        top=safe and safe.top or 0, bottom=safe and safe.bottom or 0,
        left=safe and safe.left or 0, right=safe and safe.right or 0
    }
end

function UI.creatorLayout(categories, options)
    options = options or {}
    local w, h = WIDTH, HEIGHT
    local safe = UI.safeArea()
    local topInset, bottomInset = safe.top, safe.bottom
    local topBar = topInset + 55
    local headerY = h - topInset - 27
    local panelHeight = math.min(365, h * .46)
    local clearBottom = math.max(27, bottomInset + 12)
    local footerY = clearBottom + 15
    local contentHeight = panelHeight - clearBottom - 43
    local optionHeight = contentHeight * .36 / 2
    local categoryHeight = contentHeight * .64 / 4
    local optionsBottom = clearBottom + 36
    local categoriesBottom = optionsBottom + optionHeight * 2 + 6
    local left, right = 12 + safe.left, w - 12 - safe.right
    local categoryWidth, optionWidth = (right-left)/4, (right-left)/3
    local layout = {
        topBar=topBar, headerY=headerY, panelHeight=panelHeight, footerY=footerY,
        frame={bottom=panelHeight+49, top=h-topBar-9},
        leftX=left, centerX=(left+right)*.5,
        athlete=options.athlete, kit=options.kit,
        home=box(left+23,footerY,46,34,options.athlete and "BACK" or "HOME","home"),
        done=box(w-safe.right-49,headerY,82,39,options.athlete and "HOME KIT" or "PRACTICE"),
        fullGame=box(w-safe.right-136,headerY,82,39,options.athlete and "AWAY KIT" or "FULL GAME"),
        reset=box(right-68, panelHeight+23, 136, 34, "RESET CAMERA"),
        career=box(right-171, panelHeight+23, 56, 34, "CAREER", "career"),
        left=box(left+(right-left)*.29,footerY,48,34,"<"),
        right=box(right-(right-left)*.20,footerY,48,34,">"),
        categories={}, options={}
    }

    for index, category in ipairs(categories) do
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        layout.categories[index] = box(left + (column + .5) * categoryWidth,
            categoriesBottom + (3.5 - row) * categoryHeight,
            categoryWidth - 5, categoryHeight - 4, category.label or category.key, index)
    end
    for index = 1, 6 do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        layout.options[index] = box(left + (column + .5) * optionWidth,
            optionsBottom + (1.5 - row) * optionHeight,
            optionWidth - 5, optionHeight - 4)
    end
    return layout
end

function UI.firstOption(category, selected)
    return math.max(1, math.min(selected - 2, #category.choices - 5))
end

function UI.creator(layout, category, categoryIndex, selected, firstOption, showCareer, options)
    if type(showCareer) == "table" then options,showCareer = showCareer,false end
    local athlete = layout.athlete or options and options.athlete
    local kit = options and options.kit or layout.kit
    local away = type(kit) == "string" and kit:lower() == "away"
    beginHud()
    fillRect(0, HEIGHT-layout.topBar, WIDTH, layout.topBar, navy)
    local title=athlete and options and options.team and options.team.short or "MODIFY PLAYER"
    leftLabel(title,layout.leftX+2,layout.headerY+(athlete and 6 or 0),WIDTH<350 and 15 or 18,white)
    if athlete and options and options.uniform then
        for index,tint in ipairs({options.uniform.primary,options.uniform.secondary,options.uniform.accent}) do
            fill(tint)
            ellipseMode(CENTER)
            ellipse(layout.leftX+9+(index-1)*16,layout.headerY-12,10)
        end
    end
    button(layout.fullGame,not athlete or away,11)
    button(layout.done,athlete and not away,11)
    fillRect(0,0,WIDTH,layout.panelHeight,navy)
    fillRect(0,layout.panelHeight-5,WIDTH,5,panel)
    fillRect(layout.leftX,layout.panelHeight-1,54,2,blue)
    leftLabel(category.label or category.key, layout.leftX+2, layout.panelHeight+23, 12, white)
    button(layout.reset, false, 11)
    if showCareer and not athlete then button(layout.career,false,10) end

    for _, item in ipairs(layout.categories) do
        button(item, item.id == categoryIndex, item.label == "LEG SLEEVES" and 10 or 12)
    end

    for slot = 1, math.min(#category.choices, #layout.options) do
        local item = layout.options[slot]
        local index = firstOption + slot - 1
        item.label = category.choices[index]
        if category.key=="IDENTITY" and options then
            local key=index==1 and "first" or "last"
            local value=options.part==key and (options.draft or "").."|" or options[key]
            PolyLax.Style.panel(item.x,item.y,item.w,item.h,options.part==key,7)
            label(item.label,item.x,item.y+6,8,silver)
            label(value and value~="" and value or "Edit",item.x,item.y-7,9,white)
        elseif category.key == "TEAM" or category.key == "OPPONENT" then
            local city, name = item.label:match("^(.*) (%S+)$")
            if city then
                local active = index == selected
                PolyLax.Style.panel(item.x,item.y,item.w,item.h,active,7)
                label(city,item.x,item.y+6,9,active and white or silver)
                label(name,item.x,item.y-7,11,white)
            else
                button(item, index == selected, 11)
            end
        else
            button(item, index == selected, 11)
        end
    end
    button(layout.home,false,10)
    button(layout.left,false,16)
    button(layout.right, false, 16)
    label(tostring(selected) .. " / " .. tostring(#category.choices),
        layout.centerX, layout.footerY, 12, silver)
    endHud()
end

local glass = color(10, 21, 38, 222)
local glassSoft = color(14, 26, 43, 188)
local muted = color(169, 190, 210)
local sky = color(117, 204, 255)
local warm = color(255, 217, 98)
local red = color(251, 141, 137)
local function rounded(...)
    return PolyLax.Style.rounded(...)
end

function UI.press(layout, item, id)
    if not item or id == nil then return end
    layout.motion = layout.motion or {}
    layout.touches = layout.touches or {}
    UI.release(layout,id)
    local motion = layout.motion[item] or {amount=0,held=0}
    layout.motion[item], layout.touches[id] = motion, item
    motion.held = motion.held+1
    motion.amount = math.max(motion.amount,.18)
end

function UI.release(layout, id)
    local item = layout.touches and id ~= nil and layout.touches[id]
    if not item then return end
    local motion = layout.motion[item]
    motion.held = math.max(0,motion.held-1)
    layout.touches[id] = nil
end

function UI.step(layout, dt)
    if not layout.motion then return end
    for item, motion in pairs(layout.motion) do
        local target = motion.held > 0 and 1 or 0
        local easing = 1-math.exp(-(target == 1 and 27 or 17)*dt)
        motion.amount = motion.amount+(target-motion.amount)*easing
        if target == 0 and motion.amount < .002 then layout.motion[item] = nil end
    end
end

function UI.practiceLayout(showPositioning)
    local safe = UI.safeArea()
    local left, right = safe.left+12, WIDTH-safe.right-12
    local width, header = right-left, HEIGHT-safe.top
    local footer = math.max(12,safe.bottom+6)
    local tacticalHeight = 36
    local controlBase = footer+tacticalHeight+8
    local diameter = math.min(63,width*.205)
    local bX = right-diameter*.5-2
    local aX = bX-diameter-6
    local joyMaxX = left+math.min(width*.31,104)
    local joyX = (left+joyMaxX)*.5
    local joyRadius = math.min(39,(joyMaxX-left)*.44)
    local joyY = controlBase+joyRadius+1
    local auxRight = aX-diameter*.5-5
    local auxX = (joyMaxX+auxRight)*.5
    local auxWidth = math.min(64,auxRight-joyMaxX-4)
    local panelHeight = math.max(joyY+joyRadius+30,controlBase+diameter+36)
    local cameraW = math.max(106,math.min(137,width*.37))

    local layout = {
        panelHeight=panelHeight, headerY=header, leftX=left, rightX=right,
        centerX=(left+right)*.5, width=width, footer=footer, touches={}, motion={},
        frame={bottom=panelHeight+6,top=header-(showPositioning and 141 or 117)},
        joyX=joyX, joyY=joyY, joyRadius=joyRadius, joyMaxX=joyMaxX, joyMinY=controlBase,
        commands={}, tactical={},
        edit=box(right-25,header-60,50,32,"EDIT","edit"),
        reset=box(right-81,header-60,54,32,"RESET","reset"),
        zoomIn=box(right-18,header-98,36,33,"+","zoomIn"),
        zoomOut=box(right-58,header-98,36,33,"-","zoomOut"),
        camera=box(right-80-cameraW*.5,header-98,cameraW,33,"CAMERA","camera"),
        pause=box(left+25,header-98,50,33,"PAUSE","pause"),
        sprint=box(joyX,joyY+joyRadius+16,math.min(78,joyMaxX-left-6),28,"SPRINT","sprint")
    }
    if showPositioning then
        layout.positionNotice = box(layout.centerX,header-126,width,20)
    end

    local primaryA = box(aX,controlBase+diameter*.5,diameter,diameter,"PASS","pass")
    local primaryB = box(bX,controlBase+diameter*.89,diameter,diameter,"SHOOT","shoot")
    primaryA.primary, primaryB.primary = "A","B"
    layout.primaryA, layout.primaryB = primaryA, primaryB
    layout.commands = {
        box(auxX,controlBase+18,auxWidth,33,"DODGE","dodge"),
        box(auxX,controlBase+57,auxWidth,33,"PICK","setpick"),
        box(aX,controlBase+diameter+19,math.min(61,diameter),31,"SWITCH","switch"),
        primaryA, primaryB
    }

    layout.tacticalPanel = box(layout.centerX,footer+tacticalHeight*.5,width+8,tacticalHeight+6)
    local tactical = {
        {"swing","SWING"}, {"clear","CLEAR"}, {"passdown","PASS DOWN"}, {"pickdown","PICK DOWN"}
    }
    local span = width/#tactical
    for i,pair in ipairs(tactical) do
        local item = box(left+span*(i-.5),layout.tacticalPanel.y,span-5,tacticalHeight,pair[2],pair[1])
        item.tactical = true
        layout.tactical[i] = item
        layout.commands[#layout.commands+1] = item
    end
    return layout
end

local faceoffActions = {shoot="faceoff",pass="counter"}
local defenseActions = {pass="poke",shoot="body",dodge="slap",switch="switch"}
local legacyDefense = {pass="poke",switch="switch"}

local function holderOf(game)
    return game.carrier and game.squad[game.carrier]
end

function UI.action(game, item)
    if not item then return nil end
    local id = item.id
    if game.careerWaiting or id == "switch" and game.careerPlayer then return nil end
    if game.clubsPlayer and (id=="switch" or item.tactical) then return nil end
    if game.phase == "FACEOFF" then
        local draw = game.faceoff
        if game.clubsPlayer and (not draw or game.clubsPlayer~=draw.home.id) then return nil end
        if draw and (draw.userTeam == false or draw.phase == "EXIT") then return nil end
        if id == "pass" and (not draw or draw.meter == nil) then return nil end
        return faceoffActions[id]
    end
    if game.homeScore ~= nil and game.phase ~= "LIVE" then return nil end
    if game.inNet or game.clock and game.clock <= 0 then return nil end
    if id == "pass" and game.loose then return "scoop" end
    local holder = holderOf(game)
    if game.homeScore ~= nil and holder and holder.team == 2 then
        return (PolyLax.Defense and defenseActions or legacyDefense)[id]
    end
    if item.tactical and (not holder or game.pending or game.flight) then return nil end
    if id == "setpick" then
        local player = game.squad[game.controlled]
        if not holder or game.carrier == game.controlled or player and player.role == "G"
            or game.screen and game.screen.screener ~= game.controlled then return nil end
    end
    if id == "shoot" and game.carrier ~= game.controlled then return nil end
    if id == "pass" and not holder then return nil end
    if id == "sprint" and game.homeScore ~= nil and not holder then return nil end
    return id
end

local icons = {
    setpick={{-2,-7,-2,7},{2,-7,2,7},{-8,0,-2,0},{2,0,8,0}},
    switch={{-7,3,7,3},{7,3,3,7},{7,3,3,-1},{7,-3,-7,-3},{-7,-3,-3,-7},{-7,-3,-3,1}},
    dodge={{-7,-5,-2,3},{-2,3,2,-2},{2,-2,8,5},{8,5,4,5},{8,5,8,1}},
    slap={{-8,6,-2,3},{-2,3,7,-6},{-7,-3,-3,-3},{-5,-5,-5,-1},{2,6,7,6}},
    sprint={{-7,6,-1,0},{-1,0,-7,-6},{1,6,7,0},{7,0,1,-6}},
    pause={{-2,-6,-2,6},{2,-6,2,6}},
    camera={{-8,5,4,5},{4,5,4,-5},{4,-5,-8,-5},{-8,-5,-8,5},{4,2,8,5},{8,5,8,-5},{8,-5,4,-2}},
    zoomIn={{-5,0,5,0},{0,-5,0,5}},
    zoomOut={{-5,0,5,0}}
}
local actionNames = {faceoff="CLAMP",counter="COUNTER",body="BODY",poke="POKE",slap="SLAP",scoop="SCOOP"}

local function icon(name, x, y, factor, tint)
    local strokes = icons[name]
    if not strokes then return end
    stroke(tint)
    strokeWidth(1.65*factor)
    for _, edge in ipairs(strokes) do
        line(x+edge[1]*factor,y+edge[2]*factor,x+edge[3]*factor,y+edge[4]*factor)
    end
    noStroke()
end

local function motionAmount(layout, item)
    local motion = layout.motion[item]
    return motion and motion.amount or 0
end

local function chip(layout, item, name, symbol, emphatic)
    local press = 1-.06*motionAmount(layout,item)
    rounded(item.x,item.y,item.w,item.h,10,emphatic and warm or glass,press)
    if symbol then
        local iconX = name == "" and item.x or item.x-item.w*.5+15
        icon(symbol,iconX,item.y,.76,emphatic and navy or sky)
    end
    if name ~= "" then
        label(name,item.x+(symbol and 7 or 0),item.y,10,emphatic and navy or white)
    end
end

local primaryBlue = color(27,92,204,248)
local primaryBlueLight = color(58,132,242,244)
local primaryBlueDark = color(30,53,87,227)
local primaryRed = color(184,45,64,248)
local primaryRedLight = color(223,71,93,244)
local primaryRedDark = color(82,39,52,227)
local primaryRim = color(155,181,207,195)
local controlShadow = color(5,9,14,208)
local graphite = color(34,42,52,241)
local graphiteDim = color(26,33,42,228)
local graphiteEdge = color(107,122,136,132)

local function compactAction(layout, item, action, textValue, active)
    local press = 1-.06*motionAmount(layout,item)
    local fillTint = active and warm or action and graphite or graphiteDim
    local textTint = active and navy or action and white or muted
    rounded(item.x,item.y,item.w,item.h,9,graphiteEdge,press)
    rounded(item.x,item.y,item.w-2,item.h-2,8,fillTint,press)
    local symbol = not item.tactical and item.w >= 54 and (action or item.id)
    local hasSymbol = symbol and icons[symbol]
    if hasSymbol then
        icon(symbol,item.x-item.w*.5+11,item.y,.63,active and navy or muted)
    end
    label(textValue,item.x+(hasSymbol and 5 or 0),item.y,item.w < 51 and 9 or 10,textTint)
end

local function primaryAction(layout, item, action, textValue, active)
    local press = 1-.085*motionAmount(layout,item)
    local span = item.w*press
    local isBlue = item.primary == "A"
    local fillTint = action and (isBlue and primaryBlue or primaryRed)
        or (isBlue and primaryBlueDark or primaryRedDark)
    local face = action and (isBlue and primaryBlueLight or primaryRedLight) or fillTint
    ellipseMode(CENTER)
    fill(controlShadow)
    ellipse(item.x,item.y-2,span+2)
    fill(active and warm or primaryRim)
    ellipse(item.x,item.y,span+1)
    fill(fillTint)
    ellipse(item.x,item.y,span-2)
    fill(face)
    ellipse(item.x,item.y+2,span-7)
    label(item.primary,item.x,item.y+7,23,action and white or muted)
    label(textValue,item.x,item.y-13,item.w < 51 and 8 or 9,action and white or muted)
end

local function drawAim(guide)
    if not guide then return end
    local start, target = guide.from, guide.target
    stroke(color(255,217,98,196))
    strokeWidth(2)
    line(start.x,start.y,target.x,target.y)
    stroke(warm)
    noFill()
    ellipseMode(CENTER)
    ellipse(target.x,target.y,20)
    line(target.x-14,target.y,target.x-8,target.y)
    line(target.x+8,target.y,target.x+14,target.y)
    line(target.x,target.y-14,target.x,target.y-8)
    line(target.x,target.y+8,target.x,target.y+14)
    noStroke()
end

local function drawScore(layout, game)
    local x, y = layout.centerX, layout.headerY-19
    local left, right = layout.leftX, layout.rightX
    rounded(x,y,layout.width,34,12,glass)
    local minutes, seconds = math.floor(game.clock/60), math.floor(game.clock%60)
    local time = string.format("%d:%02d",minutes,seconds)
    if game.homeScore ~= nil then
        local home, away = game.homeTeam, game.awayTeam
        local homeColor = home.home and home.home.accent or sky
        local awayColor = away.home and away.home.accent or muted
        rounded(left+10,y,4,18,2,homeColor)
        rounded(right-10,y,4,18,2,awayColor)
        label(home.short,left+33,y,13,white)
        label(away.short,right-33,y,13,white)
        label(tostring(game.homeScore),left+67,y,19,white)
        label(tostring(game.awayScore),right-67,y,19,white)
        label("Q"..game.period.."   "..time,x,y,13,warm)
    else
        leftLabel("POLYLAX",left+11,y,15,white)
        label(time,x,y,14,warm)
        label("G "..game.goals.."   P "..game.passes,right-43,y,11,muted)
    end

    local holder = game.carrier and game.squad[game.carrier]
    local controlled = game.squad[game.controlled]
    local contact = holder and holder.name
        or game.inNet and "IN NET"
        or game.flight and "IN FLIGHT"
        or "LOOSE"
    if holder and game.homeScore ~= nil then
        contact = (holder.team == 1 and game.homeTeam.short or game.awayTeam.short).." "..contact
    elseif game.phase == "FACEOFF" then
        contact = "FACEOFF"
    end
    local status = (controlled and controlled.name or "-").."  /  "..contact
    local width = math.min(layout.width-116,math.max(114,#status*6.5+16))
    rounded(left+width*.5,layout.edit.y,width,32,10,glassSoft)
    leftLabel(status,left+8,layout.edit.y,11,white)
    if not game.clubsPlayer then
        chip(layout,layout.reset,"RESET")
        chip(layout,layout.edit,"EDIT")
    end
end

local stickFace = color(13,19,26,232)
local stickThumb = color(61,74,90,247)
local stickLight = color(126,140,155,203)
local stickTexture = color(160,175,190,135)
local function drawJoystick(layout, x, y)
    local r, jx, jy = layout.joyRadius, layout.joyX, layout.joyY
    local knobX, knobY = jx+x*r*.55,jy+y*r*.55
    ellipseMode(CENTER)
    fill(controlShadow)
    ellipse(jx,jy-2,r*2+3)
    fill(graphiteEdge)
    ellipse(jx,jy,r*2+2)
    fill(graphite)
    ellipse(jx,jy,r*2)
    fill(stickFace)
    ellipse(jx,jy,r*1.70)
    stroke(graphiteEdge)
    strokeWidth(1.2)
    for index=0,11 do
        local theta = index*math.pi/6
        local dx,dy = math.cos(theta),math.sin(theta)
        local inner = r*(index % 3 == 0 and .78 or .86)
        line(jx+dx*inner,jy+dy*inner,jx+dx*r*.96,jy+dy*r*.96)
    end
    noStroke()
    fill(controlShadow)
    ellipse(knobX,knobY-2,r*.93)
    fill(stickLight)
    ellipse(knobX,knobY,r*.90)
    fill(stickThumb)
    ellipse(knobX,knobY+1,r*.80)
    fill(stickTexture)
    for column=-2,2 do
        for row=-2,2 do
            if column*column+row*row <= 5 then
                ellipse(knobX+column*r*.105,knobY+row*r*.105,1.6)
            end
        end
    end
end

local function clamp01(value)
    return math.max(0,math.min(1,value))
end

local meterTrack = color(46,62,82,255)
local meterWindow = color(87,192,142,235)
local function drawFaceoff(layout, game)
    local faceoff = game.faceoff
    if game.phase ~= "FACEOFF" or not faceoff then return end
    local x, y = layout.centerX,layout.frame.bottom+48
    local width = math.min(264,layout.width-20)
    local meterWidth, yMeter = width-30,y-3
    local defaultTime = 1.55
    local meter = clamp01(faceoff.meter or (game.phaseTime or 0)/defaultTime)
    local start = clamp01(faceoff.windowStart or .74/defaultTime)
    local finish = clamp01(faceoff.windowEnd or 1.18/defaultTime)
    local left = x-meterWidth*.5
    local cpu = faceoff.cpuMeter or (type(faceoff.cpu) == "number" and faceoff.cpu)
    local exit = faceoff.phase == "EXIT"
    local title, prompt = "FACEOFF","Time your clamp in the green"
    if exit then
        title,prompt = "CHOOSE EXIT","Move to your outlet"
        if faceoff.result and faceoff.result.loose then
            title,prompt = "LOOSE BALL","Chase the exit"
        end
    elseif faceoff.active == false then
        title,prompt = "GET SET","Watch the whistle"
    end
    if faceoff.userTeam == false then
        title,prompt = "FACEOFF","Waiting for possession"
    end

    rounded(x,y,width,77,15,glass)
    label(title,x,y+22,13,white)
    rounded(x,yMeter,meterWidth,13,6,meterTrack)
    rounded(left+meterWidth*(start+finish)*.5,yMeter,meterWidth*(finish-start),
        13,6,meterWindow)
    if faceoff.sweetSpot then
        rounded(left+meterWidth*clamp01(faceoff.sweetSpot),yMeter,2,11,1,white)
    end
    rounded(left+meterWidth*meter,yMeter,6,20,3,warm)
    if cpu then rounded(left+meterWidth*clamp01(cpu),yMeter-12,5,5,2,red) end
    label(prompt,x,y-25,11,muted)
end

local function finalScore(game, layout)
    local x, y = layout.centerX,(layout.frame.top+layout.frame.bottom)*.5
    local home, away = game.stats[1],game.stats[2]
    rounded(x,y,layout.width-9,176,22,glass)
    label("FINAL SCORE",x,y+63,13,muted)
    label(string.format("%s %d  -  %d %s",game.homeTeam.short,game.homeScore,
        game.awayScore,game.awayTeam.short),x,y+34,25,warm)
    label(string.format("SHOTS  %d - %d       SAVES  %d - %d",
        home.shots,away.shots,home.saves,away.saves),x,y+1,12,white)
    label(string.format("GROUND BALLS   %d - %d",home.groundBalls,away.groundBalls),x,y-26,12,white)
    label(string.format("TURNOVERS   %d - %d",home.turnovers,away.turnovers),x,y-52,12,white)
end

local function drawBallEdge(mark)
    if not mark then return end
    local x, y, dx, dy = mark.x,mark.y,mark.dx,mark.dy
    rounded(x-dx*6,y-dy*6,22,22,10,glass)
    fill(warm)
    ellipseMode(CENTER)
    ellipse(x-dx*6,y-dy*6,6)
    stroke(warm)
    strokeWidth(2)
    line(x+dx*7,y+dy*7,x-dy*4,y+dx*4)
    line(x+dx*7,y+dy*7,x+dy*4,y-dx*4)
    noStroke()
end

local function passTarget(layout, guide)
    if not guide or guide.y < layout.frame.bottom or guide.y > layout.frame.top
        or guide.x < layout.leftX or guide.x > layout.rightX then return end
    local x, y = guide.x,guide.y
    local tint = guide.manual and sky or white
    ellipseMode(CENTER)
    stroke(tint)
    strokeWidth(guide.manual and 2.5 or 1.5)
    noFill()
    ellipse(x,y,guide.manual and 26 or 20)
    noStroke()
    if guide.name and guide.name ~= "" then
        local w = math.min(124,math.max(38,#guide.name*6+14))
        local bx = math.max(layout.leftX+w*.5,math.min(layout.rightX-w*.5,x))
        local by = y+21 < layout.frame.top and y+21 or y-21
        rounded(bx,by,w,18,7,glass)
        label(guide.name,bx,by,10,tint)
    end
end

local function tacticMode(game)
    local value = game.mode
    if type(game.tactical) == "table" and game.tactical.team ~= 2 then
        value = game.tactical.call or game.tactical.mode or game.tactical.name or value
    elseif type(game.tactical) == "string" then
        value = game.tactical
    end
    return type(value) == "string" and value:gsub("[%s_%-]",""):lower()
end

local function commandLabel(item, action, game, aim)
    if action == "shoot" and aim then return "AIM" end
    if action == "pass" and game.carrier and game.carrier ~= game.controlled then return "CALL" end
    return actionNames[action] or item.label
end

local warningGlass = color(57,42,22,237)
local offsidesGlass = color(63,29,41,240)
local function drawPositionNotice(layout, game)
    local positioning = game.positioning
    if game.phase ~= "LIVE" or not positioning or (positioning.noticeTime or 0) <= 0 then return end
    local message = positioning.notice
    if type(message) ~= "string" or message == "" then return end
    local strip = layout.positionNotice
    local x, y, width, height = layout.centerX,layout.frame.top-15,layout.width,23
    if strip then x, y, width, height = strip.x,strip.y,strip.w,strip.h end
    local foul = positioning.level == "offsides"
    local ink = foul and red or warm
    local size = 11
    if textSize then
        fontSize(size)
        local measured = textSize(message)
        if measured > width-25 then size = math.max(9,size*(width-25)/measured) end
    end
    rounded(x,y,width,height,8,foul and offsidesGlass or warningGlass)
    rounded(x-width*.5+8,y,3,height*.59,1.5,ink)
    label(message,x+3,y,size,ink)
    return message
end

local function drawRulesClock(layout, game)
    local strip, clock = layout.positionNotice, game.ruleClock
    if not strip or game.phase ~= "LIVE" or not clock then return end
    local labels = {}
    if clock.shot then labels[#labels+1] = "SHOT "..math.ceil(clock.shot) end
    if clock.clear then labels[#labels+1] = "CLEAR "..math.ceil(clock.clear) end
    if clock.crease then labels[#labels+1] = "CREASE "..math.ceil(clock.crease) end
    if #labels == 0 then return end
    local remaining = math.min(clock.shot or math.huge,clock.clear or math.huge,
        clock.crease or math.huge)
    rounded(strip.x,strip.y,strip.w,strip.h,8,glassSoft)
    label(table.concat(labels,"    ·    "),strip.x,strip.y,11,remaining <= 5 and warm or white)
end

function UI.practice(layout, game, moveX, moveZ, aim, cameraLabel, ballEdge, passGuide)
    beginHud()
    local positionMessage = drawPositionNotice(layout,game)
    if not positionMessage then drawRulesClock(layout,game) end
    drawAim(aim)
    drawBallEdge(ballEdge)
    passTarget(layout,passGuide)
    drawScore(layout,game)
    chip(layout,layout.pause,game.clubsPlayer and "LOBBY" or "PAUSE","pause")
    chip(layout,layout.camera,cameraLabel or "CAMERA","camera")
    chip(layout,layout.zoomOut,"","zoomOut")
    chip(layout,layout.zoomIn,"","zoomIn")

    local bar = layout.tacticalPanel
    rounded(bar.x,bar.y,bar.w,bar.h,11,glassSoft)
    drawJoystick(layout,moveX,moveZ)
    local sprintAction = UI.action(game,layout.sprint)
    compactAction(layout,layout.sprint,sprintAction,"SPRINT",
        sprintAction and motionAmount(layout,layout.sprint)>.1)

    local mode = tacticMode(game)
    local screen = game.screen
    local settingPick = screen and screen.phase ~= "RELEASE" and screen.screener == game.controlled
    for _, item in ipairs(layout.commands) do
        local action = UI.action(game,item)
        local active = item.tactical and mode == item.id
            or action == "shoot" and aim ~= nil
            or action == "setpick" and settingPick
        local title = commandLabel(item,action,game,aim)
        if item.primary then
            primaryAction(layout,item,action,title,active)
        else
            compactAction(layout,item,action,title,active)
        end
    end

    if game.phase == "FINAL" then
        finalScore(game,layout)
    else
        drawFaceoff(layout,game)
        local message = game.clubsStatus or game.careerWaiting and game.phase == "LIVE" and "FIRST SHIFT SOON"
            or game.announcementTime > 0 and game.announcement
            or game.clock <= 0 and game.homeScore == nil and "PRACTICE COMPLETE"
        if message and message ~= "" and message ~= positionMessage then
            local spacing = positionMessage and not layout.positionNotice and 33 or 0
            local y = layout.frame.top-15-spacing
            rounded(layout.centerX,y,math.min(layout.width,#message*8+32),34,12,glass)
            label(message,layout.centerX,y,14,warm)
        end
    end
    endHud()
end
end

-- Athlete
do
-- PolyLax 2.0 | Career athlete identity and appearance
PolyLax = PolyLax or {}
local P = PolyLax
local Athlete = {}
P.Athlete = Athlete

local minimumHeight, maximumHeight = 64, 82
local defaultHeights = {70, 72, 72, 79}
Athlete.nameLimit = 18
local appearanceSchema = 1
local heightChoices = {}
for inches = minimumHeight, maximumHeight do
    heightChoices[#heightChoices + 1] = string.format("%d'%d\"", math.floor(inches/12), inches % 12)
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function option(value, count)
    value = tonumber(value)
    if value and value % 1 == 0 and value >= 1 and value <= count then return value end
end

local function cleanName(value)
    if type(value) ~= "string" then return "" end
    value = value:gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local stop = math.min(#value, Athlete.nameLimit)
    while stop > 0 and stop < #value do
        local nextByte = value:byte(stop + 1)
        if nextByte < 128 or nextByte >= 192 then break end
        stop = stop - 1
    end
    local cut = value:sub(1, stop):gsub("%s+$", "")
    if utf8 and not utf8.len(cut) then return "" end
    return cut
end

local function storedAppearance(career)
    return type(career.appearance) == "table" and career.appearance or {}
end

function Athlete.names(career)
    local appearance = storedAppearance(career)
    local legacy = type(career.name) == "string" and career.name or "New Player"
    local first, last = legacy:match("^%s*(%S+)%s*(.-)%s*$")
    local savedFirst = cleanName(appearance.firstName)
    if savedFirst == "" then savedFirst = cleanName(first) end
    local savedLast = type(appearance.lastName) == "string" and appearance.lastName or last
    return savedFirst ~= "" and savedFirst or "New", cleanName(savedLast)
end

function Athlete.name(career)
    local first, last = Athlete.names(career)
    return last == "" and first or first .. " " .. last
end

local function isAppearance(category)
    return category.key ~= "TEAM" and category.key ~= "OPPONENT"
end

function Athlete.profile(career, fallback)
    local saved = storedAppearance(career)
    fallback = fallback or {}
    local profile = {TEAM=career.team}
    for _, category in ipairs(P.Profile.categories) do
        if isAppearance(category) then
            local key, count = category.key, #category.choices
            profile[key] = option(saved[key], count) or option(fallback[key], count) or category.default
        end
    end
    local height = defaultHeights[profile.BODY] or 72
    profile.HEIGHT = option(saved.HEIGHT, #heightChoices) or height - minimumHeight + 1
    return profile
end

function Athlete.heightInches(profile)
    local index = option(profile.HEIGHT, #heightChoices)
    return index and minimumHeight + index - 1
end

function Athlete.heightScale(profile)
    local inches = Athlete.heightInches(profile)
    return inches and inches / 72
end

function Athlete.canChange(career, locked)
    return not locked and career.stage == "highSchool" and (career.games or 0) == 0
end

function Athlete.categories(career, locked, positionMutable)
    local base = {}
    for _, category in ipairs(P.Profile.categories) do base[category.key] = category end
    local positions, positionValues = {}, {}
    local mutable = Athlete.canChange(career, locked)
    if positionMutable == nil then positionMutable = mutable end
    for index, position in ipairs(P.Career.positions) do
        if positionMutable or index == career.position then
            positions[#positions + 1], positionValues[#positionValues + 1] = position.label, index
        end
    end
    local teams, teamValues = {}, {}
    if mutable then
        for _, school in ipairs(P.SchoolTeams.highSchool) do
            teams[#teams + 1], teamValues[#teamValues + 1] = school.name, school.id
        end
    else
        local current = P.TeamUniform.get(career.team)
        teams[1], teamValues[1] = current.name, current.id
    end
    return {
        {key="IDENTITY", choices={"FIRST NAME", "LAST NAME"}, default=1},
        {key="POSITION", choices=positions, values=positionValues, default=1},
        {key="HEIGHT", choices=heightChoices, default=9},
        {key="BODY", label="BUILD", choices={"LEAN", "ATHLETIC", "STOCKY", "SLIM"}, default=2},
        {key="TEAM", label="TEAM", choices=teams, values=teamValues, default=1},
        base.NUMBER, base.FACE, base.HAIR, base.BEARD,
        {key="HELMET", choices={"TEAM","STEEL","DARK","ACCENT","SATIN","MATTE",
            "CHROME","DARK CHROME","BRIGHT CHROME","SATIN CHROME","ACCENT CHROME"},default=1},
        {key="GLOVES", choices={"TEAM","STEEL TRIM","ACCENT","DARK CUFF","SATIN","MATTE"},default=1},
        base.SHORTS,
        base.CLEATS, base.STICK, base.SLEEVES, base.HOODIE
    }
end

function Athlete.choice(career, profile, category)
    if category.values then
        local value = category.key == "POSITION" and career.position or career.team
        for index, available in ipairs(category.values) do
            if value == available then return index end
        end
        return 1
    end
    return option(profile[category.key], #category.choices) or category.default
end

local function draft(career, fallback)
    local candidate = copy(career)
    local saved = copy(storedAppearance(career))
    local profile = Athlete.profile(career, fallback)
    for key, value in pairs(profile) do
        if key ~= "TEAM" then saved[key] = value end
    end
    saved.schema = appearanceSchema
    saved.firstName, saved.lastName = Athlete.names(career)
    candidate.appearance, candidate.name = saved, Athlete.name(career)
    return candidate
end

local function commit(career, candidate, save)
    save = save or P.Career.save
    if not save(candidate) then return false, "Could not save appearance" end
    for key in pairs(career) do
        if candidate[key] == nil then career[key] = nil end
    end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

function Athlete.ensure(career, fallback, save)
    if storedAppearance(career).schema == appearanceSchema then
        career.name = Athlete.name(career)
        return true
    end
    return commit(career, draft(career, fallback), save)
end

function Athlete.rename(career, fallback, part, value, save)
    if part ~= "first" and part ~= "last" then return false end
    local clean = cleanName(value)
    if part == "first" and clean == "" then return false, "Enter a first name" end
    local candidate = draft(career, fallback)
    candidate.appearance[part == "first" and "firstName" or "lastName"] = clean
    candidate.name = Athlete.name(candidate)
    return commit(career, candidate, save)
end

function Athlete.select(career, fallback, category, index, locked, save, positionMutable)
    index = option(index, #category.choices)
    if not index or category.key == "IDENTITY" then return false end
    local key = category.key
    local candidate = draft(career, fallback)
    if key == "POSITION" or key == "TEAM" then
        local value = category.values and category.values[index]
        if not value then return false end
        local mutable = Athlete.canChange(career, locked)
        if key == "POSITION" and positionMutable ~= nil then mutable = positionMutable end
        if not mutable then
            return false, key == "TEAM" and "Team changes follow recruiting" or "Position is locked"
        end
        if key == "POSITION" then
            if value == career.position then return Athlete.ensure(career, fallback, save) end
            if save then
                candidate.position = value
                if not career.development or (career.development.spent or 0) == 0 then
                    candidate.attributes = P.Attributes.forPosition(value)
                end
                return commit(career, candidate, save)
            end
            if not P.Career.setPosition(candidate, value) then return false, "Could not save position" end
            for name, item in pairs(candidate) do career[name] = item end
            return true
        end
        local school = P.SchoolTeams.get(value)
        if not school or school.group ~= "highSchool" then return false, "Choose a high school" end
        if candidate.team ~= school.id then
            candidate.team, candidate.seasonData = school.id, nil
        end
    elseif key == "HEIGHT" or candidate.appearance[key] ~= nil then
        candidate.appearance[key] = index
    else
        return false
    end
    return commit(career, candidate, save)
end

function Athlete.uniform(career, isAway)
    local team = P.TeamUniform.get(career.team)
    return isAway and team.away or team.home
end
end

-- Career
do
-- PolyLax Build 013 | Road to the Pros player profile and match handoff
PolyLax = PolyLax or {}
local P = PolyLax
local Career = {}
P.Career = Career

local saveKey = "PolyLax.Career.1"
local statKeys = {"goals","assists","points","saves","goalsAllowed","shotsFaced",
    "groundBalls","faceoffs","faceoffsWon","faceoffAttempts","causedTurnovers","interceptions","shots","shotsOnGoal",
    "passes","completions","turnovers","committedForcedTurnovers","unforcedTurnovers",
    "fouls","penalties","penaltyMinutes","gamesPlayed","gamesStarted","minutesPlayed",
    "screens","screenAssists","screenOpenShots","illegalScreens"}
Career.statKeys = statKeys

Career.positions = {
    {label="Attack", slot=1, attributes={shooting=68, ballSecurity=67, speed=69, strength=64}},
    {label="Midfield", slot=5, attributes={speed=72, stamina=71, passing=65, strength=66}},
    {label="Defense", slot=7, attributes={stickCheck=72, bodyCheck=70, interception=70, strength=73}},
    {label="Faceoff", slot=4, attributes={faceoff=76, reaction=69, stamina=70, strength=70}},
    {label="Goalie", slot=10, attributes={reflexes=75, handSpeed=74, clearingAccuracy=68, strength=62}},
    {label="Long-Stick Mid", slot=5, role="LSM"},
    {label="Short-Stick Def Mid", slot=6, role="SSDM"}
}

Career.stages = {highSchool="HIGH SCHOOL", college="COLLEGE", professional="PROFESSIONAL"}

local function position(index)
    return Career.positions[index] or Career.positions[2]
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function defaults(index)
    return P.Attributes.forPosition(index)
end

local function nameOf(value)
    return type(value) == "string" and value:sub(1, 24):gsub("[%c]", "") or ""
end

local function bounded(value, min, max)
    return math.max(min, math.min(max, math.floor(tonumber(value) or min)))
end

local function statValue(key,value)
    value=tonumber(value) or 0
    if key=="minutesPlayed" or key=="penaltyMinutes" then return math.min(1000000,math.max(0,value)) end
    return bounded(value,0,1000000)
end

local function careerStats(stats)
    if type(stats) ~= "table" then stats = {} end
    if stats.points==nil then stats.points=(tonumber(stats.goals) or 0)+(tonumber(stats.assists) or 0) end
    if stats.faceoffsWon==nil then stats.faceoffsWon=stats.faceoffs end
    for _, key in ipairs(statKeys) do stats[key] = statValue(key,stats[key]) end
    stats.screenCoachPoints = bounded(tonumber(stats.screenCoachPoints) or 0, -1000000, 1000000)
    return stats
end

function Career.new()
    return {version=1, name="New Player", position=2, stage="highSchool", team="briarbank",
        season=1, games=0, wins=0, losses=0, ties=0, xp=0, stats=careerStats(), entries={},
        attributes=defaults(2)}
end

function Career.load()
    local fresh = Career.new()
    local raw = readLocalData and readLocalData(saveKey)
    if type(raw) ~= "string" or not json then return fresh end
    local ok, saved = pcall(json.decode, raw)
    if not ok or type(saved) ~= "table" or saved.version ~= fresh.version then return fresh end
    saved.position = bounded(saved.position, 1, #Career.positions)
    saved.name = nameOf(saved.name)
    if saved.name == "" then saved.name = fresh.name end
    if not Career.stages[saved.stage] then saved.stage = fresh.stage end
    if type(saved.team) ~= "string" and type(saved.team) ~= "number" then saved.team = fresh.team end
    local school = P.SchoolTeams.get(saved.team)
    if saved.stage == "highSchool" and (not school or school.group ~= "highSchool") then
        saved.team = fresh.team
    elseif saved.stage == "college" and (not school or school.group == "highSchool") then
        saved.team = "syracuse"
    elseif saved.stage == "professional" then
        saved.team = bounded(saved.team, 1, #P.TeamUniform.teams)
    elseif school then
        saved.team = school.id
    end
    for _, key in ipairs({"games", "wins", "losses", "ties", "xp"}) do
        saved[key] = bounded(saved[key], 0, 1000000)
    end
    saved.season = bounded(saved.season, 1, 10000)
    saved.championships = bounded(saved.championships, 0, 10000)
    saved.spentXP = bounded(saved.spentXP, 0, saved.xp)
    if saved.stage == "professional" then
        local contract = type(saved.contract) == "table" and saved.contract or {}
        saved.contract = {length=bounded(contract.length,1,5),remaining=bounded(contract.remaining,0,5),
            value=bounded(contract.value,0,1000000)}
    else
        saved.contract = nil
    end
    saved.history = type(saved.history) == "table" and saved.history or {}
    saved.attributes=P.Attributes.restore(saved.attributes,saved.position)
    local stored=type(saved.stats)=="table" and saved.stats or {}
    if stored.gamesPlayed==nil then stored.gamesPlayed=saved.games end
    saved.stats=careerStats(stored)
    saved.entries = type(saved.entries) == "table" and saved.entries or {}
    return saved
end

function Career.save(career)
    if not saveLocalData or not json then return false end
    local ok, raw = pcall(json.encode, career)
    if not ok then return false end
    return pcall(saveLocalData, saveKey, raw)
end

function Career.rename(career, value)
    local name = nameOf(value):match("^%s*(.-)%s*$")
    if name == "" then return false end
    career.name = name
    return Career.save(career)
end

function Career.setPosition(career, index)
    if career.games > 0 or not Career.positions[index] then return false end
    career.position, career.attributes = index, defaults(index)
    return Career.save(career)
end

function Career.teamName(career)
    return P.TeamUniform.get(career.team).name
end

function Career.cycleSchool(career)
    if career.games > 0 or career.stage ~= "highSchool" then return false end
    local list = P.SchoolTeams.highSchool
    for index, school in ipairs(list) do
        if school.id == career.team then
            career.team = list[index % #list+1].id
            return Career.save(career)
        end
    end
    return false
end

function Career.fixture(career)
    return P.CareerSeason.fixture(career)
end

function Career.matchOptions(career, fixture)
    local home = P.TeamUniform.get(career.team)
    local age = home.ruleset
    local ruleset = ({highSchool="highSchool",ncaa="ncaa",club="collegeClub",
        professional="professional"})[home.fieldType] or "arcade"
    return {name="Career short game", profile=ruleset, periods=2, periodLength=60, intermissionTime=2,
        ageGroup=age, bodyContact=age == "highSchool" or age == "adult",
        faceoffDifficulty=career.stage == "professional" and "HARD" or "NORMAL",
        careerEntryDelay=P.CareerSeason.status(career).starter and 0 or 4,
        fieldTeam=fixture.home and career.team or fixture.opponent, venueAway=not fixture.home,
        careerPlayerSlot=position(career.position).slot, careerPlayerRole=position(career.position).role,
        playerName=career.name,
        playerAttributes=copy(career.attributes)}
end

local function screenEvaluation(events)
    local result, points = {}, 0
    for _, item in ipairs(type(events) == "table" and events or {}) do
        if type(item) == "table" and type(item.kind) == "string" and item.kind ~= ""
            and type(item.points) == "number" and item.points % 1 == 0 then
            local eventPoints = bounded(item.points, -100, 100)
            local event = {kind=item.kind:sub(1, 40), points=eventPoints}
            if type(item.time) == "number" and item.time >= 0 and item.time < math.huge then
                event.time = item.time
            end
            result[#result+1] = event
            points = points + eventPoints
        end
    end
    return result, points
end

function Career.record(career, fixture, match)
    if not fixture or not match or match.phase ~= "FINAL" then return false end
    if career.entries[fixture.id] then return false end
    local player = match.squad[match.careerPlayer]
    if not player then return false end
    local nextSave = copy(career)
    nextSave.stats, nextSave.entries = copy(career.stats), copy(career.entries)
    local box=P.Statistics.finalize(match)
    local actual=box and box.players["career-player"]
    local personal, oldStats = {}, actual and actual.stats or player.stats or {}
    for _, key in ipairs(statKeys) do
        local value = oldStats[key]
        if key == "causedTurnovers" then value = value or oldStats.forcedTurnovers end
        value=statValue(key,value)
        personal[key] = value
        nextSave.stats[key] = (career.stats[key] or 0) + value
    end
    local screenEvents, coachPoints = screenEvaluation(player.screenCoachEvents)
    personal.screenCoachPoints = coachPoints
    nextSave.stats.screenCoachPoints = (career.stats.screenCoachPoints or 0) + coachPoints
    local win = match.homeScore > match.awayScore
    local tie = match.homeScore == match.awayScore
    nextSave.games = nextSave.games + 1
    if win then nextSave.wins = nextSave.wins + 1
    elseif tie then nextSave.ties = nextSave.ties + 1
    else nextSave.losses = nextSave.losses + 1 end
    local earned = 20 + (win and 10 or 0) + personal.goals * 6
        + personal.assists * 5 + personal.saves * 3 + personal.faceoffs * 4
        + personal.groundBalls * 2 + personal.causedTurnovers * 4 + personal.interceptions * 3
    nextSave.xp = nextSave.xp + earned
    P.Development.onMatch(nextSave,fixture,personal,match)
    if not P.CareerSeason.record(nextSave,fixture,match,earned,personal,screenEvents,box) then
        return false, "This result does not match the scheduled game"
    end
    local trophies=#P.Awards.trophies(nextSave)
    P.Awards.finalize(nextSave)
    nextSave.xp=nextSave.xp+30*(#P.Awards.trophies(nextSave)-trophies)
    nextSave.entries[fixture.id] = {home=match.homeScore, away=match.awayScore,
        opponent=fixture.opponent, stats=personal, screenCoachEvents=screenEvents}
    if not Career.save(nextSave) then return false, "Save unavailable" end
    for key, value in pairs(nextSave) do career[key] = value end
    return true
end
end

-- Development
do
-- PolyLax 2.0 | Skill points, match rewards and training menu
PolyLax = PolyLax or {}
local P = PolyLax
local Development = {}
P.Development = Development

local schema = 1
local milestones = {
    {id="firstMatch", key="games", target=1, points=6},
    {id="fiveMatches", key="games", target=5, points=12},
    {id="firstWin", key="wins", target=1, points=6},
    {id="firstGoal", key="goals", target=1, points=6},
    {id="firstAssist", key="assists", target=1, points=5},
    {id="fiveSaves", key="saves", target=5, points=8},
    {id="fiveDraws", key="faceoffs", target=5, points=8},
    {id="tenGroundBalls", key="groundBalls", target=10, points=8},
    {id="firstScreen", key="screens", target=1, points=5}
}

local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge then return minimum end
    return math.max(minimum, math.min(maximum, math.floor(value)))
end

local function count(value)
    return integer(value, 0, 10000000)
end

local function copy(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do result[key] = value end
    end
    return result
end

local function savedState(career)
    local saved = career.development
    return type(saved) == "table" and saved.schema == schema and saved or nil
end

function Development.points(career)
    local xp = count(career.xp)
    local legacySpent = math.min(xp, count(career.spentXP))
    local saved = savedState(career)
    if not saved then return xp - legacySpent end
    -- Take in only XP and legacy expenditures accumulated since the last write.
    local earned = math.max(0, xp - count(saved.accountedXP))
    local spent = math.max(0, legacySpent - count(saved.accountedLegacy))
    return count(count(saved.points) + earned - spent)
end

local function snapshot(career)
    local saved = savedState(career) or {}
    return {
        schema=schema, points=Development.points(career),
        accountedXP=count(career.xp), accountedLegacy=math.min(count(career.xp), count(career.spentXP)),
        spent=count(saved.spent), claims=copy(saved.claims), milestones=copy(saved.milestones),
        lastReward=saved.lastReward
    }
end

function Development.claimed(career, key)
    local saved = savedState(career)
    return saved ~= nil and type(saved.claims) == "table" and saved.claims[key] == true
end

local function commit(career, candidate, save)
    save = save or P.Career.save
    if not save(candidate) then return false, "Could not save development" end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

local function performancePoints(stats)
    local score = count(stats.goals) * 2 + count(stats.assists) * 2 + count(stats.saves)
        + count(stats.groundBalls) + count(stats.faceoffs) * 2
        + count(stats.causedTurnovers) * 2 + count(stats.interceptions) * 2
        - count(stats.turnovers) - count(stats.fouls) * 2
    return integer(score, 0, 18)
end

local function milestonePoints(candidate, state, stats, won)
    local earned = 0
    local cumulative = type(candidate.stats) == "table" and candidate.stats or {}
    for _, milestone in ipairs(milestones) do
        local key = milestone.key
        local total, new
        if key == "games" then
            total, new = count(candidate.games), 1
        elseif key == "wins" then
            total, new = count(candidate.wins), won and 1 or 0
        else
            total, new = count(cumulative[key]), count(stats[key])
        end
        if not state.milestones[milestone.id] and total >= milestone.target and total - new < milestone.target then
            state.milestones[milestone.id] = true
            earned = earned + milestone.points
        end
    end
    return earned
end

-- Career.record owns the match transaction. This only updates its candidate.
function Development.onMatch(candidate, fixture, actualStats, match)
    if not fixture or type(fixture.id) ~= "string" or fixture.id == ""
        or not match or match.phase ~= "FINAL" then return false end
    local key = "match:" .. fixture.id
    if Development.claimed(candidate, key) then return false end
    actualStats = type(actualStats) == "table" and actualStats or {}
    local state = snapshot(candidate)
    local previous = savedState(candidate)
    local matchXP = previous and math.max(0, state.accountedXP - count(previous.accountedXP)) or nil
    local performance = performancePoints(actualStats)
    local coach = integer(count(actualStats.screenCoachPoints) * .5, 0, 8)
    local won = count(match.homeScore) > count(match.awayScore)
    local milestone = milestonePoints(candidate, state, actualStats, won)
    local bonus = performance + coach + milestone
    state.points = count(state.points + bonus)
    state.lastReward = {kind="match", xp=matchXP, performance=performance, coach=coach,
        milestone=milestone, bonus=bonus}
    state.claims[key] = true
    candidate.development = state
    return true, state.lastReward
end

function Development.reward(career, key, xp, bonus)
    if type(key) ~= "string" or key == "" or #key > 160 or key:find("^match:") then
        return false, "Invalid drill reward"
    end
    if Development.claimed(career, key) then return false, "Reward already earned" end
    xp, bonus = integer(xp, 0, 250), integer(bonus, 0, 250)
    if xp + bonus <= 0 then return false, "No reward earned" end
    local candidate = copy(career)
    local state = snapshot(career)
    candidate.xp = count(candidate.xp + xp)
    local gainedXP = candidate.xp - state.accountedXP
    state.accountedXP = candidate.xp
    state.claims[key] = true
    state.points = count(state.points + gainedXP + bonus)
    state.lastReward = {kind="drill", xp=gainedXP, bonus=bonus}
    candidate.development = state
    local ok, message = commit(career, candidate)
    if not ok then return false, message end
    return true, string.format("+%d XP  ·  +%d skill points", gainedXP, gainedXP + bonus)
end

function Development.upgrade(career, key, save)
    local attributes = P.Attributes
    local nextValue, cost = attributes.advance(career.attributes, key, career.position)
    if not nextValue then return false, "Skill is capped or unavailable" end
    local state = snapshot(career)
    if state.points < cost then return false, string.format("Need %d skill points", cost) end
    local candidate = copy(career)
    candidate.attributes = attributes.restore(career.attributes, career.position)
    candidate.attributes[key] = nextValue
    state.points, state.spent = state.points - cost, count(state.spent + cost)
    candidate.development = state
    local ok, message = commit(career, candidate, save)
    if not ok then return false, message end
    for _, descriptor in ipairs(attributes.descriptors) do
        if descriptor.key == key then
            return true, string.format("%s increased to %d", descriptor.label, nextValue)
        end
    end
    return true
end

local function box(id, x, y, width, height, label, enabled)
    return {id=id,x=x,y=y,w=width,h=height,label=label,enabled=enabled ~= false}
end

function Development.layout(career, page)
    local area = P.UI.safeArea()
    local top, bottom = HEIGHT - area.top - 12, area.bottom + 10
    local width = math.min(494, WIDTH - area.left - area.right - 28)
    local center = (WIDTH + area.left - area.right) * .5
    local left, right = center - width * .5, center + width * .5
    local gap = 7
    local topRow, bottomRow = top - 114, bottom + 89
    local available = topRow - bottomRow
    local perPage = available < 245 and 4 or 5
    local descriptors = P.Attributes.descriptors
    local pages = math.max(1, math.ceil(#descriptors / perPage))
    local index = integer(page, 1, pages)
    local first = (index - 1) * perPage + 1
    local rowHeight = math.max(26, math.min(65, (available - gap * (perPage - 1)) / perPage))
    local points = Development.points(career)
    local layout = {
        x=center, w=width, top=top, bottom=bottom, left=left, right=right,
        rows={}, points=points, overall=P.Attributes.overall(career.attributes, career.position),
        page=index, pages=pages, headerY=top-17, walletY=top-63, messageY=top-102,
        back=box("back", left+32, top-17, 64, 34, "Back"),
        previous=box("previous", left+27, bottom+62, 54, 34, "‹", index>1),
        next=box("next", right-27, bottom+62, 54, 34, "›", index<pages),
        drill=box("drill", center, bottom+19, width, 38, "Play Training Drill")
    }
    local current = P.Attributes.restore(career.attributes, career.position)
    for n = 0, perPage - 1 do
        local descriptor = descriptors[first+n]
        if not descriptor then break end
        local y = topRow - rowHeight * .5 - n * (rowHeight + gap)
        local rating = current[descriptor.key]
        local cost = P.Attributes.cost(current, descriptor.key, career.position)
        local upgradeWidth = math.min(75, width * .245)
        local upgrade = box(descriptor.key,right-upgradeWidth*.5-8,y,upgradeWidth,math.min(38,rowHeight-9),
            cost and ("+1  ·  " .. cost) or "MAX", cost and points >= cost or false)
        layout.rows[#layout.rows+1] = {
            x=center,y=y,w=width,h=rowHeight,key=descriptor.key,rating=rating,
            label=descriptor.label,detail=descriptor.description,upgrade=upgrade
        }
    end
    return layout
end

local function label(value, x, y, size, tint, corner, limit)
    if not value then return end
    fontSize(size)
    if limit and textSize then
        local measured = textSize(value)
        if measured > limit then fontSize(math.max(8, size * limit / measured)) end
    end
    fill(tint)
    if corner then textMode(CORNER) end
    text(value, x, corner and y - size*.53 or y)
    if corner then textMode(CENTER) end
end

local function button(style, item, active)
    style.panel(item.x, item.y, item.w, item.h, item.enabled and active, 9)
    local isPager = item.id == "previous" or item.id == "next"
    label(item.label, item.x, item.y, isPager and 17 or 12,
        item.enabled and style.palette.white or style.palette.muted)
end

local function detailLines(value, allowed)
    if not textSize or textSize(value) <= allowed then return value end
    local first, rest
    for offset in value:gmatch("() ") do
        if textSize(value:sub(1,offset-1)) > allowed then break end
        first, rest = value:sub(1,offset-1), value:sub(offset+1)
    end
    return first or value, rest
end

function Development.draw(career, hud, message)
    local style = P.Style
    local palette = style.palette
    background(palette.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    noStroke()
    font("AvenirNext-DemiBold")

    button(style, hud.back, false)
    label("Development", hud.x, hud.headerY, 22, palette.white)
    style.panel(hud.x,hud.walletY,hud.w,48,false,13)
    local walletX = hud.left + hud.w*.21
    local ratingX = hud.right - hud.w*.21
    label(tostring(hud.points),walletX,hud.walletY+7,22,palette.glow)
    label("SKILL POINTS",walletX,hud.walletY-13,9,palette.muted)
    label(tostring(count(career.xp)),hud.x,hud.walletY+5,17,palette.white)
    label("CAREER XP",hud.x,hud.walletY-13,9,palette.muted)
    label(tostring(hud.overall),ratingX,hud.walletY+7,22,palette.amber)
    label("OVERALL",ratingX,hud.walletY-13,9,palette.muted)
    label(message,hud.x,hud.messageY,11,palette.amber,false,hud.w)

    for _, row in ipairs(hud.rows) do
        style.panel(row.x,row.y,row.w,row.h,false,11)
        local plotX = hud.left+11
        local ratingX = row.upgrade.x-row.upgrade.w*.5-23
        local descriptionWidth = math.max(58,ratingX-plotX-22)
        local detailSize = row.h < 43 and 9 or 10
        label(row.label,plotX,row.y+row.h*.20,13,palette.white,true,descriptionWidth)
        fontSize(detailSize)
        local first, second = detailLines(row.detail,descriptionWidth)
        local y = row.y-row.h*.24
        label(first,plotX,y+(second and 4.5 or 0),detailSize,palette.muted,true,descriptionWidth)
        if second then label(second,plotX,y-4.5,detailSize,palette.muted,true,descriptionWidth) end
        label(tostring(row.rating),ratingX,row.y,19,palette.glow)
        button(style,row.upgrade,true)
    end
    button(style,hud.previous,false)
    button(style,hud.next,false)
    label(string.format("%d / %d",hud.page,hud.pages),hud.x,hud.previous.y,12,palette.muted)
    if hud.drill then button(style,hud.drill,true) end
    popMatrix()
    popStyle()
end
end

-- StatUI
do
-- PolyLax 2.0 | Live statistics and final box score
PolyLax = PolyLax or {}
local P = PolyLax
local StatsUI = {}
P.StatsUI = StatsUI

local background = color(11,18,29)
local panel = color(23,36,52)
local alternate = color(29,43,59)
local active = color(48,103,179)
local white = color(242,246,249)
local soft = color(172,190,208)
local accent = color(149,210,255)

local pages = {
    {
        title="Scoring & passing",
        {"Goals","goals"}, {"Assists","assists"}, {"Points","points"}, {"Shots","shots"},
        {"Shots on goal","shotsOnGoal"}, {"Shooting %","shootingPct",true},
        {"Passes","passes"}, {"Completions","completions"}, {"Completion %","completionPct",true}
    },
    {
        title="Possession & discipline",
        {"Ground balls","groundBalls"}, {"Caused turnovers","causedTurnovers"},
        {"Turnovers","turnovers"}, {"Forced losses","committedForcedTurnovers"},
        {"Unforced losses","unforcedTurnovers"}, {"Interceptions","interceptions"},
        {"Penalties","penalties"}, {"Penalty minutes","penaltyMinutes",false,1},
        {"Legal screens","screens"}
    },
    {
        title="Goalkeeping & faceoffs",
        {"Saves","saves"}, {"Goals allowed","goalsAllowed"}, {"Shots faced","shotsFaced"},
        {"Save %","savePct",true}, {"Goalie wins","wins"}, {"Goalie losses","losses"},
        {"Faceoffs won","faceoffsWon"}, {"Faceoff attempts","faceoffAttempts"},
        {"Faceoff %","faceoffPct",true}
    }
}

local playerInfo = {
    title="Appearances",
    {"Games played","gamesPlayed"}, {"Games started","gamesStarted"},
    {"Minutes played","minutesPlayed",false,1}, {"Clear attempts","clearsAttempted"},
    {"Clears completed","clearsCompleted"}, {"Clear %","clearPct",true},
    {"Screen assists","screenAssists"}, {"Open shots from screens","screenOpenShots"},
    {"Illegal screens","illegalScreens"}
}

local function box(x,y,w,h,label,id)
    return {x=x,y=y,w=w,h=h,label=label,id=id}
end

local function clamp(value,low,high)
    return math.min(high,math.max(low,value))
end

local function begin()
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    font("AvenirNext-DemiBold")
    textAlign(CENTER)
    textMode(CENTER)
end

local function finish()
    popMatrix()
    popStyle()
end

local function fillBox(item,tint)
    fill(tint)
    rectMode(CENTER)
    if P.Style then P.Style.rounded(item.x,item.y,item.w,item.h,8,tint)
    else rect(item.x,item.y,item.w,item.h) end
end

local function label(value,x,y,size,tint,maximum)
    value = tostring(value or "")
    fill(tint or white)
    fontSize(size)
    if maximum and textSize then
        local width = textSize(value)
        if width > maximum then fontSize(math.max(8,size*maximum/width)) end
    end
    text(value,x,y)
end

local function button(item,selected)
    fillBox(item,selected and active or panel)
    label(item.label,item.x,item.y,13,white,item.w-8)
end

local function formatted(line,stat)
    if stat[3] then
        local value = line.rates[stat[2]]
        return value and string.format("%.0f%%",value*100) or "–"
    end
    local value = line.stats[stat[2]] or 0
    if stat[4] then return string.format("%.1f",value) end
    return tostring(value)
end

function StatsUI.entry(playHUD,game)
    if not game.statistics then return nil end
    local pause,camera=playHUD.pause,playHUD.camera
    local left=pause and pause.x+pause.w*.5+4 or (playHUD.leftX or 12)
    local right=camera and camera.x-camera.w*.5-4 or left+84
    local width=math.min(84,right-left)
    if width<39 then return nil end
    local title=game.statSummary and width>=66 and "BOX SCORE" or "STATS"
    return box(left+width*.5,playHUD.headerY-98,width,33,title,"statistics")
end

function StatsUI.drawEntry(playHUD,game)
    local item = StatsUI.entry(playHUD,game)
    if not item then return end
    begin()
    button(item,false)
    finish()
end

function StatsUI.open(game)
    local summary = game.source and game.sides and game or P.Statistics.matchSummary(game)
    if not summary then return nil end
    return {summary=summary,view="teams",page=1,side=1}
end

function StatsUI.layout(state)
    local safe = P.UI and P.UI.safeArea and P.UI.safeArea() or {left=0,right=0,top=0,bottom=0}
    local w = math.min(560,WIDTH-safe.left-safe.right-28)
    local cx = (WIDTH+safe.left-safe.right)*.5
    local left,right = cx-w*.5,cx+w*.5
    local top = HEIGHT-safe.top-24
    local footer = safe.bottom+33
    local summary = state.summary
    local view = state.view
    local selected = state.player and summary.players[state.player]
    local hud = {
        cx=cx,w=w,left=left,right=right,top=top,footer=footer,
        state=state,summary=summary,selected=selected,
        close=box(right-33,top,66,33,"CLOSE","close"),
        teams=box(left+w*.25,top-50,w*.5-4,36,"TEAM STATS","teams"),
        players=box(left+w*.75,top-50,w*.5-4,36,"PLAYERS","players"),
        leftPage=box(left+28,footer,56,36,"‹","previous"),
        rightPage=box(right-28,footer,56,36,"›","next"),
        rows={}
    }
    local topRows = top-177
    if view == "teams" or selected then
        hud.pages = selected and #pages+1 or #pages
        hud.page = clamp(state.page,1,hud.pages)
        hud.section = pages[hud.page] or playerInfo
        local height = clamp((topRows-footer-20)/#hud.section,21,39)
        for i, stat in ipairs(hud.section) do
            hud.rows[i] = box(cx,topRows-(i-.5)*height,w,height-2,stat[1],stat[2])
            hud.rows[i].stat = stat
        end
        if selected then
            hud.back = box(left+39,top-121,78,29,"ROSTER","roster")
        end
    else
        local side = summary.sides[state.side]
        local roster = side and side.roster or {}
        hud.home = box(left+w*.25,top-116,w*.5-4,31,summary.sides[1].name,"home")
        hud.away = box(left+w*.75,top-116,w*.5-4,31,summary.sides[2].name,"away")
        local count = clamp(math.floor((topRows-footer-12)/42),3,8)
        hud.pages = math.max(1,math.ceil(#roster/count))
        hud.page = clamp(state.page,1,hud.pages)
        local first = (hud.page-1)*count+1
        for i = first, math.min(first+count-1,#roster) do
            local line = summary.players[roster[i]]
            local item = box(cx,topRows-(i-first)*42-14,w,39,line.name,"player")
            item.player = line
            hud.rows[#hud.rows+1] = item
        end
    end
    return hud
end

local function teamHeader(hud)
    local summary = hud.summary
    local one,two = summary.sides[1],summary.sides[2]
    local y = hud.top-101
    label(one.name,hud.cx-hud.w*.29,y,14,soft,hud.w*.40)
    label(two.name,hud.cx+hud.w*.29,y,14,soft,hud.w*.40)
    label(summary.homeScore.." – "..summary.awayScore,hud.cx,y,21,white,hud.w*.19)
    local id = summary.playerOfGame
    local player = id and summary.players[id]
    if player then
        label("PLAYER OF THE GAME  ·  "..player.name,hud.cx,y-29,12,accent,hud.w-12)
    elseif not summary.final then
        label("LIVE BOX SCORE",hud.cx,y-29,11,accent,hud.w)
    end
end

local function drawStats(hud)
    local one,two = hud.summary.sides[1],hud.summary.sides[2]
    if hud.selected then
        button(hud.back,false)
        local player = hud.selected
        label(("#%s  %s  ·  %s"):format(player.number or "–",player.name or "",player.role or ""),
            hud.cx+hud.w*.14,hud.top-111,17,white,hud.w-101)
    else
        teamHeader(hud)
    end
    label(hud.section.title,hud.cx,hud.top-160,14,accent,hud.w)
    for i, item in ipairs(hud.rows) do
        fillBox(item,i%2==0 and alternate or panel)
        if hud.selected then
            label(item.label,hud.cx-hud.w*.17,item.y,13,soft,hud.w*.60)
            label(formatted(hud.selected,item.stat),hud.cx+hud.w*.34,item.y,14,white,hud.w*.17)
        else
            label(item.label,hud.cx,item.y,13,soft,hud.w*.52)
            label(formatted(one,item.stat),hud.cx-hud.w*.39,item.y,14,white,hud.w*.18)
            label(formatted(two,item.stat),hud.cx+hud.w*.39,item.y,14,white,hud.w*.18)
        end
    end
end

local function drawRoster(hud)
    button(hud.home,hud.state.side==1)
    button(hud.away,hud.state.side==2)
    label("PLAYER",hud.left+39,hud.top-151,11,soft,65)
    label("G / A / GB",hud.right-59,hud.top-151,11,soft,96)
    for i,item in ipairs(hud.rows) do
        local player = item.player
        fillBox(item,i%2==0 and alternate or panel)
        label(player.number or "–",hud.left+22,item.y,13,accent,33)
        label(player.name,hud.left+hud.w*.35,item.y,14,white,hud.w*.47)
        local stats = player.stats
        local line = player.role=="G" and (tostring(stats.saves or 0).." SV")
            or ("%d / %d / %d"):format(stats.goals or 0,stats.assists or 0,stats.groundBalls or 0)
        label(line,hud.right-57,item.y,13,soft,104)
    end
end

function StatsUI.draw(hud)
    begin()
    fillBox(box(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT),background)
    local mode = hud.summary.final and "Box score" or "Match statistics"
    label(mode,hud.left+78,hud.top,22,white,157)
    button(hud.close,false)
    button(hud.teams,hud.state.view=="teams")
    button(hud.players,hud.state.view=="players")
    if hud.state.view=="teams" or hud.selected then drawStats(hud)
    else drawRoster(hud) end
    if hud.page>1 then button(hud.leftPage,false) end
    if hud.page<hud.pages then button(hud.rightPage,false) end
    label(("%d / %d"):format(hud.page,hud.pages),hud.cx,hud.footer,13,soft,84)
    finish()
end

function StatsUI.touch(state,hud,touch)
    if touch.state~=BEGAN then return nil end
    local function hit(item)
        return item and math.abs(touch.x-item.x)<=item.w*.5 and math.abs(touch.y-item.y)<=item.h*.5
    end
    if hit(hud.close) then return "close" end
    if hit(hud.teams) then state.view,state.page,state.player="teams",1,nil
    elseif hit(hud.players) then state.view,state.page,state.player="players",1,nil
    elseif hit(hud.home) then state.side,state.page=1,1
    elseif hit(hud.away) then state.side,state.page=2,1
    elseif hit(hud.back) then state.player,state.page=nil,state.rosterPage or 1
    elseif hit(hud.leftPage) and hud.page>1 then state.page=hud.page-1
    elseif hit(hud.rightPage) and hud.page<hud.pages then state.page=hud.page+1
    else
        for _,item in ipairs(hud.rows) do
            if item.player and hit(item) then
                state.player,state.page,state.rosterPage=item.player.playerId,1,hud.page
                break
            end
        end
    end
    return "handled"
end
end

-- Awards
do
-- PolyLax 2.0 | Awards from the career season's match reports
PolyLax = PolyLax or {}
local P = PolyLax
local Awards = {}
P.Awards = Awards

local college = {{id="tewaaraton", title="Tewaaraton Award"}}
local professional = {
    {id="pro-mvp", title="Professional MVP"},
    {id="pro-offense", title="Offensive Player of the Year", roles={A=true,M=true}},
    {id="pro-defense", title="Defensive Player of the Year", roles={D=true}},
    {id="pro-goalie", title="Goalie of the Year", roles={G=true}},
    {id="pro-rookie", title="Rookie of the Year", rookie=true},
    {id="championship-mvp", title="Championship MVP", championship=true}
}

local totals = {"goals","assists","shots","shotsOnGoal","groundBalls","causedTurnovers",
    "interceptions","turnovers","penalties","penaltyMinutes","saves","goalsAllowed",
    "shotsFaced","faceoffWins","faceoffAttempts","passes","completions"}
local roleNames = {attack="A",mid="M",midfield="M",midfielder="M",defense="D",defender="D",
    faceoff="F",fogo="F",goalie="G",goalkeeper="G"}
local validRoles = {A=true,M=true,D=true,F=true,G=true}
local cache = setmetatable({}, {__mode="k"})

local function number(value)
    if type(value) == "number" and value >= 0 and value < math.huge then return value end
    return 0
end

local function clamp(value, maximum)
    return math.max(0,math.min(maximum or 1,value))
end

local function fraction(numerator, denominator, prior, weight)
    -- Shrink tiny samples toward typical efficiency.
    return (math.min(number(numerator),number(denominator)) + prior*weight)
        / (number(denominator)+weight)
end

local function field(stats,key)
    if key == "faceoffWins" then
        return number(stats.faceoffWins or stats.faceoffsWon or stats.faceoffs)
    elseif key == "causedTurnovers" then
        return number(stats.causedTurnovers or stats.forcedTurnovers)
    elseif key == "shotsFaced" then
        return math.max(number(stats.shotsFaced),number(stats.saves)+number(stats.goalsAllowed))
    end
    return number(stats[key])
end

local function roleOf(line, stats)
    local supplied = tostring(line.role or "M")
    local role = validRoles[supplied] and supplied or roleNames[supplied:lower()] or "M"
    if role == "M" and field(stats,"faceoffAttempts") >= 3 then return "F" end
    return role
end

local function quality(stats, role, games, production)
    production = production or stats
    local function output(key, norm)
        return clamp(field(production,key)/(games*norm),1.25)
    end
    local scoring = clamp((field(production,"goals")+.8*field(production,"assists"))/(games*3.15),1.25)
    local shooting = fraction(stats.goals,stats.shots,.29,5)
    local passing = fraction(stats.completions,stats.passes,.66,8)
    local ground = output("groundBalls",3)
    local caused = output("causedTurnovers",2.1)
    local value
    if role == "G" then
        local saveRate = fraction(stats.saves,field(stats,"shotsFaced"),.49,8)
        value = .42*output("saves",7.8) + .45*clamp((saveRate-.27)/.33,1.25)
            + .08*ground + .05*clamp(passing/.76,1.25)
    elseif role == "F" then
        local faceRate = fraction(field(stats,"faceoffWins"),stats.faceoffAttempts,.49,8)
        value = .40*output("faceoffWins",6.8) + .36*clamp((faceRate-.24)/.40,1.25)
            + .18*ground + .06*scoring
    elseif role == "D" then
        value = .49*caused + .26*ground + .14*output("interceptions",1.25)
            + .07*scoring + .04*clamp(passing/.76,1.25)
    elseif role == "A" then
        local efficiency = clamp(shooting/.38,1.25) * clamp(field(stats,"shots")/(games*2.8))
        value = .59*scoring + .17*efficiency + .13*output("assists",1.6)
            + .07*ground + .04*caused
    else
        local efficiency = clamp(shooting/.38,1.25) * clamp(field(stats,"shots")/(games*2.5))
        value = .47*scoring + .12*efficiency + .20*ground + .15*caused
            + .06*clamp(passing/.76,1.25)
    end
    local errors = (field(stats,"turnovers")*.023 + field(stats,"penalties")*.027
        + field(stats,"penaltyMinutes")*.012)/games
    return clamp(value-math.min(.28,errors),1.25)
end

local function eligibleTeam(career,teamId)
    if career.stage == "professional" then return true end
    local schools = P.SchoolTeams
    local team = schools and schools.get(teamId)
    return career.stage == "college" and team and team.group == "ncaa"
end

local function definitions(career)
    if career.stage == "professional" then return professional end
    if eligibleTeam(career,career.team) then return college end
end

local function reportsFor(career,data)
    local season = P.CareerSeason
    local stored = season and season.boxScores and season.boxScores(career)
        or data.matchReports or data.boxScores or {}
    local distinct = {}
    for key, report in pairs(stored) do
        if type(report) == "table" and type(report.players) == "table"
            and (report.source == "played" or report.source == "simulated")
            and (not report.stage or report.stage == career.stage)
            and (not report.season or report.season == career.season)
            and report.homeId ~= nil and report.awayId ~= nil
            and eligibleTeam(career,report.homeId) and eligibleTeam(career,report.awayId)
            and type(report.homeScore) == "number" and type(report.awayScore) == "number" then
            local id = tostring(report.id or key)
            if not distinct[id] or report.source == "played" then distinct[id] = report end
        end
    end
    local ids = {}
    for id in pairs(distinct) do ids[#ids+1] = id end
    table.sort(ids)
    local reports = {}
    for i,id in ipairs(ids) do reports[i] = distinct[id] end
    return reports
end

local function resultFor(report,teamId)
    local home = tostring(report.homeId) == tostring(teamId)
    local own,opp = report.homeScore,report.awayScore
    local opponent = report.awayId
    if not home then own,opp,opponent = opp,own,report.homeId end
    return own == opp and .5 or own > opp and 1 or 0,opponent
end

local function recordTeams(reports)
    local teams = {}
    for _,report in ipairs(reports) do
        for _,teamId in ipairs({report.homeId,report.awayId}) do
            local key = tostring(teamId)
            local team = teams[key] or {games=0, wins=0}
            local result = resultFor(report,teamId)
            team.games,team.wins = team.games+1,team.wins+result
            teams[key] = team
        end
    end
    return teams
end

local function firstProfessionalSeason(career)
    if career.stage~="professional" then return false end
    for _,season in ipairs(career.history or {}) do
        if season.stage=="professional" then return false end
    end
    return true
end

local function opportunityScale(report)
    -- Compare production against available game events. Published counters and
    -- efficiency are still raw, including in shorter player-controlled games.
    local teams = report.teams or {}
    local home = teams[tostring(report.homeId)] or teams[report.homeId]
    local away = teams[tostring(report.awayId)] or teams[report.awayId]
    if not home or not away then return 1 end
    local shots = field(home.stats or home,"shots") + field(away.stats or away,"shots")
    return math.max(.84,clamp(math.sqrt(46/(shots+10)),1.58))
end

local function candidateRows(career,reports,teams)
    local rows = {}
    local userRookie = firstProfessionalSeason(career)
    for _,report in ipairs(reports) do
        local opportunity = opportunityScale(report)
        for mapId,line in pairs(report.players) do
            if type(line) == "table" and type(line.stats) == "table" and line.teamId ~= nil
                and eligibleTeam(career,line.teamId) then
                local stats,role = line.stats,roleOf(line,line.stats)
                local participated = number(stats.gamesPlayed)>0 or number(stats.secondsPlayed)>0
                    or number(stats.minutesPlayed)>0
                local teamKey = tostring(line.teamId)
                local id = tostring(line.playerId or mapId)
                local profile = line.career==true or line.profile==true
                    or id==career.playerId or id==career.profileId
                if participated and (report.source=="played" or not profile)
                    and (teamKey == tostring(report.homeId) or teamKey == tostring(report.awayId)) then
                    local rookie = line.rookie==true or profile and userRookie
                    local row = rows[id] or {id=id,teamId=line.teamId,name=line.name or id,
                        role=role,number=line.number,career=false,rookie=false,
                        games=0,played=0,simulated=0,stats={},production={},
                        sum=0,squared=0,wins=0,opponents=0,clutch=0,clutchGames=0,
                        championship=0,championshipGames=0}
                    if role == "F" then row.role = role end
                    row.career = row.career or profile
                    row.rookie = row.rookie or rookie
                    row.games = row.games+1
                    row[report.source] = row[report.source]+1
                    local result,opponent = resultFor(report,line.teamId)
                    local other = teams[tostring(opponent)]
                    local opponentStrength = other and (other.wins+1)/(other.games+2) or .5
                    local production = {}
                    for _,key in ipairs(totals) do
                        local value = field(stats,key)
                        production[key] = value*opportunity
                        row.stats[key] = (row.stats[key] or 0)+value
                        row.production[key] = (row.production[key] or 0)+production[key]
                    end
                    local impact = quality(stats,role,1,production)
                    row.wins = row.wins+result
                    row.opponents = row.opponents+opponentStrength
                    row.sum,row.squared = row.sum+impact,row.squared+impact*impact
                    local championship = report.postseason == "championship"
                    if report.postseason or opponentStrength > .59 then
                        local weight = championship and 1.4 or 1
                        row.clutch,row.clutchGames = row.clutch+impact*weight,row.clutchGames+weight
                    end
                    if championship and result > .5 then
                        row.championship = row.championship+impact
                        row.championshipGames = row.championshipGames+1
                    end
                    rows[id] = row
                end
            end
        end
    end
    return rows
end

local function ranking(row,teams)
    local team = teams[tostring(row.teamId)]
    local mean = row.sum/row.games
    local spread = math.sqrt(math.max(0,row.squared/row.games - mean*mean))
    local consistency = clamp(mean/.72)*clamp(1-spread/.53)
    local exposure = clamp(row.games/math.max(1,team and team.games or row.games))
    local impact = quality(row.stats,row.role,row.games,row.production)
    local clutch = (row.clutch+.9*mean)/(row.clutchGames+.9)
    local sample = clamp(row.games/5)
    local score = (64*impact + 10*(row.wins/row.games) + 8*consistency + 6*exposure
        + 5*(row.opponents/row.games) + 7*clutch) * (.88 + .12*sample)
    return score,exposure
end

local labels = {A="Attack",M="Midfield",D="Defense",F="Faceoff",G="Goalie"}

local function publicRow(row,score,exposure)
    local stats = row.stats
    return {id=row.id, name=row.name, role=row.role, roleLabel=labels[row.role], teamId=row.teamId,
        number=row.number, career=row.career, rookie=row.rookie, score=math.floor(score*10+.5)/10,
        games=row.games, played=row.played, simulated=row.simulated, exposure=exposure,
        goals=stats.goals, assists=stats.assists, saves=stats.saves, goalsAllowed=stats.goalsAllowed,
        causedTurnovers=stats.causedTurnovers, groundBalls=stats.groundBalls,
        faceoffWins=stats.faceoffWins, faceoffAttempts=stats.faceoffAttempts}
end

local function buildBoard(definition,rows,teams,phase)
    local rank = {}
    for _,row in pairs(rows) do
        if (not definition.roles or definition.roles[row.role])
            and (not definition.rookie or row.rookie)
            and (not definition.championship or row.championshipGames > 0) then
            local score,exposure = ranking(row,teams)
            local enough = phase == "watchlist" or phase == "midseason"
                or definition.championship or row.games>=2 and exposure>=.45
            if enough then
                if definition.championship then score = 92*row.championship/row.championshipGames+8 end
                rank[#rank+1] = publicRow(row,score,exposure)
            end
        end
    end
    table.sort(rank,function(a,b)
        if a.score ~= b.score then return a.score > b.score end
        if a.games ~= b.games then return a.games > b.games end
        return a.id < b.id
    end)
    local finalists,leaderboard = {},{}
    for i=1,math.min(15,#rank) do
        local row = rank[i]
        row.rank = i
        leaderboard[i] = row
        if i<=3 and (phase=="finalists" or phase=="complete") then finalists[i] = row end
    end
    return {id=definition.id,title=definition.title,rows=leaderboard,finalists=finalists,
        winner=phase=="complete" and rank[1] or nil}
end

local function racePhase(data)
    if data.phase == "complete" then return "complete" end
    local week, count = number(data.week), #(data.rounds or {})
    if data.phase and data.phase ~= "regular" or count>0 and week>count*.76 then return "finalists" end
    if count>0 and week>count*.48 then return "midseason" end
    return "watchlist"
end

function Awards.preview(career)
    local catalog = definitions(career)
    if not catalog then
        local reason = career.stage=="college" and "College club has a separate competition"
            or "Season honors open in NCAA Division I and professional play"
        return {eligible=false,reason=reason,boards={}}
    end
    local data = career.seasonData
    if not data then return {eligible=true,phase="watchlist",boards={}} end
    if data.awards and data.awards.phase == "complete" then return data.awards end
    local phase = racePhase(data)
    local signature = table.concat({phase,data.season or "",data.week or "",data.games or "",
        data.replay or "",data.phase or ""},":")
    local old = cache[career]
    if old and old.data==data and old.signature==signature then return old.preview end
    local reports = reportsFor(career,data)
    local teams = recordTeams(reports)
    local rows = candidateRows(career,reports,teams)
    local output = {eligible=true,phase=phase,season=career.season,stage=career.stage,
        games=#reports,boards={}}
    for i,definition in ipairs(catalog) do
        output.boards[i] = buildBoard(definition,rows,teams,phase)
    end
    cache[career] = {data=data,signature=signature,preview=output}
    return output
end

function Awards.trophies(career)
    return type(career.trophies)=="table" and career.trophies or {}
end

function Awards.finalize(career)
    local data = career.seasonData
    if not data or data.phase ~= "complete" or not definitions(career) then return nil end
    if data.awards then return data.awards end
    local output = Awards.preview(career)
    if not output.games or output.games == 0 then return nil end
    data.awards = output
    local shelf,seen = {},{}
    for _,trophy in ipairs(Awards.trophies(career)) do
        shelf[#shelf+1] = trophy
        if type(trophy)=="table" and trophy.key then seen[trophy.key] = true end
    end
    for _,board in ipairs(output.boards) do
        local winner = board.winner
        local key = table.concat({career.stage,career.season,tostring(career.team),board.id},":")
        if winner and winner.career and not seen[key] then
            shelf[#shelf+1] = {key=key,id=board.id,title=board.title,stage=career.stage,
                season=career.season,teamId=winner.teamId,playerId=winner.id,
                player=winner.name,role=winner.role,score=winner.score}
        end
    end
    career.trophies = shelf
    return output
end
end

-- AwardUI
do
-- PolyLax 2.0 | Career awards panel
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.AwardUI = UI

local headings = {watchlist="Watchlist",midseason="Midseason rankings",finalists="Finalists",
    complete="Season results"}

local function box(id,x,y,w,h,label,selected)
    return {id=id,x=x,y=y,w=w,h=h,label=label,selected=selected}
end

local function add(panel,id,x,y,w,h,label,selected)
    local item = box(id,x,y,w,h,label,selected)
    panel.buttons[#panel.buttons+1] = item
    return item
end

function UI.layout(career,area,state)
    state = state or {}
    local awards = P.Awards.preview(career)
    local mode = state.mode == "trophies" and "trophies" or "race"
    local left,right,top,bottom = area.left,area.right,area.top,area.bottom
    local w,x = right-left,(right+left)*.5
    local panel = {left=left,right=right,x=x,w=w,bottom=bottom,top=top,mode=mode,
        buttons={},rows={},award=awards}
    add(panel,"race",left+w*.25-1.5,top-15,w*.5-3,30,"Season awards",mode=="race")
    add(panel,"trophies",right-w*.25+1.5,top-15,w*.5-3,30,"Trophy case",mode=="trophies")

    local available,firstTop
    if mode=="trophies" then
        local shelf = P.Awards.trophies(career)
        available = {}
        for i=#shelf,1,-1 do available[#available+1] = shelf[i] end
        firstTop = top-37
        if #available==0 then panel.notice = "Earn season honors to fill your trophy case" end
    elseif not awards.eligible then
        panel.notice = awards.reason
    else
        local boards = awards.boards
        local index = math.min(math.max(1,state.board or 1),math.max(1,#boards))
        local active = boards[index]
        panel.boardIndex,panel.boardCount,panel.active = index,#boards,active
        if active then
            if #boards>1 then
                add(panel,"previousBoard",left+16,top-51,32,30,"‹")
                add(panel,"nextBoard",right-16,top-51,32,30,"›")
            end
            panel.heading = headings[awards.phase]
            panel.headingY,panel.subheadY = top-48,top-70
            firstTop = top-85
            if active.winner and awards.phase=="complete" then
                panel.winner = box("winner",x,firstTop-19,w,38)
                firstTop = firstTop-45
            end
            available = awards.phase == "finalists" and active.finalists or active.rows
        end
        if not available or #available==0 then
            panel.notice = active and active.id == "championship-mvp" and "Available after the championship"
                or "Rankings begin when season results are recorded"
        end
    end
    if not available or #available==0 then return panel end
    local rowHeight = mode=="trophies" and 40 or 35
    local capacity = math.max(1,math.floor((firstTop-bottom-34)/rowHeight))
    local pages = math.ceil(#available/capacity)
    local page = math.min(math.max(1,state.page or 1),pages)
    panel.page,panel.pages = page,pages
    if page>1 then add(panel,"previousPage",left+42,bottom+15,84,29,"Previous") end
    if page<pages then add(panel,"nextPage",right-42,bottom+15,84,29,"Next") end
    local first = (page-1)*capacity+1
    for i=first,math.min(#available,first+capacity-1) do
        panel.rows[#panel.rows+1] = {item=box(nil,x,firstTop-(i-first+.5)*rowHeight,
            w,rowHeight-4),value=available[i]}
    end
    return panel
end

local function label(textValue,x,y,size,tint,maxWidth,leading)
    if not textValue or textValue=="" then return end
    fontSize(size)
    if maxWidth and textSize then
        local width=textSize(textValue)
        if width>maxWidth then fontSize(math.max(9,size*maxWidth/width)) end
    end
    fill(tint)
    if leading then textMode(CORNER) else textMode(CENTER) end
    text(textValue,x,leading and y-size*.5 or y)
    textMode(CENTER)
end

local function teamLabel(id)
    local team = P.TeamUniform and P.TeamUniform.get(id)
    return team and (team.short or team.name) or tostring(id)
end

function UI.draw(panel)
    local style,col = P.Style,P.Style.palette
    pushStyle()
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    for _,item in ipairs(panel.buttons) do
        style.panel(item.x,item.y,item.w,item.h,item.selected,9)
        label(item.label,item.x,item.y,12,item.selected and col.white or col.muted,item.w-9)
    end
    if panel.active then
        local buttonSpace = panel.boardCount>1 and 72 or 12
        label(panel.active.title,panel.x,panel.headingY,17,col.white,panel.w-buttonSpace)
        label(panel.heading,panel.x,panel.subheadY,11,col.glow,panel.w-12)
    end
    local winner = panel.active and panel.active.winner
    local banner = panel.winner
    if winner and banner then
        style.panel(banner.x,banner.y,banner.w,banner.h,true,10)
        label("Winner",panel.left+10,banner.y+8,10,col.amber,55,true)
        label(winner.name.."   "..teamLabel(winner.teamId),panel.left+10,banner.y-8,
            13,col.white,panel.w-24,true)
    end
    if panel.notice then
        label(panel.notice,panel.x,(panel.top+panel.bottom)*.5,13,col.muted,panel.w-12)
    end
    for _,row in ipairs(panel.rows) do
        local item,value = row.item,row.value
        style.panel(item.x,item.y,item.w,item.h,value.career,8)
        if panel.mode=="trophies" then
            label(value.title,panel.left+9,item.y+7,13,col.white,item.w-18,true)
            label("Season "..value.season.."  ·  "..teamLabel(value.teamId),panel.left+9,item.y-9,
                10,col.muted,item.w-18,true)
        else
            label(tostring(value.rank),panel.left+15,item.y,13,col.amber)
            label(value.name,panel.left+32,item.y+6,12,col.white,item.w-93,true)
            local detail = teamLabel(value.teamId).."  ·  "..value.roleLabel
            if value.simulated>0 then detail = detail.."  ·  Sim "..value.simulated.."/"..value.games end
            label(detail,panel.left+32,item.y-8,9,col.muted,item.w-89,true)
            label(string.format("%.1f",value.score),panel.right-26,item.y,13,col.glow,43)
        end
    end
    if panel.pages and panel.pages>1 then
        label(string.format("%d / %d",panel.page,panel.pages),panel.x,panel.bottom+15,11,col.muted)
    end
    popStyle()
end

function UI.touch(panel,state,touch)
    if touch.state~=BEGAN then return false end
    for _,item in ipairs(panel.buttons) do
        if P.UI.hit(item,touch.x,touch.y) then
            local id = item.id
            if id=="race" or id=="trophies" then
                state.mode,state.page = id,1
            elseif id=="previousBoard" or id=="nextBoard" then
                local change = id=="previousBoard" and -1 or 1
                state.board = (panel.boardIndex+change-1)%panel.boardCount+1
                state.page = 1
            else
                state.page = panel.page+(id=="previousPage" and -1 or 1)
            end
            return true
        end
    end
    return false
end
end

-- Presentation
do
-- PolyLax 2.0 | On-field presentation using the live match rigs and scene.
PolyLax = PolyLax or {}
local P = PolyLax
local Presentation = {}
P.Presentation = Presentation

local durations = {pregame=11.6,goal=2.6,postgame=7.1,championship=8.4}
local scoreInk = color(251,207,105)
local white = color(244,250,255)
local shade = color(11,18,29,222)

local function clamp(v,a,b)
    return math.max(a,math.min(b,v))
end

local function ease(t)
    t = clamp(t,0,1)
    return t*t*(3-2*t)
end

local function blend(a,b,t)
    return a+(b-a)*t
end

local function copy(v)
    return vec3(v.x,v.y,v.z)
end

local function ground(x,z)
    return vec3(x,0,z)
end

local function yawTo(direction)
    return math.deg((math.atan2 or math.atan)(-direction.x,-direction.z))
end

local function snapshot(entity, saved, known)
    if not entity or known[entity] then return end
    known[entity] = true
    saved[#saved+1] = {entity=entity,position=copy(entity.position),rotation=entity.rotation}
end

local function actor(player,index,saved,known)
    local rig = player.rig
    snapshot(rig.root,saved,known)
    snapshot(rig.pelvis,saved,known)
    snapshot(rig.stickRoot,saved,known)
    for _, joint in pairs(rig.joints) do snapshot(joint,saved,known) end
    return {index=index,team=player.team or 1,slot=player.slot or index,
        player=player,base=copy(rig.root.position),yaw=player.yaw or 0}
end

local function shot(pose,time,grip,shaft,torso,crouch,freeHand)
    pose[#pose+1] = {time=time,grip=grip,shaft=shaft,torso=torso,
        crouch=crouch or 0,roll=0,freeHand=freeHand or 0}
end

local function registerClips(animation)
    if animation.clips.presentationLift then return end
    local poses = {}
    shot(poses,.24,vec3(.46,.97,-.20),vec3(.67,.73,-.11),vec3(-6,-13,5),.035,.45)
    shot(poses,.55,vec3(.43,1.14,-.18),vec3(.19,.98,-.15),vec3(3,-8,-7),0,1)
    shot(poses,1.15,vec3(.44,1.09,-.16),vec3(.16,.98,-.1),vec3(2,8,-12),.01,1)
    animation.clips.presentationLift = {duration=1.65,poses=poses}
    poses = {}
    shot(poses,.17,vec3(.43,.54,.06),vec3(.47,.78,.30),vec3(-5,0,-5),.025,1)
    shot(poses,.57,vec3(.39,.53,.11),vec3(.53,.77,.23),vec3(-5,4,-3),.025,1)
    animation.clips.presentationGreeting = {duration=.93,poses=poses}
    poses = {}
    shot(poses,.23,vec3(.32,.43,-.38),vec3(.58,.32,-.72),vec3(-23,0,0),.25,.05)
    shot(poses,.85,vec3(.33,.32,-.40),vec3(.63,.13,-.76),vec3(-30,0,0),.38,.08)
    animation.clips.presentationDraw = {duration=1.10,poses=poses}
end

local function findActor(state, requested)
    local id = type(requested) == "table" and (requested.id or requested.index) or requested
    local name = type(requested) == "table" and requested.name or requested
    for _, item in ipairs(state.actors) do
        if item.index == id or item.player.name == name then return item end
    end
end

local function nomination(state)
    local best, value
    for _, item in ipairs(state.actors) do
        local s = item.player.stats or {}
        local rating = (s.goals or 0)*5+(s.assists or 0)*3+(s.saves or 0)*1.1
            +(s.groundBalls or 0)*.65+(s.causedTurnovers or s.forcedTurnovers or 0)*1.6
            +(s.faceoffs or 0)*.8+(s.interceptions or 0)*.8-(s.turnovers or 0)*.3
        if not best or rating > value then best,value = item,rating end
    end
    return best
end

local function pose(item, position, facing, dt, clip)
    local rig = item.player.rig
    if not item.animation then item.animation = P.AnimationController.new(rig) end
    local movement = position-rig.root.position
    rig.root.position = position
    rig.root.eulerAngles = vec3(0,facing,0)
    if clip and item.clip ~= clip then
        if P.AnimationController.play(item.animation,clip) then item.clip=clip end
    elseif not clip then
        item.clip = nil
    end
    P.AnimationController.update(item.animation,dt,{speed=math.min(7.8,movement:len()/math.max(dt,.001))})
end

local function travel(item, start, finish, progress, restYaw, dt, clip)
    local at = blend(start,finish,ease(progress))
    local yaw = (finish-start):len() > .01 and yawTo(finish-start) or restYaw
    local turn = (restYaw-yaw+180)%360-180
    yaw = yaw+turn*ease((progress-.78)/.22)
    pose(item,at,yaw,dt,clip)
end

local function setCamera(play, state, eye, target, dt)
    local amount = state.eye and 1-math.exp(-4.5*dt) or 1
    state.eye = state.eye and blend(state.eye,eye,amount) or eye
    state.target = state.target and blend(state.target,target,amount) or target
    play.camera.entity.position = state.eye
    play.camera.entity.rotation = quat.lookRotation((state.target-state.eye):normalize(),vec3(0,1,0))
end

local function benchAndLine(state, game)
    local field = game.field
    local edge = field and math.min(field.halfWidth+1,27) or 11
    for _,item in ipairs(state.actors) do
        local side = item.team == 1 and 1 or -1
        item.bench = ground(-edge+math.floor((item.slot-1)/3)*.9,side*(2+(item.slot-1)*1.05))
        item.line = ground((item.slot-(field and 5.5 or 3.5))*1.44,side*2.25)
        item.approach = item.base
        if field and item.slot == 4 then
            item.approach = ground(item.base.x,item.base.z+side*1.7)
        end
        item.player.rig.root.position = item.bench
    end
end

local function pregame(play,state,dt)
    local game, t = play.game,state.time
    local width = game.field and game.field.halfWidth or 9
    local length = game.field and game.field.halfLength or 17
    local hero = state.lead.player.rig.root
    local eye, target
    if t < 1.25 then
        state.title = game.homeTeam and game.homeTeam.name or "Practice"
        state.subtitle = game.awayTeam and ("vs "..game.awayTeam.name)
        eye,target = vec3(width*.62,length*1.70,length*1.22),vec3(0,.6,0)
    elseif t < 4.65 then
        state.title,state.subtitle = "Run-on",nil
        for _,item in ipairs(state.actors) do
            local delay = ((item.slot-1)%4)*.075
            travel(item,item.bench,item.line,(t-1.25-delay)/3.17,
                item.team == 1 and 0 or 180,dt)
        end
        target = hero.position+vec3(0,1.16,0)
        eye = target+vec3(-6.0,5.4,10.0)
    elseif t < 5.80 then
        state.title = "Starting lineup"
        local track = -3.0+5.5*ease((t-4.65)/1.15)
        eye,target = vec3(track+5.8,4.55,11.5),vec3(track,1.34,0)
        for _,item in ipairs(state.actors) do
            pose(item,item.line,item.team == 1 and 0 or 180,dt)
        end
    elseif t < 10.28 then
        state.title = "To formation"
        for _,item in ipairs(state.actors) do
            travel(item,item.line,item.approach,(t-5.80)/4.48,item.yaw,dt)
        end
        target = hero.position+vec3(0,1.2,0)
        eye = target+vec3(5.1,13,18)
    else
        state.title = game.field and "Opening faceoff" or "Ready"
        for _,item in ipairs(state.actors) do
            local isDraw = game.field and item.slot == 4
            travel(item,item.approach,item.base,(t-10.28)/.81,item.yaw,dt,
                isDraw and t>10.88 and "presentationDraw" or nil)
        end
        eye,target = vec3(4.8,3.1,7.0),vec3(0,.91,0)
    end
    setCamera(play,state,eye,target,dt)
end

local function closestPartners(state, focus, team, count)
    local pool = {}
    for _,item in ipairs(state.actors) do
        if item ~= focus and item.team == team and item.slot ~= 10 then
            pool[#pool+1] = item
        end
    end
    table.sort(pool,function(a,b)
        local ad = (a.base-focus.base):len()
        local bd = (b.base-focus.base):len()
        return ad == bd and a.index < b.index or ad < bd
    end)
    while #pool > count do pool[#pool] = nil end
    return pool
end

local function prepareGoal(state, game, options)
    state.lead = findActor(state,options.scorer or game.lastGoalScorer or game.goalScorer) or state.lead
    local team = options.team or game.lastGoalTeam or state.lead.team
    local teamInfo = team == 1 and game.homeTeam or game.awayTeam
    if team ~= state.lead.team then
        for _,item in ipairs(state.actors) do
            if item.team == team then state.lead=item break end
        end
    end
    state.title = teamInfo and teamInfo.name.." GOAL" or "Goal"
    state.subtitle = state.lead.player.name
    local lead = state.lead
    local towardCenter = lead.base.z < 0 and 1 or -1
    lead.stage = lead.base+ground(1.0,towardCenter*2.1)
    state.group = {lead}
    for i, mate in ipairs(closestPartners(state,lead,team,2)) do
        mate.stage = blend(mate.base,lead.stage+ground((i==1 and -1 or 1)*1.48,.8),.68)
        state.group[#state.group+1] = mate
    end
end

local function celebration(play,state,dt)
    local t = state.time
    for i,item in ipairs(state.group) do
        travel(item,item.base,item.stage,(t-(i-1)*.11)/1.10,i == 1 and -30 or 24,dt,
            t>.31+(i-1)*.18 and "presentationLift" or nil)
    end
    local lead = state.lead.player.rig.root.position
    local target = lead+vec3(0,1.56,0)
    local eye = target+vec3(3.7,2.2,-5.9+ease(t/2.5)*1.25)
    setCamera(play,state,eye,target,dt)
end

local function nearMidfield(state,team)
    local group = {}
    for _,item in ipairs(state.actors) do
        if item.team == team and item.slot ~= 10 then group[#group+1] = item end
    end
    table.sort(group,function(a,b)
        local aa,bb = a.base:len(),b.base:len()
        return aa == bb and a.index < b.index or aa < bb
    end)
    return group
end

local function makeTrophy(play,state)
    local stage = play.scene
    local standard = asset and asset.builtin and asset.builtin.Materials
    local function material(tint,metal)
        local m = craft.material(standard and standard.Standard or "Materials:Standard")
        m.diffuse,m.metalness,m.roughness = tint,metal,.30
        return m
    end
    local gold = material(color(238,177,51),.61)
    local light = material(color(253,215,112),.48)
    local base = material(color(32,40,52),.14)
    local cube = craft.model.cube(vec3(1,1,1))
    local round = craft.model.icosphere(1,1,true)
    local trophy = {}
    local function part(model, tint, position, scaleValue, tilt)
        local e = stage:entity()
        e.model,e.material,e.position,e.scale = model,tint,position,scaleValue
        if tilt then e.eulerAngles = vec3(0,0,tilt) end
        trophy[#trophy+1] = e
    end
    part(cube,base,vec3(.52,.20,.25),vec3(1.05,.40,.73))
    part(cube,light,vec3(.52,.43,.25),vec3(.55,.07,.46))
    part(round,gold,vec3(.52,.68,.25),vec3(.073,.22,.073))
    part(round,gold,vec3(.52,1.00,.25),vec3(.25,.25,.21))
    part(round,light,vec3(.52,1.17,.25),vec3(.277,.055,.22))
    for _,s in ipairs({-1,1}) do
        part(cube,light,vec3(.52+s*.285,1.02,.25),vec3(.15,.043,.048),s*28)
        part(cube,gold,vec3(.52+s*.345,.98,.25),vec3(.045,.14,.048),-s*14)
        part(cube,light,vec3(.52+s*.285,.91,.25),vec3(.112,.041,.044),-s*26)
    end
    state.trophy = trophy
end

local function preparePostgame(state, game, options)
    local one, two = nearMidfield(state,1),nearMidfield(state,2)
    local home,away = game.homeScore or game.goals or 0,game.awayScore or 0
    local victor = home > away and 1 or away > home and 2
    state.winner = victor
    state.mvp = findActor(state,options.playerOfGame) or nomination(state)
    local requested = options.playerOfGame
    state.mvpName = type(requested) == "table" and requested.name or
        type(requested) == "string" and requested or state.mvp.player.name
    state.pairs = {}
    state.title = "Final whistle"
    state.subtitle = home.."–"..away
    for i=1,math.min(4,#one,#two) do
        local lane = (i-2.5)*1.85
        local home,away = one[i],two[i]
        home.stage,away.stage = ground(lane+.43,.62),ground(lane-.43,-.62)
        state.pairs[#state.pairs+1] = home
        state.pairs[#state.pairs+1] = away
    end
end

local function greeting(item,t)
    local amount = ease((t-3.18)/.25)*ease((4.10-t)/.27)
    if amount <= 0 then return end
    local joints = item.player.rig.joints
    local wiggle = math.sin((t-3.18)*17)*5*amount
    local toward = quat.eulerAngles(72+wiggle,0,-5)
    local bent = quat.eulerAngles(14-wiggle,0,1)
    -- The free glove reaches forward while the other hand keeps the stick.
    if joints.leftShoulder.rotation.slerp then
        joints.leftShoulder.rotation = joints.leftShoulder.rotation:slerp(toward,amount)
        joints.leftElbow.rotation = joints.leftElbow.rotation:slerp(bent,amount)
    else
        joints.leftShoulder.eulerAngles = vec3(65*amount+wiggle,0,-5*amount)
        joints.leftElbow.eulerAngles = vec3(14*amount-wiggle,0,amount)
    end
end

local function postgame(play,state,dt)
    local t = state.time
    if t < 1.16 then
        local focus = state.mvp
        local p = focus.player.rig.root.position
        for _,item in ipairs(state.pairs) do
            local clip = state.winner == item.team and t>.16 and "presentationLift" or nil
            pose(item,item.base,item.yaw,dt,clip)
            if state.winner and item.team ~= state.winner then
                item.player.rig.joints.head.eulerAngles = vec3(9*ease(t/.7),0,-5)
            end
        end
        setCamera(play,state,p+vec3(4.3,3.9,7.9),p+vec3(0,1.45,0),dt)
    elseif t < 4.32 then
        state.title,state.subtitle = "Postgame handshake",nil
        for _,item in ipairs(state.pairs) do
            travel(item,item.base,item.stage,(t-1.16)/1.99,item.team == 1 and 0 or 180,dt,
                t>3.08 and "presentationGreeting" or nil)
            greeting(item,t)
        end
        local slide = -1.6+3.3*ease((t-2.69)/1.63)
        setCamera(play,state,vec3(slide+3.2,3.65,8.3),vec3(slide,1.19,0),dt)
    else
        local focus = state.mvp
        local podium = state.kind == "championship"
        local start = focus.stage or focus.base
        local finish = ground(podium and -.57 or 0,0)
        local position = blend(start,finish,ease((t-4.32)/.80))
        pose(focus,position,166,dt,t>5.05 and "presentationLift" or nil)
        if podium and t>4.95 and not state.trophy then makeTrophy(play,state) end
        state.title = podium and "Championship trophy" or "Player of the Game"
        state.subtitle = podium and "Player of the Game  ·  "..state.mvpName or state.mvpName
        setCamera(play,state,vec3(2.9,3.1,6.8),vec3(0,1.36,0),dt)
    end
end

local function showMarker(game, visible)
    if game.marker then game.marker.active = visible end
end

function Presentation.start(play,kind,options)
    options = options or {}
    if options.championship and kind == "postgame" then kind = "championship" end
    if not durations[kind] or not play.game or #play.game.squad == 0 then return false end
    if play.presentation then Presentation.skip(play) end
    local game, camera = play.game,play.camera
    if not camera.playEye then
        local updateCamera = game.homeScore ~= nil and P.CameraController.match or P.CameraController.practice
        updateCamera(camera,game,0,nil,options.frame)
    end
    local state = {kind=kind,time=0,duration=durations[kind],actors={},saved={},
        markerActive=game.marker and game.marker.active,near=camera.lens.nearPlane,
        far=camera.lens.farPlane}
    registerClips(P.AnimationController)
    local known = {}
    for i,player in ipairs(game.squad) do
        state.actors[i]=actor(player,i,state.saved,known)
    end
    state.lead = state.actors[game.careerPlayer or game.controlled] or state.actors[1]
    if kind == "pregame" then
        benchAndLine(state,game)
    else
        state.eye,state.target = copy(camera.playEye),copy(camera.playTarget)
        if kind == "goal" then prepareGoal(state,game,options)
        else preparePostgame(state,game,options) end
    end
    camera.lens.nearPlane,camera.lens.farPlane = .30,math.max(455,state.far or 455)
    showMarker(game,false)
    play.presentation = state
    Presentation.update(play,0)
    return true
end

function Presentation.skip(play)
    local state = play.presentation
    if not state then return false end
    for _,part in ipairs(state.saved) do
        part.entity.position,part.entity.rotation = part.position,part.rotation
    end
    for _,part in ipairs(state.trophy or {}) do
        if part.destroy then part:destroy() else part.active = false end
    end
    local camera = play.camera
    camera.lens.nearPlane,camera.lens.farPlane = state.near,state.far
    camera.playEye,camera.playTarget = state.eye,state.target
    showMarker(play.game,state.markerActive)
    play.presentation = nil
    return true
end

function Presentation.update(play,dt)
    local state = play.presentation
    if not state then return false end
    state.time = state.time + math.max(0,dt)
    if state.time >= state.duration then
        Presentation.skip(play)
        return false
    end
    if state.kind == "pregame" then pregame(play,state,dt)
    elseif state.kind == "goal" then celebration(play,state,dt)
    else postgame(play,state,dt) end
    return true
end

function Presentation.skipBox()
    local safe = P.UI.safeArea()
    return {id="SKIP",x=WIDTH-safe.right-53,y=HEIGHT-safe.top-32,w=80,h=39}
end

function Presentation.touch(play,touch)
    if not play.presentation then return false end
    if touch.state == BEGAN and P.UI.hit(Presentation.skipBox(),touch.x,touch.y) then
        Presentation.skip(play)
    end
    return true
end

local function label(textValue,x,y,size,tint,maxWidth)
    fontSize(size)
    if maxWidth and textSize then
        local width = textSize(textValue)
        if width > maxWidth then fontSize(math.max(10,size*maxWidth/width)) end
    end
    fill(tint)
    text(textValue,x,y)
end

function Presentation.draw(play)
    local state = play.presentation
    if not state then return end
    local safe = P.UI.safeArea()
    local skip = Presentation.skipBox()
    local x = (WIDTH+safe.left-safe.right)*.5
    local w = math.min(390,WIDTH-safe.left-safe.right-28)
    local y = safe.bottom+53
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    P.Style.panel(skip.x,skip.y,skip.w,skip.h,false,11)
    label("SKIP",skip.x,skip.y,13,white)
    P.Style.rounded(x,y,w,65,13,shade)
    label(state.title or "",x,y+(state.subtitle and 8 or 0),16,white,w-22)
    if state.subtitle then label(state.subtitle,x,y-12,12,scoreInk,w-22) end
    local bar = (w-24)*clamp(state.time/state.duration,0,1)
    P.Style.rounded(x-w*.5+12+bar*.5,y-27,bar,2,1,scoreInk)
    popMatrix()
    popStyle()
end
end

-- CareerUI
do
-- PolyLax Build 013 | Road to the Pros
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.CareerUI = UI

local backgroundColor = color(7,19,35)
local surface = color(19,37,58)
local raised = color(28,50,73)
local border = color(43,65,86)
local muted = color(164,183,204)
local white = color(246,249,255)
local amber = color(253,205,85)
local green = color(111,229,182)
local red = color(255,155,145)

local tabs = {
    {id="profile",label="Overview"},
    {id="schedule",label="Schedule"},
    {id="standings",label="Standings"},
    {id="stats",label="Stats"},
    {id="awards",label="Awards"},
    {id="offers",label="Offers"}
}

local function box(x,y,w,h,label,id)
    return {x=x,y=y,w=w,h=h,label=label,id=id}
end

local function teamName(id)
    local team = id and P.TeamUniform.get(id)
    return team and team.name or ""
end

local function overview(l, career, playing, training)
    local width, center, top = l.w,l.x,l.contentTop
    local column = (width-8)*.5
    local fit = math.min(1, (top-l.bottom-72)/309)
    l.overviewScale = fit
    l.name = box(center,top-22*fit,width,42*fit,career.name,"name")
    local position = P.Career.positions[career.position] or P.Career.positions[2]
    l.position = box(l.left+column*.5,top-70*fit,column,43*fit,position.label,"position")
    l.team = box(l.right-column*.5,top-70*fit,column,43*fit,P.Career.teamName(career),"team")
    l.summary = box(center,top-134*fit,width,76*fit)
    l.statsY = top-185*fit
    l.screenStats = box(center,top-225*fit,width,62*fit)
    if P.Development then
        l.development=box(center,top-286*fit,width,43*fit,"Player development","development")
    elseif training then
        l.nextSkill = box(l.left+column*.5,top-286*fit,column,43*fit,training.label,"nextSkill")
        l.train = box(l.right-column*.5,top-286*fit,column,43*fit,"Train +"..(training.gain or 1),training.key)
        l.train.enabled = training.available and not playing or false
        l.training = training
    end
end

local function listLayout(l, entries, requestedPage, height)
    local start = l.contentTop-34
    local reserve = l.bottom+103
    local capacity = math.max(1,math.floor((start-reserve)/height))
    l.pages = math.max(1,math.ceil(#entries/capacity))
    l.page = math.max(1,math.min(l.pages,math.floor(tonumber(requestedPage) or 1)))
    l.rows = {}
    local first = (l.page-1)*capacity+1
    for i=first,math.min(#entries,first+capacity-1) do
        l.rows[#l.rows+1] = {
            item=box(l.x,start-((i-first)+.5)*height,l.w,height-5),
            value=entries[i]
        }
    end

    if l.page > 1 then
        l.leftPage = box(l.left+43,l.bottom+84,86,32,"Previous","previous")
    end
    if l.page < l.pages then
        l.rightPage = box(l.right-43,l.bottom+84,86,32,"Next","next")
    end
end

local statModes={{id="career",label="Career"},{id="season",label="Season"},
    {id="matches",label="Boxes"},{id="leaders",label="Leaders"},{id="timeline",label="Timeline"}}
local leaderCache={}

local function leaders(career)
    local data=career.seasonData
    if leaderCache.career==career and leaderCache.data==data then return leaderCache.rows end
    local rows={}
    for _,kind in ipairs({{"Goals","goals"},{"Assists","assists"},{"Saves","saves"},
        {"Ground balls","groundBalls"},{"Caused turnovers","causedTurnovers"},{"Faceoffs","faceoffsWon"}}) do
        local ranked=P.CareerSeason.leaderboard(career,kind[2])
        for index=1,math.min(3,#ranked) do
            local player=ranked[index]
            rows[#rows+1]={label=kind[1].." · "..player.name,value=tostring(player.value)}
        end
    end
    leaderCache={career=career,data=career.seasonData,rows=rows}
    return rows
end
local statFields={
    {"Games played","gamesPlayed"},{"Starts","gamesStarted"},{"Minutes","minutesPlayed",1},
    {"Goals","goals"},{"Assists","assists"},{"Points","points"},{"Shots","shots"},
    {"On target","shotsOnGoal"},{"Shooting %","shootingPct",2},{"Ground balls","groundBalls"},
    {"Caused turnovers","causedTurnovers"},{"Turnovers","turnovers"},{"Forced losses","committedForcedTurnovers"},
    {"Unforced losses","unforcedTurnovers"},{"Penalties","penalties"},{"Penalty minutes","penaltyMinutes",1},
    {"Faceoff wins","faceoffs"},{"Faceoff attempts","faceoffAttempts"},{"Faceoff %","faceoffPct",2},
    {"Saves","saves"},{"Goals allowed","goalsAllowed"},{"Save %","savePct",2},
    {"Screens","screens"},{"Screen assists","screenAssists"},{"Team wins","wins"},{"Team losses","losses"}
}

local function report(career,kind)
    local entries={}
    if kind=="leaders" then return leaders(career) end
    if kind=="timeline" then
        local function seasonRow(item,active)
            local team=P.TeamUniform.get(item.team)
            local stage=P.Career.stages[item.stage] or item.stage or ""
            local detail=active and "NOW" or item.title and "TITLE" or
                string.format("%d–%d–%d",item.wins or 0,item.losses or 0,item.ties or 0)
            entries[#entries+1]={label="S"..item.season.."  "..team.short.." · "..stage,value=detail}
        end
        seasonRow(career,true)
        for i=#(career.history or {}),1,-1 do seasonRow(career.history[i],false) end
        return entries
    end
    if kind=="matches" then
        local profile=P.Statistics.profile("career-player")
        for index=#profile.order,1,-1 do
            local summary=profile.matches[profile.order[index]]
            if summary then
                local away=summary.awayId and P.TeamUniform.get(summary.awayId).short or ""
                entries[#entries+1]={label=(summary.mode or "Match").."  "..away,
                    value=summary.homeScore.."–"..summary.awayScore,box=summary}
            end
        end
        return entries
    end
    local season=career.seasonData or {}
    local stats=kind=="season" and (season.personal or {}) or career.stats
    local rates=P.Statistics.rates(stats)
    local record=kind=="season" and season or career
    for _,field in ipairs(statFields) do
        local key,format=field[2],field[3]
        local value=key=="wins" or key=="losses"
        value=value and record[key] or stats[key]
        if format==2 then value=rates[key] and string.format("%.0f%%",rates[key]*100) or "–"
        elseif format==1 then value=string.format("%.1f",value or 0)
        else value=tostring(value or 0) end
        entries[#entries+1]={label=field[1],value=value}
    end
    return entries
end

function UI.layout(career, view, playing, trainIndex, page, statMode, awardState)
    view = view or "profile"
    local safe = P.UI.safeArea()
    local width = math.min(480,WIDTH-safe.left-safe.right-28)
    local center = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-12,math.max(18,safe.bottom+10)
    local left, right = center-width*.5,center+width*.5
    local season = P.CareerSeason
    local status = season and season.status(career)
    local fixture = not playing and (season and season.fixture(career) or
        not season and P.Career.fixture(career))
    local l = {
        x=center,w=width,left=left,right=right,top=top,bottom=bottom,contentTop=top-91,
        view=view,nav={},offerButtons={},fixture=fixture,status=status,
        back=box(left+29,top-19,58,36,"Back","back")
    }
    for i, tab in ipairs(tabs) do
        local span = width/#tabs
        l.nav[i] = box(left+span*(i-.5),top-61,span-4,37,tab.label,tab.id)
    end
    if playing then
        local finished = playing.game.phase == "FINAL"
        l.play = box(center,bottom+23,width,46,
            finished and "Retry saving result" or "Resume career game","play")
    elseif fixture then
        l.play = box(center,bottom+23,width,46,"Play next game","play")
    elseif career.stage == "professional" and status and status.canAdvance then
        l.advance = box(center,bottom+23,width,46,"Start next pro season","advance")
    end

    if view == "schedule" then
        listLayout(l,season and season.schedule(career) or {},page,37)
    elseif view == "standings" then
        listLayout(l,season and season.standings(career) or {},page,34)
    elseif view=="awards" then
        local area={left=left,right=right,top=l.contentTop,bottom=l.bottom+78}
        l.awards=P.AwardUI.layout(career,area,awardState)
    elseif view=="stats" then
        l.statMode=statMode or "career"
        l.statModes={}
        for i,kind in ipairs(statModes) do
            local span=width/#statModes
            l.statModes[i]=box(left+span*(i-.5),l.contentTop-12,span-5,29,kind.label,kind.id)
        end
        listLayout(l,report(career,l.statMode),page,35)
    elseif view == "offers" then
        listLayout(l,season and season.offers(career) or {},page,49)
        if not playing then
            for _, row in ipairs(l.rows) do
                local item = row.item
                item.id = row.value.id
                l.offerButtons[#l.offerButtons+1] = item
            end
        end
    else
        overview(l,career,playing,not P.Development and season and season.training(career,trainIndex or 1))
    end
    return l
end

local function label(value,x,y,size,tint,maxWidth)
    if type(value) ~= "string" or value == "" then return end
    fill(tint)
    fontSize(size)
    if maxWidth and textSize then
        local width = textSize(value)
        if width > maxWidth then fontSize(math.max(9,size*maxWidth/width)) end
    end
    text(value,x,y)
end

local function rectAt(item,tint)
    rectMode(CENTER)
    fill(tint)
    if P.Style then P.Style.rounded(item.x,item.y,item.w,item.h,9,tint)
    else rect(item.x,item.y,item.w,item.h) end
end

local function leading(value,x,y,size,tint,maxWidth)
    textMode(CORNER)
    label(value,x,y-size*.54,size,tint,maxWidth)
    textMode(CENTER)
end

local function card(item,sub,strong,disabled)
    rectAt(item,strong and amber or surface)
    local tint = strong and backgroundColor or disabled and muted or white
    if sub then label(sub,item.x,item.y+9,9,strong and backgroundColor or muted,item.w-12) end
    label(item.label,item.x,item.y-(sub and 7 or 0),strong and 14 or 13,tint,item.w-12)
end

local function drawScreenStats(l, stats, status)
    local item, scale = l.screenStats, l.overviewScale
    local side, width = item.w*.25, item.w*.5-10
    rectAt(item,surface)
    label("SCREENS "..(stats.screens or 0),item.x-side,item.y+17*scale,10,white,width)
    label("SCREEN ASSISTS "..(stats.screenAssists or 0),item.x+side,item.y+17*scale,10,white,width)
    label("OPEN SHOTS "..(stats.screenOpenShots or 0),item.x-side,item.y+2*scale,10,white,width)
    label("ILLEGAL SCREENS "..(stats.illegalScreens or 0),item.x+side,item.y+2*scale,10,white,width)
    local points = status.screenCoachPoints or 0
    local textValue = string.format("COACH %+d SEASON",points)
    if status.lastScreenCoach then
        textValue = textValue..string.format("  ·  %+d LAST GAME",status.lastScreenCoach.points)
    end
    local tint = points > 0 and green or points < 0 and red or muted
    label(textValue,item.x,item.y-18*scale,10,tint,item.w-12)
end

local function drawOverview(career,l,editing,draft,playing)
    local name = l.name
    if editing then name = box(name.x,name.y,name.w,name.h,(draft or "").."|") end
    local appearance=P.Athlete.profile(career)
    local rating=P.Attributes.overall(career.attributes,career.position)
    card(name,string.format("ATHLETE  ·  #%d  ·  %d OVR",(appearance.NUMBER or 1)-1,rating))
    card(l.position,"POSITION",false,career.games>0 or playing)
    card(l.team,"TEAM",false,career.games>0 or playing)
    local status = l.status or {}
    local summary, stats, scale = l.summary,career.stats,l.overviewScale
    rectAt(summary,surface)
    local title = type(status.title) == "string" and status.title
        or status.title == true and "CHAMPIONSHIP WON" or P.Career.stages[career.stage]
    label(title,l.x,summary.y+25*scale,12,amber,l.w-18)
    local xp = math.max(0,career.xp-(career.spentXP or 0))
    local season=career.seasonData or career
    label(string.format("SEASON  %d–%d–%d     XP  %d",season.wins or 0,season.losses or 0,season.ties or 0,xp),
        l.x,summary.y+7*scale,13,white,l.w-18)
    local role = status.starter == true and "STARTER" or status.starter == false and "RESERVE"
    local detail = status.statusLine or ""
    if role then detail = role .. (detail == "" and "" or "  ·  "..detail) end
    label(detail,l.x,summary.y-11*scale,10,muted,l.w-18)
    local trophyCount=#P.Awards.trophies(career)
    local award = trophyCount>0 and ("Honors "..trophyCount)
        or (status.championships or 0)>0 and ("Titles "..status.championships)
    if status.lastResult and not award then award="Last game  "..status.lastResult end
    if status.contract then
        award = status.contract .. (award and "  ·  "..award or "")
    end
    label(award,l.x,summary.y-26*scale,9,muted,l.w-18)
    label(string.format("%d G   %d A   %d GB   %d CTO   %d SV   %d FO",
        stats.goals or 0,stats.assists or 0,stats.groundBalls or 0,stats.causedTurnovers or 0,
        stats.saves or 0,stats.faceoffs or 0),l.x,l.statsY,11,white,l.w-10)
    drawScreenStats(l,stats,status)
    if l.development then
        local overall=P.Attributes.overall(career.attributes,career.position)
        card(l.development,string.format("OVR %d  ·  %d SP",overall,P.Development.points(career)),true)
    elseif l.training then
        local training = l.training
        card(l.nextSkill,"SKILL  "..tostring(training.value).."   ›",false)
        local cost = training.available and ("COST  "..tostring(training.cost).." XP")
            or (training.value >= 99 and "MAX RATING" or ("NEEDS "..tostring(training.cost).." XP"))
        card(l.train,cost,l.train.enabled,not l.train.enabled)
    end
end

local function gameResultTint(result)
    local first = result and result:sub(1,1)
    return first == "W" and green or first == "L" and red or muted
end

local function drawSchedule(l)
    leading("FIXTURES",l.left+3,l.contentTop-12,11,muted)
    for _, row in ipairs(l.rows) do
        local item, fixture = row.item,row.value
        rectAt(item,fixture.current and raised or surface)
        if fixture.current then rectAt(box(l.left+2,item.y,4,item.h),amber) end
        local venue = fixture.home == false and "AT" or "VS"
        leading(venue.."  "..fixture.opponent,l.left+10,item.y+5,12,white,l.w-106)
        local detail=fixture.label
        if fixture.opponentRecord then
            local rec=fixture.opponentRecord
            detail=detail..string.format("  ·  %d–%d–%d",rec.wins,rec.losses,rec.ties)
        elseif fixture.site then detail=detail.."  ·  "..fixture.site end
        if fixture.screenCoachPoints then detail=detail..string.format("  ·  Coach %+d",fixture.screenCoachPoints) end
        leading(detail,l.left+10,item.y-8,9,muted,l.w-106)
        local result = fixture.result or (fixture.current and "NEXT" or "—")
        label(result,l.right-44,item.y,11,fixture.current and amber or gameResultTint(result),77)
    end
    if #l.rows == 0 then label("No fixtures scheduled",l.x,l.contentTop-78,14,muted) end
end

local function drawStandings(career,l)
    local w = l.w
    local sites = {l.right-w*.36,l.right-w*.28,l.right-w*.20,l.right-w*.115,l.right-w*.04}
    leading("TEAM",l.left+10,l.contentTop-12,10,muted)
    for i,value in ipairs({"W","L","T","PTS","+/-"}) do
        label(value,sites[i],l.contentTop-12,9,muted)
    end
    for _,row in ipairs(l.rows) do
        local item,team = row.item,row.value
        local selected = team.id == career.team
        rectAt(item,selected and raised or surface)
        if selected then rectAt(box(l.left+2,item.y,4,item.h),amber) end
        leading(team.name,l.left+9,item.y,11,selected and amber or white,w*.56)
        local numbers = {team.wins,team.losses,team.ties,team.points,team.differential}
        for i,value in ipairs(numbers) do label(tostring(value),sites[i],item.y,10,white) end
    end
    if #l.rows == 0 then label("Standings appear with the season",l.x,l.contentTop-78,13,muted) end
end

local function drawStats(l)
    for _,item in ipairs(l.statModes) do card(item,nil,item.id==l.statMode) end
    for _,row in ipairs(l.rows) do
        rectAt(row.item,surface)
        leading(row.value.label,l.left+11,row.item.y,12,white,l.w-90)
        label(row.value.value,l.right-43,row.item.y,12,amber,76)
    end
    if #l.rows==0 then label("Finish a game to see a box score",l.x,l.contentTop-57,12,muted,l.w-12) end
end

local function drawOffers(l,playing)
    local title = #l.rows > 0 and "SELECT AN OFFER" or "RECRUITING & CONTRACTS"
    leading(title,l.left+3,l.contentTop-12,11,muted)
    for _, row in ipairs(l.rows) do
        local item, offer = row.item,row.value
        rectAt(item,playing and surface or raised)
        leading(offer.name,l.left+11,item.y+7,13,white,l.w-45)
        leading(offer.detail,l.left+11,item.y-9,10,muted,l.w-45)
        if not playing then label("›",l.right-18,item.y,21,amber) end
    end
    if #l.rows == 0 then
        local status = l.status or {}
        label(status.contract or "No offers yet",l.x,l.contentTop-74,15,white,l.w-18)
        label(status.statusLine,l.x,l.contentTop-99,11,muted,l.w-18)
        if (status.championships or 0) > 0 then
            label("Championships  "..status.championships,l.x,l.contentTop-125,12,amber)
        end
    end
end

function UI.draw(career,l,playing,editing,draft,message)
    background(backgroundColor)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    card(l.back)
    leading("Road to the Pros",l.left+69,l.top-16,19,white,l.w-76)
    local stage = P.Career.stages[career.stage]
    local season = l.status and l.status.season or career.season
    leading((stage or "").."   ·   SEASON "..(season or 1),l.left+70,l.top-32,9,amber,l.w-76)
    for _,tab in ipairs(l.nav) do
        local active = tab.id == l.view
        rectAt(tab,active and raised or surface)
        if active then rectAt(box(tab.x,tab.y-tab.h*.5+1,tab.w,2,tab.label),amber) end
        label(tab.label,tab.x,tab.y,12,active and amber or muted,tab.w-3)
    end

    if l.view == "schedule" then drawSchedule(l)
    elseif l.view == "standings" then drawStandings(career,l)
    elseif l.view=="awards" then P.AwardUI.draw(l.awards)
    elseif l.view=="stats" then drawStats(l)
    elseif l.view == "offers" then drawOffers(l,playing)
    else drawOverview(career,l,editing,draft,playing) end

    if l.pages and l.pages > 1 then
        if l.leftPage then card(l.leftPage) end
        if l.rightPage then card(l.rightPage) end
        label(string.format("%d / %d",l.page,l.pages),l.x,l.bottom+84,11,muted)
    end
    if l.play then
        local opponent = l.fixture and teamName(l.fixture.opponent)
        local detail = opponent and ((l.fixture.home == false and "AT " or "VS ")..opponent)
        if detail and l.fixture.site then detail=detail.."  ·  "..l.fixture.site end
        card(l.play,detail,true)
    elseif l.advance then
        card(l.advance,nil,true)
    end
    if message then label(message,l.x,l.bottom+58,11,amber,l.w-10) end
    popMatrix()
    popStyle()
end
end

-- Clubs
do
-- PolyLax 3.1 | Independent Clubs profile and club storage
PolyLax = PolyLax or {}
local P = PolyLax
local Clubs = {}
P.Clubs = Clubs

local saveKey = "PolyLax.Clubs.1"
local version = 1
Clubs.nameLimit = 28
Clubs.stages = {"highSchool", "college", "professional"}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function replace(fields, candidate)
    for key in pairs(fields) do
        if candidate[key] == nil then fields[key] = nil end
    end
    for key, value in pairs(candidate) do fields[key] = value end
end

local function integer(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(low, math.min(high, math.floor(value)))
end

local function clean(value, maximum)
    if type(value) ~= "string" then return "" end
    local name = value:gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local stop = math.min(#name, maximum)
    while stop < #name and stop > 0 do
        local nextByte = name:byte(stop + 1)
        if nextByte < 128 or nextByte >= 192 then break end
        stop = stop - 1
    end
    name = name:sub(1, stop):gsub("%s+$", "")
    return utf8 and not utf8.len(name) and "" or name
end

local function relayURL(value)
    if type(value) ~= "string" then return end
    value = value:match("^%s*(.-)%s*$"):gsub("/+$", "")
    if #value > 240 then return end
    local authority, path = value:match("^https://([^/]+)(.*)$")
    if not authority or not path:match("^[A-Za-z0-9/_%.%-~]*$") or path:find("%.%.") then return end
    local host, port = authority:match("^([A-Za-z0-9%.%-]+):(%d+)$")
    host = host or authority:match("^([A-Za-z0-9%.%-]+)$")
    if not host or not host:match("^[A-Za-z0-9].*[A-Za-z0-9]$") then return end
    if port and (tonumber(port) < 1 or tonumber(port) > 65535) then return end
    return value
end

function Clubs.teamChoices(stage)
    if stage == "professional" then return P.TeamUniform.teams end
    if stage == "college" then return P.SchoolTeams.college end
    return P.SchoolTeams.highSchool
end

local function teamFor(stage, id)
    for _, team in ipairs(Clubs.teamChoices(stage)) do
        if team.id == id then return id end
    end
end

local function profileID()
    -- A stable local identifier only. A relay must issue its own access token.
    return ("plx_%08x%08x%08x%08x"):format(math.random(0,0x7fffffff),
        math.random(0,0x7fffffff), math.random(0,0x7fffffff), math.random(0,0x7fffffff))
end

local function validID(value)
    return type(value) == "string" and #value == 36 and value:match("^plx_[0-9a-f]+$") ~= nil
end

local function restorePlayer(saved)
    local player = P.Career.new()
    player.development = {schema=1,points=36,accountedXP=0,accountedLegacy=0}
    if type(saved) ~= "table" then
        player.id = profileID()
        return player
    end

    local name = clean(saved.name, P.Athlete.nameLimit*2+1)
    if name ~= "" then player.name = name end
    player.id = validID(saved.id) and saved.id or profileID()
    player.position = integer(saved.position, player.position, 1, #P.Career.positions)
    player.attributes = P.Attributes.restore(saved.attributes, player.position)
    if P.Career.stages[saved.stage] then player.stage = saved.stage end
    player.team = teamFor(player.stage, saved.team) or Clubs.teamChoices(player.stage)[1].id
    player.season = integer(saved.season, 1, 1, 10000)
    for _, key in ipairs({"games","wins","losses","ties","xp","championships"}) do
        player[key] = integer(saved[key], 0, 0, 1000000)
    end
    player.spentXP = integer(saved.spentXP, 0, 0, player.xp)
    for _, key in ipairs({"appearance","development","entries","history","trophies","contract"}) do
        if type(saved[key]) == "table" then player[key] = copy(saved[key]) end
    end
    if type(saved.stats) == "table" then
        for key in pairs(player.stats) do
            local value = tonumber(saved.stats[key])
            if value and value == value and math.abs(value) < math.huge then player.stats[key] = value end
        end
    end
    return player
end

function Clubs.save(data)
    if not saveLocalData or not json or not json.encode then return false end
    local stored = {version=version, player=data.player, club=data.club, settings=data.settings,
        online=data.online}
    local encoded, raw = pcall(json.encode, stored)
    if not encoded or type(raw) ~= "string" then return false end
    local written, result = pcall(saveLocalData, saveKey, raw)
    return written and result ~= false
end

function Clubs.load()
    local saved
    if readLocalData and json and json.decode then
        local read, raw = pcall(readLocalData, saveKey)
        if read and type(raw) == "string" then
            local decoded, result = pcall(json.decode, raw)
            if decoded and type(result) == "table" and result.version == version then saved = result end
        end
    end

    local data = {version=version, player=restorePlayer(saved and saved.player), settings={}}
    if saved and type(saved.online) == "table" then
        local online = saved.online
        data.online = {games=integer(online.games, 0, 0, 1000000),
            wins=integer(online.wins, 0, 0, 1000000), losses=integer(online.losses, 0, 0, 1000000),
            ties=integer(online.ties, 0, 0, 1000000),
            history=type(online.history) == "table" and copy(online.history) or {}}
    end
    if saved and type(saved.settings) == "table" then
        data.settings.relayURL = relayURL(saved.settings.relayURL)
    end
    local stored = saved and saved.club
    if type(stored) == "table" then
        local name = clean(stored.name, Clubs.nameLimit)
        local stage = P.Career.stages[stored.stage] and stored.stage
        local team = stage and teamFor(stage, stored.team)
        if name ~= "" and team then
            local season = integer(stored.season, 1, 1, 10000)
            data.club = {name=name, stage=stage, team=team, season=season}
            data.player.stage, data.player.team, data.player.season = stage, team, season
        end
    end
    if not saved or type(saved.player) ~= "table" or not validID(saved.player.id) then Clubs.save(data) end
    return data
end

function Clubs.setRelay(data, value)
    local url = relayURL(value)
    if not url and value ~= nil and (type(value) ~= "string" or value:find("%S")) then
        return false, "Enter an HTTPS relay address without a query or password"
    end
    local candidate = copy(data)
    candidate.settings.relayURL = url
    if not Clubs.save(candidate) then return false, "Could not save the relay address" end
    data.settings.relayURL = url
    return true
end

function Clubs.savePlayer(data, player)
    if player.id ~= data.player.id then return false end
    local club = data.club
    if club and (player.team ~= club.team or player.stage ~= club.stage or player.season ~= club.season) then
        return false
    end
    local candidate = {player=player, club=club, settings=data.settings, online=data.online}
    if not Clubs.save(candidate) then return false end
    replace(data.player, player)
    return true
end

local function placePlayer(data, club, stage, team)
    local player = copy(data.player)
    local season = club and club.season or player.season
    player.stage, player.team, player.season = stage, team, season
    local candidate = {player=player, club=club, settings=data.settings, online=data.online}
    if not Clubs.save(candidate) then return false, "Could not save the club" end
    data.club = club
    replace(data.player, player)
    return true
end

function Clubs.create(data, name, stage, team)
    name = clean(name, Clubs.nameLimit)
    if name == "" then return false, "Enter a club name" end
    if data.club then return false, "You already have a local club" end
    stage = stage or data.player.stage
    if not P.Career.stages[stage] then return false, "Choose a competition" end
    team = team or (stage == data.player.stage and data.player.team) or Clubs.teamChoices(stage)[1].id
    if not teamFor(stage, team) then return false, "Choose a team in this competition" end
    local club = {name=name, stage=stage, team=team, season=1}
    return placePlayer(data, club, stage, team)
end

function Clubs.setTeam(data, stage, team)
    if not P.Career.stages[stage] or not teamFor(stage, team) then
        return false, "Choose a team in this competition"
    end
    local club
    if data.club then
        local current = data.club
        local same = current.stage == stage and current.team == team
        club = {name=current.name, stage=stage, team=team, season=same and current.season or 1}
    end
    return placePlayer(data, club, stage, team)
end

function Clubs.activeClub(data)
    return data.joined or data.club
end

local function assignedClub(lobby)
    if type(lobby) ~= "table" or not P.Career.stages[lobby.stage] or not teamFor(lobby.stage, lobby.team) then return end
    if type(lobby.code) ~= "string" or not lobby.code:match("^[A-Z0-9]+$") or #lobby.code ~= 8 then return end
    local name = clean(lobby.name, Clubs.nameLimit)
    if name ~= "" then
        return {code=lobby.code, name=name, stage=lobby.stage, team=lobby.team, season=1}
    end
end

function Clubs.joinedTeam(data, lobby)
    if lobby == nil then data.joined = nil return true end
    local remote = assignedClub(lobby)
    if not remote then return false, "The relay returned an invalid team" end
    local localClub = data.club
    if localClub and localClub.stage == remote.stage and localClub.team == remote.team then
        remote.season = localClub.season
    end
    -- Room membership is session-only. Keep the saved club and athlete intact.
    data.joined = remote
    return true
end

function Clubs.schedule(data)
    local club = Clubs.activeClub(data)
    if not club then return {} end
    -- Preview the league's real fixture ordering with a Club-only season seed.
    return P.CareerSeason.schedule({stage=club.stage, team=club.team, season=club.season, entries={}})
end

local function statValue(key, value)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
    if key == "screenCoachPoints" then return math.max(-1000, math.min(1000, value)) end
    value = math.max(0, math.min(1000, value))
    if key == "minutesPlayed" or key == "penaltyMinutes" then return value end
    if key == "gamesPlayed" or key == "gamesStarted" then return math.min(1, math.floor(value)) end
    return math.floor(value)
end

local function onlineRecord(result, remote, matchId, stats, earned)
    local opponent = result.opponent
    if not teamFor(remote.stage, opponent) then
        local school = P.SchoolTeams.get(opponent)
        if not school or P.League.profile(remote.stage, opponent).id ~= P.League.profile(remote.stage, remote.team).id then
            opponent = nil
        end
    end
    return {id=matchId, label="Clubs match", code=remote.code, name=remote.name, stage=remote.stage,
        team=remote.team, opponentId=opponent, opponent=opponent and P.TeamUniform.get(opponent).name or "Opponent", home=true,
        homeScore=result.homeScore, awayScore=result.awayScore, result=string.format("%d–%d",result.homeScore,result.awayScore),
        xp=earned, stats=stats}
end

function Clubs.results(data)
    local played = data.online and data.online.history or {}
    local results = {}
    for index=#played,1,-1 do results[#results+1] = played[index] end
    return results
end

-- Invoke only with the authenticated final returned by the relay. A repeated
-- result is acknowledged without changing the player, wallet, or record.
function Clubs.recordOnline(data, lobby, result, memberId)
    local remote = assignedClub(lobby)
    if not remote or lobby.phase ~= "final" or type(result) ~= "table" then
        return false, "No completed Clubs match"
    end
    local id = result.matchId
    if id ~= lobby.matchId or type(id) ~= "string" or #id > 72 or not id:match("^[A-Za-z0-9_%-]+$") then
        return false, "The result does not match this room"
    end
    local player = data.player
    local member
    if type(memberId) ~= "string" or type(lobby.players) ~= "table" then return false, "Missing Clubs player" end
    for _, row in ipairs(lobby.players) do
        if type(row) == "table" and row.id == memberId and type(row.profile) == "table"
            and row.profile.id == player.id then member = row break end
    end
    if not member then return false, "The result is for another player" end
    local key = "club:"..id
    if player.entries[key] then return true, nil, false end
    local score, opposing = result.homeScore, result.awayScore
    if type(score) ~= "number" or type(opposing) ~= "number" or score % 1 ~= 0 or opposing % 1 ~= 0
        or score < 0 or opposing < 0 or score > 999 or opposing > 999 then
        return false, "The relay returned an invalid score"
    end
    local actual = type(result.stats) == "table" and result.stats[memberId]
    if type(actual) ~= "table" then return false, "Your athlete's statistics are missing" end

    local candidate = copy(data)
    local updated = candidate.player
    local personal = {screenCoachPoints=statValue("screenCoachPoints", actual.screenCoachPoints)}
    for _, stat in ipairs(P.Career.statKeys) do personal[stat] = statValue(stat, actual[stat]) end
    for stat, value in pairs(personal) do updated.stats[stat] = (updated.stats[stat] or 0) + value end
    local bucket = score > opposing and "wins" or score < opposing and "losses" or "ties"
    updated.games, updated[bucket] = updated.games + 1, updated[bucket] + 1
    local earned = 20 + (bucket == "wins" and 10 or 0) + personal.goals * 6 + personal.assists * 5
        + personal.saves * 3 + personal.faceoffs * 4 + personal.groundBalls * 2
        + personal.causedTurnovers * 4 + personal.interceptions * 3
    updated.xp = updated.xp + earned
    P.Development.onMatch(updated, {id=key}, personal, {phase="FINAL",homeScore=score,awayScore=opposing})
    local record = onlineRecord(result, remote, id, personal, earned)
    updated.entries[key] = {home=score, away=opposing, opponent=record.opponentId, stats=personal, xp=earned}
    local online = candidate.online or {games=0,wins=0,losses=0,ties=0,history={}}
    online.games, online[bucket] = online.games + 1, online[bucket] + 1
    online.history[#online.history+1] = record
    candidate.online = online
    if not Clubs.save(candidate) then return false, "Could not save the match result" end
    replace(player, updated)
    data.online = online
    return true, nil, true
end

function Clubs.roster(data)
    if not data.club then return {} end
    local player = data.player
    local position = P.Career.positions[player.position]
    local jersey = P.Athlete.profile(player).NUMBER - 1
    local roster, used = {}, {[jersey]=true}
    local labels = {A="Attack", M="Midfield", D="Defense", G="Goalie"}
    for slot, member in ipairs(P.League.roster(data.club.team)) do
        if slot == position.slot then
            roster[slot] = {slot=slot, id=player.id, name=P.Athlete.name(player),
                position=position.label, number=jersey, kind="local"}
        else
            local number = member.number
            while used[number] do number = (number + 1) % 100 end
            used[number] = true
            roster[slot] = {slot=slot, id=member.playerId, name=member.name, number=number,
                position=member.specialty == "FOGO" and "Faceoff" or labels[member.role], kind="ai"}
        end
    end
    return roster
end
end

-- ClubsUI
do
-- Club and connection screens. Gameplay HUD and single-player career have their own layouts.
PolyLax = PolyLax or {}
local P = PolyLax
local ClubsUI = {}
P.ClubsUI = ClubsUI

local heading = {
    CLUBS="PolyLax Clubs", CREATE="Create Club", JOIN="Join Club",
    ROSTER="Club Roster", SCHEDULE="Schedule", LOBBY="Club Lobby", SETTINGS="Settings"
}

local function item(id, title, detail, enabled, primary)
    return {id=id,label=title,detail=detail,enabled=enabled~=false,primary=primary}
end

local function place(layout, box, x, y, width, height)
    box.x,box.y,box.w,box.h=x,y,width,height
    layout.rows[#layout.rows+1]=box
    if box.id then
        layout.buttons[#layout.buttons+1]=box
        layout.byId[box.id]=box
    end
    return box
end

local function stack(layout, rows, ceiling)
    if #rows==0 then return end
    local gap = 7
    local height = math.min(ceiling or 58,(layout.cursor-layout.floor-gap*(#rows-1))/#rows)
    for _, row in ipairs(rows) do
        place(layout,row,layout.x,layout.cursor-height*.5,layout.w,height)
        layout.cursor=layout.cursor-height-gap
    end
end

local function field(options, id, value, placeholder)
    if options.editing==id then
        return (options.draft or "").."▏"
    end
    return (value and value~="" and value) or placeholder
end

local function relayURL(data, options)
    local value=options.relay or data.settings and data.settings.relayURL
    return type(value)=="string" and value~="" and value or nil
end

local function teamName(teamID)
    if teamID==nil then return end
    local team=P.TeamUniform.get(teamID)
    return team and team.name
end

local function clubStamp(layout, title, description, stats)
    local height = stats and 78 or 64
    layout.stamp={title=title,detail=description,stats=stats,
        x=layout.x,y=layout.cursor-height*.5,w=layout.w,h=height}
    layout.cursor=layout.cursor-height-12
end

local function scheduleRow(game)
    local opponent=type(game.opponent)=="table" and game.opponent.name or game.opponent
    local venue=game.home and "Home" or "Away"
    local detail=table.concat({tostring(game.label or "Fixture"),venue,tostring(game.result or game.site or "Scheduled")},"  ·  ")
    return item(nil,tostring(opponent or "Opponent"),detail,nil,game.current==true)
end

local function rosterRow(member)
    local pos=member.position or member.role
    if type(pos)=="number" then
        local definition=P.Career.positions[pos]
        pos=definition and definition.label
    end
    local number=member.number or member.jerseyNumber
    local suffix=number and ("  ·  #"..tostring(number)) or ""
    local owner=member.host and "  ·  HOST" or ""
    local name=tostring(member.name or "Player")..(member.kind=="local" and member.online and " (You)" or "")
    local row=item(nil,name,tostring(pos or "Unassigned")..suffix..owner)
    local source=member.kind
    row.badge=(member.ai or source=="ai") and "AI" or source=="local" and not member.online and "YOU"
        or member.connected==false and "OFFLINE" or member.ready and "READY" or "NOT READY"
    row.badgeActive=member.ready==true
    return row
end

local function pageList(layout, items, convert, fallback, options)
    if #items==0 then
        stack(layout,{item(nil,fallback)},52)
        return
    end
    local count = math.min(10,math.max(1,math.floor((layout.cursor-layout.floor-48)/54)))
    local pages = math.ceil(#items/count)
    local current = math.max(1,math.min(pages,math.floor(tonumber(options.page) or 1)))
    if pages>1 then
        layout.pages,layout.page=pages,current
        local y = layout.floor+19
        place(layout,item("PREV_PAGE","Previous",nil,current>1),layout.x-layout.w*.34,y,layout.w*.31,38)
        place(layout,item("NEXT_PAGE","Next",nil,current<pages),layout.x+layout.w*.34,y,layout.w*.31,38)
        layout.pager={x=layout.x,y=y,label=string.format("%d / %d",current,pages)}
        layout.floor=layout.floor+46
    end
    local rows={}
    for i=(current-1)*count+1,math.min(#items,current*count) do
        rows[#rows+1]=convert(items[i])
    end
    stack(layout,rows,49)
end

local screens = {}

function screens.CLUBS(layout, data, options)
    local club, player = options.lobby or data.club, data.player or {}
    local title = club and club.name or "Your club"
    local identity = P.Athlete.name(player)
    local description = club and (teamName(club.team) or "Local club").."  ·  "..identity
        or identity
    local jersey = P.Athlete.profile(player).NUMBER-1
    local stats = string.format("#%d   ·   %d OVR   ·   %d skill points",jersey,
        P.Attributes.overall(player.attributes,player.position),P.Development.points(player))
    clubStamp(layout,title,description,stats)
    local rows = {
        item("CREATE","Create Club",nil,true,true),
        item("JOIN","Join Club"), item("MY_PLAYER","My Player"),
        item("ROSTER","Club Roster"), item("SCHEDULE","Schedule"),
        item("DEVELOPMENT","Player Development")
    }
    if club or options.lobby then rows[#rows+1]=item("LOBBY","Club Lobby") end
    stack(layout,rows,57)
end

function screens.CREATE(layout, data, options)
    local club = data.club or {}
    local team = options.teamName or teamName(club.team) or "Choose a team"
    local stage = options.stageName or P.Career.stages[club.stage or "highSchool"]
    stack(layout,{
        item("EDIT_NAME","Club name",field(options,"EDIT_NAME",options.name or club.name,"Enter a club name")),
        item("NEXT_STAGE","Competition",stage),
        item("NEXT_TEAM","Team",team),
        item("SAVE_CLUB","Save Club",nil,options.canCreate~=false,true)
    },68)
end

function screens.JOIN(layout, data, options)
    local relay=relayURL(data,options)
    stack(layout,{
        item("EDIT_CODE","Invitation code",field(options,"EDIT_CODE",options.code,"Enter the host's code")),
        item("EDIT_RELAY","Relay server",field(options,"EDIT_RELAY",relay,"Enter the online server address")),
        item("CONNECT","Join Club",nil,options.canConnect==true,true)
    },68)
    if not relay and not options.message then
        layout.message="Set the relay server address to join a room."
    end
end

function screens.SETTINGS(layout, data, options)
    local relay=relayURL(data,options)
    stack(layout,{
        item("CREATOR","Player Creator","Customize the Quick Play athlete"),
        item("EDIT_RELAY","Clubs relay server",field(options,"EDIT_RELAY",relay,"Set the online server address"))
    },68)
end

function screens.ROSTER(layout, data, options)
    local roster=options.roster or P.Clubs.roster(data) or {}
    pageList(layout,roster,rosterRow,"Create or join a club to view its roster.",options)
end

function screens.SCHEDULE(layout, data, options)
    local schedule=options.schedule or P.Clubs.schedule(data) or {}
    pageList(layout,schedule,scheduleRow,"Create a club to open a season schedule.",options)
end

function screens.LOBBY(layout, data, options)
    local lobby=options.lobby
    if not lobby then
        clubStamp(layout,data.club and data.club.name or "Club Lobby","This club is saved on this device")
        stack(layout,{item("HOST_ONLINE","Host Online","Open an invitation room on the relay",
            options.hostEnabled==true,true)},62)
        if not options.message and not relayURL(data,options) then
            layout.message="Set a relay server address in Settings to host online."
        end
        return
    end
    local code = lobby.code
    local description = code and code~="" and ("Invitation code   "..code) or "Connecting to the relay"
    if lobby.phase=="final" and lobby.result then
        description=string.format("Final score   %d–%d",lobby.result.homeScore,lobby.result.awayScore)
    end
    clubStamp(layout,lobby.name or data.club and data.club.name or "Club Lobby",description)
    local y = layout.floor+19
    if lobby.phase=="match" then
        place(layout,item("RESUME_MATCH","Return to Match",nil,options.canResume==true,true),layout.x,y,layout.w,38)
    elseif lobby.phase=="final" then
        place(layout,item("LEAVE","Leave Room"),layout.x,y,layout.w,38)
    else
        local width = (layout.w-12)/3
        place(layout,item("READY",options.ready and "Unready" or "Ready",nil,options.canReady==true),
            layout.x-width-6,y,width,38)
        place(layout,item("START","Start Game",nil,options.canStart==true,true),layout.x,y,width,38)
        place(layout,item("LEAVE","Leave"),layout.x+width+6,y,width,38)
    end
    layout.floor=layout.floor+45
    pageList(layout,options.roster or lobby.members or {},rosterRow,"Waiting for players",options)
end

function ClubsUI.layout(view, data, options)
    view=heading[view] and view or "CLUBS"
    options,data=options or {},data or {}
    local safe=P.UI.safeArea()
    local width=math.min(452,WIDTH-safe.left-safe.right-30)
    local x=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-12,safe.bottom+12
    local layout={view=view,title=heading[view],top=top,bottom=bottom,x=x,w=width,
        cursor=top-58,floor=bottom+26,rows={},buttons={},byId={},message=options.message}
    local back=place(layout,item("BACK","Back"),x-width*.5+30,top-21,60,36)
    back.compact=true
    screens[view](layout,data,options)
    return layout
end

local function textAt(value, x, y, size, colorValue, limit, left)
    if not value then return end
    fontSize(size)
    if textSize and limit and limit>0 then
        local width=textSize(value)
        if width>limit then fontSize(math.max(9,size*limit/width)) end
    end
    fill(colorValue)
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.51 or y)
    if left then textMode(CENTER) end
end

local function drawRow(style, row)
    local p = style.palette
    style.panel(row.x,row.y,row.w,row.h,row.primary and row.enabled,11)
    local ink = row.enabled and p.white or p.muted
    if row.compact or row.id=="PREV_PAGE" or row.id=="NEXT_PAGE"
        or row.id=="READY" or row.id=="START" or row.id=="LEAVE" then
        textAt(row.label,row.x,row.y,13,ink,row.w-10)
        return
    end
    local left = row.x-row.w*.5+14
    local hasArrow = row.id and row.enabled
    local room = row.w-29-(row.badge and 76 or hasArrow and 20 or 0)
    textAt(row.label,left,row.y+(row.detail and 9 or 0),row.primary and 18 or 16,ink,room,true)
    textAt(row.detail,left,row.y-11,11,row.enabled and p.muted or p.rim,room,true)
    if row.badge then
        local x=row.x+row.w*.5-43
        style.rounded(x,row.y,64,22,8,p.inset)
        textAt(row.badge,x,row.y,10,row.badgeActive and p.glow or p.muted,59)
    elseif hasArrow then
        local x=row.x+row.w*.5-17
        stroke(p.glow)
        strokeWidth(2)
        line(x-4,row.y+4,x,row.y)
        line(x,row.y,x-4,row.y-4)
        noStroke()
    end
end

function ClubsUI.draw(layout)
    local style=P.Style
    local p=style.palette
    background(p.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CENTER)
    noStroke()
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    textAt(layout.title,layout.x-layout.w*.5+76,layout.top-21,23,p.white,layout.w-76,true)
    if layout.stamp then
        local stamp=layout.stamp
        style.panel(stamp.x,stamp.y,stamp.w,stamp.h,false,13)
        local x=stamp.x-stamp.w*.5+29
        style.rounded(x,stamp.y,37,37,10,p.inset)
        style.clubsIcon(x,stamp.y,37,p.glow)
        textAt(stamp.title,x+29,stamp.y+(stamp.stats and 20 or 9),19,p.white,stamp.w-75,true)
        textAt(stamp.detail,x+29,stamp.y+(stamp.stats and 0 or -12),11,p.muted,stamp.w-75,true)
        textAt(stamp.stats,x+29,stamp.y-19,11,p.glow,stamp.w-75,true)
    end
    for _, row in ipairs(layout.rows) do drawRow(style,row) end
    if layout.pager then
        textAt(layout.pager.label,layout.pager.x,layout.pager.y,12,p.muted)
    end
    textAt(layout.message,layout.x,layout.bottom+9,11,p.amber,layout.w)
    popMatrix()
    popStyle()
end

function ClubsUI.touch(layout, touch)
    if touch.state~=BEGAN then return end
    for _, box in ipairs(layout.buttons) do
        if box.enabled and P.UI.hit(box,touch.x,touch.y) then return box.id end
    end
end
end

-- ClubsMatch
do
-- Host simulation and guest rendering for the two-player Clubs prototype.
PolyLax = PolyLax or {}
local P = PolyLax
local ClubsMatch = {}
P.ClubsMatch = ClubsMatch

local positions = {
    attack=1, midfield=2, defense=3, faceoff=4, goalie=5, lsm=6, ssdm=7,
    ["long-stick mid"]=6, ["short-stick def mid"]=7
}
local ruleProfiles = {highSchool="highSchool", ncaa="ncaa", club="collegeClub", professional="professional"}
local permitted = {
    faceoff=true, clamp=true, counter=true, pass=true, shoot=true, scoop=true,
    poke=true, slap=true, body=true, dodge=true, setpick=true, releasepick=true
}
local phases = {FACEOFF=true, LIVE=true, FOUL=true, INTERMISSION=true, GOAL=true, FINAL=true}

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<math.huge
end

local function bounded(n, lower, upper, fallback)
    if not finite(n) then return fallback or 0 end
    return math.max(lower,math.min(n,upper))
end

local function movement(x, z)
    x, z = bounded(x,-1,1), bounded(z,-1,1)
    local scale = math.max(1,math.sqrt(x*x+z*z))
    return x/scale,z/scale
end

local function cleanPlayer(profile, name, team)
    profile = type(profile)=="table" and profile or {}
    local position = tonumber(profile.position) or positions[tostring(profile.position):lower()] or 2
    position = math.floor(bounded(position,1,#P.Career.positions,2))
    local raw = type(profile.appearance)=="table" and profile.appearance or {}
    local appearance = P.Athlete.profile({team=team,appearance=raw})
    if finite(profile.number) then appearance.NUMBER = 1+math.floor(bounded(profile.number,0,99)) end
    local nickname = type(profile.name)=="string" and profile.name:sub(1,38) or name
    return {
        name=nickname, role=P.Career.positions[position].role, appearance=appearance,
        attributes=P.Attributes.restore(profile.attributes,position), x=0, z=0
    }
end

local function vector(aim, minY, maxY, xLimit, zLimit)
    if type(aim)~="table" and type(aim)~="userdata" then return end
    if not finite(aim.x) or not finite(aim.y) or not finite(aim.z) then return end
    return {
        x=bounded(aim.x,-xLimit,xLimit), y=bounded(aim.y,minY,maxY),
        z=bounded(aim.z,-zLimit,zLimit)
    }
end

local function cleanAction(game, action, moveX, moveZ, aim)
    if not permitted[action] then return end
    local x,z = movement(moveX,moveZ)
    local input = {action=action,x=x,z=z}
    if action=="shoot" then
        input.aim = vector(aim,.02,5,3.6,game.field.halfLength)
    elseif action=="pass" and type(aim)=="table" then
        if finite(aim.to) then input.to = math.floor(bounded(aim.to,1,20)) end
        if not input.to then
            input.point = vector(aim.point,.09,3,game.field.halfWidth,game.field.halfLength)
        end
    end
    return input
end

local function applyCommand(game, slot, input)
    local aim
    if input.action=="shoot" and input.aim then
        local v = input.aim
        aim = vec3(v.x,v.y,v.z)
    elseif input.action=="pass" then
        if input.to then
            aim = P.Passing.forTarget(game,input.to)
        elseif input.point then
            local point, player = input.point, game.squad[slot]
            local x,z = point.x-player.x,point.z-player.z
            local range = math.sqrt(x*x + z*z)
            local scale = math.min(1,26/math.max(range,.001))
            aim = {point=vec3(player.x+x*scale,point.y,player.z+z*scale)}
        end
    end
    return P.FullMatch.command(game,input.action,input.x,input.z,aim,slot)
end

function ClubsMatch.command(play, action, moveX, moveZ, aim)
    local game = play.game
    if game.phase=="FACEOFF" and play.localSlot~=game.faceoff.home.id then return false end
    if game.phase~="FACEOFF" and game.phase~="LIVE" then return false end
    local input = cleanAction(game,action,moveX,moveZ,aim)
    if not input then return false end
    if play.isHost then return applyCommand(game,play.localSlot,input) end
    if #play.actions >= 8 then return false end
    play.actions[#play.actions+1] = input
    return true
end

function ClubsMatch.takeActions(play)
    local actions = play.actions
    play.actions = {}
    return actions
end

function ClubsMatch.new(scene, lobby, localId)
    if type(lobby)~="table" or type(lobby.players)~="table" or not lobby.matchId then return end
    local home = P.TeamUniform.get(lobby.team)
    local opponent = P.TeamUniform.opponent(home.home,lobby.opponent).teamId
    local humans, members = {}, {}
    local localSlot, humanCount = nil, 0
    for _, member in ipairs(lobby.players) do
        local slot = type(member)=="table" and member.slot
        if finite(slot) and slot%1==0 and slot>=1 and slot<=10 and not humans[slot]
            and type(member.id)=="string" and not members[member.id] then
            humans[slot] = cleanPlayer(member.profile,"Club Player",home.id)
            members[member.id] = {slot=slot,id=member.id,lastSequence=0}
            humanCount = humanCount+1
            if member.id==localId then localSlot = slot end
        end
    end
    if not localSlot or humanCount~=2 then return end
    local rules = {name="Clubs Scrimmage",profile=ruleProfiles[home.fieldType] or "arcade",
        periods=2,periodLength=60,humans=humans,playerId=localSlot,
        statistics={id=lobby.matchId,profileId=tostring(localId),profilePlayer=localSlot,mode="CLUBS"}}
    local game = P.FullMatch.new(scene,humans[localSlot].appearance,home.id,opponent,rules)
    game.clubsPlayer = localSlot
    local play = {scene=scene,game=game,localSlot=localSlot,isHost=localId==lobby.hostId,
        matchId=lobby.matchId,members=members,actions={},elapsed=0,sequence=0}
    play.controller = {
        command=function(_, ...) return ClubsMatch.command(play,...) end,
        canAim=P.FullMatch.canAim, aimContext=P.FullMatch.aimContext,
        passPreview=P.FullMatch.passPreview
    }
    return play
end

local function updateControl(target, input)
    target.x,target.z = movement(input.x,input.z)
    target.sprint = input.sprint==true
end

function ClubsMatch.hostStep(play, dt, localInput, events)
    if not play.isHost then return end
    dt = bounded(dt,0,.1)
    play.elapsed = play.elapsed+dt
    local game = play.game
    updateControl(game.humans[play.localSlot],localInput or {})
    if game.phase=="FINAL" then return end
    for _, event in ipairs(events or {}) do
        local member = play.members[event.playerId]
        local input = event.input
        if member and member.slot~=play.localSlot and member.slot==event.slot
            and type(input)=="table" and finite(input.seq) and input.seq>member.lastSequence then
            member.lastSequence,member.lastSeen = input.seq,play.elapsed
            updateControl(game.humans[member.slot],input)
            for i, item in ipairs(type(input.actions)=="table" and input.actions or {}) do
                if i>8 then break end
                if type(item)=="table" then
                    local aim = item.action=="pass" and {to=item.to,point=item.point} or item.aim
                    local action = cleanAction(game,item.action,item.x,item.z,aim)
                    if action then applyCommand(game,member.slot,action) end
                end
            end
        end
    end
    for _, member in pairs(play.members) do
        if member.slot~=play.localSlot and play.elapsed-(member.lastSeen or 0)>.75 then
            updateControl(game.humans[member.slot],{})
        end
    end
    local localControl = game.humans[play.localSlot]
    P.FullMatch.update(game,dt,localControl.x,localControl.z)
end

local function faceoffState(draw)
    if not draw then return end
    return {
        phase=draw.phase, active=draw.active, meter=draw.meter,
        windowStart=draw.windowStart, windowEnd=draw.windowEnd, sweetSpot=draw.sweetSpot,
        cpuMeter=draw.cpuMeter, userTeam=draw.userTeam, result=draw.result and {loose=draw.result.loose}
    }
end

function ClubsMatch.snapshot(play)
    if not play.isHost then return end
    local game = play.game
    local cached = play.outbound
    if cached and cached.phase==game.phase and play.elapsed-play.lastSnapshot<.083 then return cached end
    play.sequence,play.lastSnapshot = play.sequence+1,play.elapsed
    local players, blocked = {}, {}
    for index, p in ipairs(game.squad) do
        players[index] = {p.x,p.z,p.yaw,p.speed,p.turn,p.anim.action or "",p.anim.actionTime,p.anim.actionSpeed}
        if game.positioning.blocked[index] then blocked[#blocked+1] = index end
    end
    local ball, clock, screen = game.ball.position, game.ruleClock, game.screen
    play.outbound = {
        seq=play.sequence, matchId=play.matchId, players=players, ball={ball.x,ball.y,ball.z},
        phase=game.phase, phaseTime=game.phaseTime, clock=game.clock, period=game.period,
        homeScore=game.homeScore, awayScore=game.awayScore, carrier=game.carrier,
        pending=game.pending and game.pending.kind, flight=game.flight and game.flight.kind, loose=game.loose,
        inNet=game.inNet~=nil, announcement=game.announcement, announcementTime=game.announcementTime,
        ruleClock=clock and {shot=clock.shot,clear=clock.clear,crease=clock.crease},
        faceoff=game.phase=="FACEOFF" and faceoffState(game.faceoff) or nil,
        screen=screen and {screener=screen.screener,phase=screen.phase},
        blocked=blocked
    }
    return play.outbound
end

local function validSnapshot(play, data)
    if type(data)~="table" or data.matchId~=play.matchId or not finite(data.seq)
        or data.seq<=play.sequence or not phases[data.phase] or not finite(data.clock)
        or not finite(data.homeScore) or not finite(data.awayScore) or not finite(data.period)
        or type(data.players)~="table" or #data.players~=#play.game.squad or type(data.ball)~="table" then
        return false
    end
    for _, row in ipairs(data.players) do
        if type(row)~="table" or not finite(row[1]) or not finite(row[2]) or not finite(row[3]) then
            return false
        end
    end
    return finite(data.ball[1]) and finite(data.ball[2]) and finite(data.ball[3])
end

local function acceptSnapshot(play, data)
    local game = play.game
    play.sequence,play.inbound,play.lastSnapshot = data.seq,data,play.elapsed
    game.phase,game.phaseTime,game.clock,game.period = data.phase,data.phaseTime or 0,data.clock,data.period
    game.homeScore,game.awayScore = data.homeScore,data.awayScore
    game.controlled = play.localSlot
    game.carrier = finite(data.carrier) and game.squad[data.carrier] and data.carrier or nil
    game.pending,game.flight = data.pending and {kind=data.pending},data.flight and {kind=data.flight}
    game.loose,game.inNet = data.loose==true,data.inNet and {} or nil
    game.announcement = type(data.announcement)=="string" and data.announcement or ""
    game.announcementTime = bounded(data.announcementTime,0,10)
    game.ruleClock = type(data.ruleClock)=="table" and data.ruleClock or {}
    game.screen = type(data.screen)=="table" and data.screen or nil
    if type(data.blocked)=="table" then
        for _, slot in ipairs(data.blocked) do
            if slot==play.localSlot then
                game.positioning.notice,game.positioning.level,game.positioning.noticeTime = "OFFSIDES","offsides",.45
                break
            end
        end
    end
    if type(data.faceoff)=="table" then
        local draw = game.faceoff
        for _, key in ipairs({"phase","active","meter","windowStart","windowEnd","sweetSpot","cpuMeter","result"}) do
            draw[key] = data.faceoff[key]
        end
        draw.userTeam = play.localSlot==draw.home.id and data.faceoff.userTeam or false
    end
    for index, row in ipairs(data.players) do
        local anim = game.squad[index].anim
        local action = type(row[6])=="string" and P.AnimationController.clips[row[6]] and row[6] or nil
        anim.action,anim.actionTime,anim.actionSpeed = action,bounded(row[7],0,8),bounded(row[8],.5,2,1)
        if not action then anim.entry=nil end
    end
end

function ClubsMatch.guestStep(play, dt, snapshot)
    if play.isHost then return end
    local game = play.game
    dt = bounded(dt,0,.1)
    play.elapsed = play.elapsed+dt
    game.positioning.noticeTime = math.max(0,(game.positioning.noticeTime or 0)-dt)
    if validSnapshot(play,snapshot) then acceptSnapshot(play,snapshot) end
    local data = play.inbound
    if not data then return end
    local stale = play.elapsed-play.lastSnapshot>.6
    local blend = 1-math.exp(-18*dt)
    for index, player in ipairs(game.squad) do
        local row = data.players[index]
        player.x = player.x+(row[1]-player.x)*blend
        player.z = player.z+(row[2]-player.z)*blend
        player.yaw = player.yaw+((row[3]-player.yaw+180)%360-180)*blend
        player.speed = stale and 0 or bounded(row[4],0,20)
        player.turn = bounded(row[5],-1,1)
        player.rig.root.position,player.rig.root.eulerAngles = vec3(player.x,0,player.z),vec3(0,player.yaw,0)
        P.AnimationController.update(player.anim,dt,{speed=player.speed,turn=player.turn,possessed=game.carrier==index})
    end
    local p = game.squad[play.localSlot]
    game.marker.position = p.rig.root.position
    local target = vec3(data.ball[1],data.ball[2],data.ball[3])
    game.ball.position = game.ball.position+(target-game.ball.position)*blend
end

function ClubsMatch.result(play)
    if not play.isHost or play.game.phase~="FINAL" then return end
    local game = play.game
    local summary = P.Statistics.matchSummary(game)
    local stats = {}
    for id, member in pairs(play.members) do
        local entry = game.statistics.entries[member.slot]
        local line = entry.profile or entry.actor
        stats[id] = summary.players[line.playerId].stats
    end
    return {matchId=play.matchId,homeScore=game.homeScore,awayScore=game.awayScore,opponent=game.awayId,stats=stats}
end
end

-- ClubsNet
do
-- PolyLax Clubs relay client for Codea's asynchronous http.request API.
PolyLax = PolyLax or {}
local Net = {}
PolyLax.ClubsNet = Net

local requestTimeout, maxBackoff = 8, 8
local matchPoll, lobbyPoll = .15, .65
local maxActions, actionsPerRequest = 24, 8
local maxBody, maxReply = 64 * 1024, 1024 * 1024

local function trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

function Net.validURL(value, allowLoopback)
    local url = trim(value):gsub("/+$", "")
    if #url == 0 then return nil, "Set a Clubs relay URL in Settings." end
    local scheme, authority, path = url:match("^(https?)://([^/]+)(.*)$")
    if not scheme or #url > 240 or path:find("[^%w_./~%-]") or path:find("%.%.") then
        return nil, "Enter a valid HTTPS relay URL."
    end
    local host, port = authority:match("^([%w.%-]+):(%d+)$")
    if not host then host = authority:match("^([%w.%-]+)$") end
    if not host or port and (tonumber(port) < 1 or tonumber(port) > 65535) then
        return nil, "Enter a valid HTTPS relay URL."
    end
    if scheme ~= "https" and not (allowLoopback and (host == "127.0.0.1" or host == "localhost")) then
        return nil, "Online Clubs requires HTTPS."
    end
    return url
end

local function validSession(session)
    return type(session) == "table" and type(session.token) == "string"
        and #session.token >= 16 and #session.token <= 256 and session.token:match("^[%w_%-]+$")
        and type(session.playerId) == "string" and #session.playerId > 0
        and type(session.roomCode) == "string" and #session.roomCode > 0
end

function Net.new(url, options)
    options = options or {}
    local relay, problem = Net.validURL(url, options.allowLoopback)
    local codec = options.json or json
    local transport = options.transport or (http and http.request)
    if relay and (type(transport) ~= "function" or not codec
        or type(codec.encode) ~= "function" or type(codec.decode) ~= "function") then
        relay, problem = nil, "Codea HTTP or JSON is unavailable in this runtime."
    end
    return {url=relay, status=relay and "idle" or "unavailable", error=problem,
        request=transport, codec=codec, clock=0, nextPoll=0, retry=0,
        actions={}, inputs={}, inputSeq=0, after=0, change=0}
end

function Net.isHost(connection)
    return connection.session ~= nil and connection.lobby ~= nil
        and connection.lobby.hostId == connection.session.playerId
end

local function resetMatch(connection)
    connection.snapshot, connection.pendingInput, connection.localInput = nil, nil, nil
    connection.refreshLobby = nil
    connection.inputSeq, connection.after = 0, 0
    connection.actions, connection.inputs = {}, {}
end

local function clearSession(connection)
    connection.session, connection.lobby, connection.command = nil, nil, nil
    resetMatch(connection)
end

local function changed(connection, operation)
    connection.lastOperation = operation
    connection.change = connection.change + 1
end

local function updateReply(connection, operation, reply, sent)
    local lobby = reply.lobby
    if operation == "leave" then
        clearSession(connection)
    elseif type(lobby) == "table" and type(lobby.players) == "table"
        and type(lobby.code) == "string" and type(lobby.phase) == "string" then
        if lobby.matchId ~= (connection.lobby and connection.lobby.matchId) then resetMatch(connection) end
        connection.lobby = lobby
        if validSession(reply.session) then connection.session = reply.session end
    else
        return false
    end
    if operation ~= "leave" and not connection.session then return false end
    if type(reply.inputSeq) == "number" then
        connection.inputSeq = math.max(connection.inputSeq, reply.inputSeq)
    end
    local snapshot = reply.snapshot
    if type(snapshot) == "table" and type(snapshot.seq) == "number"
        and (not connection.snapshot or snapshot.seq > connection.snapshot.seq) then
        connection.snapshot = snapshot
    end
    if connection.pendingInput and sent.input == connection.pendingInput then
        connection.pendingInput = nil
    end
    if type(reply.inputs) == "table" then
        for _, event in ipairs(reply.inputs) do
            if type(event) == "table" and type(event.id) == "number" and event.id > connection.after then
                connection.after = event.id
                connection.inputs[#connection.inputs+1] = event
            end
        end
    end
    return true
end

local function retryLater(connection, transaction, message)
    if connection.inFlight ~= transaction then return end
    connection.inFlight, connection.busy = nil, false
    connection.retry = math.min(maxBackoff, math.max(.5, connection.retry * 2))
    connection.nextPoll = connection.clock + connection.retry
    connection.status = connection.session and "reconnecting" or "idle"
    connection.error = message
    changed(connection, transaction.operation)
end

local function request(connection, operation, payload)
    local ok, body = true, "{}"
    if next(payload) then ok, body = pcall(connection.codec.encode, payload) end
    if not ok or type(body) ~= "string" or #body > maxBody then
        connection.error = "Could not encode this Clubs request."
        connection.nextPoll = connection.clock + lobbyPoll
        return false, connection.error
    end
    local transaction = {operation=operation, deadline=connection.clock + requestTimeout}
    connection.inFlight, connection.busy = transaction, true
    if not connection.lobby then connection.status = "connecting" end
    local headers = {["Content-Type"]="application/json", Accept="application/json"}
    if connection.session then headers.Authorization = "Bearer "..connection.session.token end

    local function success(raw, status)
        if connection.inFlight ~= transaction then return end
        if type(status) ~= "number" or status >= 500 or status == 429 then
            retryLater(connection, transaction, "The Clubs relay is temporarily unavailable.")
            return
        end
        local decoded, reply = false, nil
        if type(raw) == "string" and #raw <= maxReply then
            decoded, reply = pcall(connection.codec.decode, raw)
        end
        if not decoded or type(reply) ~= "table" then
            retryLater(connection, transaction, "The relay returned an unreadable response.")
            return
        end
        connection.inFlight, connection.busy = nil, false
        if status < 200 or status >= 300 then
            if status == 401 then clearSession(connection) end
            if operation == "sync" then
                connection.pendingInput = nil
                -- A playing client may still have input in flight when the
                -- host finishes. Fetch the new phase without stale match data.
                connection.refreshLobby = status == 409 and payload.input ~= nil
            end
            local message = type(reply.message) == "string" and reply.message
                or type(reply.error) == "string" and reply.error or "The relay declined this request."
            connection.error = message:gsub("%c", " "):sub(1, 140)
            connection.status = connection.lobby and "connected" or "idle"
            connection.nextPoll = connection.clock + (connection.refreshLobby and 0 or lobbyPoll)
        elseif not updateReply(connection, operation, reply, payload) then
            connection.error = "The relay response is incomplete."
            connection.status = connection.session and "reconnecting" or "idle"
            connection.nextPoll = connection.clock + lobbyPoll
        else
            connection.error, connection.retry = nil, 0
            connection.status = connection.lobby and "connected" or "idle"
            local interval = connection.lobby and connection.lobby.phase == "match" and matchPoll or lobbyPoll
            connection.nextPoll = connection.clock + interval
        end
        changed(connection, operation)
    end

    local function failed()
        retryLater(connection, transaction, "Could not reach the Clubs relay.")
    end
    local sent = pcall(connection.request, connection.url.."/v1/"..operation, success, failed,
        {method="POST", headers=headers, data=body})
    if not sent then failed() end
    return sent
end

local function command(connection, operation, payload, authenticated)
    if not connection.url then return false, connection.error end
    if authenticated and not validSession(connection.session) then return false, "Join a room first." end
    if connection.command then return false, "Wait for the current request." end
    if connection.inFlight then
        if connection.inFlight.operation ~= "sync" then return false, "Wait for the current request." end
        connection.command = {operation=operation, payload=payload}
        return true
    end
    return request(connection, operation, payload)
end

function Net.create(connection, club, profile)
    if connection.session then return false, "Leave your current room first." end
    if type(club) ~= "table" or type(profile) ~= "table" then return false, "Create a club and a player first." end
    return command(connection, "create", {name=club.name, team=club.team, stage=club.stage, profile=profile})
end

function Net.join(connection, roomCode, profile)
    if connection.session then return false, "Leave your current room first." end
    local code = trim(roomCode):upper()
    if not code:match("^%w+$") or #code > 16 then return false, "Enter the invitation code." end
    if type(profile) ~= "table" then return false, "Create a Clubs player first." end
    return command(connection, "join", {roomCode=code, profile=profile})
end

function Net.resume(connection, session)
    if not connection.url then return false, connection.error end
    if not validSession(session) then return false, "No saved Clubs room." end
    if connection.inFlight or connection.command then return false, "Wait for the current request." end
    if not connection.session or session.token ~= connection.session.token then clearSession(connection) end
    connection.session = {token=session.token, playerId=session.playerId, roomCode=session.roomCode}
    return command(connection, "resume", {}, true)
end

function Net.ready(connection, ready)
    return command(connection, "ready", {ready=ready == true}, true)
end

function Net.start(connection)
    return command(connection, "start", {}, true)
end

function Net.leave(connection)
    return command(connection, "leave", {}, true)
end

function Net.finish(connection, result)
    if type(result) ~= "table" then return false, "A final score is required." end
    return command(connection, "finish", {result=result}, true)
end

function Net.disconnect(connection)
    connection.inFlight, connection.busy = nil, false
    connection.status = connection.url and "idle" or "unavailable"
    clearSession(connection)
    changed(connection, "disconnect")
end

local function axis(value)
    return type(value) == "number" and value == value and math.max(-1, math.min(1, value)) or 0
end

function Net.queueAction(connection, action)
    if type(action) ~= "table" or #connection.actions >= maxActions then return false end
    connection.actions[#connection.actions+1] = action
    return true
end

function Net.takeInputs(connection)
    local inputs = connection.inputs
    connection.inputs = {}
    return inputs
end

local function buildInput(connection)
    if not connection.localInput then return end
    if connection.pendingInput then return connection.pendingInput end
    connection.inputSeq = connection.inputSeq + 1
    local control = connection.localInput
    local pending = {seq=connection.inputSeq, x=control.x, z=control.z, sprint=control.sprint}
    if #connection.actions > 0 then
        pending.actions = {}
        for _ = 1, math.min(actionsPerRequest, #connection.actions) do
            pending.actions[#pending.actions+1] = table.remove(connection.actions, 1)
        end
    end
    connection.pendingInput = pending
    return pending
end

-- Pass one frame of controls to tick. `actions` holds only new events from
-- that frame, and movement is sampled at the request rate for guests.
function Net.tick(connection, dt, exchange)
    if not connection.url then return end
    connection.clock = connection.clock + math.max(dt or 0, 0)
    exchange = exchange or {}
    local control = exchange.input
    local playing = connection.lobby and connection.lobby.phase == "match"
    if playing and not Net.isHost(connection) then
        if control then
            connection.localInput = {x=axis(control.x), z=axis(control.z), sprint=control.sprint == true}
            for _, action in ipairs(control.actions or {}) do Net.queueAction(connection, action) end
        else
            connection.localInput = {x=0, z=0, sprint=false}
        end
    end
    local transaction = connection.inFlight
    if transaction and connection.clock >= transaction.deadline then
        retryLater(connection, transaction, "The Clubs request timed out.")
    end
    if connection.inFlight then return end
    local pending = connection.command
    if pending then
        connection.command = nil
        if connection.session then request(connection, pending.operation, pending.payload) end
    elseif connection.session and connection.clock >= connection.nextPoll then
        local payload = {}
        if Net.isHost(connection) then
            payload.after = connection.after
            if playing then payload.snapshot = exchange.snapshot end
        elseif playing and not connection.refreshLobby then
            payload.input = buildInput(connection)
        end
        connection.refreshLobby = nil
        request(connection, "sync", payload)
    end
end
end

-- CareerSeason
do
-- PolyLax 2.0 | Competition calendar, postseason, and career progression
PolyLax = PolyLax or {}
local P = PolyLax
local Season = {}
P.CareerSeason = Season

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function commit(career, candidate)
    if not P.Career.save(candidate) then return false end
    for key in pairs(career) do
        if candidate[key] == nil then career[key] = nil end
    end
    for key, value in pairs(candidate) do career[key] = value end
    return true
end

function Season.competition(career)
    return P.League.profile(career.stage,career.team)
end

local function newSeason(career)
    local profile, records = Season.competition(career), {}
    for _, team in ipairs(P.League.teams(profile)) do
        records[tostring(team.id)] = {id=team.id,wins=0,losses=0,ties=0,differential=0}
    end
    return {team=career.team, stage=career.stage, season=career.season, week=1, phase="regular",
        rounds=P.League.schedule(profile,career.season), records=records, results={},
        playoffs={}, personal={}, gameBoxes={}, games=0, xp=0,
        screenCoachCounts={}, wins=0, losses=0, ties=0, replay=0}
end

local function state(career)
    local data = career.seasonData
    if type(data) ~= "table" or data.team ~= career.team or data.stage ~= career.stage
        or data.season ~= career.season or type(data.records) ~= "table"
        or type(data.rounds) ~= "table" or type(data.results) ~= "table"
        or type(data.week) ~= "number" or type(data.playoffs) ~= "table" then
        data = newSeason(career)
        career.seasonData = data
    end
    if type(data.personal) ~= "table" then data.personal = {} end
    if type(data.screenCoachCounts) ~= "table" then data.screenCoachCounts = {} end
    if type(data.gameBoxes) ~= "table" then data.gameBoxes = {} end
    return data
end

local function fixtureID(career, suffix)
    return career.stage .. "-" .. career.season .. "-" .. suffix
end

local function regularFixture(career, data, week)
    for _, game in ipairs(data.rounds[week] or {}) do
        if game.home == career.team or game.away == career.team then
            local home = game.home == career.team
            local venue = P.League.venue(game.home)
            return {id=fixtureID(career, "w"..week), opponent=home and game.away or game.home,
                home=home, homeId=game.home, awayId=game.away, label="Week "..week, week=week,
                site=venue.name, venueId=venue.id, stage=career.stage, season=career.season}
        end
    end
end

local function ranked(data)
    local order = {}
    for _, record in pairs(data.records) do
        local row = copy(record)
        row.name = P.TeamUniform.get(row.id).name
        row.points = 2*row.wins + row.ties
        order[#order+1] = row
    end
    table.sort(order, function(a,b)
        if a.points ~= b.points then return a.points>b.points end
        if a.differential ~= b.differential then return a.differential>b.differential end
        return tostring(a.id)<tostring(b.id)
    end)
    return order
end

local function leagueResult(data, a, b, home, away)
    local first, second = data.records[tostring(a)], data.records[tostring(b)]
    first.differential = first.differential + home-away
    second.differential = second.differential + away-home
    if home > away then first.wins,second.losses=first.wins+1,second.losses+1
    elseif home < away then first.losses,second.wins=first.losses+1,second.wins+1
    else first.ties,second.ties=first.ties+1,second.ties+1 end
end

local function simulate(career, data, label, homeId, awayId, week, postseason)
    local id = fixtureID(career,label.."-"..P.League.teamKey(homeId).."-"..P.League.teamKey(awayId))
    local box = data.gameBoxes[id]
    if not box then
        box = P.League.simulate(Season.competition(career), {
            id=id, season=career.season, stage=career.stage, week=week, postseason=postseason,
            homeId=homeId, awayId=awayId
        })
        data.gameBoxes[id] = box
    end
    return box
end

local function weekResults(career, data, week, actual)
    for _, pair in ipairs(data.rounds[week]) do
        local box = actual
        if pair.home ~= career.team and pair.away ~= career.team then
            box = simulate(career,data,"w"..week,pair.home,pair.away,week)
        end
        leagueResult(data,pair.home,pair.away,box.homeScore,box.awayScore)
    end
end

local function complete(career, data, title)
    data.phase = "complete"
    if title then career.championships = (career.championships or 0) + 1 end
    data.titleWon = title == true
    if career.contract then
        career.contract.remaining = math.max(0,career.contract.remaining-1)
    end
end

local postseasonLabels = {quarterfinal="Quarterfinal", semifinal="Semifinal", final="Championship"}

local function phaseLabel(phase)
    local size = phase:match("^round%-of%-(%d+)$")
    return postseasonLabels[phase] or (size and "Round of "..size) or phase
end

local function postseasonName(phase)
    return phase == "final" and "championship" or phase
end

local function winner(box)
    return box.homeScore > box.awayScore and box.homeId or box.awayId
end

local function playoffGame(career, home, away, phase)
    local venue = P.League.venue(home)
    return {home=home == career.team, opponent=home == career.team and away or home,
        label=phaseLabel(phase), phase=phase, postseason=postseasonName(phase),
        homeId=home,awayId=away,site=venue.name, venueId=venue.id, stage=career.stage,season=career.season}
end

local function openBracketRound(career, data, remaining)
    local bracket = data.bracket
    while #remaining > 1 do
        table.sort(remaining,function(a,b) return bracket.seeds[tostring(a)] < bracket.seeds[tostring(b)] end)
        local capacity = 2
        while capacity < #remaining do capacity = capacity*2 end
        local phase = capacity == 2 and "final" or capacity == 4 and "semifinal"
            or capacity == 8 and "quarterfinal" or "round-of-"..capacity
        local byeCount = capacity - #remaining
        local pending = {}
        for index=1,byeCount do pending[index] = remaining[index] end
        bracket.userIndex, bracket.pending = nil, pending
        for index=1,(#remaining-byeCount)/2 do
            local home,away = remaining[byeCount+index],remaining[#remaining+1-index]
            if home == career.team or away == career.team then
                data.playoffs[#data.playoffs+1] = playoffGame(career,home,away,phase)
                bracket.userIndex = #data.playoffs
            else
                local box = simulate(career,data,phase,home,away,nil,postseasonName(phase))
                pending[#pending+1] = winner(box)
            end
        end
        if bracket.userIndex then
            data.phase, data.replay = phase, 0
            return
        end
        remaining = pending
    end
    data.champion = remaining[1]
    complete(career,data,data.champion == career.team)
end

local function advanceRegular(career, data)
    while data.week <= #data.rounds and not regularFixture(career,data,data.week) do
        weekResults(career,data,data.week)
        data.week = data.week+1
    end
    if data.week <= #data.rounds then return end
    local order, seeds, remaining = ranked(data), {}, {}
    local qualified = math.min(#order, math.max(2, Season.competition(career).qualified))
    for index=1,qualified do
        local id = order[index].id
        seeds[tostring(id)], remaining[index] = index, id
    end
    data.bracket = {seeds=seeds}
    openBracketRound(career,data,remaining)
end

function Season.fixture(career)
    local data = state(career)
    if data.phase == "regular" then advanceRegular(career,data) end
    if data.phase == "regular" then return regularFixture(career,data,data.week) end
    local stage = data.bracket and data.phase ~= "complete" and data.bracket.userIndex
        or data.phase == "semifinal" and 1 or data.phase == "final" and 2
    if not stage then return end
    local game = copy(data.playoffs[stage])
    game.id = fixtureID(career,data.phase.."-"..data.replay)
    game.phase, game.postseason = data.phase,postseasonName(data.phase)
    if not game.site then
        game.homeId = game.home and career.team or game.opponent
        game.awayId = game.home and game.opponent or career.team
        local venue = P.League.venue(game.homeId)
        game.site, game.venueId = venue.name,venue.id
        game.stage, game.season = career.stage,career.season
    end
    if data.replay > 0 then game.label = game.label.." replay" end
    return game
end

local function actualBox(career, fixture, match, captured)
    local box = captured and copy(captured) or {players={},teams={},detailUnavailable=true}
    if box.sides and box.awayId == fixture.homeId and box.homeId ~= fixture.homeId then
        box.sides[1],box.sides[2] = box.sides[2],box.sides[1]
    end
    box.id, box.source, box.competition = fixture.id,"played",Season.competition(career).id
    box.stage, box.season, box.week = career.stage,career.season,fixture.week
    box.postseason, box.venueId = fixture.postseason,fixture.venueId
    box.homeId,box.awayId = fixture.homeId,fixture.awayId
    box.homeScore = fixture.home and match.homeScore or match.awayScore
    box.awayScore = fixture.home and match.awayScore or match.homeScore
    return box
end

function Season.record(career, fixture, match, experience, personal, screenEvents, captured)
    local current = Season.fixture(career)
    if not current or current.id ~= fixture.id then return false end
    fixture = current
    local data = copy(career.seasonData)
    career.seasonData = data
    if career.contract then career.contract = copy(career.contract) end
    local own, other = match.homeScore, match.awayScore
    local box = actualBox(career,fixture,match,captured)
    data.gameBoxes[fixture.id] = box
    data.results[fixture.id] = own.."–"..other
    data.lastFixtureId = fixture.id
    data.games, data.xp = data.games+1, data.xp+experience
    for key, value in pairs(personal) do data.personal[key] = (data.personal[key] or 0)+value end
    screenEvents = screenEvents or {}
    for _, event in ipairs(screenEvents) do
        local kind = event.kind
        data.screenCoachCounts[kind] = (data.screenCoachCounts[kind] or 0)+1
    end
    data.lastScreenCoach = {fixtureId=fixture.id, points=personal.screenCoachPoints or 0, count=#screenEvents}
    if own>other then data.wins=data.wins+1
    elseif own<other then data.losses=data.losses+1
    else data.ties=data.ties+1 end
    if data.phase == "regular" then
        weekResults(career,data,data.week,box)
        data.week = data.week+1
        advanceRegular(career,data)
        return true
    end
    if own == other then
        data.replay = data.replay+1
        return true
    end
    local bracket = data.bracket
    if bracket then
        local game = data.playoffs[bracket.userIndex]
        game.result,game.fixtureId = data.results[fixture.id],fixture.id
        bracket.pending[#bracket.pending+1] = winner(box)
        openBracketRound(career,data,bracket.pending)
        return true
    end

    -- Keep the already-open legacy two-round bracket playable on older saves.
    local semifinal = data.phase == "semifinal"
    local game = data.playoffs[semifinal and 1 or 2]
    game.result, game.fixtureId = data.results[fixture.id], fixture.id
    data.replay = 0
    if semifinal and own > other then
        data.phase = "final"
        data.playoffs[2] = playoffGame(career,career.team,data.otherFinalist,"final")
    else
        if semifinal and data.otherFinalist then
            local final = simulate(career,data,"final",fixture.opponent,data.otherFinalist,nil,"championship")
            data.champion = winner(final)
        else
            data.champion = winner(box)
        end
        complete(career,data,not semifinal and own>other)
    end
    return true
end

function Season.standings(career)
    Season.fixture(career)
    return ranked(state(career))
end

function Season.boxScores(career, season)
    if not season or season == career.season then return state(career).gameBoxes end
    for _, archived in ipairs(career.history or {}) do
        if archived.season == season then return archived.boxScores or {} end
    end
    return {}
end

function Season.leaderboard(career, key, season)
    local byPlayer, rows = {}, {}
    for _, box in pairs(Season.boxScores(career,season)) do
        for id,line in pairs(box.players or {}) do
            local row = byPlayer[id]
            if not row then
                row = {playerId=id,teamId=line.teamId,name=line.name,role=line.role,career=line.career,stats={},
                    playedGames=0,simulatedGames=0}
                byPlayer[id] = row
            end
            local source = box.source == "simulated" and "simulatedGames" or "playedGames"
            row[source] = row[source] + 1
            for stat,value in pairs(line.stats or {}) do
                if type(value) == "number" then row.stats[stat] = (row.stats[stat] or 0)+value end
            end
        end
    end
    for _, row in pairs(byPlayer) do
        row.value = row.stats[key] or 0
        if row.value ~= 0 then rows[#rows+1] = row end
    end
    table.sort(rows,function(a,b)
        if a.value ~= b.value then return a.value > b.value end
        return a.playerId < b.playerId
    end)
    return rows
end

local function gameScreenPoints(career, fixtureId)
    local entry = fixtureId and career.entries[fixtureId]
    return entry and entry.stats and entry.stats.screenCoachPoints
end

function Season.schedule(career)
    local current = Season.fixture(career)
    local data, rows = state(career), {}
    for week=1,#data.rounds do
        local game = regularFixture(career,data,week)
        if game then
            rows[#rows+1] = {id=game.id,label=game.label,opponent=P.TeamUniform.get(game.opponent).name,
                home=game.home,result=data.results[game.id],current=current and current.id==game.id,
                site=game.site,week=week,opponentRecord=data.records[tostring(game.opponent)],
                screenCoachPoints=gameScreenPoints(career, game.id)}
        end
    end
    for i, game in ipairs(data.playoffs) do
        local phase = game.phase or (i==1 and "semifinal" or "final")
        rows[#rows+1] = {id=game.fixtureId, label=game.label,opponent=P.TeamUniform.get(game.opponent).name,
            home=game.home,site=game.site,opponentRecord=data.records[tostring(game.opponent)],
            result=game.result,current=current and phase==data.phase,
            screenCoachPoints=gameScreenPoints(career, game.fixtureId)}
    end
    return rows
end

local function screenCoachAdjustment(data)
    return math.max(-12, math.min(12, data.personal.screenCoachPoints or 0))
end

function Season.status(career)
    local nextGame = Season.fixture(career)
    local data = state(career)
    local contract = career.contract
    local completeSeason = data.phase == "complete"
    local starter = data.games >= 2 and data.xp + screenCoachAdjustment(data) >= 56
    local status = completeSeason and "Season complete" or data.phase == "regular"
        and ("Week "..data.week.." of "..#data.rounds) or phaseLabel(data.phase)
    if data.titleWon then status = "Championship won" end
    if nextGame then nextGame.opponentRecord = data.records[tostring(nextGame.opponent)] end
    local lastResult = data.lastFixtureId and data.results[data.lastFixtureId]
    if not lastResult then
        local lastPlayoff = data.playoffs[#data.playoffs]
        lastResult = lastPlayoff and lastPlayoff.result
        for week=data.week-1,1,-1 do
            if lastResult then break end
            lastResult = data.results[fixtureID(career,"w"..week)]
        end
    end
    return {phase=data.phase,season=career.season,starter=starter,title=data.titleWon,
        statusLine=status,championships=career.championships or 0,
        competition=Season.competition(career),nextGame=nextGame,lastResult=lastResult,champion=data.champion,
        screenCoachPoints=data.personal.screenCoachPoints or 0, lastScreenCoach=data.lastScreenCoach,
        contract=contract and (contract.remaining.." season(s) left · "..contract.value.." credits"),
        canAdvance=completeSeason and contract and contract.remaining > 0}
end

function Season.offers(career)
    local data = state(career)
    if data.phase ~= "complete" then return {} end
    local performance = data.xp + data.wins*5 + (data.titleWon and 30 or 0) + screenCoachAdjustment(data)
    local list = {}
    if career.stage == "highSchool" then
        for i, team in ipairs(P.SchoolTeams.ncaa) do
            if performance >= 80+i*8 then
                list[#list+1] = {id=team.id,name=team.name,detail="Division I scholarship"}
            end
        end
        local club = P.SchoolTeams.get("florida-state")
        list[#list+1] = {id=club.id,name=club.name,detail="MCLA club invitation"}
    elseif career.stage == "college" or career.contract and career.contract.remaining <= 0 then
        local count = math.max(2,math.min(#P.TeamUniform.teams,math.floor(performance/37)))
        local pick = math.max(1,64-math.floor(performance/5))
        for i=1,count do
            local team = P.TeamUniform.teams[(i+career.season-2)%#P.TeamUniform.teams+1]
            local length = i<=2 and 2 or 1
            local value = 40+math.floor(performance*.35)+i*3
            list[#list+1] = {id=team.id,name=team.name,length=length,value=value,
                detail=(career.stage=="college" and ("Draft "..pick.." · ") or "")
                    ..length.." yr · "..value.." credits"}
        end
    end
    return list
end

local function nextSeason(career, candidate, stage, team)
    local data=state(candidate)
    P.Awards.finalize(candidate)
    candidate.history = candidate.history or {}
    candidate.history[#candidate.history+1] = {season=candidate.season, stage=candidate.stage,
        team=candidate.team, wins=data.wins, losses=data.losses, ties=data.ties,
        stats=data.personal, screenCoachCounts=data.screenCoachCounts, title=data.titleWon,
        champion=data.champion, competition=Season.competition(candidate).id, boxScores=data.gameBoxes,
        standings=ranked(data),awards=data.awards}
    candidate.stage, candidate.team = stage, team
    candidate.season, candidate.seasonData = candidate.season+1, nil
    return commit(career,candidate)
end

function Season.accept(career, id)
    for _, offer in ipairs(Season.offers(career)) do
        if offer.id == id then
            local candidate = copy(career)
            local stage = career.stage == "highSchool" and "college" or "professional"
            if offer.length then candidate.contract = {length=offer.length,remaining=offer.length,value=offer.value} end
            return nextSeason(career,candidate,stage,id)
        end
    end
    return false
end

function Season.advance(career)
    if not Season.status(career).canAdvance then return false end
    return nextSeason(career,copy(career),career.stage,career.team)
end

local skills = {
    {{"shooting","Shooting"},{"ballSecurity","Ball security"},{"speed","Speed"},{"passing","Passing"}},
    {{"speed","Speed"},{"stamina","Stamina"},{"passing","Passing"},{"shooting","Shooting"}},
    {{"stickCheck","Stick checks"},{"bodyCheck","Body checks"},{"interception","Interceptions"},{"speed","Speed"}},
    {{"faceoff","Faceoffs"},{"stamina","Stamina"},{"reaction","Reactions"},{"ballSecurity","Ball security"}},
    {{"reflexes","Reflexes"},{"handSpeed","Hand speed"},{"clearingAccuracy","Clears"},{"reaction","Reactions"}}
}

for _, list in ipairs(skills) do
    list[#list+1] = {"strength", "Strength"}
end

function Season.trainingCount(career)
    return #(skills[career.position] or skills[2])
end

local modernSkill={shooting="shotPower",ballSecurity="ballControl",
    interception="defensiveAwareness",reaction="defensiveAwareness",
    handSpeed="reflexes",clearingAccuracy="passing"}

function Season.training(career, index)
    local list = skills[career.position] or skills[2]
    local item = list[((index or 1)-1)%#list+1]
    if P.Development then
        local key=modernSkill[item[1]] or item[1]
        local current=P.Attributes.restore(career.attributes,career.position)[key]
        local nextValue,cost=P.Attributes.advance(career.attributes,key,career.position)
        return {key=key,label=item[2],value=current,cost=cost or 0,
            gain=nextValue and nextValue-current or 0,available=nextValue and P.Development.points(career)>=cost or false}
    end
    local value = career.attributes[item[1]]
    local cost = 40 + math.max(0,value-65)*2
    return {key=item[1],label=item[2],value=value,cost=cost,gain=math.min(3,99-value),
        available=value<99 and career.xp-(career.spentXP or 0)>=cost}
end

function Season.train(career, key)
    if P.Development then return P.Development.upgrade(career,modernSkill[key] or key) end
    for index=1,Season.trainingCount(career) do
        local skill = Season.training(career,index)
        if skill.key==key and skill.available then
            local candidate = copy(career)
            candidate.spentXP = (candidate.spentXP or 0)+skill.cost
            candidate.attributes[key] = math.min(99,skill.value+3)
            return commit(career,candidate)
        end
    end
    return false
end
end

-- End of PolyLax 3.1
