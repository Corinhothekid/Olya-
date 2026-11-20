-- From the repository root: lua tests/clubs_local.lua [PolyLax.codea]
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local mock = dofile(tests.."craft_mock.lua")
for _, name in ipairs({"stroke","strokeWidth","noFill","line","textWrapWidth","showKeyboard","hideKeyboard"}) do
    _G[name]=function() end
end
function background(...)
    assert(select('#',...)<3,"Unexpected Codea draw failure")
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for k,v in pairs(value) do result[k]=copy(v) end
    return result
end
local records={}
json={encode=function(value)
    records[#records+1]=copy(value)
    return tostring(#records)
end,decode=function(id) return copy(records[tonumber(id)]) end}
local combined=os.getenv("POLYLAX_TEST_DELIVERABLE")
if combined then
    dofile(combined)
else
    local plist=assert(io.open(project.."/Info.plist"))
    local contents=plist:read("*a")
    plist:close()
    for tab in contents:gmatch("<string>([%w_]+)</string>") do dofile(project.."/"..tab..".lua") end
end

local P=PolyLax
local solo=P.Career.new()
solo.name,solo.xp="Solo Athlete",80
assert(P.Career.save(solo))
local soloSave=mock.store["PolyLax.Career.1"]
local function upvalue(fn,key)
    local index=1
    while true do
        local name,value=debug.getupvalue(fn,index)
        if name==key then return value end
        if not name then return end
        index=index+1
    end
end
setup(); draw()
local s=assert(upvalue(upvalue(draw,"runFrame"),"state"))
local function tap(button)
    assert(button and button.enabled~=false)
    touched({id=1,state=BEGAN,x=button.x,y=button.y})
    draw()
end
local function club(id)
    tap(P.ClubsUI.layout(s.clubView,s.clubs,{page=s.clubPage}).byId[id])
end
local home=P.Style.screenLayout("FRONT").byId
assert(home.MODES.label=="Quick Play" and home.CAREER.label=="Be a Pro" and home.CLUBS and home.SETTINGS)
tap(home.CLUBS)
local id=s.clubs.player.id
assert(id and s.career.name=="Solo Athlete")
club("MY_PLAYER")
assert(s.page=="CREATOR" and s.clubsCreator and not s.careerCreator)
tap(s.layout.options[1])
s.careerName="Relay"
keyboard("\n"); draw()
tap(s.layout.categories[2])
for _=1,4 do tap(s.layout.right) end
assert(s.clubs.player.position==6 and s.creator.rig.stickType=="long")
tap(s.layout.categories[6]); tap(s.layout.right)
assert(P.Athlete.profile(s.clubs.player).NUMBER==5)
tap(s.layout.home)
assert(s.page=="CLUBS" and s.clubView=="CLUBS")
club("CREATE")
club("EDIT_NAME")
for c in ("River Club"):gmatch(".") do keyboard(c) end
keyboard("\n")
club("NEXT_STAGE"); club("NEXT_STAGE"); club("NEXT_TEAM")
club("SAVE_CLUB")
assert(s.clubView=="LOBBY" and s.clubs.club.name=="River Club" and s.clubs.club.stage=="professional")
assert(not P.ClubsUI.layout("LOBBY",s.clubs).byId.HOST_ONLINE.enabled)
assert(#P.Clubs.roster(s.clubs)==10 and #P.Clubs.schedule(s.clubs)>0)
club("BACK"); club("ROSTER"); club("BACK"); club("SCHEDULE"); club("BACK")
club("DEVELOPMENT")
local row=P.Development.layout(s.clubs.player,1).rows[1]
local balance=P.Development.points(s.clubs.player)
tap(row.upgrade)
assert(s.clubs.player.attributes[row.key]==row.rating+1 and P.Development.points(s.clubs.player)<balance)
tap(P.Development.layout(s.clubs.player,1).back)
club("JOIN")
assert(not P.ClubsUI.layout("JOIN",s.clubs).byId.CONNECT.enabled)
club("BACK"); club("BACK")
local restored=P.Clubs.load()
assert(restored.player.id==id and P.Athlete.names(restored.player)=="Relay")
assert(restored.club.team==s.clubs.club.team and mock.store["PolyLax.Career.1"]==soloSave)
assert(P.Career.load().name=="Solo Athlete" and P.Career.load().xp==80)
print("Clubs menu, independent athlete, kit, club setup, roster, schedule, skill spend and isolated reload passed.")
