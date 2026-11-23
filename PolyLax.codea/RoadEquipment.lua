-- Road to Glory owns this wallet and its cosmetics independently of Ultimate Team.
PolyLax = PolyLax or {}
local P = PolyLax
local Equipment = {}
P.RoadEquipment = Equipment

local V = vec3
local sides = {"left","right"}
local twoPi = math.pi*2

local function hash(x,y)
    local n=math.sin(x*127.1+y*311.7)*43758.5453
    return n-math.floor(n)
end

local function camo(u,v)
    local value=math.sin(19*u+math.cos(12*v)*1.7)+math.cos(20*v+2.1*math.sin(8*u))
    return value>.5 and 3 or value<-.55 and 2 or 1
end

local function spot(u,v)
    local x,y=math.floor(u*7),math.floor(v*8)
    local dx,dy=u*7-x-.26-.40*hash(x,y),v*8-y-.26-.40*hash(y,x)
    local d=dx*dx+dy*dy
    return d<.035 and 1 or d<.085 and 2 or 3
end

local function stamp(u,v,bird)
    local x,y=u*3%1,v*4%1
    local body=((x-.43)/.28)^2+((y-.37)/.17)^2<1
    local head=(x-.64)^2+(y-.52)^2<.011
    if x>.70 and x<.89 and y>.49 and y<.56 then return 2 end
    if head or body or bird and x>.63 and x<.68 and y>.55 and y<.82 then return 3 end
    if not bird and x>.56 and x<.75 and y>.10 and y<.28 then return 2 end
    return 1
end

local patterns = {
    {name="Solid"},
    {name="Woodland Camo", colors={{32,49,32},{95,72,40},{111,139,75}}, sample=camo},
    {name="Snow Camo", colors={{215,230,240},{123,151,171},{245,249,251}}, sample=camo},
    {name="Digital Camo", colors={{36,51,46},{72,121,115},{191,196,152}}, sample=function(u,v)
        local n=hash(math.floor(u*11),math.floor(v*13))
        return n<.46 and 1 or n<.73 and 2 or 3
    end},
    {name="Zebra", colors={{233,239,244},{53,64,83},{17,24,36}}, sample=function(u,v)
        local stripe=math.sin(56*u+3.8*math.sin(11*v))
        return stripe>.34 and 3 or stripe>.16 and 2 or 1
    end},
    {name="Flamingo", colors={{34,61,76},{244,213,124},{250,128,178}}, sample=function(u,v)
        return stamp(u,v,true)
    end},
    {name="Leopard", colors={{39,29,23},{153,89,40},{229,170,87}}, sample=spot},
    {name="Tiger Stripes", colors={{239,101,34},{252,158,66},{22,28,33}}, sample=function(u,v)
        local stripe=math.sin(46*u+8*v+2.8*math.sin(10*v))
        return stripe>.58 and 3 or stripe>.31 and 2 or 1
    end},
    {name="Galaxy", colors={{22,22,62},{110,69,174},{187,211,247}}, sample=function(u,v)
        if hash(math.floor(u*27),math.floor(v*29))>.93 then return 3 end
        return math.sin(11*u+5*v+math.cos(v*12))>.29 and 2 or 1
    end},
    {name="Graffiti", colors={{34,31,50},{90,234,182},{246,79,157}}, sample=function(u,v)
        local s=math.sin(53*u+42*v)+math.sin(91*u-22*v)
        return s>1.11 and 3 or s<-.71 and 2 or 1
    end},
    {name="Electric Storm", colors={{25,32,75},{70,111,241},{143,238,255}}, sample=function(u,v)
        local line=math.abs((u+.48*v+.10*math.sin(math.floor(v*8)))% .32-.16)
        return line<.027 and 3 or line<.056 and 2 or 1
    end},
    {name="Retro 90s", colors={{58,35,127},{255,193,82},{48,219,201}}, sample=function(u,v)
        local a,b=u*5%1,v*5%1
        return a+b>.92 and a+b<1.24 and 3 or a>.78 and b>.62 and 2 or 1
    end},
    {name="Inferno Flames", colors={{41,25,32},{237,55,39},{255,181,66}}, sample=function(u,v)
        local s=v*3%1+.34*math.cos(41*u+5*v)+.12*math.sin(81*u)
        return s<.40 and 3 or s<.68 and 2 or 1
    end},
    {name="Rubber Ducks", colors={{38,142,175},{249,113,42},{255,216,77}}, sample=function(u,v)
        return stamp(u,v,false)
    end}
}
Equipment.patterns = patterns

