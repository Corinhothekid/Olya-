-- PolyLax 2.0 | Main
PolyLax = PolyLax or {}
local P = PolyLax
local state

local function navigate(page)
    local previous = state.page
    if state.menuAssets and previous == "FRONT" and page ~= "FRONT" then
        P.MenuAssets.leave(state.menuAssets)
    end
    state.page, state.pageAge, state.layout = page, 0, nil
    if state.menuAssets and page == "FRONT" and previous ~= "FRONT" and state.menuInteracted then
        P.MenuAssets.enter(state.menuAssets)
    end
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
        canResume=lobby and lobby.phase=="match" and state.clubPlay~=nil,
        menuMuted=state.menuAssets.muted,hasMenuTheme=state.menuAssets.hasTheme
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
    elseif id == "MENU_MUSIC" then
        P.MenuAssets.toggleMute(state.menuAssets)
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
        categoryIndex=4,career=P.Career.load(),awardState={},menuAssets=P.MenuAssets.load()}
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

local function renderShowcase(showcase, dt)
    P.MenuShowcase.update(showcase,dt)
    showcase.scene:update(dt)
    showcase.scene:draw()
end

local function frontScene(dt)
    if state.menuShowcaseFailed then return false end
    if not state.menuShowcase then
        local ok, showcase = pcall(function()
            return P.MenuShowcase.new(configuredScene(),state.profile.TEAM,state.profile.OPPONENT)
        end)
        if not ok then
            state.menuShowcaseFailed = true
            print("PolyLax menu showcase unavailable: "..tostring(showcase))
            return false
        end
        state.menuShowcase = showcase
    end
    local ok, message = pcall(renderShowcase,state.menuShowcase,dt)
    if not ok then
        state.menuShowcaseFailed = true
        state.menuShowcase = nil
        print("PolyLax menu showcase unavailable: "..tostring(message))
    end
    return ok
end

function draw()
    local dt = math.max(0, math.min(DeltaTime or 1/60, .05))
    state.pageAge = state.pageAge + dt
    updateClubs(dt)
    if isMenu(state.page) then
        local front = state.page=="FRONT"
        local shown = front and frontScene(dt)
        P.Style.screen(state.page,menuLayout(),state.pageAge,shown,front and state.menuAssets or nil)
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
    if touch.state==BEGAN and not state.menuInteracted then
        state.menuInteracted=true
        if state.page=="FRONT" then P.MenuAssets.enter(state.menuAssets) end
    end
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
            "Install the complete PolyLax 3.2 Main tab.")
        local modules = PolyLax or {}
        local missing = {}
        for _, name in ipairs({
            "Profile", "TeamUniform", "Character", "AnimationController",
            "CameraController", "GoalPhysics", "Gameplay", "Field", "Midfield", "MatchAI", "FullMatch",
            "Defense", "Faceoff", "MatchRules", "UI", "Career", "CareerUI", "SchoolTeams", "CareerSeason",
            "Passing", "Tactics", "Screens", "Style", "Athlete", "Attributes", "Development", "Statistics", "StatsUI", "League", "Awards", "AwardUI", "Presentation", "Clubs", "ClubsUI", "ClubsMatch", "ClubsNet", "MenuShowcase", "MenuAssets"
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
