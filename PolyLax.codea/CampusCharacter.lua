-- Shared low-poly mesh recipes and articulated campus character rigs.
PolyLax = PolyLax or {}
local Character = {}
PolyLax.CampusCharacter = Character

local V=vec3
local sides={-1,1}
local neutral, eyeWhite, iris=color(255,255,255),color(248,239,223),color(44,33,30)
local bootSole=color(39,41,46)

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
    local earShade=color(look.skin[1]*.88,look.skin[2]*.78,look.skin[3]*.80)
    local jaw = ({oval=1,angular=1.16,round=1.11,long=.91})[look.headShape] or 1
    return paintedModel(function(mesh)
        loft(mesh,{{-.19,.058*jaw,.07,.017},{-.16,.107*jaw,.112,.008},{-.082,.155*jaw,.135},
            {.026,.166,.151},{.097,.167,.146,.007},{.154,.140,.134,.013},
            {.181,.082,.080,.02},{.188,.002,.002,.023}},10,skin)
        for _,side in ipairs({-1,1}) do
            smallOval(mesh,side*.158,-.024,.014,.037,.090,.047,skin)
            smallOval(mesh,side*.179,-.023,-.012,.014,.048,.013,earShade)
            smallOval(mesh,side*.070,.033,-.131,.043,.032,.018,eyeWhite)
            smallOval(mesh,side*.066,.032,-.148,.016,.028,.008,iris)
            badge(mesh,side*.066-.005,.040,-.157,.006,.007,.006,neutral)
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
        elseif cut=="braids" then
            for _,side in ipairs(sides) do
                for i=0,3 do
                    local x,y,z=side*(.140+i*.010),.059-i*.075,.091+i*.006
                    smallOval(mesh,x,y,z,.032,.096,.040,i%2==0 and hair or hairGlint)
                end
                badge(mesh,side*.172,-.213,.111,.045,.020,.046,lip)
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
        elseif look.outfit=="apron" then
            badge(mesh,0,-.117,-.125,.267,.352,.026,trim)
            badge(mesh,0,-.187,-.141,.201,.018,.021,shirt)
        elseif look.outfit=="polo" then
            for _,side in ipairs(sides) do
                badge(mesh,side*.046,.193,-.086,.078,.043,.043,trim)
            end
            badge(mesh,0,.099,-.132,.027,.116,.016,trim)
        elseif look.outfit=="cardigan" then
            badge(mesh,0,-.055,-.133,.119,.467,.025,trim)
            for y=-.21,.11,.079 do badge(mesh,-.046,y,-.153,.012,.013,.010,shirt) end
            badge(mesh,-.141,-.167,-.123,.098,.055,.026,trim)
            badge(mesh,.141,-.167,-.123,.098,.055,.026,trim)
        else
            badge(mesh,0,-.049,-.132,.014,.459,.018,trim)
            badge(mesh,0,.174,-.114,.117,.035,.027,trim)
            badge(mesh,.115,.061,-.130,.068,.041,.025,trim)
        end
        if look.accessory=="pack" then
            smallOval(mesh,0,-.04,.155,.186,.441,.090,trim)
            for _,side in ipairs(sides) do
                badge(mesh,side*.144,-.021,-.124,.037,.405,.029,trim)
            end
        elseif look.accessory=="lanyard" then
            for _,side in ipairs(sides) do
                local upperIn,upperOut=V(side*.057,.204,-.111),V(side*.071,.204,-.111)
                local lowerIn,lowerOut=V(side*.001,-.030,-.155),V(side*.012,-.030,-.155)
                if side==1 then
                    paintQuad(mesh,upperIn,upperOut,lowerOut,lowerIn,trim)
                else
                    paintQuad(mesh,upperOut,upperIn,lowerIn,lowerOut,trim)
                end
            end
            badge(mesh,0,-.077,-.158,.071,.086,.017,neutral)
            badge(mesh,0,-.073,-.169,.042,.020,.007,trim)
        end
    end)
end

