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
