-- PolyLax 3.4.3 | Complete single-tab edition
-- Paste into Main in a Legacy Craft project with a single tab.

-- Main
do
-- PolyLax 2.0 | Main
PolyLax = PolyLax or {}
local P = PolyLax
local state
local openRoad, openRoadActivity

local function roadPlayPage(page)
    return page=="ROAD_PRACTICE" or page=="ROAD_TRYOUT"
end

local function navigate(page)
    local previous = state.page
    if state.menuAssets and previous == "FRONT" and page ~= "FRONT" then
        P.MenuAssets.leave(state.menuAssets)
    end
    state.page, state.pageAge, state.layout = page, 0, nil
    if state.menuAssets and page == "FRONT" and previous ~= "FRONT" then
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
    if state.storyCreator then return state.road.story.athlete end
end

local function saveClubPlayer(candidate)
    return P.Clubs.savePlayer(state.clubs,candidate)
end

local function saveStoryPlayer(candidate)
    return P.Story.updateAthlete(state.road.story,candidate)
end

local function creatorSave()
    if state.clubsCreator then return saveClubPlayer end
    if state.storyCreator then return saveStoryPlayer end
end

local function storyCreatorLocked()
    return state.road.play~=nil or state.road.story.results.tryout~=nil
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
    elseif state.storyCreator then
        return P.Athlete.categories(athlete,storyCreatorLocked())
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
    P.Character.setStickType(state.creator.rig,careerPosition and careerPosition.stick or "short")
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

local function openUltimate()
    if not state.ultimate then state.ultimate = P.UltimateUI.new(P.Ultimate.load()) end
    P.UltimateUI.reset(state.ultimate)
    local play = state.ultimatePlay
    if play and play.recorded then state.ultimatePlay = nil end
    state.ultimate.activeMatch = play ~= nil and play.game.phase ~= "FINAL"
    state.ultimate.pendingResult = play ~= nil and play.game.phase == "FINAL" and not play.recorded
    if play and play.rewardMessage then P.UltimateUI.message(state.ultimate,play.rewardMessage) end
    openMenu("ULTIMATE")
end

local function openClubs(view)
    state.clubs = state.clubs or P.Clubs.load()
    state.clubView, state.clubPage = view or "CLUBS", 1
    state.clubEdit, state.clubMessage, state.clubConfirmRecover = nil, nil, nil
    openMenu("CLUBS")
end

local function openCreator(athlete, section)
    if state.creatorMode~=athlete then state.categoryIndex=4 end
    state.creatorMode = athlete
    state.careerCreator, state.clubsCreator, state.storyCreator = athlete == true, athlete == "clubs", athlete=="story"
    state.careerKit="home"
    if section then state.categoryIndex=section end
    local profile = editingAthlete()
    if profile then
        P.Athlete.ensure(profile,creatorFallback(),creatorSave())
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

local function roadNotice(message)
    return {speaker="Road to Glory",text=message,choices={{label="Continue",select=function() end}}}
end

local function leaveRoad()
    local road=state.road
    local saved,reason=P.Story.saveLocation(road.story,P.FreeRoam.location(road.roam))
    if not saved then
        P.FreeRoam.speak(road.roam,roadNotice(reason or "Could not save your campus location."))
        return false
    end
    P.FreeRoam.release(road.roam)
    return true
end

local function roadEvent(event, message)
    if not event then return message and roadNotice(message) or nil end
    local road=state.road
    if event.kind=="dialogue" then
        local choices={}
        for _,choice in ipairs(event.choices or {}) do
            choices[#choices+1]={label=choice.label,select=function()
                return roadEvent(P.Story.choose(road.story,event,choice.id))
            end}
        end
        return {speaker=event.speaker,text=event.text,choices=choices}
    end
    if not leaveRoad() then return end
    if event.kind=="activity" then
        openRoadActivity(event.activity)
    elseif event.kind=="shop" then
        road.shop=P.RoadEquipmentUI.new(configuredScene(),P.RoadToGlory.appearance(road),
            road.story.equipment,P.RoadToGlory.stickType(road),function(candidate)
                return P.Story.saveEquipment(road.story,candidate)
            end)
        openMenu("ROAD_SHOP")
    elseif event.kind=="clubs" then
        state.roadReturn=true
        openClubs()
    end
end

local function roadAction(id)
    if id=="pause" then return end
    if id=="equipment" then
        if state.road.roam.zone=="drip" then
            local dialogue=roadEvent(P.Story.interact(state.road.story,"drip"))
            if dialogue then P.FreeRoam.speak(state.road.roam,dialogue) end
        else P.FreeRoam.notice(state.road.roam,"Visit the Drip Lab to change your equipment.") end
        return
    end
    if not leaveRoad() then return end
    if id=="career" then openMenu("ROAD_JOURNAL")
    elseif id=="settings" then
        state.roadReturn=true
        openClubs("SETTINGS")
    elseif id=="home" then
        openMenu("FRONT")
    end
end

openRoad = function()
    local road=state.road
    if not road then
        road=P.RoadToGlory.new(state.profile)
        state.road=road
    end
    if road.play and road.play.recorded then road.play=nil end
    if road.roam then
        P.FreeRoam.appearance(road.roam,P.RoadToGlory.appearance(road),road.story.equipment,P.RoadToGlory.stickType(road))
    else
        road.roam=P.FreeRoam.new({
            profile=P.RoadToGlory.appearance(road),career=road.story.athlete,
            location=road.story.location,equipment=road.story.equipment,
            stickType=P.RoadToGlory.stickType(road),
            objective=function()
                local title,detail=P.Story.objective(road.story)
                return title.." · "..detail
            end,
            interact=function(point) return roadEvent(P.Story.interact(road.story,point.id)) end,
            action=roadAction,
            save=function(location) return P.Story.saveLocation(road.story,location) end,
            schedule=function() return road.story.timeOfDay end
        })
    end
    state.roadReturn=nil
    openMenu("ROAD")
    if road.message then
        P.FreeRoam.speak(road.roam,roadNotice(road.message))
        road.message=nil
    end
end

openRoadActivity = function(activity)
    local road=state.road
    local play=road.play
    if play and play.activity~=activity then
        P.FreeRoam.speak(road.roam,roadNotice("Finish your current lacrosse activity first."))
        return
    end
    if not play then
        play=P.RoadToGlory.newPlay(road,configuredScene(),activity)
        road.play=play
        if play.controller==P.FullMatch then beginPresentation(play,"pregame") end
    end
    play.captureAttempted=nil
    openMenu(play.controller==P.Gameplay and "ROAD_PRACTICE" or "ROAD_TRYOUT")
end

local function settleUltimate(play)
    if play.recorded or play.game.phase ~= "FINAL" then return end
    local ok, receipt = P.UltimateMatch.settle(state.ultimate.profile,play.game,play.id)
    play.recorded, play.rewardAttempted = ok, true
    if ok then
        play.rewardMessage = string.format("%s  +%d gold",receipt.result:upper(),receipt.payout)
    else
        play.rewardMessage = tostring(receipt or "Could not save the match result")
    end
    P.UltimateUI.message(state.ultimate,play.rewardMessage)
end

local function openUltimateMatch()
    local play = state.ultimatePlay
    if play and play.game.phase == "FINAL" then
        if not play.recorded then settleUltimate(play) end
        if play.recorded then
            state.ultimatePlay = nil
            state.ultimate.pendingResult = false
        end
        return
    end
    if not play then
        local scene = configuredScene()
        local game, id = P.UltimateMatch.new(scene,state.ultimate.profile,state.profile)
        if not game then
            P.UltimateUI.message(state.ultimate,tostring(id or "Could not start the match"))
            return
        end
        play = {scene=scene,camera=P.CameraController.new(scene,48),game=game,id=id}
        state.ultimatePlay = play
        beginPresentation(play,"pregame")
    end
    openMenu("ULTIMATE_MATCH")
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
        if state.statReturn == "ULTIMATE" then openUltimate()
        elseif state.statReturn == "ULTIMATE_RECORD" then navigate("ULTIMATE")
        elseif state.statReturn == "ROAD" then openRoad()
        else navigate(state.statReturn) end
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
            creatorSave())
        local play=state.careerCreator and state.careerPlay
        if play then
            local player=P.FullMatch.careerAthlete(play.game)
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
                            local player=play.game.careerPlayer and P.FullMatch.careerAthlete(play.game)
                                or play.game.squad[1]
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
    if page == "ULTIMATE_MATCH" then return state.ultimatePlay, P.FullMatch end
    if roadPlayPage(page) then
        local play=state.road and state.road.play
        return play,play and play.controller
    end
    if page == "CAREER_GAME" then return state.careerPlay, P.FullMatch end
    if page == "CLUB_MATCH" then return state.clubPlay, state.clubPlay.controller end
    return state.practice, P.Gameplay
end

local function isMenu(page)
    return page=="FRONT" or page=="MODES" or page=="PAUSE"
end

local function menuLayout()
    local play = state.resumePage and activePlay(state.resumePage)
    local ultimatePause = state.page=="PAUSE" and state.resumePage=="ULTIMATE_MATCH"
    local roadPause = state.page=="PAUSE" and roadPlayPage(state.resumePage)
    return P.Style.screenLayout(state.page,{resetEnabled=not (play and
        (play.recorded or (ultimatePause or roadPause) and play.game.phase=="FINAL")),
        statsEnabled=play and play.game.statistics~=nil,ultimatePause=ultimatePause,roadPause=roadPause})
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
    local saved = P.Clubs.savedRoom(state.clubs)
    local hosted = P.Clubs.hostedRoom(state.clubs)
    local canRequest = net and net.url and not net.command
        and (not net.inFlight or net.inFlight.operation=="sync")
    local member = lobby and clubMember(lobby,net.session.playerId)
    local waiting = lobby and lobby.phase == "lobby"
    local canStart = canRequest and waiting and P.ClubsNet.isHost(net) and #lobby.players==2
    if canStart then
        for _, p in ipairs(lobby.players) do canStart = canStart and p.ready and p.connected end
    end
    local host = lobby and P.ClubsNet.isHost(net)
    local interrupted = host and net.interruptedMatchId and net.interruptedMatchId==lobby.matchId
    local code = state.clubCode or saved and saved.club.code
    local message = state.clubMessage or net and (net.error or net.notice)
    if not message and net and net.busy and not lobby then message = "Contacting the relay" end
    local roster = lobby and clubOnlineRoster(net,lobby,state.clubView=="ROSTER")
    local schedule
    if state.clubView=="SCHEDULE" then
        schedule = P.Clubs.results(state.clubs)
        for _, fixture in ipairs(P.Clubs.schedule(state.clubs)) do schedule[#schedule+1] = fixture end
    end
    return P.ClubsUI.layout(state.clubView,state.clubs,{
        editing=state.clubEdit,draft=state.clubDraft,name=state.clubName,code=code,
        relay=state.clubs.settings.relayURL,stageName=P.Career.stages[stage],teamName=team and team.name,
        page=state.clubPage,message=message,lobby=lobby,roster=roster,schedule=schedule,
        canCreate=not lobby,hostEnabled=canRequest and not net.session and state.clubs.club~=nil,
        canConnect=canRequest and not net.session and #(code or "")==8,
        canReady=canRequest and waiting and member~=nil,ready=member and member.ready,canStart=canStart,
        savedRoom=saved,hostedRoom=hosted,canReconnect=canRequest and not net.session,
        host=host,canReopen=canRequest and host and lobby.phase=="final",
        interrupted=interrupted,canRecover=canRequest and interrupted,confirmRecovery=state.clubConfirmRecover,
        canResume=lobby and lobby.phase=="match" and state.clubPlay~=nil,
        menuMuted=state.menuAssets.muted,hasMenuTheme=state.menuAssets.hasTheme,
        campusReturn=state.roadReturn
    })
end

local function clubOnlineAction(id)
    local net = clubConnection()
    if not net then return end
    local result, message
    if id == "HOST_ONLINE" or id == "CONNECT" or id == "RESUME_ROOM" then
        local player = state.clubs.player
        local appearance = P.Athlete.profile(player)
        local profile = {id=player.id,name=P.Athlete.name(player),position=player.position,
            appearance=appearance,attributes=player.attributes,number=appearance.NUMBER-1}
        local saved = P.Clubs.savedRoom(state.clubs)
        local code = state.clubCode or saved and saved.club.code
        local room = id=="HOST_ONLINE" and P.Clubs.hostedRoom(state.clubs)
            or id=="CONNECT" and code and P.Clubs.savedRoom(state.clubs,code)
            or id=="RESUME_ROOM" and saved
        if room then
            result,message = P.ClubsNet.resume(net,room.session,profile)
        elseif id == "HOST_ONLINE" then
            result,message = P.ClubsNet.create(net,state.clubs.club,profile)
        else
            result,message = P.ClubsNet.join(net,code,profile)
        end
    elseif id == "READY" then
        local member = clubMember(net.lobby,net.session.playerId)
        result,message = P.ClubsNet.ready(net,not member.ready)
    elseif id == "START" then result,message = P.ClubsNet.start(net)
    elseif id == "REOPEN_ROOM" then result,message = P.ClubsNet.reopen(net)
    elseif id == "RECOVER_ROOM" then
        if not state.clubConfirmRecover then
            state.clubConfirmRecover = true
            state.clubMessage = "Confirm to end this interrupted match and keep your room"
            return
        end
        state.clubConfirmRecover = nil
        result,message = P.ClubsNet.reopen(net,true)
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
        if view == "CLUBS" or view == "SETTINGS" then
            if state.roadReturn then openRoad() else openMenu("FRONT") end
        else openClubs() end
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
        openCreator(state.roadReturn and "story" or nil)
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
        local saved = P.Clubs.savedRoom(state.clubs)
        local value = id=="EDIT_NAME" and state.clubName
            or id=="EDIT_CODE" and (state.clubCode or saved and saved.club.code)
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
            elseif id=="ROAD" then openRoad()
            elseif id=="CAREER" then openCareer()
            elseif id=="CLUBS" then state.roadReturn=nil openClubs()
            elseif id=="ULTIMATE" then openUltimate()
            elseif id=="SETTINGS" then state.roadReturn=nil openClubs("SETTINGS")
            elseif id=="PRACTICE" or id=="MATCH" then openPlay(id)
            elseif id=="HOME" and state.page=="PAUSE" and state.resumePage=="ULTIMATE_MATCH" then openUltimate()
            elseif id=="HOME" and state.page=="PAUSE" and roadPlayPage(state.resumePage) then openRoad()
            elseif id=="MODES" or id=="HOME" then openMenu(id=="HOME" and "FRONT" or id)
            elseif id=="RESUME" and state.resumePage then navigate(state.resumePage)
            elseif id=="STATS" and state.resumePage then
                local play=activePlay(state.resumePage)
                if play then openStats(play.game,"PAUSE") end
            elseif id=="RESET" and state.resumePage then
                local play,controller=activePlay(state.resumePage)
                if play and not play.recorded then resetPlaySession(play,controller,state.resumePage) end
                if play and state.resumePage=="ROAD_PRACTICE" then play.game.clock=play.duration end
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
        if net.revokedRoom then
            local removed,message = P.Clubs.forgetRoom(state.clubs,net.revokedRoom)
            net.revokedRoom = nil
            if not removed then state.clubMessage = message end
        end
        state.clubPlay, state.clubResultID = nil,nil
        if state.page=="CLUB_MATCH" then openClubs("LOBBY") end
        P.ClubsNet.tick(net,dt)
        return
    end
    if net.roomSaveChange ~= net.change then
        net.roomSaveChange = net.change
        local saved,message = P.Clubs.storeRoom(state.clubs,net.session,lobby)
        if not saved then state.clubMessage = message end
    end
    if not state.clubs.joined or state.clubs.joined.code~=lobby.code then
        local joined,message = P.Clubs.joinedTeam(state.clubs,lobby)
        if not joined then
            state.clubMessage=message
            P.ClubsNet.disconnect(net)
            return
        end
    end
    if state.page=="CLUBS" and state.clubView=="JOIN" then
        state.clubView, state.clubPage = "LOBBY",1
    end
    if play and play.matchId~=lobby.matchId then
        play,state.clubPlay = nil,nil
        if state.page=="CLUB_MATCH" then openClubs("LOBBY") end
    end

    if lobby.phase=="match" and net.interruptedMatchId~=lobby.matchId and not play then
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
    elseif lobby.phase=="final" and play and not play.isHost then
        P.ClubsMatch.guestStep(play,dt,net.snapshot)
    end
    local result = lobby.result or lobby.lastResult
    if result and state.clubResultID~=result.matchId and net.checkedResultChange~=net.change then
        net.checkedResultChange=net.change
        local ok,message=P.Clubs.recordOnline(state.clubs,lobby,result,net.session.playerId)
        if ok then state.clubResultID=result.matchId end
        if message then state.clubMessage=message end
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
    if state and state.menuAssets then P.MenuAssets.leave(state.menuAssets) end
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
        local destination=state.page=="ULTIMATE_MATCH" and "ULTIMATE"
            or roadPlayPage(state.page) and "ROAD" or state.page
        openStats(play.game,destination)
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
    if state.page=="ULTIMATE" then
        P.UltimateUI.draw(state.ultimate,dt)
        P.Style.fade(state.pageAge)
        return
    end
    if state.page=="ROAD" then
        P.FreeRoam.draw(state.road.roam,dt)
        return
    elseif state.page=="ROAD_JOURNAL" then
        P.RoadToGlory.drawJournal(state.road)
        return
    elseif state.page=="ROAD_SHOP" then
        P.RoadEquipmentUI.draw(state.road.shop,dt)
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
        if state.page == "ULTIMATE_MATCH" and not play.rewardAttempted then settleUltimate(play) end
        if roadPlayPage(state.page) then
            if not play.captureAttempted then
                local ok,message=P.RoadToGlory.capture(state.road,play)
                if ok~=nil then
                    play.recorded,play.captureAttempted=ok,true
                    if not ok then state.road.message=message or "Could not save this activity. Reenter to retry." end
                    if controller==P.Gameplay then openRoad() return end
                end
            end
        elseif controller==P.Gameplay then updateTrainingReward(play,state.page) end
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
        elseif state.storyCreator then
            P.Athlete.select(athlete,state.profile,selection,index,storyCreatorLocked(),saveStoryPlayer)
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
            elseif state.storyCreator then openRoad()
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
            elseif roadPlayPage(state.page) then openRoad()
            elseif state.page=="CAREER_GAME" then openCareer() else openCreator() end
            return
        end
        if not online and P.UI.hit(hud.reset, touch.x, touch.y) then
            if (state.page == "CAREER_GAME" and play.recorded)
                or ((state.page == "ULTIMATE_MATCH" or roadPlayPage(state.page)) and game.phase == "FINAL")
                or (roadPlayPage(state.page) and play.recorded) then return end
            P.UI.press(hud, hud.reset, touch.id)
            clearPlayInput()
            resetPlaySession(play,controller,state.page)
            if state.page=="ROAD_PRACTICE" then play.game.clock=play.duration end
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
    elseif state.page == "ULTIMATE" then
        local action,boxScore = P.UltimateUI.touch(state.ultimate,touch)
        if action == "HOME" then openMenu("FRONT")
        elseif action == "PLAY" then openUltimateMatch()
        elseif action == "BOX_SCORE" then openStats(boxScore,"ULTIMATE_RECORD") end
    elseif state.page=="ROAD" then
        P.FreeRoam.touch(state.road.roam,touch)
    elseif state.page=="ROAD_JOURNAL" then
        local action=P.RoadToGlory.journalTouch(state.road,touch)
        if action=="BACK" then openRoad()
        elseif action=="PLAYER" then openCreator("story",1) end
    elseif state.page=="ROAD_SHOP" then
        if P.RoadEquipmentUI.touch(state.road.shop,touch)=="BACK" then
            state.road.shop=nil
            openRoad()
        end
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
            "Install the complete PolyLax 3.4.3 Main tab.")
        local modules = PolyLax or {}
        local missing = {}
        for _, name in ipairs({
            "Profile", "TeamUniform", "Character", "AnimationController",
            "CameraController", "GoalPhysics", "Gameplay", "Field", "Midfield", "MatchAI", "FullMatch", "SpecialistShift",
            "Defense", "Faceoff", "MatchRules", "UI", "Career", "CareerUI", "SchoolTeams", "CareerSeason",
            "Passing", "Tactics", "Screens", "Style", "Athlete", "Attributes", "Development", "Statistics", "StatsUI", "League", "Awards", "AwardUI", "Presentation", "Clubs", "ClubsUI", "ClubsMatch", "ClubsNet", "MenuShowcase", "MenuAssets", "Ultimate", "UltimateUI", "UltimateMatch",
            "StoryChapters", "Story", "RoadEquipment", "RoadEquipmentUI", "CampusPeople", "CampusCharacter",
            "CampusMotion", "FreeRoamWorld", "FreeRoamUI", "FreeRoam", "RoadToGlory"
        }) do
            if type(modules[name]) ~= "table" then
                missing[#missing + 1] = name
            end
        end
        assert(#missing == 0, "Missing Codea tabs: " .. table.concat(missing, ", "))
        assert(P.Ultimate.Economy and P.Ultimate.SBC and P.Ultimate.SBCUI,
            "Load UltimateEconomy, UltimateSBC, and UltimateSBCUI after Ultimate.")
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
    end, r.campusHidden)
    part(r, r.body, "neck", m.skin, function(mesh)
        bevel(mesh, 0, .98, .006, .24, .35, .26)
    end)
    part(r, r.body, "collar", m.jerseyTrim, function(mesh)
        rail(mesh, .019, {V(-.15, .863, -.155), V(0, .80, -.208), V(.15, .863, -.155)})
    end, r.campusHidden)
    part(r, r.pelvis, "shorts waist", m.shorts, function(mesh)
        bevel(mesh, 0, .104, .01, .764, .33, .46)
    end, r.campusHidden)
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
    end, r.campusHidden)
    part(r, shoulder, "jersey cuff", m.jerseyTrim, function(mesh)
        box(mesh, 0, -.131, -.171, .21, .034, .025)
    end, r.campusHidden)
    part(r, shoulder, "hoodie upper sleeve", m.hoodie, function(mesh)
        bevel(mesh, 0, -.111, .002, .293, .444, .355)
    end, r.hoodieParts)
    part(r, elbow, "hoodie lower sleeve", m.hoodie, function(mesh)
        bevel(mesh, 0, -.123, 0, .217, .326, .246)
    end, r.hoodieParts)
    part(r, elbow, "elbow pads", m.silver, function(mesh)
        bevel(mesh, 0, -.049, -.105, .231, .20, .107)
        bevel(mesh, 0, -.052, .1, .196, .139, .067)
    end, r.campusHidden)
    r.arms[name].glove = part(r, wrist, "glove shell", m.gloves, function(mesh)
        bevel(mesh, 0, .047, .008, .245, .293, .237)
        bevel(mesh, 0, .128, .001, .267, .101, .234)
    end, r.campusHidden)
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
        armLengthUpper = .33, armLengthLower = .31,
        legLengthUpper = .46, legLengthLower = .44,
        ankleHeight = .14, pelvisHeight = 1.04,
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

local function swingCampusArm(rig, side, phase)
    local joints = rig.joints
    local shoulder = joints[side.."Shoulder"]
    local outer = side=="left" and -.08 or .08
    local target = shoulder.position + vec3(outer,-.59+.07*math.abs(phase),phase*.28)
    solveLimb(shoulder,joints[side.."Elbow"],target,
        rig.armLengthUpper,rig.armLengthLower,vec3(outer,-.10,-1))
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
    if rig.campus then
        base.torso = vec3(-gait*(2+run*5),swing*3,-controller.turn*gait*4)
    elseif rig.stickType == "long" then
        base.grip = vec3(.30 + cradle * .031, .68 + breath * .012 + swing * .025,
            -.38 + swing * .053 + cradle * .028)
        base.shaft = vec3(.52 + cradle * .09, .85 - cradle * .06,
            .11 + swing * .067 + cradle * .036)
        base.roll = cradle * 15 + swing * 6
    elseif rig.stickType == "goalie" then
        base.grip = vec3(.24 + cradle*.019,.62 + breath*.01 + swing*.026,-.40 + swing*.040)
        base.shaft = vec3(.23 + cradle*.067,.96,.17 + swing*.045)
        base.crouch = .10*(1-run)*(.95-controller.carry*.55)
        base.roll = 8 + cradle*12 + swing*5
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
    if rig.campus then
        swingCampusArm(rig,"left",swing)
        swingCampusArm(rig,"right",-swing)
    else
        placeArms(rig, pose, pocketTarget, pocketWeight)
    end
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
    A=1, ATT=1, ATTACK=1, M=2, MID=2, MIDFIELD=2, D=3, DEFENSE=3, ["D-POLE"]=3,
    F=4, FO=4, FOGO=4, FACEOFF=4, G=5, GOALIE=5, KEEPER=5, LSM=6, SSDM=7
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
    if receiver.rig.stickType=="goalie" then extension = receiver.rig.pocket.position.y-.70 end
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
    if not options.useMatchRoster and not practice and P.League and P.League.roster then
        rosters = {P.League.roster(homeId),P.League.roster(awayId)}
    end
    for i, player in ipairs(game.squad) do
        local side = statistics.sides[player.team or 1]
        local id = player.statId or stablePlayerId(side.id, player.slot or i, practice)
        local rosterPlayer = not player.statId and rosters and rosters[player.team or 1][player.slot or i] or player
        local shift = game.specialistShift
        if shift and i==shift.slot then rosterPlayer = shift.idle end
        local line = register(statistics,side,id,rosterPlayer)
        if not (shift and i==shift.slot) then line.number = player.number or line.number end
        statistics.entries[i] = {actor=line, team=player.team or 1}
        if i == created and not options.useMatchRoster then
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
    if entry.profile and not game.careerWaiting and not game.careerOnBench then return entry.profile, entry.team end
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
    if not data.saved and not (options and options.persist == false)
        and not (game.statisticsOptions and game.statisticsOptions.persist == false) then
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
    Character.setStickType(game.goalie,"goalie")
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
    return player.role == "M" or player.role == "FOGO" or player.role == "LSM" or player.role == "SSDM"
end

local function humanControls(match, id)
    if match.humans then return match.humans[id] ~= nil end
    return id == match.controlled and not match.careerWaiting and not match.careerOnBench
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
        local human = not (match.careerWaiting or match.careerOnBench) and match.squad[match.controlled]
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
        local catchable = velocity:len() <= maxCatchSpeed
        consider(head, gap + hands*.09, catchable)
        local stick = keeper.rig.stickRoot
        if stick then
            if keeper.stickType=="goalie" then
                for _, side in ipairs({-1,1}) do
                    consider(stick:transformPoint(vec3(side*.218,.88,-.10)),.16+hands*.035,catchable)
                end
                consider(stick:transformPoint(vec3(0,1.11,-.134)),.14,catchable)
            end
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

-- SpecialistShift
do
-- Career specialists exchange with a reserve through the midfield sideline.
PolyLax = PolyLax or {}
local P = PolyLax
local Shift = {}
P.SpecialistShift = Shift

local fields = {"rig","anim","role","name","number","stickType","attributes","stamina","runningFatigue"}

local function park(game, idle, z)
    idle.rig.root.position = vec3(game.field.halfWidth+1.25,0,z)
    idle.rig.root.eulerAngles = vec3(0,-90,0)
    P.AnimationController.reset(idle.anim)
end

function Shift.new(game, scene, style, appearance)
    local specialist = game.squad[game.careerPlayer]
    if not specialist or (style~="faceoff" and style~="defense") then return end
    local taken = {}
    for _, index in ipairs(game.teams[specialist.team]) do taken[game.squad[index].number] = true end
    local number = 91
    while taken[number] do number = (number+1)%100 end
    appearance.NUMBER = number+1
    local rig = P.Character.new(scene)
    P.Character.apply(rig,appearance,nil,game.kits[specialist.team],false)
    local idle = {rig=rig,anim=P.AnimationController.new(rig),role="M",name="Shift Midfielder",
        number=number,stickType="short",attributes=P.Attributes.forPosition("M"),stamina=1,runningFatigue=0}
    local shift = {slot=specialist.id, style=style, idle=idle, ready=1.4}
    park(game,idle,game.field.midfieldZ or 0)
    return shift
end

local function exchange(game, shift, atGate)
    local player, idle = game.squad[shift.slot], shift.idle
    for _, key in ipairs(fields) do player[key],idle[key] = idle[key],player[key] end
    game.careerOnBench = not game.careerOnBench
    if atGate then
        player.x = game.field.halfWidth-.30
        player.vx,player.vz,player.speed,player.turn,player.yaw = 0,0,0,0,-90
        player.rig.root.position = vec3(player.x,0,player.z)
        player.rig.root.eulerAngles = vec3(0,player.yaw,0)
        P.AnimationController.reset(player.anim)
    end
    park(game,idle,atGate and player.z or game.field.midfieldZ or 0)
    shift.going, shift.gateZ = nil,nil
    shift.ready = game.elapsed+1.4
end

function Shift.faceoff(game)
    local shift = game.specialistShift
    if not shift then return end
    if game.careerOnBench then exchange(game,shift,false) end
    shift.going, shift.gateZ = nil,nil
    shift.ready = game.elapsed+1.4
end

local function involved(play, index)
    return play and (play.from==index or play.to==index or play.interceptor and play.interceptor.id==index)
end

function Shift.plan(game, intents, dt)
    local shift = game.specialistShift
    if not shift then return end
    local player = game.squad[shift.slot]
    P.AnimationController.update(shift.idle.anim,dt,{})
    local carrier = game.squad[game.carrier]
    local passing = game.flight and game.flight.kind=="pass" and game.flight.to and game.flight.team
    local possession = carrier and carrier.team or passing
    local clear = possession and carrier~=player and not game.careerWaiting and not game.faceoffScramble
        and not player.dodge and not player.check and not player.anim.action and game.scoopPlayer~=player.id
        and not involved(game.pending,player.id) and not involved(game.flight,player.id)
        and not (game.screen and game.screen.screener==player.id)
    local returning = game.careerOnBench and shift.style=="defense" and possession~=player.team
    local leaving = not game.careerOnBench and (shift.style=="faceoff" or possession==player.team)
    if not clear or not (returning or leaving) or game.elapsed<shift.ready then
        shift.going, shift.gateZ = nil,nil
        return
    end
    if not shift.going then
        local middle = game.field.midfieldZ or 0
        local side = P.Midfield.side(game,player)
        local attacking = player.team==1 and -1 or 1
        local direction = side=="offense" and attacking or -attacking
        shift.going, shift.gateZ = true,middle+direction*2.15
    end
    intents[shift.slot] = {
        x=game.field.halfWidth+.39,z=shift.gateZ,speed=7.65,role="SUBSTITUTION",
        shiftGate=true
    }
end

function Shift.complete(game)
    local shift = game.specialistShift
    if not shift or not shift.going then return end
    local player = game.squad[shift.slot]
    if game.carrier==player.id or involved(game.pending,player.id) or involved(game.flight,player.id) then return end
    local assist = game.assist
    if assist and assist.from==player.id and game.elapsed-assist.at<=4.8 then return end
    if player.x < game.field.halfWidth+.06 or math.abs(player.z-shift.gateZ)>.34 then return end
    local candidate = {team=player.team,role=shift.idle.role}
    if not P.Midfield.canSubstitute(game,player.team,player.id,candidate,player.z) then return end
    exchange(game,shift,true)
    return true
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

local function careerOffField(match, index)
    return index == match.careerPlayer and (match.careerWaiting or match.careerOnBench)
end

function Match.recordStat(match, index, key, amount, detail)
    local player = match.squad[index]
    if not player then return end
    local team = match.stats[player.team]
    local increment = amount or 1
    if not careerOffField(match,index) then
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
    if careerOffField(match,index) then return end
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
    return index == match.controlled and not careerOffField(match,index)
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
    if match.specialistShift then P.SpecialistShift.faceoff(match) end
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
    if match.specialistShift then P.SpecialistShift.faceoff(match) end
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
    if match.teamOverride then
        local teams = match.teamOverride
        match.homeTeam, match.awayTeam = teams[1], teams[2]
        match.homeId, match.awayId = teams[1].id, teams[2].id
        match.kits = {teams[1].kit, teams[2].kit}
        return
    end
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
            local personal = Match.careerAthlete(match) or player
            P.Character.apply(personal.rig, profile, nil, kit, false)
            personal.number = personal.rig.numberValue
            if personal~=player then P.Character.applyUniform(player.rig,kit,false) end
        else
            P.Character.applyUniform(player.rig, kit, false)
        end
    end
    if match.specialistShift and not match.careerOnBench then
        P.Character.applyUniform(match.specialistShift.idle.rig,match.kits[1],false)
    end
end

function Match.careerAthlete(match)
    if match.careerOnBench then return match.specialistShift.idle end
    return match.squad[match.careerPlayer]
end

local midfieldRoles = {FO="FOGO",FOGO="FOGO",FACEOFF="FOGO",LSM="LSM",SSDM="SSDM"}

function Match.new(scene, profile, homeId, awayId, rules)
    rules = rules or {}
    local settings = P.MatchRules.configure(rules)
    local venue = P.TeamUniform.get(rules.fieldTeam or homeId)
    local field = P.Field.new(scene, rules.fieldTheme or venue.field, settings.fieldMetrics)
    local homeGoal = field.goals[1]
    local match = {
        field=field, venueAway=rules.venueAway == true, goalsByTeam=field.goals, goal=vec3(homeGoal.x, homeGoal.top * .5, homeGoal.z),
        ball=makeBall(scene), marker=makeMarker(scene), squad={}, teams={{},{}}, keepers={}, rules=settings
    }
    match.humans, match.playerId = rules.humans, rules.playerId
    match.statisticsOptions = rules.statistics
    match.teamOverride = rules.teams
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
        local lineup = rules.lineups and rules.lineups[team]
        local roster = not lineup and P.League and P.League.roster(team==1 and match.homeId or match.awayId)
        local specialistPole = false
        for slot, spec in ipairs(formation) do
            local index = #match.squad + 1
            local rig = P.Character.new(scene)
            local human = match.humans and match.humans[index]
            local custom = human or not lineup and not match.humans and index==(match.careerPlayer or userPlayer)
            local selected = lineup and lineup[slot] or rules.teammates and team==1 and rules.teammates[slot]
            local appearance = human and human.appearance or custom and profile or playerProfile(team,slot)
            local member = selected or roster and roster[slot]
            local role = spec[1]
            local chosenRole = human and human.role or selected and selected.role
                or index == match.careerPlayer and rules.careerPlayerRole
            if role == "M" then
                role = midfieldRoles[chosenRole] or (slot==4 and not chosenRole and "FOGO") or role
            end
            local long = role == "D" and slot-6 <= settings.maxLongPoles
                or role == "LSM" and settings.maxLongPoles >= 4 and not specialistPole
            if role == "LSM" and long then specialistPole = true end
            P.Character.setStickType(rig, role=="G" and "goalie" or long and "long" or "short")
            if member and member.number and not custom then appearance.NUMBER=member.number+1 end
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
            if selected then
                player.statId, player.cardUID, player.temporaryAI = selected.statId, selected.cardUID, selected.temporaryAI
                for key, value in pairs(selected.attributes or {}) do player.attributes[key] = value end
            end
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
    if rules.careerShift and match.careerPlayer then
        match.specialistShift = P.SpecialistShift.new(match,scene,rules.careerShift,playerProfile(1,match.careerPlayer))
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
    if match.careerWaiting or match.careerOnBench or match.specialistShift and match.specialistShift.going then return end
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

local function proposeMovement(match, player, vx, vz, dt, proposal, shiftGate)
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
    local rightLimit = shiftGate and field.halfWidth+.4 or .987*field.halfWidth
    local targetX = clamp(x + (player.vx + dx * speedup) * dt, -.987 * field.halfWidth, rightLimit)
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
    local humanID = not careerOffField(match,match.controlled) and match.controlled
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
        if not (intent.screenControl or intent.shiftGate) then
            if receiveX then
                tx,tz = receiveX,receiveZ
            elseif cut and cut.cutID==player.id and not match.pending then
                tx,tz = cut.cutX,cut.cutZ
            end
        end
        local guided = not match.humans and (receiveX or (cut and cut.cutID==player.id and not match.pending))
        local vx,vz = 0,0
        if human and not intent.screenControl and not intent.shiftGate and (not guided or distance(inputX,inputZ)>.12) then
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
        proposeMovement(match,player,vx,vz,dt,proposals[player.id],intent.shiftGate)
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
        local localBox = match.humans or match.statisticsOptions and match.statisticsOptions.persist == false
        P.Statistics.finalize(match,localBox and {persist=false} or nil)
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
    if match.specialistShift then P.SpecialistShift.plan(match,intents,dt) end
    act(match, intents)
    P.Passing.scheduleCatch(match,match.flight,dt)
    if match.flight then P.Defense.prepareIntercept(match, match.flight) end
    if match.loose and not (match.careerWaiting or match.careerOnBench) then
        if match.humans then
            for _, player in ipairs(match.squad) do
                if humanControls(match,player.id) then startScoop(match,player) end
            end
        else
            startScoop(match, match.squad[match.controlled])
        end
    end
    movePlayers(match, dt, moveX, moveZ, intents)
    if match.specialistShift and P.SpecialistShift.complete(match) then
        announce(match,match.careerOnBench and "SUBSTITUTED · ON THE BENCH" or "YOUR SHIFT",2)
    end
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
        and holder and offender.team == holder.team and not careerOffField(match,offender.id) then
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
-- PolyLax | Shared menu treatments and pause overlays
PolyLax = PolyLax or {}
local Style = {}
PolyLax.Style = Style

local palette = {
    deep=color(9,13,19), graphite=color(21,28,38), body=color(26,34,46),
    inset=color(15,21,29), steel=color(57,73,91), rim=color(80,98,117),
    muted=color(164,180,197), white=color(245,249,254), blue=color(38,137,75),
    glow=color(118,228,153), red=color(235,73,93), amber=color(253,206,100)
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
local panelActive = color(21,92,52)
function Style.panel(x, y, w, h, active, radius)
    radius = radius or 12
    Style.rounded(x,y-2,w,h,radius,panelShadow)
    Style.rounded(x,y,w,h,radius,active and palette.blue or palette.steel)
    Style.rounded(x,y,w-2,h-2,math.max(0,radius-1),active and panelActive or palette.body)
end

local choices = {
    FRONT = {
        {id="ROAD", title="Road to Glory", detail="Explore campus and play Brothers in Arms", prominent=true},
        {id="MODES", title="Quick Play", detail="Practice or play a full match", prominent=true},
        {id="CAREER", title="Be a Pro", detail="Develop your single-player career"},
        {id="ULTIMATE", title="Ultimate Team", detail="Build a squad and compete", icon="ultimate"},
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
    local front = page == "FRONT"
    local row = pause and math.min(53,room*.115) or front and math.min(66,room*.102)
        or math.min(76,room*.142)
    local gap = pause and 9 or front and math.min(9,room*.016) or 12
    local stack = #list*row + (#list-1)*gap
    local firstTop
    if pause then
        local paneHeight = stack+87
        dashboard.overlay = {x=x,y=(top+bottom)*.5,w=w+16,h=paneHeight}
        dashboard.titleY = dashboard.overlay.y+paneHeight*.5-34
        firstTop = dashboard.titleY-31
    elseif page == "FRONT" then
        firstTop = bottom+stack+16
        dashboard.titleY = (top+firstTop)*.5
        dashboard.logoHeight = math.min(120,(top-firstTop)*.84)
    else
        local reserve = math.min(147,room*.30)
        firstTop = math.max(bottom+stack+20,top-reserve)
        dashboard.titleY = (top+firstTop)*.5
    end
    for index, choice in ipairs(list) do
        local enabled = choice.id ~= "STATS" or options and options.statsEnabled == true
        if choice.id == "RESET" and options and options.resetEnabled == false then enabled=false end
        if choice.id == "CREATOR" and options and options.roadPause then enabled=false end
        local y = firstTop-row*.5-(index-1)*(row+gap)
        local item = hitbox(choice.id,x,y,w,row,choice,enabled == true)
        if choice.id == "HOME" and options and options.ultimatePause then item.label="Ultimate Team" end
        if choice.id == "HOME" and options and options.roadPause then item.label="Return to Campus" end
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
local blueTop = color(24,110,62)
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
    local colorRim = item.prominent and palette.glow or item.icon=="ultimate" and palette.amber
        or item.icon and palette.rim
        or item.enabled and palette.steel or palette.inset
    local x,y,w,h = item.x,item.y,item.w,item.h
    Style.rounded(x,y-3,w,h,13,cardShadow,s)
    Style.rounded(x,y,w,h,13,colorRim,s)
    Style.rounded(x,y,w-2,h-2,12,colorTop,s)
    if item.prominent then Style.rounded(x-w*.5+12,y,3,h*.54,1.5,palette.glow) end
    local left = x-w*.5+27
    local maxLabelWidth = w-75
    if item.icon == "clubs" then
        Style.rounded(left+6,y,37,37,10,palette.inset)
        Style.clubsIcon(left+6,y,36,palette.glow)
        left,maxLabelWidth = left+33,maxLabelWidth-33
    elseif item.icon == "ultimate" then
        Style.rounded(left+6,y,37,37,10,palette.inset)
        Style.rounded(left+6,y-1,17,23,4,palette.amber)
        Style.rounded(left+6,y+1,13,18,3,palette.inset)
        Style.rounded(left+6,y+3,8,2,1,palette.amber)
        Style.rounded(left+6,y-2,6,2,1,palette.amber)
        left,maxLabelWidth = left+33,maxLabelWidth-33
    end
    local fg = item.enabled and palette.white or disabled
    label(item.label,left,y+(item.detail and 9 or 0),item.prominent and 19 or 16,fg,true,maxLabelWidth)
    if item.detail then label(item.detail,left,y-12,11,item.prominent and palette.white or palette.muted,true,maxLabelWidth) end
    if item.enabled then
        local arrowX = x+w*.5-18
        stroke(item.prominent and palette.white or item.icon=="ultimate" and palette.amber or palette.glow)
        strokeWidth(2)
        line(arrowX-4,y+4,arrowX,y)
        line(arrowX,y,arrowX-4,y-4)
        noStroke()
    end
end

function Style.screen(page, l, elapsed, showcase, menuAssets)
    page = l.page or page
    if page ~= "PAUSE" and not showcase then background(palette.deep) end
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
        if showcase then
            fill(8,14,26,53)
            rect(WIDTH*.5,HEIGHT*.5,WIDTH,HEIGHT)
            local panelTop = l.buttons[1].y + l.buttons[1].h*.5 + 19
            fill(8,14,26,96)
            rect(WIDTH*.5,panelTop*.5,WIDTH,panelTop)
        else
            fieldMarks(l)
        end
        local logoHeight = l.logoHeight or math.min(115,(l.top-l.titleY)*1.38)
        local hasLogo = menuAssets and PolyLax.MenuAssets.drawLogo(menuAssets,l.x,l.titleY,l.w*.94,logoHeight)
        local tempo = .5+.5*math.sin((elapsed or 0)*1.6)
        if not hasLogo then
            local title = page == "FRONT" and "POLYLAX 3.4.3" or "Play Modes"
            local size = page == "FRONT" and math.min(48,l.w*.164) or 30
            font("AvenirNext-HeavyItalic")
            if showcase then label(title,l.x+1,l.titleY+7,size,palette.deep,false,l.w) end
            label(title,l.x,l.titleY+9,size,palette.white,false,l.w)
            font("AvenirNext-DemiBold")
            Style.rounded(l.x,l.titleY-25,41+tempo*7,2,1,palette.glow)
        end
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
    local tacticalHeight = 40
    local controlBase = footer+tacticalHeight+8
    local diameter = math.min(69,width*.21)
    local bX = right-diameter*.5-2
    local aX = bX-diameter-6
    local joyMaxX = left+math.min(width*.31,104)
    local joyX = (left+joyMaxX)*.5
    local joyRadius = math.min(43,(joyMaxX-left)*.44)
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
    if game.careerWaiting or game.careerOnBench or game.specialistShift and game.specialistShift.going
        or id == "switch" and game.careerPlayer then return nil end
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
        local athlete = game.squad[game.controlled]
        if athlete and athlete.role=="G" and id~="switch" then return nil end
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

local primaryBlue = color(22,130,65,248)
local primaryBlueLight = color(43,177,92,244)
local primaryBlueDark = color(23,66,42,227)
local primaryRed = color(181,49,49,248)
local primaryRedLight = color(231,76,76,244)
local primaryRedDark = color(81,37,37,227)
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
    if item.id == "dodge" or item.id == "setpick" then
        local key = item.id == "dodge" and "X" or "Y"
        local tint = item.id == "dodge" and color(38,120,205) or color(218,168,37)
        ellipseMode(CENTER)
        fill(tint)
        ellipse(item.x-item.w*.5+9,item.y+item.h*.5-3,16)
        label(key,item.x-item.w*.5+9,item.y+item.h*.5-3,9,white)
    end
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
    label(item.primary,item.x,item.y+7,25,action and white or muted)
    label(textValue,item.x,item.y-14,item.w < 51 and 8 or 10,action and white or muted)
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
        local message = game.clubsStatus
            or game.specialistShift and game.specialistShift.going and "SIDELINE EXCHANGE"
            or game.careerOnBench and game.phase=="LIVE" and "ON THE BENCH"
            or game.careerWaiting and game.phase == "LIVE" and "FIRST SHIFT SOON"
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
    {label="Attack (ATT)", slot=1, role="A", stick="short"},
    {label="Midfielder (MID)", slot=5, role="M", stick="short"},
    {label="Defense (D-Pole)", slot=7, role="D", stick="long"},
    {label="Faceoff Specialist (FOGO)", slot=4, role="FOGO", stick="short", shift="faceoff"},
    {label="Goalie (G)", slot=10, role="G", stick="goalie"},
    {label="Long-Stick Midfielder (LSM)", slot=5, role="LSM", stick="long", shift="defense"},
    {label="Short-Stick Defensive Midfielder (SSDM)", slot=6, role="SSDM", stick="short"}
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
    local assignment = position(career.position)
    local ruleset = ({highSchool="highSchool",ncaa="ncaa",club="collegeClub",
        professional="professional"})[home.fieldType] or "arcade"
    return {name="Career short game", profile=ruleset, periods=2, periodLength=60, intermissionTime=2,
        ageGroup=age, bodyContact=age == "highSchool" or age == "adult",
        faceoffDifficulty=career.stage == "professional" and "HARD" or "NORMAL",
        careerEntryDelay=(assignment.role=="FOGO" or P.CareerSeason.status(career).starter) and 0 or 4,
        fieldTeam=fixture.home and career.team or fixture.opponent, venueAway=not fixture.home,
        careerPlayerSlot=assignment.slot, careerPlayerRole=assignment.role, careerShift=assignment.shift,
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

local function roomCode(value)
    if type(value) == "string" then
        local code = value:upper()
        if #code == 8 and code:match("^[A-Z0-9]+$") then return code end
    end
end

local function assignedClub(lobby)
    if type(lobby) ~= "table" or not P.Career.stages[lobby.stage] or not teamFor(lobby.stage, lobby.team) then return end
    local code = roomCode(lobby.code)
    local name = clean(lobby.name, Clubs.nameLimit)
    if code and name ~= "" then
        return {code=code, name=name, stage=lobby.stage, team=lobby.team, season=1}
    end
end

local function roomKey(relay, code)
    return relay and code and relay.."|"..code
end

local function restoreRoom(record)
    if type(record) ~= "table" then return end
    local relay, club = relayURL(record.relayURL), assignedClub(record.club)
    local session = record.session
    if not relay or not club or type(session) ~= "table" or roomCode(session.roomCode) ~= club.code
        or not P.ClubsNet or not P.ClubsNet.validSession(session) then return end
    return {relayURL=relay, club=club, host=record.host==true,
        session={roomCode=club.code, token=session.token, playerId=session.playerId}}
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
        online=data.online, rooms=data.rooms, activeRooms=data.activeRooms}
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

    local data = {version=version, player=restorePlayer(saved and saved.player), settings={},
        rooms={}, activeRooms={}}
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
    if saved and type(saved.rooms) == "table" then
        for _, value in pairs(saved.rooms) do
            local room = restoreRoom(value)
            if room then data.rooms[roomKey(room.relayURL,room.club.code)] = room end
        end
    end
    if saved and type(saved.activeRooms) == "table" then
        for relay, code in pairs(saved.activeRooms) do
            if relayURL(relay) and roomCode(code) and data.rooms[roomKey(relay,code)] then
                data.activeRooms[relay] = code
            end
        end
    end
    local room = Clubs.savedRoom(data)
    if room then Clubs.joinedTeam(data,room.club) end
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
    local room = Clubs.savedRoom(data)
    Clubs.joinedTeam(data,room and room.club)
    return true
end

function Clubs.savePlayer(data, player)
    if player.id ~= data.player.id then return false end
    local club = data.club
    if club and (player.team ~= club.team or player.stage ~= club.stage or player.season ~= club.season) then
        return false
    end
    local candidate = {player=player, club=club, settings=data.settings, online=data.online,
        rooms=data.rooms, activeRooms=data.activeRooms}
    if not Clubs.save(candidate) then return false end
    replace(data.player, player)
    return true
end

local function placePlayer(data, club, stage, team)
    local player = copy(data.player)
    local season = club and club.season or player.season
    player.stage, player.team, player.season = stage, team, season
    local candidate = {player=player, club=club, settings=data.settings, online=data.online,
        rooms=data.rooms, activeRooms=data.activeRooms}
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

function Clubs.savedRoom(data, code)
    local relay = data.settings.relayURL
    local chosen = code and roomCode(code) or not code and data.activeRooms and data.activeRooms[relay]
    local key = roomKey(relay,chosen)
    return key and data.rooms and data.rooms[key] or nil
end

function Clubs.hostedRoom(data)
    local relay = data.settings.relayURL
    for _, room in pairs(data.rooms or {}) do
        if room.host and room.relayURL == relay then return room end
    end
end

function Clubs.storeRoom(data, session, lobby)
    local room = restoreRoom({relayURL=data.settings.relayURL, session=session, club=lobby,
        host=type(session)=="table" and type(lobby)=="table" and lobby.hostId==session.playerId})
    if not room then return false, "The relay did not return valid room credentials" end
    local assigned
    for _, member in ipairs(lobby.players or {}) do
        if member.id == session.playerId and type(member.profile) == "table" and member.profile.id == data.player.id then
            assigned = member
            break
        end
    end
    if not assigned then return false, "This Clubs room is assigned to another athlete" end
    local previous = Clubs.savedRoom(data,room.club.code)
    local active = data.activeRooms and data.activeRooms[room.relayURL]
    if previous and previous.session.token == session.token and previous.session.playerId == session.playerId
        and previous.host == room.host and previous.club.name == room.club.name
        and previous.club.team == room.club.team and previous.club.stage == room.club.stage
        and active == room.club.code then return true end

    local candidate = copy(data)
    candidate.rooms, candidate.activeRooms = candidate.rooms or {}, candidate.activeRooms or {}
    candidate.rooms[roomKey(room.relayURL,room.club.code)] = room
    candidate.activeRooms[room.relayURL] = room.club.code
    if not Clubs.save(candidate) then return false, "Could not save this club's room credentials" end
    data.rooms, data.activeRooms = candidate.rooms,candidate.activeRooms
    return true
end

function Clubs.forgetRoom(data, code)
    local room = Clubs.savedRoom(data,code)
    if not room then return true end
    local candidate = copy(data)
    candidate.rooms[roomKey(room.relayURL,room.club.code)] = nil
    if candidate.activeRooms[room.relayURL] == room.club.code then candidate.activeRooms[room.relayURL] = nil end
    if not Clubs.save(candidate) then return false,"Could not remove the expired room session" end
    data.rooms, data.activeRooms = candidate.rooms,candidate.activeRooms
    if data.joined and data.joined.code==room.club.code then Clubs.joinedTeam(data,nil) end
    return true
end

function Clubs.joinedTeam(data, lobby)
    if lobby == nil then data.joined = nil return true end
    local remote = assignedClub(lobby)
    if not remote then return false, "The relay returned an invalid team" end
    local localClub = data.club
    if localClub and localClub.stage == remote.stage and localClub.team == remote.team then
        remote.season = localClub.season
    end
    -- Joining changes the displayed club. Keep the saved club and athlete intact.
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
    if not remote or type(result) ~= "table" then
        return false, "No completed Clubs match"
    end
    local id = result.matchId
    local final = lobby.phase=="final" and id==lobby.matchId or result==lobby.lastResult
    if not final or type(id) ~= "string" or #id > 72 or not id:match("^[A-Za-z0-9_%-]+$") then
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
    local gap = 10
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
    stack(layout,rows,53)
end

local screens = {}

function screens.CLUBS(layout, data, options)
    local club = options.lobby or options.savedRoom and options.savedRoom.club or data.club
    local player = data.player or {}
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
    stack(layout,rows,62)
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
        item("CREATOR","Player Creator",options.campusReturn and "Customize your Road to Glory athlete"
            or "Customize the Quick Play athlete"),
        item("EDIT_RELAY","Clubs relay server",field(options,"EDIT_RELAY",relay,"Set the online server address")),
        item("MENU_MUSIC",options.menuMuted and "Menu Music Off" or "Menu Music On",
            options.hasMenuTheme and "Tap to change" or "Main_Menu_Melody unavailable")
    },68)
end

function screens.ROSTER(layout, data, options)
    if options.savedRoom and not options.lobby then
        pageList(layout,{},rosterRow,"Reconnect to view the current room roster.",options)
        return
    end
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
        local saved, hosted = options.savedRoom, options.hostedRoom
        local club = saved and saved.club or data.club
        local description = saved and ("Permanent room code   "..saved.club.code) or "Set up your online club"
        clubStamp(layout,club and club.name or "Club Lobby",description)
        local rows = {}
        if saved then
            rows[#rows+1] = item("RESUME_ROOM","Reconnect to Room",nil,options.canReconnect==true,true)
        end
        if not saved or data.club and hosted ~= saved then
            rows[#rows+1] = item("HOST_ONLINE",hosted and "Open My Club" or "Host Online",
                hosted and ("Permanent room code   "..hosted.club.code) or "Get a permanent invitation code",
                options.hostEnabled==true,not saved)
        end
        stack(layout,rows,62)
        if not options.message and not relayURL(data,options) then
            layout.message="Set a relay server address in Settings to host online."
        end
        return
    end
    local code = lobby.code
    local description = code and code~="" and ("Room code   "..code) or "Connecting to the relay"
    local status
    if lobby.phase=="final" and lobby.result then
        status=string.format("Final score   %d–%d",lobby.result.homeScore,lobby.result.awayScore)
    end
    clubStamp(layout,lobby.name or data.club and data.club.name or "Club Lobby",description,status)
    local y = layout.floor+19
    if lobby.phase=="match" and options.interrupted then
        local label=options.confirmRecovery and "Confirm Match Reset" or "Recover Interrupted Lobby"
        place(layout,item("RECOVER_ROOM",label,nil,options.canRecover==true,true),layout.x,y,layout.w,38)
    elseif lobby.phase=="match" then
        place(layout,item("RESUME_MATCH","Return to Match",nil,options.canResume==true,true),layout.x,y,layout.w,38)
    elseif lobby.phase=="final" then
        if options.host then
            local width=(layout.w-8)*.5
            place(layout,item("REOPEN_ROOM","Reopen Lobby",nil,options.canReopen==true,true),
                layout.x-width*.5-4,y,width,38)
            place(layout,item("LEAVE","Disconnect"),layout.x+width*.5+4,y,width,38)
        else
            place(layout,item("LEAVE","Disconnect"),layout.x,y,layout.w,38)
        end
    else
        local width = (layout.w-12)/3
        place(layout,item("READY",options.ready and "Unready" or "Ready",nil,options.canReady==true),
            layout.x-width-6,y,width,38)
        place(layout,item("START","Start Game",nil,options.canStart==true,true),layout.x,y,width,38)
        place(layout,item("LEAVE","Disconnect"),layout.x+width+6,y,width,38)
    end
    layout.floor=layout.floor+45
    pageList(layout,options.roster or lobby.members or {},rosterRow,"Waiting for players",options)
end

function ClubsUI.layout(view, data, options)
    view=heading[view] and view or "CLUBS"
    options,data=options or {},data or {}
    local safe=P.UI.safeArea()
    local width=math.min(452,WIDTH-safe.left-safe.right-34)
    local x=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-12,safe.bottom+12
    local layout={view=view,title=heading[view],top=top,bottom=bottom,x=x,w=width,
        cursor=top-58,floor=bottom+26,rows={},buttons={},byId={},message=options.message}
    local campus=options.campusReturn and (view=="CLUBS" or view=="SETTINGS")
    local backWidth=campus and 142 or 60
    layout.titleInset=backWidth+16
    local back=place(layout,item("BACK",campus and "Return to Campus" or "Back"),
        x-width*.5+backWidth*.5,top-21,backWidth,36)
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
    style.panel(row.x,row.y,row.w,row.h,row.primary and row.enabled,14)
    local ink = row.enabled and p.white or p.muted
    if row.compact or row.id=="PREV_PAGE" or row.id=="NEXT_PAGE"
        or row.id=="READY" or row.id=="START" or row.id=="LEAVE" then
        textAt(row.label,row.x,row.y,13,ink,row.w-10)
        return
    end
    local left = row.x-row.w*.5+19
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
    textAt(layout.title,layout.x-layout.w*.5+layout.titleInset,layout.top-21,23,p.white,layout.w-layout.titleInset,true)
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

function Net.validSession(session)
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
    connection.restoring, connection.interruptedMatchId, connection.resumeRequest = nil, nil, nil
    connection.notice = nil
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
        if Net.validSession(reply.session) then connection.session = reply.session end
        if connection.interruptedMatchId ~= lobby.matchId then connection.interruptedMatchId = nil end
        if connection.restoring and lobby.phase=="match" and Net.isHost(connection) then
            connection.interruptedMatchId = lobby.matchId
        end
        connection.restoring = nil
    else
        return false
    end
    if operation ~= "leave" and not connection.session then return false end
    if type(reply.inputSeq) == "number" then
        connection.inputSeq = math.max(connection.inputSeq, reply.inputSeq)
    end
    local snapshot = reply.snapshot
    if type(snapshot) == "table" and type(snapshot.seq) == "number" and connection.lobby
        and (not snapshot.matchId or snapshot.matchId == connection.lobby.matchId)
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
            if operation == "resume" then connection.resumeRequest = nil end
            if status == 401 and connection.session then
                connection.revokedRoom = connection.session.roomCode
                clearSession(connection)
            end
            if operation == "sync" then
                connection.pendingInput = nil
                -- A playing client may still have input in flight when the
                -- host finishes. Fetch the new phase without stale match data.
                connection.refreshLobby = status == 409 and (payload.input ~= nil or payload.snapshot ~= nil)
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
            if operation == "resume" then connection.resumeRequest = nil end
            if type(reply.profileError) == "string" then
                connection.notice = reply.profileError:gsub("%c"," "):sub(1,140)
            end
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
    if authenticated and not Net.validSession(connection.session) then return false, "Join a room first." end
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

function Net.resume(connection, session, profile)
    if not connection.url then return false, connection.error end
    if not Net.validSession(session) then return false, "No saved Clubs room." end
    if connection.inFlight or connection.command then return false, "Wait for the current request." end
    if connection.session and connection.session.token ~= session.token then return false, "Disconnect from your current room first." end
    if not connection.session or session.token ~= connection.session.token then clearSession(connection) end
    connection.session = {token=session.token, playerId=session.playerId, roomCode=session.roomCode}
    connection.restoring = not connection.lobby
    connection.notice = nil
    connection.resumeRequest = {profile=profile}
    return command(connection, "resume", connection.resumeRequest, true)
end

function Net.ready(connection, ready)
    return command(connection, "ready", {ready=ready == true,
        revision=connection.lobby and connection.lobby.revision}, true)
end

function Net.start(connection)
    return command(connection, "start", {revision=connection.lobby and connection.lobby.revision}, true)
end

function Net.reopen(connection, abandon)
    if not Net.isHost(connection) then return false, "Only the host can reopen the lobby." end
    local lobby = connection.lobby
    if not lobby.matchId or lobby.phase ~= (abandon and "match" or "final") then
        return false, "This lobby cannot be reopened right now."
    end
    return command(connection, "reopen", {matchId=lobby.matchId,abandon=abandon==true}, true)
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
        if connection.resumeRequest then
            request(connection,"resume",connection.resumeRequest)
            return
        end
        local payload = {}
        if Net.isHost(connection) then
            payload.after = connection.after
            if playing and not connection.refreshLobby then payload.snapshot = exchange.snapshot end
        elseif playing and not connection.refreshLobby then
            payload.input = buildInput(connection)
        end
        if payload.input or payload.snapshot then payload.matchId = connection.lobby.matchId end
        connection.refreshLobby = nil
        request(connection, "sync", payload)
    end
end
end

-- MenuAssets
do
-- Optional project art and audio for the front menu.
PolyLax = PolyLax or {}
local MenuAssets = {}
PolyLax.MenuAssets = MenuAssets

local muteKey = "PolyLax.MenuMusicMuted.1"

local function optional(call, ...)
    local ok, value = pcall(call, ...)
    if ok then return value end
end

local function field(value, name)
    if value == nil then return nil end
    return optional(function() return value[name] end)
end

function MenuAssets.load()
    local saved = optional(readLocalData, muteKey)
    local logoKey = optional(function() return asset.logo end)
    local logo
    if logoKey then logo = optional(readImage, logoKey) end
    local width, height = field(logo, "width"), field(logo, "height")
    if type(width) ~= "number" or width <= 0 or type(height) ~= "number" or height <= 0 then
        logo, width, height = nil, nil, nil
    end
    local theme = optional(function() return asset.Main_Menu_Melody end)
    return {
        logo=logo, logoWidth=width, logoHeight=height,
        theme=theme, hasTheme=theme ~= nil, muted=saved == true or saved == 1
    }
end

function MenuAssets.drawLogo(menu, x, y, maxWidth, maxHeight)
    if not menu or not menu.logo or maxWidth <= 0 or maxHeight <= 0 then return false end
    local scale = math.min(maxWidth / menu.logoWidth, maxHeight / menu.logoHeight)
    pushStyle()
    local drawn = pcall(function()
        spriteMode(CENTER)
        noTint()
        sprite(menu.logo, x, y, menu.logoWidth * scale, menu.logoHeight * scale)
    end)
    popStyle()
    if not drawn then menu.logo = nil end
    return drawn
end

local function trackName()
    local name = field(music, "name")
    if type(name) == "string" and name ~= "" then return name end
end

function MenuAssets.enter(menu)
    if not menu or menu.muted or not menu.hasTheme or music == nil then return false end
    local current = trackName()
    if current then return current == menu.playingName end
    local started = pcall(function() music(menu.theme, true, .48) end)
    menu.playingName = started and trackName() or nil
    local duration = menu.playingName and field(music, "duration")
    if menu.resumeTime and type(duration) == "number" and duration > 0 then
        optional(function() music.currentTime = menu.resumeTime % duration end)
    end
    if not menu.playingName then menu.hasTheme = false end
    return menu.playingName ~= nil
end

function MenuAssets.leave(menu)
    if not menu then return end
    if menu.playingName and menu.playingName == trackName() then
        local cursor = field(music, "currentTime")
        if type(cursor) == "number" and cursor >= 0 and cursor < math.huge then
            menu.resumeTime = cursor
        end
        optional(function() music.stop() end)
    end
    menu.playingName = nil
end

function MenuAssets.toggleMute(menu)
    menu.muted = not menu.muted
    optional(saveLocalData, muteKey, menu.muted and 1 or 0)
    if menu.muted then MenuAssets.leave(menu) end
    return menu.muted
end
end

-- MenuShowcase
do
-- PolyLax 3.2 | An isolated Craft replay for the front menu.
PolyLax = PolyLax or {}
local P = PolyLax
local Showcase = {}
P.MenuShowcase = Showcase

local duration, radius = 12.6, .09
local dodgeAt, shotAt, celebrateAt, returnAt = 3.0, 4.85, 6.25, 8.8
local up = vec3(0,1,0)
local gravity = vec3(0,-9.8,0)

-- Positions are authored relative to the near goal line. The end of every
-- path returns to its starting point while the camera is back on its crane.
-- Each entry is {time, x, distance from the goal}.
local routes = {
    {{0,-7,20.8},{1.5,-6.4,18.8},{3,-4.4,12.5},{3.62,-.65,10},
        {4.85,.95,7.2},{5.6,1.36,6.55},{6.25,1.75,6.40},{7.15,3.4,7.30},
        {8.8,3.5,7.30},{10.4,-1.8,13.6},{12.6,-7,20.8}},
    {{0,7,18.6},{3,6.3,13.5},{5.5,5.7,9.1},{7.25,4.65,8.3},
        {8.8,4.65,8.3},{12.6,7,18.6}},
    {{0,-9.7,13.3},{3.3,-8.6,10.2},{5.8,-5.5,8.0},{7.35,1.9,8.1},
        {8.8,1.9,8.1},{12.6,-9.7,13.3}},
    {{0,-4.7,12.7},{2.95,-3.55,11.55},{3.56,-4.2,10.7},{5.15,-2.5,8.6},
        {7,-3.6,6.8},{8.8,-4.5,9.1},{12.6,-4.7,12.7}},
    {{0,4.9,8.75},{3.1,4.2,6.9},{5,3.85,5.1},{6.65,5.7,4.8},
        {8.8,5.7,4.8},{12.6,4.9,8.75}},
    {{0,-.18,1.15},{2.5,-.46,1.36},{4.84,-.25,1.24},{5.44,-.72,1.10},
        {6.36,-.38,1.2},{8.8,-.18,1.15},{12.6,-.18,1.15}}
}

local function clamp(value, lo, hi)
    return math.max(lo,math.min(hi,value))
end

local function ease(value)
    local t = clamp(value,0,1)
    return t*t*(3-2*t)
end

local function range(t, start, finish)
    return ease((t-start)/(finish-start))
end

local function lerp(a,b,t)
    return a+(b-a)*t
end

local function routeAt(route,t,goalZ)
    for index=2,#route do
        local b=route[index]
        if t <= b[1] then
            local a=route[index-1]
            local progress=range(t,a[1],b[1])
            return vec3(lerp(a[2],b[2],progress),0,goalZ+lerp(a[3],b[3],progress))
        end
    end
    local last=route[#route]
    return vec3(last[2],0,goalZ+last[3])
end

local function yaw(dx,dz)
    return math.deg((math.atan2 or math.atan)(-dx,-dz))
end

local function playOnce(actor,clip)
    P.AnimationController.play(actor.anim,clip)
end

local function registerCelebration()
    local clips=P.AnimationController.clips
    if clips.showcaseCelebrate then return end
    clips.showcaseCelebrate={duration=2.0,poses={
        {time=.27,grip=vec3(.45,.96,-.23),shaft=vec3(.62,.76,-.13),
            torso=vec3(-7,-15,4),crouch=.045,roll=-9,freeHand=.46},
        {time=.62,grip=vec3(.42,1.13,-.21),shaft=vec3(.19,.98,-.13),
            torso=vec3(3,-8,-7),crouch=0,roll=0,freeHand=1},
        {time=1.46,grip=vec3(.47,1.09,-.14),shaft=vec3(.14,.98,-.12),
            torso=vec3(2,8,-11),crouch=.01,roll=0,freeHand=1}
    }}
end

local function makeActor(scene, index, kit, goalZ)
    local rig=P.Character.new(scene)
    P.Character.apply(rig,{FACE=(index-1)%4+1,BODY=index==6 and 3 or 2,
        NUMBER=({24,8,32,27,15,1})[index]},nil,kit,false)
    if index==4 or index==5 then P.Character.setStickType(rig,"long") end
    local start=routeAt(routes[index],0,goalZ)
    local heading=index<=3 and 0 or 180
    rig.root.position=start
    rig.root.eulerAngles=vec3(0,heading,0)
    return {rig=rig,anim=P.AnimationController.new(rig),heading=heading,route=routes[index]}
end

local function cameraPose(state,dt)
    local t, goalZ=state.time,state.goal.z
    local hero=state.actors[1].rig.root.position
    local arc=math.sin(t/duration*math.pi*2)
    local wide=vec3(12+3.7*arc,30,goalZ+37)
    local wideTarget=vec3(-1.4,0,goalZ+12.5)
    local track=hero+vec3(-7.6,4.55,7.8)
    local trackTarget=hero+vec3(.75,1.45,-2.75)
    local shot=hero+vec3(5.1,3.85,7.25)
    local shotTarget=lerp(hero+vec3(0,1.25,0),vec3(.15,1.2,goalZ),.42)
    local close=hero+vec3(-4.3+range(t,6.3,8.75)*2.3,2.15,-6.9)
    local closeTarget=hero+vec3(.1,1.54,.18)

    local approach=range(t,1.35,2.85)
    local eye,target=lerp(wide,track,approach),lerp(wideTarget,trackTarget,approach)
    local windup=range(t,4.08,4.98)
    eye,target=lerp(eye,shot,windup),lerp(target,shotTarget,windup)
    local reaction=range(t,5.9,6.93)
    eye,target=lerp(eye,close,reaction),lerp(target,closeTarget,reaction)
    local retreat=range(t,8.38,9.82)
    eye,target=lerp(eye,wide,retreat),lerp(target,wideTarget,retreat)

    local amount=state.eye and 1-math.exp(-7*dt) or 1
    state.eye=state.eye and lerp(state.eye,eye,amount) or eye
    state.target=state.target and lerp(state.target,target,amount) or target
    state.camera.entity.position=state.eye
    -- Craft cameras look along local +Z, as in CameraController and Presentation.
    state.camera.entity.rotation=quat.lookRotation((state.target-state.eye):normalize(),up)
end

local function animateActor(state,actor,index,dt)
    local root,t=actor.rig.root,state.time
    local destination=routeAt(actor.route,t,state.goal.z)
    local displacement=destination-root.position
    local heading=actor.heading
    if index==1 and t>=shotAt-.22 and t<celebrateAt then
        heading=yaw(.58-destination.x,state.goal.z-destination.z)
    elseif t>=celebrateAt and t<returnAt and index<=3 then
        local teammate=state.actors[index==1 and 2 or 1].rig.root.position
        heading=yaw(teammate.x-destination.x,teammate.z-destination.z)
    elseif index==6 then
        local shooter=state.actors[1].rig.root.position
        heading=yaw(shooter.x-destination.x,shooter.z-destination.z)
    elseif displacement:len()>.002 then
        heading=yaw(displacement.x,displacement.z)
    end

    local turn=(heading-actor.heading+180)%360-180
    actor.heading=actor.heading+turn*(1-math.exp(-10*dt))
    root.position=destination
    root.eulerAngles=vec3(0,actor.heading,0)
    local speed=math.min(7.8,displacement:len()/math.max(dt,.001))
    return P.AnimationController.update(actor.anim,dt,{speed=speed,
        turn=clamp(turn/85,-1,1),possessed=index==1 and not state.shot and not state.scored})
end

local function launch(state)
    local origin=state.actors[1].rig.pocket.worldPosition
    local aim=vec3(.58,.91,state.goal.z-.20)
    local flightTime=.32
    state.ball.position=origin
    state.shot={origin=origin,time=0,velocity=(aim-origin)/flightTime-gravity*(flightTime*.5)}
end

local function advanceBall(state,dt)
    if state.shot then
        local shot=state.shot
        shot.time=shot.time+dt
        local t=shot.time
        local nextPosition=shot.origin+shot.velocity*t+gravity*(.5*t*t)
        local hit=P.GoalPhysics.step(state.goal,state.ball.position,nextPosition,shot.velocity+gravity*t)
        if hit and hit.kind=="GOAL" then
            state.ball.position=P.GoalPhysics.capture(state.goal,hit.position)
            state.shot,state.scored=nil,true
        elseif t>.50 then
            state.ball.position=P.GoalPhysics.capture(state.goal,vec3(.58,.91,state.goal.z))
            state.shot,state.scored=nil,true
        else
            state.ball.position=nextPosition
        end
    elseif not state.scored then
        state.ball.position=state.actors[1].rig.pocket.worldPosition
    elseif state.time>=11.9 then
        -- The ball is reset off the wide frame rather than visibly rewinding.
        state.ball.position=state.actors[1].rig.pocket.worldPosition
    end
    state.ball.active=state.time<returnAt or state.time>=11.9
    P.GoalPhysics.update(state.goal,dt)
end

function Showcase.new(scene,homeId,awayId)
    registerCelebration()
    local home,away,team=P.TeamUniform.matchKits(homeId,awayId)
    local field=P.Field.new(scene,team.field)
    local state={scene=scene,field=field,goal=field.goals[1],actors={},time=0,
        duration=duration,stage="opening",cycles=0,scored=false}
    state.camera=P.CameraController.new(scene,51)
    for index=1,#routes do
        state.actors[index]=makeActor(scene,index,index<=3 and home or away,state.goal.z)
    end
    local standard=asset and asset.builtin and asset.builtin.Materials
    state.ball=scene:entity()
    state.ball.model=craft.model.icosphere(radius,1,true)
    state.ball.material=craft.material(standard and standard.Standard or "Materials:Standard")
    state.ball.material.diffuse=color(255,215,91)
    state.ball.position=state.actors[1].rig.pocket.worldPosition
    cameraPose(state,0)
    return state
end

function Showcase.update(state,dt)
    dt=clamp(dt or 0,0,.05)
    local previous=state.time
    state.time=state.time+dt
    if state.time>=duration then
        state.time=state.time-duration
        state.shot,state.scored=nil,false
        state.cycles=state.cycles+1
        previous=0
        P.GoalPhysics.reset(state.goal)
    end
    local t=state.time
    if previous<dodgeAt and t>=dodgeAt then
        playOnce(state.actors[1],"dodge")
        playOnce(state.actors[4],"pokeCheckLong")
    elseif previous<shotAt and t>=shotAt then
        playOnce(state.actors[1],"shoot")
    elseif previous<celebrateAt and t>=celebrateAt then
        for index=1,3 do playOnce(state.actors[index],"showcaseCelebrate") end
    end
    for index,actor in ipairs(state.actors) do
        local event=animateActor(state,actor,index,dt)
        if index==1 and event=="release" then launch(state) end
    end
    advanceBall(state,dt)
    state.stage=t<1.35 and "opening" or t<dodgeAt and "tracking"
        or t<shotAt and "dodge" or t<celebrateAt and "shot"
        or t<returnAt and "celebration" or "return"
    cameraPose(state,dt)
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

-- UltimateCatalog
do
-- Original cards, collectible season editions, and lacrosse research.
PolyLax = PolyLax or {}
local Catalog = {}
PolyLax.UltimateCatalog = Catalog

Catalog.releasePolicy = {
    publicNames=true,
    officialLogos=false,
    playerPhotos=false,
    authenticUniformArt=false,
    paidPacks=false
}
Catalog.disclaimer = "Original artwork and unaffiliated season editions."
Catalog.ratingDisclosure = "PolyLax game ratings are fictional."
Catalog.ratingVersion = 1

Catalog.sources = {
    pll = "https://stats.premierlacrosseleague.com/player-table",
    pllAwards2025 = "https://premierlacrosseleague.com/articles/pll-end-of-season-awards",
    pllAwards2026 = "https://www.premierlacrosseleague.com/articles/cj-kirst-wins-2026-pll-jim-brown-most-valuable-player-award",
    pllAwards2022 = "https://www.premierlacrosseleague.com/articles/baptiste-wins-first-career-mvp-at-2022-pll-awards",
    pllAwards2021 = "https://www.usalacrosse.com/magazine/blaze-riorden-wins-pll-mvp-others-honored-league-awards-night",
    pllChampionship2023 = "https://premierlacrosseleague.com/articles/archers-lc-wins-2023-pll-cash-app-championship",
    pllTeat2024 = "https://premierlacrosseleague.com/articles/2024-players-top-50-nos-10-1-atlas-archers-dominate-top-10",
    pllTeat = "https://premierlacrosseleague.com/articles/jeff-teat-expected-to-miss-2026-pll-season",
    mll = "https://www.usalacrosse.com/national-teams/2014-us-mens-team-roster",
    mllAllStar2017 = "https://www.usalacrosse.com/magazine/mll-all-star-game-rosters-announced",
    mllPoskay = "https://virginiasports.com/news/2010/08/20/former-uva-all-american-poskay-named-mll-mvp",
    mllHall = "https://www.usalacrosse.com/magazine/pll-announces-inaugural-class-professional-lacrosse-hall-fame",
    mllCannons2017 = "https://www.usalacrosse.com/magazine/mll-preview-bostons-fleet-long-poles-key-its-success",
    mllOutlaws2016 = "https://www.premierlacrosseleague.com/articles/its-all-i-know-how-to-do-how-matt-kavanagh-stepped-up-in-big-moments",
    mllMvp2015 = "https://www.premierlacrosseleague.com/articles/how-hard-time-and-resiliency-built-greg-gurenlians-professional-lacrosse-hall-of-fame-career",
    mllMvp2017 = "https://www.usalacrosse.com/magazine/us-national-team-continues-training-weekend-rain-soaked-practices",
    mllMvp2019 = "https://www.oursportscentral.com/services/releases/lyle-thompson-wins-coca-cola-most-valuable-player-and-warrior-offensive-player-of-the-year/n-5559160",
    mllAwards2020 = "https://www.usalacrosse.com/magazine/dialed-your-lacrosse-fix-monday-aug-24",
    mllGoodrich2020 = "https://www.usalacrosse.com/magazine/zach-goodrich-named-major-league-lacrosse-defensive-player-year",
    mllDraftReview2021 = "https://www.usalacrosse.com/magazine/phil-shores-premier-lacrosse-league-entry-draft-big-board",
    nll = "https://www.nll.com/stats/all-player-stats/",
    nllAwards2025 = "https://www.nll.com/news/nll-announces-2024-25-award-winners-3/",
    nllPositionAwards2025 = "https://www.nll.com/news/nll-announces-2024-25-offensive-defensive-transition-goaltender-of-the-year-winners/",
    nllAwards2026 = "https://www.nll.com/news/national-lacrosse-league-announces-2025-26-regular-season-award-winners/",
    nllHall = "https://www.nll.com/nll-hall-of-fame/",
    nllAwards2024 = "https://www.nll.com/news/buffalos-byrne-vancouvers-dilks-halifaxs-withers-and-torontos-rose-take-nll-positional-player-of-the-year-awards/",
    nllAwards2023 = "https://www.nll.com/news/del-bianco-becomes-second-goaltender-to-win-mvp-donville-fourth-straight-number-one-overall-selection-to-win-rookie-of-the-year/",
    nllAwards2019 = "https://www.nll.com/news/nll-announces-2018-19-season-award-winners/",
    nllAwards2017 = "https://www.nll.com/news/2017-nll-season-award-winners/",
    nllHistory = "https://www.nll.com/about/history/",
    nllSchreiber2017 = "https://www.nll.com/news/the-most-notable-free-agent-signings-in-recent-memory/",
    nllWard = "https://www.nll.com/players/13412/dillon-ward/"
}

Catalog.players = {}
Catalog.editions = {}
Catalog.realPlayers = {}
Catalog.researchCandidates = {}
local playableById = {}
local verifiedIdentities = {}
local verifiedById = {}

-- The IDs and ratings of the eight original economy cards are kept for older saves.
-- Fictional group codes make the existing league-themed challenges consistent.
local function addOriginals(league, rows)
    for _,row in ipairs(rows) do
        local card = {
            id=row[1], name=row[2], position=row[3], rating=row[4],
            team=row[5], number=row[6], league=league, fictional=true,
            ratingStatus="placeholder", playable=true
        }
        Catalog.players[#Catalog.players+1] = card
        playableById[card.id] = card
    end
end

addOriginals("PLL", {
    {"pll_sowers_2026", "Miles Rowan", "A", 82, "Juniper Field", 9},
    {"pll_holman_2026", "Rafe Calder", "A", 89, "Violet Field", 18},
    {"pll_oneill_2026", "Taylor Vale", "A", 96, "Sundown Field", 27},
    {"pll_carroll_2026", "Adrian Ford", "M", 81, "Coastal Field", 12},
    {"pll_kavanagh_2026", "Cal Keane", "A", 88, "Juniper Field", 20},
    {"pll_molloy_2026", "Rory Shaw", "A", 95, "Juniper Field", 4},
    {"pll_king_2026", "Cam Keyes", "M", 80, "Sundown Field", 16},
    {"pll_malone_2026", "Theo Mercer", "A", 87, "Coastal Field", 7},

    {"field_aria_santos", "Aria Santos", "D", 93, "Coastal Field", 33},
    {"field_des_banks", "Des Banks", "D", 86, "Violet Field", 23},
    {"field_rex_kerr", "Rex Kerr", "D", 79, "Juniper Field", 36},
    {"field_hugo_moreno", "Hugo Moreno", "D", 83, "Sundown Field", 44},
    {"field_kai_hollis", "Kai Hollis", "G", 91, "Juniper Field", 14},
    {"field_jay_navarro", "Jay Navarro", "G", 77, "Coastal Field", 39},
    {"field_sage_chen", "Sage Chen", "FO", 90, "Violet Field", 54},
    {"field_emil_shaw", "Emil Shaw", "LSM", 85, "Juniper Field", 4},
    {"field_eli_cross", "Eli Cross", "M", 86, "Coastal Field", 11},
    {"field_jules_nash", "Jules Nash", "SSDM", 78, "Sundown Field", 55}
})

addOriginals("MLL", {
    {"heritage_trey_bishop", "Trey Bishop", "A", 94, "Heritage Navy", 14},
    {"heritage_wes_roux", "Wes Roux", "A", 86, "Heritage Crimson", 5},
    {"heritage_noah_dane", "Noah Dane", "A", 79, "Copper Heritage", 18},
    {"heritage_tate_ochoa", "Tate Ochoa", "M", 92, "Copper Heritage", 21},
    {"heritage_dev_wilder", "Dev Wilder", "M", 85, "Heritage Navy", 24},
    {"heritage_gael_price", "Gael Price", "FO", 82, "Heritage Crimson", 14},
    {"heritage_leo_guerrero", "Leo Guerrero", "LSM", 88, "Heritage Navy", 8},
    {"heritage_milo_doucet", "Milo Doucet", "D", 91, "Copper Heritage", 3},
    {"heritage_tal_bennett", "Tal Bennett", "D", 84, "Heritage Navy", 36},
    {"heritage_owen_bridge", "Owen Bridge", "D", 77, "Heritage Crimson", 55},
    {"heritage_jude_cantu", "Jude Cantu", "G", 89, "Heritage Crimson", 12},
    {"heritage_ronan_blair", "Ronan Blair", "G", 75, "Copper Heritage", 2},
    {"heritage_luca_dawes", "Luca Dawes", "M", 83, "Heritage Navy", 50},
    {"heritage_aziz_cortez", "Aziz Cortez", "SSDM", 80, "Copper Heritage", 44}
})

addOriginals("NLL", {
    {"box_ari_beck", "Ari Beck", "A", 96, "Midnight Box", 26},
    {"box_remy_march", "Remy March", "A", 88, "Ice Box", 35},
    {"box_silas_voss", "Silas Voss", "A", 80, "Ember Box", 11},
    {"box_luc_renaud", "Luc Renaud", "M", 93, "Ice Box", 25},
    {"box_arden_west", "Arden West", "M", 89, "Midnight Box", 15},
    {"box_dane_costa", "Dane Costa", "M", 78, "Ember Box", 42},
    {"box_cian_frost", "Cian Frost", "D", 92, "Ember Box", 6},
    {"box_ryan_harrow", "Ryan Harrow", "D", 85, "Ice Box", 47},
    {"box_finn_park", "Finn Park", "D", 81, "Midnight Box", 38},
    {"box_mikael_dunn", "Mikael Dunn", "G", 90, "Midnight Box", 1},
    {"box_elio_tremblay", "Elio Tremblay", "G", 83, "Ice Box", 30},
    {"box_dalen_varga", "Dalen Varga", "SSDM", 87, "Ember Box", 24},
    {"box_cade_kim", "Cade Kim", "FO", 84, "Ember Box", 71},
    {"box_anton_desai", "Anton Desai", "LSM", 79, "Ice Box", 64}
})

-- Evidence records preserve the club and competition in the cited season.
-- Ratings are game design placeholders and never sourced facts.
local function addVerified(league,season,source,rows)
    for _,row in ipairs(rows) do
        local legacyCardId = playableById[row[1]] and row[1]
        local player = {
            id=legacyCardId and "record_"..legacyCardId or row[1], legacyCardId=legacyCardId,
            name=row[2], position=row[3], team=row[4], rating=row[5],
            stats=row[6], league=league, season=season, source=Catalog.sources[source],
            verification="verified", ratingStatus="placeholder", playable=false
        }
        Catalog.realPlayers[#Catalog.realPlayers+1] = player
        verifiedIdentities[league.."/"..player.name] = true
        verifiedById[row[1]] = player
    end
end

addVerified("PLL",2026,"pll",{
    {"pll_sowers_2026","Michael Sowers","A","Philadelphia Waterdogs",82,{games=12,points=51,goals=29,assists=22}},
    {"pll_holman_2026","Marcus Holman","A","Boston Cannons",89,{games=12,points=41,goals=28,assists=7}},
    {"pll_oneill_2026","Brennan O'Neill","A","Denver Outlaws",96,{games=11,points=35,goals=13,assists=19}},
    {"pll_carroll_2026","Aidan Carroll","M","Maryland Whipsnakes",81,{games=12,points=34,goals=28,assists=6}},
    {"pll_kavanagh_2026","Chris Kavanagh","A","California Redwoods",88,{games=10,points=34,goals=23,assists=10}},
    {"pll_molloy_2026","Dylan Molloy","A","California Redwoods",95,{games=12,points=34,goals=25,assists=9}},
    {"pll_king_2026","Sam King","M","Utah Archers",80,{games=12,points=33,goals=23,assists=10}},
    {"pll_malone_2026","TJ Malone","A","Maryland Whipsnakes",87,{games=12,points=32,goals=24,assists=8}}
})

addVerified("PLL",2026,"pllAwards2026",{
    {"pll_kirst_2026","CJ Kirst","A","Philadelphia Waterdogs",95,{goals=34}},
    {"pll_dobson_2026","Brett Dobson","G","Utah Archers",93,{savePct=59}},
    {"pll_lavelle_2026","Brendan Lavelle","D","Utah Archers"},
    {"pll_tevlin_2026","Brian Tevlin","SSDM","California Redwoods",nil,
        {causedTurnovers=9,points=13,goals=7,assists=6}},
    {"pll_mcmeekin_2026","Andrew McMeekin","FO","Boston Cannons",nil,{faceoffPct=62.5}},
    {"pll_currier_2026","Zach Currier","M","Philadelphia Waterdogs",nil,{groundBalls=68}},
    {"pll_rall_2026","Ethan Rall","LSM","Boston Cannons"},
    {"pll_spallina_2026","Joey Spallina","A","Maryland Whipsnakes",nil,{points=36,goals=16,assists=18}}
})

addVerified("PLL",2025,"pllAwards2025",{
    {"pll_shellenberger_2025","Connor Shellenberger","A","New York Atlas",94,{points=46,goals=23,assists=23}},
    {"pll_campbell_2025","Matt Campbell","M","Boston Cannons",89,{points=28,goals=18,assists=8}},
    {"pll_adler_2025","Gavin Adler","D","New York Atlas",91,{causedTurnovers=13}},
    {"pll_rowlett_2025","Jack Rowlett","D","Carolina Chaos",86},
    {"pll_giles_harris_2025","JT Giles-Harris","D","Denver Outlaws",89},
    {"pll_hossack_2025","Graeme Hossack","D","Utah Archers",87},
    {"pll_mcnaney_2025","Logan McNaney","G","Denver Outlaws",90,{savePct=58.3}},
    {"pll_riorden_2025","Blaze Riorden","G","Carolina Chaos",91},
    {"pll_entenmann_2025","Liam Entenmann","G","New York Atlas",86},
    {"pll_ierlan_2025","TD Ierlan","FO","California Redwoods",88,{faceoffPct=60.5,groundBalls=74}},
    {"pll_baptiste_2025","Trevor Baptiste","FO","New York Atlas",92},
    {"pll_piseno_2025","Jake Piseno","LSM","Denver Outlaws",91,{causedTurnovers=12,groundBalls=36}},
    {"pll_terefenko_2025","Ryan Terefenko","SSDM","Denver Outlaws",89,{causedTurnovers=2,groundBalls=18}}
})

addVerified("PLL",2025,"pllTeat",{
    {"pll_teat_2025","Jeff Teat","A","New York Atlas",93,{points=40,goals=17,assists=23}}
})

addVerified("PLL",2024,"pllTeat2024",{
    {"pll_teat_2024","Jeff Teat","A","New York Atlas",nil,{points=64,goals=28,assists=36}}
})

addVerified("PLL",2023,"pllChampionship2023",{
    {"pll_dobson_2023","Brett Dobson","G","Archers Lacrosse Club"}
})

addVerified("PLL",2022,"pllAwards2022",{
    {"pll_schreiber_2022","Tom Schreiber","M","Archers Lacrosse Club",nil,{games=10,points=35,goals=17,assists=14}},
    {"pll_baptiste_2022","Trevor Baptiste","FO","Atlas Lacrosse Club"}
})

addVerified("PLL",2021,"pllAwards2021",{
    {"pll_riorden_2021","Blaze Riorden","G","Chaos Lacrosse Club",nil,{games=9,saves=149,savePct=61}}
})

addVerified("MLL",2014,"mll",{
    {"mll_rabil_2014","Paul Rabil","M","Boston Cannons",95},
    {"mll_pannell_2014","Rob Pannell","A","New York Lizards",93},
    {"mll_leveille_2014","Kevin Leveille","A","Rochester Rattlers",87},
    {"mll_harrison_2014","Kyle Harrison","M","Ohio Machine",90},
    {"mll_seibald_2014","Max Seibald","M","New York Lizards",86},
    {"mll_zink_2014","Lee Zink","D","Denver Outlaws",91},
    {"mll_durkin_2014","Tucker Durkin","D","Florida Launch",89},
    {"mll_hartzell_2014","Kyle Hartzell","D","New York Lizards",87},
    {"mll_schwartzman_2014","Jesse Schwartzman","G","Denver Outlaws",90},
    {"mll_galloway_2014","John Galloway","G","Rochester Rattlers",85},
    {"mll_gurenlian_2014","Greg Gurenlian","FO","New York Lizards",92},
    {"mll_stanwick_2014","Steele Stanwick","A","Ohio Machine",85}
})

addVerified("MLL",2017,"mllAllStar2017",{
    {"mll_adams_2017","Drew Adams","G","New York Lizards",89},
    {"mll_walters_2017","Joe Walters","M","New York Lizards",89},
    {"mll_dunn_2017","Matt Dunn","D","Rochester Rattlers",85}
})

addVerified("MLL",2017,"mllMvp2017",{
    {"mll_schreiber_2017","Tom Schreiber","M","Ohio Machine",93,{goals=18,assists=26}}
})

addVerified("MLL",2010,"mllPoskay",{
    {"mll_poskay_2010","Matt Poskay","A","Boston Cannons",90,{games=12,points=52,goals=45}}
})

addVerified("MLL",2015,"mllMvp2015",{
    {"mll_gurenlian_2015","Greg Gurenlian","FO","New York Lizards",nil,{groundBalls=175}}
})

addVerified("MLL",2019,"mllMvp2019",{
    {"mll_thompson_2019","Lyle Thompson","A","Chesapeake Bayhawks",nil,{games=15,points=73,goals=46,assists=27}}
})

addVerified("MLL",2020,"mllAwards2020",{
    {"mll_wasserman_2020","Bryce Wasserman","A","Boston Cannons",nil,{games=5,goals=14}},
    {"mll_sconone_2020","Sean Sconone","G","Connecticut Hammerheads"},
    {"mll_adler_2020","Max Adler","FO","Denver Outlaws"},
    {"mll_costabile_2020","CJ Costabile","LSM","Chesapeake Bayhawks"}
})

addVerified("MLL",2020,"mllGoodrich2020",{
    {"mll_goodrich_2020","Zach Goodrich","SSDM","Boston Cannons",nil,{games=5,groundBalls=9,causedTurnovers=3}}
})

addVerified("MLL",2014,"mllHall",{
    {"mll_powell_2014","Casey Powell","A","Florida Launch",94}
})

addVerified("MLL",2007,"mllHall",{
    {"mll_striebel_2007","Matt Striebel","M","Philadelphia Barrage",90}
})

addVerified("MLL",2017,"mllCannons2017",{
    {"mll_merrill_2017","Brodie Merrill","D","Boston Cannons",92}
})

addVerified("MLL",2016,"mllOutlaws2016",{
    {"mll_grant_2016","John Grant Jr.","A","Ohio Machine",94}
})

addVerified("NLL","2024-25","nllAwards2025",{
    {"nll_fields_2025","Connor Fields","F","Rochester Knighthawks",94},
    {"nll_smith_2025","Dhane Smith","F","Buffalo Bandits",95},
    {"nll_byrne_2025","Josh Byrne","F","Buffalo Bandits",93},
    {"nll_teat_2025","Jeff Teat","F","Ottawa Black Bears",93},
    {"nll_dilks_2025","Ryan Dilks","D","Vancouver Warriors",87},
    {"nll_de_snoo_2025","Mitch de Snoo","D","Philadelphia Wings",86},
    {"nll_hossack_2025","Graeme Hossack","D","Halifax Thunderbirds",89},
    {"nll_terefenko_2025","Ryan Terefenko","T","Halifax Thunderbirds",88},
    {"nll_vinc_2025","Matt Vinc","G","Buffalo Bandits",93}
})

addVerified("NLL","2024-25","nllPositionAwards2025",{
    {"nll_scigliano_2025","Frank Scigliano","G","Saskatchewan Rush",91,{savePct=79.5}},
    {"nll_matt_hossack_2025","Matt Hossack","D","Saskatchewan Rush",nil,{causedTurnovers=34,looseBalls=129}},
    {"nll_grant_2025","Owen Grant","T","Vancouver Warriors",nil,{causedTurnovers=28,looseBalls=103,points=24,goals=15,assists=9}}
})

addVerified("NLL","2025-26","nllAwards2026",{
    {"nll_bal_2026","Keegan Bal","F","Vancouver Warriors",91,{points=124,goals=45,assists=79}},
    {"nll_currier_2026","Zach Currier","T","San Diego Seals",90,{points=57,goals=22,assists=35,looseBalls=200}},
    {"nll_del_bianco_2026","Christian Del Bianco","G","Vancouver Warriors",92},
    {"nll_dobson_2026","Brett Dobson","G","Georgia Swarm",92,{savePct=84.7}},
    {"nll_jones_2026","Callum Jones","D","Ottawa Black Bears",nil,{causedTurnovers=32,looseBalls=173}}
})

addVerified("NLL","2022-23","nllAwards2023",{
    {"nll_del_bianco_2023","Christian Del Bianco","G","Calgary Roughnecks"}
})

addVerified("NLL","2018-19","nllAwards2019",{
    {"nll_dobbie_2019","Dane Dobbie","F","Calgary Roughnecks",nil,{points=115,goals=47,assists=68,looseBalls=69}},
    {"nll_hossack_2019","Graeme Hossack","D","Rochester Knighthawks"},
    {"nll_rogers_2019","Challen Rogers","T","Toronto Rock"},
    {"nll_vinc_2019","Matt Vinc","G","Buffalo Bandits"},
    {"nll_baptiste_2019","Trevor Baptiste","T","Philadelphia Wings"}
})

addVerified("NLL",2017,"nllAwards2017",{
    {"nll_thompson_2017","Lyle Thompson","F","Georgia Swarm",nil,{points=116,goals=45,assists=71}}
})

addVerified("NLL",2017,"nllSchreiber2017",{
    {"nll_schreiber_2017","Tom Schreiber","F","Toronto Rock",nil,{points=94}}
})

addVerified("NLL","2000-01","nllHistory",{
    {"nll_tavares_2001","John Tavares","F","Buffalo Bandits"}
})

addVerified("NLL","2024-25","nllWard",{
    {"nll_ward_2025","Dillon Ward","G","Colorado Mammoth",90}
})

addVerified("NLL","2023-24","nllAwards2024",{
    {"nll_rose_2024","Nick Rose","G","Toronto Rock",90}
})

-- The Hall of Fame source verifies participation, not a single season affiliation.
addVerified("NLL",nil,"nllHall",{
    {"nll_hall_tavares","John Tavares","F",nil,96},
    {"nll_hall_grant","John Grant Jr.","F",nil,95},
    {"nll_hall_gary_gait","Gary Gait","F",nil,96},
    {"nll_hall_paul_gait","Paul Gait","F",nil,92}
})

-- Review is explicit. A sourced identity alone does not grant pack eligibility.
local recognition = {
    season={label="Regular season statistics",rating=77},
    allStar={label="All-Star selection",rating=84},
    secondTeam={label="Second-team season honors",rating=85},
    finalist={label="Position award finalist",rating=86},
    firstTeam={label="First-team season honors",rating=88},
    rookie={label="Rookie of the Year",rating=86},
    position={label="Position award winner",rating=90},
    championship={label="Championship MVP",rating=90},
    mvp={label="Season MVP",rating=93}
}

local editionsByEvidence = {
    {"season","pll_holman_2026","pll_oneill_2026","pll_carroll_2026","pll_kavanagh_2026",
        "pll_molloy_2026","pll_king_2026","pll_malone_2026","pll_teat_2025"},
    {"allStar","mll_adams_2017","mll_walters_2017","mll_dunn_2017"},
    {"secondTeam","nll_byrne_2025","nll_teat_2025","nll_de_snoo_2025",
        "nll_hossack_2025","nll_terefenko_2025","nll_vinc_2025","nll_del_bianco_2026"},
    {"finalist","pll_rowlett_2025","pll_giles_harris_2025","pll_hossack_2025",
        "pll_riorden_2025","pll_entenmann_2025","pll_baptiste_2025"},
    {"firstTeam","nll_smith_2025","nll_dilks_2025"},
    {"rookie","pll_spallina_2026","nll_schreiber_2017"},
    {"position","pll_sowers_2026","pll_dobson_2026","pll_lavelle_2026","pll_tevlin_2026",
        "pll_mcmeekin_2026","pll_currier_2026","pll_rall_2026","pll_campbell_2025",
        "pll_adler_2025","pll_mcnaney_2025","pll_ierlan_2025","pll_piseno_2025",
        "pll_terefenko_2025","pll_schreiber_2022","mll_sconone_2020","mll_adler_2020",
        "mll_costabile_2020","mll_goodrich_2020","nll_scigliano_2025","nll_matt_hossack_2025","nll_grant_2025","nll_bal_2026",
        "nll_currier_2026","nll_jones_2026","nll_hossack_2019","nll_rogers_2019","nll_vinc_2019"},
    {"championship","pll_dobson_2023"},
    {"mvp","pll_kirst_2026","pll_shellenberger_2025","pll_teat_2024","pll_baptiste_2022",
        "pll_riorden_2021","mll_poskay_2010","mll_gurenlian_2015","mll_schreiber_2017",
        "mll_thompson_2019","mll_wasserman_2020","nll_fields_2025","nll_dobson_2026",
        "nll_del_bianco_2023","nll_dobbie_2019","nll_thompson_2017","nll_tavares_2001"}
}

local extraEvidence = {
    pll_sowers_2026=Catalog.sources.pllAwards2026,
    mll_wasserman_2020=Catalog.sources.mllDraftReview2021,
    nll_schreiber_2017=Catalog.sources.nllAwards2017
}

-- Produce small role-specific tuning offsets even when a source gives an honor only.
local function gameProfile(record)
    local s = record.stats or {}
    local position = record.position
    local box = record.league == "NLL"
    local ground = math.min(3,math.floor((s.groundBalls or s.looseBalls or 0)/(box and 60 or 20)))
    if position == "FO" then
        local impact = math.min(5,math.max(0,math.floor(((s.faceoffPct or 50)-50)/3)))
        return math.max(impact,ground),{faceoff=3+impact,groundBalls=2+ground}
    elseif position == "G" then
        local typical = box and 76 or 51
        local impact = math.min(5,math.max(0,math.floor(((s.savePct or typical)-typical)/1.5)))
        return impact,{reflexes=3+impact,goaliePositioning=3,passing=1}
    elseif position == "D" or position == "LSM" or position == "SSDM" then
        local impact = math.min(5,math.floor((s.causedTurnovers or 0)/(box and 6 or 3)))
        return math.max(impact,ground),{
            stickCheck=2+impact,defensiveAwareness=3,groundBalls=1+ground,
            speed=position~="D" and 2 or 0
        }
    end
    local impact = math.min(5,math.floor((s.points or s.goals or 0)/(box and 23 or 10)))
    local creator = (s.assists or 0) > (s.goals or 0)
    if position == "M" or position == "T" then
        return math.max(impact,ground),{
            passing=creator and 4 or 2,stamina=3,groundBalls=1+ground,shotAccuracy=1+impact
        }
    end
    return impact,{passing=creator and 3+impact or 1,shotAccuracy=creator and 2 or 3+impact,ballControl=2}
end

local included = {}
for _,group in ipairs(editionsByEvidence) do
    local reason = recognition[group[1]]
    for index=2,#group do
        local recordId = group[index]
        local record = assert(verifiedById[recordId],"Missing verified edition: "..recordId)
        assert(record.season and record.team and record.source,"Incomplete verified edition: "..recordId)
        local impact, attributes = gameProfile(record)
        local edition = {
            id="edition_"..recordId, recordId=record.id,
            identity="player:"..record.name:lower():gsub("[^%w]",""),
            name=record.name, league=record.league, team=record.team,
            season=record.season, position=record.position, source=record.source,
            stats=record.stats, evidence={kind=group[1],description=reason.label,source=record.source,
                corroboration=extraEvidence[recordId]},
            rating=math.min(98,reason.rating+impact), ratingVersion=Catalog.ratingVersion, attributes=attributes,
            verification="verified", ratingStatus="fictional", playable=true
        }
        assert(not included[recordId],"Duplicate verified edition: "..recordId)
        included[recordId] = true
        Catalog.players[#Catalog.players+1] = edition
        Catalog.editions[#Catalog.editions+1] = edition
        playableById[edition.id] = edition
    end
end

-- Names carried over from the earlier editorial queue. Unresolved season and
-- club identities stay here. These IDs are never minted as playable cards.
local candidates = {
    {"research_pll_1","Jeff Teat","PLL","A"},
    {"research_pll_2","Lyle Thompson","PLL","A"},
    {"research_pll_3","Asher Nolting","PLL","A"},
    {"research_pll_4","Connor Fields","PLL","A"},
    {"research_pll_5","Matt Rambo","PLL","A"},
    {"research_pll_6","Grant Ament","PLL","A"},
    {"research_pll_7","Zed Williams","PLL","A"},
    {"research_pll_8","Rob Pannell","PLL","A"},
    {"research_pll_9","Tom Schreiber","PLL","M"},
    {"research_pll_10","Romar Dennis","PLL","M"},
    {"research_pll_11","Ryan Conrad","PLL","M"},
    {"research_pll_12","Dox Aitken","PLL","M"},
    {"research_pll_13","Trevor Baptiste","PLL","M"},
    {"research_pll_14","TD Ierlan","PLL","M"},
    {"research_pll_15","Mike Sisselberger","PLL","M"},
    {"research_pll_16","JT Giles-Harris","PLL","D"},
    {"research_pll_17","Gavin Adler","PLL","D"},
    {"research_pll_18","Matt Dunn","PLL","D"},
    {"research_pll_19","Jack Rowlett","PLL","D"},
    {"research_pll_20","Michael Ehrhardt","PLL","D"},
    {"research_pll_21","Graeme Hossack","PLL","D"},
    {"research_pll_22","Blaze Riorden","PLL","G"},
    {"research_pll_23","Jack Kelly","PLL","G"},
    {"research_pll_24","Colin Kirst","PLL","G"},
    {"research_pll_25","Brett Dobson","PLL","G"},
    {"research_mll_26","Paul Rabil","MLL","M"},
    {"research_mll_27","John Grant Jr.","MLL","A"},
    {"research_mll_28","Casey Powell","MLL","A"},
    {"research_mll_29","Ryan Powell","MLL","A"},
    {"research_mll_30","Mikey Powell","MLL","A"},
    {"research_mll_31","John Tavares","MLL","A"},
    {"research_mll_32","Matt Poskay","MLL","A"},
    {"research_mll_33","Kevin Leveille","MLL","A"},
    {"research_mll_34","Brendan Mundorf","MLL","A"},
    {"research_mll_35","Steele Stanwick","MLL","A"},
    {"research_mll_36","Kyle Harrison","MLL","M"},
    {"research_mll_37","Matt Striebel","MLL","M"},
    {"research_mll_38","Max Seibald","MLL","M"},
    {"research_mll_39","Paul Gait","MLL","M"},
    {"research_mll_40","Gary Gait","MLL","M"},
    {"research_mll_41","Joe Walters","MLL","M"},
    {"research_mll_42","Brodie Merrill","MLL","D"},
    {"research_mll_43","Nicky Polanco","MLL","D"},
    {"research_mll_44","Kyle Hartzell","MLL","D"},
    {"research_mll_45","Lee Zink","MLL","D"},
    {"research_mll_46","Jesse Schwartzman","MLL","G"},
    {"research_mll_47","Drew Adams","MLL","G"},
    {"research_mll_48","Brian Dougherty","MLL","G"},
    {"research_nll_49","Dhane Smith","NLL","F"},
    {"research_nll_50","Josh Byrne","NLL","F"},
    {"research_nll_51","Chris Cloutier","NLL","F"},
    {"research_nll_52","Ryan Smith","NLL","F"},
    {"research_nll_53","Shayne Jackson","NLL","F"},
    {"research_nll_54","Randy Staats","NLL","F"},
    {"research_nll_55","Austin Staats","NLL","F"},
    {"research_nll_56","Curtis Dickson","NLL","F"},
    {"research_nll_57","Cody Jamieson","NLL","F"},
    {"research_nll_58","Mark Matthews","NLL","F"},
    {"research_nll_59","Callum Crawford","NLL","F"},
    {"research_nll_60","Rob Hellyer","NLL","F"},
    {"research_nll_61","Tom Schreiber","NLL","F"},
    {"research_nll_62","Lyle Thompson","NLL","F"},
    {"research_nll_63","Jeff Teat","NLL","F"},
    {"research_nll_64","John Tavares","NLL","F"},
    {"research_nll_65","Dan Dawson","NLL","F"},
    {"research_nll_66","Shawn Evans","NLL","F"},
    {"research_nll_67","Colin Doyle","NLL","F"},
    {"research_nll_68","John Grant Jr.","NLL","F"},
    {"research_nll_69","Gary Gait","NLL","F"},
    {"research_nll_70","Paul Gait","NLL","F"},
    {"research_nll_71","Zach Currier","NLL","T"},
    {"research_nll_72","Tyler Pace","NLL","T"},
    {"research_nll_73","Graeme Hossack","NLL","D"},
    {"research_nll_74","Brodie Merrill","NLL","D"},
    {"research_nll_75","Steve Priolo","NLL","D"},
    {"research_nll_76","Matt Beers","NLL","D"},
    {"research_nll_77","Matt Vinc","NLL","G"},
    {"research_nll_78","Christian Del Bianco","NLL","G"},
    {"research_nll_79","Dillon Ward","NLL","G"},
    {"research_nll_80","Nick Rose","NLL","G"},
    {"research_nll_81","Doug Jamieson","NLL","G"},
    {"research_nll_82","Mike Poulin","NLL","G"},
}
for _,row in ipairs(candidates) do
    if not verifiedIdentities[row[3].."/"..row[2]] then
        Catalog.researchCandidates[#Catalog.researchCandidates+1] = {
            id=row[1], name=row[2], league=row[3], position=row[4],
            verification="pending", playable=false
        }
    end
end

-- Hand-picked game colors and generic designs. No badge, team mark or jersey goes here.
Catalog.kits = {
    {id="field_violet",name="Violet Field",league="PLL",era="modern",home={34,30,73},away={228,222,241},accent={202,158,64}},
    {id="field_coastal",name="Coastal Field",league="PLL",era="modern",home={17,77,92},away={229,238,237},accent={94,194,177}},
    {id="heritage_navy",name="Heritage Navy",league="MLL",era="throwback",home={28,44,71},away={232,235,241},accent={191,143,65}},
    {id="heritage_crimson",name="Heritage Crimson",league="MLL",era="throwback",home={107,31,49},away={244,231,229},accent={217,171,94}},
    {id="box_midnight",name="Midnight Box",league="NLL",era="indoor",home={27,28,37},away={222,223,231},accent={221,114,47}},
    {id="box_ice",name="Ice Box",league="NLL",era="indoor",home={23,67,113},away={225,241,250},accent={97,188,226}}
}

local kitsById = {}
for _,kit in ipairs(Catalog.kits) do
    kitsById[kit.id] = kit
end

function Catalog.find(id)
    return playableById[id]
end

function Catalog.kit(id)
    return kitsById[id]
end

function Catalog.verified(league)
    local records = {}
    for _,player in ipairs(Catalog.realPlayers) do
        if not league or player.league == league then
            records[#records+1] = player
        end
    end
    return records
end
end

-- Ultimate
do
-- PolyLax Ultimate | local collection, squad, and profile persistence
PolyLax = PolyLax or {}
local Ultimate = {}
PolyLax.Ultimate = Ultimate

local Catalog = assert(PolyLax.UltimateCatalog, "Load UltimateCatalog before Ultimate")
Ultimate.version = 3
Ultimate.players = Catalog.players
Ultimate.researchCandidates = Catalog.researchCandidates
Ultimate.realPlayers = Catalog.realPlayers
Ultimate.kits = Catalog.kits
Ultimate.sources = Catalog.sources
Ultimate.releasePolicy = Catalog.releasePolicy
Ultimate.disclaimer = Catalog.disclaimer
Ultimate.slotRoles = {"A","A","A","M","M","M","D","D","D","G"}

-- Only enable in a private source build. It uses a separate save from public builds.
local developerBuild = false
local storageKey = "PolyLax.Ultimate.Collection.3" .. (developerBuild and ".Dev" or "")
local legacyKeys = {"PolyLax.Ultimate.Collection.2", "PolyLax.Ultimate.Collection"}
local maxHistory = 20

function Ultimate.isDeveloperBuild()
    return developerBuild
end

function Ultimate.catalog(league, includeResearch)
    local source = includeResearch and Ultimate.researchCandidates or Ultimate.players
    local results = {}
    for _, player in ipairs(source or {}) do
        if not league or player.league == league then results[#results+1] = player end
    end
    return results
end

function Ultimate.find(id)
    return Catalog.find(id)
end

function Ultimate.kit(id)
    return Catalog.kit(id)
end

function Ultimate.displayName(player)
    return player and (player.displayName or player.name) or "Unknown player"
end

function Ultimate.role(player)
    if not player then return nil end
    local position = player.position or player.role
    if position == "F" then return "A" end
    if position == "T" or position == "FO" or position == "FOGO" or position == "FACEOFF"
        or position == "LSM" or position == "SSDM" then
        return "M"
    end
    return position
end

function Ultimate.identity(player)
    return player and (player.identity or player.id)
end

function Ultimate.isCollectible(player)
    return player and player.playable == true and (player.fictional == true or player.verification == "verified")
end

function Ultimate.defaultCollection()
    return {
        version=Ultimate.version,
        cards={}, nextCardId=1, squad={}, equippedKit="field_violet",
        coins=0, unopenedPacks=0, completedSBC={}, starterGranted=false,
        matches=0, wins=0, draws=0, losses=0, nextMatchId=1, matchHistory={},
        testGoldGranted=false
    }
end

local function nonnegativeInt(value)
    local n = tonumber(value)
    if not n or n ~= n or n < 0 or n >= 9007199254740991 then return 0 end
    return math.floor(n)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function statValues(raw)
    local values = {}
    if type(raw) == "table" then
        for key, value in pairs(raw) do
            if type(key) == "string" and #key <= 32 and type(value) == "number"
                and math.abs(value) < math.huge then values[key] = value end
        end
    end
    return values
end

-- Keep the box score required by StatsUI, without the per-frame match event log.
function Ultimate.resultBox(raw, matchId, ownScore, opponentScore)
    if type(raw) ~= "table" or raw.final ~= true or raw.id ~= "ultimate:match:"..matchId
        or raw.homeScore ~= ownScore or raw.awayScore ~= opponentScore
        or type(raw.sides) ~= "table" or type(raw.players) ~= "table" then return end
    local box = {id=raw.id,source="played",mode="ULTIMATE TEAM",final=true,
        homeScore=ownScore,awayScore=opponentScore,sides={},players={}}
    for index=1,2 do
        local side = raw.sides[index]
        if type(side) ~= "table" or type(side.name) ~= "string" or type(side.roster) ~= "table"
            or #side.roster ~= 10 then return end
        local line = {name=side.name:sub(1,60),id=side.id,roster={},
            stats=statValues(side.stats),rates=statValues(side.rates)}
        box.sides[index] = line
        for slot=1,10 do
            local id = side.roster[slot]
            if type(id) ~= "string" or #id > 80 or box.players[id] then return end
            local player = raw.players[id]
            if type(player) ~= "table" or type(player.name) ~= "string" then return end
            box.players[id] = {playerId=id,teamId=line.id,slot=slot,name=player.name:sub(1,100),
                number=nonnegativeInt(player.number),role=type(player.role)=="string" and player.role:sub(1,12),
                stats=statValues(player.stats),rates=statValues(player.rates)}
            line.roster[slot] = id
        end
    end
    box.homeId,box.awayId = box.sides[1].id,box.sides[2].id
    if type(raw.playerOfGame)=="string" and box.players[raw.playerOfGame] then
        box.playerOfGame=raw.playerOfGame
    end
    return box
end

local function addInstance(collection, id)
    local uid = "card-" .. tostring(collection.nextCardId)
    collection.cards[uid] = id
    collection.nextCardId = collection.nextCardId + 1
    return uid
end

-- Raw inventory operations are used inside Ultimate.transact.
function Ultimate.addCard(collection, id)
    if not Ultimate.isCollectible(Ultimate.find(id)) then return false, "Unknown player" end
    return true, addInstance(collection, id)
end

function Ultimate.resolveCard(collection, uid)
    if type(uid) ~= "string" then return nil end
    return Ultimate.find(collection.cards[uid])
end

function Ultimate.ownedCards(collection)
    local cards = {}
    for uid, id in pairs(collection.cards) do
        local player = Ultimate.find(id)
        if player then cards[#cards+1] = {uid=uid, id=id, player=player} end
    end
    table.sort(cards, function(a, b)
        if a.id == b.id then return a.uid < b.uid end
        return a.id < b.id
    end)
    return cards
end

function Ultimate.removeCard(collection, uid)
    if not Ultimate.resolveCard(collection, uid) then return false, "Card not owned" end
    collection.cards[uid] = nil
    for slot, equipped in pairs(collection.squad) do
        if equipped == uid then collection.squad[slot] = nil end
    end
    return true
end

local function restoreCards(collection, raw)
    local firstCopy = {}
    if type(raw.cards) == "table" then
        collection.nextCardId = math.max(1, nonnegativeInt(raw.nextCardId))
        for uid, id in pairs(raw.cards) do
            local sequence = type(uid) == "string" and uid:match("^card%-(%d+)$")
            if sequence and type(id) == "string" then
                collection.cards[uid] = id
                collection.nextCardId = math.max(collection.nextCardId, nonnegativeInt(sequence) + 1)
            end
        end
    elseif type(raw.owned) == "table" then
        local ids = {}
        for id in pairs(raw.owned) do
            if type(id) == "string" then ids[#ids+1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            -- The previous research build represented each player by an ID and quantity.
            -- Keep IDs even if a catalog update temporarily removes a card.
            for _ = 1, nonnegativeInt(raw.owned[id]) do
                local uid = addInstance(collection, id)
                firstCopy[id] = firstCopy[id] or uid
            end
        end
    end
    if type(raw.squad) ~= "table" then return end
    local seen = {}
    for slot, role in ipairs(Ultimate.slotRoles) do
        local saved = raw.squad[tostring(slot)] or raw.squad[slot]
        local uid = firstCopy[saved] or saved
        local player = Ultimate.resolveCard(collection, uid)
        local identity = Ultimate.identity(player)
        if player and Ultimate.role(player) == role and not seen[identity] then
            collection.squad[slot] = uid
            seen[identity] = true
        end
    end
end

local function restoreMatches(collection, raw)
    collection.matches = math.max(collection.matches, collection.wins + collection.draws + collection.losses)
    local nextMatchId = math.max(1, nonnegativeInt(raw.nextMatchId))
    local activeMatch = nonnegativeInt(raw.activeMatch)
    local seen = {}
    if type(raw.matchHistory) == "table" then
        for index = math.max(1, #raw.matchHistory - maxHistory + 1), #raw.matchHistory do
            local entry = raw.matchHistory[index]
            if type(entry) == "table" then
                local id = nonnegativeInt(entry.id)
                local result = entry.result
                if id > 0 and not seen[id] and (result == "win" or result == "draw" or result == "loss") then
                    local record = {
                        id=id, result=result, payout=nonnegativeInt(entry.payout),
                        ownScore=entry.ownScore and nonnegativeInt(entry.ownScore),
                        opponentScore=entry.opponentScore and nonnegativeInt(entry.opponentScore)
                    }
                    record.box = Ultimate.resultBox(entry.box,id,record.ownScore,record.opponentScore)
                    collection.matchHistory[#collection.matchHistory+1] = record
                    nextMatchId = math.max(nextMatchId, id+1)
                    seen[id] = true
                end
            end
        end
    end
    if activeMatch > 0 and not seen[activeMatch] then
        collection.activeMatch = activeMatch
        nextMatchId = math.max(nextMatchId, activeMatch+1)
    end
    collection.nextMatchId = nextMatchId
end

local function restore(raw)
    local collection = Ultimate.defaultCollection()
    for _, key in ipairs({"coins","unopenedPacks","matches","wins","draws","losses"}) do
        collection[key] = nonnegativeInt(raw[key])
    end
    collection.starterGranted = raw.starterGranted == true
    collection.testGoldGranted = raw.testGoldGranted == true
    if Ultimate.kit(raw.equippedKit) then collection.equippedKit = raw.equippedKit end
    if type(raw.completedSBC) == "table" then
        for id, complete in pairs(raw.completedSBC) do
            if type(id) == "string" and complete == true then collection.completedSBC[id] = true end
        end
    end
    restoreCards(collection, raw)
    restoreMatches(collection, raw)
    return collection
end

local function readCollection(key)
    local read, raw = pcall(readLocalData, key)
    if not read then return nil, "Could not read the Ultimate Team save" end
    if raw == nil then return nil end
    local decoded, data = pcall(function() return json.decode(raw) end)
    if not decoded or type(data) ~= "table" then
        return nil, "Ultimate Team save could not be opened"
    end
    local version = data.version == nil and 2 or tonumber(data.version)
    if not version or version % 1 ~= 0 or version < 2 or version > Ultimate.version then
        return nil, "Ultimate Team save could not be opened"
    end
    return restore(data)
end

function Ultimate.load()
    local collection, err = readCollection(storageKey)
    if not collection and not err and not developerBuild then
        for _, key in ipairs(legacyKeys) do
            collection, err = readCollection(key)
            if collection or err then break end
        end
    end
    if collection then return collection end
    collection = Ultimate.defaultCollection()
    -- Leave an unreadable save intact. Purchases and awards remain blocked until it can be loaded.
    collection.loadError = err
    return collection
end

function Ultimate.save(collection)
    if collection.loadError then return false, collection.loadError end
    local snapshot = copy(collection)
    -- A squad with open slots is a dictionary, not a JSON array with holes.
    snapshot.squad = {}
    for slot, uid in pairs(collection.squad) do snapshot.squad[tostring(slot)] = uid end
    local encoded, raw = pcall(function() return json.encode(snapshot) end)
    if not encoded or type(raw) ~= "string" then return false, "Could not encode the Ultimate Team save" end
    local written, result = pcall(saveLocalData, storageKey, raw)
    if not written or result == false then return false, "Could not save Ultimate Team" end
    return true
end

function Ultimate.transact(collection, change)
    if collection.loadError then return false, collection.loadError end
    local draft = copy(collection)
    local ok, result = change(draft)
    if not ok then return false, result end
    local saved, err = Ultimate.save(draft)
    if not saved then return false, err end
    for key in pairs(collection) do collection[key] = nil end
    for key, value in pairs(draft) do collection[key] = value end
    return true, result
end

function Ultimate.equip(collection, slot, uid)
    if not Ultimate.slotRoles[slot] then return false, "Invalid slot" end
    local player = Ultimate.resolveCard(collection, uid)
    if not player then return false, "Card not owned" end
    if Ultimate.role(player) ~= Ultimate.slotRoles[slot] then return false, "Wrong position" end
    for otherSlot, otherUid in pairs(collection.squad) do
        local other = Ultimate.resolveCard(collection, otherUid)
        if otherSlot ~= slot and other and Ultimate.identity(player) == Ultimate.identity(other) then
            return false, "This athlete already starts in another slot"
        end
    end
    return Ultimate.transact(collection, function(draft)
        draft.squad[slot] = uid
        return true
    end)
end

function Ultimate.unequip(collection, slot)
    if not Ultimate.slotRoles[slot] then return false, "Invalid slot" end
    return Ultimate.transact(collection, function(draft)
        draft.squad[slot] = nil
        return true
    end)
end

function Ultimate.equipKit(collection, id)
    if not Ultimate.kit(id) then return false, "Unknown jersey" end
    return Ultimate.transact(collection, function(draft)
        draft.equippedKit = id
        return true
    end)
end
end

-- UltimateEconomy
do
-- PolyLax Ultimate | earn-only starter packs, packs, wheel, and match rewards
PolyLax = PolyLax or {}
local U = assert(PolyLax.Ultimate, "Load Ultimate before UltimateEconomy")
local E = {}
U.Economy = E

E.packSize = 5
E.wheelCost = 1200
E.packCost = 3500
E.rates = {
    {tier="elite", minimum=90, maximum=99, weight=20},
    {tier="high", minimum=85, maximum=89, weight=35},
    {tier="core", minimum=75, maximum=84, weight=45}
}
E.matchRewards = {win=450, draw=250, loss=150}
local developerBuild = U.isDeveloperBuild()
local highMinimum = E.rates[2].minimum
local maxHistory = 20

function E.rating(player)
    return player and player.rating
end

local function eligiblePools()
    local pools = {}
    for _, tier in ipairs(E.rates) do
        local pool = {}
        for _, player in ipairs(U.players) do
            local rating = E.rating(player)
            if U.isCollectible(player) and type(rating) == "number"
                and rating >= tier.minimum and rating <= tier.maximum then
                pool[#pool+1] = player
            end
        end
        if #pool == 0 then return nil, "No eligible " .. tier.tier .. " cards" end
        pools[tier.tier] = pool
    end
    return pools
end

local function draw(pools, rng, minimumRating)
    local total = 0
    for _, tier in ipairs(E.rates) do
        if tier.minimum >= minimumRating then total = total + tier.weight end
    end
    local roll = rng(1, total)
    for _, tier in ipairs(E.rates) do
        if tier.minimum >= minimumRating then
            roll = roll - tier.weight
            if roll <= 0 then
                local pool = pools[tier.tier]
                local player = pool[rng(1, #pool)]
                return {
                    id=player.id, name=U.displayName(player), position=player.position, role=U.role(player),
                    league=player.league, season=player.season, rating=E.rating(player), tier=tier.tier
                }
            end
        end
    end
end

local function mint(draft, results)
    for _, card in ipairs(results) do
        local ok, uid = U.addCard(draft, card.id)
        if not ok then return false, uid end
        card.uid = uid
    end
    return true
end

local function open(collection, starter, rng)
    if starter and collection.starterGranted then return false, "Starter already claimed" end
    if not starter and collection.unopenedPacks < 1 then return false, "No unopened packs" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    local results = {}
    for i = 1, E.packSize do
        local minimum = starter and i == E.packSize and highMinimum or 0
        results[i] = draw(pools, rng or math.random, minimum)
    end
    return U.transact(collection, function(draft)
        local ok, mintError = mint(draft, results)
        if not ok then return false, mintError end
        if starter then
            draft.starterGranted = true
        else
            draft.unopenedPacks = draft.unopenedPacks - 1
        end
        return true, results
    end)
end

function E.grantStarter(collection, rng)
    return open(collection, true, rng)
end

function E.openPack(collection, rng)
    return open(collection, false, rng)
end

function E.buyPack(collection)
    if collection.coins < E.packCost then return false, "Not enough gold" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    return U.transact(collection, function(draft)
        draft.coins = draft.coins - E.packCost
        draft.unopenedPacks = draft.unopenedPacks + 1
        return true
    end)
end

function E.spin(collection, rng)
    if collection.coins < E.wheelCost then return false, "Not enough gold" end
    local pools, err = eligiblePools()
    if not pools then return false, err end
    local card = draw(pools, rng or math.random, 0)
    return U.transact(collection, function(draft)
        local ok, mintError = mint(draft, {card})
        if not ok then return false, mintError end
        draft.coins = draft.coins - E.wheelCost
        return true, card
    end)
end

function E.canGrantTestGold(collection)
    return developerBuild and collection and not collection.testGoldGranted and not collection.loadError
end

function E.grantTestGold(collection)
    if not developerBuild then return false, "Developer mode disabled" end
    if collection.testGoldGranted then return false, "Test gold already claimed" end
    return U.transact(collection, function(draft)
        draft.coins = draft.coins + 1000000
        draft.testGoldGranted = true
        return true, draft.coins
    end)
end

function E.resetTestProgress(collection)
    if not developerBuild then return false, "Developer mode disabled" end
    return U.transact(collection, function(draft)
        local fresh = U.defaultCollection()
        fresh.testGoldGranted = draft.testGoldGranted
        fresh.nextMatchId, fresh.nextCardId = draft.nextMatchId, draft.nextCardId
        for key in pairs(draft) do draft[key] = nil end
        for key, value in pairs(fresh) do draft[key] = value end
        return true
    end)
end

function E.beginMatch(collection)
    return U.transact(collection, function(draft)
        local id = draft.nextMatchId
        draft.nextMatchId = id+1
        draft.activeMatch = id
        return true, id
    end)
end

function E.abandonMatch(collection, id)
    if not id or collection.activeMatch ~= id then return false, "Match is no longer active" end
    return U.transact(collection, function(draft)
        draft.activeMatch = nil
        return true
    end)
end

function E.recordMatch(collection, result, id, ownScore, opponentScore, boxScore)
    local payout = E.matchRewards[result]
    if not payout then return false, "Invalid match result" end
    if not id or collection.activeMatch ~= id then return false, "Match is no longer active" end
    if ownScore ~= nil or opponentScore ~= nil then
        if type(ownScore) ~= "number" or ownScore < 0 or ownScore % 1 ~= 0
            or type(opponentScore) ~= "number" or opponentScore < 0 or opponentScore % 1 ~= 0 then
            return false, "Invalid score"
        end
        local actual = ownScore == opponentScore and "draw" or (ownScore > opponentScore and "win" or "loss")
        if actual ~= result then return false, "Result does not match score" end
    end
    local record = {id=id, result=result, payout=payout, ownScore=ownScore, opponentScore=opponentScore}
    if boxScore then
        record.box = U.resultBox(boxScore,id,ownScore,opponentScore)
        if not record.box then return false,"Invalid final box score" end
    end
    return U.transact(collection, function(draft)
        draft.coins = draft.coins + payout
        draft.matches = draft.matches + 1
        local category = result == "loss" and "losses" or result .. "s"
        draft[category] = draft[category] + 1
        draft.activeMatch = nil
        local history = draft.matchHistory
        history[#history+1] = record
        if #history > maxHistory then table.remove(history, 1) end
        return true, record
    end)
end
end

-- UltimateSBC
do
-- PolyLax Ultimate | Squad Building Challenges
PolyLax = PolyLax or {}
local U = assert(PolyLax.Ultimate, "Ultimate.lua required")
local SBC = {}
U.SBC = SBC

SBC.challenges = {
    {id="starter_exchange",name="First Trade",slots=2,repeatable=false,
        reward={coins=250,pack=1},rules={minLeagues=1}},
    {id="field_specialists",name="Field Specialists",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="PLL",positions={"A","M","D"},minOverall=80}},
    {id="box_experts",name="Box Experts",slots=3,repeatable=false,
        reward={coins=600,pack=1},rules={league="NLL",positions={"A","M","G"},minOverall=82}},
    {id="heritage",name="Heritage Exchange",slots=3,repeatable=false,
        reward={coins=650,pack=1},rules={league="MLL",positions={"A","D","G"},minOverall=82}},
    {id="cross_league",name="Cross-League Chemistry",slots=4,repeatable=false,
        reward={coins=1200,pack=2},rules={positions={"A","M","D","G"},
            minLeagues=2,minOverall=82,minChemistry=2}},
    {id="ultimate_mix",name="Ultimate Trio",slots=6,repeatable=false,
        reward={coins=2000,pack=3},rules={positions={"A","A","M","FO","D","G"},
            minLeagues=3,minOverall=85,minChemistry=4}}
}

local leagueNames = {PLL="PLL",MLL="MLL",NLL="NLL"}
local positions = {A="ATT",M="MID",D="DEF",G="G",FO="FOGO",LSM="LSM",SSDM="SSDM"}
local positionAliases = {F="A",T="M",FACEOFF="FO",FOGO="FO"}

local function positionCode(position)
    return positionAliases[position] or position
end

function SBC.find(challengeId)
    for _, challenge in ipairs(SBC.challenges) do
        if challenge.id == challengeId then return challenge end
    end
end

function SBC.requirements(challenge)
    local rules = challenge.rules
    local requirements = {challenge.slots.." cards"}
    if rules.league then
        requirements[1] = challenge.slots.." "..leagueNames[rules.league].." cards"
    elseif (rules.minLeagues or 1) > 1 then
        requirements[#requirements+1] = rules.minLeagues.."+ leagues"
    end
    if rules.minOverall then
        requirements[#requirements+1] = rules.minOverall.."+ Avg OVR"
    end
    return table.concat(requirements," · ")
end

function SBC.positionLabel(position)
    return positions[positionCode(position)] or "ANY"
end

function SBC.positionForSlot(challenge, slot)
    return challenge.rules.positions and challenge.rules.positions[slot]
end

function SBC.isComplete(collection, challenge)
    return not challenge.repeatable and collection.completedSBC
        and collection.completedSBC[challenge.id] == true
end

function SBC.isEquipped(collection, uid)
    for _, id in pairs(collection.squad or {}) do
        if id == uid then return true end
    end
    return false
end

function SBC.allows(challenge, player, slot)
    if not player or player.playable==false or player.verification=="pending" or not leagueNames[player.league] then
        return false,"Only collectible cards can be used"
    end
    local league = challenge.rules.league
    if league and player.league~=league then return false,"Use "..league.." cards" end
    local required = positionCode(SBC.positionForSlot(challenge, slot))
    if required and required~=U.role(player) and required~=positionCode(player.position or player.role) then
        return false,"Slot "..slot.." needs "..SBC.positionLabel(required)
    end
    local rating = U.Economy.rating(player)
    if type(rating)~="number" or rating<0 or rating>99 or rating~=rating then
        return false,"This card has no valid rating"
    end
    return true
end

local function progress(collection, challenge, cardIds)
    local metrics = {cards=0,leagues=0,ratingTotal=0,overall=0,chemistry=0}
    local used, leagueCount = {}, {}
    for slot=1,challenge.slots do
        local uid = cardIds[slot]
        local player = type(uid)=="string" and U.resolveCard(collection,uid)
        if uid~=nil then
            if type(uid)~="string" then
                metrics.issue = metrics.issue or "Invalid card selection"
            elseif used[uid] then
                metrics.issue = metrics.issue or "Each card copy can fill one slot"
            elseif not player then
                metrics.issue = metrics.issue or "A selected card is no longer owned"
            else
                local allowed, reason = SBC.allows(challenge,player,slot)
                if allowed then
                    used[uid] = true
                    local linked = leagueCount[player.league] or 0
                    if linked==0 then metrics.leagues = metrics.leagues+1 end
                    -- This card gains one point per previously placed card from its league.
                    metrics.chemistry = metrics.chemistry+linked
                    leagueCount[player.league] = linked+1
                    metrics.cards = metrics.cards+1
                    metrics.ratingTotal = metrics.ratingTotal+U.Economy.rating(player)
                else
                    metrics.issue = metrics.issue or reason
                end
            end
        end
    end
    if metrics.cards>0 then metrics.overall = metrics.ratingTotal/metrics.cards end
    return metrics
end

function SBC.validate(collection, challengeId, cardIds)
    local challenge = SBC.find(challengeId)
    if not challenge then return false, "Unknown challenge" end
    if SBC.isComplete(collection, challenge) then return false, "Exchange completed" end
    if type(cardIds) ~= "table" then return false, "Choose "..challenge.slots.." cards" end
    for slot in pairs(cardIds) do
        if type(slot) ~= "number" or slot%1 ~= 0 or slot < 1 or slot > challenge.slots then
            return false, "Invalid card slot"
        end
    end

    local metrics = progress(collection,challenge,cardIds)
    if metrics.issue then return false,metrics.issue,metrics end
    if metrics.cards<challenge.slots then return false,"Choose "..challenge.slots.." cards",metrics end
    local rules = challenge.rules
    if metrics.leagues<(rules.minLeagues or 1) then
        return false,"Add cards from more leagues",metrics
    end
    if rules.minOverall and metrics.ratingTotal<rules.minOverall*challenge.slots then
        return false,"Raise your squad's average OVR",metrics
    end
    if metrics.chemistry<(rules.minChemistry or 0) then
        return false,"Add more same-league pairs",metrics
    end
    return true,challenge,metrics
end

function SBC.submit(collection, challengeId, cardIds)
    return U.transact(collection, function(draft)
        local valid, challenge = SBC.validate(draft, challengeId, cardIds)
        if not valid then return false, challenge end
        for slot = 1, challenge.slots do
            local removed, reason = U.removeCard(draft, cardIds[slot])
            if not removed then return false, reason end
        end
        local coins, packs = challenge.reward.coins, challenge.reward.pack
        draft.coins = (draft.coins or 0)+coins
        draft.unopenedPacks = (draft.unopenedPacks or 0)+packs
        draft.completedSBC = draft.completedSBC or {}
        draft.completedSBC[challengeId] = true
        return true, {coins=coins,packs=packs}
    end)
end
end

-- UltimateSBCUI
do
-- PolyLax Ultimate | challenge field, collection picker, and exchange review
PolyLax = PolyLax or {}
local P = PolyLax
local U = assert(P.Ultimate, "Ultimate.lua required")
local SBC = assert(U.SBC, "UltimateSBC.lua required")
local UI = {}
U.SBCUI = UI

local ink = color(243,241,229)
local muted = color(165,183,174)
local gold = color(247,209,119)
local green = color(104,210,155)
local red = color(236,150,134)
local backgroundInk = color(11,17,20)
local panelInk = color(24,34,35)
local panelBorder = color(49,67,62)
local goldPanel = color(91,73,32)
local fieldBase = color(19,56,45)
local fieldStripe = color(24,64,48)
local fieldLine = color(113,151,121,155)
local shadow = color(4,10,9,175)
local cardInk = color(13,23,24)
local tierColors = {
    elite=color(239,193,101), high=color(131,193,170), core=color(170,179,165)
}

-- Advance up the field from goalie and defense through midfield to attack.
local formations = {
    [2]={{.30,.60},{.70,.60}},
    [3]={{.50,.77},{.27,.52},{.50,.25}},
    [4]={{.50,.80},{.27,.58},{.72,.50},{.50,.23}},
    [6]={{.33,.78},{.67,.78},{.23,.52},{.50,.52},{.77,.48},{.50,.22}}
}

local function box(x, y, w, h)
    return {x=x,y=y,w=w,h=h}
end

local function surface(b, tint, radius)
    P.Style.rounded(b.x,b.y,b.w,b.h,radius or 10,tint)
end

local function outlined(b, tint, border, radius)
    radius = radius or 10
    surface(b,border,radius)
    surface(box(b.x,b.y,b.w-2,b.h-2),tint,radius-1)
end

local function label(value, x, y, size, tint, width)
    fontSize(size)
    if width and textSize then
        local used = textSize(value)
        if used > width then fontSize(math.max(8,size*width/used)) end
    end
    fill(tint or ink)
    text(value,x,y)
end

local function leftLabel(value, x, y, size, tint, width)
    textMode(CORNER)
    label(value,x,y-size*.56,size,tint,width)
    textMode(CENTER)
end

local function button(b, value, active)
    surface(box(b.x,b.y-2,b.w,b.h),shadow)
    outlined(b,active and goldPanel or panelInk,active and gold or panelBorder)
    label(value,b.x,b.y,12,active and gold or muted,b.w-10)
end

local function hit(b, touch)
    return P.UI.hit(b,touch.x,touch.y)
end

local function challenge(state)
    return SBC.challenges[state.challenge]
end

function UI.new(collection)
    return {collection=collection,challenge=1,entries={},drafts={},selected=1,
        page=1,view="field",time=0}
end

local function refreshChoices(state)
    local used = {}
    for index, uid in pairs(state.entries) do
        if index ~= state.selected then used[uid] = true end
    end
    local list, ch = {}, challenge(state)
    for _, owned in ipairs(U.ownedCards(state.collection)) do
        if not used[owned.uid] and SBC.allows(ch,owned.player,state.selected) then
            list[#list+1] = owned
        end
    end
    table.sort(list,function(a,b)
        local ra, rb = U.Economy.rating(a.player), U.Economy.rating(b.player)
        if ra ~= rb then return ra > rb end
        local na, nb = U.displayName(a.player), U.displayName(b.player)
        if na ~= nb then return na < nb end
        return a.uid < b.uid
    end)
    state.options = list
end

local function changeChallenge(state, direction)
    state.drafts[challenge(state).id] = state.entries
    state.challenge = (state.challenge-1+direction)%#SBC.challenges+1
    state.entries = state.drafts[challenge(state).id] or {}
    state.selected, state.message = 1, nil
end

local function fieldSlots(count)
    if formations[count] then return formations[count] end
    local points = {}
    local columns = math.min(count,3)
    local rows = math.ceil(count/columns)
    for index=1,count do
        local row = math.floor((index-1)/columns)
        local inRow = math.min(columns,count-row*columns)
        points[index] = {((index-1)%columns+1)/(inRow+1),1-(row+.5)/rows}
    end
    return points
end

function UI.layout(state)
    local safe = P.UI.safeArea()
    local width = math.min(460,WIDTH-safe.left-safe.right-26)
    local cx = (WIDTH+safe.left-safe.right)*.5
    local top, bottom = HEIGHT-safe.top-9, safe.bottom+11
    local left, right = cx-width*.5,cx+width*.5
    local fieldTop, fieldBottom = top-154,bottom+98
    local fieldHeight = fieldTop-fieldBottom
    local f = box(cx,fieldBottom+fieldHeight*.5,width,fieldHeight)
    local slots, ch = {},challenge(state)
    local slotHeight = math.min(83,fieldHeight*math.min(.235,.85/math.ceil(ch.slots/3)))
    for i, point in ipairs(ch.formation or fieldSlots(ch.slots)) do
        slots[i] = box(left+point[1]*width,fieldBottom+point[2]*fieldHeight,
            math.min(77,width*.216),slotHeight)
    end

    local rowH = math.min(53,math.max(35,(top-bottom-168)/6))
    local count = math.floor((top-bottom-154)/(rowH+5))
    local rows = math.max(1,math.min(8,count))
    local pageItems = {}
    if state.view == "picker" then
        local start = (state.page-1)*rows
        for i=1,rows do
            if state.options[start+i] then
                pageItems[i] = box(cx,top-99-(i-1)*(rowH+5),width,rowH)
            end
        end
    end
    local review = box(cx,bottom+28,math.min(154,width*.5),43)
    local confirmWidth = math.min(100,(width-review.w-14)*.5)
    local confirm = box(right-confirmWidth*.5,bottom+28,confirmWidth,43)
    local cancel = box(left+confirmWidth*.5,bottom+28,confirmWidth,43)
    return {left=left,right=right,width=width,x=cx,top=top,bottom=bottom,field=f,slots=slots,
        back=box(left+32,top-22,64,37),review=review,confirm=confirm,cancel=cancel,
        previous=box(left+19,top-72,38,40),next=box(right-19,top-72,38,40),
        pickerPrev=box(left+22,bottom+24,44,37),pickerNext=box(right-22,bottom+24,44,37),
        remove=box(cx,bottom+25,130,38),rows=rows,pageItems=pageItems,
        exchangeRow=math.min(42,(top-bottom-170)/ch.slots)}
end

local function tierOf(player)
    local rating = U.Economy.rating(player)
    return rating, rating >= 90 and tierColors.elite or rating >= 85 and tierColors.high or tierColors.core
end

local function pitch(l)
    local f = l.field
    surface(f,fieldBase,12)
    rectMode(CENTER)
    for i=1,4 do
        fill(fieldStripe)
        rect(f.x,f.y-f.h*.5+(i*2-.5)*f.h/8,f.w-12,f.h/8-1)
    end
    stroke(fieldLine)
    strokeWidth(1)
    noFill()
    rect(f.x,f.y,f.w-14,f.h-13)
    line(f.x-f.w*.5+7,f.y,f.x+f.w*.5-7,f.y)
    ellipseMode(CENTER)
    ellipse(f.x,f.y,math.min(67,f.h*.27))
    for _, side in ipairs({-1,1}) do
        local goalY = f.y+f.h*.39*side
        line(f.x-f.w*.5+7,f.y+f.h*.263*side,f.x+f.w*.5-7,f.y+f.h*.263*side)
        ellipse(f.x,goalY,math.min(29,f.h*.13))
        rect(f.x,goalY,14,6)
    end
    noStroke()
end

local function drawCard(b, player, current, position)
    surface(box(b.x,b.y-2,b.w,b.h),shadow,8)
    if not player then
        outlined(b,cardInk,current and gold or panelBorder,8)
        label("+",b.x,b.y+2,23,current and gold or green)
        label(SBC.positionLabel(position),b.x,b.y-b.h*.3,9,muted)
        return
    end
    local rating, tier = tierOf(player)
    outlined(b,tier,current and gold or cardInk,8)
    local name = U.displayName(player)
    label(tostring(rating),b.x,b.y+b.h*.26,17,cardInk)
    label(name:match("([^ ]+)$") or name,b.x,b.y-1,11,cardInk,b.w-5)
    label(player.league.." · "..SBC.positionLabel(player.position or U.role(player)),b.x,b.y-b.h*.31,9,cardInk,b.w-5)
end

local function drawField(state, l, ch)
    surface(box(l.x,l.top-72,l.width,48),panelInk)
    label(ch.name,l.x,l.top-66,16,gold,l.width-88)
    label(state.challenge.." / "..#SBC.challenges,l.x,l.top-83,10,muted)
    button(l.previous,"‹")
    button(l.next,"›")
    local complete = SBC.isComplete(state.collection,ch)
    local valid, detail, metrics = SBC.validate(state.collection,ch.id,state.entries)
    label(SBC.requirements(ch),l.x,l.top-104,12,ink,l.width-10)
    if complete then
        label("Exchange completed",l.x,l.top-123,11,green,l.width-10)
    elseif metrics and (ch.rules.minOverall or ch.rules.minChemistry) then
        local progress = {}
        if ch.rules.minOverall then
            local overall = metrics.cards>0 and ("%.1f"):format(metrics.overall) or "—"
            progress[1] = "Avg OVR "..overall.."/"..ch.rules.minOverall
        end
        if ch.rules.minChemistry then
            progress[#progress+1] = ("Chemistry %d/%d"):format(metrics.chemistry,ch.rules.minChemistry)
            label("+1 chemistry per same-league pair",l.x,l.top-138,10,muted,l.width-10)
        end
        label(table.concat(progress," · "),l.x,l.top-122,11,valid and green or muted,l.width-10)
    end
    pitch(l)
    for index, slot in ipairs(l.slots) do
        drawCard(slot,U.resolveCard(state.collection,state.entries[index]),index==state.selected,
            SBC.positionForSlot(ch,index))
    end
    label("REWARD   "..ch.reward.coins.." GOLD   +   "..ch.reward.pack..
        (ch.reward.pack==1 and " PACK" or " PACKS"),l.x,l.bottom+82,11,gold,l.width)
    label(state.message or (valid and "Squad ready" or detail),l.x,l.bottom+61,11,
        state.message and (complete and green or red) or muted,l.width)
    if valid then
        local pulse = math.floor(35+30*(1+math.sin(state.time*3)))
        surface(box(l.review.x,l.review.y,l.review.w+5,l.review.h+4),
            color(247,209,119,pulse))
    end
    button(l.review,complete and "Completed" or "Review exchange",valid)
end

local function cardRow(item, player, equipped, selected)
    outlined(item,panelInk,selected and gold or panelBorder,8)
    local rating,tier = tierOf(player)
    local cx = item.x-item.w*.5+24
    surface(box(cx,item.y,31,30),tier,7)
    label(tostring(rating),cx,item.y,12,cardInk)
    leftLabel(U.displayName(player),cx+24,item.y+7,13,ink,item.w-67)
    local info = player.league.." · "..SBC.positionLabel(player.position or U.role(player))
        ..(equipped and " · In squad" or "")
    leftLabel(info,cx+24,item.y-10,10,equipped and gold or muted,item.w-67)
end

local function drawPicker(state, l)
    local ch = challenge(state)
    local position = SBC.positionLabel(SBC.positionForSlot(ch,state.selected))
    local league = ch.rules.league
    label("Slot "..state.selected.." · "..position..(league and (" · "..league) or ""),
        l.x,l.top-57,13,muted,l.width)
    if #state.options == 0 then
        label("No eligible cards are available.",l.x,l.field.y,15,muted,l.width)
    end
    local start = (state.page-1)*l.rows
    for index, item in ipairs(l.pageItems) do
        local owned = state.options[start+index]
        cardRow(item,owned.player,SBC.isEquipped(state.collection,owned.uid),
            state.entries[state.selected]==owned.uid)
    end
    local pages = math.max(1,math.ceil(#state.options/l.rows))
    label(state.page.." / "..pages,l.x,l.bottom+58,12,muted)
    button(l.pickerPrev,"‹",state.page>1)
    button(l.pickerNext,"›",state.page<pages)
    button(l.remove,"Remove card",state.entries[state.selected]~=nil)
end

local function drawReview(state, l, ch)
    label(ch.name,l.x,l.top-65,17,gold,l.width)
    label("These cards will leave your collection.",l.x,l.top-89,13,ink,l.width)
    local equipped = false
    for index, uid in ipairs(state.entries) do
        if index > ch.slots then break end
        local player = U.resolveCard(state.collection,uid)
        if player then
            local inSquad = SBC.isEquipped(state.collection,uid)
            equipped = equipped or inSquad
            cardRow(box(l.x,l.top-119-(index-1)*(l.exchangeRow+3),l.width,l.exchangeRow),
                player,inSquad,false)
        end
    end
    if equipped then label("Cards in your active lineup will be unequipped.",l.x,l.bottom+82,11,red,l.width) end
    label("Receive "..ch.reward.coins.." gold and "..ch.reward.pack..
        (ch.reward.pack==1 and " pack" or " packs"),l.x,l.bottom+61,12,gold,l.width)
    button(l.cancel,"Cancel")
    button(l.confirm,"Submit",true)
end

function UI.draw(state, dt)
    state.time = (state.time+math.min(dt or 0,.05))%1000
    local l, ch = UI.layout(state),challenge(state)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    background(backgroundInk)
    noStroke()
    rectMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    button(l.back,"‹ Back")
    local title = state.view=="picker" and "Choose a card"
        or state.view=="review" and "Confirm exchange" or "Squad Challenges"
    label(title,l.x+23,l.top-22,19,ink,l.width-110)
    if state.view=="picker" then
        drawPicker(state,l)
    elseif state.view=="review" then
        drawReview(state,l,ch)
    else
        drawField(state,l,ch)
    end
    popMatrix()
    popStyle()
    return l
end

function UI.touch(state, touch)
    if touch.state ~= BEGAN then return nil end
    local l, ch = UI.layout(state),challenge(state)
    if hit(l.back,touch) then
        if state.view=="field" then return "back" end
        state.view = "field"
        return "field"
    end
    if state.view=="picker" then
        local pages = math.max(1,math.ceil(#state.options/l.rows))
        if hit(l.pickerPrev,touch) then state.page=math.max(1,state.page-1);return "page" end
        if hit(l.pickerNext,touch) then state.page=math.min(pages,state.page+1);return "page" end
        if hit(l.remove,touch) then
            state.entries[state.selected],state.view = nil,"field"
            return "removed"
        end
        for index, item in ipairs(l.pageItems) do
            if hit(item,touch) then
                local owned = state.options[(state.page-1)*l.rows+index]
                state.entries[state.selected],state.view = owned.uid,"field"
                return "selected"
            end
        end
        return nil
    end
    if state.view=="review" then
        if hit(l.cancel,touch) then state.view="field";return "field" end
        if hit(l.confirm,touch) then
            local valid, result = SBC.submit(state.collection,ch.id,state.entries)
            state.view = "field"
            if valid then
                state.drafts[ch.id],state.entries,state.selected = nil,{},1
                state.message = "Exchange complete"
                return "completed"
            end
            state.message = result
            return "invalid"
        end
        return nil
    end
    if hit(l.previous,touch) then changeChallenge(state,-1);return "previous" end
    if hit(l.next,touch) then changeChallenge(state,1);return "next" end
    if SBC.isComplete(state.collection,ch) then return nil end
    for index, slot in ipairs(l.slots) do
        if hit(slot,touch) then
            state.selected,state.page,state.view,state.message = index,1,"picker",nil
            refreshChoices(state)
            return "picker"
        end
    end
    if hit(l.review,touch) then
        local valid, reason = SBC.validate(state.collection,ch.id,state.entries)
        if valid then state.view="review";return "review" end
        state.message = reason
        return "invalid"
    end
end
end

-- UltimateUI
do
-- Portrait Ultimate Team hub and collection management.
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.UltimateUI = UI

local ink = {
    deep=color(10,16,18), shadow=color(7,12,14), panel=color(21,29,31),
    elevated=color(27,38,39), muted=color(168,190,180), white=color(246,247,238),
    edge=color(51,71,63), dim=color(101,124,113), gold=color(244,207,124),
    goldDark=color(101,80,47), goldFill=color(48,40,26), green=color(110,225,173),
    greenFill=color(17,52,41), turf=color(14,44,35), stripe=color(17,53,42),
    fieldLine=color(93,141,115), rust=color(213,157,110), blue=color(137,202,225)
}

local sections = {
    {"SQUAD","My Squad","Set your starting ten","squad"},
    {"PACKS","Player Packs","Five players per pack","packs"},
    {"WHEEL","Gold Wheel","Spin for one player","wheel"},
    {"SBC","Squad Building","Challenges · SBC","sbc"},
    {"COLLECTION","My Collection","Browse owned cards","collection"},
    {"VAULT","Jersey Vault","Choose an original kit","jersey"},
    {"RECORD","Club Record","Results and box scores","record"}
}
local titles = {
    DASHBOARD="Ultimate Team", SQUAD="My Squad", PICK="Select Player",
    PACKS="Player Packs", WHEEL="Gold Wheel", COLLECTION="My Collection",
    VAULT="Jersey Vault", RECORD="Club Record", DEV="Developer Testing",
    DEV_CONFIRM="Reset Test Progress"
}
local roleNames = {A="Attack",M="Midfield",D="Defense",G="Goalie"}
local colors = {
    elite={border=ink.gold,base=ink.goldFill,label="Elite"},
    high={border=ink.blue,base=color(22,43,54),label="High"},
    core={border=ink.rust,base=color(47,35,30),label="Core"}
}

local function round(x,y,w,h,r,tint,press)
    P.Style.rounded(x,y,w,h,r,tint,press)
end

local function number(value)
    local raw=tostring(math.max(0,math.floor(tonumber(value) or 0)))
    local reversed=raw:reverse():gsub("(%d%d%d)","%1,")
    return (reversed:reverse():gsub("^,",""))
end

local function label(value,x,y,size,tint,maxWidth,left)
    if not value then return end
    fontSize(size)
    if maxWidth and textSize then
        local width=textSize(value)
        if width and width>maxWidth then
            size=math.max(8,size*maxWidth/width)
            fontSize(size)
        end
    end
    fill(tint)
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.55 or y)
    if left then textMode(CENTER) end
end

local function panel(x,y,w,h,theme,press,rad)
    rad=rad or 12
    round(x,y-2,w,h,rad,ink.shadow,press)
    round(x,y,w,h,rad,theme and theme.border or ink.edge,press)
    round(x,y,w-2,h-2,rad-1,theme and theme.base or ink.panel,press)
end

local function icon(kind,x,y,s,tint)
    fill(tint)
    if kind=="squad" then
        for n=-1,1 do
            ellipse(x+n*s*.3,y+s*.19,s*.18)
            round(x+n*s*.3,y-s*.07,s*.23,s*.2,s*.06,tint)
        end
    elseif kind=="packs" or kind=="collection" then
        round(x+s*.15,y+s*.08,s*.53,s*.69,s*.075,tint)
        local front=kind=="packs" and ink.greenFill or ink.panel
        round(x+s*.03,y+s*.02,s*.51,s*.65,s*.08,front)
        round(x-s*.1,y-s*.045,s*.51,s*.65,s*.08,tint)
        round(x-s*.1,y-s*.045,s*.35,s*.34,s*.05,front)
    elseif kind=="wheel" or kind=="gold" then
        ellipse(x,y,s*.68)
        fill(ink.goldFill)
        ellipse(x,y,s*.51)
        fill(tint)
        ellipse(x,y,s*.16)
        if kind=="wheel" then
            for n=1,6 do
                local a=n*math.pi/3
                ellipse(x+math.cos(a)*s*.26,y+math.sin(a)*s*.26,s*.07)
            end
        end
    elseif kind=="sbc" then
        for row=-1,1,2 do
            for col=-1,1,2 do
                round(x+col*s*.22,y+row*s*.16,s*.34,s*.24,s*.04,tint)
            end
        end
    elseif kind=="jersey" then
        round(x,y,s*.49,s*.61,s*.075,tint)
        round(x-s*.26,y+s*.13,s*.23,s*.29,s*.05,tint)
        round(x+s*.26,y+s*.13,s*.23,s*.29,s*.05,tint)
        fill(ink.panel)
        ellipse(x,y+s*.29,s*.21,s*.125)
    elseif kind=="play" then
        stroke(tint)
        strokeWidth(2)
        line(x-s*.2,y-s*.23,x+s*.27,y)
        line(x+s*.27,y,x-s*.2,y+s*.23)
        line(x-s*.2,y+s*.23,x-s*.2,y-s*.23)
        noStroke()
    elseif kind=="record" or kind=="dev" then
        for n=0,2 do
            local h=s*(.24+n*.15)
            round(x+(n-1)*s*.19,y-s*.29+h*.5,s*.105,h,2,tint)
        end
    elseif kind=="stick" then
        stroke(tint)
        strokeWidth(1.5)
        noFill()
        ellipse(x+s*.13,y+s*.18,s*.43,s*.38)
        line(x+s*.01,y+s*.03,x-s*.26,y-s*.31)
        line(x+s*.11,y+s*.32,x+s*.24,y+s*.09)
        noStroke()
    end
end

local function item(layout,id,labelText,x,y,w,h,options)
    local box=options or {}
    box.id,box.label,box.x,box.y,box.w,box.h=id,labelText,x,y,w,h
    layout.items[#layout.items+1]=box
    layout.byId[id]=box
    return box
end

local function gotoPage(ui,page)
    ui.page=page
    ui.messageText=nil
    ui.messageTime=0
    ui.listPage=1
    ui.press=nil
    ui.reveal=nil
end

function UI.new(profile)
    return {profile=profile,page="DASHBOARD",listPage=1,time=0,messageTime=0}
end

function UI.reset(ui)
    gotoPage(ui,"DASHBOARD")
    ui.sbc=nil
    ui.slot=nil
    if ui.profile.loadError then UI.message(ui,ui.profile.loadError) end
end

function UI.message(ui,message)
    ui.messageText=message and tostring(message)
    ui.messageTime=message and 3.5 or 0
end

local function getFrame()
    local safe=P.UI.safeArea()
    local w=math.min(450,WIDTH-safe.left-safe.right-28)
    local top,bottom=HEIGHT-safe.top-12,safe.bottom+12
    local x=(WIDTH+safe.left-safe.right)*.5
    return {x=x,w=w,top=top,bottom=bottom,body=top-105,floor=bottom+34,items={},byId={}}
end

local function dashboard(ui,l)
    local room=l.body-l.floor
    local hero=math.min(104,room*.26)
    local profile=ui.profile
    local title=ui.pendingResult and "Retry Result" or (ui.activeMatch and "Resume Match" or "Play Match")
    local record=string.format("10v10 vs CPU   ·   %dW  %dD  %dL",profile.wins,profile.draws,profile.losses)
    local detail=ui.pendingResult and "Save your completed result and reward" or record
    local history=profile.matchHistory
    local last=history[#history]
    local latest
    if last and not ui.pendingResult then
        local score=last.ownScore and last.opponentScore and string.format("  %d–%d",last.ownScore,last.opponentScore) or ""
        latest=string.format("Last %s%s  ·  +%s gold",last.result:upper(),score,number(last.payout))
    end
    item(l,"PLAY",title,l.x,l.body-hero*.5,l.w,hero,
        {kind="hero",icon="play",detail=detail,latest=latest})
    local col=(l.w-8)*.5
    local rows=math.ceil(#sections/2)
    local row=math.min(78,(room-hero-12-(rows-1)*8)/rows)
    local function dashboardItem(index,menu)
        local x=l.x+(index%2==1 and -1 or 1)*(col+8)*.5
        local y=l.body-hero-12-row*.5-(math.ceil(index/2)-1)*(row+8)
        item(l,menu[1],menu[2],x,y,col,row,{kind="menu",detail=menu[3],icon=menu[4]})
    end
    for index,menu in ipairs(sections) do dashboardItem(index,menu) end
    if P.Ultimate.isDeveloperBuild() then
        dashboardItem(#sections+1,{"DEV","Developer Testing","Private save","dev"})
    end
end

local function cardTier(rating)
    return rating>=90 and "elite" or rating>=85 and "high" or "core"
end

local function cardData(PU,player)
    local rating=PU.Economy.rating(player)
    return {name=PU.displayName(player),rating=rating,role=player.position or PU.role(player),
        league=player.league,season=player.season,tier=cardTier(rating)}
end

local function formation(ui,l)
    local U=P.Ultimate
    local top=l.body-21
    local fieldH=math.min(420,top-l.floor)
    l.field={x=l.x,y=top-fieldH*.5,w=l.w,h=fieldH}
    l.caption="Tap a position to assign a card"
    local cardW=math.min(103,(l.w-42)/3)
    local cardH=math.min(77,fieldH*.20)
    for slot,role in ipairs(U.slotRoles) do
        local row=math.floor((slot-1)/3)
        local col=(slot-1)%3
        local x=slot==10 and l.x or l.x + (col-1)*(cardW+6)
        local y=top-fieldH*.145-row*fieldH*.23
        local player=U.resolveCard(ui.profile,ui.profile.squad[slot])
        item(l,"SLOT:"..slot,slot==4 and "Faceoff" or roleNames[role],x,y,cardW,cardH,{
            kind="formation",card=player and cardData(U,player),slot=slot,role=slot==4 and "FO" or role
        })
    end
end

local function pageControls(ui,l,total)
    local y=l.floor+18
    item(l,"PREV","‹",l.x-l.w*.35,y,48,36,{enabled=ui.listPage>1})
    item(l,"NEXT","›",l.x+l.w*.35,y,48,36,{enabled=ui.listPage<total})
    l.pageLabel=string.format("%d / %d",ui.listPage,total)
    l.pageY=y
end

local function ownedCards(ui,U)
    if ui.ownedSource~=ui.profile.cards then
        local cards=U.ownedCards(ui.profile)
        table.sort(cards,function(a,b)
            local first,second=U.Economy.rating(a.player),U.Economy.rating(b.player)
            if first~=second then return first>second end
            if a.id~=b.id then return a.id<b.id end
            return a.uid<b.uid
        end)
        ui.ownedSource,ui.owned=ui.profile.cards,cards
    end
    return ui.owned
end

local function listCards(ui,l)
    local U=P.Ultimate
    local picked=ui.page=="PICK"
    local rows={}
    local wanted=picked and U.slotRoles[ui.slot]
    local assigned,assignedPlayers={},{}
    for slot,uid in pairs(ui.profile.squad) do
        assigned[uid]=slot
        local player=U.resolveCard(ui.profile,uid)
        if player then assignedPlayers[U.identity(player)]=slot end
    end
    for _,owned in ipairs(ownedCards(ui,U)) do
        if not wanted or wanted==U.role(owned.player) then
            rows[#rows+1]=owned
        end
    end
    local top=l.body
    if picked then
        l.caption=ui.slot==4 and "Faceoff · Midfield cards" or roleNames[wanted].." · Position "..ui.slot
        top=top-26
        if ui.profile.squad[ui.slot] then
            item(l,"REMOVE","Clear position",l.x,top-19,l.w,38)
            top=top-47
        end
    end
    if #rows==0 then
        l.empty=picked and "Open a pack or spin for this position." or "Open your starter pack to collect players."
        if not picked then
            item(l,"PACKS","Go to Player Packs",l.x,top-58,l.w,43,{primary=true})
        end
        return
    end
    local columns=2
    local rowH=math.min(109,math.max(65,math.floor((top-l.floor)/3)))
    local pageSize=columns*math.max(1,math.floor((top-l.floor-44)/(rowH+8)))
    local pages=math.max(1,math.ceil(#rows/pageSize))
    ui.listPage=math.min(ui.listPage,pages)
    if pages>1 then pageControls(ui,l,pages) end
    local w=(l.w-8)*.5
    for index=1,pageSize do
        local owned=rows[(ui.listPage-1)*pageSize+index]
        if not owned then break end
        local x=l.x+(index%2==1 and -1 or 1)*(w+8)*.5
        local y=top-rowH*.5-math.floor((index-1)/2)*(rowH+8)
        local inSlot=picked and assignedPlayers[U.identity(owned.player)] or assigned[owned.uid]
        local used=inSlot and (picked and inSlot~=ui.slot and "In slot "..inSlot or "Starting ten") or nil
        local data=cardData(U,owned.player)
        item(l,"CARD:"..owned.uid,data.name,x,y,w,rowH,{
            kind="player",uid=owned.uid,card=data,status=used,
            enabled=picked and (not inSlot or inSlot==ui.slot),interactive=picked
        })
    end
end

local function getOdds(e)
    local odds={}
    for _,rarity in ipairs(e.rates) do
        local entry=colors[rarity.tier]
        if entry then
            local range=rarity.tier=="elite" and "90+" or string.format("%d–%d",rarity.minimum,rarity.maximum)
            odds[#odds+1]={tier=rarity.tier,range=range,value=rarity.weight,palette=entry}
        end
    end
    return odds
end

local function packs(ui,l)
    local c,E=ui.profile,P.Ultimate.Economy
    if ui.reveal then
        l.caption="Saved to My Collection"
        local finished=ui.time-ui.reveal.start>=1.7
        item(l,"DONE",finished and "Done" or "Skip Animation",l.x,l.floor+20,l.w,40,{primary=finished})
        return
    end
    local top=l.body-108
    l.caption=number(c.unopenedPacks).." unopened · 5 players in every pack"
    l.odds={rows=getOdds(E),y=l.body-74,title="STANDARD ODDS PER CARD"}
    local rows={}
    if not c.starterGranted then
        rows[#rows+1]={id="STARTER",title="Open Starter Pack",primary=true,detail="Free · One card guaranteed 85+"}
    end
    local hasPacks=(c.unopenedPacks or 0)>0
    rows[#rows+1]={id="OPEN_PACK",title="Open Pack",primary=hasPacks,enabled=hasPacks,
        detail=number(c.unopenedPacks).." available"}
    rows[#rows+1]={id="BUY_PACK",title="Buy Standard Pack",enabled=(c.coins or 0)>=E.packCost,
        detail=number(E.packCost).." gold"}
    local row=math.min(48,(top-l.floor-7*(#rows-1))/#rows)
    for index,data in ipairs(rows) do
        item(l,data.id,data.title,l.x,top-row*.5-(index-1)*(row+7),l.w,row,data)
    end
end

local function wheel(ui,l)
    local E=P.Ultimate.Economy
    l.caption="One player per spin"
    l.wheelRadius=math.max(16,math.min(l.w*.36,(l.body-l.floor-151)*.5,138))
    l.wheelY=l.body-32-l.wheelRadius
    l.odds={rows=getOdds(E),y=l.wheelY-l.wheelRadius-35}
    local spin=ui.reveal
    if spin and ui.time-spin.start>=3 then
        l.winY=l.odds.y
        l.odds=nil
    end
    if spin then
        local finished=ui.time-spin.start>=3
        item(l,"WHEEL_DONE",finished and "Done" or "Skip Animation",l.x,l.floor+20,l.w,40,{primary=finished})
    else
        item(l,"SPIN","Spin for "..number(E.wheelCost).." Gold",l.x,l.floor+20,l.w,40,
            {enabled=(ui.profile.coins or 0)>=E.wheelCost,primary=true})
    end
end

local function vault(ui,l)
    l.caption="Original home and away uniforms"
    local kits=P.Ultimate.kits
    local row=math.min(123,(l.body-20-l.floor-14)/math.ceil(#kits/2))
    local col=(l.w-8)*.5
    for index,k in ipairs(kits) do
        local x=l.x+(index%2==1 and -1 or 1)*(col+8)*.5
        local y=l.body-24-row*.5-math.floor((index-1)/2)*(row+6)
        item(l,"KIT:"..k.id,k.name,x,y,col,row,
            {kind="kit",kit=k,selected=ui.profile.equippedKit==k.id})
    end
end

local function record(ui,l)
    local profile=ui.profile
    l.caption=string.format("%d played  ·  %d wins  ·  %d draws  ·  %d losses",
        profile.matches,profile.wins,profile.draws,profile.losses)
    local history=profile.matchHistory
    if #history==0 then l.empty="Complete a match to see your results here." return end
    local row=52
    local size=math.max(1,math.floor((l.body-24-l.floor-38)/row))
    local pages=math.ceil(#history/size)
    ui.listPage=math.min(pages,ui.listPage)
    if pages>1 then pageControls(ui,l,pages) end
    for i=1,size do
        local entry=history[#history-(ui.listPage-1)*size-i+1]
        if not entry then break end
        local score=entry.ownScore and entry.opponentScore
            and string.format("  %d–%d",entry.ownScore,entry.opponentScore) or ""
        item(l,"RESULT:"..entry.id,entry.result:upper()..score,l.x,l.body-43-(i-1)*row,l.w,row-5,{
            detail="+"..number(entry.payout).." gold  ·  "..(entry.box and "View box score" or "Earlier result"),
            boxScore=entry.box,interactive=entry.box~=nil
        })
    end
end

local function dev(ui,l)
    local E=P.Ultimate.Economy
    l.caption="Private Ultimate Team save"
    item(l,"TEST_GOLD","Grant 1,000,000 Gold",l.x,l.body-54,l.w,54,
        {enabled=E.canGrantTestGold(ui.profile),detail=ui.profile.testGoldGranted and "Already claimed" or "One-time grant"})
    item(l,"DEV_RESET","Reset Test Progress",l.x,l.body-119,l.w,54,
        {enabled=not ui.activeMatch and not ui.pendingResult,detail="One-time grant status is retained"})
end

local function devConfirm(_,l)
    l.caption="Clear this private collection, gold, and records?"
    l.empty="Your one-time gold claim stays recorded."
    item(l,"DEV_CONFIRM","Reset Private Save",l.x,l.body-77,l.w,49)
end

local layouts={
    DASHBOARD=dashboard,SQUAD=formation,PACKS=packs,WHEEL=wheel,
    PICK=listCards,COLLECTION=listCards,VAULT=vault,RECORD=record,DEV=dev,DEV_CONFIRM=devConfirm
}

function UI.layout(ui)
    if ui.page=="SBC" then return end
    local l=getFrame()
    local onDashboard=ui.page=="DASHBOARD"
    item(l,"BACK",onDashboard and "‹ Home" or "‹ Back",l.x-l.w*.5+38,l.top-16,76,32)
    l.gold={x=l.x+l.w*.5-64,y=l.top-16,w=128,h=32}
    l.title=titles[ui.page]
    layouts[ui.page](ui,l)
    return l
end

local borderGreen={border=ink.green,base=ink.greenFill}
local borderGold={border=ink.goldDark,base=ink.goldFill}

local function drawCard(box,selected,progress)
    local x,y,w,h=box.x,box.y,box.w,box.h
    local card=box.card
    local theme=card and colors[card.tier]
    local press=progress or (selected and .965 or 1)
    if card then
        panel(x,y,w,h,theme,press,box.kind=="formation" and 8 or 12)
        if progress and progress<.72 then return end
        local tiny=box.kind=="formation"
        local ratingSize=tiny and 19 or 28
        local top=y+h*.24
        label(tostring(card.rating),x-w*.23,top,ratingSize,theme.border)
        local role = box.slot==4 and "FO" or card.position or card.role
        label(role or "",x+w*.24,top,tiny and 11 or 13,theme.border,w*.40)
        if not tiny and h>=96 then icon("stick",x,y+h*.08,h*.28,theme.border) end
        label(card.name,x,y-h*.09,tiny and 10 or 13,ink.white,w-10)
        local footer=box.status
        if not tiny then
            local edition=card.league or ""
            if card.season then edition=edition.." "..tostring(card.season) end
            local description=edition~="" and edition.." · "..theme.label or theme.label
            label(description,x,y-h*.32,9,theme.border,w-10)
            label(footer,x,y-h*.45,8,ink.muted,w-10)
        end
    else
        panel(x,y,w,h,{border=ink.fieldLine,base=ink.turf},press,8)
        label("+",x,y+h*.13,19,ink.green)
        label((box.role or "").." · AI",x,y-h*.20,9,ink.muted,w-10)
    end
end

local function pitch(area)
    panel(area.x,area.y,area.w,area.h,{border=ink.fieldLine,base=ink.turf},nil,12)
    local x,y,w,h=area.x,area.y,area.w,area.h
    for i=-3,3,2 do
        round(x,y+i*h*.063,w-19,h*.103,3,ink.stripe)
    end
    local left,right=x-w*.46,x+w*.46
    local lower,upper=y-h*.47,y+h*.47
    stroke(ink.fieldLine)
    strokeWidth(1)
    line(left,lower,right,lower)
    line(left,upper,right,upper)
    line(left,lower,left,upper)
    line(right,lower,right,upper)
    line(left,y,right,y)
    noFill()
    ellipse(x,y,math.min(56,w*.24))
    ellipse(x,lower+h*.12,42)
    ellipse(x,upper-h*.12,42)
    noStroke()
end

local function kitColor(rgb) return color(rgb[1],rgb[2],rgb[3]) end

local function garment(x,y,size,base,accent)
    round(x-size*.30,y+size*.12,size*.30,size*.31,size*.045,base)
    round(x+size*.30,y+size*.12,size*.30,size*.31,size*.045,base)
    round(x,y,size*.58,size*.66,size*.065,base)
    round(x,y-size*.10,size*.56,size*.068,1,accent)
    fill(ink.panel)
    ellipse(x,y+size*.31,size*.22,size*.13)
end

local function drawBox(ui,box)
    local selected=ui.press and ui.press.box.id==box.id
    if box.kind=="player" or box.kind=="formation" then
        drawCard(box,selected)
        return
    end
    local x,y,w,h=box.x,box.y,box.w,box.h
    local pressed=selected and .967 or 1
    if box.kind=="kit" then
        panel(x,y,w,h,box.selected and borderGreen,pressed)
        local size=math.min(53,h*.53,w*.33)
        garment(x-w*.22,y+h*.11,size,kitColor(box.kit.home),kitColor(box.kit.accent))
        garment(x+w*.22,y+h*.11,size,kitColor(box.kit.away),kitColor(box.kit.accent))
        label(box.label,x,y-h*.24,12,ink.white,w-10)
        if box.selected then label("Equipped",x,y-h*.40,9,ink.green,w-10) end
    elseif box.kind=="hero" then
        panel(x,y,w,h,borderGreen,pressed,14)
        local glimmer=math.floor(70+32*(1+math.sin(ui.time*2)))
        round(x-w*.5+14,y,3,h*.60,1.5,color(113,241,187,glimmer))
        icon("play",x+w*.5-32,y,33,ink.green)
        local left,width=x-w*.5+26,w-85
        label(box.label,left,y+(box.latest and 18 or 9),21,ink.white,width,true)
        label(box.detail,left,y+(box.latest and -4 or -14),12,ink.green,width,true)
        label(box.latest,left,y-23,10,ink.muted,width,true)
    elseif box.kind=="menu" then
        panel(x,y,w,h,nil,pressed)
        local size=math.min(31,h*.48)
        local ix=x-w*.5+size*.54+9
        round(ix,y,size+4,size+4,9,ink.greenFill)
        icon(box.icon,ix,y,size,ink.gold)
        local left=ix+size*.5+8
        local width=x+w*.5-left-6
        label(box.label,left,y+8,14,ink.white,width,true)
        label(box.detail,left,y-10,10,ink.muted,width,true)
    else
        panel(x,y,w,h,box.primary and box.enabled~=false and borderGreen,pressed)
        local tint=box.enabled==false and ink.dim or ink.white
        label(box.label,x,y+(box.detail and 7 or 0),box.id=="BACK" and 13 or 15,tint,w-10)
        label(box.detail,x,y-11,10,box.enabled==false and ink.dim or ink.muted,w-10)
    end
end

local function oddsStrip(l)
    local o=l.odds
    if not o then return end
    if o.title then label(o.title,l.x,o.y+34,11,ink.gold,l.w) end
    local w=(l.w-12)/3
    for index,entry in ipairs(o.rows) do
        local x=l.x+(index-2)*(w+5)
        panel(x,o.y,w,49,entry.palette,nil,8)
        label(tostring(entry.value).."%",x,o.y+7,16,entry.palette.border,w-6)
        label(entry.palette.label.." "..entry.range,x,o.y-10,9,ink.white,w-6)
    end
end

local function revealPack(ui,l)
    local list=ui.reveal.cards
    local available=l.body-l.floor-79
    local w=math.min(111,(l.w-12)/3)
    local h=math.min(143,available*.47)
    for index,card in ipairs(list) do
        local current=math.max(0,math.min(1,(ui.time-ui.reveal.start-(index-1)*.34)/.27))
        local row=index<=3 and 1 or 2
        local column=index<=3 and index-2 or index-4.5
        local x=l.x+column*(w+5)
        local y=l.body-34-h*.5-(row-1)*(h+10)
        if current>0 then
            drawCard({x=x,y=y,w=w,h=h,card=card},false,1-(1-current)^3*.90)
        else
            panel(x,y,w,h,borderGold,nil,12)
            icon("packs",x,y,46,ink.gold)
        end
    end
end

local wheelShapes = {}

local function wheelSector(entry,elapsed,x,y,r,spin)
    if mesh and rotate and scale then
        local shape=wheelShapes[entry.tier]
        if not shape then
            local vertices={}
            local triangles=math.ceil(entry.value*.44)
            local low,high=elapsed+.42,elapsed+entry.value-.42
            for i=0,triangles-1 do
                local a=(low+(high-low)*i/triangles)*2*math.pi/100
                local b=(low+(high-low)*(i+1)/triangles)*2*math.pi/100
                local n=#vertices
                vertices[n+1],vertices[n+2],vertices[n+3]=vec3(),vec3(math.cos(a),math.sin(a)),vec3(math.cos(b),math.sin(b))
            end
            shape=mesh()
            shape.vertices=vertices
            shape:setColors(entry.palette.base)
            wheelShapes[entry.tier]=shape
        end
        pushMatrix()
        translate(x,y)
        rotate(math.deg(spin))
        scale(r-5)
        shape:draw()
        popMatrix()
        return
    end
    for stripe=elapsed+.45,elapsed+entry.value-.25,.90 do
        local angle=(stripe/100*2*math.pi)+spin
        stroke(entry.palette.base)
        strokeWidth(4)
        line(x+math.cos(angle)*r*.21,y+math.sin(angle)*r*.21,
             x+math.cos(angle)*(r-5),y+math.sin(angle)*(r-5))
    end
end

local function wheelGraphic(ui,l)
    local x,y,r=l.x,l.wheelY,l.wheelRadius
    local foundation=ui.reveal and math.min(1,(ui.time-ui.reveal.start)/3) or 0
    local spin=ui.reveal and ui.reveal.angle*(1-(1-foundation)^3) or 0
    fill(ink.gold)
    ellipse(x,y,r*2)
    fill(ink.shadow)
    ellipse(x,y,r*2-4)
    local elapsed=0
    for _,entry in ipairs(getOdds(P.Ultimate.Economy)) do
        local center=elapsed+entry.value*.5
        wheelSector(entry,elapsed,x,y,r,spin)
        local angle=(center/100*2*math.pi)+spin
        noStroke()
        label(entry.palette.label,x+math.cos(angle)*r*.72,y+math.sin(angle)*r*.72,10,entry.palette.border,50)
        elapsed=elapsed+entry.value
    end
    icon("gold",x,y,r*.76,ink.gold)
    stroke(ink.gold)
    strokeWidth(2)
    line(x-7,y+r+6,x,y+r-5)
    line(x+7,y+r+6,x,y+r-5)
    noStroke()
    if l.winY and ui.reveal then
        drawCard({x=x,y=l.winY,w=math.min(l.w-16,164),h=66,card=ui.reveal.cards[1]},false)
    end
end

function UI.draw(ui,dt)
    ui.time=ui.time+math.max(0,dt or 0)
    ui.messageTime=math.max(0,ui.messageTime-(dt or 0))
    if ui.page=="SBC" then
        P.Ultimate.SBCUI.draw(ui.sbc,dt)
        return
    end
    local l=UI.layout(ui)
    background(ink.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    rectMode(CENTER)
    ellipseMode(CENTER)
    textMode(CENTER)
    textAlign(CENTER)
    font("AvenirNext-DemiBold")
    round(l.x,l.top-72,l.w,56,11,ink.elevated)
    label(l.title,l.x,l.top-68,ui.page=="DASHBOARD" and 25 or 23,ink.white,l.w-12)
    round(l.x,l.top-91,math.min(l.w*.45,148),2,1,ink.goldDark)
    local coin=l.gold
    panel(coin.x,coin.y,coin.w,coin.h,borderGold,nil,10)
    icon("gold",coin.x-46,coin.y,22,ink.gold)
    label(number(ui.profile.coins).." gold",coin.x+10,coin.y,13,ink.gold,coin.w-35)
    if l.field then pitch(l.field) end
    label(l.caption,l.x,l.body-8,11,ink.muted,l.w)
    label(l.empty,l.x,l.body-34,12,ink.muted,l.w)
    label(l.pageLabel,l.x,l.pageY,11,ink.muted,l.w*.35)
    if ui.page=="PACKS" and ui.reveal then revealPack(ui,l) end
    if ui.page=="WHEEL" then wheelGraphic(ui,l) end
    oddsStrip(l)
    for _,box in ipairs(l.items) do drawBox(ui,box) end
    if ui.page=="PACKS" or ui.page=="WHEEL" or ui.page=="COLLECTION" or ui.page=="PICK" then
        label("Fictional PolyLax ratings",l.x,l.bottom+11,10,ink.muted,l.w)
    end
    if ui.messageTime>0 and ui.messageText then
        panel(l.x,l.bottom+12,l.w,28,borderGold,nil,8)
        label(ui.messageText,l.x,l.bottom+12,11,ink.gold,l.w-11)
    end
    popMatrix()
    popStyle()
end

local function openReveal(ui,data)
    ui.reveal={cards=data,start=ui.time}
end

local function buy(ui)
    local ok,result=P.Ultimate.Economy.buyPack(ui.profile)
    if ok then UI.message(ui,"Pack added. Tap Open Pack to reveal it.")
    else UI.message(ui,result) end
end

local function getPack(ui,operation)
    local ok,result=operation(ui.profile)
    if ok then openReveal(ui,result)
    else UI.message(ui,result) end
end

local function spinWheel(ui)
    local E=P.Ultimate.Economy
    local ok,result=E.spin(ui.profile)
    if not ok then UI.message(ui,result) return end
    openReveal(ui,{result})
    local offset=0
    for _,rarity in ipairs(E.rates) do
        if rarity.tier==result.tier then
            offset=offset+rarity.weight*.5
            break
        end
        offset=offset+rarity.weight
    end
    ui.reveal.angle=math.pi*8+((math.pi/2-offset/100*2*math.pi)%(math.pi*2))
end

local function back(ui)
    if ui.page=="DASHBOARD" then return "HOME" end
    if ui.page=="PICK" then gotoPage(ui,"SQUAD")
    elseif ui.page=="DEV_CONFIRM" then gotoPage(ui,"DEV")
    else gotoPage(ui,"DASHBOARD") end
end

local actions={
    BACK=back,
    PLAY=function() return "PLAY" end,
    PREV=function(ui) ui.listPage=ui.listPage-1 end,
    NEXT=function(ui) ui.listPage=ui.listPage+1 end,
    REMOVE=function(ui)
        local ok,reason=P.Ultimate.unequip(ui.profile,ui.slot)
        if ok then gotoPage(ui,"SQUAD") else UI.message(ui,reason) end
    end,
    STARTER=function(ui) getPack(ui,P.Ultimate.Economy.grantStarter) end,
    OPEN_PACK=function(ui) getPack(ui,P.Ultimate.Economy.openPack) end,
    BUY_PACK=buy,
    SPIN=spinWheel,
    DONE=function(ui)
        if ui.time-ui.reveal.start<1.7 then ui.reveal.start=ui.time-2 else ui.reveal=nil end
    end,
    WHEEL_DONE=function(ui)
        if ui.time-ui.reveal.start<3 then ui.reveal.start=ui.time-3 else ui.reveal=nil end
    end,
    TEST_GOLD=function(ui)
        local ok,reason=P.Ultimate.Economy.grantTestGold(ui.profile)
        UI.message(ui,ok and "Developer gold granted." or reason)
    end,
    DEV_RESET=function(ui) gotoPage(ui,"DEV_CONFIRM") end,
    DEV_CONFIRM=function(ui)
        local ok,reason=P.Ultimate.Economy.resetTestProgress(ui.profile)
        if ok then gotoPage(ui,"DEV") end
        UI.message(ui,ok and "Private progress reset." or reason)
    end,
    SBC=function(ui)
        gotoPage(ui,"SBC")
        ui.sbc=P.Ultimate.SBCUI.new(ui.profile)
    end
}

local function select(ui,box)
    local id=box.id
    if actions[id] then return actions[id](ui) end
    local U=P.Ultimate
    if box.boxScore then
        return "BOX_SCORE",box.boxScore
    elseif box.slot then
        ui.slot=box.slot
        gotoPage(ui,"PICK")
    elseif box.uid then
        local ok,reason=U.equip(ui.profile,ui.slot,box.uid)
        if ok then gotoPage(ui,"SQUAD") else UI.message(ui,reason) end
    elseif box.kit then
        local ok,reason=U.equipKit(ui.profile,box.kit.id)
        UI.message(ui,ok and "Uniform equipped for your next match." or reason)
    elseif layouts[id] then
        gotoPage(ui,id)
    end
end

function UI.touch(ui,t)
    if ui.page=="SBC" then
        local result=P.Ultimate.SBCUI.touch(ui.sbc,t)
        if result=="back" or result=="BACK" then gotoPage(ui,"DASHBOARD") end
        return
    end
    if t.state==BEGAN then
        if ui.press then return end
        for _,box in ipairs(UI.layout(ui).items) do
            if box.enabled~=false and box.interactive~=false and P.UI.hit(box,t.x,t.y) then
                ui.press={id=t.id,box=box}
                return
            end
        end
        return
    end
    local press=ui.press
    if not press or press.id~=t.id then return end
    if t.state==CANCELLED or t.state==MOVING and not P.UI.hit(press.box,t.x,t.y) then
        ui.press=nil
    elseif t.state==ENDED then
        ui.press=nil
        if P.UI.hit(press.box,t.x,t.y) then return select(ui,press.box) end
    end
end
end

-- UltimateMatch
do
-- Ultimate Team uses the existing full-field simulation with a local squad snapshot.
PolyLax = PolyLax or {}
local P = PolyLax
local Match = {}
P.UltimateMatch = Match

local roles = {"A","A","A","M","M","M","D","D","D","G"}
local slots = {"A1","A2","A3","FO","M2","M3","D1","D2","D3","G"}
local specialist = {FO="FOGO",FOGO="FOGO",FACEOFF="FOGO",LSM="LSM",SSDM="SSDM"}
local shortNames = {"UT","GLD"}

local function ratings(role, overall, bonuses)
    local attrs = P.Attributes.forPosition(role)
    local boost = overall - P.Attributes.overall(attrs,role)
    for key, value in pairs(attrs) do
        attrs[key] = math.max(30,math.min(99,value+boost+(bonuses and bonuses[key] or 0)))
    end
    return attrs
end

local function nextNumber(numbers, preferred)
    local number = math.max(0,math.min(99,math.floor(preferred)))
    while numbers[number] do number = (number+1)%100 end
    numbers[number] = true
    return number
end

local function buildLineups(collection)
    local ultimate = P.Ultimate
    local own, opponent, used, numbers, awayNumbers = {}, {}, {}, {}, {}
    for slot, role in ipairs(roles) do
        local uid = collection.squad[slot]
        local card = uid and ultimate.resolveCard(collection,uid)
        if card and (used[ultimate.identity(card)] or ultimate.role(card) ~= role) then card = nil end
        local fallbackRole = slot==4 and "FOGO" or role
        local cardRole = card and specialist[tostring(card.position):upper()] or nil
        if card then
            used[ultimate.identity(card)] = true
            own[slot] = {
                name=ultimate.displayName(card), role=cardRole or fallbackRole,
                number=nextNumber(numbers,tonumber(card.number) or slot+8),
                cardUID=uid, statId="ultimate:card:"..tostring(uid),
                attributes=ratings(cardRole or fallbackRole,ultimate.Economy.rating(card),card.attributes)
            }
        else
            own[slot] = {
                name="Reserve "..slots[slot], role=fallbackRole, temporaryAI=true,
                number=nextNumber(numbers,slot+28), statId="ultimate:reserve:"..slot,
                attributes=ratings(fallbackRole,72)
            }
        end
        opponent[slot] = {
            name="Gold "..slots[slot], role=fallbackRole,
            number=nextNumber(awayNumbers,slot+18), statId="ultimate:opponent:"..slot,
            attributes=ratings(fallbackRole,78+(slot%5))
        }
    end
    return {own,opponent}
end

local function makeTeam(index, name, palette, away)
    local id = "ultimate-"..index
    local dark, light = color(table.unpack(palette.home)), color(table.unpack(palette.away))
    local accent = color(table.unpack(palette.accent))
    return {
        id=id,name=name,short=shortNames[index],
        kit={teamId=id,primary=away and light or dark,secondary=accent,shorts=dark,
            shell=dark,accent=accent,gloves=dark,number=away and dark or light}
    }
end

function Match.new(scene, collection, profile)
    if collection.loadError then return nil,collection.loadError end
    local ultimate = P.Ultimate
    local palette = ultimate.kit(collection.equippedKit) or ultimate.kits[1]
    local rival = {home={38,36,22},away={242,233,196},accent={180,135,44}}
    local home, away = makeTeam(1,"Ultimate Squad",palette), makeTeam(2,"Gold Scouts",rival,true)
    local kit = home.kit
    local game = P.FullMatch.new(scene,profile,nil,nil,{
        profile="professional",periodLength=45,
        lineups=buildLineups(collection),teams={home,away},
        fieldTheme={id="ultimate-arena",wordmark="ULTIMATE",endWordmark="POLYLAX",
            centerWordmark="UT",primary=kit.primary,secondary=kit.secondary,
            accent=kit.accent,lettering=kit.number},
        statistics={mode="ULTIMATE TEAM",useMatchRoster=true,persist=false}
    })
    local ok, id = ultimate.Economy.beginMatch(collection)
    if not ok then return nil,id end
    local statId = "ultimate:match:"..id
    game.statisticsOptions.id, game.statistics.id = statId,statId
    return game,id
end

function Match.settle(collection, game, id)
    if game.phase ~= "FINAL" then return false,"Finish the match to earn gold" end
    local box = P.Statistics.matchSummary(game)
    if not box or not box.final then return false,"Final match statistics are unavailable" end
    local own, away = game.homeScore,game.awayScore
    local result = own>away and "win" or own<away and "loss" or "draw"
    return P.Ultimate.Economy.recordMatch(collection,result,id,own,away,box)
end
end

-- StoryChapters
do
-- Road to Glory | Brothers in Arms interactive chapter data.
PolyLax = PolyLax or {}
local Chapter = {}
PolyLax.StoryChapters = Chapter

Chapter.title = "Brothers in Arms"
Chapter.act = "Act I · The Freshmen"
Chapter.characters = {
    ethan="Ethan Cole", coach="Coach Daniel Mercer", jace="Jace Holloway", maya="Maya Brooks",
    drip="Nina Reyes", tryout="Locker Room", practice="Practice Field",
    training="Trainer Avery"
}

Chapter.missions = {
    arrival={title="First Day",detail="Meet Ethan in the courtyard.",target="ethan",zone="campus",node="arrival"},
    coach={title="Earn a Look",detail="Visit Coach Mercer inside the school.",target="coach",zone="coach",node="coach"},
    rival={title="An Early Rival",detail="Meet Jace beside the practice field.",target="jace",zone="campus",node="rival"},
    equipment={title="Get Fitted",detail="Enter Drip Lab and speak with Nina.",target="drip",zone="drip",node="equipment"},
    locker={title="First Locker Room",detail="Meet the team in the locker room.",target="tryout",zone="lockers",node="locker"},
    practice={title="First Practice",detail="Finish an opening practice on the outdoor field.",target="practice",zone="campus",activity="practice"},
    tryout={title="Freshman Tryout",detail="Use the locker-room bench to launch your tryout.",target="tryout",zone="lockers",activity="tryout"},
    debrief={title="Mercer's Decision",detail="Ask Coach Mercer about your placement.",target="coach",zone="coach",node="debrief"},
    promise={title="Brothers in Arms",detail="Find Ethan in the courtyard and compare placements.",target="ethan",zone="campus",node="promise"},
    debut={title="First Whistle",detail="Go to the practice field to play your first game.",target="practice",zone="campus",activity="debut"},
    complete={title="The Freshmen Complete",detail="Talk to teammates, train on the field, or visit your clubhouse."}
}

local function option(id,label,changes,nextNode)
    return {id=id,label=label,changes=changes,nextNode=nextNode}
end

local function finish(id,label,changes)
    local result = option(id,label,changes)
    result.finish = true
    return result
end

local function sameUnit(save)
    return save.athlete.position==2 or save.athlete.position==7
end

Chapter.nodes = {
    arrival={
        speaker="ethan",
        text=function(save)
            return "Your first morning at " .. PolyLax.Career.teamName(save.athlete)
                .. ". Ethan is holding the folded goals sheet you both made in middle school. He’s already written ‘varsity’ twice."
        end,
        options={
            option("promise","Tell him you’ll earn it together.",{ethan=8,bond="together"},"arrival_plan"),
            option("honest","Tell him you each have to earn your spot.",{ethan=2,bond="earned"},"arrival_plan"),
            option("race","Make it a race to varsity.",{ethan=-5,bond="rivalry"},"arrival_plan")
        }
    },
    arrival_plan={
        speaker="ethan",
        text=function(save)
            if save.flags.bond=="rivalry" then
                return "Ethan pockets the sheet. “Fine. Loser carries the balls.” His grin comes half a second late. “Mercer wanted to see us before practice.”"
            elseif save.flags.bond=="earned" then
                return "“Fair,” Ethan says. “Just don’t disappear when one of us gets there first. Mercer wanted to see us before practice.”"
            end
            return "“Good,” Ethan says. “Remind me you said that when I make you run extra clears. I saw Mercer heading into his office.”"
        end,
        options={finish("find_coach","Go find Coach Mercer.")}
    },
    coach={
        speaker="coach",
        text="Mercer moves a magnet marked ‘FRESHMEN’ onto the depth chart. “I have room for effort. What do I get from you when a shift goes wrong?”",
        options={
            option("outlet","Make the next outlet and help the group reset.",{coach=7,approach="team"},"coach_next"),
            option("learn","Ask what I missed and fix it on the next shift.",{coach=6,approach="study"},"coach_next"),
            option("prove","Ask for another rep and prove it myself.",{coach=1,approach="prove",reputation=3},"coach_next")
        }
    },
    coach_next={
        speaker="coach",
        text=function(save)
            local ending = "Get fitted at Drip Lab after you meet Jace. He’s at the practice field."
            if save.flags.approach=="study" then
                return "“Good. I’ll be watching how quickly you make an adjustment. " .. ending .. "”"
            elseif save.flags.approach=="prove" then
                return "“Aggression can help. A bad hero play can cost ten people. " .. ending .. "”"
            end
            return "“Good. Your job lasts until the ball is safe with somebody else. " .. ending .. "”"
        end,
        options={finish("outside","Head back outside.")}
    },
    rival={
        speaker="jace",
        text=function(save)
            if sameUnit(save) then
                return "Jace finishes a sprint at midfield. “Mercer’s looking at our rotation, huh? Varsity doesn’t have two free midfield shifts because two friends showed up.”"
            end
            return "Jace finishes a sprint at midfield. “Freshmen usually learn how quick varsity is after one shift. What’s your unit planning to show us?”"
        end,
        options={
            finish("read","Ask him for the read he uses on the first clear.",{jace=8,coach=1,jaceFound="mentor"}),
            finish("challenge","Tell him you’ll make him remember this tryout.",{jace=-8,reputation=4,jaceFound="rival"}),
            finish("quiet","Save the talk for after the reps.",{jace=1,jaceFound="quiet"})
        }
    },
    equipment={
        speaker="drip",
        text="“Nina Reyes. I keep the campus Drip Lab running. Preview a shaft pattern, some glove trim, or a sleeve. What you buy here is for style. The coach still grades the player.”",
        options={finish("browse","Browse the equipment displays.",{fitted=true})},
        after={kind="shop"}
    },
    locker={
        speaker="tryout",
        text="The JV and varsity benches face each other. A clean pinnie waits on the bench with your number. Ethan keeps retying his right cleat even though the knot is already tight.",
        options={
            option("check_in","Sit beside Ethan and walk through the first shift.",{ethan=7,prep="together"},"locker_ethan"),
            option("warmup","Tell him where you’ll meet, then warm up alone.",{prep="alone"},"locker_ethan")
        }
    },
    locker_ethan={
        speaker="ethan",
        text=function(save)
            if save.flags.prep=="together" then
                return "“The first easy pass. Got it.” Ethan finally leaves the laces alone. “I’ll look for you when we clear.”"
            end
            return "“Go ahead. I need a second anyway.” Ethan looks up. “I hope we both get a real shift.”"
        end,
        options={finish("ready","Get ready for the tryout.")}
    },
    debrief={
        speaker="coach",
        text=function(save)
            local result=save.results.tryout
            local observation=result.secondsPlayed and " in "..result.secondsPlayed.." seconds on the field" or ""
            return "“I logged " .. result.focus .. observation .. ". Your evaluation was " .. result.grade
                .. "/100. I’m putting you at " .. result.placement .. ". "
                .. (result.placement=="Varsity rotation" and "Meet me here again if the pace gets away from you.”"
                or "An assignment is where you start. Good reps can change the next board.”")
        end,
        options={
            option("feedback","Ask for a specific thing to work on.",{coach=5,debriefStyle="feedback"},"debrief_coaching"),
            finish("ethan_first","Ask how Ethan handled his shift.",{ethan=4,coach=1,debriefStyle="ethan"}),
            finish("move_on","Take the assignment and head back outside.",{debriefStyle="focus"})
        }
    },
    debrief_coaching={
        speaker="coach",
        text=function(save)
            local role=PolyLax.Career.positions[save.athlete.position].role
            local feedback = {
                A="Work one clean give-and-go before reaching for the difficult shot.",
                M="On your first change of possession, find the open side before making the outlet.",
                D="Take the inside lane away first. You can challenge the stick once the next slide is ready.",
                LSM="Win the easy ground ball, get the outlet moving, and time your exchange.",
                SSDM="Show them the outside lane. Pressure the next catch once your help arrives.",
                FOGO="Decide where the exit goes before you set your feet.",
                G="Make the save first, then call for one reliable outlet."
            }
            return "“" .. feedback[role] .. " And talk to Ethan. He’s been watching the board.”"
        end,
        options={finish("understood","Go check in with Ethan.")}
    },
    promise={
        speaker="ethan",
        text=function(save)
            local own=save.results.tryout.placement
            local other=save.ethan.depth
            if own==other then
                return "“We both got " .. own .. ".” Ethan studies the board. “Same room again. Do we still know how to hold each other to it?”"
            elseif other=="Varsity rotation" then
                return "“I got varsity rotation.” Ethan keeps his voice low. “I really want to take it. I also didn’t want you to find out from a list.”"
            elseif own=="Varsity rotation" then
                return "“You got varsity. I got " .. other .. ".” Ethan folds the goals sheet until it fits in his pocket. “Do you still have time for me after practice?”"
            elseif save.ethan.health=="managed strain" then
                return "“Mercer put me at " .. other .. " while I get my leg right.” Ethan runs a thumb down the board. “Try not to celebrate doing twice the extra reps without me.”"
            end
            return "“Mercer put me at " .. other .. ".” Ethan runs a thumb down the board. “Different reps. We can still make our own plan, right?”"
        end,
        options={
            finish("partners","Pick a time to work together every week.",{ethan=10,friendship="partners"}),
            finish("space","Give each other some space until the next game.",{ethan=-2,friendship="space"}),
            finish("compete","Make your next shift the way to settle it.",{ethan=-10,reputation=3,friendship="compete"})
        }
    }
}

Chapter.sequence={"arrival","coach","rival","equipment","locker","practice","tryout","debrief","promise","debut","complete"}
end

-- RoadEquipment
do
-- Road to Glory owns this wallet and its cosmetics independently of Ultimate Team.
PolyLax = PolyLax or {}
local P = PolyLax
local Equipment = {}
P.RoadEquipment = Equipment

local V = vec3
local sides = {"left","right"}
local twoPi = math.pi*2

local function hash(x,y)
    local n=math.sin(x*127.1+y*311.7)*43758.5453
    return n-math.floor(n)
end

local function camo(u,v)
    local value=math.sin(19*u+math.cos(12*v)*1.7)+math.cos(20*v+2.1*math.sin(8*u))
    return value>.5 and 3 or value<-.55 and 2 or 1
end

local function spot(u,v)
    local x,y=math.floor(u*7),math.floor(v*8)
    local dx,dy=u*7-x-.26-.40*hash(x,y),v*8-y-.26-.40*hash(y,x)
    local d=dx*dx+dy*dy
    return d<.035 and 1 or d<.085 and 2 or 3
end

local function stamp(u,v,bird)
    local x,y=u*3%1,v*4%1
    local body=((x-.43)/.28)^2+((y-.37)/.17)^2<1
    local head=(x-.64)^2+(y-.52)^2<.011
    if x>.70 and x<.89 and y>.49 and y<.56 then return 2 end
    if head or body or bird and x>.63 and x<.68 and y>.55 and y<.82 then return 3 end
    if not bird and x>.56 and x<.75 and y>.10 and y<.28 then return 2 end
    return 1
end

local patterns = {
    {name="Solid"},
    {name="Woodland Camo", colors={{32,49,32},{95,72,40},{111,139,75}}, sample=camo},
    {name="Snow Camo", colors={{215,230,240},{123,151,171},{245,249,251}}, sample=camo},
    {name="Digital Camo", colors={{36,51,46},{72,121,115},{191,196,152}}, sample=function(u,v)
        local n=hash(math.floor(u*11),math.floor(v*13))
        return n<.46 and 1 or n<.73 and 2 or 3
    end},
    {name="Zebra", colors={{233,239,244},{53,64,83},{17,24,36}}, sample=function(u,v)
        local stripe=math.sin(56*u+3.8*math.sin(11*v))
        return stripe>.34 and 3 or stripe>.16 and 2 or 1
    end},
    {name="Flamingo", colors={{34,61,76},{244,213,124},{250,128,178}}, sample=function(u,v)
        return stamp(u,v,true)
    end},
    {name="Leopard", colors={{39,29,23},{153,89,40},{229,170,87}}, sample=spot},
    {name="Tiger Stripes", colors={{239,101,34},{252,158,66},{22,28,33}}, sample=function(u,v)
        local stripe=math.sin(46*u+8*v+2.8*math.sin(10*v))
        return stripe>.58 and 3 or stripe>.31 and 2 or 1
    end},
    {name="Galaxy", colors={{22,22,62},{110,69,174},{187,211,247}}, sample=function(u,v)
        if hash(math.floor(u*27),math.floor(v*29))>.93 then return 3 end
        return math.sin(11*u+5*v+math.cos(v*12))>.29 and 2 or 1
    end},
    {name="Graffiti", colors={{34,31,50},{90,234,182},{246,79,157}}, sample=function(u,v)
        local s=math.sin(53*u+42*v)+math.sin(91*u-22*v)
        return s>1.11 and 3 or s<-.71 and 2 or 1
    end},
    {name="Electric Storm", colors={{25,32,75},{70,111,241},{143,238,255}}, sample=function(u,v)
        local line=math.abs((u+.48*v+.10*math.sin(math.floor(v*8)))% .32-.16)
        return line<.027 and 3 or line<.056 and 2 or 1
    end},
    {name="Retro 90s", colors={{58,35,127},{255,193,82},{48,219,201}}, sample=function(u,v)
        local a,b=u*5%1,v*5%1
        return a+b>.92 and a+b<1.24 and 3 or a>.78 and b>.62 and 2 or 1
    end},
    {name="Inferno Flames", colors={{41,25,32},{237,55,39},{255,181,66}}, sample=function(u,v)
        local s=v*3%1+.34*math.cos(41*u+5*v)+.12*math.sin(81*u)
        return s<.40 and 3 or s<.68 and 2 or 1
    end},
    {name="Rubber Ducks", colors={{38,142,175},{249,113,42},{255,216,77}}, sample=function(u,v)
        return stamp(u,v,false)
    end}
}
Equipment.patterns = patterns

local swatches = {
    {"Graphite",{40,53,67}},{"Pearl",{230,238,245}},{"Varsity Green",{39,115,88}},
    {"Cobalt",{45,99,190}},{"Crimson",{166,47,62}},{"Sunset",{231,143,55}},
    {"Lavender",{143,112,214}},{"Ice",{101,218,228}},{"Rose",{226,138,168}}
}
local colorNames, patternNames = {}, {}
for i,v in ipairs(swatches) do colorNames[i]=v[1] end
for i,v in ipairs(patterns) do patternNames[i]=v.name end

local sections = {
    {id="STICK",label="Stick",fields={
        {"shaftPattern","Shaft Pattern",patternNames,1,35},
        {"shaftColor","Shaft Color",colorNames,4,12},
        {"shaftModel","Shaft Model",{"Alloy","Slim","Reinforced"},1,20},
        {"shaftFinish","Shaft Finish",{"Satin","Matte","Polished"},1,24},
        {"gripColor","Grip Tape",colorNames,1,8},
        {"gripPattern","Grip Pattern",patternNames,1,18},
        {"headModel","Head Profile",{"Classic","Swept","Wide"},1,23},
        {"headColor","Head Color",colorNames,2,10},
        {"meshPattern","Mesh Weave",{"Diamond","Cross-Lace","Two-Tone"},1,18},
        {"meshColor","Mesh Color",colorNames,2,8},
        {"sidewallColor","Sidewall String",colorNames,1,8},
        {"topStringColor","Top String",colorNames,2,8},
        {"shootingStringColor","Shooting String",colorNames,2,8},
        {"pocket","Pocket Appearance",{"Mid Pocket","High Channel","Low Channel"},1,15}
    }},
    {id="GLOVES",label="Gloves",fields={
        {"gloveFinish","Glove Finish",{"Matte","Silver Chrome","Gold Chrome","Black Chrome","Rose-Gold Chrome","Iridescent Chrome"},1,42},
        {"gloveModel","Glove Model",{"Classic","Speed","Armor"},1,25},
        {"gloveColor","Primary Color",colorNames,2,12},
        {"gloveSecondary","Secondary Color",colorNames,1,9},
        {"gloveAccent","Accent Color",colorNames,3,9},
        {"gloveCuff","Cuff",{"Low","Flare","Shield"},1,20},
        {"glovePattern","Glove Pattern",patternNames,1,32}
    }},
    {id="SLEEVES",label="Sleeves",fields={
        {"leftSleeve","Left Sleeve",{"None","Lower Leg","Full"},1,15},
        {"leftSleevePattern","Left Pattern",patternNames,1,22},
        {"leftSleeveColor","Left Color",colorNames,1,9},
        {"rightSleeve","Right Sleeve",{"None","Lower Leg","Full"},1,15},
        {"rightSleevePattern","Right Pattern",patternNames,1,22},
        {"rightSleeveColor","Right Color",colorNames,1,9}
    }},
    {id="OUTFIT",label="Outfit",fields={
        {"hoodieColor","Hoodie Color",colorNames,3,12},
        {"hoodiePattern","Hoodie Pattern",patternNames,1,25},
        {"joggerColor","Jogger Color",colorNames,1,10},
        {"joggerPattern","Jogger Pattern",patternNames,1,25},
        {"sneaker","Sneakers",{"Court Low","High-Top","Street Trail"},1,25},
        {"sneakerColor","Sneaker Color",colorNames,2,10},
        {"backpackStyle","Backpack Style",{"Campus","Roll Top","Travel Pack"},1,25},
        {"backpackColor","Backpack Color",colorNames,1,10},
        {"backpackPattern","Backpack Pattern",patternNames,1,25}
    }},
    {id="PRESETS",label="Presets"}
}
Equipment.sections = sections
local fields = {}
for _,section in ipairs(sections) do
    for _,field in ipairs(section.fields or {}) do fields[field[1]]=field end
end
Equipment.fields = fields
Equipment.maxCredits = 999999

local function integer(value,default,min,max)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return default end
    return math.max(min,math.min(max,math.floor(value)))
end

local function key(id,value) return id..":"..value end

function Equipment.owns(kit,id,value)
    local field=fields[id]
    return field~=nil and field[3][value]~=nil
        and (value==field[4] or kit.owned[key(id,value)]==true)
end

local function validateEquipped(kit,source)
    local result={}
    for id,field in pairs(fields) do
        local chosen=integer(source[id],field[4],1,#field[3])
        result[id]=Equipment.owns(kit,id,chosen) and chosen or field[4]
    end
    return result
end

function Equipment.restore(raw)
    if type(raw)~="table" then raw={} end
    local kit={version=1,credits=integer(raw.credits,240,0,Equipment.maxCredits),owned={},presets={}}
    local owned=type(raw.owned)=="table" and raw.owned or {}
    for id,field in pairs(fields) do
        for option=1,#field[3] do
            local code=key(id,option)
            if owned[code]==true then kit.owned[code]=true end
        end
    end
    kit.equipped=validateEquipped(kit,type(raw.equipped)=="table" and raw.equipped or {})
    if type(raw.presets)=="table" then
        for slot=1,3 do
            local data=raw.presets[tostring(slot)] or raw.presets[slot]
            if type(data)=="table" then kit.presets[tostring(slot)]=validateEquipped(kit,data) end
        end
    end
    return kit
end

function Equipment.change(kit,action,id,value)
    local nextKit=Equipment.restore(kit)
    local field=fields[id]
    if action=="savePreset" or action=="loadPreset" then
        if type(value)~="number" or value%1~=0 or value<1 or value>3 then return nil,"Choose a valid preset" end
        local slot=tostring(value)
        if action=="savePreset" then
            nextKit.presets[slot]=validateEquipped(nextKit,nextKit.equipped)
        elseif nextKit.presets[slot] then
            nextKit.equipped=validateEquipped(nextKit,nextKit.presets[slot])
        else
            return nil,"This preset is empty"
        end
        return nextKit
    end
    if not field or type(value)~="number" or not field[3][value] then return nil,"Choose an available option" end
    if action=="buy" then
        if Equipment.owns(nextKit,id,value) then return nil,"You already own this option" end
        if nextKit.credits<field[5] then return nil,"More credits needed" end
        nextKit.owned[key(id,value)]=true
        nextKit.credits=nextKit.credits-field[5]
    elseif action=="equip" then
        if not Equipment.owns(nextKit,id,value) then return nil,"Unlock this option first" end
        nextKit.equipped[id]=value
    else
        return nil,"Choose a valid action"
    end
    return nextKit
end

function Equipment.preview(kit,id,value)
    local preview=Equipment.restore(kit)
    if fields[id] and fields[id][3][value] then preview.equipped[id]=value end
    return preview
end

local function colorFromRGB(rgb)
    return color(rgb[1],rgb[2],rgb[3])
end

local function tint(i)
    return colorFromRGB(swatches[i][2])
end

-- Keep blending on the source palette. A Craft material can read back its diffuse
-- value in a native representation with different fields from a Codea color.
local function blendRGB(a,b,amount)
    return color(a[1]+(b[1]-a[1])*amount,
        a[2]+(b[2]-a[2])*amount,a[3]+(b[3]-a[3])*amount)
end

local blackRGB = {24,31,42}
local black, white = colorFromRGB(blackRGB), color(246,248,247)

local function entity(r,parent,x,y,z)
    local e=r.scene:entity()
    e.parent=parent
    e.position=V(x or 0,y or 0,z or 0)
    return e
end

local function material(paint,roughness,metalness)
    local standard=asset and asset.builtin and asset.builtin.Materials
    local result=craft.material(standard and standard.Standard or "Materials:Standard")
    result.diffuse,result.roughness,result.metalness=paint,roughness or .88,metalness or .0
    return result
end

local cube
local function piece(r,parent,mat,x,y,z,w,h,d)
    local e=entity(r,parent,x,y,z)
    cube=cube or craft.model.cube()
    e.model,e.material,e.scale=cube,mat,V(w,h,d)
    return e
end

local meshCache, meshCount = {}, 0
local function mesh(shape,pattern,swatch)
    local signature=shape..":"..pattern..":"..swatch
    if meshCache[signature] then return meshCache[signature] end
    local record=patterns[pattern] or {}
    local base=swatches[swatch][2]
    local colors={}
    if record.colors then
        for i,components in ipairs(record.colors) do
            colors[i]=blendRGB(components,base,.25)
        end
    else
        colors[1]=pattern==0 and white or colorFromRGB(base)
    end
    local positions,normals,vertexColors,indices,uvs={},{},{},{},{}
    local radial=shape=="tube"
    local minX,minY=radial and 8 or 12,14
    local uv=vec2(0,0)
    for row=0,minY-1 do
        local l,h=row/minY,(row+1)/minY
        for col=0,minX-1 do
            local u,w=col/minX,(col+1)/minX
            local a,b,c,d,normal
            if radial then
                local first,last=u*twoPi,w*twoPi
                local x,z,nx,nz=math.cos(first),math.sin(first),math.cos(last),math.sin(last)
                a,b,c,d=V(x,l-.5,z),V(x,h-.5,z),V(nx,h-.5,nz),V(nx,l-.5,nz)
                normal=V(math.cos((first+last)*.5),0,math.sin((first+last)*.5))
            else
                a,b,c,d=V(u-.5,l-.5,0),V(w-.5,l-.5,0),V(w-.5,h-.5,0),V(u-.5,h-.5,0)
                normal=V(0,0,1)
            end
            local start=#positions+1
            positions[start],positions[start+1],positions[start+2],positions[start+3]=a,b,c,d
            local paint=colors[record.sample and record.sample((u+w)*.5,(l+h)*.5) or 1]
            for vertex=start,start+3 do
                vertexColors[vertex],normals[vertex],uvs[vertex]=paint,normal,uv
            end
            local index=#indices
            indices[index+1],indices[index+2],indices[index+3]=start,start+1,start+2
            indices[index+4],indices[index+5],indices[index+6]=start,start+2,start+3
            if not radial then
                indices[index+7],indices[index+8],indices[index+9]=start,start+2,start+1
                indices[index+10],indices[index+11],indices[index+12]=start,start+3,start+2
            end
        end
    end
    local model=craft.model()
    model.positions,model.normals,model.colors,model.indices,model.uvs=positions,normals,vertexColors,indices,uvs
    if meshCount>=48 then meshCache,meshCount={},0 end
    meshCache[signature],meshCount=model,meshCount+1
    return model
end

local function patch(r,parent,shared,x,y,z,w,h,d,reverse)
    local e=entity(r,parent,x,y,z)
    e.material,e.scale=shared,V(w,h,d or 1)
    if reverse then e.eulerAngles=V(0,180,0) end
    e.active=false
    return e
end

local function coat(e,shape,pattern,shade,visible)
    e.active=visible and pattern>1
    if e.active then e.model=mesh(shape,pattern,shade) end
end

local function band(r,parent,mat,x,y,z,rx,height,rz)
    local e=patch(r,parent,mat,x,y,z,rx,height,rz)
    e.model=mesh("tube",0,1)
    e.active=true
    return e
end

local function lineSegment(r,parent,mat,a,b,thickness)
    local mid=(a+b)*.5
    local e=piece(r,parent,mat,mid.x,mid.y,mid.z,thickness,(b-a):len(),thickness)
    e.rotation=quat.fromToRotation(V(0,1,0),(b-a):normalize())
    return e
end

local shaftBounds={short={-.923,.419,-.37,0},long={-1.36,.879,-.48,.46},
    goalie={-.95,.469,-.39,0}}

local function buildStick(r)
    if r.roadStick then return r.roadStick end
    local base=material(white)
    local root=r.stickRoot
    local s={finish=material(black),top=material(white),side=material(black),shoot=material(white)}
    s.upper,s.lower=patch(r,root,base,0,0,0,1,1,1),patch(r,root,base,0,0,0,1,1,1)
    s.grip=patch(r,root,base,0,0,0,1,1,1)
    s.strings=entity(r,root)
    s.goalieStrings=entity(r,root)
    local function strings(parent,goalie)
        local half=goalie and .29 or .171
        local y=goalie and 1.135 or .95
        local edge=goalie and .14 or .104
        lineSegment(r,parent,s.top,V(-edge,y,-.131),V(edge,y,-.131),.010)
        for _,dir in ipairs({-1,1}) do
            lineSegment(r,parent,s.side,V(dir*half*.54,.55,-.052),
                V(dir*half,.82,-.081),.018)
        end
        local span=half*.92
        return lineSegment(r,parent,s.shoot,V(-span,.80,-.044),V(span,.80,-.044),.013)
    end
    s.fieldLine,s.goalieLine=strings(s.strings,false),strings(s.goalieStrings,true)
    r.stickTape.material=s.finish
    r.roadStick=s
    return s
end

local function stick(r,opts)
    local s=buildStick(r)
    local size=shaftBounds[r.stickType] or shaftBounds.short
    local goalie=r.stickType=="goalie"
    local widths={1,.88,1.12}
    local radius=widths[opts.shaftModel]
    r.stickShaft.scale=V(radius,1,radius)
    r.stickShaft.material.diffuse=tint(opts.shaftColor)
    local finish={{.27,.52},{.75,.18},{.14,.67}}
    local surface=finish[opts.shaftFinish]
    r.stickShaft.material.roughness,r.stickShaft.material.metalness=surface[1],surface[2]
    s.finish.diffuse=tint(opts.gripColor)
    s.top.diffuse,s.side.diffuse,s.shoot.diffuse=tint(opts.topStringColor),tint(opts.sidewallColor),tint(opts.shootingStringColor)
    local function paintShaft(e,lo,hi)
        e.position,e.scale=V(0,(lo+hi)*.5,0),V(.031*radius,hi-lo,.031*radius)
        coat(e,"tube",opts.shaftPattern,opts.shaftColor,true)
    end
    paintShaft(s.upper,.124,size[2]-.011)
    paintShaft(s.lower,size[1]+.172,size[3]-.109)
    s.grip.position,s.grip.scale=V(0,.024,0),V(.034,.183,.034)
    coat(s.grip,"tube",opts.gripPattern,opts.gripColor,true)
    local headScale=({1,.93,1.08})[opts.headModel]
    r.stickHead.scale,r.stickMesh.scale=V(headScale,1,1),V(headScale,1,1)
    r.stickHead.material.diffuse=tint(opts.headColor)
    local meshRGB=swatches[opts.meshColor][2]
    r.stickMesh.material.diffuse=opts.meshPattern==3
        and blendRGB(meshRGB,swatches[opts.shootingStringColor][2],.44) or colorFromRGB(meshRGB)
    r.stickMesh.material.roughness=opts.meshPattern==2 and .68 or .91
    s.strings.active,s.goalieStrings.active=not goalie,goalie
    s.strings.position,s.strings.scale=V(0,size[4],0),V(headScale,1,1)
    s.goalieStrings.scale=V(headScale,1,1)
    local offset=opts.pocket==2 and .025 or opts.pocket==3 and -.05 or 0
    s.fieldLine.position,s.goalieLine.position=V(0,.8+offset,-.044),V(0,.8+offset,-.044)
end

local finishes = {
    {rough=.50,metal=.06}, {rgb={185,204,228},rough=.13,metal=.80},
    {rgb={229,185,79},rough=.15,metal=.78},
    {rgb={63,72,90},rough=.14,metal=.80},
    {rgb={208,132,121},rough=.16,metal=.76},
    {rgb={143,130,227},accent=color(85,225,221),rough=.17,metal=.76}
}

local function buildMatch(r)
    if r.roadMatch then return r.roadMatch end
    local overlay=material(white)
    local m={gloves={},sleeves={},cuff=material(black,.42)}
    for _,side in ipairs(sides) do
        local wrist=r.joints[side.."Wrist"]
        local pads=patch(r,wrist,overlay,0,.048,.130,.165,.163)
        local cuff=piece(r,wrist,m.cuff,0,.120,.099,.249,.05,.08)
        m.gloves[side]={pads=pads,cuff=cuff}
        local leg=r.legs[side]
        local fabric=material(black)
        m.sleeves[side]={fabric=fabric,
            thigh=patch(r,leg.hip,overlay,0,-.326,-.001,.137,.274,.141),
            shin=patch(r,leg.knee,overlay,0,-.175,.002,.129,.441,.145)}
        for _,part in ipairs(r.sleeveParts[side]) do part.material=fabric end
    end
    r.roadMatch=m
    return m
end

function Equipment.applyMatch(r,kit)
    if not r then return end
    local ops=(kit or Equipment.restore()).equipped
    if r.campus then P.Character.setCampusMode(r,false) end
    if r.roadCasual then
        for _,part in ipairs(r.roadCasual.parts) do part.active=false end
    end
    stick(r,ops)
    local m=buildMatch(r)
    local finish=finishes[ops.gloveFinish]
    local gloveRGB=swatches[ops.gloveColor][2]
    r.materials.gloves.diffuse=finish.rgb and blendRGB(finish.rgb,gloveRGB,.22) or colorFromRGB(gloveRGB)
    r.materials.gloveTrim.diffuse=finish.accent or tint(ops.gloveSecondary)
    r.materials.gloves.roughness,r.materials.gloves.metalness=finish.rough,finish.metal
    if ops.gloveFinish>1 then
        local env=P.Character.equipmentEnvironment()
        if env then pcall(function() r.materials.gloves.envMap=env end) end
    end
    m.cuff.diffuse=finish.accent or tint(ops.gloveAccent)
    for _,side in ipairs(sides) do
        local parts=m.gloves[side]
        local scale=({1,.91,1.07})[ops.gloveModel]
        r.arms[side].glove.scale=V(scale,1,scale)
        parts.pads.position=V(0,.048,.132*scale)
        parts.cuff.active=ops.gloveCuff>1
        parts.cuff.scale=ops.gloveCuff==3 and V(.27,.075,.10) or V(.25,.043,.085)
        coat(parts.pads,"panel",ops.glovePattern,ops.gloveAccent,true)
        local wrap=m.sleeves[side]
        local style=ops[side.."Sleeve"]
        local pattern,shade=ops[side.."SleevePattern"],ops[side.."SleeveColor"]
        wrap.fabric.diffuse=tint(shade)
        r.sleeveParts[side][1].active=style==3
        r.sleeveParts[side][2].active=style>=2
        r.exposedLegParts[side][1].active=style<3
        r.exposedLegParts[side][2].active=style<2
        coat(wrap.thigh,"tube",pattern,shade,style==3)
        coat(wrap.shin,"tube",pattern,shade,style>=2)
    end
end

local function buildCasual(r)
    if r.roadCasual then return r.roadCasual end
    local c={parts={},legs={},hoodie=material(white),
        joggers=material(black),sneakers=material(white),shoeTrim=material(black),
        pack=material(black),packTrim=material(color(47,63,80)),plain=material(white)}
    local function add(e) c.parts[#c.parts+1]=e return e end
    c.chest=add(patch(r,r.body,c.plain,0,.555,-.242,.565,.385,1,true))
    c.pantsWaist=add(piece(r,r.pelvis,c.joggers,0,-.006,0,.655,.216,.395))
    c.packRoot=add(entity(r,r.body,0,.56,.247))
    r.backpack=c.packRoot
    c.packShell=piece(r,c.packRoot,c.pack,0,.008,.158,.575,.606,.31)
    c.packCover=piece(r,c.packRoot,c.packTrim,0,.229,.262,.545,.186,.157)
    c.packPocket=piece(r,c.packRoot,c.packTrim,0,-.127,.341,.426,.193,.102)
    c.packPanel=patch(r,c.packRoot,c.plain,0,-.115,.394,.386,.159)
    r.backpackStick=entity(r,c.packRoot,.345,.194,.169)
    r.backpackStick.eulerAngles=V(0,0,-9)
    for _,k in ipairs({-1,1}) do
        lineSegment(r,c.packRoot,c.packTrim,V(k*.22,.312,.02),V(k*.263,.226,-.512),.056)
        lineSegment(r,c.packRoot,c.packTrim,V(k*.263,.226,-.512),V(k*.246,-.229,-.510),.054)
        lineSegment(r,c.packRoot,c.packTrim,V(k*.246,-.229,-.510),V(k*.22,-.286,.039),.053)
    end
    for _,y in ipairs({-.14,.12}) do
        local tie=piece(r,c.packRoot,c.packTrim,.292,y,.167,.189,.068,.141)
        tie.eulerAngles=V(0,0,8)
    end
    for _,side in ipairs(sides) do
        local hip,knee,ankle=r.legs[side].hip,r.legs[side].knee,r.legs[side].ankle
        local wrist=r.joints[side.."Wrist"]
        add(piece(r,wrist,r.materials.skin,0,-.034,0,.145,.145,.138))
        add(piece(r,wrist,r.materials.skin,.051,-.031,-.064,.070,.088,.05))
        local thigh=add(band(r,hip,c.joggers,0,-.238,0,.159,.507,.163))
        local shin=add(band(r,knee,c.joggers,0,-.192,.002,.123,.455,.146))
        local cuff=add(band(r,knee,c.packTrim,0,-.369,0,.124,.085,.147))
        local shoe=add(piece(r,ankle,c.sneakers,0,-.047,-.109,.287,.161,.426))
        local sole=add(piece(r,ankle,c.shoeTrim,0,-.116,-.108,.306,.046,.454))
        local tongue=add(piece(r,ankle,c.sneakers,0,.022,-.046,.190,.130,.229))
        local heel=add(piece(r,ankle,c.shoeTrim,0,-.039,.079,.24,.102,.043))
        for i=0,2 do
            local lace=add(piece(r,ankle,c.shoeTrim,0,.026+i*.013,-.182+i*.047,.139,.020,.017))
            lace.eulerAngles=V(0,0,8-i*8)
        end
        local paintTop=add(patch(r,hip,c.plain,0,-.235,0,.163,.50,.167))
        local paintBottom=add(patch(r,knee,c.plain,0,-.186,.002,.127,.444,.150))
        local sleeveThigh=add(patch(r,hip,c.plain,0,-.302,0,.168,.380,.172))
        local sleeveShin=add(patch(r,knee,c.plain,0,-.16,.002,.133,.43,.155))
        c.legs[side]={thigh=thigh,shin=shin,cuff=cuff,shoe=shoe,sole=sole,tongue=tongue,heel=heel,
            paintTop=paintTop,paintBottom=paintBottom,sleeveThigh=sleeveThigh,sleeveShin=sleeveShin}
    end
    r.roadCasual=c
    return c
end

function Equipment.applyCasual(r,profile,kit,stickType)
    P.Character.apply(r,profile)
    P.Character.setStickType(r,stickType or r.stickType)
    P.Character.setCampusMode(r,true)
    local c=buildCasual(r)
    local ops=(kit or Equipment.restore()).equipped
    for _,part in ipairs(c.parts) do part.active=true end
    if r.roadMatch then
        for _,side in ipairs(sides) do
            local glove,wrap=r.roadMatch.gloves[side],r.roadMatch.sleeves[side]
            glove.pads.active,glove.cuff.active,wrap.thigh.active,wrap.shin.active=false,false,false,false
        end
    end
    local hoodieRGB=swatches[ops.hoodieColor][2]
    local sneakerRGB=swatches[ops.sneakerColor][2]
    local packRGB=swatches[ops.backpackColor][2]
    r.materials.hoodie.diffuse=colorFromRGB(hoodieRGB)
    r.materials.hoodTrim.diffuse=blendRGB(hoodieRGB,blackRGB,.48)
    c.sneakers.diffuse,c.joggers.diffuse=colorFromRGB(sneakerRGB),tint(ops.joggerColor)
    c.shoeTrim.diffuse=blendRGB(sneakerRGB,blackRGB,.78)
    c.pack.diffuse=colorFromRGB(packRGB)
    c.packTrim.diffuse=blendRGB(packRGB,blackRGB,.54)
    local packShape=({{.575,.606,.31},{.505,.704,.263},{.611,.707,.34}})[ops.backpackStyle]
    c.packShell.scale=V(packShape[1],packShape[2],packShape[3])
    c.packCover.position=V(0,packShape[2]*.38,.262)
    coat(c.chest,"panel",ops.hoodiePattern,ops.hoodieColor,true)
    coat(c.packPanel,"panel",ops.backpackPattern,ops.backpackColor,true)
    for _,side in ipairs(sides) do
        local leg=c.legs[side]
        local style=ops[side.."Sleeve"]
        local pattern,shade=ops[side.."SleevePattern"],ops[side.."SleeveColor"]
        coat(leg.paintTop,"tube",ops.joggerPattern,ops.joggerColor,style~=3)
        coat(leg.paintBottom,"tube",ops.joggerPattern,ops.joggerColor,style==1)
        leg.sleeveThigh.active,leg.sleeveShin.active=style==3,style>=2
        if leg.sleeveThigh.active then leg.sleeveThigh.model=mesh("tube",pattern,shade) end
        if leg.sleeveShin.active then leg.sleeveShin.model=mesh("tube",pattern,shade) end
        leg.tongue.scale=ops.sneaker==2 and V(.211,.203,.225) or V(.19,.13,.229)
        leg.sole.scale=ops.sneaker==3 and V(.319,.062,.465) or V(.306,.046,.454)
    end
    stick(r,ops)
    r.stickRoot.parent=r.backpackStick
    r.stickRoot.position,r.stickRoot.eulerAngles=V(0,0,0),V(0,0,0)
end

function Equipment.newCasual(scene,profile,kit,stickType)
    local rig=P.Character.new(scene)
    Equipment.applyCasual(rig,profile,kit,stickType)
    return rig
end
end

-- Story
do
-- Road to Glory | Versioned chapter state, dialogue, and gameplay outcomes.
PolyLax = PolyLax or {}
local P = PolyLax
local Story = {}
P.Story = Story

local key = "PolyLax.RoadToGlory.1"
local version = 1
local zones = {campus=true,school=true,lockers=true,training=true,coach=true,drip=true,clubhouse=true}
local targets = {mercer="coach",driplab="drip",locker="tryout",field="practice"}
local act = "freshmen"
local relationships = {ethan=55,coach=36,jace=26}
local startPosition = {zone="campus",x=0,z=9,yaw=0,cameraYaw=0,zoomSteps=0}
local placements = {"JV development","JV rotation","Varsity rotation"}

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

local function replace(target, value)
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(value) do target[k] = v end
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function count(value, default, minimum, maximum)
    if not finite(value) then return default end
    return math.max(minimum,math.min(maximum,math.floor(value)))
end

local function sanitizeLocation(raw)
    if type(raw) ~= "table" or not zones[raw.zone]
        or not finite(raw.x) or not finite(raw.z) or math.abs(raw.x)>200 or math.abs(raw.z)>200 then
        return copy(startPosition)
    end
    return {zone=raw.zone,x=raw.x,z=raw.z,yaw=finite(raw.yaw) and raw.yaw or 0,
        cameraYaw=finite(raw.cameraYaw) and raw.cameraYaw or 0,
        zoomSteps=count(raw.zoomSteps,0,-3,3)}
end

local function equipment(raw)
    return P.RoadEquipment and P.RoadEquipment.restore(raw) or copy(type(raw)=="table" and raw or {})
end

local function normalizeAthlete(raw)
    local athlete = P.Career.new()
    if type(raw) ~= "table" then return athlete end
    athlete.name = type(raw.name)=="string" and raw.name:sub(1,40) or athlete.name
    athlete.position = count(raw.position,athlete.position,1,#P.Career.positions)
    local team = P.SchoolTeams.get(raw.team)
    if team and team.group=="highSchool" then athlete.team=team.id end
    athlete.attributes = P.Attributes.restore(raw.attributes,athlete.position)
    athlete.appearance = type(raw.appearance)=="table" and copy(raw.appearance) or nil
    for _, field in ipairs({"games","wins","losses","ties","xp"}) do
        athlete[field]=count(raw[field],athlete[field],0,1000000)
    end
    if type(raw.stats)=="table" then
        for field in pairs(athlete.stats) do
            local value=raw.stats[field]
            if finite(value) then athlete.stats[field]=value end
        end
    end
    return athlete
end

function Story.new()
    return {version=version,chapter=act,mission="arrival",timeOfDay="morning",day=1,
        athlete=P.Career.new(),equipment=equipment(),location=copy(startPosition),completed={},
        flags={},relationships=copy(relationships),reputation=0,results={},
        ethan={position=2,attributes=P.Attributes.forPosition(2),training=0,form=53,
            health="available",depth="Freshman",recruiting=0,
            statTotals={games=0,goals=0,assists=0,groundBalls=0,secondsPlayed=0}}}
end

local function restore(raw)
    local save = Story.new()
    save.athlete=normalizeAthlete(raw.athlete)
    save.equipment=equipment(raw.equipment)
    save.location=sanitizeLocation(raw.location)
    local chapter=P.StoryChapters
    if type(raw.completed)=="table" then
        for _,id in ipairs(chapter.sequence) do
            if raw.completed[id]==true then save.completed[id]=true end
        end
    end
    if type(raw.flags)=="table" then save.flags=copy(raw.flags) end
    if type(raw.relationships)=="table" then
        for name,value in pairs(relationships) do
            save.relationships[name]=count(raw.relationships[name],value,0,100)
        end
    end
    save.reputation=count(raw.reputation,0,0,100)
    save.day=count(raw.day,1,1,1000)
    if raw.timeOfDay=="afternoon" or raw.timeOfDay=="practice" or raw.timeOfDay=="evening" then
        save.timeOfDay=raw.timeOfDay
    end
    if type(raw.ethan)=="table" then
        local stored=raw.ethan
        save.ethan.training=count(stored.training,0,0,1000)
        save.ethan.form=count(stored.form,53,0,100)
        save.ethan.recruiting=count(stored.recruiting,0,0,100)
        save.ethan.attributes=P.Attributes.restore(stored.attributes,save.ethan.position)
        if stored.health=="managed strain" then save.ethan.health=stored.health end
        for _,depth in ipairs(placements) do
            if stored.depth==depth then save.ethan.depth=depth end
        end
        if type(stored.statTotals)=="table" then
            for field in pairs(save.ethan.statTotals) do
                save.ethan.statTotals[field]=count(stored.statTotals[field],0,0,1000000)
            end
        end
    end
    if type(raw.results)=="table" then
        for _,id in ipairs({"tryout","debut","practice","training"}) do
            local row=raw.results[id]
            if type(row)=="table" and type(row.focus)=="string" and type(row.placement)=="string"
                and finite(row.grade) then save.results[id]=copy(row) end
        end
    end
    local mission=raw.mission
    if chapter.missions[mission] then save.mission=mission end
    if save.mission=="tryout" or save.mission=="debrief" or save.mission=="promise"
        or save.mission=="debut" or save.mission=="complete" then save.completed.practice=true end
    if (save.mission=="debrief" or save.mission=="promise" or save.mission=="debut"
        or save.mission=="complete") and not save.results.tryout then
        save.mission="tryout"
    end
    local node=raw.node
    if type(node)=="string" and chapter.nodes[node] then save.node=node end
    return save
end

function Story.load()
    local save=Story.new()
    if not readLocalData then return save end
    local read, raw=pcall(readLocalData,key)
    if read and raw==nil then return save end
    local ok, value=pcall(function() return json.decode(raw) end)
    if not read or not ok or type(value)~="table" or value.version~=version then
        save.saveError="Road to Glory save could not be read."
        return save
    end
    return restore(value)
end

function Story.save(save)
    if save.saveError then return false,save.saveError end
    local encoded, raw=pcall(function() return json.encode(save) end)
    if not encoded or type(raw)~="string" then return false,"Could not encode Road to Glory progress." end
    local written, reply=pcall(saveLocalData,key,raw)
    if not written or reply==false then return false,"Could not save Road to Glory progress." end
    return true
end

local function change(save, writer)
    local draft=copy(save)
    writer(draft)
    local ok, reason=Story.save(draft)
    if not ok then return false,reason end
    local athlete, kit=save.athlete,save.equipment
    replace(athlete,draft.athlete)
    replace(kit,draft.equipment)
    draft.athlete,draft.equipment=athlete,kit
    replace(save,draft)
    return true
end

function Story.setLocation(save, point)
    local location=sanitizeLocation(point)
    return change(save,function(draft) draft.location=location end)
end

Story.saveLocation = Story.setLocation

function Story.saveEquipment(save, candidate)
    return change(save,function(draft) draft.equipment=equipment(candidate) end)
end

function Story.updateAthlete(save, candidate)
    if save.results.tryout and (candidate.position~=save.athlete.position or candidate.team~=save.athlete.team) then
        return false,"Your roster assignment is locked after the tryout."
    end
    return change(save,function(draft) draft.athlete=normalizeAthlete(candidate) end)
end

function Story.objective(save)
    local chapter=P.StoryChapters
    local mission=chapter.missions[save.mission]
    return mission.title,mission.detail
end

local function complete(save)
    for i,id in ipairs(P.StoryChapters.sequence) do
        if id==save.mission then
            save.completed[id]=true
            save.mission=P.StoryChapters.sequence[i+1] or id
            save.node=nil
            if id=="arrival" then save.timeOfDay="afternoon" end
            if id=="locker" then save.timeOfDay="practice" end
            if id=="debrief" then save.timeOfDay="evening" end
            if id=="promise" then save.timeOfDay,save.day="afternoon",save.day+1 end
            if id=="debut" then save.timeOfDay="evening" end
            return
        end
    end
end

local function dialogue(save, id)
    local chapter=P.StoryChapters
    local node=chapter.nodes[id]
    local event={kind="dialogue",mission=save.mission,node=id,speaker=chapter.characters[node.speaker],
        text=type(node.text)=="function" and node.text(save) or node.text,choices={}}
    for i,item in ipairs(node.options) do
        event.choices[i]={id=item.id,label=item.label}
    end
    return event
end

local function line(character, text)
    return {kind="dialogue",speaker=P.StoryChapters.characters[character],text=text,
        transient=true,choices={{id="close",label="Continue"}}}
end

function Story.interact(save, target)
    target=targets[target] or target
    if not target then return end
    if target=="clubs" then return {kind="clubs"} end
    if save.saveError then return line("coach",save.saveError) end
    local mission=P.StoryChapters.missions[save.mission]
    if target==mission.target then
        if mission.activity then return {kind="activity",activity=mission.activity} end
        return dialogue(save,save.node or mission.node)
    end
    if target=="drip" then return {kind="shop"} end
    if target=="practice" or target=="training" then return {kind="activity",activity=target} end
    if target=="ethan" then
        if save.results.debut then
            local note=save.flags.friendship=="partners" and "Still good for those extra reps this week?"
                or save.flags.friendship=="compete" and "I’m keeping track of our next head-to-head shift."
                or "Let me know when you want to run again."
            return line(target,"“Good to have a real game in the books. "..note.."”")
        end
        return line(target,"“Check the next objective. I’ll see you outside when you’re done.”")
    elseif target=="coach" then
        return line(target,save.results.tryout and "“Keep working on one useful adjustment per shift.”"
            or "“Keep moving through check-in. I’ll be here after the tryout.”")
    elseif target=="jace" then
        return line(target, save.relationships.jace>=30 and "“Show up early. We can work through a set of clears.”"
            or "“I’ll let your next shift do the talking.”")
    elseif target=="maya" then
        local debut=save.results.debut
        if debut and finite(debut.homeScore) and finite(debut.awayScore) then
            return line(target, ("“I’ve got the %d–%d final. The school paper is covering your first game.”")
                :format(math.floor(debut.homeScore),math.floor(debut.awayScore)))
        end
        return line(target,save.results.tryout and
            "“How did the tryout feel from the field? I’m collecting quotes for the Briarbank paper.”" or
            "“Maya Brooks, school paper. I’m following the freshman lacrosse class this year. See you at the field.”")
    elseif target=="tryout" then
        return line(target,"Your assignment is posted on the objective tracker.")
    end
end

function Story.choose(save, event, choice)
    if type(event)~="table" or event.transient then return end
    local mission=P.StoryChapters.missions[save.mission]
    if event.mission~=save.mission or event.node~=(save.node or mission.node) then
        return nil,"That conversation has already moved on."
    end
    local node=P.StoryChapters.nodes[event.node]
    if not node then return nil,"That conversation is unavailable." end
    for _,item in ipairs(node.options) do
        if item.id==choice then
            local ok, reason=change(save,function(draft)
                for field,value in pairs(item.changes or {}) do
                    if relationships[field] then
                        draft.relationships[field]=count(draft.relationships[field]+value,0,0,100)
                    elseif field=="reputation" then
                        draft.reputation=count(draft.reputation+value,0,0,100)
                    else
                        draft.flags[field]=value
                    end
                end
                if item.finish then complete(draft)
                else draft.node=item.nextNode end
            end)
            if not ok then return nil,reason end
            if item.finish then return node.after and copy(node.after) end
            return dialogue(save,save.node)
        end
    end
    return nil,"That response is unavailable."
end

local function stat(stats, name, legacy)
    return count(stats[name] or stats[legacy],0,0,200)
end

local function evaluation(stats, role)
    local ground=stat(stats,"groundBalls")
    local goals, assists=stat(stats,"goals"),stat(stats,"assists")
    local saves,allowed=stat(stats,"saves"),stat(stats,"goalsAllowed")
    local draws,attempts=stat(stats,"faceoffsWon","faceoffs"),stat(stats,"faceoffAttempts")
    local takes, picks=stat(stats,"causedTurnovers","forcedTurnovers"),stat(stats,"interceptions")
    local passes=stat(stats,"completions")
    local score, focus
    if role=="G" then
        score=saves*12-allowed*3+passes*3
        focus=string.format("%d saves, %d goals allowed, %d completed outlets",saves,allowed,passes)
    elseif role=="FOGO" then
        score=draws*15-math.max(0,attempts-draws)*2+ground*4+passes*2
        focus=string.format("%d of %d faceoffs, %d ground balls",draws,math.max(draws,attempts),ground)
    elseif role=="D" or role=="LSM" or role=="SSDM" then
        score=takes*11+picks*8+ground*6+passes*2
        focus=string.format("%d caused turnovers, %d interceptions, %d ground balls",takes,picks,ground)
    elseif role=="M" then
        score=goals*12+assists*9+ground*5+passes*3+takes*5
        focus=string.format("%d goals, %d assists, %d ground balls, %d completed passes",goals,assists,ground,passes)
    else
        score=goals*16+assists*11+ground*4+passes*2
        focus=string.format("%d goals, %d assists, %d completed passes",goals,assists,passes)
    end
    return score-stat(stats,"turnovers")*5-stat(stats,"penalties")*6,focus
end

local function ethanTryout(save, result)
    local score=result and 44+evaluation(result,"M") or save.ethan.form
    local readiness=(save.flags.prep=="together" and 8 or 0)+(save.flags.bond=="rivalry" and -4 or 0)
    local ethan=save.ethan
    ethan.form=count(score+readiness,53,0,100)
    ethan.training=ethan.training+(save.flags.prep=="together" and 2 or 1)
    ethan.health=save.flags.bond=="rivalry" and save.flags.prep=="alone" and "managed strain" or "available"
    ethan.depth=ethan.form>=67 and placements[3] or ethan.form>=47 and placements[2] or placements[1]
    ethan.recruiting=ethan.recruiting+(ethan.form>=67 and 3 or 1)
    ethan.attributes.stamina=math.min(99,ethan.attributes.stamina+1)
end

local function recordBox(draft, result)
    local stats = result.stats
    local athlete=draft.athlete
    athlete.games=athlete.games+1
    local key=result.homeScore>result.awayScore and "wins" or result.homeScore<result.awayScore and "losses" or "ties"
    athlete[key]=athlete[key]+1
    athlete.xp=athlete.xp+16
    for _,name in ipairs(P.Career.statKeys) do
        if finite(stats[name]) then athlete.stats[name]=(athlete.stats[name] or 0)+stats[name] end
    end
    local own=type(result.ethanStats)=="table" and result.ethanStats or nil
    if own then
        local ethan=draft.ethan
        ethan.statTotals.games=ethan.statTotals.games+1
        for _,name in ipairs({"goals","assists","groundBalls","secondsPlayed"}) do
            ethan.statTotals[name]=ethan.statTotals[name]+count(own[name],0,0,3600)
        end
        ethan.training=ethan.training+1
        ethan.form=count(ethan.form+evaluation(own,"M")*.15,53,0,100)
        ethan.recruiting=count(ethan.recruiting+(ethan.depth=="Varsity rotation" and 2 or 1),0,0,100)
    end
end

function Story.recordActivity(save, activity, result)
    local optionalActivity=activity=="practice" or activity=="training"
    local assigned=save.mission==activity
    if activity~="tryout" and activity~="debut" and not optionalActivity then
        return false,"Unknown Road to Glory activity."
    end
    if not optionalActivity and not assigned then return false,"This result has already been recorded." end
    local previouslyRecorded=save.results[activity]
    if optionalActivity and previouslyRecorded and not assigned then return true,previouslyRecorded end
    if type(result)~="table" or type(result.stats)~="table"
        or not finite(result.homeScore) or not finite(result.awayScore) or result.homeScore<0 or result.awayScore<0
        or not finite(result.elapsed) or result.elapsed<=0 then
        return false,"Finish the activity before saving a result."
    end
    local role=P.Career.positions[save.athlete.position].role
    local merit, focus=evaluation(result.stats,role)
    local teamBonus=result.homeScore>result.awayScore and 3 or 0
    local grade=count(44+merit+teamBonus+(save.relationships.coach-36)*.38,44,0,100)
    local placement=grade>=65 and placements[3] or grade>=48 and placements[2] or placements[1]
    local receipt={grade=grade,focus=focus,placement=placement,stats=copy(result.stats),
        homeScore=result.homeScore,awayScore=result.awayScore,
        secondsPlayed=count(result.stats.secondsPlayed,count(result.elapsed,0,0,3600),0,3600)}
    local ok, reason=change(save,function(draft)
        draft.results[activity]=receipt
        if assigned then complete(draft) end
        local reward=optionalActivity and 15 or activity=="tryout" and 40 or 60
        if not previouslyRecorded then
            draft.equipment.credits=count((draft.equipment.credits or 0)+reward,0,0,1000000)
        end
        if activity=="tryout" then
            ethanTryout(draft,result.ethanStats)
        elseif activity=="debut" then
            recordBox(draft,result)
        end
    end)
    if not ok then return false,reason end
    return true,receipt
end
end

-- RoadEquipmentUI
do
-- Drip Lab previews are local to the shop. Only a confirmed save changes the career.
PolyLax = PolyLax or {}
local P = PolyLax
local Shop = {}
P.RoadEquipmentUI = Shop

local colors = {
    ink=color(19,27,34), shadow=color(8,13,17), panel=color(23,34,43),
    line=color(50,68,81), highlight=color(23,84,64), mint=color(129,240,187),
    paper=color(238,247,247), subdued=color(163,182,191), gold=color(239,190,110)
}

local function field(view)
    local section=P.RoadEquipment.sections[view.section]
    return section.fields and section.fields[view.field]
end

local function cycle(value,offset,count)
    return (value-1+offset)%count+1
end

local function refresh(view)
    local equipment=P.RoadEquipment
    local selected=field(view)
    local preview=selected and equipment.preview(view.kit,selected[1],view.choice) or view.kit
    if view.section==3 and selected then
        -- Preview different threads even before the player buys the sleeve itself.
        local side=selected[1]:match("^left") and "left" or "right"
        local style=side.."Sleeve"
        if selected[1]~=style and preview.equipped[style]==1 then preview.equipped[style]=3 end
    end
    local rig=view.rig
    if view.section>=4 then
        equipment.applyCasual(rig,view.profile,preview,view.stickType)
    else
        P.Character.setCampusMode(rig,false)
        P.Character.apply(rig,view.profile)
        P.Character.setStickType(rig,view.stickType)
        equipment.applyMatch(rig,preview)
    end
end

function Shop.new(scene,profile,kit,stickType,onSave)
    local view={
        scene=scene,profile=profile,kit=P.RoadEquipment.restore(kit),stickType=stickType or "short",
        onSave=onSave,section=1,field=1,preset=1,elapsed=0,heading=-14,goalHeading=-14
    }
    view.choice=view.kit.equipped.shaftPattern
    view.rig=P.Character.new(scene)
    view.camera=P.CameraController.new(scene,38)
    view.camera.lens.farPlane=45
    local stage=scene:entity()
    local standard=asset and asset.builtin and asset.builtin.Materials
    stage.model=craft.model.cube()
    stage.material=craft.material(standard and standard.Standard or "Materials:Standard")
    stage.material.diffuse=color(50,76,79)
    stage.position,stage.scale=vec3(0,-.086,0),vec3(3.4,.16,3.3)
    refresh(view)
    view.animation=P.AnimationController.new(view.rig)
    return view
end

local function add(layout,id,label,x,y,w,h,selected,enabled)
    local item={id=id,label=label,x=x,y=y,w=w,h=h,selected=selected,enabled=enabled~=false}
    layout.items[#layout.items+1]=item
    layout.byId[id]=item
    return item
end

function Shop.layout(view)
    local safe=P.UI.safeArea()
    local width=math.min(504,WIDTH-safe.left-safe.right-22)
    local mid=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-8,safe.bottom+10
    local L={items={},byId={},width=width,mid=mid,top=top,bottom=bottom}
    L.topRow,L.tabsY=top-23,top-69
    local left,right=mid-width*.5,mid+width*.5
    L.editorTop=bottom+176
    L.previewBottom,L.previewTop=L.editorTop+4,L.tabsY-22
    L.fieldY,L.valueY,L.actionY=bottom+134,bottom+84,bottom+25
    add(L,"BACK","Exit",left+33,L.topRow,66,38)
    local sections=P.RoadEquipment.sections
    local step=width/#sections
    for number,tab in ipairs(sections) do
        add(L,tab.id,tab.label,left+(number-.5)*step,L.tabsY,step-4,36,number==view.section)
    end
    if view.section==5 then
        local p=tostring(view.preset)
        local preset=view.kit.presets[p]
        L.fieldLabel="Look "..p
        L.valueLabel=preset and "Saved equipment and outfit" or "Empty preset"
        add(L,"VALUE_PREV","‹",left+23,L.valueY,46,42)
        add(L,"VALUE_NEXT","›",right-23,L.valueY,46,42)
        local w=(width-8)*.5
        add(L,"SAVE_PRESET","Save look",mid-(w+8)*.5,L.actionY,w,44,true)
        add(L,"LOAD_PRESET","Equip look",mid+(w+8)*.5,L.actionY,w,44,false,preset~=nil)
    else
        local selected=field(view)
        local id,count=selected[1],#P.RoadEquipment.sections[view.section].fields
        L.fieldLabel=selected[2]
        L.fieldCount=view.field.." / "..count
        L.valueLabel=selected[3][view.choice]
        add(L,"FIELD_PREV","‹",left+23,L.fieldY,46,42)
        add(L,"FIELD_NEXT","›",right-23,L.fieldY,46,42)
        add(L,"VALUE_PREV","‹",left+23,L.valueY,46,42)
        add(L,"VALUE_NEXT","›",right-23,L.valueY,46,42)
        if view.choice==view.kit.equipped[id] then
            add(L,"EQUIP","Equipped",mid,L.actionY,width,44,false,false)
        elseif P.RoadEquipment.owns(view.kit,id,view.choice) then
            add(L,"EQUIP","Equip",mid,L.actionY,width,44,true)
        else
            add(L,"BUY","Buy • "..selected[5].." credits",mid,L.actionY,width,44,true,
                view.kit.credits>=selected[5])
        end
    end
    return L
end

local function label(value,x,y,size,ink,width)
    if not value then return end
    fontSize(size)
    if textSize and width then
        local actual=textSize(value)
        if actual>width then fontSize(math.max(9,size*width/actual)) end
    end
    fill(ink)
    text(value,x,y)
end

local function panel(x,y,w,h,corner,ink)
    P.Style.rounded(x,y,w,h,corner,ink)
end

local function drawButton(item)
    local fillColor=item.selected and colors.highlight or colors.panel
    local strokeColor=item.selected and colors.mint or colors.line
    panel(item.x,item.y,item.w,item.h,10,strokeColor)
    panel(item.x,item.y,item.w-2,item.h-2,9,fillColor)
    label(item.label,item.x,item.y,(item.label=="‹" or item.label=="›") and 24 or 14,
        item.enabled and colors.paper or colors.subdued,item.w-10)
end

local function renderPreview(view,L,dt)
    local rig=view.rig
    view.heading=view.heading+(view.goalHeading-view.heading)*(1-math.exp(-dt*15))
    rig.root.eulerAngles=vec3(0,view.heading,0)
    P.AnimationController.update(view.animation,dt,{speed=0})
    local height=rig.proportions.scale.y
    local equipmentY,objectSpan,radius=1.45*height,3.12*height,1.45
    if view.section==2 then equipmentY,objectSpan,radius=1.57*height,1.56*height,1.02 end
    if view.section==3 then equipmentY,objectSpan,radius=.58*height,1.29*height,.73 end
    local t=view.camera.tanHalf
    local visible=math.max(.27,(L.previewTop-L.previewBottom)/HEIGHT)
    local dist=math.max(radius/(t*WIDTH/HEIGHT*.87),objectSpan/(2*t*visible*.87))
    local q=(L.previewTop+L.previewBottom)/HEIGHT-1
    local eyeY=equipmentY-q*dist*t
    local eye=vec3(0,eyeY,-dist)
    view.camera.entity.position=eye
    view.camera.entity.rotation=quat.lookRotation(vec3(0,0,1),vec3(0,1,0))
    view.scene:update(dt)
    view.scene:draw()
end

function Shop.draw(view,dt)
    dt=math.max(0,math.min(dt or 0,.05))
    local L=Shop.layout(view)
    view.elapsed=view.elapsed+dt
    if view.messageTime and view.elapsed>=view.messageTime then view.message=nil end
    renderPreview(view,L,dt)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CORNER)
    textMode(CENTER)
    textAlign(CENTER)
    noStroke()
    font("AvenirNext-DemiBold")
    fill(colors.shadow)
    rect(0,0,WIDTH,L.editorTop)
    rect(0,L.previewTop,WIDTH,HEIGHT-L.previewTop)
    local cx=L.mid
    label("Drip Lab",cx,L.topRow,22,colors.paper,L.width-148)
    label(tostring(view.kit.credits).." cr",cx+L.width*.5-35,L.topRow,15,colors.gold,69)
    label("Drag preview to rotate",cx,L.previewBottom+14,12,colors.paper,L.width)
    label(L.fieldLabel,cx,L.fieldY+6,17,colors.paper,L.width-106)
    label(L.fieldCount,cx,L.fieldY-14,11,colors.subdued,55)
    label(L.valueLabel,cx,L.valueY,16,colors.mint,L.width-108)
    if view.message then
        label(view.message,cx,L.bottom+55,12,colors.gold,L.width-10)
    end
    for _,item in ipairs(L.items) do drawButton(item) end
    popMatrix()
    popStyle()
end

local function selectField(view)
    local selected=field(view)
    view.choice=selected and view.kit.equipped[selected[1]] or 1
end

local function commit(view,action)
    local selected=field(view)
    local candidate,message=P.RoadEquipment.change(view.kit,action,selected and selected[1],
        selected and view.choice or view.preset)
    if candidate and view.onSave then
        local saved
        saved,message=view.onSave(candidate)
        if not saved then candidate=nil end
    end
    if candidate and view.onSave then
        view.kit=candidate
        message=action=="buy" and "Unlocked. Equip it to keep this look." or
            action=="savePreset" and "Look saved" or "Equipped"
    else
        message=message or "Could not save your changes"
    end
    view.message,view.messageTime=message,view.elapsed+2.4
    refresh(view)
end

local function handle(view,id)
    for number,tab in ipairs(P.RoadEquipment.sections) do
        if tab.id==id then
            view.section,view.field=number,1
            view.goalHeading=number>=4 and 156 or -14
            selectField(view)
            refresh(view)
            return
        end
    end
    if id=="BACK" then return "BACK" end
    if id=="FIELD_PREV" or id=="FIELD_NEXT" then
        local section=P.RoadEquipment.sections[view.section]
        view.field=cycle(view.field,id=="FIELD_PREV" and -1 or 1,#section.fields)
        selectField(view)
        refresh(view)
    elseif id=="VALUE_PREV" or id=="VALUE_NEXT" then
        local offset=id=="VALUE_PREV" and -1 or 1
        if view.section==5 then
            view.preset=cycle(view.preset,offset,3)
        else
            view.choice=cycle(view.choice,offset,#field(view)[3])
            refresh(view)
        end
    elseif id=="BUY" then commit(view,"buy")
    elseif id=="EQUIP" then commit(view,"equip")
    elseif id=="SAVE_PRESET" then commit(view,"savePreset")
    elseif id=="LOAD_PRESET" then commit(view,"loadPreset") end
end

function Shop.touch(view,touch)
    if touch.state==BEGAN then
        local L=Shop.layout(view)
        for _,item in ipairs(L.items) do
            if P.UI.hit(item,touch.x,touch.y) then
                if item.enabled then return handle(view,item.id) end
                return
            end
        end
        if touch.y>=L.previewBottom and touch.y<=L.previewTop and not view.drag then
            view.drag={id=touch.id,x=touch.x}
        end
    elseif view.drag and view.drag.id==touch.id then
        if touch.state==MOVING then
            view.goalHeading=view.goalHeading+(touch.x-view.drag.x)*.8
            view.drag.x=touch.x
        else
            view.drag=nil
        end
    end
end
end

-- CampusPeople
do
-- Stable appearance recipes for named people and authored background spawn slots.
PolyLax = PolyLax or {}
local People = {}
PolyLax.CampusPeople = People

local named = {
    ethan={name="Ethan Cole",role="athlete",height=1.02,width=.97,frame="athletic",
        faceWidth=.97,faceHeight=1.01,headShape="oval",skin={195,134,102},hair={86,47,33},haircut="sweep",
        shirt={40,102,91},trim={126,178,157},pants={48,67,86},shoe={230,232,221},outfit="hoodie",
        shoeStyle="court",accessory="watch",motion="easy"},
    jace={name="Jace Holloway",role="athlete",height=1.07,width=1.13,frame="broad",
        faceWidth=1.04,faceHeight=.98,headShape="angular",skin={126,80,60},hair={26,23,24},haircut="crop",
        shirt={171,63,37},trim={237,218,172},pants={39,48,69},shoe={218,225,230},outfit="varsity",
        shoeStyle="runner",accessory="wristband",motion="athletic"},
    coach={name="Coach Daniel Mercer",role="coach",height=1.05,width=1.11,frame="broad",
        faceWidth=1.03,faceHeight=1.07,headShape="long",skin={200,148,111},hair={98,94,89},
        haircut="neat",beard=true,glasses=true,shirt={43,59,85},trim={150,166,179},pants={88,92,77},
        shoe={111,80,62},outfit="jacket",shoeStyle="boot",accessory="lanyard",motion="measured"},
    maya={name="Maya Brooks",role="journalist",height=.97,width=.94,frame="slim",
        faceWidth=.97,faceHeight=1.02,headShape="round",skin={165,109,83},hair={34,24,29},
        haircut="braids",earrings=true,shirt={80,62,118},trim={235,178,101},pants={52,65,82},
        shoe={228,221,197},outfit="cardigan",shoeStyle="court",accessory="notebook",motion="animated"},
    drip={name="Nina Reyes",role="staff",height=.96,width=.95,frame="slim",
        faceWidth=.96,faceHeight=.99,headShape="oval",skin={150,94,72},hair={41,29,35},
        haircut="bun",earrings=true,shirt={101,78,156},trim={241,160,100},pants={50,47,71},
        shoe={177,147,223},outfit="apron",shoeStyle="runner",accessory="watch",motion="animated"},
    training={name="Trainer Avery",role="coach",height=1.01,width=1.04,frame="athletic",
        faceWidth=1.01,faceHeight=.99,headShape="angular",skin={105,65,50},hair={30,28,36},
        haircut="curls",shirt={30,101,119},trim={224,189,106},pants={52,61,68},
        shoe={208,228,222},outfit="polo",shoeStyle="runner",accessory="lanyard",motion="athletic"}
}

local function copy(source)
    local result={}
    for key,value in pairs(source) do
        result[key]=type(value)=="table" and copy(value) or value
    end
    return result
end

function People.named(id)
    if not named[id] then return end
    local result=copy(named[id])
    result.id=id
    return result
end

-- Used for appearance and animation offsets without consuming gameplay randomness.
function People.seed(key)
    local value=14369
    for i=1,#key do value=(value*131+key:byte(i))%2147483647 end
    return value
end

local skin={{105,66,52},{134,85,64},{165,109,79},{193,133,98},{216,158,119},{235,184,147}}
local hair={{33,29,28},{56,35,32},{101,58,36},{163,105,70},{200,153,94},{101,95,87}}
local shades={
    {{158,67,65},{238,172,117}},{{64,111,126},{164,211,205}},{{137,91,50},{230,187,99}},
    {{66,94,73},{185,201,132}},{{112,78,126},{203,163,196}},{{61,82,123},{160,186,221}},
    {{160,96,53},{242,205,146}},{{83,91,105},{176,192,211}}
}
local pants={{48,59,78},{64,70,69},{69,58,54},{49,61,78}}
local shoes={{216,222,219},{139,107,86},{205,219,191},{128,149,168}}
local headShapes={"oval","angular","round","long"}
local frames={"slim","athletic","broad"}
local haircuts={"sweep","crop","neat","bun","bob","curls","braids"}
local roles={
    student={outfits={"hoodie","cardigan","varsity"},accessories={"pack","watch","notebook"},motion={"easy","animated","athletic"}},
    coach={outfits={"jacket","polo"},accessories={"lanyard","watch"},motion={"measured","athletic"}},
    staff={outfits={"cardigan","polo","jacket"},accessories={"lanyard","notebook"},motion={"measured","animated"}}
}

local function generated(id,role,key,used)
    local state=People.seed(key)
    local function pick(values)
        state=(state*48271)%2147483647
        return values[state%#values+1]
    end
    local options=roles[role]
    -- Nearby people get different hair silhouettes and primary outfit colors.
    local combinations=#haircuts*#shades
    local combination=state%combinations
    for _=1,combinations do
        if not used[combination] then break end
        combination=(combination+1)%combinations
    end
    used[combination]=true
    local style=haircuts[combination%#haircuts+1]
    local cloth=shades[math.floor(combination/#haircuts)+1]
    local skinTone,frame=pick(skin),pick(frames)
    return {
        id=id,role=role,height=pick({.93,.97,1.01,1.05,1.09}),width=pick({.91,.96,1.01,1.06}),
        frame=frame,faceWidth=pick({.94,1,1.06}),faceHeight=pick({.95,1,1.05}),
        headShape=pick(headShapes),skin=copy(skinTone),hair=copy(pick(hair)),haircut=style,
        shirt=copy(cloth[1]),trim=copy(cloth[2]),pants=copy(pick(pants)),shoe=copy(pick(shoes)),
        outfit=pick(options.outfits),accessory=pick(options.accessories),motion=pick(options.motion),
        shoeStyle=pick({"runner","boot","court"}),glasses=pick({false,false,true})
    }
end

function People.background(zone,slots)
    local order={}
    for i,slot in ipairs(slots) do order[i]=slot end
    table.sort(order,function(a,b) return a.id<b.id end)
    local definitions,used={},{}
    for _,slot in ipairs(order) do
        assert(not definitions[slot.id],"Duplicate campus NPC slot "..slot.id)
        local role=roles[slot.role] and slot.role or "student"
        definitions[slot.id]=generated(slot.id,role,zone.."/"..slot.id.."/"..role,used)
    end
    return definitions
end
end

-- CampusCharacter
do
-- Shared low-poly mesh recipes and articulated campus character rigs.
PolyLax = PolyLax or {}
local Character = {}
PolyLax.CampusCharacter = Character

local V=vec3
local sides={-1,1}
local neutral, eyeWhite, iris=color(255,255,255),color(248,239,223),color(44,33,30)
local bootSole=color(39,41,46)

local function dye(rgb)
    return color(rgb[1],rgb[2],rgb[3])
end

local function paintQuad(mesh,a,b,c,d,ink)
    local verts,indices=mesh.positions,mesh.indices
    local at, offset=#verts,#indices
    local normal=(b-a):cross(c-a):normalize()
    verts[at+1],verts[at+2],verts[at+3],verts[at+4]=a,b,c,d
    for k=at+1,at+4 do mesh.normals[k],mesh.colors[k]=normal,ink end
    indices[offset+1],indices[offset+2],indices[offset+3]=at+1,at+2,at+3
    indices[offset+4],indices[offset+5],indices[offset+6]=at+1,at+3,at+4
end

local function paintedModel(build)
    local mesh={positions={},normals={},indices={},colors={}}
    build(mesh)
    local uv,uvs=vec2(0,0),{}
    for i=1,#mesh.positions do uvs[i]=uv end
    local model=craft.model()
    model.positions,model.normals,model.indices=mesh.positions,mesh.normals,mesh.indices
    model.colors,model.uvs=mesh.colors,uvs
    return model
end

-- Rings give soft silhouettes and leave the face, clothing and hair in two draw calls.
local function loft(mesh, rings, sides, ink, x)
    local function point(row, i)
        local angle=math.pi*2*i/sides
        local forward=math.cos(angle)
        return V((x or 0)+row[2]*math.sin(angle),row[1]-(row[5] or 0)*(1-forward)*.5,
            (row[4] or 0)-row[3]*forward)
    end
    for i=1,#rings-1 do
        local lower,upper=rings[i],rings[i+1]
        for side=0,sides-1 do
            paintQuad(mesh,point(lower,side),point(upper,side),
                point(upper,side+1),point(lower,side+1),ink)
        end
    end
end

local function badge(mesh,x,y,z,w,h,d,ink)
    local first,last=x-w*.5,x+w*.5
    local low,high,front,back=y-h*.5,y+h*.5,z-d*.5,z+d*.5
    local a,b,c,e=V(first,low,front),V(last,low,front),V(last,high,front),V(first,high,front)
    local f,g,i,j=V(first,low,back),V(last,low,back),V(last,high,back),V(first,high,back)
    paintQuad(mesh,a,e,c,b,ink)
    paintQuad(mesh,f,g,i,j,ink)
    paintQuad(mesh,a,f,j,e,ink)
    paintQuad(mesh,b,c,i,g,ink)
    paintQuad(mesh,e,j,i,c,ink)
    paintQuad(mesh,a,b,g,f,ink)
end

local function smallOval(mesh,x,y,z,w,h,d,ink)
    loft(mesh,{{y-h*.5,.001,.001,z},{y-h*.24,w*.83,d*.82,z},
        {y,w,d,z},{y+h*.24,w*.83,d*.82,z},{y+h*.5,.001,.001,z}},8,ink,x)
end

local function faceModel(look)
    local skin,hair=dye(look.skin),dye(look.hair)
    local hairGlint=color(look.hair[1]+16,look.hair[2]+12,look.hair[3]+10)
    local lip=color(look.skin[1]*.62,look.skin[2]*.53,look.skin[3]*.55)
    local earShade=color(look.skin[1]*.88,look.skin[2]*.78,look.skin[3]*.80)
    local jaw = ({oval=1,angular=1.16,round=1.11,long=.91})[look.headShape] or 1
    return paintedModel(function(mesh)
        loft(mesh,{{-.19,.058*jaw,.07,.017},{-.16,.107*jaw,.112,.008},{-.082,.155*jaw,.135},
            {.026,.166,.151},{.097,.167,.146,.007},{.154,.140,.134,.013},
            {.181,.082,.080,.02},{.188,.002,.002,.023}},10,skin)
        for _,side in ipairs({-1,1}) do
            smallOval(mesh,side*.158,-.024,.014,.037,.090,.047,skin)
            smallOval(mesh,side*.179,-.023,-.012,.014,.048,.013,earShade)
            smallOval(mesh,side*.070,.033,-.131,.043,.032,.018,eyeWhite)
            smallOval(mesh,side*.066,.032,-.148,.016,.028,.008,iris)
            badge(mesh,side*.066-.005,.040,-.157,.006,.007,.006,neutral)
            badge(mesh,side*.072,.071,-.136,.064,.013,.018,hair)
        end
        smallOval(mesh,0,-.021,-.145,.027,.086,.031,skin)
        smallOval(mesh,0,-.079,-.134,.042,.015,.008,lip)
        local cut=look.haircut
        local drop=cut=="bob" and .231 or cut=="sweep" and .095 or cut=="neat" and .080 or .114
        local top=cut=="curls" and .238 or cut=="crop" and .207 or .225
        loft(mesh,{{.108,.170,.149,.010,drop},{.145,.171,.152,.011,drop*.39},
            {.183,.157,.133,.019},{top-.017,.092,.097,.011},{top,.001,.001,.009}},10,hair)
        if cut=="sweep" or cut=="neat" then
            smallOval(mesh,-.053,.146,-.106,.107,.114,.080,hair)
            smallOval(mesh,-.076,.192,-.081,.072,.045,.066,hairGlint)
        elseif cut=="curls" then
            for _,x in ipairs({-.093,.003,.091}) do
                smallOval(mesh,x,.204,-.048,.061,.081,.073,x==.003 and hairGlint or hair)
            end
        elseif cut=="bun" then
            smallOval(mesh,0,.120,.164,.086,.163,.086,hair)
            smallOval(mesh,-.074,.142,-.105,.077,.095,.066,hairGlint)
        elseif cut=="bob" then
            for _,side in ipairs({-1,1}) do
                smallOval(mesh,side*.138,-.025,.049,.053,.270,.113,hair)
            end
        elseif cut=="braids" then
            for _,side in ipairs(sides) do
                for i=0,3 do
                    local x,y,z=side*(.140+i*.010),.059-i*.075,.091+i*.006
                    smallOval(mesh,x,y,z,.032,.096,.040,i%2==0 and hair or hairGlint)
                end
                badge(mesh,side*.172,-.213,.111,.045,.020,.046,lip)
            end
        end
        if look.beard then
            local beard=color(101,87,78)
            loft(mesh,{{-.187,.035,.043,-.043},{-.156,.098,.114,-.018},
                {-.115,.133,.135,.002},{-.092,.102,.089,.025}},8,beard)
            badge(mesh,0,-.064,-.142,.078,.016,.015,beard)
        end
        if look.glasses then
            local frame=color(59,51,48)
            for _,side in ipairs({-1,1}) do
                badge(mesh,side*.070,.063,-.148,.096,.012,.012,frame)
                badge(mesh,side*.070,.004,-.150,.096,.010,.014,frame)
                for _,endX in ipairs({.027,.111}) do
                    badge(mesh,side*endX,.035,-.145,.010,.056,.014,frame)
                end
                badge(mesh,side*.152,.048,-.070,.015,.013,.151,frame)
            end
            badge(mesh,0,.044,-.161,.045,.011,.011,frame)
        end
        if look.earrings then
            local gold=color(239,206,135)
            smallOval(mesh,-.163,-.072,-.005,.012,.034,.012,gold)
            smallOval(mesh,.163,-.072,-.005,.012,.034,.012,gold)
        end
    end)
end

local function costumeModel(look)
    local shirt,trim=dye(look.shirt),dye(look.trim)
    return paintedModel(function(mesh)
        loft(mesh,{{-.33,.18,.093},{-.309,.194,.119},{-.13,.197,.134},
            {.064,.244,.136},{.185,.251,.119},{.229,.163,.099},
            {.244,.087,.076},{.248,.065,.061}},10,shirt)
        if look.outfit=="hoodie" then
            smallOval(mesh,0,.202,.085,.150,.194,.089,shirt)
            badge(mesh,0,-.176,-.125,.245,.089,.025,trim)
            for _,side in ipairs({-1,1}) do
                badge(mesh,side*.043,.075,-.139,.010,.106,.012,trim)
            end
        elseif look.outfit=="apron" then
            badge(mesh,0,-.117,-.125,.267,.352,.026,trim)
            badge(mesh,0,-.187,-.141,.201,.018,.021,shirt)
        elseif look.outfit=="polo" then
            for _,side in ipairs(sides) do
                badge(mesh,side*.046,.193,-.086,.078,.043,.043,trim)
            end
            badge(mesh,0,.099,-.132,.027,.116,.016,trim)
        elseif look.outfit=="cardigan" then
            badge(mesh,0,-.055,-.133,.119,.467,.025,trim)
            for y=-.21,.11,.079 do badge(mesh,-.046,y,-.153,.012,.013,.010,shirt) end
            badge(mesh,-.141,-.167,-.123,.098,.055,.026,trim)
            badge(mesh,.141,-.167,-.123,.098,.055,.026,trim)
        else
            badge(mesh,0,-.049,-.132,.014,.459,.018,trim)
            badge(mesh,0,.174,-.114,.117,.035,.027,trim)
            badge(mesh,.115,.061,-.130,.068,.041,.025,trim)
        end
        if look.accessory=="pack" then
            smallOval(mesh,0,-.04,.155,.186,.441,.090,trim)
            for _,side in ipairs(sides) do
                badge(mesh,side*.144,-.021,-.124,.037,.405,.029,trim)
            end
        elseif look.accessory=="lanyard" then
            for _,side in ipairs(sides) do
                local upperIn,upperOut=V(side*.057,.204,-.111),V(side*.071,.204,-.111)
                local lowerIn,lowerOut=V(side*.001,-.030,-.155),V(side*.012,-.030,-.155)
                if side==1 then
                    paintQuad(mesh,upperIn,upperOut,lowerOut,lowerIn,trim)
                else
                    paintQuad(mesh,upperOut,upperIn,lowerIn,lowerOut,trim)
                end
            end
            badge(mesh,0,-.077,-.158,.071,.086,.017,neutral)
            badge(mesh,0,-.073,-.169,.042,.020,.007,trim)
        end
    end)
end

local function handModel(look,side)
    local skin=dye(look.skin)
    local crease=color(look.skin[1]*.82,look.skin[2]*.74,look.skin[3]*.78)
    local trim=dye(look.trim)
    return paintedModel(function(mesh)
        loft(mesh,{{-.107,.018,.023,-.010},{-.093,.040,.038,-.008},
            {-.042,.059,.040},{.012,.050,.034},{.044,.045,.033}},8,skin)
        smallOval(mesh,-side*.046,-.028,-.026,.026,.070,.027,skin)
        for i=-1,1 do
            badge(mesh,i*.018,-.075,-.044,.003,.031,.005,crease)
        end
        if side==-1 and (look.accessory=="watch" or look.accessory=="wristband") then
            badge(mesh,0,.021,0,.103,.028,.086,trim)
            if look.accessory=="watch" then
                badge(mesh,0,.020,-.049,.047,.036,.014,bootSole)
                badge(mesh,0,.020,-.058,.014,.017,.006,neutral)
            end
        elseif side==-1 and look.accessory=="notebook" then
            badge(mesh,-.012,-.041,-.070,.138,.196,.027,trim)
            badge(mesh,-.012,-.041,-.085,.119,.176,.009,neutral)
            badge(mesh,-.063,-.041,-.097,.022,.201,.014,bootSole)
        end
    end)
end

local function shoeModel(look)
    local main,trim=dye(look.shoe),dye(look.trim)
    local style=look.shoeStyle
    local rise=style=="boot" and .136 or .092
    local sole=style=="runner" and .041 or .030
    return paintedModel(function(mesh)
        loft(mesh,{{-.096,.077,.135,-.083},{-.096+sole,.097,.161,-.070},
            {-.066+sole,.097,.161,-.070}},10,bootSole)
        loft(mesh,{{-.058,.092,.158,-.072},{.008,.088,.148,-.069},
            {.043,.070,.116,-.043},{rise,.056,.074,.005}},10,main)
        badge(mesh,0,.028,-.202,.098,.020,.024,trim)
        for i=0,2 do
            badge(mesh,0,.044+i*.009,-.137+i*.030,.080-i*.009,.009,.014,neutral)
        end
        badge(mesh,0,.004,.079,.080,.048,.019,trim)
    end)
end

local function surface(ink)
    local standard=asset and asset.builtin and asset.builtin.Materials
    local result=craft.material(standard and standard.Standard or "Materials:Standard")
    result.diffuse,result.roughness=ink,.88
    return result
end

-- Geometry keys use only the interchangeable parts that affect each mesh.
local function paletteKey(rgb)
    return table.concat(rgb,",")
end

local meshes,materials={},{}
local function cached(cache,kind,key,build,...)
    local section=cache[kind]
    if not section then section={keys={},items={}} cache[kind]=section end
    local item=section.items[key]
    if item then return item end
    item=build(...)
    if #section.keys>=24 then section.items[table.remove(section.keys,1)]=nil end
    section.keys[#section.keys+1]=key
    section.items[key]=item
    return item
end

local function dyelot(rgb)
    return cached(materials,"dye",paletteKey(rgb),function(data) return surface(dye(data)) end,rgb)
end

local limbModel,paint
local function node(scene,parent,model)
    local entity=scene:entity()
    if parent then entity.parent=parent end
    if model then entity.model=model end
    return entity
end

function Character.apply(rig,look)
    local frame=({slim=.92,athletic=1,broad=1.11})[look.frame] or 1
    local skin,hair,shirt,trim=paletteKey(look.skin),paletteKey(look.hair),
        paletteKey(look.shirt),paletteKey(look.trim)
    local faceKey=table.concat({look.headShape or "oval",skin,hair,look.haircut,
        tostring(look.beard),tostring(look.glasses),tostring(look.earrings)},"/")
    local torsoAccessory=(look.accessory=="pack" or look.accessory=="lanyard") and look.accessory or "none"
    local outfitKey=table.concat({look.outfit,shirt,trim,torsoAccessory},"/")
    local footwearKey=table.concat({look.shoeStyle or "court",paletteKey(look.shoe),trim},"/")
    local shoe=cached(meshes,"shoes",footwearKey,shoeModel,look)
    rig.root.scale=V(look.width,look.height,look.width)
    rig.face.model=cached(meshes,"heads",faceKey,faceModel,look)
    rig.face.scale=V(look.faceWidth,look.faceHeight,1)
    rig.outfit.model=cached(meshes,"outfits",outfitKey,costumeModel,look)
    rig.outfit.scale,rig.waist.scale=V(frame,1,frame),V(.385*frame,.24,.285)
    local skinMat,shirtMat,trimMat,trousers=dyelot(look.skin),dyelot(look.shirt),dyelot(look.trim),dyelot(look.pants)
    rig.neck.material,rig.waist.material=skinMat,trousers
    local shortSleeves=look.outfit=="varsity" or look.outfit=="apron" or look.outfit=="polo"
    for i,side in ipairs(sides) do
        rig.arms[i].position=V(side*.235*frame,.158,0)
        rig.legs[i].position=V(side*.100*frame,.942,0)
        rig.sleeves[i].material=shortSleeves and trimMat or shirtMat
        rig.forearms[i].material=shortSleeves and skinMat or shirtMat
        rig.thighs[i].material,rig.shins[i].material=trousers,trousers
        local accessory=i==1 and look.accessory
        local handAccessory=(accessory=="watch" or accessory=="wristband" or accessory=="notebook") and accessory or "none"
        local handKey=table.concat({skin,side,handAccessory,handAccessory~="none" and trim or ""},"/")
        rig.hands[i].model=cached(meshes,"hands",handKey,handModel,look,side)
        rig.feet[i].model=shoe
    end
    rig.definition=look
end

function Character.new(scene,look)
    limbModel=limbModel or paintedModel(function(mesh)
        loft(mesh,{{-.5,.29,.31},{-.416,.459,.461},{-.303,.49,.49},
            {.313,.5,.5},{.436,.454,.457},{.5,.29,.31}},8,neutral)
    end)
    paint=paint or surface(neutral)
    local root=node(scene)
    local rig={root=root,arms={},elbows={},wrists={},legs={},knees={},ankles={},
        sleeves={},forearms={},thighs={},shins={},hands={},feet={}}
    local function part(parent,x,y,z,w,h,d,model)
        local e=node(scene,parent,model)
        e.position=V(x,y,z)
        if w then e.scale=V(w,h,d) end
        return e
    end
    rig.torso=part(root,0,1.34,0)
    rig.outfit=part(rig.torso,0,0,0)
    rig.outfit.material=paint
    rig.waist=part(root,0,1.001,0,.385,.24,.285,limbModel)
    rig.neck=part(rig.torso,0,.266,0,.147,.187,.159,limbModel)
    rig.head=part(rig.torso,0,.439,-.007)
    rig.face=part(rig.head,0,.071,0)
    rig.face.material=paint
    for i,side in ipairs(sides) do
        local arm=part(rig.torso,side*.235,.158,0)
        local elbow=part(arm,side*.030,-.252,-.004)
        local wrist=part(elbow,0,-.239,-.006)
        local leg=part(root,side*.100,.942,0)
        local knee=part(leg,0,-.410,.008)
        local ankle=part(knee,0,-.439,-.006)
        rig.sleeves[i]=part(arm,side*.012,-.117,0,.159,.298,.178,limbModel)
        rig.forearms[i]=part(elbow,0,-.109,0,.130,.247,.138,limbModel)
        rig.thighs[i]=part(leg,0,-.166,0,.202,.416,.224,limbModel)
        rig.shins[i]=part(knee,0,-.187,0,.164,.417,.179,limbModel)
        rig.hands[i],rig.feet[i]=wrist,ankle
        rig.hands[i].material,rig.feet[i].material=paint,paint
        rig.arms[i],rig.elbows[i],rig.wrists[i]=arm,elbow,wrist
        rig.legs[i],rig.knees[i],rig.ankles[i]=leg,knee,ankle
    end
    Character.apply(rig,look)
    return rig
end
end

-- CampusMotion
do
-- Small procedural articulation profiles for campus rigs. World owns root travel and facing.
PolyLax = PolyLax or {}
local Motion = {}
PolyLax.CampusMotion = Motion

local V=vec3
local tau=math.pi*2
local sides={-1,1}
local presets={
    easy={stride=21,step=1.50,arms=15,sway=2,nod=5,tempo=1.7,
        breath=1.65,glance=4.5,restRoll=1.25,gesture="greet",hand=2},
    athletic={stride=24,step=1.67,arms=18,sway=1.4,nod=3,tempo=2.0,
        breath=2.05,glance=2.8,restRoll=.65,gesture="point",hand=2},
    measured={stride=17,step=1.26,arms=11,sway=1,nod=3.5,tempo=1.28,
        breath=1.31,glance=2.4,restRoll=.34,gesture="explain",hand=1},
    animated={stride=20,step=1.57,arms=16,sway=2.8,nod=6,tempo=2.25,
        breath=1.9,glance=5.4,restRoll=1.5,gesture="explain",hand=2}
}
local gestures={
    greet={time=.82,arm=48,elbow=32,roll=24,wrist=18,head=5},
    point={time=.67,arm=40,elbow=19,roll=9,wrist=3,head=2},
    explain={time=.94,arm=24,elbow=36,roll=18,wrist=12,head=6},
    nod={time=.58,arm=0,elbow=0,roll=0,wrist=0,head=11}
}

function Motion.new(rig,profile,seed)
    local offset=(seed or 0)%619/619
    return {
        rig=rig,profile=presets[profile] or presets.easy,mode="idle",
        time=offset*5,phase=offset*tau,bob=0,walking=0,talking=0,
        headX=0,headY=0,headZ=0,bodyX=0,bodyY=0,bodyZ=0,
        arms={0,0},elbows={9,9},roll={-6,6},wrists={0,0},legs={0,0},knees={0,0},ankles={0,0}
    }
end

function Motion.gesture(state,id)
    local beat=gestures[id]
    if not beat then return false end
    state.beat,state.beatTime=beat,0
    return true
end

local function toward(current,target,factor)
    return current+(target-current)*factor
end

function Motion.update(state,dt,mode,speed)
    if dt<=0 then return end
    local profile,rig=state.profile,state.rig
    if mode~=state.mode then
        if mode=="talk" then Motion.gesture(state,profile.gesture) end
        if mode=="walk" then state.beat=nil end
        state.mode=mode
    end
    local blend=1-math.exp(-dt*10)
    state.time=state.time+dt
    state.walking=toward(state.walking,mode=="walk" and math.min(1,(speed or 0)/.75) or 0,blend)
    state.talking=toward(state.talking,mode=="talk" and 1 or 0,blend)
    if mode=="walk" then
        state.phase=(state.phase+tau*profile.step*math.min(1.25,(speed or 0)/.75)*dt)%tau
    end
    local beat=state.beat
    local amount=0
    if beat then
        state.beatTime=state.beatTime+dt
        if state.beatTime<beat.time then amount=math.sin(math.pi*state.beatTime/beat.time)^2
        else state.beat=nil end
    end
    local wave=math.sin(state.phase)
    local gait=state.walking
    local speech=math.sin(state.time*profile.tempo*4)
    local breath=math.sin(state.time*profile.breath)
    local idle=1-gait
    local listening=mode=="listen"
    state.bob=.032*gait*math.abs(wave)+.006*idle*(1+breath)
    state.bodyX=toward(state.bodyX,-6*gait+(listening and -2.5 or 0),blend)
    state.bodyY=toward(state.bodyY,profile.sway*wave*gait,blend)
    state.bodyZ=toward(state.bodyZ,-profile.sway*wave*gait+profile.restRoll*idle*breath,blend)
    state.headX=toward(state.headX,1.5+speech*profile.nod*state.talking
        +(beat and beat.head*amount or 0)+(listening and 1.4*breath or 0),blend)
    state.headY=toward(state.headY,math.sin(state.time*.76)*profile.glance*idle*(1-state.talking),blend)
    state.headZ=toward(state.headZ,.8*breath*idle-profile.sway*wave*gait*.35,blend)
    rig.torso.eulerAngles=V(state.bodyX,state.bodyY,state.bodyZ)
    rig.head.eulerAngles=V(state.headX,state.headY,state.headZ)
    for i,side in ipairs(sides) do
        local step=-side*wave*gait
        local gesture=beat and i==profile.hand and amount or 0
        local speechHand=i==profile.hand and state.talking*(2+speech*2.5) or 0
        state.legs[i]=toward(state.legs[i],step*profile.stride,blend)
        state.knees[i]=toward(state.knees[i],-math.max(0,-step)*31,blend)
        state.ankles[i]=toward(state.ankles[i],-step*8+math.max(0,-step)*8,blend)
        state.arms[i]=toward(state.arms[i],-step*profile.arms-1.4*breath*idle
            +(beat and beat.arm*gesture or 0)+speechHand,blend)
        state.elbows[i]=toward(state.elbows[i],9+math.max(0,-step)*12+speechHand
            +(beat and beat.elbow*gesture or 0),blend)
        state.roll[i]=toward(state.roll[i],side*(6+(beat and beat.roll*gesture or 0)),blend)
        state.wrists[i]=toward(state.wrists[i],(beat and beat.wrist*gesture or 0),blend)
        rig.arms[i].eulerAngles=V(state.arms[i],0,state.roll[i])
        rig.elbows[i].eulerAngles=V(state.elbows[i],0,0)
        rig.wrists[i].eulerAngles=V(0,0,state.wrists[i]*side)
        rig.legs[i].eulerAngles=V(state.legs[i],0,0)
        rig.knees[i].eulerAngles=V(state.knees[i],0,0)
        rig.ankles[i].eulerAngles=V(state.ankles[i],0,0)
    end
end
end

-- FreeRoamWorld
do
-- Road to Glory campus geometry, authored locations, and lightweight collision.
PolyLax = PolyLax or {}
local P = PolyLax
local World = {}
P.FreeRoamWorld = World

local zones = {
    campus={label="Briarbank High",x=0,z=9,yaw=0,minX=-23,maxX=23,minZ=-28,maxZ=19,
        blocks={{-5.75,5.75,-15.75,-10.25,5.7},{-13.2,-6.8,-8.4,-4.2,4.2},
            {6.8,13.2,-8.4,-4.2,4.2},{-14.4,-7.6,5.25,9.85,4.5},
            {7.6,14.4,5.25,9.85,4.5},{-1.10,1.10,-25.8,-24.55,1.9},
            {-1.28,1.28,-.7,1.02,.54},
            {-17.5,-16.5,-4.5,-3.5,3},{16.5,17.5,-4.5,-3.5,3}}},
    school={label="School Hall",x=0,z=3.2,yaw=0,
        blocks={{4.65,6.62,-.6,.6,4},{-5.15,-2.45,1.34,1.87,.96}}},
    lockers={label="Varsity and JV Locker Rooms",x=0,z=3.2,yaw=0,
        blocks={{-6.85,-5.75,-4.6,1.25,3},{5.75,6.85,-4.6,1.25,3},
            {-2.25,-.9,-1.35,-.6,.9},{.9,2.25,-1.35,-.6,.9}}},
    training={label="Weight Room",x=0,z=3.2,yaw=0,
        blocks={{-5,-2.35,-3.9,-2.5,2.5},{2.35,5,-3.9,-2.5,2.5}}},
    coach={label="Coach's Office",x=0,z=3.2,yaw=0,
        blocks={{-2,2,-3.95,-2.65,1.2},{-6.75,-5.85,-4.2,-1.15,2.6}}},
    drip={label="Drip Lab",x=0,z=3.2,yaw=0,
        blocks={{-6.75,-5.25,-4.35,1.7,2.35},{5.25,6.75,-4.35,1.7,2.35}}},
    clubhouse={label="Pro Clubs Clubhouse",x=0,z=3.2,yaw=0,
        blocks={{-5.8,-3.1,-2.4,-.1,1.5},{3.1,5.8,-2.4,-.1,1.5},{-.91,.91,-4.68,-3.93,1.68}}}
}
local campusObstacles = zones.campus.blocks
for _,side in ipairs({-1,1}) do
    local function obstacle(x,z,width,depth,height)
        campusObstacles[#campusObstacles+1] = {side*x-width*.5,side*x+width*.5,
            z-depth*.5,z+depth*.5,height}
    end
    obstacle(4.53,2.94,1.90,.55,.96)
    obstacle(4.05,8.05,.29,.29,2.75)
    obstacle(5.92,-3.6,.29,.29,2.75)
    obstacle(19.4,5.4,1.32,16,.70)
    for _,z in ipairs({-17.5,1.1,11.9,15.2}) do obstacle(17,z,.32,.32,2.9) end
    for _,z in ipairs({-22.7,-17.6,-12.4}) do obstacle(20.6,z,.32,.32,3.6) end
end
local roomWalls = {{-7.4,-6.8,-6.5,5.55,4.9},{6.8,7.4,-6.5,5.55,4.9},
    {-7.4,7.4,-6.5,-5.95,4.9},{-7.4,7.4,5.28,5.65,4.9}}
for _,zone in pairs(zones) do
    if not zone.minX then
        zone.minX,zone.maxX,zone.minZ,zone.maxZ = -6.8,6.8,-5.95,5.28
        for _,wall in ipairs(roomWalls) do zone.blocks[#zone.blocks+1] = wall end
    end
end

local contacts = {
    campus={
        {"ethan","Ethan Cole",-2.8,4.2,2.1}, {"jace","Jace Holloway",6.72,-17.18,2},
        {"maya","Maya Brooks",2.9,-1.95,1.85},
        {"door:school","Main School Building",0,-9.75,1.8,"school"},
        {"door:lockers","Varsity and JV Locker Rooms",-10,-3.72,1.8,"lockers"},
        {"door:training","Weight Room",10,-3.72,1.8,"training"},
        {"door:drip","Enter Drip Lab",-11,10.35,1.8,"drip"},
        {"door:clubhouse","Pro Clubs Clubhouse",11,10.35,1.8,"clubhouse"},
        {"practice","Lacrosse Practice Field",0,-17.25,2.3}
    },
    school={
        {"door:coach","Coach Mercer's Office",4.95,-1.15,1.8,"coach"},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",0,-8.4,180}
    },
    lockers={
        {"tryout","Lacrosse Tryouts",0,-3.35,2.25},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",-10,-2.35,180}
    },
    training={
        {"training","Trainer Avery",0,-2.45,2.1},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",10,-2.35,180}
    },
    coach={
        {"coach","Coach Daniel Mercer",0,-1.48,2.05},
        {"door:school","Return to School Hall",0,4.75,1.75,"school",4.32,-2.05,90}
    },
    drip={
        {"drip","Shop and Customize",0,-2.05,2.3},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",-11,11.82,180}
    },
    clubhouse={
        {"clubs","Enter Pro Clubs",0,-2.7,2.35},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",11,11.82,180}
    }
}

local palette = {
    turf={73,112,74}, turfLight={71,134,89}, turfDark={59,113,76}, hedge={43,86,62},
    pine={43,100,72}, pineLight={66,127,82}, bark={111,78,62},
    brick={150,95,87}, redBrick={119,67,66}, stucco={196,190,171}, white={234,234,219},
    concrete={149,157,153}, road={77,84,83}, pavement={119,130,127}, glass={61,108,128,.22},
    navy={31,53,68}, dark={28,44,50}, metal={99,123,128,.48}, gold={221,162,78,.58},
    wood={158,110,72}, orange={217,99,64}, teal={60,144,132}, violet={114,97,146},
    light={242,217,155,.25}, rubber={54,61,61}
}
local swatches = {}
local V = vec3

local function material(key)
    local value = swatches[key]
    if not value then
        local spec = palette[key]
        local standard = asset and asset.builtin and asset.builtin.Materials
        value = craft.material(standard and standard.Standard or "Materials:Standard")
        value.diffuse = color(spec[1],spec[2],spec[3])
        value.roughness = spec[4] or .89
        swatches[key] = value
    end
    return value
end

local function quad(world,key,a,b,c,d)
    local mesh = world.meshes[key]
    if not mesh then
        mesh = {positions={},normals={},indices={}}
        world.meshes[key] = mesh
    end
    local vertices,normals,indices = mesh.positions,mesh.normals,mesh.indices
    local i,j = #vertices,#indices
    local n = (b-a):cross(c-a):normalize()
    vertices[i+1],vertices[i+2],vertices[i+3],vertices[i+4] = a,b,c,d
    normals[i+1],normals[i+2],normals[i+3],normals[i+4] = n,n,n,n
    indices[j+1],indices[j+2],indices[j+3],indices[j+4],indices[j+5],indices[j+6] = i+1,i+2,i+3,i+1,i+3,i+4
    indices[j+7],indices[j+8],indices[j+9],indices[j+10],indices[j+11],indices[j+12] = i+3,i+2,i+1,i+4,i+3,i+1
end

local function plane(world,key,x,z,w,d,y)
    local l,r,b,f = x-w*.5,x+w*.5,z-d*.5,z+d*.5
    quad(world,key,V(l,y,b),V(l,y,f),V(r,y,f),V(r,y,b))
end

local function box(world,key,x,y,z,w,h,d)
    local l,r,b,t,a,f = x-w*.5,x+w*.5,y-h*.5,y+h*.5,z-d*.5,z+d*.5
    local p,q,s,u = V(l,b,a),V(l,b,f),V(r,b,a),V(r,b,f)
    local w0,w1,w2,w3 = V(l,t,a),V(l,t,f),V(r,t,a),V(r,t,f)
    quad(world,key,w0,w1,w3,w2)
    quad(world,key,p,s,u,q)
    quad(world,key,p,q,w1,w0)
    quad(world,key,s,w2,w3,u)
    quad(world,key,q,u,w3,w1)
    quad(world,key,p,w0,w2,s)
end

local glyphs = {
    A={2,5,7,5,5}, B={6,5,6,5,6}, C={3,4,4,4,3}, D={6,5,5,5,6},
    E={7,4,6,4,7}, F={7,4,6,4,4}, G={3,4,5,5,3}, H={5,5,7,5,5},
    I={7,2,2,2,7}, J={1,1,1,5,2}, K={5,5,6,5,5}, L={4,4,4,4,7},
    M={5,7,7,5,5}, N={5,7,7,7,5}, O={2,5,5,5,2}, P={6,5,6,4,4},
    Q={2,5,5,7,3}, R={6,5,6,5,5}, S={3,4,2,1,6}, T={7,2,2,2,2},
    U={5,5,5,5,7}, V={5,5,5,5,2}, W={5,5,7,7,5}, X={5,5,2,5,5},
    Y={5,5,2,2,2}, Z={7,1,2,4,7}
}

local function sign(world,text,x,y,z,cell,ink)
    -- Signs are read from the +Z side of each facade.
    local start=x-(#text*4-1)*cell*.5
    for index=1,#text do
        local glyph=glyphs[text:sub(index,index)]
        if glyph then
            for row,mask in ipairs(glyph) do
                for col=0,2 do
                    if math.floor(mask/2^(2-col))%2==1 then
                        local left = start+((index-1)*4+col)*cell
                        local right = left+cell*.9
                        local top = y+(3-row)*cell
                        quad(world,ink,V(left,top,z),V(left,top-cell*.9,z),
                            V(right,top-cell*.9,z),V(right,top,z))
                    end
                end
            end
        end
    end
end

local function shopfront(world,x,z,w,d,h,title,facade,accent)
    local front=z+d*.5
    box(world,facade,x,h*.5,z,w,h,d)
    box(world,"navy",x,h+.035,z,w+.43,.29,d+.42)
    box(world,accent,x,h-.3,front+.045,w,.13,.1)
    box(world,"navy",x,1.07,front+.04,1.47,2.2,.1)
    box(world,"glass",x,1.26,front+.11,1.15,1.50,.10)
    box(world,"gold",x-.46,1.03,front+.18,.08,.14,.045)
    for _,side in ipairs({-1,1}) do
        local ix=x+side*w*.31
        box(world,"stucco",ix,1.66,front+.075,w*.29,1.34,.11)
        box(world,"glass",ix,1.66,front+.145,w*.252,1.08,.08)
        box(world,"metal",ix,1.66,front+.195,.06,1.09,.035)
    end
    box(world,"navy",x,h-.84,front+.12,w-.58,.7,.16)
    sign(world,title,x,h-.83,front+.207,math.min(.104,(w-.8)/(#title*4)),"white")
    box(world,accent,x,2.39,front+.28,2,.14,.62)
end

local function tree(world,x,z,h)
    box(world,"bark",x,h*.29,z,.32,h*.58,.32)
    for level=1,2 do
        local y=h*(level==1 and .28 or .51)
        local w=h*(level==1 and .34 or .26)
        local tip=V(x,y+h*.51,z)
        local near,far,left,right=V(x,y,z+w),V(x,y,z-w),V(x-w,y,z),V(x+w,y,z)
        local greens=level==1 and "pine" or "pineLight"
        -- A narrowed tip is closed with the same material as the bark-free crown.
        local cap=tip+V(.006,0,0)
        quad(world,greens,left,near,tip,cap)
        quad(world,greens,near,right,tip,cap)
        quad(world,greens,right,far,tip,cap)
        quad(world,greens,far,left,tip,cap)
    end
end

local function bench(world,x,z,w)
    box(world,"wood",x,.47,z,w,.15,.50)
    box(world,"wood",x,.81,z-.25,w,.28,.09)
    for _,side in ipairs({-1,1}) do
        box(world,"metal",x+side*w*.32,.24,z,.10,.48,.34)
    end
end

local function bollard(world,x,z)
    box(world,"metal",x,1.25,z,.10,2.50,.10)
    box(world,"navy",x,.13,z,.26,.26,.26)
    box(world,"light",x,2.53,z,.26,.26,.24)
    box(world,"navy",x,2.69,z,.31,.08,.30)
end

local function campus(world)
    plane(world,"turf",0,-4.5,66,65,-.045)
    plane(world,"road",0,17.5,47,5.6,-.012)
    for index=-7,7 do plane(world,"white",index*2.9,17.4,1.48,.06,.003) end
    plane(world,"concrete",0,12.6,32,2.5,-.005)
    plane(world,"pavement",0,3.1,10.7,11.6,-.003)
    plane(world,"concrete",0,-3.8,17.6,2.15,-.004)
    plane(world,"concrete",0,-6.5,3.18,9.3,-.006)
    for _,side in ipairs({-1,1}) do
        plane(world,"concrete",side*7.02,-14.05,2.32,18.4,-.008)
        plane(world,"stucco",side*11,11.3,3.18,3,-.001)
        plane(world,"pavement",side*10,-4.01,3.25,1.6,-.002)
        bench(world,side*4.53,2.95,1.90)
        bollard(world,side*4.05,8.05)
        bollard(world,side*5.92,-3.6)
        for _,z in ipairs({-17.5,-4,1.1,11.9,15.2}) do tree(world,side*17,z,2.8) end
        for _,z in ipairs({-22.7,-17.6,-12.4}) do tree(world,side*20.6,z,3.55) end
        box(world,"hedge",side*19.4,.33,5.4,1.32,.68,16)
    end
    box(world,"stucco",0,.24,.16,2.56,.48,1.70)
    box(world,"pine",0,.48,.16,2.32,.12,1.48)
    for _,side in ipairs({-1,1}) do tree(world,side*.67,.20,1.45) end
    shopfront(world,0,-13,11.5,5.5,5.32,"BRIARBANK HIGH","brick","gold")
    for _,side in ipairs({-1,1}) do
        box(world,"stucco",side*4.67,2.10,-10.07,.45,4.2,.42)
        for column=1,3 do
            box(world,"glass",side*(2.45+column*.84),3.18,-10.197,.67,.67,.11)
        end
    end
    shopfront(world,-10,-6.3,6.4,4.2,3.9,"LOCKER ROOMS","redBrick","teal")
    shopfront(world,10,-6.3,6.4,4.2,3.9,"TRAINING","stucco","orange")
    shopfront(world,-11,7.55,6.8,4.6,4.15,"DRIP LAB","dark","teal")
    shopfront(world,11,7.55,6.8,4.6,4.15,"PRO CLUBS","navy","gold")
    plane(world,"road",0,-21.5,14.1,11.2,-.025)
    for i=0,5 do
        plane(world,i%2==0 and "turfLight" or "turfDark",0,-25.7+i*1.70,11,1.7,-.014)
    end
    for _,side in ipairs({-1,1}) do
        plane(world,"white",side*5.15,-21.45,.09,9.9,.002)
        plane(world,"white",0,-21.45+side*4.95,10.32,.09,.002)
    end
    plane(world,"white",0,-19.5,10.32,.08,.002)
    box(world,"navy",0,1.83,-26.85,5.4,.82,.25)
    sign(world,"LACROSSE",0,1.85,-26.715,.114,"white")
    P.GoalPhysics.new(world.scene,{x=0,z=-24.55,attackSign=-1})
end

local function room(world,title,accent)
    plane(world,"concrete",0,-.22,14.5,12.65,-.035)
    plane(world,"pavement",0,-.16,7.8,10.55,-.027)
    box(world,"stucco",0,1.7,-6.19,14.15,3.4,.32)
    for _,side in ipairs({-1,1}) do
        box(world,"stucco",side*7,1.70,-.15,.30,3.40,11.85)
        box(world,accent,side*6.823,.63,-.15,.05,.78,11.85)
        for _,z in ipairs({-3.9,-.15,3.58}) do
            box(world,"glass",side*6.818,2.36,z,.045,.61,1.32)
        end
        box(world,"stucco",side*4.2,1.35,5.44,5.7,2.7,.26)
    end
    box(world,accent,0,.65,-6.015,13.8,.82,.05)
    box(world,"navy",0,2.81,-5.997,8.45,.84,.08)
    sign(world,title,0,2.85,-5.943,.11,"white")
    box(world,"navy",0,2.83,5.4,2.66,.36,.25)
    plane(world,accent,0,4.88,2.24,.16,-.014)
end

local function school(world)
    room(world,"SCHOOL HALL","gold")
    for _,side in ipairs({-1,1}) do
        for i=1,5 do
            local z=-4.85+(i-1)*.69
            box(world,"navy",side*6.64,1.02,z,.30,2.04,.66)
            box(world,"metal",side*6.472,1.18,z+.18,.06,.21,.06)
        end
    end
    box(world,"navy",5.28,1.10,0,1.36,2.20,.28)
    sign(world,"COACH",5.28,2.46,.155,.057,"navy")
    bench(world,-3.8,1.6,2.7)
end

local function lockers(world)
    room(world,"LOCKER ROOMS","teal")
    sign(world,"JV",-3.75,1.78,-5.938,.13,"navy")
    sign(world,"VARSITY",3.75,1.78,-5.938,.13,"navy")
    for _,side in ipairs({-1,1}) do
        for i=0,5 do
            local z=-4.2+i*.97
            box(world,side<0 and "navy" or "dark",side*6.33,1.27,z,.95,2.54,.88)
            box(world,"metal",side*5.831,1.39,z+.22,.046,.20,.09)
        end
        bench(world,side*1.56,-.98,1.34)
    end
    plane(world,"teal",0,-3.35,1.2,1.2,-.020)
end

local function training(world)
    room(world,"WEIGHT ROOM","orange")
    for _,side in ipairs({-1,1}) do
        local x=side*3.65
        plane(world,"rubber",x,-3.25,3.1,2,-.011)
        box(world,"rubber",x,.50,-3.25,1.75,.22,.58)
        box(world,"metal",x,.25,-3.25,.18,.50,.39)
        for _,post in ipairs({-1,1}) do
            box(world,"metal",x+post*1.1,.93,-3.52,.10,1.86,.12)
            box(world,"orange",x+post*.79,1.36,-3.52,.14,.38,.38)
        end
        box(world,"metal",x,1.36,-3.52,2.17,.06,.06)
    end
end

local function coach(world)
    room(world,"COACH MERCER","gold")
    box(world,"wood",0,.85,-3.29,3.95,.17,1.24)
    for _,side in ipairs({-1,1}) do box(world,"navy",side*1.65,.39,-3.29,.55,.78,1.08) end
    box(world,"navy",.78,.99,-3.31,.65,.16,.42)
    box(world,"white",-.71,.96,-3.22,.75,.02,.46)
    for _,level in ipairs({.35,1.15,1.94}) do
        box(world,"wood",-6.33,level,-2.68,.82,.11,3.16)
    end
    for _,z in ipairs({-3.75,-3.14,-2.15}) do
        box(world,"gold",-6.33,2.15,z,.34,.31,.28)
        box(world,"metal",-6.33,2.03,z,.40,.08,.38)
    end
end

local function drip(world)
    room(world,"DRIP LAB","teal")
    sign(world,"STICKS",-3.64,2.05,-5.944,.10,"navy")
    sign(world,"GLOVES",3.64,2.05,-5.944,.10,"navy")
    local options={"orange","teal","violet","gold","white"}
    for _,side in ipairs({-1,1}) do
        local x=side*5.94
        box(world,"navy",x,.75,-1.3,1.53,1.50,6.04)
        box(world,"glass",x,1.53,-1.3,1.55,.12,6.05)
        for i,ink in ipairs(options) do
            local z=-3.9+(i-1)*1.28
            if side<0 then
                box(world,ink,x,1.93,z,.08,.84,.08)
                box(world,ink,x,2.39,z,.10,.21,.22)
                box(world,"white",x,2.43,z+.06,.13,.04,.07)
            else
                box(world,ink,x-.22,1.69,z,.32,.23,.34)
                box(world,ink,x+.22,1.69,z,.32,.23,.34)
            end
        end
    end
    plane(world,"teal",0,-2.05,2.8,2.38,-.019)
end

local function clubhouse(world)
    room(world,"PRO CLUBS","gold")
    for _,side in ipairs({-1,1}) do
        box(world,"navy",side*4.47,.45,-1.25,2.61,.90,2.10)
        box(world,"teal",side*4.47,.92,-1.95,2.61,.55,.48)
        box(world,"gold",side*4.20,1.85,-5.893,1.18,1.26,.18)
        box(world,"navy",side*4.20,1.87,-5.778,.88,.90,.07)
    end
    box(world,"metal",0,.53,-4.3,1.34,1.06,.76)
    box(world,"navy",0,1.33,-4.23,1.81,.69,.20)
    box(world,"teal",0,1.32,-4.101,1.60,.49,.07)
    plane(world,"gold",0,-2.70,2.17,1.45,-.020)
end

local builders={campus=campus,school=school,lockers=lockers,training=training,
    coach=coach,drip=drip,clubhouse=clubhouse}

local function compile(world)
    local uv,white = vec2(0,0),color(255,255,255)
    for key,mesh in pairs(world.meshes) do
        local colors,uvs={},{}
        for i=1,#mesh.positions do colors[i],uvs[i]=white,uv end
        local model=craft.model()
        model.positions,model.normals,model.indices=mesh.positions,mesh.normals,mesh.indices
        model.colors,model.uvs=colors,uvs
        local entity=world.scene:entity()
        entity.model,entity.material=model,material(key)
    end
    world.meshes=nil
end

-- Named actors keep their story IDs. Background slots pair stable IDs with a route.
local storyRoutes={
    ethan={{-2.8,4.2},{-3.25,3.70},{-2.9,2.55},{-2.55,3.4}},
    jace={{6.72,-17.18},{7.52,-17.30},{7.06,-18.18},{6.45,-17.79}},
    maya={{2.9,-1.95},{3.64,-2.22},{3.36,-3.34},{2.68,-2.80}},
    coach={{0,-1.48},{.78,-1.55},{.70,-.85},{.10,-.96}},
    drip={{0,-2.05},{.68,-2.60},{.86,-1.8},{.21,-1.38}},
    training={{0,-2.45},{.78,-2.42},{.8,-1.6},{.06,-1.65}}
}
local backgroundSlots={
    campus={
        {id="studentA",role="student",route={{-5.05,6.2},{-4.65,3.8},{-4.75,-.7},{-5.25,2.65}}},
        {id="studentB",role="student",route={{5.35,7.2},{3.8,6.6},{3.85,4.65},{5.8,5.6}}},
        {id="fieldAssistant",role="coach",route={{-7.4,-17.8},{-8.1,-21.3},{-10.4,-21.0},{-10.5,-17.9}}}
    },
    school={{id="hallStaff",role="staff",route={{-2.0,1.5},{-1.6,-.7},{-3.9,-.7},{-4.25,.75}}}}
}

local function spawnActor(world,definition,route,point)
    local rig=P.CampusCharacter.new(world.scene,definition)
    local actor={id=definition.id,definition=definition,rig=rig,root=rig.root,head=rig.head,
        arms=rig.arms,elbows=rig.elbows,legs=rig.legs,knees=rig.knees,
        route=route,point=point,index=2,rest=2,x=route[1][1],z=route[1][2],yaw=180}
    actor.motion=P.CampusMotion.new(rig,definition.motion,P.CampusPeople.seed(world.zone.."/"..actor.id))
    actor.root.position,actor.root.eulerAngles=V(actor.x,0,actor.z),V(0,actor.yaw,0)
    world.actors[#world.actors+1]=actor
end

local function clear(zone,x,z,radius)
    if x<zone.minX+radius or x>zone.maxX-radius or z<zone.minZ+radius
        or z>zone.maxZ-radius then return false end
    for _,block in ipairs(zone.blocks) do
        if x>block[1]-radius and x<block[2]+radius and z>block[3]-radius
            and z<block[4]+radius then return false end
    end
    return true
end

local function finite(value)
    return type(value)=="number" and math.abs(value)<math.huge
end

function World.sanitize(zone,x,z)
    zone=zones[zone] and zone or "campus"
    local map=zones[zone]
    if not (finite(x) and finite(z) and clear(map,x,z,.34)) then x,z=map.x,map.z end
    return zone,x,z
end

function World.new(scene,zone)
    zone=zones[zone] and zone or "campus"
    local map=zones[zone]
    local world={scene=scene,zone=zone,name=map.label,spawn={x=map.x,z=map.z,yaw=map.yaw},
        map=map,hotspots={},actors={},elapsed=0,meshes={}}
    builders[zone](world)
    compile(world)
    for _,spec in ipairs(contacts[zone]) do
        local id,into=spec[1],spec[6]
        local point={id=id,label=spec[2],x=spec[3],z=spec[4],radius=spec[5],zone=into}
        if into then
            local destination=zones[into]
            point.spawnX,point.spawnZ,point.spawnYaw=spec[7] or destination.x,
                spec[8] or destination.z,spec[9] or destination.yaw
        end
        world.hotspots[#world.hotspots+1]=point
        if storyRoutes[id] then
            spawnActor(world,assert(P.CampusPeople.named(id)),storyRoutes[id],point)
        end
    end
    local slots=backgroundSlots[zone]
    if slots then
        local definitions=P.CampusPeople.background(zone,slots)
        for _,slot in ipairs(slots) do spawnActor(world,definitions[slot.id],slot.route) end
    end
    return world
end

function World.anchors(world)
    return world.hotspots
end

function World.interaction(world,x,z)
    local nearest, distance
    for _,point in ipairs(world.hotspots) do
        local dx,dz=point.x-x,point.z-z
        local d=dx*dx+dz*dz
        if d<=point.radius*point.radius and (not distance or d<distance) then
            nearest,distance=point,d
        end
    end
    return nearest
end

function World.move(world,x,z,dx,dz,radius)
    radius=radius or .34
    local steps=math.max(1,math.ceil(math.max(math.abs(dx),math.abs(dz))/.24))
    local stepX,stepZ=dx/steps,dz/steps
    for _=1,steps do
        if clear(world.map,x+stepX,z,radius) then x=x+stepX end
        if clear(world.map,x,z+stepZ,radius) then z=z+stepZ end
    end
    return x,z
end

local function slab(start,delta,lo,hi,first,last)
    if math.abs(delta)<.00001 then
        if start>=lo and start<=hi then return first,last end
        return
    end
    local a,b=(lo-start)/delta,(hi-start)/delta
    if b<a then a,b=b,a end
    first,last=math.max(a,first),math.min(b,last)
    if first<=last then return first,last end
end

function World.camera(world,target,desired)
    local delta=desired-target
    local finish=1
    local r=.13
    for _,block in ipairs(world.map.blocks) do
        local first,last=slab(target.x,delta.x,block[1]-r,block[2]+r,0,finish)
        if first then first,last=slab(target.z,delta.z,block[3]-r,block[4]+r,first,last) end
        if first then first=slab(target.y,delta.y,-.2,block[5]+r,first,last) end
        if first then finish=math.min(finish,math.max(.07,first-.033)) end
    end
    return target+delta*finish
end

local function advanceActor(actor,dt,schedule,playerX,playerZ,talkingTo)
    local dx,dz=actor.x-playerX,actor.z-playerZ
    local distanceSq=dx*dx+dz*dz
    local nearby=distanceSq < 22*22
    actor.root.active=nearby
    if not nearby then return end
    local speed=0
    local talk=actor.id==talkingTo
    local nearPoint=actor.point and distanceSq<=actor.point.radius^2
    local point=actor.route[actor.index]
    -- Hold still briefly for dialogue, then return to the schedule route.
    if not talk and not nearPoint then
        actor.rest=actor.rest-dt
        if actor.rest<=0 then
            dx,dz=point[1]-actor.x,point[2]-actor.z
            local range=math.sqrt(dx*dx+dz*dz)
            if range<=.08 then
                if schedule=="EVENING" or schedule=="Evening" or schedule=="evening" then
                    actor.index=(actor.index+#actor.route-2)%#actor.route+1
                else
                    actor.index=actor.index%#actor.route+1
                end
                actor.rest=actor.point and 2.4 or .48
            else
                local scale=math.min(1,dt*(actor.point and .48 or .80)/range)
                actor.x,actor.z=actor.x+dx*scale,actor.z+dz*scale
                local facing=math.deg((math.atan2 or math.atan)(-dx,-dz))
                actor.yaw=actor.yaw+((facing-actor.yaw+180)%360-180)*math.min(1,dt*5)
                speed=range*scale/dt
            end
        end
    elseif distanceSq>.001 then
        local facing=math.deg((math.atan2 or math.atan)(dx,dz))
        actor.yaw=actor.yaw+((facing-actor.yaw+180)%360-180)*math.min(1,dt*5)
    end
    local mode=talk and "talk" or nearPoint and "listen" or speed>0 and "walk" or "idle"
    P.CampusMotion.update(actor.motion,dt,mode,speed)
    actor.root.position=V(actor.x,actor.motion.bob,actor.z)
    actor.root.eulerAngles=V(0,actor.yaw,0)
    if actor.point then actor.point.x,actor.point.z=actor.x,actor.z end
end

function World.update(world,dt,schedule,playerX,playerZ,talkingTo)
    world.elapsed=world.elapsed+dt
    if world.elapsed<1/30 then return end
    local step=math.min(world.elapsed,.12)
    world.elapsed=0
    for _,actor in ipairs(world.actors) do
        advanceActor(actor,step,schedule,playerX or world.spawn.x,playerZ or world.spawn.z,talkingTo)
    end
end
end

-- FreeRoamUI
do
-- Safe-area-aware campus HUD, dialogue and pause panel.
PolyLax = PolyLax or {}
local P = PolyLax
local UI = {}
P.FreeRoamUI = UI

local ink = {
    paper=color(245,245,233), dim=color(183,197,192), gold=color(238,206,137),
    glass=color(13,24,27,232), rim=color(74,91,81,232), green=color(38,85,65,246),
    soft=color(119,170,145), empty=color(22,35,36,169), veil=color(8,15,19,155),
    knob=color(68,112,91,245), shade=color(8,13,16,172)
}

local names = {
    campus="Briarbank Campus", school="Briarbank High", lockers="Locker Rooms",
    training="Training Facility", coach="Coach’s Office", drip="PolyLax Drip Lab",
    clubhouse="Pro Clubs Clubhouse"
}

local actions = {
    ethan="Talk", coach="Talk", jace="Talk", maya="Talk", clubs="ENTER PRO CLUBS",
    tryout="Start Tryout", practice="Practice", training="Train", drip="Browse Gear"
}

local timeLabels = {
    morning="Morning", afternoon="Afternoon", practice="Practice time", evening="Evening"
}

local function box(id, title, x, y, width, height)
    return {id=id,label=title,x=x,y=y,w=width,h=height}
end

local function baseLayout(safe)
    local left = safe.left+12
    local right = WIDTH-safe.right-12
    local top = HEIGHT-safe.top-10
    local bottom = safe.bottom+12
    local width = right-left
    local center = (left+right)*.5
    local radius = math.min(48, width*.149)
    local joystick = box("move",nil,left+radius+5,bottom+radius+12,2*radius,2*radius)
    joystick.radius = radius
    local actionWidth = math.min(145,width*.42)
    local interact = box("interact","Interact",right-actionWidth*.5,bottom+73,actionWidth,45)
    local dockWidth = math.min(184,right-(joystick.x+radius+12))
    local gap = 5
    local buttonWidth = (dockWidth-3*gap)*.25
    local function cameraButton(id,label,index)
        local x = right-dockWidth+buttonWidth*.5+(index-1)*(buttonWidth+gap)
        return box(id,label,x,bottom+20,buttonWidth,38)
    end
    local orbitLeft = cameraButton("orbitLeft","‹",1)
    local orbitRight = cameraButton("orbitRight","›",2)
    local zoomOut = cameraButton("zoomOut","−",3)
    local zoomIn = cameraButton("zoomIn","+",4)
    local pause = box("pause","Ⅱ",right-21,top-22,42,42)
    local career = box("career","Career Log",left+(width-7)*.25,top-137,(width-7)*.5,37)
    local equipment = box("equipment","Equipment",right-(width-7)*.25,top-137,(width-7)*.5,37)
    return {
        left=left,right=right,top=top,bottom=bottom,center=center,width=width,
        joystick=joystick,interact=interact,orbitLeft=orbitLeft,orbitRight=orbitRight,
        zoomOut=zoomOut,zoomIn=zoomIn,
        pause=pause,career=career,equipment=equipment,lookBottom=bottom+121,lookTop=top-165,
        controls={interact,orbitLeft,orbitRight,zoomOut,zoomIn,pause,career,equipment}
    }
end

local function wrapped(value, width, fontPixels)
    local lines, current = {}, ""
    local limit = math.max(14,math.floor(width/(fontPixels*.55)))
    for word in tostring(value or ""):gmatch("%S+") do
        if #current+#word+1 > limit and current~="" then
            lines[#lines+1],current = current,word
        else
            current = (current=="" and word or current.." "..word)
        end
    end
    if current~="" then lines[#lines+1] = current end
    return lines
end

local function modalLayout(layout, dialogue)
    local options = dialogue.choices
    local count = math.max(1,options and #options or 0)
    local width = math.min(490,layout.width)
    local textHeight = 21
    local lines = wrapped(dialogue.text,width-35,15)
    local viewport = layout.top-layout.bottom-18
    local optionHeight = math.min(44,(viewport-100)/math.max(count,4))
    local card = {
        w=width, h=67+#lines*textHeight+count*(optionHeight+7), x=layout.center,
        bottom=layout.bottom+6, choices={}, lines=lines, textHeight=textHeight,
        speaker=dialogue.speaker or "Campus"
    }
    local excess = card.h-viewport
    if excess>0 and #lines>0 then
        card.textHeight = math.max(12,textHeight-excess/#lines)
        card.h = 67+#lines*card.textHeight+count*(optionHeight+7)
    end
    card.y = card.bottom+card.h*.5
    card.top = card.bottom+card.h
    for i=1,count do
        local option = options and options[i]
        local button = box("choice",option and option.label or "Continue",
            card.x, card.bottom+(count-i+.5)*(optionHeight+7)+6, card.w-24, optionHeight)
        button.choice = i
        card.choices[i] = button
    end
    return card
end

function UI.layout(roam)
    local safe = P.UI.safeArea()
    local cache = roam.hud
    local stamp = WIDTH..":"..HEIGHT..":"..safe.left..":"..safe.right..":"..safe.top..":"..safe.bottom
    if not cache or cache.stamp~=stamp then
        cache = baseLayout(safe)
        cache.stamp = stamp
        roam.hud = cache
    end
    if roam.dialogue then
        if cache.dialogue ~= roam.dialogue then
            cache.dialogue,cache.modal = roam.dialogue,modalLayout(cache,roam.dialogue)
        end
        cache.buttons,cache.choices = cache.modal.choices,cache.modal.choices
    elseif roam.paused then
        if not cache.pauseItems then
            local y = (cache.top+cache.bottom)*.5+28
            local width = math.min(290,cache.width-30)
            cache.pauseItems = {
                box("resume","Resume",cache.center,y,width,44),
                box("settings","Settings",cache.center,y-57,width,44),
                box("home","Main Menu",cache.center,y-114,width,44)
            }
        end
        cache.buttons,cache.choices = cache.pauseItems,nil
    else
        cache.interact.enabled = roam.point~=nil
        cache.zoomOut.enabled = roam.zoomSteps>P.FreeRoam.minZoom
        cache.zoomIn.enabled = roam.zoomSteps<P.FreeRoam.maxZoom
        cache.buttons,cache.choices = cache.controls,nil
    end
    return cache
end

local function begin()
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

local function shade(value, x, y, size, tint, width, left)
    if not value then return end
    value = tostring(value)
    fill(tint)
    fontSize(size)
    if width and textSize then
        local used = textSize(value)
        if used > width then fontSize(math.max(10,size*width/used)) end
    end
    if left then textMode(CORNER) end
    text(value,x,left and y-size*.53 or y)
    if left then textMode(CENTER) end
end

local function rounded(x,y,w,h,r,tint)
    P.Style.rounded(x,y,w,h,r,tint)
end

local function panel(x,y,w,h,r,tint,edge)
    rounded(x,y,w,h,r,edge or ink.rim)
    rounded(x,y,w-2,h-2,r-1,tint or ink.glass)
end

local function button(item, active, title, size, accent)
    local color = item.enabled==false and ink.empty or active and ink.knob or accent and ink.green or ink.glass
    panel(item.x,item.y,item.w,item.h,12,color,accent and ink.soft or ink.rim)
    shade(title or item.label,item.x,item.y,size or 14,item.enabled==false and ink.dim or ink.paper,item.w-11)
end

local function blackout(tint)
    rectMode(CORNER)
    fill(tint)
    rect(0,0,WIDTH,HEIGHT)
end

local function pressed(roam, item)
    return roam.press and roam.press.item==item
end

local function drawDialogue(roam, card)
    blackout(ink.veil)
    panel(card.x,card.y,card.w,card.h,18)
    rounded(card.x-card.w*.5+17,card.top-26,4,21,2,ink.gold)
    shade(card.speaker,card.x-card.w*.5+28,card.top-25,20,ink.gold,card.w-39,true)
    for index,line in ipairs(card.lines) do
        shade(line,card.x-card.w*.5+18,card.top-52-(index-1)*card.textHeight,
            math.min(15,card.textHeight),ink.paper,card.w-36,true)
    end
    for _,item in ipairs(card.choices) do
        button(item,pressed(roam,item),nil,14,true)
    end
end

local function drawPause(roam, hud)
    blackout(ink.veil)
    local centerY = (hud.top+hud.bottom)*.5
    panel(hud.center,centerY-12,math.min(320,hud.width),246,18)
    shade("Paused",hud.center,centerY+82,24,ink.paper,hud.width-20)
    for _,item in ipairs(hud.pauseItems) do
        button(item,pressed(roam,item),nil,15,item.id=="resume")
    end
end

local function drawObjective(roam, hud)
    local y = hud.top-82
    panel(hud.center,y,hud.width,59,12)
    shade("Objective",hud.left+13,y+17,12,ink.gold,hud.width-26,true)
    local objective = roam.objective and roam.objective() or "Explore the campus"
    if hud.objectiveText ~= objective then
        hud.objectiveText = objective
        hud.objectiveLines = wrapped(objective,hud.width-25,14)
    end
    local lines = hud.objectiveLines
    if #lines==1 then
        shade(lines[1],hud.left+13,y-7,14,ink.paper,hud.width-26,true)
    else
        shade(lines[1],hud.left+13,y-2,13,ink.paper,hud.width-26,true)
        shade(table.concat(lines," ",2),hud.left+13,y-18,13,ink.paper,hud.width-26,true)
    end
end

local function drawCampus(roam,hud)
    local headerWidth = hud.width-49
    local headerX = hud.left+headerWidth*.5
    panel(headerX,hud.top-22,headerWidth,42,12)
    local time = timeLabels[roam.timeOfDay]
    shade(names[roam.zone] or "Campus",hud.left+13,hud.top-(time and 17 or 22),17,
        ink.paper,headerWidth-25,true)
    if time then shade(time,hud.left+13,hud.top-33,11,ink.gold,headerWidth-25,true) end
    button(hud.pause,pressed(roam,hud.pause),nil,18)
    drawObjective(roam,hud)
    button(hud.career,pressed(roam,hud.career))
    button(hud.equipment,pressed(roam,hud.equipment))
    button(hud.orbitLeft,pressed(roam,hud.orbitLeft),nil,21)
    button(hud.orbitRight,pressed(roam,hud.orbitRight),nil,21)
    button(hud.zoomOut,pressed(roam,hud.zoomOut),nil,21)
    button(hud.zoomIn,pressed(roam,hud.zoomIn),nil,21)

    local joy = hud.joystick
    ellipseMode(CENTER)
    fill(ink.shade)
    ellipse(joy.x,joy.y-2,joy.w+3)
    fill(ink.rim)
    ellipse(joy.x,joy.y,joy.w)
    fill(ink.glass)
    ellipse(joy.x,joy.y,joy.w-2)
    for quarter=0,3 do
        fill(ink.soft)
        ellipse(joy.x+math.cos(quarter*math.pi*.5)*joy.radius*.77,
            joy.y+math.sin(quarter*math.pi*.5)*joy.radius*.77,4)
    end
    local x,y = joy.x+roam.axisX*joy.radius*.61,joy.y+roam.axisY*joy.radius*.61
    fill(ink.soft)
    ellipse(x,y,joy.radius*.91)
    fill(ink.knob)
    ellipse(x,y,joy.radius*.79)
    local point = roam.point
    button(hud.interact,pressed(roam,hud.interact),
        point and (point.action or actions[point.id] or (point.zone and "Enter" or "Interact")) or nil,
        point and point.id=="clubs" and 13 or 15,point~=nil)
    if point then
        shade(point.label,hud.interact.x,hud.interact.y+40,12,ink.paper,hud.interact.w+18)
    end
    if roam.noticeTime>0 then
        local noticeY = hud.bottom+149
        panel(hud.center,noticeY,hud.width,33,10)
        shade(roam.noticeText,hud.center,noticeY,12,ink.paper,hud.width-17)
    end
end

function UI.draw(roam, fade)
    local hud = UI.layout(roam)
    begin()
    if roam.dialogue then
        drawDialogue(roam,hud.modal)
    elseif roam.paused then
        drawPause(roam,hud)
    else
        drawCampus(roam,hud)
    end
    if fade and fade>0 then blackout(color(8,15,19,math.floor(math.min(1,fade)*255))) end
    popMatrix()
    popStyle()
end
end

-- FreeRoam
do
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
    roam.rig.root.position = vec3(roam.x,0,roam.z)
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
    place(roam)
    roam.animation = P.AnimationController.new(roam.rig)
    P.AnimationController.update(roam.animation,0,{speed=0})
    if P.RoadEquipment.stow then P.RoadEquipment.stow(roam.rig) end
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
    if P.RoadEquipment.stow then P.RoadEquipment.stow(roam.rig) end
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
        place(roam)
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
    P.AnimationController.update(roam.animation,dt,{speed=speed,turn=turn})
    if P.RoadEquipment.stow then P.RoadEquipment.stow(roam.rig) end
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
end

-- RoadToGlory
do
-- Story career adapters for the existing match, practice, and HUD systems.
PolyLax = PolyLax or {}
local P = PolyLax
local Road = {}
P.RoadToGlory = Road

local matchPlayer = "road-player"
local teammate = "road-ethan"
local titles = {practice="First Practice",training="Training Session",tryout="Freshman Tryouts",debut="First Team Game"}

function Road.new(profile)
    return {story=P.Story.load(),profile=profile}
end

function Road.appearance(road)
    return P.Athlete.profile(road.story.athlete,road.profile)
end

function Road.stickType(road)
    return P.Career.positions[road.story.athlete.position].stick
end

function Road.newPlay(road, scene, activity)
    assert(titles[activity], "Unknown Road to Glory activity")
    local athlete = road.story.athlete
    local appearance = Road.appearance(road)
    local school = P.SchoolTeams.defaultOpponent(athlete.team)
    local opponent = school and school.id or 2
    local play = {scene=scene,camera=P.CameraController.new(scene,48),activity=activity}
    local options = {id="road:"..activity,profileId=matchPlayer,stage=athlete.stage,persist=false}
    if activity=="practice" or activity=="training" then
        play.controller = P.Gameplay
        options.mode = "PRACTICE"
        appearance.attributes = athlete.attributes
        play.game = P.Gameplay.new(scene,appearance,P.Athlete.uniform(athlete,false),opponent,options)
        play.duration = 30
        play.game.clock = play.duration
        local rig = play.game.squad[1].rig
        P.Character.setStickType(rig,Road.stickType(road))
        P.RoadEquipment.applyMatch(rig,road.story.equipment)
    else
        play.controller = P.FullMatch
        options.mode = "ROAD TO GLORY"
        local rules = P.Career.matchOptions(athlete,{opponent=opponent,home=true})
        rules.periodLength, rules.periods, rules.careerEntryDelay = 35,1,0
        if activity=="debut" and rules.careerPlayerRole~="FOGO" then
            local placement = road.story.results.tryout and road.story.results.tryout.placement
            rules.careerEntryDelay = placement=="Varsity rotation" and 0 or placement=="JV rotation" and 4 or 8
        end
        rules.playerName, rules.statistics = P.Athlete.name(athlete),options
        local ethanSlot = rules.careerPlayerSlot==5 and 6 or 5
        rules.teammates = {[ethanSlot]={name="Ethan Cole",number=17,role="M",statId=teammate,
            attributes=road.story.ethan.attributes}}
        play.game = P.FullMatch.new(scene,appearance,athlete.team,opponent,rules)
        P.RoadEquipment.applyMatch(P.FullMatch.careerAthlete(play.game).rig,road.story.equipment)
        P.CameraController.cycle(play.camera)
        P.CameraController.cycle(play.camera)
    end
    play.game.announcement,play.game.announcementTime = titles[activity],2
    return play
end

function Road.capture(road, play)
    local game = play.game
    local practice = play.controller==P.Gameplay
    if play.recorded or (practice and game.clock>0) or (not practice and game.phase~="FINAL") then return end
    local box = P.Statistics.matchSummary(game)
    local athlete = box and box.players[matchPlayer]
    if not athlete then return false,"The player's activity statistics are unavailable." end
    local ethan = box.players[teammate]
    return P.Story.recordActivity(road.story,play.activity,{
        id=box.id,stats=athlete.stats,elapsed=box.elapsed,position=road.story.athlete.position,
        homeScore=box.homeScore,awayScore=box.awayScore,ethanStats=ethan and ethan.stats
    })
end

local function item(layout,id,label,x,y,w,h)
    local button={id=id,label=label,x=x,y=y,w=w,h=h}
    layout.buttons[#layout.buttons+1]=button
    layout.byId[id]=button
end

function Road.layout(road)
    local safe=P.UI.safeArea()
    local w=math.min(440,WIDTH-safe.left-safe.right-28)
    local x=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-18,safe.bottom+14
    local l={w=w,x=x,top=top,bottom=bottom,buttons={},byId={}}
    item(l,"BACK","‹ Campus",x-w*.5+43,top-17,86,34)
    item(l,"PLAYER","Edit Athlete",x,bottom+24,w,48)
    return l
end

local function label(value,x,y,size,ink,width)
    fontSize(size)
    if textSize then
        local measured=textSize(value)
        if measured>width then fontSize(math.max(10,size*width/measured)) end
    end
    fill(ink)
    text(value,x,y)
end

function Road.drawJournal(road)
    local l=Road.layout(road)
    local story,style=road.story,P.Style
    local ink=style.palette
    local athlete=story.athlete
    local objective,detail=P.Story.objective(story)
    background(ink.deep)
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    noStroke()
    textAlign(CENTER)
    textMode(CENTER)
    font("AvenirNext-DemiBold")
    for _,button in ipairs(l.buttons) do
        style.panel(button.x,button.y,button.w,button.h,button.id=="PLAYER")
        label(button.label,button.x,button.y,14,ink.white,button.w-12)
    end
    label("Road to Glory",l.x,l.top-71,24,ink.white,l.w)
    label("Brothers in Arms  ·  The Freshmen",l.x,l.top-99,13,ink.glow,l.w)
    label(P.Athlete.name(athlete).."  ·  "..P.Career.positions[athlete.position].label,
        l.x,l.top-136,15,ink.white,l.w)
    label(P.Career.teamName(athlete).."  ·  "..P.Attributes.overall(athlete.attributes,athlete.position).." OVR",
        l.x,l.top-160,13,ink.muted,l.w)
    style.panel(l.x,l.top-211,l.w,66,false)
    label(objective or "Explore campus",l.x,l.top-200,15,ink.white,l.w-20)
    label(detail or "",l.x,l.top-223,12,ink.muted,l.w-20)
    local relationships=story.relationships or {}
    local y=l.top-268
    for _,person in ipairs({{"Ethan Cole","ethan"},{"Coach Mercer","coach"},{"Jace Holloway","jace"}}) do
        style.panel(l.x,y,l.w,28,false,8)
        label(person[1],l.x-l.w*.20,y,13,ink.white,l.w*.55)
        label(tostring(relationships[person[2]] or 0),l.x+l.w*.32,y,13,ink.glow,l.w*.20)
        y=y-34
    end
    local result=story.results.tryout
    if result and y>l.bottom+51 then
        label(string.format("Tryout  %d / 100  ·  %s",result.grade,result.placement),
            l.x,y,12,ink.amber,l.w-12)
    end
    popMatrix()
    popStyle()
end

function Road.journalTouch(road,touch)
    if touch.state~=BEGAN then return end
    for _,button in ipairs(Road.layout(road).buttons) do
        if P.UI.hit(button,touch.x,touch.y) then return button.id end
    end
end
end

-- End of PolyLax 3.4.3
