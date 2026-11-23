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