local swatches = {
    {"Graphite",{40,53,67}},{"Pearl",{230,238,245}},{"Varsity Green",{39,115,88}},
    {"Cobalt",{45,99,190}},{"Crimson",{166,47,62}},{"Sunset",{231,143,55}},
    {"Lavender",{143,112,214}},{"Ice",{101,218,228}},{"Rose",{226,138,168}}
}
local colorNames, patternNames, gearPatterns = {}, {}, {}
for i,v in ipairs(swatches) do colorNames[i]=v[1] end
for i,v in ipairs(patterns) do patternNames[i],gearPatterns[i]=v.name,v.name end
local assetKeys = {"camo","ducky","galaxy","zebra"}
local assetLabels = {"Camo","Ducky","Galaxy","Zebra"}
local assetPatterns = {"Solid"}
for i,label in ipairs(assetLabels) do
    assetPatterns[i+1] = "Imported "..label
    gearPatterns[#patterns+i] = assetPatterns[i+1]
end

local sections = {
    {id="STICK",label="Stick",fields={
        {"shaftPattern","Shaft Pattern",gearPatterns,1,35},
        {"shaftColor","Shaft Color",colorNames,4,12},
        {"shaftModel","Shaft Model",{"Alloy","Slim","Reinforced"},1,20},
        {"shaftFinish","Shaft Finish",{"Satin","Matte","Polished"},1,24},
        {"gripColor","Grip Tape",colorNames,1,8},
        {"gripPattern","Grip Pattern",gearPatterns,1,18},
        {"headModel","Head Profile",{"Classic","Swept","Wide"},1,23},
        {"headColor","Head Color",colorNames,2,10},
        {"headPattern","Head Pattern",assetPatterns,1,25},
        {"meshPattern","Mesh Weave",{"Diamond","Cross-Lace","Two-Tone"},1,18},
        {"meshColor","Mesh Color",colorNames,2,8},
        {"pocketPattern","Pocket Pattern",assetPatterns,1,18},
        {"sidewallColor","Sidewall String",colorNames,1,8},
        {"topStringColor","Top String",colorNames,2,8},
        {"shootingStringColor","Shooting String",colorNames,2,8},
        {"pocket","Pocket Appearance",{"Mid Pocket","High Channel","Low Channel"},1,15}
    }},
    {id="GLOVES",label="Gloves",fields={
        {"gloveFinish","Glove Finish",{"Matte","Silver Chrome","Gold Chrome","Black Chrome","Rose-Gold Chrome","Iridescent Chrome"},1,42},
        {"gloveModel","Glove Model",{"Classic","Speed","Armor"},1,25},
        {"gloveColor","Primary Color",colorNames,2,12},
        {"gloveSecondary","Secondary Color",colorNames,1,9},
        {"gloveAccent","Accent Color",colorNames,3,9},
        {"gloveCuff","Cuff",{"Low","Flare","Shield"},1,20},
        {"glovePattern","Glove Pattern",gearPatterns,1,32}
    }},
    {id="SLEEVES",label="Sleeves",fields={
        {"leftSleeve","Left Sleeve",{"None","Lower Leg","Full"},1,15},
        {"leftSleevePattern","Left Pattern",gearPatterns,1,22},
        {"leftSleeveColor","Left Color",colorNames,1,9},
        {"rightSleeve","Right Sleeve",{"None","Lower Leg","Full"},1,15},
        {"rightSleevePattern","Right Pattern",gearPatterns,1,22},
        {"rightSleeveColor","Right Color",colorNames,1,9}
    }},
    {id="OUTFIT",label="Outfit",fields={
        {"hoodieColor","Hoodie Color",colorNames,3,12},
        {"hoodiePattern","Hoodie Pattern",patternNames,1,25},
        {"joggerColor","Jogger Color",colorNames,1,10},
        {"joggerPattern","Jogger Pattern",patternNames,1,25},
        {"sneaker","Sneakers",{"Court Low","High-Top","Street Trail"},1,25},
        {"sneakerColor","Sneaker Color",colorNames,2,10},
        {"backpackStyle","Backpack Style",{"Campus","Roll Top","Travel Pack"},1,25},
        {"backpackColor","Backpack Color",colorNames,1,10},
        {"backpackPattern","Backpack Pattern",patternNames,1,25}
    }},
    {id="PRESETS",label="Presets"}
}
Equipment.sections = sections
local fields = {}
for _,section in ipairs(sections) do
    for _,field in ipairs(section.fields or {}) do fields[field[1]]=field end
end
Equipment.fields = fields
Equipment.maxCredits = 999999

local function imported(option)
    return assetKeys[option-#patterns]
end

function Equipment.patternStatus(id,choice)
    local field = fields[id]
    if not (field and type(choice)=="number") then return end
    local key
    if field[3]==gearPatterns then key=imported(choice)
    elseif field[3]==assetPatterns then key=assetKeys[choice-1] end
    if key then return P.EquipmentTextures.status(key) end
end

local function integer(value,default,min,max)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return default end
    return math.max(min,math.min(max,math.floor(value)))
end

local function key(id,value) return id..":"..value end

function Equipment.owns(kit,id,value)
    local field=fields[id]
    return field~=nil and field[3][value]~=nil
        and (value==field[4] or kit.owned[key(id,value)]==true)
end

local function validateEquipped(kit,source)
    local result={}
    for id,field in pairs(fields) do
        local chosen=integer(source[id],field[4],1,#field[3])
        result[id]=Equipment.owns(kit,id,chosen) and chosen or field[4]
    end
    return result
end

function Equipment.restore(raw)
    if type(raw)~="table" then raw={} end
    local kit={version=1,credits=integer(raw.credits,240,0,Equipment.maxCredits),owned={},presets={}}
    local owned=type(raw.owned)=="table" and raw.owned or {}
    for id,field in pairs(fields) do
        for option=1,#field[3] do
            local code=key(id,option)
            if owned[code]==true then kit.owned[code]=true end
        end
    end
    kit.equipped=validateEquipped(kit,type(raw.equipped)=="table" and raw.equipped or {})
    if type(raw.presets)=="table" then
        for slot=1,3 do
            local data=raw.presets[tostring(slot)] or raw.presets[slot]
            if type(data)=="table" then kit.presets[tostring(slot)]=validateEquipped(kit,data) end
        end
    end
    return kit
end

function Equipment.change(kit,action,id,value)
    local nextKit=Equipment.restore(kit)
    local field=fields[id]
    if action=="savePreset" or action=="loadPreset" then
        if type(value)~="number" or value%1~=0 or value<1 or value>3 then return nil,"Choose a valid preset" end
        local slot=tostring(value)
        if action=="savePreset" then
            nextKit.presets[slot]=validateEquipped(nextKit,nextKit.equipped)
        elseif nextKit.presets[slot] then
            nextKit.equipped=validateEquipped(nextKit,nextKit.presets[slot])
        else
            return nil,"This preset is empty"
        end
        return nextKit
    end
    if not field or type(value)~="number" or not field[3][value] then return nil,"Choose an available option" end
    if action=="buy" then
        if Equipment.owns(nextKit,id,value) then return nil,"You already own this option" end
        if Equipment.patternStatus(id,value)==false then return nil,"Pattern asset unavailable" end
        if nextKit.credits<field[5] then return nil,"More credits needed" end
        nextKit.owned[key(id,value)]=true
        nextKit.credits=nextKit.credits-field[5]
    elseif action=="equip" then
        if not Equipment.owns(nextKit,id,value) then return nil,"Unlock this option first" end
        nextKit.equipped[id]=value
    else
        return nil,"Choose a valid action"
    end
    return nextKit
end

function Equipment.preview(kit,id,value)
    local preview=Equipment.restore(kit)
    if fields[id] and fields[id][3][value] then preview.equipped[id]=value end
    return preview
end

local function colorFromRGB(rgb)
    return color(rgb[1],rgb[2],rgb[3])
end

local function tint(i)
    return colorFromRGB(swatches[i][2])
end

-- Keep blending on the source palette. A Craft material can read back its diffuse
-- value in a native representation with different fields from a Codea color.
local function blendRGB(a,b,amount)
    return color(a[1]+(b[1]-a[1])*amount,
        a[2]+(b[2]-a[2])*amount,a[3]+(b[3]-a[3])*amount)
end

local blackRGB = {24,31,42}
local black, white = colorFromRGB(blackRGB), color(246,248,247)

local function entity(r,parent,x,y,z)
    local e=r.scene:entity()
    if parent then e.parent=parent end
    e.position=V(x or 0,y or 0,z or 0)
    return e
end

local function material(paint,roughness,metalness)
    local standard=asset and asset.builtin and asset.builtin.Materials
    local result=craft.material(standard and standard.Standard or "Materials:Standard")
    result.diffuse,result.roughness,result.metalness=paint,roughness or .88,metalness or .0
    return result
end

local cube
local function piece(r,parent,mat,x,y,z,w,h,d)
    local e=entity(r,parent,x,y,z)
    cube=cube or craft.model.cube()
    e.model,e.material,e.scale=cube,mat,V(w,h,d)
    return e
end

local meshCache, meshCount = {}, 0
local function mesh(shape,pattern,swatch)
    local signature=shape..":"..pattern..":"..swatch
    local cached=meshCache[signature]
    if cached then return cached[1],cached[2] end
    local record=patterns[pattern] or {}
    local base=swatches[swatch][2]
    local colors={}
    if record.colors then
        for i,components in ipairs(record.colors) do
            colors[i]=blendRGB(components,base,.25)
        end
    else
        colors[1]=pattern==0 and white or colorFromRGB(base)
    end
    local positions,normals,vertexColors,indices,uvs={},{},{},{},{}
    local radial=shape=="tube"
    local minX,minY=radial and 8 or 12,14
    local uv=vec2(0,0)
    for row=0,minY-1 do
        local l,h=row/minY,(row+1)/minY
        for col=0,minX-1 do
            local u,w=col/minX,(col+1)/minX
            local a,b,c,d,normal
            if radial then
                local first,last=u*twoPi,w*twoPi
                local x,z,nx,nz=math.cos(first),math.sin(first),math.cos(last),math.sin(last)
                a,b,c,d=V(x,l-.5,z),V(x,h-.5,z),V(nx,h-.5,nz),V(nx,l-.5,nz)
                normal=V(math.cos((first+last)*.5),0,math.sin((first+last)*.5))
            else
                a,b,c,d=V(u-.5,l-.5,0),V(w-.5,l-.5,0),V(w-.5,h-.5,0),V(u-.5,h-.5,0)
                normal=V(0,0,1)
            end
            local start=#positions+1
            positions[start],positions[start+1],positions[start+2],positions[start+3]=a,b,c,d
            local paint=colors[record.sample and record.sample((u+w)*.5,(l+h)*.5) or 1]
            for vertex=start,start+3 do
                vertexColors[vertex],normals[vertex],uvs[vertex]=paint,normal,uv
            end
            local index=#indices
            indices[index+1],indices[index+2],indices[index+3]=start,start+1,start+2
            indices[index+4],indices[index+5],indices[index+6]=start,start+2,start+3
            if not radial then
                indices[index+7],indices[index+8],indices[index+9]=start,start+2,start+1
                indices[index+10],indices[index+11],indices[index+12]=start,start+3,start+2
            end
        end
    end
    local model,paint=P.CraftPalette.build({positions=positions,normals=normals,colors=vertexColors,
        indices=indices,uvs=uvs})
    if meshCount>=48 then meshCache,meshCount={},0 end
    meshCache[signature],meshCount={model,paint},meshCount+1
    return model,paint
end

local function patch(r,parent,x,y,z,w,h,d)
    local e=entity(r,parent,x,y,z)
    e.scale=V(w,h,d or 1)
    e.active=false
    return e
end

local function coat(e,shape,pattern,shade,visible)
    e.active=visible and pattern>1 and patterns[pattern]~=nil
    if e.active then
        local model,paint=mesh(shape,pattern,shade)
        e.model=model
        e.material=paint
    end
end

local function mapOf(key,roughness,metalness,environment)
    return key and P.EquipmentTextures.material(key,roughness,metalness,environment)
end

local function resolvedSurface(part,base,baseMaterial,map,projection)
    part.model=map and P.EquipmentTextures.uvModel(base,projection) or base
    part.material=map or baseMaterial
end

local function lineSegment(r,parent,mat,a,b,thickness)
    local mid=(a+b)*.5
    local e=piece(r,parent,mat,mid.x,mid.y,mid.z,thickness,(b-a):len(),thickness)
    e.rotation=quat.fromToRotation(V(0,1,0),(b-a):normalize())
    return e
end

local shaftBounds={short={-.923,.419,-.37,0},long={-1.36,.879,-.48,.46},
    goalie={-.95,.469,-.39,0}}

local function buildStick(r)
    if r.roadStick then return r.roadStick end
    local root=r.stickRoot
    local s={finish=material(black),top=material(white),side=material(black),shoot=material(white)}
    s.upper,s.lower=patch(r,root,0,0,0,1,1,1),patch(r,root,0,0,0,1,1,1)
    s.center=patch(r,root,0,0,0,1,1,1)
    s.grip=patch(r,root,0,0,0,1,1,1)
    s.strings=entity(r,root)
    s.goalieStrings=entity(r,root)
    local function strings(parent,goalie)
        local half=goalie and .29 or .171
        local y=goalie and 1.135 or .95
        local edge=goalie and .14 or .104
        lineSegment(r,parent,s.top,V(-edge,y,-.131),V(edge,y,-.131),.010)
        for _,dir in ipairs({-1,1}) do
            lineSegment(r,parent,s.side,V(dir*half*.54,.55,-.052),
                V(dir*half,.82,-.081),.018)
        end
        local span=half*.92
        return lineSegment(r,parent,s.shoot,V(-span,.80,-.044),V(span,.80,-.044),.013)
    end
    s.fieldLine,s.goalieLine=strings(s.strings,false),strings(s.goalieStrings,true)
    r.stickTape.material=s.finish
    r.roadStick=s
    return s
end

local stickFinishes={{.27,.52},{.75,.18},{.14,.67}}

local function coatShaft(e,map,pattern,shade,radius,lo,hi)
    local length=hi-lo
    e.position,e.scale=V(0,(lo+hi)*.5,0),V(radius,length,radius)
    if map then
        e.model=P.EquipmentTextures.shaft(math.max(1,math.floor(length/.19+.5)))
        e.material=map
        e.active=true
    else
        coat(e,"tube",pattern,shade,true)
    end
end

local function stick(r,opts)
    local s=buildStick(r)
    local size=shaftBounds[r.stickType] or shaftBounds.short
    local goalie=r.stickType=="goalie"
    local widths={1,.88,1.12}
    local radius=widths[opts.shaftModel]
    r.stickShaft.scale=V(radius,1,radius)
    r.stickShaft.material.diffuse=tint(opts.shaftColor)
    local surface=stickFinishes[opts.shaftFinish]
    r.stickShaft.material.roughness,r.stickShaft.material.metalness=surface[1],surface[2]
    s.finish.diffuse=tint(opts.gripColor)
    s.top.diffuse,s.side.diffuse,s.shoot.diffuse=tint(opts.topStringColor),tint(opts.sidewallColor),tint(opts.shootingStringColor)
    local shaftMap=mapOf(imported(opts.shaftPattern),surface[1])
    local shaftRadius=.031*radius
    coatShaft(s.upper,shaftMap,opts.shaftPattern,opts.shaftColor,shaftRadius,.124,size[2]-.011)
    coatShaft(s.lower,shaftMap,opts.shaftPattern,opts.shaftColor,shaftRadius,size[1]+.172,size[3]-.109)
    coatShaft(s.center,shaftMap,1,opts.shaftColor,shaftRadius,size[3]+.070,-.074)
    local gripMap=mapOf(imported(opts.gripPattern))
    coatShaft(s.grip,gripMap,opts.gripPattern,opts.gripColor,gripMap and .036 or .034,-.0675,.1155)
    local headScale=({1,.93,1.08})[opts.headModel]
    r.stickHead.scale,r.stickMesh.scale=V(headScale,1,1),V(headScale,1,1)
    if s.kind~=r.stickType then
        s.kind,s.headModel,s.pocketModel=r.stickType,r.stickHead.model,r.stickMesh.model
    end
    r.materials.stick.diffuse=tint(opts.headColor)
    local meshRGB=swatches[opts.meshColor][2]
    r.materials.mesh.diffuse=opts.meshPattern==3
        and blendRGB(meshRGB,swatches[opts.shootingStringColor][2],.44) or colorFromRGB(meshRGB)
    r.materials.mesh.roughness=opts.meshPattern==2 and .68 or .91
    resolvedSurface(r.stickHead,s.headModel,r.materials.stick,mapOf(assetKeys[opts.headPattern-1]),"face")
    resolvedSurface(r.stickMesh,s.pocketModel,r.materials.mesh,mapOf(assetKeys[opts.pocketPattern-1]),"face")
    s.strings.active,s.goalieStrings.active=not goalie,goalie
    s.strings.position,s.strings.scale=V(0,size[4],0),V(headScale,1,1)
    s.goalieStrings.scale=V(headScale,1,1)
    local offset=opts.pocket==2 and .025 or opts.pocket==3 and -.05 or 0
    s.fieldLine.position,s.goalieLine.position=V(0,.8+offset,-.044),V(0,.8+offset,-.044)
end

function Equipment.textureTest(scene)
    local preview={shafts={},radius=1.12,height=1.60,centerY=0}
    for i,key in ipairs(assetKeys) do
        local owner={scene=scene}
        local root=entity(owner,nil,(i-2.5)*.65,0,0)
        local loaded,status=P.EquipmentTextures.status(key)
        local shaft
        if loaded then
            shaft=patch(owner,root,0,0,0,.10,1.50,.10)
            shaft.model=P.EquipmentTextures.shaft(7)
            shaft.material=P.EquipmentTextures.material(key)
            shaft.active=true
        end
        preview.shafts[i]={key=key,label=assetLabels[i],root=root,loaded=loaded,status=status,shaft=shaft}
    end
    return preview
end

local finishes = {
    {rough=.50,metal=.06}, {rgb={185,204,228},rough=.13,metal=.80},
    {rgb={229,185,79},rough=.15,metal=.78},
    {rgb={63,72,90},rough=.14,metal=.80},
    {rgb={208,132,121},rough=.16,metal=.76},
    {rgb={143,130,227},accent=color(85,225,221),rough=.17,metal=.76}
}
local gloveSizes={1,.91,1.07}

local function buildMatch(r)
    if r.roadMatch then return r.roadMatch end
    local m={gloves={},sleeves={},cuff=material(black,.42)}
    for _,side in ipairs(sides) do
        local wrist=r.joints[side.."Wrist"]
        local pads=patch(r,wrist,0,.048,.130,.165,.163)
        local cuff=piece(r,wrist,m.cuff,0,.120,.099,.249,.05,.08)
        m.gloves[side]={pads=pads,cuff=cuff}
        local leg=r.legs[side]
        local fabric=material(black)
        local sleeve=r.sleeveParts[side]
        m.sleeves[side]={fabric=fabric,
            thighModel=sleeve[1].model,shinModel=sleeve[2].model,
            thigh=patch(r,leg.hip,0,-.326,-.001,.137,.274,.141),
            shin=patch(r,leg.knee,0,-.175,.002,.129,.441,.145)}
        for _,part in ipairs(sleeve) do part.material=fabric end
    end
    r.roadMatch=m
    return m
end

local function gloveTexture(ops,finish,environment)
    return mapOf(imported(ops.glovePattern),finish.rough,finish.metal,environment)
end

function Equipment.applyMatch(r,kit)
    if not r then return end
    local ops=(kit or Equipment.restore()).equipped
    stick(r,ops)
    local m=buildMatch(r)
    local finish=finishes[ops.gloveFinish]
    local gloveRGB=swatches[ops.gloveColor][2]
    r.materials.gloves.diffuse=finish.rgb and blendRGB(finish.rgb,gloveRGB,.22) or colorFromRGB(gloveRGB)
    r.materials.gloveTrim.diffuse=finish.accent or tint(ops.gloveSecondary)
    r.materials.gloves.roughness,r.materials.gloves.metalness=finish.rough,finish.metal
    local environment=ops.gloveFinish>1 and P.Character.equipmentEnvironment() or nil
    if environment then pcall(function() r.materials.gloves.envMap=environment end) end
    local gloveMap=gloveTexture(ops,finish,environment)
    m.cuff.diffuse=finish.accent or tint(ops.gloveAccent)
    for _,side in ipairs(sides) do
        local parts=m.gloves[side]
        local scale=gloveSizes[ops.gloveModel]
        local shell=r.arms[side].glove
        shell.scale=V(scale,1,scale)
        resolvedSurface(shell,P.Character.gloveModel(),r.materials.gloves,gloveMap,"glove")
        parts.pads.position=V(0,.048,.132*scale)
        parts.cuff.active=ops.gloveCuff>1
        parts.cuff.scale=ops.gloveCuff==3 and V(.27,.075,.10) or V(.25,.043,.085)
        coat(parts.pads,"panel",ops.glovePattern,ops.gloveAccent,true)
        local wrap=m.sleeves[side]
        local style=ops[side.."Sleeve"]
        local pattern,shade=ops[side.."SleevePattern"],ops[side.."SleeveColor"]
        local map=mapOf(imported(pattern))
        local thigh,shin=r.sleeveParts[side][1],r.sleeveParts[side][2]
        wrap.fabric.diffuse=tint(shade)
        resolvedSurface(thigh,wrap.thighModel,wrap.fabric,style==3 and map,"sleeve")
        resolvedSurface(shin,wrap.shinModel,wrap.fabric,style>=2 and map,"sleeve")
        thigh.active,shin.active=style==3,style>=2
        r.exposedLegParts[side][1].active=style<3
        r.exposedLegParts[side][2].active=style<2
        coat(wrap.thigh,"tube",pattern,shade,style==3)
        coat(wrap.shin,"tube",pattern,shade,style>=2)
    end
end

-- Campus textiles shade the actual curved mesh. Match equipment keeps its own
-- overlay geometry and dimensions for pads, gloves and the competition rig.
local function fabric(pattern,shade)
    local base=swatches[shade][2]
    local record=patterns[pattern]
    local colors={}
    for i,rgb in ipairs(record.colors or {base}) do
        colors[i]=blendRGB(rgb,base,.25)
    end
    return function(u,v)
        return colors[record.sample and record.sample(u,v) or 1]
    end
end

local function trim(rgb,amount)
    return {rgb[1]+(blackRGB[1]-rgb[1])*amount,rgb[2]+(blackRGB[2]-rgb[2])*amount,
        rgb[3]+(blackRGB[3]-rgb[3])*amount}
end

local function casualLook(profile,ops)
    local look=P.CampusPeople.player(profile)
    look.shirt,look.pants=swatches[ops.hoodieColor][2],swatches[ops.joggerColor][2]
    look.shoe,look.pack=swatches[ops.sneakerColor][2],swatches[ops.backpackColor][2]
    look.trim,look.packTrim=trim(look.shirt,.48),trim(look.pack,.54)
    look.shoeStyle=({"court","boot","runner"})[ops.sneaker]
    look.backpackStyle=({"campus","roll","travel"})[ops.backpackStyle]
    look.carriesStick=true
    look.inks,look.patternKeys={},{}
    local function dye(part,pattern,shade)
        look.inks[part]=fabric(pattern,shade)
        look.patternKeys[part]=pattern..":"..shade
    end
    if ops.hoodiePattern>1 then dye("hoodie",ops.hoodiePattern,ops.hoodieColor) end
    if ops.backpackPattern>1 then dye("backpack",ops.backpackPattern,ops.backpackColor) end
    for _,side in ipairs(sides) do
        local part=side=="left" and "Left" or "Right"
        local style=ops[side.."Sleeve"]
        local pattern,shade=ops[side.."SleevePattern"],ops[side.."SleeveColor"]
        if style==3 and patterns[pattern] then
            dye("thigh"..part,pattern,shade)
        elseif style~=3 and ops.joggerPattern>1 then
            dye("thigh"..part,ops.joggerPattern,ops.joggerColor)
        end
        if style>=2 and patterns[pattern] then
            dye("shin"..part,pattern,shade)
        elseif style==1 and ops.joggerPattern>1 then
            dye("shin"..part,ops.joggerPattern,ops.joggerColor)
        end
    end
    return look
end

local function casualTextureGear(r,ops)
    local environment=imported(ops.glovePattern) and ops.gloveFinish>1
        and P.Character.equipmentEnvironment() or nil
    local gloves=gloveTexture(ops,finishes[ops.gloveFinish],environment)
    for i,side in ipairs(sides) do
        local style=ops[side.."Sleeve"]
        local map=style>=2 and mapOf(imported(ops[side.."SleevePattern"]))
        if map then
            local thigh,shin=r.thighs[i],r.shins[i]
            if style==3 then resolvedSurface(thigh,thigh.model,thigh.material,map,"sleeve") end
            resolvedSurface(shin,shin.model,shin.material,map,"sleeve")
        end
        if gloves then
            r.casualGloves=r.casualGloves or {}
            local glove=r.casualGloves[i]
            if not glove then
                glove=entity(r,r.wrists[i],0,-.102,0)
                r.casualGloves[i]=glove
            end
            local size=gloveSizes[ops.gloveModel]
            local scale=P.Character.campusScale
            glove.scale=V(scale*size,scale,scale*size)
            resolvedSurface(glove,P.Character.gloveModel(),nil,gloves,"glove")
            glove.active=true
        elseif r.casualGloves then
            r.casualGloves[i].active=false
        end
        r.hands[i].active=not gloves
    end
end

local function equipStowed(r,ops,kind)
    P.Character.setStickType(r,kind or r.stickType)
    stick(r,ops)
    -- The long shaft shifts upward along the same two attachment loops.
    local rise=r.stickType=="long" and .127*P.Character.campusScale or 0
    r.backpackStick.position=V(.166+rise*math.tan(math.rad(6)),.040+rise,.128)
end

function Equipment.applyCasual(r,profile,kit,stickType)
    local ops=(kit or Equipment.restore()).equipped
    P.CampusCharacter.apply(r,casualLook(profile,ops))
    casualTextureGear(r,ops)
    equipStowed(r,ops,stickType)
end

function Equipment.newCasual(scene,profile,kit,stickType)
    local ops=(kit or Equipment.restore()).equipped
    local r=P.CampusCharacter.new(scene,casualLook(profile,ops))
    r.campus=true
    P.Character.addEquipmentStick(r)
    r.backpackStick=entity(r,r.backpack)
    r.backpackStick.eulerAngles=V(0,0,-6)
    local scale=P.Character.campusScale
    r.backpackStick.scale=V(scale,scale,scale)
    r.stickRoot.parent=r.backpackStick
    r.stickRoot.position,r.stickRoot.eulerAngles=V(0,0,0),V(0,0,0)
    casualTextureGear(r,ops)
    equipStowed(r,ops,stickType)
    return r
end