local function handModel(look,side)
    local skin=dye(look.skin)
    local crease=color(look.skin[1]*.82,look.skin[2]*.74,look.skin[3]*.78)
    local trim=dye(look.trim)
    return paintedModel(function(mesh)
        loft(mesh,{{-.107,.018,.023,-.010},{-.093,.040,.038,-.008},
            {-.042,.059,.040},{.012,.050,.034},{.044,.045,.033}},8,skin)
        smallOval(mesh,-side*.046,-.028,-.026,.026,.070,.027,skin)
        for i=-1,1 do
            badge(mesh,i*.018,-.075,-.044,.003,.031,.005,crease)
        end
        if side==-1 and (look.accessory=="watch" or look.accessory=="wristband") then
            badge(mesh,0,.021,0,.103,.028,.086,trim)
            if look.accessory=="watch" then
                badge(mesh,0,.020,-.049,.047,.036,.014,bootSole)
                badge(mesh,0,.020,-.058,.014,.017,.006,neutral)
            end
        elseif side==-1 and look.accessory=="notebook" then
            badge(mesh,-.012,-.041,-.070,.138,.196,.027,trim)
            badge(mesh,-.012,-.041,-.085,.119,.176,.009,neutral)
            badge(mesh,-.063,-.041,-.097,.022,.201,.014,bootSole)
        end
    end)
end

local function shoeModel(look)
    local main,trim=dye(look.shoe),dye(look.trim)
    local style=look.shoeStyle
    local rise=style=="boot" and .136 or .092
    local sole=style=="runner" and .041 or .030
    return paintedModel(function(mesh)
        loft(mesh,{{-.096,.077,.135,-.083},{-.096+sole,.097,.161,-.070},
            {-.066+sole,.097,.161,-.070}},10,bootSole)
        loft(mesh,{{-.058,.092,.158,-.072},{.008,.088,.148,-.069},
            {.043,.070,.116,-.043},{rise,.056,.074,.005}},10,main)
        badge(mesh,0,.028,-.202,.098,.020,.024,trim)
        for i=0,2 do
            badge(mesh,0,.044+i*.009,-.137+i*.030,.080-i*.009,.009,.014,neutral)
        end
        badge(mesh,0,.004,.079,.080,.048,.019,trim)
    end)
end

local function surface(ink)
    local standard=asset and asset.builtin and asset.builtin.Materials
    local result=craft.material(standard and standard.Standard or "Materials:Standard")
    result.diffuse,result.roughness=ink,.88
    return result
end

-- Geometry keys use only the interchangeable parts that affect each mesh.
local function paletteKey(rgb)
    return table.concat(rgb,",")
end

