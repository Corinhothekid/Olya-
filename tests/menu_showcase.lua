-- Run from the repository root with Lua 5.4:
-- lua tests/menu_showcase.lua [PolyLax.codea]
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock = dofile(tests.."craft_mock.lua")
WIDTH = tonumber(os.getenv("POLYLAX_TEST_WIDTH")) or WIDTH
HEIGHT = tonumber(os.getenv("POLYLAX_TEST_HEIGHT")) or HEIGHT
for _, name in ipairs({"stroke","strokeWidth","noFill","line","textWrapWidth","showKeyboard",
    "hideKeyboard","spriteMode","noTint","tint","smooth","translate","scale","rotate","noSmooth"}) do
    _G[name] = function() end
end
function background() end

local function copy(value)
    if type(value)~="table" then return value end
    local snapshot = {}
    for key, item in pairs(value) do snapshot[key] = copy(item) end
    return snapshot
end

local records = {}
json = {
    encode=function(value)
        records[#records+1]=copy(value)
        return tostring(#records)
    end,
    decode=function(index) return copy(records[tonumber(index)]) end
}

local combined = os.getenv("POLYLAX_TEST_DELIVERABLE")
if combined then
    dofile(combined)
else
    local info = assert(io.open(project.."/Info.plist"))
    local plist = info:read("*a")
    info:close()
    for tab in plist:gmatch("<string>([%w_]+)</string>") do
        dofile(project.."/"..tab..".lua")
    end
end

local P = PolyLax
local Showcase, Assets = assert(P.MenuShowcase), assert(P.MenuAssets)
local profile = P.Profile.load()
local solo = P.Career.new()
solo.name, solo.xp = "Solo Athlete", 42
assert(P.Career.save(solo) and P.Athlete.ensure(solo,profile))
local club = P.Clubs.load()
club.player.name = "Clubs Athlete"
assert(P.Clubs.create(club,"Test Club","highSchool","briarbank"))
local oldCareer, oldClubs = mock.store["PolyLax.Career.1"], mock.store["PolyLax.Clubs.1"]

local scene = craft.scene()
local showcase = Showcase.new(scene,1,2)
assert(showcase.scene==scene and #showcase.actors==6)
assert(showcase.ball and showcase.field and showcase.duration>8)
local entityCount = #scene.entities
assert(entityCount>0)
local startCamera = scene.camera.position
local stages, actions = {}, {}
local goals, loops = 0, 0
local scored = false
for _=1,math.ceil(showcase.duration*64) do
    local oldPosition, oldCycle = scene.camera.position, showcase.cycles
    Showcase.update(showcase,1/30)
    if showcase.cycles~=oldCycle then
        loops=loops+1
        assert((scene.camera.position-oldPosition):len()<2,"Camera jumped at the loop seam")
    end
    if showcase.scored and not scored then goals=goals+1 end
    scored=showcase.scored
    stages[showcase.stage]=true
    for _, actor in ipairs(showcase.actors) do
        if actor.anim.action then actions[actor.anim.action]=true end
    end
end
for _, stage in ipairs({"opening","tracking","dodge","shot","celebration","return"}) do
    assert(stages[stage],"Showcase skipped "..stage)
end
assert(actions.dodge and actions.shoot and actions.showcaseCelebrate,"The sequence missed an action clip")
assert(goals>=2 and loops>=2,"The shot or loop failed to repeat")
assert((scene.camera.position-startCamera):len()>0)
assert(#scene.entities==entityCount,"Showcase update added entities")
assert(mock.store["PolyLax.Career.1"]==oldCareer and mock.store["PolyLax.Clubs.1"]==oldClubs)

local missing = Assets.load()
assert(not Assets.drawLogo(missing,200,600,220,100),"Missing logo drew a sprite")
assert(not missing.hasTheme,"Missing theme resolved as a track")
Assets.enter(missing)
Assets.leave(missing)

local function upvalue(fn,key)
    local index=1
    while true do
        local name,value=debug.getupvalue(fn,index)
        if name==key then return value end
        if not name then return end
        index=index+1
    end
end

local originalNew, originalUpdate = Showcase.new, Showcase.update
local menuScene, menuState, newCalls, updateCalls
newCalls, updateCalls = 0, 0
function Showcase.new(menuCraft,...)
    newCalls=newCalls+1
    menuScene=menuCraft
    menuState=originalNew(menuCraft,...)
    return menuState
end
function Showcase.update(menu,...)
    assert(menu==menuState,"Main rendered an unrelated game scene as a showcase")
    updateCalls=updateCalls+1
    return originalUpdate(menu,...)
end

local screenLayout, careerLayout, clubLayout
local originalScreen, originalCareer, originalClub = P.Style.screen,P.CareerUI.draw,P.ClubsUI.layout
function P.Style.screen(page,layout,...)
    screenLayout=layout
    return originalScreen(page,layout,...)
end
function P.CareerUI.draw(career,layout,...)
    careerLayout=layout
    return originalCareer(career,layout,...)
end
function P.ClubsUI.layout(...)
    clubLayout=originalClub(...)
    return clubLayout
end

local function tick()
    draw()
    local diagnostic = upvalue(draw,"startupError")
    assert(not diagnostic,diagnostic)
end
local function tap(button)
    assert(button and button.enabled~=false,"No enabled button for test route")
    touched({id=1,state=BEGAN,x=button.x,y=button.y})
    tick()
end

setup()
tick()
local state=assert(upvalue(assert(upvalue(draw,"runFrame")),"state"))
assert(state.page=="FRONT" and menuScene and newCalls==1 and updateCalls>0)
local count = #menuScene.entities
local before = updateCalls
tap(screenLayout.byId.MODES)
assert(state.page=="MODES" and updateCalls==before)
tap(screenLayout.byId.HOME)
assert(state.page=="FRONT" and updateCalls>before)
tap(screenLayout.byId.CAREER)
assert(state.page=="CAREER" and state.career.name=="Solo Athlete")
tap(careerLayout.back)
tap(screenLayout.byId.CLUBS)
assert(state.page=="CLUBS" and state.clubView=="CLUBS" and state.clubs.player.name=="Clubs Athlete")
tap(clubLayout.byId.BACK)
tap(screenLayout.byId.SETTINGS)
assert(state.page=="CLUBS" and state.clubView=="SETTINGS")
tap(clubLayout.byId.BACK)
assert(state.page=="FRONT" and newCalls==1 and #menuScene.entities==count)
assert(mock.store["PolyLax.Career.1"]==oldCareer and mock.store["PolyLax.Clubs.1"]==oldClubs)

-- The confirmed project keys are opaque to the menu loader.
local logo, theme = {}, {}
asset={logo=logo,Main_Menu_Melody=theme}
local imageReads, spriteDraws, starts, stops = 0, 0, 0, 0
function readImage(key)
    assert(key==logo)
    imageReads=imageReads+1
    return {width=300,height=150}
end
function sprite(_,x,y,w,h)
    spriteDraws=spriteDraws+1
    assert(x==200 and y==600 and w==200 and h==100,"Logo exceeded its aspect-fit bounds")
end
music=setmetatable({duration=92}, {__call=function(track,key,looped,volume)
    assert(key==theme and looped==true and volume==.48)
    starts=starts+1
    track.name="Main Menu Melody.m4a"
    track.currentTime=0
    track.playing=true
end})
function music.stop()
    stops=stops+1
    music.name=nil
    music.playing=false
end
local media = Assets.load()
assert(media.hasTheme and not media.muted and starts==0)
assert(Assets.drawLogo(media,200,600,220,100) and Assets.drawLogo(media,200,600,220,100))
assert(imageReads==1 and spriteDraws==2,"The logo was reloaded every draw")
Assets.enter(media)
Assets.enter(media)
assert(starts==1,"Entering the menu twice restarted the theme")
music.currentTime=17.5
Assets.toggleMute(media)
assert(stops==1 and media.muted and Assets.load().muted)
Assets.enter(media)
assert(starts==1,"Muted theme started")
Assets.toggleMute(media)
Assets.enter(media)
assert(starts==2 and not Assets.load().muted and music.currentTime==17.5)
music.name="Another track"
Assets.leave(media)
assert(stops==1,"Leaving the menu stopped unrelated music")
music.name, music.playing = nil, false

local workingRead, workingMusic = readImage, music
function readImage() error("Image decoder rejected the file") end
music=setmetatable({}, {__call=function() error("Audio decoder rejected the file") end})
local corrupt = Assets.load()
assert(not Assets.drawLogo(corrupt,200,600,220,100),"Image failure skipped text fallback")
assert(not Assets.enter(corrupt) and not corrupt.hasTheme,"Audio failure crashed or stayed available")
Assets.leave(corrupt)
readImage, music = workingRead, workingMusic

function sprite(_,_,_,w,h)
    assert(w>0 and math.abs(w/h-2)<.001,"The front menu distorted the logo")
    spriteDraws=spriteDraws+1
end

local priorStarts, priorDraws = starts, spriteDraws
setup()
tick()
local assetState=assert(upvalue(assert(upvalue(draw,"runFrame")),"state"))
assert(starts==priorStarts+1 and spriteDraws>priorDraws,"Startup missed the logo or looping theme")
for _=1,8 do tick() end
assert(starts==priorStarts+1,"Drawing frames restarted the theme")
music.currentTime=24.25
local beforeLeave = stops
tap(screenLayout.byId.MODES)
tap(screenLayout.byId.PRACTICE)
assert(assetState.page=="PRACTICE" and stops==beforeLeave+1 and not music.name)
tap(assetState.layout.pause)
tap(screenLayout.byId.HOME)
assert(assetState.page=="FRONT" and starts==priorStarts+2 and music.currentTime==24.25)
tap(screenLayout.byId.SETTINGS)
tap(clubLayout.byId.MENU_MUSIC)
assert(assetState.menuAssets.muted and mock.store["PolyLax.MenuMusicMuted.1"]==1)
local mutedStarts = starts
tap(clubLayout.byId.BACK)
assert(starts==mutedStarts,"Muted audio started on the front menu")
tap(screenLayout.byId.SETTINGS)
tap(clubLayout.byId.MENU_MUSIC)
assert(not assetState.menuAssets.muted and mock.store["PolyLax.MenuMusicMuted.1"]==0)
tap(clubLayout.byId.BACK)
assert(starts==mutedStarts+1,"Returning to the front menu did not start the unmuted theme")
assert(mock.store["PolyLax.Career.1"]==oldCareer and mock.store["PolyLax.Clubs.1"]==oldClubs)
print("Cinematic loops, exact asset keys, startup/resume audio, four menu routes, and media-error fallbacks passed.")
