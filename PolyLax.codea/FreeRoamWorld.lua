-- Road to Glory campus geometry, authored locations, and lightweight collision.
PolyLax = PolyLax or {}
local P = PolyLax
local World = {}
P.FreeRoamWorld = World

local zones = {
    campus={label="Briarbank High",x=0,z=9,yaw=0,minX=-23,maxX=23,minZ=-28,maxZ=19,
        blocks={{-5.75,5.75,-15.75,-10.25,5.7},{-13.2,-6.8,-8.4,-4.2,4.2},
            {6.8,13.2,-8.4,-4.2,4.2},{-14.4,-7.6,5.25,9.85,4.5},
            {7.6,14.4,5.25,9.85,4.5},{-1.10,1.10,-25.8,-24.55,1.9},
            {-1.28,1.28,-.7,1.02,.54},
            {-17.5,-16.5,-4.5,-3.5,3},{16.5,17.5,-4.5,-3.5,3}}},
    school={label="School Hall",x=0,z=3.2,yaw=0,
        blocks={{4.65,6.62,-.6,.6,4},{-5.15,-2.45,1.34,1.87,.96}}},
    lockers={label="Varsity and JV Locker Rooms",x=0,z=3.2,yaw=0,
        blocks={{-6.85,-5.75,-4.6,1.25,3},{5.75,6.85,-4.6,1.25,3},
            {-2.25,-.9,-1.35,-.6,.9},{.9,2.25,-1.35,-.6,.9}}},
    training={label="Weight Room",x=0,z=3.2,yaw=0,
        blocks={{-5,-2.35,-3.9,-2.5,2.5},{2.35,5,-3.9,-2.5,2.5}}},
    coach={label="Coach's Office",x=0,z=3.2,yaw=0,
        blocks={{-2,2,-3.95,-2.65,1.2},{-6.75,-5.85,-4.2,-1.15,2.6}}},
    drip={label="Drip Lab",x=0,z=3.2,yaw=0,
        blocks={{-6.75,-5.25,-4.35,1.7,2.35},{5.25,6.75,-4.35,1.7,2.35}}},
    clubhouse={label="Pro Clubs Clubhouse",x=0,z=3.2,yaw=0,
        blocks={{-5.8,-3.1,-2.4,-.1,1.5},{3.1,5.8,-2.4,-.1,1.5},{-.91,.91,-4.68,-3.93,1.68}}}
}
local campusObstacles = zones.campus.blocks
for _,side in ipairs({-1,1}) do
    local function obstacle(x,z,width,depth,height)
        campusObstacles[#campusObstacles+1] = {side*x-width*.5,side*x+width*.5,
            z-depth*.5,z+depth*.5,height}
    end
    obstacle(4.53,2.94,1.90,.55,.96)
    obstacle(4.05,8.05,.29,.29,2.75)
    obstacle(5.92,-3.6,.29,.29,2.75)
    obstacle(19.4,5.4,1.32,16,.70)
    for _,z in ipairs({-17.5,1.1,11.9,15.2}) do obstacle(17,z,.32,.32,2.9) end
    for _,z in ipairs({-22.7,-17.6,-12.4}) do obstacle(20.6,z,.32,.32,3.6) end
end
local roomWalls = {{-7.4,-6.8,-6.5,5.55,4.9},{6.8,7.4,-6.5,5.55,4.9},
    {-7.4,7.4,-6.5,-5.95,4.9},{-7.4,7.4,5.28,5.65,4.9}}
