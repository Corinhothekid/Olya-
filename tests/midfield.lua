-- Run from the repository root with Lua 5.4:
--   lua tests/midfield.lua [PolyLax.codea]
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local checks = arg and arg[0] and arg[0]:match("^(.*[/])")
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(checks.."craft_mock.lua")

local plist = assert(io.open(project.."/Info.plist"))
local orders = plist:read("*a")
plist:close()
for tab in orders:gmatch("<string>([%w_]+)</string>") do
    dofile(project.."/"..tab..".lua")
end

local P = PolyLax
local Midfield, Match = assert(P.Midfield), assert(P.FullMatch)
local dt = .035
local function direction(team) return team == 1 and -1 or 1 end

local function legal(match)
    for team=1,2 do
        local count = Midfield.counts(match,team)
        assert(count.valid and count.offense>=3 and count.defense>=4,
            ("Side %d has %d ahead and %d back during %s"):format(team,count.offense,count.defense,match.phase))
        assert(count.offense+count.defense==10)
        assert(Midfield.side(match,match.squad[match.keepers[team]])=="defense")
    end
end

local function fieldPlayer(match, team, slot)
    return match.squad[match.teams[team][slot]]
end

local function place(player, x, z)
    player.x,player.z,player.vx,player.vz,player.speed=x,z,0,0,0
    player.rig.root.position=vec3(x,0,z)
end

local function lineUp(match, homeOffense, awayOffense)
    for _,player in ipairs(match.squad) do
        local quota = player.team==1 and homeOffense or awayOffense
        local sign = player.slot<=quota and direction(player.team) or -direction(player.team)
        place(player,(player.slot-5)*2,sign*.34)
    end
    Midfield.reset(match)
    legal(match)
end

local function propose(match, targets, human, intent)
    local steps = {}
    for _,player in ipairs(match.squad) do
        local z = targets[player.id] or player.z
        local vz = player.id==human and intent or (z-player.z)/dt
        steps[player.id] = {x=player.x,z=z,intentZ=vz}
    end
    Midfield.resolve(match,steps,human,dt)
    for _,player in ipairs(match.squad) do
        local step=steps[player.id]
        assert(step.x==player.x,"the boundary moved a player sideways")
        place(player,step.x,step.z)
    end
    legal(match)
end

local profile = P.Profile.load()
local match = Match.new(craft.scene(),profile,1,2)
legal(match)
lineUp(match,3,6)
local attack = fieldPlayer(match,1,1)
local awayDefender = fieldPlayer(match,2,7)
propose(match,{[attack.id]=-.06},attack.id,4)
assert(match.positioning.level=="warning" and attack.z<0,"close illegal approach gave no warning")
propose(match,{[attack.id]=.24,[awayDefender.id]=.24},attack.id,4)
assert(match.positioning.level=="offsides" and match.positioning.notice=="OFFSIDES")
assert(match.positioning.blocked[attack.id] and match.positioning.blocked[awayDefender.id])
assert(math.abs(attack.z)<.013 and Midfield.side(match,attack)=="offense")
assert(math.abs(awayDefender.z)<.013 and Midfield.side(match,awayDefender)=="defense")
propose(match,{[attack.id]=0,[awayDefender.id]=0})
assert(Midfield.side(match,attack)=="offense" and Midfield.side(match,awayDefender)=="defense",
    "zero erased one player's prior side")

-- Resolve both directions together. Each switch is legal only if its partner
-- also crosses, including when the teams make exchanges in the same step.
lineUp(match,3,3)
local defender = fieldPlayer(match,1,7)
local awayAttack = fieldPlayer(match,2,1)
propose(match,{[attack.id]=.42,[defender.id]=-.42,[awayAttack.id]=-.42,[awayDefender.id]=.42},attack.id)
assert(Midfield.side(match,attack)=="defense" and Midfield.side(match,defender)=="offense")
assert(Midfield.side(match,awayAttack)=="defense" and Midfield.side(match,awayDefender)=="offense")
assert(not match.positioning.blocked[attack.id] and not match.positioning.blocked[awayDefender.id])

