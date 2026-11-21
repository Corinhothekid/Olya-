-- Run from the repository root with lua tests/ultimate_sbc.lua.
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local tests = (arg and arg[0] and arg[0]:match("^(.*[/])"))
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests.."craft_mock.lua")
for _, name in ipairs({"stroke","strokeWidth","noFill","line","background"}) do
    _G[name] = function() end
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end
local saves = {}
json = {
    encode=function(value)
        saves[#saves+1] = copy(value)
        return tostring(#saves)
    end,
    decode=function(id) return copy(saves[tonumber(id)]) end
}
for _, tab in ipairs({"UI","Style","UltimateCatalog","Ultimate","UltimateEconomy","UltimateSBC","UltimateSBCUI"}) do
    dofile(project.."/"..tab..".lua")
end

local U = PolyLax.Ultimate
local SBC, screen = U.SBC, U.SBCUI
local profile = U.defaultCollection()
local function mint(collection, id)
    local ok, uid = U.addCard(collection,id)
    assert(ok,uid)
    return uid
end
local first = mint(profile,"pll_sowers_2026")
local copyOfFirst = mint(profile,"pll_sowers_2026")
local keeper = mint(profile,"box_mikael_dunn")
assert(first~=copyOfFirst)
assert(U.equip(profile,1,first))
assert(U.equip(profile,10,keeper))

local initial = profile.coins
local function rejects(id, cards)
    assert(not SBC.submit(profile,id,cards))
    assert(profile.coins==initial and profile.unopenedPacks==0)
    assert(profile.squad[1]==first and profile.squad[10]==keeper)
    assert(#U.ownedCards(profile)==3)
end
rejects("starter_exchange",{first,first})
rejects("starter_exchange",{[1]=first,[3]=copyOfFirst})
rejects("starter_exchange",{first,copyOfFirst,keeper})
rejects("starter_exchange",{first,"research_pll_1"})
rejects("field_specialists",{first,copyOfFirst,keeper})
assert(SBC.validate(profile,"starter_exchange",{first,copyOfFirst}))

-- A failed save leaves consumed cards, the lineup and rewards exactly as before.
local normalSave = saveLocalData
saveLocalData = function() error("test write failure") end
rejects("starter_exchange",{first,copyOfFirst})
saveLocalData = normalSave

local function tap(state, element)
    return screen.touch(state,{state=BEGAN,x=element.x,y=element.y,id=1})
end
for _, size in ipairs({{320,568},{393,852}}) do
    WIDTH,HEIGHT = size[1],size[2]
    layout = {safeArea={top=44,bottom=34,left=0,right=0}}
    local state = screen.new(profile)
    for index, challenge in ipairs(SBC.challenges) do
        local geometry = screen.draw(state,1/60)
        assert(state.challenge==index and #geometry.slots==challenge.slots)
        assert(geometry.confirm.x-geometry.confirm.w/2>geometry.review.x+geometry.review.w/2)
        for _, slot in ipairs(geometry.slots) do
            assert(slot.y-slot.h/2>geometry.field.y-geometry.field.h/2)
            assert(slot.y+slot.h/2<geometry.field.y+geometry.field.h/2)
        end
        assert(tap(state,geometry.next)=="next")
    end
    assert(state.challenge==1)
    assert(tap(state,screen.layout(state).slots[1])=="picker")
    local function select(uid)
        for i, entry in ipairs(state.options) do
            if entry.uid==uid then
                assert(tap(state,screen.draw(state,1/60).pageItems[i])=="selected")
                return
            end
        end
        error("Missing card "..uid)
    end
    select(first)
    assert(tap(state,screen.layout(state).slots[2])=="picker")
    for _, entry in ipairs(state.options) do assert(entry.uid~=first) end
    select(copyOfFirst)
    local form = screen.draw(state,1/60)
    assert(tap(state,form.review)=="review")
    assert(profile.coins==initial and #U.ownedCards(profile)==3)
    assert(not tap(state,form.review)) -- Same tap can never confirm the exchange.
    local review = screen.draw(state,1/60)
    assert(tap(state,review.cancel)=="field")
    assert(profile.coins==initial and #U.ownedCards(profile)==3)
    assert(tap(state,form.review)=="review")
    if size[1]==393 then
        assert(tap(state,screen.layout(state).confirm)=="completed")
        assert(tap(state,screen.layout(state).review)==nil)
        assert(tap(state,screen.layout(state).back)=="back")
    end
end

assert(profile.coins==initial+250 and profile.unopenedPacks==1)
assert(profile.completedSBC.starter_exchange and profile.squad[1]==nil and profile.squad[10]==keeper)
assert(not U.resolveCard(profile,first) and not U.resolveCard(profile,copyOfFirst))
assert(#U.ownedCards(profile)==1)
assert(not SBC.submit(profile,"starter_exchange",{keeper,keeper}))
local restored = U.load()
assert(restored.completedSBC.starter_exchange and restored.coins==profile.coins)
assert(restored.unopenedPacks==1 and restored.squad[10]==keeper and #U.ownedCards(restored)==1)

local byLeague = {}
for _, player in ipairs(U.players) do
    byLeague[player.league] = byLeague[player.league] or {}
    local team = byLeague[player.league]
    team[#team+1] = player.id
end
local leagues = {"PLL","MLL","NLL"}
for _, challenge in ipairs(SBC.challenges) do
    local challenger, cards, previous = U.defaultCollection(), {}, {}
    for slot=1,challenge.slots do
        local league = challenge.rules.league or leagues[(slot-1)%#leagues+1]
        local copyIndex = (previous[league] or 0)+1
        previous[league] = copyIndex
        local cardId = assert(byLeague[league] and byLeague[league][copyIndex])
        cards[slot] = mint(challenger,cardId)
    end
    local submitted, reward = SBC.submit(challenger,challenge.id,cards)
    assert(submitted,challenge.id)
    assert(reward.coins==challenge.reward.coins and reward.packs==challenge.reward.pack)
    assert(#U.ownedCards(challenger)==0 and challenger.unopenedPacks==challenge.reward.pack)
    assert(not SBC.submit(challenger,challenge.id,cards))
    assert(challenger.coins==challenge.reward.coins and challenger.unopenedPacks==challenge.reward.pack)
end
print("Ultimate SBC passed instance validation, league rules, review/cancel, atomic rewards, rollback, and reload.")
