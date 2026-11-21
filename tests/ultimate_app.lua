-- Run from the repository root: lua tests/ultimate_app.lua [PolyLax.codea]
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock = dofile(tests.."craft_mock.lua")
WIDTH = tonumber(os.getenv("POLYLAX_TEST_WIDTH")) or WIDTH
HEIGHT = tonumber(os.getenv("POLYLAX_TEST_HEIGHT")) or HEIGHT
viewer = {safeArea={top=44,bottom=34,left=0,right=0}}
DeltaTime = .05
for _, key in ipairs({"stroke","strokeWidth","noFill","line","translate","scale","rotate",
    "clip","textWrapWidth","spriteMode","smooth","noSmooth"}) do
    _G[key] = function() end
end
function background(...) assert(select("#",...)~=3,"Main displayed its fatal error screen") end
function textSize(s) return #s*fontSize()*.50,fontSize() end

local function copy(value)
    if type(value)~="table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local saved = {}
json = {
    encode=function(value)
        saved[#saved+1] = copy(value)
        return tostring(#saved)
    end,
    decode=function(value) return copy(saved[tonumber(value)]) end
}

local combined = os.getenv("POLYLAX_TEST_DELIVERABLE")
local privateBuild = os.getenv("POLYLAX_TEST_PRIVATE") == "1"
if combined then dofile(combined)
else
    local info = assert(io.open(project.."/Info.plist"))
    for tab in info:read("*a"):gmatch("<string>([%w_]+)</string>") do
        if privateBuild and tab=="Ultimate" then
            local file=assert(io.open(project.."/Ultimate.lua"))
            local source,count=file:read("*a"):gsub("local developerBuild = false","local developerBuild = true",1)
            file:close()
            assert(count==1)
            assert(load(source))()
        else
            dofile(project.."/"..tab..".lua")
        end
    end
    info:close()
end

local function upvalue(fn, key)
    for i=1,80 do
        local name, value = debug.getupvalue(fn,i)
        if name==key then return value end
        if not name then break end
    end
end

local serial = 0
local function tap(button)
    assert(button,"Missing touch target")
    serial = serial + 1
    touched({state=BEGAN,id=serial,x=button.x,y=button.y})
    touched({state=ENDED,id=serial,x=button.x,y=button.y})
end

local P = PolyLax
local U, E = P.Ultimate, P.Ultimate.Economy
local career = P.Career.new()
assert(P.Career.save(career))
local clubs = P.Clubs.load()
assert(P.Clubs.create(clubs,"Existing Club","highSchool","briarbank"))
local careerSave, clubsSave = mock.store["PolyLax.Career.1"], mock.store["PolyLax.Clubs.1"]
setup()
draw()
local app = assert(upvalue(upvalue(draw,"runFrame"),"state"))
local front = P.Style.screenLayout("FRONT")
for i, button in ipairs(front.buttons) do
    assert(button.y-button.h*.5>=front.bottom)
    if i>1 then
        local above=front.buttons[i-1]
        assert(button.y+button.h*.5<above.y-above.h*.5)
    end
end
tap(front.byId.ULTIMATE)
draw()
assert(app.page=="ULTIMATE")
local ui, profile = app.ultimate, app.ultimate.profile

-- Tap through the public UI, then check match startup and settlement from Main.
local function ultimateButton(id)
    return assert(P.UltimateUI.layout(ui).byId[id],"Missing Ultimate Team button "..id)
end

if privateBuild then
    tap(ultimateButton("DEV")); draw()
    tap(ultimateButton("TEST_GOLD")); draw()
    assert(profile.coins==1000000 and not ultimateButton("TEST_GOLD").enabled)
    tap(ultimateButton("DEV_RESET")); draw()
    assert(ui.page=="DEV_CONFIRM" and profile.coins==1000000)
    tap(ultimateButton("BACK"))
    tap(ultimateButton("DEV_RESET")); tap(ultimateButton("DEV_CONFIRM")); draw()
    assert(ui.page=="DEV" and profile.coins==0 and profile.testGoldGranted)
    tap(ultimateButton("BACK"))
else
    assert(not P.UltimateUI.layout(ui).byId.DEV)
end

local function verifyMatch(play)
    local game = play.game
    assert(#game.squad==20 and #game.teams[1]==10 and #game.teams[2]==10)
    assert(game.homeTeam.name=="Ultimate Squad" and game.awayTeam.name=="Gold Scouts")
    assert(game.kits[1].primary.r~=game.kits[2].primary.r)
    assert(game.statistics.mode=="ULTIMATE TEAM" and #game.statistics.sides[1].roster==10)
    for _, player in ipairs(game.squad) do
        assert(player.anim and player.rig.root.active)
    end
    for slot, uid in pairs(profile.squad) do
        if U.resolveCard(profile,uid) then
            local actor = game.squad[tonumber(slot)]
            assert(actor.cardUID==uid and not actor.temporaryAI)
            assert(game.statistics.entries[actor.id].actor.name==actor.name)
            assert(P.Attributes.overall(actor.attributes,actor.role)>=70)
        end
    end
end

local function finishMatch(play, own, opponent)
    -- Let the faceoff enter LIVE and exercise goal-plane detection before the final whistle.
    if play.presentation then P.Presentation.skip(play) end
    for _=1,220 do
        if play.game.phase=="LIVE" then break end
        draw()
    end
    local game = play.game
    assert(game.phase=="LIVE","The full-match faceoff did not start live play")
    game.period=game.rules.periods
    if own~=opponent then
        local team=own>opponent and 1 or 2
        local goal=game.goalsByTeam[team]
        local keeper=game.squad[game.keepers[3-team]]
        keeper.x=goal.x+8
        keeper.rig.root.position=vec3(keeper.x,0,keeper.z)
        local origin=vec3(goal.x+goal.halfWidth*.35,goal.top*.45,goal.z-goal.attackSign*.25)
        game.carrier,game.pending,game.loose=nil,nil,nil
        game.ball.position=origin
        game.ballVelocity=vec3(0,0,goal.attackSign*26)
        game.flight={from=game.teams[team][1],kind="shot",team=team,goal=goal,
            origin=origin,velocity=game.ballVelocity,time=0,duration=.5,onTarget=true}
        draw()
        assert(game.phase=="GOAL" and game.homeScore==own and game.awayScore==opponent)
        game.clock=0
        if play.presentation then P.Presentation.skip(play) end
    else
        game.clock=.001
    end
    for _=1,80 do
        if game.phase=="FINAL" then break end
        draw()
    end
    assert(game.phase=="FINAL" and play.recorded and play.presentation)
    local delta = profile.coins
    for _=1,160 do
        if app.page=="STATS" then break end
        draw()
    end
    assert(app.page=="STATS" and app.statView.summary.final)
    assert(profile.coins==delta,"A final result credited gold twice")
    tap(P.StatsUI.layout(app.statView).close)
    draw()
    assert(app.page=="ULTIMATE" and not app.ultimatePlay)
end

tap(ultimateButton("PACKS")); draw()
assert(not P.UltimateUI.layout(ui).byId.TEST_GOLD)
tap(ultimateButton("STARTER")); draw()
assert(profile.starterGranted and #ui.reveal.cards==5 and #U.ownedCards(profile)==5)
assert(ui.reveal.cards[5].rating>=85)
tap(ultimateButton("DONE")); tap(ultimateButton("DONE"))
assert(not P.UltimateUI.layout(ui).byId.STARTER)

-- A wallet fixture keeps this UI test independent of repeated matches.
profile.coins=5000
assert(U.save(profile))
tap(ultimateButton("BUY_PACK")); draw()
assert(profile.coins==1500 and profile.unopenedPacks==1)
tap(ultimateButton("OPEN_PACK")); draw()
assert(profile.unopenedPacks==0 and #ui.reveal.cards==5 and #U.ownedCards(profile)==10)
tap(ultimateButton("DONE")); tap(ultimateButton("DONE"))
tap(ultimateButton("BACK")); tap(ultimateButton("WHEEL")); draw()
local wheel=ultimateButton("SPIN")
tap(wheel)
touched({state=ENDED,id=serial,x=wheel.x,y=wheel.y})
tap(wheel)
draw()
assert(profile.coins==300 and #ui.reveal.cards==1 and #U.ownedCards(profile)==11)
for _=1,70 do draw() end
tap(ultimateButton("WHEEL_DONE"))
assert(not ui.reveal and P.UltimateUI.layout(ui).byId.SPIN.enabled==false)
tap(ultimateButton("BACK"))

tap(ultimateButton("SQUAD")); draw()
local owned = U.ownedCards(profile)[1]
local slot
for i, role in ipairs(U.slotRoles) do
    if U.role(owned.player)==role then slot=i break end
end
tap(ultimateButton("SLOT:"..slot)); draw()
while not P.UltimateUI.layout(ui).byId["CARD:"..owned.uid] do
    local nextPage = ultimateButton("NEXT")
    assert(nextPage.enabled,"Owned athlete was missing from the slot picker")
    tap(nextPage); draw()
end
tap(ultimateButton("CARD:"..owned.uid)); draw()
assert(profile.squad[slot]==owned.uid and U.load().squad[slot]==owned.uid)
tap(ultimateButton("BACK"))
tap(ultimateButton("COLLECTION")); draw()
assert(ui.page=="COLLECTION")
tap(ultimateButton("BACK"))
tap(ultimateButton("SBC")); draw()
assert(ui.page=="SBC" and ui.sbc)
tap(P.Ultimate.SBCUI.layout(ui.sbc).back); draw()
assert(ui.page=="DASHBOARD")
tap(ultimateButton("VAULT")); draw()
tap(ultimateButton("KIT:heritage_crimson")); draw()
assert(U.load().equippedKit=="heritage_crimson")
tap(ultimateButton("BACK"))

local records = {{1,0,450,"win"},{0,0,250,"draw"},{0,1,150,"loss"}}
for i, record in ipairs(records) do
    local before = profile.coins
    tap(ultimateButton("PLAY")); draw()
    assert(app.page=="ULTIMATE_MATCH")
    local play = assert(app.ultimatePlay)
    verifyMatch(play)
    assert(play.game.kits[1].primary.r==U.kit("heritage_crimson").home[1])
    assert(play.game.squad[slot].cardUID==owned.uid)
    assert(not E.recordMatch(profile,record[4],play.id+1,record[1],record[2]))
    if i==1 then
        P.Presentation.skip(play)
        draw()
        tap(app.layout.pause); draw()
        assert(app.page=="PAUSE")
        tap(P.Style.screenLayout("PAUSE").byId.HOME); draw()
        assert(app.page=="ULTIMATE" and ui.activeMatch)
        assert(ultimateButton("PLAY").label=="Resume Match")
        tap(ultimateButton("PLAY")); draw()
        assert(app.page=="ULTIMATE_MATCH" and app.ultimatePlay==play)
    end
    finishMatch(play,record[1],record[2])
    local loaded = U.load()
    assert(loaded.matches==i and loaded.coins==before+record[3] and #U.ownedCards(loaded)==11)
    assert(loaded.matchHistory[i].result==record[4])
    local box=assert(loaded.matchHistory[i].box)
    assert(box.homeScore==record[1] and box.awayScore==record[2])
    assert((box.sides[1].stats.goals or 0)==record[1] and (box.sides[2].stats.goals or 0)==record[2])
    assert(not E.recordMatch(profile,record[4],play.id,record[1],record[2]))
end
assert(profile.wins==1 and profile.draws==1 and profile.losses==1)
assert(mock.store["PolyLax.Career.1"]==careerSave and mock.store["PolyLax.Clubs.1"]==clubsSave)
assert(mock.store["PolyLax.Statistics.2.career-player"]==nil)
tap(ultimateButton("RECORD")); draw()
assert(ui.page=="RECORD")
tap(ultimateButton("RESULT:1")); draw()
assert(app.page=="STATS" and app.statView.summary.homeScore==1)
tap(P.StatsUI.layout(app.statView).close); draw()
assert(app.page=="ULTIMATE" and ui.page=="RECORD")
tap(ultimateButton("BACK"))
tap(ultimateButton("BACK")); draw()
assert(app.page=="FRONT")
print("Ultimate dashboard, packs, wheel, squad, SBC, jerseys, 20-player matches and single-settlement payouts passed.")
