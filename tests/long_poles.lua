-- From the repository root: lua tests/long_poles.lua [PolyLax.codea]
local source = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local tests = arg and arg[0] and arg[0]:match("^(.*[/])")
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
dofile(tests .. "craft_mock.lua")
for _, tab in ipairs({"Profile", "Character", "AnimationController", "Attributes", "Passing"}) do
    dofile(source .. "/" .. tab .. ".lua")
end
local C, A, Passing = PolyLax.Character, PolyLax.AnimationController, PolyLax.Passing

local scene = craft.scene()
local short, long, secondLong = C.new(scene), C.new(scene), C.new(scene)
local entityCount = #scene.entities
local shortShaft, shortTape = short.stickShaft.model, short.stickTape.model
assert(short.stickType == "short")
C.setStickType(long, "long")
C.setStickType(secondLong, "long")
assert(#scene.entities == entityCount and #long.stickParts == #short.stickParts)
assert(long.stickShaft.model == secondLong.stickShaft.model and long.stickTape.model == secondLong.stickTape.model)
assert(long.stickHead.model == short.stickHead.model and long.stickMesh.model == short.stickMesh.model)
assert(math.abs((long.pocket.position.y - short.pocket.position.y) - .46) < .001)
assert(long.stickHead.position.y == long.stickMesh.position.y)
local function extent(model)
    local low, high = math.huge, -math.huge
    for _, point in ipairs(model.positions) do low, high = math.min(low, point.y), math.max(high, point.y) end
    return high - low
end
assert(extent(long.stickShaft.model) >= extent(shortShaft) * 1.6)
C.setStickType(long, "short")
assert(long.stickShaft.model == shortShaft and long.stickTape.model == shortTape and long.pocket.position.y == .70)
C.setStickType(long, "long")
assert(#scene.entities == entityCount)

local maximumRightGripDistance, minimumScoopY = 0, math.huge
local function verifyGrip(rig, idle)
    local wrist = (rig.joints.rightWrist.worldPosition - rig.stickRoot.worldPosition):len()
    local other = (rig.joints.leftWrist.worldPosition - rig.lowerGrip.worldPosition):len()
    maximumRightGripDistance = math.max(maximumRightGripDistance, wrist)
    assert(wrist < .04, "upper hand detached")
    if idle then assert(other < .04, "lower hand detached at carry") end
    local a,b = C.stickSegment(rig)
    assert((rig.pocket.worldPosition - b):len() < .0001)
    assert((rig.stickRoot:inverseTransformPoint(b)-rig.stickRoot:inverseTransformPoint(a)):len() > 1.05)
    minimumScoopY = math.min(minimumScoopY,rig.stickHead:transformPoint(vec3(0,1.004,-.152)).y)

    -- Check the shaft against the torso core in body space throughout poses.
    local base = rig.body:inverseTransformPoint(rig.stickRoot:transformPoint(vec3(0,-1.36,0)))
    local tip = rig.body:inverseTransformPoint(rig.stickRoot:transformPoint(vec3(0,.879,0)))
    for i=0,32 do
        local point = base + (tip-base)*(i/32)
        local inside = point.y > .29 and point.y < .78 and math.abs(point.x)<.375 and math.abs(point.z)<.205
        assert(not inside,"long shaft crosses the torso core")
    end
end
for _, profile in ipairs({{BODY=1},{BODY=2},{BODY=3},{BODY=4}}) do
    C.apply(long,profile,"HELMET")
    assert(long.stickType == "long" and not long.stickShaft.active)
    C.apply(long,profile)
    assert(long.stickType == "long" and long.stickShaft.active)
    local anim = A.new(long)
    for _=1,90 do
        A.update(anim,1/60,{speed=5,possessed=true})
        verifyGrip(long,true)
    end
    for _, action in ipairs({"pokeCheckLong","slapCheckLong","pass","shoot","catch","scoop","dodge","protect"}) do
        assert(A.play(anim,action))
        local count=0
        for _=1,90 do
            local event=A.update(anim,1/60,{speed=3,possessed=true})
            if event then count=count+1 end
            verifyGrip(long)
        end
        assert(count == (A.clips[action].event and 1 or 0),action)
    end
end
assert(minimumScoopY >= -.05,"stick dipped too far beneath turf")

local feed = {squad = {{rig=short, x=0,z=0,speed=0,team=1}, {rig=long,x=0,z=0,speed=0,team=1}}}
local function testFeed(bearing)
    short.root.position = vec3(14 * math.cos(bearing), 0, 14 * math.sin(bearing))
    feed.squad[1].x, feed.squad[1].z = short.root.position.x, short.root.position.z
    A.new(short)
    local source = short.pocket.worldPosition
    local atan2 = math.atan2 or math.atan
    long.root.eulerAngles = vec3(0,math.deg(atan2(-source.x,-source.z)),0)
    local anim = A.new(long)
    local flight = Passing.launch(feed,{from=1,to=2})
    assert(A.play(anim,"catch"))
    assert(A.update(anim,A.clips.catch.eventTime)=="catch")
    local difference = (long.pocket.worldPosition-flight.point):len()
    assert(difference < .34,"predicted long pocket drifts from the authored catch pose")
    assert(Passing.canCatch(feed,flight,2,flight.point))
end
for angle=0,7 do testFeed(angle * math.pi / 4) end

print(("Shared mesh, pole swap, animated hand anchors, release/catch/scoop/check timing passed; max top grip gap %.4f, min scoop height %.4f"):format(maximumRightGripDistance,minimumScoopY))
