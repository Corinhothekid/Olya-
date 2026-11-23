-- From the repository root: lua tests/road_gait.lua [PolyLax.codea]
local checks = os.getenv("POLYLAX_TEST_CHECKS")
    or (arg and arg[0] and arg[0]:match("^(.*[/])")) or "tests/"
local project = (arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(checks .. "/craft_mock.lua")
for _, tab in ipairs({"CampusPeople", "CraftPalette","CampusHumanMeshes", "CampusCharacter", "CampusMotion"}) do
    dofile(project .. "/" .. tab .. ".lua")
end

local People = PolyLax.CampusPeople
local Character = PolyLax.CampusCharacter
local Motion = PolyLax.CampusMotion
local dt = 1 / 60

local player = People.player({BODY=4, FACE=3, HAIR=4})
player.shirt, player.trim = {128, 82, 76}, {187, 134, 123}
player.pants, player.shoe = {37, 43, 52}, {223, 225, 218}
player.pack, player.backpackStyle = {58, 72, 96}, "campus"

local function checkTravel(look, speed, mode)
    local rig = Character.new(craft.scene(), look)
    local state = Motion.new(rig, look.motion, People.seed(look.id))
    local feet, phases, soles = {}, {}, {}
    local plantedFrames, oppositeArms = 0, 0
    local kneeBend, swingRise, slip, groundError = 0, 0, 0, 0
    local floor = rig.ankles[1].worldPosition.y
    for leg = 1, 2 do
        for _, vertex in ipairs(rig.feet[leg].model.positions) do
            if not soles[leg] or vertex.y < soles[leg].y then soles[leg] = vertex end
        end
        assert(soles[leg], "The articulated ankle is missing its shoe sole")
    end
    for tick = 1, 330 do
        Motion.update(state, dt, mode, speed)
        rig.root.position = vec3(0, state.bob, -tick * speed * dt)
        for leg = 1, 2 do
            local foot = rig.ankles[leg].worldPosition
            local phase = (state.phase + (leg-1)*.5) % 1
            if tick > 120 then
                -- This measures world position along a straight path while the
                -- same foot remains planted between frames.
                if phase < state.duty and phases[leg] < state.duty and phase >= phases[leg] then
                    plantedFrames = plantedFrames + 1
                    slip = math.max(slip, math.abs(foot.z - feet[leg].z))
                    local soleY = rig.feet[leg]:transformPoint(soles[leg]).y
                    groundError = math.max(groundError, math.abs(soleY))
                end
                kneeBend = math.max(kneeBend, -state.knees[leg])
                swingRise = math.max(swingRise, foot.y - floor)
            end
            feet[leg], phases[leg] = foot, phase
        end
        if tick > 120 and state.arms[1]*state.arms[2] < -1 then
            oppositeArms = oppositeArms + 1
        end
    end

    local context = look.id .. " " .. mode
    assert(plantedFrames > 65, context .. " lacks stance intervals")
    assert(slip < .003, context .. " drags its planted foot " .. slip)
    assert(groundError < .002, context .. " moves planted foot away from ground " .. groundError)
    assert(kneeBend > 28 and swingRise > .08, context .. " fails to flex and clear the foot")
    assert(oppositeArms > 130, context .. " is missing reciprocal arm swing")
    local phase = state.phase
    for _ = 1, 60 do Motion.update(state, dt, "idle", 0) end
    assert(state.phase == phase and math.abs(state.bob) < .001 and state.walking < .001,
        context .. " does not settle at rest")
    return swingRise, kneeBend
end

checkTravel(People.named("coach"), .48, "walk")
checkTravel(People.named("ethan"), .80, "walk")
local walkRise, walkKnee = checkTravel(player, 2.7, "walk")
local runRise, runKnee = checkTravel(player, 5.7, "run")
assert(runRise > walkRise + .10 and runKnee > walkKnee + 12,
    "The running pose needs greater foot clearance and knee flex than the walk")
print("Campus player and NPC gaits passed plant, swing, knee, arm opposition, and movement stop checks.")