local meshes,materials={},{}
local function cached(cache,kind,key,build,...)
    local section=cache[kind]
    if not section then section={keys={},items={}} cache[kind]=section end
    local item=section.items[key]
    if item then return item end
    item=build(...)
    if #section.keys>=24 then section.items[table.remove(section.keys,1)]=nil end
    section.keys[#section.keys+1]=key
    section.items[key]=item
    return item
end

local function dyelot(rgb)
    return cached(materials,"dye",paletteKey(rgb),function(data) return surface(dye(data)) end,rgb)
end

local limbModel,paint
local function node(scene,parent,model)
    local entity=scene:entity()
    if parent then entity.parent=parent end
    if model then entity.model=model end
    return entity
end

function Character.apply(rig,look)
    local frame=({slim=.92,athletic=1,broad=1.11})[look.frame] or 1
    local skin,hair,shirt,trim=paletteKey(look.skin),paletteKey(look.hair),
        paletteKey(look.shirt),paletteKey(look.trim)
    local faceKey=table.concat({look.headShape or "oval",skin,hair,look.haircut,
        tostring(look.beard),tostring(look.glasses),tostring(look.earrings)},"/")
    local torsoAccessory=(look.accessory=="pack" or look.accessory=="lanyard") and look.accessory or "none"
    local outfitKey=table.concat({look.outfit,shirt,trim,torsoAccessory},"/")
    local footwearKey=table.concat({look.shoeStyle or "court",paletteKey(look.shoe),trim},"/")
    local shoe=cached(meshes,"shoes",footwearKey,shoeModel,look)
    rig.root.scale=V(look.width,look.height,look.width)
    rig.face.model=cached(meshes,"heads",faceKey,faceModel,look)
    rig.face.scale=V(look.faceWidth,look.faceHeight,1)
    rig.outfit.model=cached(meshes,"outfits",outfitKey,costumeModel,look)
    rig.outfit.scale,rig.waist.scale=V(frame,1,frame),V(.385*frame,.24,.285)
    local skinMat,shirtMat,trimMat,trousers=dyelot(look.skin),dyelot(look.shirt),dyelot(look.trim),dyelot(look.pants)
    rig.neck.material,rig.waist.material=skinMat,trousers
    local shortSleeves=look.outfit=="varsity" or look.outfit=="apron" or look.outfit=="polo"
    for i,side in ipairs(sides) do
        rig.arms[i].position=V(side*.235*frame,.158,0)
        rig.legs[i].position=V(side*.100*frame,.942,0)
        rig.sleeves[i].material=shortSleeves and trimMat or shirtMat
        rig.forearms[i].material=shortSleeves and skinMat or shirtMat
        rig.thighs[i].material,rig.shins[i].material=trousers,trousers
        local accessory=i==1 and look.accessory
        local handAccessory=(accessory=="watch" or accessory=="wristband" or accessory=="notebook") and accessory or "none"
        local handKey=table.concat({skin,side,handAccessory,handAccessory~="none" and trim or ""},"/")
        rig.hands[i].model=cached(meshes,"hands",handKey,handModel,look,side)
        rig.feet[i].model=shoe
    end
    rig.definition=look
end

function Character.new(scene,look)
    limbModel=limbModel or paintedModel(function(mesh)
        loft(mesh,{{-.5,.29,.31},{-.416,.459,.461},{-.303,.49,.49},
            {.313,.5,.5},{.436,.454,.457},{.5,.29,.31}},8,neutral)
    end)
    paint=paint or surface(neutral)
    local root=node(scene)
    local rig={root=root,arms={},elbows={},wrists={},legs={},knees={},ankles={},
        sleeves={},forearms={},thighs={},shins={},hands={},feet={}}
    local function part(parent,x,y,z,w,h,d,model)
        local e=node(scene,parent,model)
        e.position=V(x,y,z)
        if w then e.scale=V(w,h,d) end
        return e
    end
    rig.torso=part(root,0,1.34,0)
    rig.outfit=part(rig.torso,0,0,0)
    rig.outfit.material=paint
    rig.waist=part(root,0,1.001,0,.385,.24,.285,limbModel)
    rig.neck=part(rig.torso,0,.266,0,.147,.187,.159,limbModel)
    rig.head=part(rig.torso,0,.439,-.007)
    rig.face=part(rig.head,0,.071,0)
    rig.face.material=paint
    for i,side in ipairs(sides) do
        local arm=part(rig.torso,side*.235,.158,0)
        local elbow=part(arm,side*.030,-.252,-.004)
        local wrist=part(elbow,0,-.239,-.006)
        local leg=part(root,side*.100,.942,0)
        local knee=part(leg,0,-.410,.008)
        local ankle=part(knee,0,-.439,-.006)
        rig.sleeves[i]=part(arm,side*.012,-.117,0,.159,.298,.178,limbModel)
        rig.forearms[i]=part(elbow,0,-.109,0,.130,.247,.138,limbModel)
        rig.thighs[i]=part(leg,0,-.166,0,.202,.416,.224,limbModel)
        rig.shins[i]=part(knee,0,-.187,0,.164,.417,.179,limbModel)
        rig.hands[i],rig.feet[i]=wrist,ankle
        rig.hands[i].material,rig.feet[i].material=paint,paint
        rig.arms[i],rig.elbows[i],rig.wrists[i]=arm,elbow,wrist
        rig.legs[i],rig.knees[i],rig.ankles[i]=leg,knee,ankle
    end
    Character.apply(rig,look)
    return rig
end