lineUp(match,4,4)
local goalie, awayGoalie = fieldPlayer(match,1,10),fieldPlayer(match,2,10)
propose(match,{[goalie.id]=-.47,[awayGoalie.id]=.47})
assert(match.positioning.blocked[goalie.id] and match.positioning.blocked[awayGoalie.id],
    "a keeper was allowed beyond midfield")

-- A substitute inherits the line side of the person stepping off. A swap to
-- the other half is allowed when the team can spare a player from that half.
lineUp(match,3,6)
for team=1,2 do
    local outgoing = fieldPlayer(match,team,team==1 and 1 or 7)
    local incoming = {role="M",team=team}
    local allowed, result = Midfield.canSubstitute(match,team,outgoing.id,incoming,0)
    assert(allowed and result.valid and result.offense==Midfield.counts(match,team).offense)
    local excluded, predicted, reason = Midfield.canSubstitute(match,team,outgoing.id,incoming,-outgoing.z)
    assert(not excluded and not predicted.valid and reason)
    local replacement = fieldPlayer(match,team,team==1 and 7 or 1)
    assert(Midfield.canSubstitute(match,team,replacement.id,incoming,-replacement.z))
end
legal(match)

local function runFrames(game, frames, moveX, moveZ)
    for _=1,frames do
        Match.update(game,dt,moveX or 0,moveZ or 0)
        legal(game)
    end
end

local function livePossession(game, owner, controlled)
    game.phase,game.carrier,game.controlled="LIVE",owner.id,controlled.id
    game.pending,game.flight,game.loose=nil,nil,nil
    P.AnimationController.reset(owner.anim)
    if owner~=controlled then P.AnimationController.reset(controlled.anim) end
    game.ball.position=owner.rig.pocket.worldPosition
end

local exhibition = Match.new(craft.scene(),profile,2,3)
runFrames(exhibition,24) -- Set and opening draw use their own control path.
runFrames(exhibition,150,.15,1)
lineUp(exhibition,4,4)
local owner, receiver = fieldPlayer(exhibition,1,1),fieldPlayer(exhibition,1,2)
livePossession(exhibition,owner,receiver)
Match.command(exhibition,"switch")
assert(exhibition.controlled==owner.id)
assert(Match.canAim(exhibition))
assert(Match.command(exhibition,"pass",0,0,receiver.id) and exhibition.pending.to==receiver.id)
runFrames(exhibition,24)
Match.command(exhibition,"reset")
assert(exhibition.phase=="FACEOFF" and exhibition.carrier==nil)
legal(exhibition)

lineUp(exhibition,6,6)
local nearerDefender = fieldPlayer(exhibition,1,7)
place(nearerDefender,exhibition.field.halfWidth-.9,.36)
Midfield.reset(exhibition)
exhibition.phase,exhibition.lastTouch,exhibition.loose="LIVE",2,true
exhibition.ball.position,exhibition.ballVelocity=vec3(exhibition.field.halfWidth+.1,.09,-.42),vec3()
runFrames(exhibition,1)
assert(exhibition.carrier and exhibition.carrier~=nearerDefender.id)
assert(Midfield.side(exhibition,exhibition.squad[exhibition.carrier])=="offense")

local career = Match.new(craft.scene(),profile,"briarbank","foxmere",{careerPlayerSlot=7,careerEntryDelay=0})
local locked = career.controlled
assert(locked==7)
runFrames(career,145,-.1,-1)
lineUp(career,4,4)
local defenderCareer = career.squad[locked]
livePossession(career,fieldPlayer(career,1,1),defenderCareer)
Match.command(career,"switch")
assert(career.controlled==locked,"midfield positioning broke career player lock")
local updateAI = P.MatchAI.update
P.MatchAI.update = function(game)
    local stationary = {}
    for _,player in ipairs(game.squad) do stationary[player.id]={x=player.x,z=player.z} end
    return stationary
end
runFrames(career,20,.1,1)
P.MatchAI.update = updateAI
assert(defenderCareer.z<0,"a career defenseman was barred from a legal clear")
print("Midfield role exchanges, both team limits, warnings, keeper, substitutions, exhibition controls and career player lock passed.")
