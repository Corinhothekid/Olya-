-- Smooth indexed meshes for the articulated campus rig. Local front is -Z.
PolyLax = PolyLax or {}
local Human = {}
PolyLax.CampusHumanMeshes = Human

local V, sin, cos = vec3, math.sin, math.cos
local tau = math.pi * 2
local sides = {-1,1}
local chalk, charcoal = color(239,236,224), color(36,38,44)
local up = V(0,1,0)

local function dye(rgb)
    return color(rgb[1],rgb[2],rgb[3])
end

local function tone(rgb, factor, tint)
    local function channel(i)
        return math.max(0,math.min(255,rgb[i]*factor+(tint and tint[i] or 0)))
    end
    return color(channel(1),channel(2),channel(3))
end

local function meshModel(build)
    local mesh={positions={},normals={},indices={},colors={},uvs={}}
    build(mesh)
    for index, normal in ipairs(mesh.normals) do mesh.normals[index]=normal:normalize() end
    local model=craft.model()
    model.positions,model.normals,model.colors,model.indices,model.uvs=
        mesh.positions,mesh.normals,mesh.colors,mesh.indices,mesh.uvs
    return model
end

local function vertex(mesh,p,ink,u,v)
    local index=#mesh.positions+1
    mesh.positions[index],mesh.normals[index],mesh.colors[index],mesh.uvs[index]=p,V(),ink,vec2(u,v)
    return index
end

local function triangle(mesh,a,b,c)
    local p, n, i = mesh.positions,mesh.normals,mesh.indices
    local normal=(p[b]-p[a]):cross(p[c]-p[a])
    n[a],n[b],n[c]=n[a]+normal,n[b]+normal,n[c]+normal
    local j=#i+1
    i[j],i[j+1],i[j+2]=a,b,c
end

local ringsBySides={}
local function ringAngles(n)
    local angles=ringsBySides[n]
    if angles then return angles end
    angles={}
    for col=1,n do
        local u=(col-1)/n
        angles[col]={sin(u*tau),cos(u*tau),u}
    end
    ringsBySides[n]=angles
    return angles
end

-- A ring lattice shares vertices through the curves. Cap vertices are separate,
-- so contact surfaces such as soles and garment openings can retain clean edges.
local function surface(mesh,count,n,point,ink,sample)
    local start=#mesh.positions
    local angles=ringAngles(n)
    for row=1,count do
        local v=(row-1)/(count-1)
        for _,angle in ipairs(angles) do
            local s,c,u=angle[1],angle[2],angle[3]
            vertex(mesh,point(row,s,c),sample and sample(u,v,ink) or ink,u,v)
        end
    end
    for row=0,count-2 do
        for col=0,n-1 do
            local a,b=start+row*n+col+1,start+row*n+(col+1)%n+1
            triangle(mesh,a,a+n,b+n)
            triangle(mesh,a,b+n,b)
        end
    end
    for _,row in ipairs({1,count}) do
        local capStart=#mesh.positions
        local center=V()
        for col=1,n do
            local i=start+(row-1)*n+col
            local p=mesh.positions[i]
            vertex(mesh,p,mesh.colors[i],.5,.5)
            center=center+p
        end
        local hub=vertex(mesh,center/n,ink,.5,.5)
        for col=0,n-1 do
            local a,b=capStart+col+1,capStart+(col+1)%n+1
            if row==1 then triangle(mesh,hub,a,b) else triangle(mesh,hub,b,a) end
        end
    end
end

-- Sections contain height, half-width, half-depth, and optional depth/lateral shift.
local function loft(mesh,rings,n,ink,warp,sample)
    surface(mesh,#rings,n,function(row,s,c)
        local ring=rings[row]
        local x,y,z=(ring[5] or 0)+ring[2]*s,ring[1],(ring[4] or 0)-ring[3]*c
        if warp then x,y,z=warp(x,y,z,s,c,row) end
        return V(x,y,z)
    end,ink,sample)
end

