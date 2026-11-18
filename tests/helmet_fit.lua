-- From the repository root, run with Lua 5.4:
--   lua tests/helmet_fit.lua
local tests=(arg and arg[0] and arg[0]:match("^(.*[/])")) or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project=(arg and arg[1]) or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
dofile(tests.."craft_mock.lua")
for _,tab in ipairs({"Profile","Character","Athlete","CameraController","UI"}) do
    dofile(project.."/"..tab..".lua")
end

local P=PolyLax
local rig=P.Character.new(craft.scene())
local profile={FACE=2,HAIR=5,BEARD=1,HELMET=4,BODY=2}
P.Character.apply(rig,profile,"HELMET")
assert(rig.helmetRoot.parent==rig.head and #rig.helmetParts==5)
local crown,outerX,outerZ=-math.huge,0,math.huge
for _,part in ipairs(rig.helmetParts) do
    assert(part.parent==rig.helmetRoot and part.active)
    for _,point in ipairs(part.model.positions) do
        crown=math.max(crown,point.y)
        outerX=math.max(outerX,math.abs(point.x))
        outerZ=math.min(outerZ,point.z)
    end
end
assert(crown>=.42 and crown<=.51,"crown extends too far from the skull")
assert(outerX>=.33 and outerX<=.405,"helmet side clearance outside fitted range")
assert(outerZ>=-.47 and outerZ<=-.397,"incorrect visor or cage projection")

local rayOrigin=vec3(0,.067,.011)
local surface=rig.helmetParts[1].model
local backings=rig.helmetParts[3].model
local function firstSurface(model,direction)
    local distance=math.huge
    for i=1,#model.indices,6 do
        local a=model.positions[model.indices[i]]
        local u=model.positions[model.indices[i+1]]-a
        local v=model.positions[model.indices[i+2]]-a
        local normal=direction:cross(v)
        local det=u:dot(normal)
        if math.abs(det)>1e-9 then
            local offset=rayOrigin-a
            local q=offset:cross(u)
            local x,y=offset:dot(normal)/det,direction:dot(q)/det
            local t=v:dot(q)/det
            if x>=-1e-6 and y>=-1e-6 and x+y<=1.000001 and t>0 then
                distance=math.min(distance,t)
            end
        end
    end
    return distance
end
local samples,covered=0,0
for _,part in ipairs(rig.scene.entities) do
    if part.parent==rig.head and part.model and part.material==rig.materials.skin then
        for _,point in ipairs(part.model.positions) do
            if point.y>.28 or point.z>.12 and point.y>-.10 then
                samples=samples+1
                local direction=point-rayOrigin
                local t=math.min(firstSurface(surface,direction),firstSurface(backings,direction))
                assert(t>=.996,"shell or vent liner clips the crown or rear skull")
                if t<math.huge then covered=covered+1 end
            end
        end
    end
end
assert(samples>0 and covered>=samples*.94,"uncovered crown or rear skull")

local camera=P.CameraController.new(rig.scene,34)
for _,size in ipairs({{320,568},{390,844},{430,932}}) do
    WIDTH,HEIGHT=size[1],size[2]
    local frame=P.UI.creatorLayout(P.Profile.categories).frame
    for build=1,4 do
        profile.BODY=build
        for _,height in ipairs({1,10,19}) do
            profile.HEIGHT=height
            for yaw=0,315,45 do
                rig.root.eulerAngles=vec3(0,yaw,0)
                P.Character.apply(rig,profile,"HELMET")
                P.CameraController.preview(camera,rig,"HELMET",frame,2)
                for _,part in ipairs(rig.helmetParts) do
                    for _,point in ipairs(part.model.positions) do
                        local screen=assert(P.CameraController.project(camera,part:transformPoint(point)))
                        assert(screen.y>=frame.bottom-1 and screen.y<=frame.top+1
                            and screen.x>=0 and screen.x<=WIDTH,"helmet cropped in portrait")
                    end
                end
            end
        end
    end
end
P.Character.apply(rig,profile,"HAIR")
for _,part in ipairs(rig.helmetParts) do assert(not part.active) end
assert(rig.hairParts[profile.HAIR].active)
profile.HELMET=8
P.Character.apply(rig,profile,"HELMET")
assert(rig.chromeFinish and not rig.hairParts[profile.HAIR].active)
print("Helmet shell clearance, portrait framing, and customization toggles passed.")
