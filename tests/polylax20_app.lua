-- From the repository root, run with Lua 5.4:
--   lua tests/polylax20_app.lua
local tests=(arg and arg[0] and arg[0]:match("^(.*[/])")) or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests..'craft_mock.lua')
for _, key in ipairs({'stroke','strokeWidth','noFill','textWrapWidth','line','smooth','noSmooth','translate','rotate','clip'}) do
    _G[key]=function()end
end
function background(...) if select('#',...)==3 then error('Unexpected fatal game error') end end
local project=(arg and arg[1]) or os.getenv('POLYLAX_TEST_PROJECT') or 'PolyLax.codea'
local info=assert(io.open(project..'/Info.plist'))
local tabs={}
for tab in info:read('*a'):gmatch('<string>([%w_]+)</string>') do tabs[#tabs+1]=tab end
info:close()
local deliverable=os.getenv('POLYLAX_TEST_DELIVERABLE')
if deliverable then dofile(deliverable)
else for _,tab in ipairs(tabs) do dofile(project..'/'..tab..'.lua') end end
local function up(f,k)
    for i=1,80 do local n,v=debug.getupvalue(f,i); if n==k then return v end; if not n then return end end
end
local function tap(item,id,phase,x,y)
    touched({id=id or 1,state=phase or BEGAN,x=item.x+(x or 0),y=item.y+(y or 0)})
end
local function button(page,id)
    for _,item in ipairs(PolyLax.Style.screenLayout(page).buttons) do if item.id==id then return item end end
    error('Missing style button '..id)
end
setup(); draw()
local s=assert(up(up(draw,'runFrame'),'state'))
assert(s.page=='FRONT')
tap(button(s.page,'SETTINGS')); draw()
assert(s.page=='CLUBS' and s.clubView=='SETTINGS')
tap(PolyLax.ClubsUI.layout('SETTINGS',s.clubs).byId.CREATOR); draw()
assert(s.page=='CREATOR' and s.creator.rig.root.active)
local rig=s.creator.rig.root
for i=1,#PolyLax.Profile.categories do
    tap(s.layout.categories[i]); tap(s.layout.right); draw()
    assert(s.creator.rig.root==rig)
end
tap(s.layout.home); draw()
assert(s.page=='FRONT')
tap(button(s.page,'MODES')); draw()
assert(s.page=='MODES')
tap(button(s.page,'PRACTICE')); draw()
assert(s.page=='PRACTICE' and #s.practice.game.squad==6)
local hud=s.layout
local clock=s.practice.game.clock
tap(hud.pause); draw()
assert(s.page=='PAUSE')
for i=1,8 do draw() end
assert(s.practice.game.clock==clock)
tap(button(s.page,'RESUME')); draw()
assert(s.page=='PRACTICE' and s.practice.game.clock<clock)
local j={x=hud.joyX,y=hud.joyY}
tap(j,2,BEGAN,1,1)
assert(s.joystick and s.moveX==0 and s.moveZ==0)
tap(j,2,MOVING,12,70)
assert(s.moveZ>.9)
tap(hud.primaryA,3)
assert(s.passAim and s.joystick and s.moveZ>.9)
tap(hud.primaryA,3,CANCELLED)
assert(not s.passAim and s.joystick)
draw()
assert(s.nubZ>0)
tap(j,2,ENDED)
assert(s.moveZ==0 and not s.joystick)
for i=1,24 do draw() end
assert(s.nubZ<.001)
print('Front, mode chooser, preserved creator, pause/resume clock, joystick deadzone/recenter and simultaneous pass gesture passed.')
if PolyLax.Athlete then
    local stored
    json={encode=function(value) stored=value return 'app-save' end,decode=function()return stored end}
    function showKeyboard()end
    function hideKeyboard()end
    tap(s.layout.pause); draw()
    tap(button(s.page,'HOME')); draw()
    tap(button(s.page,'CAREER')); draw()
    local career=s.career
    local layout=PolyLax.CareerUI.layout(career,'profile')
    tap(layout.name); draw()
    assert(s.page=='CREATOR' and s.careerCreator and s.creator.rig.root==rig)
    local home=PolyLax.Athlete.uniform(career,false)
    local away=PolyLax.Athlete.uniform(career,true)
    assert(s.creator.rig.materials.jersey.diffuse==home.primary)
    tap(s.layout.fullGame); draw()
    assert(s.creator.rig.materials.jersey.diffuse==away.primary)
    tap(s.layout.categories[5]); draw()
    tap(s.layout.options[2]); draw()
    assert(career.team~=home.teamId and s.creator.rig.root==rig)
    tap(s.layout.categories[3]); draw()
    local scale=s.creator.rig.proportions.scale.y
    tap(s.layout.right); draw()
    assert(s.creator.rig.proportions.scale.y~=scale)
    tap(s.layout.categories[1]); draw()
    tap(s.layout.options[1]); assert(s.careerNamePart=='first')
    s.careerName='Riley'; keyboard('\n'); draw()
    assert(PolyLax.Athlete.names(career)=='Riley')
    tap(s.layout.home); draw(); assert(s.page=='CAREER')
    print('Career creator, kit preview, school selection, height and name editing passed.')
end
if PolyLax.Development then
    local career=s.career
    local hud=PolyLax.CareerUI.layout(career,'profile')
    tap(hud.development); draw()
    assert(s.page=='DEVELOPMENT')
    local D=PolyLax.Development
    local firstPage=D.layout(career,s.developmentPage)
    assert(firstPage.page==1 and not firstPage.previous.enabled and firstPage.next.enabled)
    local locked=firstPage.rows[1].upgrade
    assert(not locked.enabled and D.points(career)==0)
    local before=career.attributes[locked.id]
    tap(locked); draw()
    assert(career.attributes[locked.id]==before and D.points(career)==0)
    tap(firstPage.next); draw()
    local secondPage=D.layout(career,s.developmentPage)
    assert(secondPage.page==2 and secondPage.previous.enabled)
    tap(secondPage.previous); draw()
    assert(s.developmentPage==1)
    assert(D.reward(career,'test-objective',220,12))
    assert(not D.reward(career,'test-objective',220,12))
    local dk=D.layout(career,1)
    local item=dk.rows[1].upgrade
    local previous=career.attributes[item.id]
    local points=D.points(career)
    local cost=assert(PolyLax.Attributes.cost(career.attributes,item.id,career.position))
    tap(item); draw()
    assert(career.attributes[item.id]==previous+1 and D.points(career)==points-cost)
    local reloaded=PolyLax.Career.load()
    assert(reloaded.attributes[item.id]==previous+1 and D.points(reloaded)==points-cost)
    tap(dk.drill); draw()
    assert(s.page=='TRAINING' and s.training.game.clock<60 and s.training.game.clock>59)
    local game=s.training.game
    game.goals,game.passes,game.clock=1,2,0
    draw();draw()
    assert(D.claimed(career,s.training.rewardKey))
    tap(s.layout.edit);draw()
    assert(s.page=='DEVELOPMENT')
    print('Development rendering, paging, locked upgrades, exact skill point spend, reload, and drill rewards passed.')
end
if PolyLax.Statistics then
    local D=PolyLax.Development
    tap(D.layout(s.career,s.developmentPage).back);draw()
    local c=PolyLax.CareerUI.layout(s.career,'profile')
    local stats
    for _,item in ipairs(c.nav) do if item.id=='stats' then stats=item end end
    tap(assert(stats));draw()
    assert(s.careerView=='stats')
    tap(PolyLax.CareerUI.layout(s.career,'stats').back);draw()
    tap(button(s.page,'MODES'));draw()
    tap(button(s.page,'MATCH'));draw()
    -- Cinematic builds leave the gameplay HUD deferred until Skip.
    if s.match.presentation then PolyLax.Presentation.skip(s.match); draw() end
    local hdr=s.layout
    tap(hdr.pause);draw()
    local item
    for _,b in ipairs(PolyLax.Style.screenLayout('PAUSE',{statsEnabled=true}).buttons) do if b.id=='STATS' then item=b end end
    tap(assert(item));draw()
    assert(s.page=='STATS' and s.statView.summary.players['career-player'])
    local tick=s.match.game.clock
    for i=1,4 do draw() end
    assert(s.match.game.clock==tick)
    tap(PolyLax.StatsUI.layout(s.statView).close);draw()
    assert(s.page=='PAUSE')
    print('Career statistics navigation and live team/player statistics pause passed.')
end
if PolyLax.Presentation then
    tap(button(s.page,'HOME'));draw()
    tap(button(s.page,'CAREER'));draw()
    local nav=PolyLax.CareerUI.layout(s.career,'profile').nav
    for _,item in ipairs(nav) do if item.id=='awards' then tap(item) break end end
    draw()
    assert(s.careerView=='awards')
    local award=PolyLax.CareerUI.layout(s.career,'awards',nil,nil,1,nil,s.awardState).awards
    assert(award and not award.award.eligible)
    tap(award.buttons[2]);draw()
    assert(s.awardState.mode=='trophies')
    tap(PolyLax.CareerUI.layout(s.career,'awards').play);draw()
    local p=s.careerPlay
    assert(p and p.presentation.kind=='pregame')
    local initialClock=p.game.clock
    for i=1,8 do draw() end
    assert(p.game.clock==initialClock and p.presentation.time>0)
    tap(PolyLax.Presentation.skipBox()); draw()
    assert(not p.presentation)
    p.game.phase='GOAL'
    p.game.homeScore,p.game.lastGoalScorer,p.game.lastGoalTeam=1,4,1
    draw(); assert(p.presentation.kind=='goal')
    tap(PolyLax.Presentation.skipBox());draw()
    assert(not p.presentation)
    p.game.phase='FINAL'
    PolyLax.Statistics.finalize(p.game)
    draw()
    assert(p.recorded and p.presentation.kind=='postgame')
    tap(PolyLax.Presentation.skipBox());draw()
    assert(s.page=='STATS' and s.statView.summary.final)
    assert(s.career.games==1 and #s.career.seasonData.rounds>0)
    print('Awards routes, career fixture launch, skip, goal/postgame presentation, final box, and career result handoff passed.')
end