for _,zone in pairs(zones) do
    if not zone.minX then
        zone.minX,zone.maxX,zone.minZ,zone.maxZ = -6.8,6.8,-5.95,5.28
        for _,wall in ipairs(roomWalls) do zone.blocks[#zone.blocks+1] = wall end
    end
end

local contacts = {
    campus={
        {"ethan","Ethan Cole",-2.8,4.2,2.1}, {"jace","Jace Holloway",6.72,-17.18,2},
        {"door:school","Main School Building",0,-9.75,1.8,"school"},
        {"door:lockers","Varsity and JV Locker Rooms",-10,-3.72,1.8,"lockers"},
        {"door:training","Weight Room",10,-3.72,1.8,"training"},
        {"door:drip","Enter Drip Lab",-11,10.35,1.8,"drip"},
        {"door:clubhouse","Pro Clubs Clubhouse",11,10.35,1.8,"clubhouse"},
        {"practice","Lacrosse Practice Field",0,-17.25,2.3}
    },
    school={
        {"door:coach","Coach Mercer's Office",4.95,-1.15,1.8,"coach"},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",0,-8.4,180}
    },
    lockers={
        {"tryout","Lacrosse Tryouts",0,-3.35,2.25},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",-10,-2.35,180}
    },
    training={
        {"training","Training Station",0,-2.45,2.1},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",10,-2.35,180}
    },
    coach={
        {"coach","Coach Daniel Mercer",0,-1.48,2.05},
        {"door:school","Return to School Hall",0,4.75,1.75,"school",4.32,-2.05,90}
    },
    drip={
        {"drip","Shop and Customize",0,-2.05,2.3},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",-11,11.82,180}
    },
    clubhouse={
        {"clubs","Enter Pro Clubs",0,-2.7,2.35},
        {"door:campus","Return to Courtyard",0,4.75,1.75,"campus",11,11.82,180}
    }
}

local palette = {
    turf={73,112,74}, turfLight={71,134,89}, turfDark={59,113,76}, hedge={43,86,62},
    pine={43,100,72}, pineLight={66,127,82}, bark={111,78,62},
    brick={150,95,87}, redBrick={119,67,66}, stucco={196,190,171}, white={234,234,219},
    concrete={149,157,153}, road={77,84,83}, pavement={119,130,127}, glass={61,108,128,.22},
    navy={31,53,68}, dark={28,44,50}, metal={99,123,128,.48}, gold={221,162,78,.58},
    wood={158,110,72}, orange={217,99,64}, teal={60,144,132}, violet={114,97,146},
    light={242,217,155,.25}, rubber={54,61,61}, avatarPaint={255,255,255}
}
local swatches = {}
local V = vec3

local function material(key)
    local value = swatches[key]
    if not value then
        local spec = palette[key]
        local standard = asset and asset.builtin and asset.builtin.Materials
        value = craft.material(standard and standard.Standard or "Materials:Standard")
        value.diffuse = color(spec[1],spec[2],spec[3])
        value.roughness = spec[4] or .89
        swatches[key] = value
    end
    return value
end

local function quad(world,key,a,b,c,d)
    local mesh = world.meshes[key]
    if not mesh then
        mesh = {positions={},normals={},indices={}}
        world.meshes[key] = mesh
    end
    local vertices,normals,indices = mesh.positions,mesh.normals,mesh.indices
    local i,j = #vertices,#indices
    local n = (b-a):cross(c-a):normalize()
    vertices[i+1],vertices[i+2],vertices[i+3],vertices[i+4] = a,b,c,d
    normals[i+1],normals[i+2],normals[i+3],normals[i+4] = n,n,n,n
    indices[j+1],indices[j+2],indices[j+3],indices[j+4],indices[j+5],indices[j+6] = i+1,i+2,i+3,i+1,i+3,i+4
    indices[j+7],indices[j+8],indices[j+9],indices[j+10],indices[j+11],indices[j+12] = i+3,i+2,i+1,i+4,i+3,i+1
end

local function plane(world,key,x,z,w,d,y)
    local l,r,b,f = x-w*.5,x+w*.5,z-d*.5,z+d*.5
    quad(world,key,V(l,y,b),V(l,y,f),V(r,y,f),V(r,y,b))
end

local function box(world,key,x,y,z,w,h,d)
    local l,r,b,t,a,f = x-w*.5,x+w*.5,y-h*.5,y+h*.5,z-d*.5,z+d*.5
    local p,q,s,u = V(l,b,a),V(l,b,f),V(r,b,a),V(r,b,f)
    local w0,w1,w2,w3 = V(l,t,a),V(l,t,f),V(r,t,a),V(r,t,f)
    quad(world,key,w0,w1,w3,w2)
    quad(world,key,p,s,u,q)
    quad(world,key,p,q,w1,w0)
    quad(world,key,s,w2,w3,u)
    quad(world,key,q,u,w3,w1)
    quad(world,key,p,w0,w2,s)
end

local glyphs = {
    A={2,5,7,5,5}, B={6,5,6,5,6}, C={3,4,4,4,3}, D={6,5,5,5,6},
    E={7,4,6,4,7}, F={7,4,6,4,4}, G={3,4,5,5,3}, H={5,5,7,5,5},
    I={7,2,2,2,7}, J={1,1,1,5,2}, K={5,5,6,5,5}, L={4,4,4,4,7},
    M={5,7,7,5,5}, N={5,7,7,7,5}, O={2,5,5,5,2}, P={6,5,6,4,4},
    Q={2,5,5,7,3}, R={6,5,6,5,5}, S={3,4,2,1,6}, T={7,2,2,2,2},
    U={5,5,5,5,7}, V={5,5,5,5,2}, W={5,5,7,7,5}, X={5,5,2,5,5},
    Y={5,5,2,2,2}, Z={7,1,2,4,7}
}

local function sign(world,text,x,y,z,cell,ink)
    -- Signs are read from the +Z side of each facade.
    local start=x-(#text*4-1)*cell*.5
    for index=1,#text do
        local glyph=glyphs[text:sub(index,index)]
        if glyph then
            for row,mask in ipairs(glyph) do
                for col=0,2 do
                    if math.floor(mask/2^(2-col))%2==1 then
                        local left = start+((index-1)*4+col)*cell
                        local right = left+cell*.9
                        local top = y+(3-row)*cell
                        quad(world,ink,V(left,top,z),V(left,top-cell*.9,z),
                            V(right,top-cell*.9,z),V(right,top,z))
                    end
                end
            end
        end
    end
end

local function shopfront(world,x,z,w,d,h,title,facade,accent)
    local front=z+d*.5
    box(world,facade,x,h*.5,z,w,h,d)
    box(world,"navy",x,h+.035,z,w+.43,.29,d+.42)
    box(world,accent,x,h-.3,front+.045,w,.13,.1)
    box(world,"navy",x,1.07,front+.04,1.47,2.2,.1)
    box(world,"glass",x,1.26,front+.11,1.15,1.50,.10)
    box(world,"gold",x-.46,1.03,front+.18,.08,.14,.045)
    for _,side in ipairs({-1,1}) do
        local ix=x+side*w*.31
        box(world,"stucco",ix,1.66,front+.075,w*.29,1.34,.11)
        box(world,"glass",ix,1.66,front+.145,w*.252,1.08,.08)
        box(world,"metal",ix,1.66,front+.195,.06,1.09,.035)
    end
    box(world,"navy",x,h-.84,front+.12,w-.58,.7,.16)
    sign(world,title,x,h-.83,front+.207,math.min(.104,(w-.8)/(#title*4)),"white")
    box(world,accent,x,2.39,front+.28,2,.14,.62)
end

local function tree(world,x,z,h)
    box(world,"bark",x,h*.29,z,.32,h*.58,.32)
    for level=1,2 do
        local y=h*(level==1 and .28 or .51)
        local w=h*(level==1 and .34 or .26)
        local tip=V(x,y+h*.51,z)
        local near,far,left,right=V(x,y,z+w),V(x,y,z-w),V(x-w,y,z),V(x+w,y,z)
        local greens=level==1 and "pine" or "pineLight"
        -- A narrowed tip is closed with the same material as the bark-free crown.
        local cap=tip+V(.006,0,0)
        quad(world,greens,left,near,tip,cap)
        quad(world,greens,near,right,tip,cap)
        quad(world,greens,right,far,tip,cap)
        quad(world,greens,far,left,tip,cap)
    end
end

local function bench(world,x,z,w)
    box(world,"wood",x,.47,z,w,.15,.50)
    box(world,"wood",x,.81,z-.25,w,.28,.09)
    for _,side in ipairs({-1,1}) do
        box(world,"metal",x+side*w*.32,.24,z,.10,.48,.34)
    end
end

local function bollard(world,x,z)
    box(world,"metal",x,1.25,z,.10,2.50,.10)
    box(world,"navy",x,.13,z,.26,.26,.26)
    box(world,"light",x,2.53,z,.26,.26,.24)
    box(world,"navy",x,2.69,z,.31,.08,.30)
end

local function campus(world)
    plane(world,"turf",0,-4.5,66,65,-.045)
    plane(world,"road",0,17.5,47,5.6,-.012)
    for index=-7,7 do plane(world,"white",index*2.9,17.4,1.48,.06,.003) end
    plane(world,"concrete",0,12.6,32,2.5,-.005)
    plane(world,"pavement",0,3.1,10.7,11.6,-.003)
    plane(world,"concrete",0,-3.8,17.6,2.15,-.004)
    plane(world,"concrete",0,-6.5,3.18,9.3,-.006)
    for _,side in ipairs({-1,1}) do
        plane(world,"concrete",side*7.02,-14.05,2.32,18.4,-.008)
        plane(world,"stucco",side*11,11.3,3.18,3,-.001)
        plane(world,"pavement",side*10,-4.01,3.25,1.6,-.002)
        bench(world,side*4.53,2.95,1.90)
        bollard(world,side*4.05,8.05)
        bollard(world,side*5.92,-3.6)
        for _,z in ipairs({-17.5,-4,1.1,11.9,15.2}) do tree(world,side*17,z,2.8) end
        for _,z in ipairs({-22.7,-17.6,-12.4}) do tree(world,side*20.6,z,3.55) end
        box(world,"hedge",side*19.4,.33,5.4,1.32,.68,16)
    end
    box(world,"stucco",0,.24,.16,2.56,.48,1.70)
    box(world,"pine",0,.48,.16,2.32,.12,1.48)
    for _,side in ipairs({-1,1}) do tree(world,side*.67,.20,1.45) end
    shopfront(world,0,-13,11.5,5.5,5.32,"BRIARBANK HIGH","brick","gold")
    for _,side in ipairs({-1,1}) do
        box(world,"stucco",side*4.67,2.10,-10.07,.45,4.2,.42)
        for column=1,3 do
            box(world,"glass",side*(2.45+column*.84),3.18,-10.197,.67,.67,.11)
        end
    end
    shopfront(world,-10,-6.3,6.4,4.2,3.9,"LOCKER ROOMS","redBrick","teal")
    shopfront(world,10,-6.3,6.4,4.2,3.9,"TRAINING","stucco","orange")
    shopfront(world,-11,7.55,6.8,4.6,4.15,"DRIP LAB","dark","teal")
    shopfront(world,11,7.55,6.8,4.6,4.15,"PRO CLUBS","navy","gold")
    plane(world,"road",0,-21.5,14.1,11.2,-.025)
    for i=0,5 do
        plane(world,i%2==0 and "turfLight" or "turfDark",0,-25.7+i*1.70,11,1.7,-.014)
    end
    for _,side in ipairs({-1,1}) do
        plane(world,"white",side*5.15,-21.45,.09,9.9,.002)
        plane(world,"white",0,-21.45+side*4.95,10.32,.09,.002)
    end
    plane(world,"white",0,-19.5,10.32,.08,.002)
    box(world,"navy",0,1.83,-26.85,5.4,.82,.25)
    sign(world,"LACROSSE",0,1.85,-26.715,.114,"white")
    P.GoalPhysics.new(world.scene,{x=0,z=-24.55,attackSign=-1})
end

local function room(world,title,accent)
    plane(world,"concrete",0,-.22,14.5,12.65,-.035)
    plane(world,"pavement",0,-.16,7.8,10.55,-.027)
    box(world,"stucco",0,1.7,-6.19,14.15,3.4,.32)
    for _,side in ipairs({-1,1}) do
        box(world,"stucco",side*7,1.70,-.15,.30,3.40,11.85)
        box(world,accent,side*6.823,.63,-.15,.05,.78,11.85)
        for _,z in ipairs({-3.9,-.15,3.58}) do
            box(world,"glass",side*6.818,2.36,z,.045,.61,1.32)
        end
        box(world,"stucco",side*4.2,1.35,5.44,5.7,2.7,.26)
    end
    box(world,accent,0,.65,-6.015,13.8,.82,.05)
    box(world,"navy",0,2.81,-5.997,8.45,.84,.08)
    sign(world,title,0,2.85,-5.943,.11,"white")
    box(world,"navy",0,2.83,5.4,2.66,.36,.25)
    plane(world,accent,0,4.88,2.24,.16,-.014)
end

local function school(world)
    room(world,"SCHOOL HALL","gold")
    for _,side in ipairs({-1,1}) do
        for i=1,5 do
            local z=-4.85+(i-1)*.69
            box(world,"navy",side*6.64,1.02,z,.30,2.04,.66)
            box(world,"metal",side*6.472,1.18,z+.18,.06,.21,.06)
        end
    end
    box(world,"navy",5.28,1.10,0,1.36,2.20,.28)
    sign(world,"COACH",5.28,2.46,.155,.057,"navy")
    bench(world,-3.8,1.6,2.7)
end

local function lockers(world)
    room(world,"LOCKER ROOMS","teal")
    sign(world,"JV",-3.75,1.78,-5.938,.13,"navy")
    sign(world,"VARSITY",3.75,1.78,-5.938,.13,"navy")
    for _,side in ipairs({-1,1}) do
        for i=0,5 do
            local z=-4.2+i*.97
            box(world,side<0 and "navy" or "dark",side*6.33,1.27,z,.95,2.54,.88)
            box(world,"metal",side*5.831,1.39,z+.22,.046,.20,.09)
        end
        bench(world,side*1.56,-.98,1.34)
    end
    plane(world,"teal",0,-3.35,1.2,1.2,-.020)
end

local function training(world)
    room(world,"WEIGHT ROOM","orange")
    for _,side in ipairs({-1,1}) do
        local x=side*3.65
        plane(world,"rubber",x,-3.25,3.1,2,-.011)
        box(world,"rubber",x,.50,-3.25,1.75,.22,.58)
        box(world,"metal",x,.25,-3.25,.18,.50,.39)
        for _,post in ipairs({-1,1}) do
            box(world,"metal",x+post*1.1,.93,-3.52,.10,1.86,.12)
            box(world,"orange",x+post*.79,1.36,-3.52,.14,.38,.38)
        end
        box(world,"metal",x,1.36,-3.52,2.17,.06,.06)
    end
end

local function coach(world)
    room(world,"COACH MERCER","gold")
    box(world,"wood",0,.85,-3.29,3.95,.17,1.24)
    for _,side in ipairs({-1,1}) do box(world,"navy",side*1.65,.39,-3.29,.55,.78,1.08) end
    box(world,"navy",.78,.99,-3.31,.65,.16,.42)
    box(world,"white",-.71,.96,-3.22,.75,.02,.46)
    for _,level in ipairs({.35,1.15,1.94}) do
        box(world,"wood",-6.33,level,-2.68,.82,.11,3.16)
    end
    for _,z in ipairs({-3.75,-3.14,-2.15}) do
        box(world,"gold",-6.33,2.15,z,.34,.31,.28)
        box(world,"metal",-6.33,2.03,z,.40,.08,.38)
    end
end

local function drip(world)
    room(world,"DRIP LAB","teal")
    sign(world,"STICKS",-3.64,2.05,-5.944,.10,"navy")
    sign(world,"GLOVES",3.64,2.05,-5.944,.10,"navy")
    local options={"orange","teal","violet","gold","white"}
    for _,side in ipairs({-1,1}) do
        local x=side*5.94
        box(world,"navy",x,.75,-1.3,1.53,1.50,6.04)
        box(world,"glass",x,1.53,-1.3,1.55,.12,6.05)
        for i,ink in ipairs(options) do
            local z=-3.9+(i-1)*1.28
            if side<0 then
                box(world,ink,x,1.93,z,.08,.84,.08)
                box(world,ink,x,2.39,z,.10,.21,.22)
                box(world,"white",x,2.43,z+.06,.13,.04,.07)
            else
                box(world,ink,x-.22,1.69,z,.32,.23,.34)
                box(world,ink,x+.22,1.69,z,.32,.23,.34)
            end
        end
    end
    plane(world,"teal",0,-2.05,2.8,2.38,-.019)
end

local function clubhouse(world)
    room(world,"PRO CLUBS","gold")
    for _,side in ipairs({-1,1}) do
        box(world,"navy",side*4.47,.45,-1.25,2.61,.90,2.10)
        box(world,"teal",side*4.47,.92,-1.95,2.61,.55,.48)
        box(world,"gold",side*4.20,1.85,-5.893,1.18,1.26,.18)
        box(world,"navy",side*4.20,1.87,-5.778,.88,.90,.07)
    end
    box(world,"metal",0,.53,-4.3,1.34,1.06,.76)
    box(world,"navy",0,1.33,-4.23,1.81,.69,.20)
    box(world,"teal",0,1.32,-4.101,1.60,.49,.07)
    plane(world,"gold",0,-2.70,2.17,1.45,-.020)
end

local builders={campus=campus,school=school,lockers=lockers,training=training,
    coach=coach,drip=drip,clubhouse=clubhouse}

local function compile(world)
    local uv,white = vec2(0,0),color(255,255,255)
    for key,mesh in pairs(world.meshes) do
        local colors,uvs={},{}
        for i=1,#mesh.positions do colors[i],uvs[i]=white,uv end
        local model=craft.model()
        model.positions,model.normals,model.indices=mesh.positions,mesh.normals,mesh.indices
        model.colors,model.uvs=colors,uvs
        local entity=world.scene:entity()
        entity.model,entity.material=model,material(key)
    end
    world.meshes=nil
end

local npcPaths={
    ethan={{-2.8,4.2},{-3.25,3.70},{-2.9,2.55},{-2.55,3.4}},
    jace={{6.72,-17.18},{7.52,-17.30},{7.06,-18.18},{6.45,-17.79}},
    studentA={{-5.05,6.2},{-4.65,3.8},{-4.75,-.7},{-5.25,2.65}},
    studentB={{5.35,7.2},{3.8,6.6},{3.85,4.65},{5.8,5.6}},
    coach={{0,-1.48},{.78,-1.55},{.70,-.85},{.10,-.96}},
    drip={{0,-2.05},{.68,-2.60},{.86,-1.8},{.21,-1.38}}
}

local npcLooks = {
    ethan={height=1.02,width=.97,faceWidth=.98,faceHeight=1.04,skin={195,134,102},hair={86,47,33},haircut="sweep",
        shirt={40,102,91},trim={126,178,157},pants={48,67,86},shoe={230,232,221},outfit="hoodie"},
    jace={height=1.07,width=1.13,faceWidth=.97,faceHeight=1.01,skin={126,80,60},hair={26,23,24},haircut="crop",
        shirt={171,63,37},trim={237,218,172},pants={39,48,69},shoe={218,225,230},outfit="varsity"},
    coach={height=1.05,width=1.11,faceWidth=1.02,faceHeight=1.04,skin={200,148,111},hair={98,94,89},
        haircut="neat",beard=true,glasses=true,
        shirt={43,59,85},trim={150,166,179},pants={88,92,77},shoe={111,80,62},outfit="jacket"},
    drip={height=.96,width=.95,faceWidth=.98,faceHeight=1.04,skin={150,94,72},hair={41,29,35},
        haircut="bun",earrings=true,
        shirt={101,78,156},trim={241,160,100},pants={50,47,71},shoe={177,147,223},outfit="apron"},
    studentA={height=.95,width=.94,faceWidth=1.04,faceHeight=.97,skin={105,64,51},hair={29,24,28},
        haircut="bob",glasses=true,
        shirt={171,100,51},trim={230,187,99},pants={58,65,95},shoe={223,208,173},outfit="pack"},
    studentB={height=1.00,width=.94,faceWidth=.95,faceHeight=1.08,skin={224,169,130},hair={141,86,48},haircut="curls",
        shirt={103,63,79},trim={202,141,177},pants={62,77,74},shoe={204,224,219},outfit="pack"}
}
local npcAssets = {}
local limbModel
local neutral, eyeWhite, iris=color(255,255,255),color(248,239,223),color(44,33,30)
local sides = {-1,1}

local function dye(rgb)
    return color(rgb[1],rgb[2],rgb[3])
end

local function paintQuad(mesh,a,b,c,d,ink)
    local verts,indices=mesh.positions,mesh.indices
    local at, offset=#verts,#indices
    local normal=(b-a):cross(c-a):normalize()
    verts[at+1],verts[at+2],verts[at+3],verts[at+4]=a,b,c,d
    for k=at+1,at+4 do mesh.normals[k],mesh.colors[k]=normal,ink end
    indices[offset+1],indices[offset+2],indices[offset+3]=at+1,at+2,at+3
    indices[offset+4],indices[offset+5],indices[offset+6]=at+1,at+3,at+4
end

local function paintedModel(build)
    local mesh={positions={},normals={},indices={},colors={}}
    build(mesh)
    local uv,uvs=vec2(0,0),{}
    for i=1,#mesh.positions do uvs[i]=uv end
    local model=craft.model()
    model.positions,model.normals,model.indices=mesh.positions,mesh.normals,mesh.indices
    model.colors,model.uvs=mesh.colors,uvs
    return model
end

-- Rings give soft silhouettes and leave the face, clothing and hair in two draw calls.
local function loft(mesh, rings, sides, ink, x)
    local function point(row, i)
        local angle=math.pi*2*i/sides
        local forward=math.cos(angle)
        return V((x or 0)+row[2]*math.sin(angle),row[1]-(row[5] or 0)*(1-forward)*.5,
            (row[4] or 0)-row[3]*forward)
    end
    for i=1,#rings-1 do
        local lower,upper=rings[i],rings[i+1]
        for side=0,sides-1 do
            paintQuad(mesh,point(lower,side),point(upper,side),
                point(upper,side+1),point(lower,side+1),ink)
        end
    end
end

local function badge(mesh,x,y,z,w,h,d,ink)
    local first,last=x-w*.5,x+w*.5
    local low,high,front,back=y-h*.5,y+h*.5,z-d*.5,z+d*.5
    local a,b,c,e=V(first,low,front),V(last,low,front),V(last,high,front),V(first,high,front)
    local f,g,i,j=V(first,low,back),V(last,low,back),V(last,high,back),V(first,high,back)
    paintQuad(mesh,a,e,c,b,ink)
    paintQuad(mesh,f,g,i,j,ink)
    paintQuad(mesh,a,f,j,e,ink)
    paintQuad(mesh,b,c,i,g,ink)
    paintQuad(mesh,e,j,i,c,ink)
    paintQuad(mesh,a,b,g,f,ink)
end

local function smallOval(mesh,x,y,z,w,h,d,ink)
    loft(mesh,{{y-h*.5,.001,.001,z},{y-h*.24,w*.83,d*.82,z},
        {y,w,d,z},{y+h*.24,w*.83,d*.82,z},{y+h*.5,.001,.001,z}},8,ink,x)
end

local function faceModel(look)
    local skin,hair=dye(look.skin),dye(look.hair)
    local hairGlint=color(look.hair[1]+16,look.hair[2]+12,look.hair[3]+10)
    local lip=color(look.skin[1]*.62,look.skin[2]*.53,look.skin[3]*.55)
    return paintedModel(function(mesh)
        loft(mesh,{{-.19,.058,.07,.017},{-.16,.107,.112,.008},{-.082,.155,.135},
            {.026,.166,.151},{.097,.167,.146,.007},{.154,.140,.134,.013},
            {.181,.082,.080,.02},{.188,.002,.002,.023}},10,skin)
        for _,side in ipairs({-1,1}) do
            smallOval(mesh,side*.158,-.024,.014,.037,.090,.047,skin)
            smallOval(mesh,side*.070,.033,-.131,.045,.041,.018,eyeWhite)
            smallOval(mesh,side*.066,.031,-.148,.019,.039,.008,iris)
            badge(mesh,side*.072,.071,-.136,.064,.013,.018,hair)
        end
        smallOval(mesh,0,-.021,-.145,.027,.086,.031,skin)
        smallOval(mesh,0,-.079,-.134,.042,.015,.008,lip)
        local cut=look.haircut
        local drop=cut=="bob" and .231 or cut=="sweep" and .095 or cut=="neat" and .080 or .114
        local top=cut=="curls" and .238 or cut=="crop" and .207 or .225
        loft(mesh,{{.108,.170,.149,.010,drop},{.145,.171,.152,.011,drop*.39},
            {.183,.157,.133,.019},{top-.017,.092,.097,.011},{top,.001,.001,.009}},10,hair)
        if cut=="sweep" or cut=="neat" then
            smallOval(mesh,-.053,.146,-.106,.107,.114,.080,hair)
            smallOval(mesh,-.076,.192,-.081,.072,.045,.066,hairGlint)
        elseif cut=="curls" then
            for _,x in ipairs({-.093,.003,.091}) do
                smallOval(mesh,x,.204,-.048,.061,.081,.073,x==.003 and hairGlint or hair)
            end
        elseif cut=="bun" then
            smallOval(mesh,0,.120,.164,.086,.163,.086,hair)
            smallOval(mesh,-.074,.142,-.105,.077,.095,.066,hairGlint)
        elseif cut=="bob" then
            for _,side in ipairs({-1,1}) do
                smallOval(mesh,side*.138,-.025,.049,.053,.270,.113,hair)
            end
        end
        if look.beard then
            local beard=color(101,87,78)
            loft(mesh,{{-.187,.035,.043,-.043},{-.156,.098,.114,-.018},
                {-.115,.133,.135,.002},{-.092,.102,.089,.025}},8,beard)
            badge(mesh,0,-.064,-.142,.078,.016,.015,beard)
        end
        if look.glasses then
            local frame=color(59,51,48)
            for _,side in ipairs({-1,1}) do
                badge(mesh,side*.070,.063,-.148,.096,.012,.012,frame)
                badge(mesh,side*.070,.004,-.150,.096,.010,.014,frame)
                for _,endX in ipairs({.027,.111}) do
                    badge(mesh,side*endX,.035,-.145,.010,.056,.014,frame)
                end
                badge(mesh,side*.152,.048,-.070,.015,.013,.151,frame)
            end
            badge(mesh,0,.044,-.161,.045,.011,.011,frame)
        end
        if look.earrings then
            local gold=color(239,206,135)
            smallOval(mesh,-.163,-.072,-.005,.012,.034,.012,gold)
            smallOval(mesh,.163,-.072,-.005,.012,.034,.012,gold)
        end
    end)
end

local function costumeModel(look)
    local shirt,trim=dye(look.shirt),dye(look.trim)
    return paintedModel(function(mesh)
        loft(mesh,{{-.33,.18,.093},{-.309,.194,.119},{-.13,.197,.134},
            {.064,.244,.136},{.185,.251,.119},{.229,.163,.099},
            {.244,.087,.076},{.248,.065,.061}},10,shirt)
        if look.outfit=="hoodie" then
            smallOval(mesh,0,.202,.085,.150,.194,.089,shirt)
            badge(mesh,0,-.176,-.125,.245,.089,.025,trim)
            for _,side in ipairs({-1,1}) do
                badge(mesh,side*.043,.075,-.139,.010,.106,.012,trim)
            end
        elseif look.outfit=="pack" then
            smallOval(mesh,0,-.04,.155,.186,.441,.090,trim)
            for _,side in ipairs({-1,1}) do
                badge(mesh,side*.144,-.021,-.124,.037,.405,.029,trim)
            end
        elseif look.outfit=="apron" then
            badge(mesh,0,-.117,-.125,.267,.352,.026,trim)
            badge(mesh,0,-.187,-.141,.201,.018,.021,shirt)
        else
            badge(mesh,0,-.049,-.132,.014,.459,.018,trim)
            badge(mesh,0,.174,-.114,.117,.035,.027,trim)
            badge(mesh,.115,.061,-.130,.068,.041,.025,trim)
        end
    end)
end

local function avatarParts(id, look)
    if npcAssets[id] then return npcAssets[id] end
    local function fabric(rgb)
        local standard=asset and asset.builtin and asset.builtin.Materials
        local mat=craft.material(standard and standard.Standard or "Materials:Standard")
        mat.diffuse,mat.roughness=dye(rgb),.9
        return mat
    end
    local parts={face=faceModel(look),body=costumeModel(look),skin=fabric(look.skin),
        shirt=fabric(look.shirt),trim=fabric(look.trim),pants=fabric(look.pants),shoe=fabric(look.shoe)}
    npcAssets[id]=parts
    return parts
end

local function createAvatar(world,id,point)
    local scene=world.scene
    local root=scene:entity()
    local look=npcLooks[id]
    local pieces=avatarParts(id,look)
    limbModel=limbModel or paintedModel(function(mesh)
        loft(mesh,{{-.5,.29,.31},{-.416,.459,.461},{-.303,.49,.49},
            {.313,.5,.5},{.436,.454,.457},{.5,.29,.31}},8,neutral)
    end)
    local function part(mat,x,y,z,w,h,d,parent,model)
        local entity=scene:entity()
        entity.parent=parent or root
        entity.position=V(x,y,z)
        if mat then
            entity.model,entity.material=model or limbModel,mat
            entity.scale=V(w,h,d)
        end
        return entity
    end
    local route=npcPaths[id]
    root.position=V(route[1][1],0,route[1][2])
    root.scale=V(look.width,look.height,look.width)
    local ink=material("avatarPaint")
    local actor={id=id,root=root,route=route,point=point,arms={},elbows={},legs={},knees={},index=2,rest=2,
        x=route[1][1],z=route[1][2],yaw=180,gait=0,stride=0}
    part(ink,0,1.34,0,1,1,1,nil,pieces.body)
    part(pieces.pants,0,1.001,0,.369,.242,.270)
    part(pieces.skin,0,1.606,-.002,.147,.187,.159)
    actor.head=part(nil,0,1.779,-.007)
    part(ink,0,.071,0,look.faceWidth,look.faceHeight,1,actor.head,pieces.face)
    for i,side in ipairs({-1,1}) do
        local arm=part(nil,side*.235,1.498,0)
        local elbow=part(nil,side*.032,-.252,-.004,nil,nil,nil,arm)
        local leg=part(nil,side*.100,.942,0)
        local knee=part(nil,0,-.410,.008,nil,nil,nil,leg)
        local exposed=look.outfit=="varsity" or look.outfit=="apron"
        part(exposed and pieces.trim or pieces.shirt,side*.012,-.117,0,.159,.296,.174,arm)
        part(exposed and pieces.skin or pieces.shirt,0,-.109,0,.130,.242,.138,elbow)
        part(pieces.skin,0,-.268,-.005,.117,.141,.116,elbow)
        part(pieces.pants,0,-.166,0,.202,.416,.224,leg)
        part(look.outfit=="varsity" and pieces.skin or pieces.pants,0,-.187,0,.162,.411,.176,knee)
        part(pieces.shoe,0,-.427,-.056,.197,.139,.321,knee)
        part(material("rubber"),0,-.505,-.057,.201,.046,.323,knee)
        actor.arms[i],actor.legs[i]=arm,leg
        actor.elbows[i],actor.knees[i]=elbow,knee
    end
    root.eulerAngles=V(0,actor.yaw,0)
    world.actors[#world.actors+1]=actor
end

local function clear(zone,x,z,radius)
    if x<zone.minX+radius or x>zone.maxX-radius or z<zone.minZ+radius
        or z>zone.maxZ-radius then return false end
    for _,block in ipairs(zone.blocks) do
        if x>block[1]-radius and x<block[2]+radius and z>block[3]-radius
            and z<block[4]+radius then return false end
    end
    return true
end

local function finite(value)
    return type(value)=="number" and math.abs(value)<math.huge
end

function World.sanitize(zone,x,z)
    zone=zones[zone] and zone or "campus"
    local map=zones[zone]
    if not (finite(x) and finite(z) and clear(map,x,z,.34)) then x,z=map.x,map.z end
    return zone,x,z
end

function World.new(scene,zone)
    zone=zones[zone] and zone or "campus"
    local map=zones[zone]
    local world={scene=scene,zone=zone,name=map.label,spawn={x=map.x,z=map.z,yaw=map.yaw},
        map=map,hotspots={},actors={},elapsed=0,meshes={}}
    builders[zone](world)
    compile(world)
    for _,spec in ipairs(contacts[zone]) do
        local id,into=spec[1],spec[6]
        local point={id=id,label=spec[2],x=spec[3],z=spec[4],radius=spec[5],zone=into}
        if into then
            local destination=zones[into]
            point.spawnX,point.spawnZ,point.spawnYaw=spec[7] or destination.x,
                spec[8] or destination.z,spec[9] or destination.yaw
        end
        world.hotspots[#world.hotspots+1]=point
        if npcPaths[id] then createAvatar(world,id,point) end
    end
    if zone=="campus" then
        createAvatar(world,"studentA")
        createAvatar(world,"studentB")
    end
    return world
end

function World.anchors(world)
    return world.hotspots
end

function World.interaction(world,x,z)
    local nearest, distance
    for _,point in ipairs(world.hotspots) do
        local dx,dz=point.x-x,point.z-z
        local d=dx*dx+dz*dz
        if d<=point.radius*point.radius and (not distance or d<distance) then
            nearest,distance=point,d
        end
    end
    return nearest
end

function World.move(world,x,z,dx,dz,radius)
    radius=radius or .34
    local steps=math.max(1,math.ceil(math.max(math.abs(dx),math.abs(dz))/.24))
    local stepX,stepZ=dx/steps,dz/steps
    for _=1,steps do
        if clear(world.map,x+stepX,z,radius) then x=x+stepX end
        if clear(world.map,x,z+stepZ,radius) then z=z+stepZ end
    end
    return x,z
end

local function slab(start,delta,lo,hi,first,last)
    if math.abs(delta)<.00001 then
        if start>=lo and start<=hi then return first,last end
        return
    end
    local a,b=(lo-start)/delta,(hi-start)/delta
    if b<a then a,b=b,a end
    first,last=math.max(a,first),math.min(b,last)
    if first<=last then return first,last end
end

function World.camera(world,target,desired)
    local delta=desired-target
    local finish=1
    local r=.13
    for _,block in ipairs(world.map.blocks) do
        local first,last=slab(target.x,delta.x,block[1]-r,block[2]+r,0,finish)
        if first then first,last=slab(target.z,delta.z,block[3]-r,block[4]+r,first,last) end
        if first then first=slab(target.y,delta.y,-.2,block[5]+r,first,last) end
        if first then finish=math.min(finish,math.max(.07,first-.033)) end
    end
    return target+delta*finish
end

local function advanceActor(actor,dt,schedule,playerX,playerZ)
    local dx,dz=actor.x-playerX,actor.z-playerZ
    local distanceSq=dx*dx+dz*dz
    local nearby=distanceSq < 22*22
    actor.root.active=nearby
    if not nearby then return end
    local stride=0
    local point=actor.route[actor.index]
    -- Hold still briefly for dialogue, then return to the schedule route.
    if not actor.point or distanceSq>actor.point.radius^2 then
        actor.rest=actor.rest-dt
        if actor.rest<=0 then
            dx,dz=point[1]-actor.x,point[2]-actor.z
            local range=math.sqrt(dx*dx+dz*dz)
            if range<=.08 then
                if schedule=="EVENING" or schedule=="Evening" or schedule=="evening" then
                    actor.index=(actor.index+#actor.route-2)%#actor.route+1
                else
                    actor.index=actor.index%#actor.route+1
                end
                actor.rest=actor.point and 2.4 or .48
            else
                local scale=math.min(1,dt*(actor.point and .48 or .80)/range)
                actor.x,actor.z=actor.x+dx*scale,actor.z+dz*scale
                local facing=math.deg((math.atan2 or math.atan)(-dx,-dz))
                actor.yaw=actor.yaw+((facing-actor.yaw+180)%360-180)*math.min(1,dt*5)
                actor.gait=actor.gait+dt*7
                stride=math.sin(actor.gait)*16
            end
        end
    elseif distanceSq>.001 then
        local facing=math.deg((math.atan2 or math.atan)(dx,dz))
        actor.yaw=actor.yaw+((facing-actor.yaw+180)%360-180)*math.min(1,dt*5)
    end
    actor.stride=actor.stride+(stride-actor.stride)*math.min(1,dt*11)
    actor.root.position=V(actor.x,math.abs(actor.stride)*.0011,actor.z)
    actor.root.eulerAngles=V(0,actor.yaw,0)
    actor.head.eulerAngles=V(1.5+math.abs(actor.stride)*.085,0,actor.stride*.10)
    for i,side in ipairs(sides) do
        local step=actor.stride*-side
        actor.arms[i].eulerAngles=V(-step,0,side*7)
        actor.elbows[i].eulerAngles=V(9+math.max(0,-step)*.55,0,0)
        actor.legs[i].eulerAngles=V(step,0,0)
        actor.knees[i].eulerAngles=V(-math.max(0,-step)*.76,0,0)
    end
    if actor.point then actor.point.x,actor.point.z=actor.x,actor.z end
end

function World.update(world,dt,schedule,playerX,playerZ)
    world.elapsed=world.elapsed+dt
    if world.elapsed<1/15 then return end
    local step=math.min(world.elapsed,.12)
    world.elapsed=0
    for _,actor in ipairs(world.actors) do
        advanceActor(actor,step,schedule,playerX or world.spawn.x,playerZ or world.spawn.z)
    end
end
