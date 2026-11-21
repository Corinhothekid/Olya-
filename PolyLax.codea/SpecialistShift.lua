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