local function oval(mesh,x,y,z,rx,ry,rz,ink,n)
    if math.max(rx,ry,rz)<.026 then
        loft(mesh,{{y-ry,rx*.22,rz*.22,z,x},{y-ry*.63,rx*.77,rz*.77,z,x},
            {y,rx,rz,z,x},{y+ry*.63,rx*.77,rz*.77,z,x},{y+ry,rx*.22,rz*.22,z,x}},
            math.min(n or 6,6),ink)
        return
    end
    loft(mesh,{{y-ry,rx*.16,rz*.16,z,x},{y-ry*.76,rx*.62,rz*.62,z,x},
        {y-ry*.35,rx*.92,rz*.92,z,x},{y,rx,rz,z,x},
        {y+ry*.35,rx*.92,rz*.92,z,x},{y+ry*.76,rx*.62,rz*.62,z,x},
        {y+ry,rx*.16,rz*.16,z,x}},n or 8,ink)
end

-- Narrow swept bands provide seams, drawstrings, frames, braids and straps.
local function strand(mesh,path,wide,deep,ink,n)
    local direction=(path[#path]-path[1]):normalize()
    local preferred=math.abs(direction.x)>.51 and up or V(1,0,0)
    local widths,depths={},{}
    for row=1,#path do
        local tangent=(path[math.min(#path,row+1)]-path[math.max(1,row-1)]):normalize()
        local along=preferred-tangent*preferred:dot(tangent)
        if along:len()<.04 then along=V(0,0,1)-tangent*tangent.z end
        along=along:normalize()
        widths[row],depths[row]=along*wide,tangent:cross(along)*deep
    end
    surface(mesh,#path,n or 6,function(row,s,c)
        return path[row]+widths[row]*s+depths[row]*c
    end,ink)
end

local function chestWarp(outfit)
    local relaxed=outfit=="hoodie" and 1 or outfit=="polo" and .94 or .98
    return function(x,y,z,s,c)
        return x*relaxed,y,z-(c>0 and c*(1-c)*.024 or 0)
    end
end

function Human.body(look)
    local cloth,trim=dye(look.shirt),dye(look.trim)
    local edge=tone(look.shirt,.73)
    local highlight=tone(look.shirt,1.13)
    return meshModel(function(mesh)
        loft(mesh,{{-.035,.132,.091,.007},{-.007,.153,.111,.005},{.035,.163,.118,.005},
            {.120,.160,.116,.009},{.220,.163,.105,.009},{.330,.178,.124,.004},
            {.432,.188,.127,.007},{.505,.184,.114,.013},{.549,.156,.084,.013},
            {.584,.105,.065,.013},{.602,.059,.052,.008}},14,cloth,
            chestWarp(look.outfit),look.inks and look.inks.hoodie)
        local outfit=look.outfit
        if outfit=="hoodie" then
            -- The hood is a folded collar with its opening visible near the neck.
            loft(mesh,{{.346,.044,.042,.110},{.395,.092,.064,.121},{.464,.111,.077,.108},
                {.521,.102,.081,.087},{.558,.077,.064,.076},{.574,.050,.044,.066}},12,cloth)
            strand(mesh,{V(-.087,.507,.054),V(-.065,.553,.057),V(-.030,.566,.095),
                V(.029,.566,.095),V(.065,.553,.057),V(.088,.506,.052)},.008,.010,edge,6)
            for _,side in ipairs(sides) do
                strand(mesh,{V(side*.063,.573,-.052),V(side*.079,.510,-.085),
                    V(side*.067,.435,-.122),V(side*.073,.355,-.127)},.004,.004,highlight)
                strand(mesh,{V(side*.082,.185,-.107),V(side*.109,.130,-.098),
                    V(side*.104,.103,-.094)},.004,.003,edge)
            end
            loft(mesh,{{.076,.084,.022,-.100},{.086,.106,.023,-.100},{.130,.109,.028,-.102},
                {.167,.087,.019,-.101},{.177,.065,.010,-.103}},10,cloth)
        elseif outfit=="jacket" or outfit=="varsity" or outfit=="cardigan" then
            local seam=outfit=="varsity" and trim or edge
            strand(mesh,{V(0,.032,-.115),V(0,.150,-.113),V(0,.257,-.110),V(0,.410,-.125),
                V(0,.522,-.101),V(0,.577,-.056)},.005,.004,seam)
            for _,side in ipairs(sides) do
                strand(mesh,{V(side*.042,.591,-.042),V(side*.060,.565,-.059),
                    V(side*.089,.527,-.084),V(side*.106,.504,-.089)},.010,.008,trim)
                strand(mesh,{V(side*.070,.156,-.102),V(side*.113,.112,-.077),
                    V(side*.123,.074,-.072)},.004,.004,edge)
            end
            if outfit=="cardigan" then
                for i=1,3 do oval(mesh,.009,.115+i*.104,-.121,.006,.006,.004,trim,6) end
            else
                strand(mesh,{V(0,.446,-.126),V(0,.474,-.120)},.009,.004,trim)
            end
        elseif outfit=="polo" then
            for _,side in ipairs(sides) do
                strand(mesh,{V(side*.039,.596,-.040),V(side*.065,.567,-.062),
                    V(side*.061,.526,-.090),V(side*.020,.554,-.077)},.010,.007,trim)
            end
            strand(mesh,{V(0,.532,-.089),V(0,.476,-.111),V(0,.420,-.122)},.010,.003,edge)
            oval(mesh,0,.453,-.120,.005,.006,.004,trim,6)
        elseif outfit=="apron" then
            loft(mesh,{{.016,.112,.015,-.108},{.035,.125,.017,-.107},{.237,.118,.023,-.102},
                {.411,.099,.019,-.117},{.470,.077,.012,-.110}},10,trim)
            strand(mesh,{V(-.059,.454,-.122),V(-.088,.529,-.085),V(-.045,.584,-.045),
                V(.047,.583,-.044),V(.085,.529,-.085),V(.056,.450,-.122)},.010,.005,trim)
        end
        if look.accessory=="lanyard" then
            strand(mesh,{V(-.053,.570,-.062),V(-.057,.480,-.130),V(-.046,.395,-.137),
                V(-.017,.295,-.123),V(.022,.297,-.123),V(.050,.395,-.137),
                V(.062,.478,-.125),V(.053,.569,-.060)},.004,.004,trim)
            loft(mesh,{{.224,.021,.004,-.128,.009},{.231,.024,.006,-.129,.009},
                {.284,.024,.006,-.129,.009},{.291,.021,.004,-.128,.009}},8,chalk)
            strand(mesh,{V(-.008,.272,-.135),V(.022,.272,-.135)},.003,.003,trim)
        end
    end)
end

function Human.pelvis(look)
    return meshModel(function(mesh)
        loft(mesh,{{-.107,.107,.047,.023},{-.077,.131,.070,.014},{-.026,.153,.096,.012},
            {.046,.160,.108,.009},{.091,.156,.107,.006},{.120,.144,.099,.005}},12,
            dye(look.pants),function(x,y,z,s,c)
                local bottom=math.max(0,math.min(1,-y/.108))
                return x,y+bottom*.054*(1-s*s),z+bottom*.023*math.max(0,c)
            end)
    end)
end

function Human.neck(look)
    return meshModel(function(mesh)
        loft(mesh,{{-.036,.063,.054,.007},{-.015,.060,.051,.005},
            {.023,.048,.046,.008},{.059,.046,.045,.006},{.101,.056,.043,-.003}},10,dye(look.skin))
    end)
end

local jawWidths={oval=1,angular=1.10,round=1.08,long=.91}

local function faceWarp(x,y,z,s,c)
    local f=math.max(0,c)
    local cheek=math.max(0,1-math.abs(y+.032)*26)
    local hollow=math.max(0,1-math.abs(y-.026)*46)
    z=z-cheek*(1-c*c)*f*.028+hollow*(1-c*c)*f*.038
    return x,y,z
end

local function eyesAndNose(mesh,look,skin)
    local topLid=tone(look.skin,.57,{11,4,3})
    local bottomLid=tone(look.skin,.86,{6,1,0})
    local iris=look.skin[1]<160 and color(59,44,32) or color(83,77,53)
    local eyebrow=tone(look.hair,.71,{11,9,7})
    for _,side in ipairs(sides) do
        local x=side*.044
        loft(mesh,{{.016,.007,.004,-.094,x},{.020,.014,.008,-.094,x},
            {.025,.021,.009,-.095,x},{.030,.017,.008,-.095,x},
            {.034,.009,.005,-.094,x}},10,color(209,204,190))
        oval(mesh,x-side*.001,.025,-.103,.006,.007,.004,iris,8)
        oval(mesh,x-side*.002,.025,-.106,.003,.004,.002,color(31,26,23),6)
        oval(mesh,x-.002,.028,-.107,.0016,.0016,.0012,chalk,6)
        strand(mesh,{V(x-.020,.025,-.096),V(x-.010,.032,-.103),V(x+.006,.034,-.103),
            V(x+.017,.029,-.100),V(x+.020,.025,-.096)},.0018,.0016,topLid,5)
        strand(mesh,{V(x-.018,.023,-.096),V(x-.009,.018,-.102),V(x+.008,.019,-.103),
            V(x+.018,.023,-.096)},.0017,.0015,bottomLid,5)
        strand(mesh,{V(side*.022,.047,-.108),V(side*.038,.054,-.109),
            V(side*.056,.057,-.101),V(side*.075,.049,-.088)},.0041,.0035,eyebrow)
    end
    loft(mesh,{{-.033,.009,.005,-.108},{-.028,.017,.014,-.111},
        {-.022,.017,.024,-.109},{-.011,.014,.023,-.106},{.012,.009,.016,-.103},
        {.043,.012,.010,-.105},{.055,.010,.005,-.102}},10,skin)
    for _,side in ipairs(sides) do
        oval(mesh,side*.013,-.026,-.115,.009,.007,.010,skin,8)
        oval(mesh,side*.011,-.030,-.122,.004,.002,.003,tone(look.skin,.52,{15,5,3}),6)
        oval(mesh,side*.104,-.009,.011,.019,.046,.028,skin,10)
        oval(mesh,side*.114,-.006,-.011,.008,.029,.007,tone(look.skin,.83,{10,2,2}),8)
        if look.earrings then oval(mesh,side*.117,-.044,-.012,.008,.011,.007,color(224,174,88),8) end
    end
end

local function hair(mesh,look)
    local style=look.haircut
    if not style or style=="none" then return end
    local base=dye(look.hair)
    local shine=tone(look.hair,1.06,{13,10,8})
    local thin=style=="crop"
    local sweep=style=="sweep" or style=="neat"
    local volume=thin and 0 or style=="curls" and .016 or .010
    local roots={{.083,.115,.109,.012},{.110,.124,.117,.012},{.131,.116,.108,.012},
        {.144+volume*.66,.098,.093,.013},{.153+volume,.063,.071,.012},
        {.157+volume,.019,.025,.012},{.159+volume,.004,.006,.013}}
    loft(mesh,roots,14,base,function(x,y,z,s,c,row)
        local variation=1-(row-1)/(#roots-1)
        local rear=style=="bob" and .124 or style=="braids" and .080 or .078
        if c<.65 then y=y-rear*variation*((.65-c)/1.65)^.67 end
        if sweep then
            local front=math.max(0,c)*variation
            local wave=sin(s*2.8+.5)
            y=y-.022*front*wave
            x=x-(style=="neat" and .014 or .021)*front
            z=z-.013*front*wave
        elseif style=="curls" then
            y=y+.008*variation*cos(8*s+4*c)
        end
        return x,y,z
    end)
    if sweep then
        strand(mesh,{V(-.090,.104,-.066),V(-.063,.128,-.085),V(-.028,.150,-.074),
            V(.026,.148,-.060),V(.064,.132,-.044)},.006,.009,shine,7)
        strand(mesh,{V(-.077,.119,-.061),V(-.041,.141,-.068),V(.004,.151,-.055),
            V(.053,.138,-.035)},.003,.006,base,6)
        if style=="neat" then
            local silver=tone(look.hair,1.14,{14,11,8})
            for _,side in ipairs(sides) do
                strand(mesh,{V(side*.111,.048,.004),V(side*.119,.073,.009),
                    V(side*.118,.102,-.011)},.005,.005,silver,6)
            end
        end
    elseif style=="curls" then
        for i=0,5 do
            local a=i*tau/6
            oval(mesh,sin(a)*.079,.129+(i%2)*.015,-cos(a)*.067+.007,
                .033,.035,.031,i==3 and shine or base,8)
        end
    elseif style=="bun" then
        oval(mesh,0,.097,.122,.049,.052,.041,base,10)
        strand(mesh,{V(-.037,.109,.140),V(-.012,.132,.153),V(.023,.126,.157),
            V(.046,.101,.136)},.005,.004,shine)
    elseif style=="bob" then
        for _,side in ipairs(sides) do
            loft(mesh,{{-.106,.011,.022,.020,side*.095},{-.091,.026,.051,.029,side*.101},
                {-.040,.024,.072,.035,side*.109},{.037,.023,.067,.029,side*.108},
                {.083,.019,.046,.022,side*.105}},9,base)
        end
    elseif style=="braids" then
        for _,side in ipairs(sides) do
            local path={V(side*.094,.098,.065),V(side*.114,.051,.077),
                V(side*.122,-.015,.085),V(side*.123,-.085,.085),V(side*.107,-.159,.078)}
            strand(mesh,path,.014,.012,base,8)
            local braid={}
            for i=1,4 do
                local a,b=path[i],path[i+1]
                for step=0,3 do
                    local anchor=a+(b-a)*(step/4)
                    braid[#braid+1]=anchor+V(.007*sin(step*tau/4),0,.007+.002*(step%2))
                end
            end
            braid[#braid+1]=path[#path]+V(0,0,.008)
            strand(mesh,braid,.004,.004,shine)
            oval(mesh,side*.107,-.158,.078,.016,.008,.014,dye(look.trim),6)
        end
    end
end

local function beard(mesh,look)
    local style=look.beardStyle or (look.beard and 5 or 1)
    if style==1 then return end
    local body=tone(look.hair,1.03,{7,6,5})
    if style==2 then body=tone(look.skin,.68,{11,9,9}) end
    if style==2 or style==5 or style==6 then
        local fullness=style==6 and 1.07 or 1
        loft(mesh,{{-.133,.026,.043,-.027},{-.122,.046,.069,-.018},
            {-.107,.070,.082,-.011},{-.084,.085,.086,-.005},{-.064,.091,.072,.003}},
            12,body,function(x,y,z,s,c)
                return x*fullness,y+.022*math.abs(s),z-(c>.35 and .006*fullness or 0)
            end)
    elseif style==4 then
        oval(mesh,0,-.105,-.087,.027,.022,.012,body,8)
    end
    if style>=3 then
        for _,side in ipairs(sides) do
            strand(mesh,{V(side*.003,-.043,-.110),V(side*.016,-.041,-.104),
                V(side*.029,-.046,-.099)},.005,.003,body,6)
        end
    end
end

local function eyeglasses(mesh)
    local frame=color(51,48,48)
    for _,side in ipairs(sides) do
        local path={}
        for i=0,10 do
            local a=i*tau/10
            path[#path+1]=V(side*.045+sin(a)*.027,.026+cos(a)*.017,-.114+.096*math.abs(.045+side*sin(a)*.027))
        end
        strand(mesh,path,.0028,.003,frame,6)
        strand(mesh,{V(side*.071,.030,-.108),V(side*.093,.032,-.083),
            V(side*.114,.024,-.018),V(side*.116,.009,.000)},.003,.0035,frame,6)
    end
    strand(mesh,{V(-.018,.029,-.118),V(0,.037,-.124),V(.018,.029,-.118)},.003,.0028,frame,6)
end

function Human.head(look)
    local skin=dye(look.skin)
    local jaw=jawWidths[look.headShape] or 1
    local mouth=tone(look.skin,.66,{20,4,8})
    return meshModel(function(mesh)
        loft(mesh,{{-.132,.025*jaw,.036,-.016},{-.123,.043*jaw,.063,-.010},
            {-.105,.069*jaw,.075,.000},{-.078,.086*jaw,.090,.002},
            {-.037,.101,.102,.004},{.005,.109,.105,.003},{.036,.110,.104,.002},
            {.071,.110,.102,.004},{.100,.101,.093,.010},{.122,.077,.074,.013},
            {.135,.045,.045,.015},{.139,.008,.011,.018}},16,skin,faceWarp)
        eyesAndNose(mesh,look,skin)
        beard(mesh,look)
        strand(mesh,{V(-.027,-.060,-.092),V(-.015,-.064,-.100),V(0,-.062,-.105),
            V(.015,-.063,-.099),V(.028,-.059,-.092)},.0028,.0031,mouth,6)
        strand(mesh,{V(-.014,-.069,-.099),V(0,-.073,-.103),V(.014,-.068,-.099)},
            .0029,.0025,tone(look.skin,.96,{12,3,5}),6)
        hair(mesh,look)
        if look.glasses then eyeglasses(mesh) end
    end)
end

local armParts={
    upperArm={{-.322,.029,.031,0},{-.305,.040,.042,0},{-.280,.043,.046,-.001},
        {-.224,.048,.050,.004},{-.170,.054,.057,.006},{-.099,.060,.063,.006},
        {-.047,.064,.068,.002},{-.008,.060,.065,.002},{.024,.049,.054,.005},{.044,.018,.026,.005}},
    forearm={{-.264,.027,.029,-.003},{-.252,.033,.037,-.001},{-.225,.035,.039,0},
        {-.177,.039,.044,.004},{-.118,.048,.051,.007},{-.064,.051,.052,.006},
        {-.021,.045,.044,.002},{.021,.038,.036,0}},
    thigh={{-.497,.024,.025,.001},{-.479,.055,.060,0},{-.440,.062,.064,-.011},
        {-.382,.063,.071,-.001},{-.316,.071,.075,.009},{-.237,.077,.088,.006},
        {-.155,.086,.092,.016},{-.070,.088,.104,.019},{.002,.079,.092,.015},{.058,.049,.054,.010}},
    shin={{-.475,.034,.037,0},{-.460,.041,.049,0},{-.410,.046,.053,.009},
        {-.334,.048,.061,.008},{-.267,.059,.068,.013},{-.188,.063,.079,.014},
        {-.115,.061,.079,.014},{-.059,.053,.060,.005},{-.009,.056,.061,-.004},
        {.033,.040,.048,-.006}}
}

function Human.limb(look,part,side)
    local isLeg=part=="thigh" or part=="shin"
    local short=look.outfit=="polo" or look.outfit=="apron"
    local upper=part=="upperArm"
    local key=isLeg and part..(side<0 and "Left" or "Right") or nil
    local fabric=isLeg and look.pants or (look.outfit=="varsity" and look.trim or look.shirt)
    local skin=short and part=="forearm"
    local ink=skin and look.skin or fabric
    return meshModel(function(mesh)
        loft(mesh,armParts[part],10,dye(ink),function(x,y,z,s,c)
            local fold=sin((y+.415)*31+side*s*1.25)*.045
            local cloth=not skin and 1+fold or 1
            local shape=look.frame=="broad" and 1.045 or look.frame=="slim" and .92 or 1
            local sleeveRoom=not isLeg and not skin and .007 or 0
            local shoulder=upper and math.max(0,math.min(1,(y+.12)*7.6)) or 0
            return (x+s*sleeveRoom)*cloth*shape-side*shoulder*.020,
                y-math.max(0,side*s)*shoulder*.022,(z-c*sleeveRoom)*cloth
        end,key and look.inks and look.inks[key])
        local ribbed=look.outfit=="hoodie" or look.outfit=="varsity"
        if part=="shin" and look.outfit=="hoodie" and not (look.inks and look.inks[key]) then
            loft(mesh,{{-.463,.041,.046},{-.452,.046,.053},{-.425,.046,.056,.002},
                {-.417,.043,.053,.004}},10,tone(look.pants,.82))
        elseif part=="forearm" and ribbed then
            loft(mesh,{{-.251,.035,.038},{-.245,.041,.045},{-.217,.042,.047,.002},{-.208,.039,.043,.003}},
                10,look.outfit=="varsity" and dye(look.shirt) or tone(look.shirt,.78))
        elseif short and upper then
            -- Expose the elbow through a fitted sleeve opening on polos and staff shirts.
            loft(mesh,{{-.324,.033,.034},{-.307,.043,.043},{-.267,.044,.047},{-.226,.047,.051}},
                10,dye(look.skin))
            loft(mesh,{{-.248,.046,.050},{-.244,.053,.058},{-.223,.053,.058},{-.213,.049,.055}},
                10,look.outfit=="polo" and dye(look.trim) or tone(look.shirt,.82))
        end
    end)
end

function Human.hand(look,side)
    local skin=dye(look.skin)
    return meshModel(function(mesh)
        loft(mesh,{{-.121,.024,.015,-.005},{-.108,.037,.021,-.005},{-.081,.045,.025,-.003},
            {-.047,.040,.024,0},{-.016,.032,.022,.001},{.013,.025,.022,.001}},10,skin)
        local tips={-.148,-.167,-.174,-.161}
        for i=1,4 do
            local x=(i-2.5)*.017*side
            local tip=tips[i]
            strand(mesh,{V(x,tip,-.029),V(x*1.03,tip+.016,-.022),
                V(x*1.08,-.112,-.011),V(x,-.097,0)},.009,.010,skin,7)
        end
        strand(mesh,{V(side*.047,-.107,-.018),V(side*.047,-.091,-.012),
            V(side*.040,-.068,-.006),V(side*.027,-.046,-.004)},.012,.011,skin,8)
        if side==-1 and (look.accessory=="watch" or look.accessory=="wristband") then
            loft(mesh,{{-.021,.032,.023},{-.017,.034,.027},{.001,.031,.026},{.004,.028,.022}},
                9,dye(look.trim))
            if look.accessory=="watch" then
                oval(mesh,0,-.009,-.025,.016,.017,.006,charcoal,9)
                oval(mesh,0,-.009,-.030,.011,.011,.004,color(101,144,147),7)
            end
        elseif side==-1 and look.accessory=="notebook" then
            loft(mesh,{{-.154,.022,.007,-.041},{-.148,.048,.010,-.047},{-.021,.048,.010,-.047},
                {-.015,.022,.007,-.041}},8,dye(look.trim))
            loft(mesh,{{-.146,.037,.003,-.057},{-.139,.042,.004,-.057},{-.031,.042,.004,-.057},
                {-.024,.037,.003,-.057}},8,chalk)
            strand(mesh,{V(-.038,-.145,-.058),V(-.039,-.116,-.059),V(-.039,-.032,-.059)},
                .003,.004,charcoal)
        end
    end)
end

function Human.shoe(look,side)
    local upper=dye(look.shoe)
    local upperSeam=tone(look.shoe,.72)
    local outsole=tone(look.shoe,.24,{14,13,12})
    local midsole=tone(look.shoe,.49,{36,34,29})
    local boot=look.shoeStyle=="boot"
    local runner=look.shoeStyle=="runner"
    local function last(x,y,z,s,c)
        local width=c>0 and 1+c*.12 or 1+c*.25
        return (x*width+side*.013*math.max(0,c)),y,z
    end
    return meshModel(function(mesh)
        loft(mesh,{{-.099,.060,.116,-.053},{-.094,.065,.124,-.054},
            {runner and -.078 or -.083,.066,.124,-.054},{-.073,.063,.122,-.054}},14,outsole,last)
        loft(mesh,{{-.080,.065,.124,-.054},{-.070,.067,.125,-.054},
            {-.053,.064,.122,-.055},{-.050,.061,.120,-.055}},14,midsole,last)
        loft(mesh,{{-.064,.060,.117,-.056},{-.038,.061,.117,-.056},
            {-.021,.058,.109,-.055},{.000,.054,.092,-.042},{.017,.047,.072,-.022},
            {.032,.042,.060,-.012},{boot and .067 or .043,.039,.047,.001},
            {boot and .073 or .047,.033,.041,.001}},14,upper,last)
        local laces=boot and upperSeam or chalk
        for i=0,2 do
            local y,z=.015+i*.009,-.084+i*.017
            local x=.027-i*.002
            strand(mesh,{V(-x,y-.003,z+.005),V(0,y+.006,z),V(x,y-.001,z-.005)},.003,.0025,laces,5)
        end
        local x=side*.056
        strand(mesh,{V(x,-.043,-.127),V(x*1.08,-.032,-.077),
            V(x*.90,-.009,-.035),V(x*.67,.014,.032)},.004,.004,upperSeam)
    end)
end

function Human.backpack(look)
    local shell=look.pack or look.trim
    local base,trim=dye(shell),dye(look.packTrim or look.shirt)
    local zipper=tone(shell,1.14,{14,16,17})
    local style=look.backpackStyle
    local tall=(style=="roll" or style=="travel" or style==2 or style==3) and 1 or 0
    local travel=style=="travel" or style==3
    return meshModel(function(mesh)
        loft(mesh,{{-.250,.089,.044,.098},{-.237,.124,.066,.113},{-.210,.146,.086,.116},
            {-.148,.152,.102,.127},{-.025,.152,.107,.127},{.086,.150,.105,.122},
            {.153,.146,.094,.106},{.206,.135,.072,.091},{.248+tall*.026,.097,.048,.072},
            {.268+tall*.031,.058,.031,.066}},14,base,function(x,y,z)
                return x*(travel and 1.04 or 1),y,z+(travel and .010 or 0)
            end,look.inks and look.inks.backpack)
        loft(mesh,{{-.208,.054,.020,.187},{-.196,.094,.035,.195},{-.168,.113,.049,.202},
            {-.119,.114,.052,.207},{-.084,.100,.047,.201},{-.057,.077,.033,.193}},12,trim)
        strand(mesh,{V(-.095,-.099,.224),V(-.057,-.083,.244),V(0,-.077,.249),
            V(.055,-.084,.244),V(.096,-.099,.223)},.0035,.0037,zipper)
        strand(mesh,{V(.072,-.084,.241),V(.078,-.107,.245)},.005,.004,zipper)
        if tall==1 then
            strand(mesh,{V(-.095,.255,.087),V(-.067,.286,.126),V(0,.292,.145),
                V(.070,.282,.126),V(.097,.255,.084)},.018,.024,trim,8)
        end
        strand(mesh,{V(-.047,.245,.050),V(-.050,.282,.053),V(-.027,.303,.054),
            V(.030,.303,.054),V(.050,.282,.054),V(.048,.245,.051)},.007,.007,trim)
        for _,side in ipairs(sides) do
            strand(mesh,{V(side*.103,.224,.045),V(side*.111,.273,-.039),
                V(side*.136,.244,-.122),V(side*.144,.154,-.187),V(side*.133,.060,-.202),
                V(side*.128,-.048,-.181),V(side*.132,-.152,-.126),
                V(side*.142,-.191,-.033),V(side*.123,-.217,.058)},.020,.011,trim,7)
            strand(mesh,{V(side*.135,.144,-.196),V(side*.131,.104,-.211),
                V(side*.128,.083,-.211)},.023,.013,zipper)
        end
        if look.carriesStick then
            -- Lashing rings wrap the shaft center fitted to the pack mount in CampusCharacter.
            for _,y in ipairs({-.120,.120}) do
                local x=.166+(y-.04)*math.tan(math.rad(6))
                strand(mesh,{V(.126,y,.097),V(x+.015,y,.096),V(x+.040,y,.117),
                    V(x+.039,y,.142),V(x+.017,y,.161),V(.130,y,.163)},.008,.013,trim,7)
                oval(mesh,x+.038,y,.126,.010,.015,.017,zipper,7)
            end
        end
    end)
end
