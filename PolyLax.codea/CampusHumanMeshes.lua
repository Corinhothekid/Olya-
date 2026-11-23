-- Faceted clothing and gear for the campus version of the game rig. Local front is -Z.
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
    return PolyLax.CraftPalette.build(mesh)
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
local function surface(mesh,count,n,point,ink)
    local start=#mesh.positions
    local angles=ringAngles(n)
    for row=1,count do
        local v=(row-1)/(count-1)
        for _,angle in ipairs(angles) do
            local s,c,u=angle[1],angle[2],angle[3]
            vertex(mesh,point(row,s,c),ink,u,v)
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
local function loft(mesh,rings,n,ink)
    surface(mesh,#rings,n,function(row,s,c)
        local ring=rings[row]
        local x,y,z=(ring[5] or 0)+ring[2]*s,ring[1],(ring[4] or 0)-ring[3]*c
        return V(x,y,z)
    end,ink)
end

-- The game rig's eight-sided contours meet at visible facet edges. Keep the
-- same crease on campus clothes and avoid a separate smooth-surface style.
local function classicLoft(mesh,rings,ink,sample)
    local rows={}
    for i,ring in ipairs(rings) do
        local row={}
        for side=0,7 do
            local angle=side*tau/8+math.pi/8
            local x,z=sin(angle),cos(angle)
            local scale=math.max(math.abs(x),math.abs(z))
            row[side+1]=V((ring[5] or 0)+ring[2]*x/scale,ring[1],(ring[4] or 0)-ring[3]*z/scale)
        end
        rows[i]=row
    end
    for i=1,#rows-1 do
        local bottom,top=rows[i],rows[i+1]
        local low,high=(i-1)/(#rows-1),i/(#rows-1)
        for side=1,8 do
            local nextSide=side%8+1
            local left,right=(side-1)/8,side/8
            local paint=sample and sample((left+right)*.5,(low+high)*.5,ink) or ink
            local a=vertex(mesh,bottom[side],paint,left,low)
            local b=vertex(mesh,top[side],paint,left,high)
            local c=vertex(mesh,top[nextSide],paint,right,high)
            local d=vertex(mesh,bottom[nextSide],paint,right,low)
            triangle(mesh,a,b,c)
            triangle(mesh,a,c,d)
        end
    end
    for _,i in ipairs({1,#rings}) do
        local ring,row=rings[i],rows[i]
        local center=vertex(mesh,V(ring[5] or 0,ring[1],ring[4] or 0),ink,.5,.5)
        local indices={}
        for side=1,8 do indices[side]=vertex(mesh,row[side],ink,.5,.5) end
        for side=1,8 do
            local a,b=indices[side],indices[side%8+1]
            if i==1 then triangle(mesh,center,a,b) else triangle(mesh,center,b,a) end
        end
    end
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

local atan2=math.atan2 or math.atan

local function addMatchMesh(mesh,source,ink,sample,low,high)
    local offset=#mesh.positions
    local positions,normals=source.positions,source.normals
    local rigScale=PolyLax.Character.campusScale
    for i,p in ipairs(positions) do
        local u=(atan2(p.x,-p.z)/tau)%1
        local v=low and math.max(0,math.min(1,(p.y-low)/(high-low))) or .5
        local index=vertex(mesh,p*rigScale,sample and sample(u,v,ink) or ink,u,v)
        mesh.normals[index]=normals[i]
    end
    for _,index in ipairs(source.indices) do
        mesh.indices[#mesh.indices+1]=offset+index
    end
end

local function classicBevel(mesh,x,y,z,w,h,d,ink)
    classicLoft(mesh,{{y-h*.5,w*.38,d*.38,z,x},{y-h*.3,w*.5,d*.5,z,x},
        {y+h*.3,w*.5,d*.5,z,x},{y+h*.5,w*.38,d*.38,z,x}},ink)
end

function Human.body(look)
    local cloth,trim=dye(look.shirt),dye(look.trim)
    local edge=tone(look.shirt,.70)
    return meshModel(function(mesh)
        local outfit=look.outfit
        if outfit=="hoodie" then
            local body,details=PolyLax.Character.campusApparel("hoodie")
            addMatchMesh(mesh,body,cloth,look.inks and look.inks.hoodie,.040,1.095)
            addMatchMesh(mesh,details,trim)
        else
            addMatchMesh(mesh,PolyLax.Character.campusApparel("jersey"),cloth)
            if outfit=="jacket" or outfit=="varsity" or outfit=="cardigan" then
                strand(mesh,{V(0,.162,-.155),V(0,.337,-.168),V(0,.503,-.164),V(0,.607,-.136)},
                    .007,.006,outfit=="varsity" and trim or edge)
                for _,side in ipairs(sides) do
                    strand(mesh,{V(side*.058,.634,-.111),V(side*.105,.590,-.147),
                        V(side*.129,.555,-.160)},.012,.008,trim)
                    strand(mesh,{V(side*.102,.250,-.166),V(side*.158,.220,-.165),
                        V(side*.193,.189,-.156)},.006,.004,edge)
                end
                if outfit=="cardigan" then
                    for i=1,3 do oval(mesh,.011,.175+i*.105,-.174,.007,.007,.004,trim,6) end
                end
            elseif outfit=="polo" then
                for _,side in ipairs(sides) do
                    strand(mesh,{V(side*.041,.630,-.124),V(side*.083,.603,-.143),
                        V(side*.116,.560,-.165),V(side*.066,.555,-.166)},.013,.010,trim)
                end
                strand(mesh,{V(0,.598,-.148),V(0,.544,-.165),V(0,.488,-.174)},.009,.006,edge)
            elseif outfit=="apron" then
                classicLoft(mesh,{{.144,.162,.016,-.151},{.195,.175,.019,-.157},
                    {.369,.177,.020,-.164},{.496,.144,.019,-.163},
                    {.553,.105,.014,-.157}},trim)
                strand(mesh,{V(-.096,.535,-.171),V(-.101,.599,-.149),V(-.052,.647,-.110),
                    V(.052,.647,-.110),V(.101,.599,-.149),V(.096,.535,-.171)},.012,.006,trim)
            end
        end
        if look.accessory=="lanyard" then
            strand(mesh,{V(-.056,.626,-.122),V(-.066,.571,-.168),V(-.044,.475,-.184),
                V(-.017,.379,-.183),V(.022,.381,-.183),V(.052,.475,-.184),
                V(.069,.571,-.168),V(.056,.626,-.122)},.005,.005,trim)
            classicBevel(mesh,.008,.349,-.185,.042,.060,.013,chalk)
        end
    end)
end

function Human.pelvis(look)
    return meshModel(function(mesh)
        -- The joint sits inside the waistband and the two thighs overlap its lower edge.
        classicLoft(mesh,{{-.149,.133,.080,.009},{-.117,.200,.104,.009},
            {-.061,.249,.143,.009},{.001,.265,.150,.007},{.068,.272,.148,.005},
            {.121,.254,.139,.004},{.158,.218,.123,.003}},dye(look.pants))
    end)
end

local legRings={
    thigh={{-.379,.075,.078,.004},{-.358,.091,.094,.003},{-.310,.104,.110,.005},
        {-.211,.113,.124,.010},{-.104,.123,.131,.014},{.006,.131,.135,.018},{.058,.101,.114,.018}},
    shin={{-.349,.058,.064,0},{-.331,.065,.074,0},{-.282,.072,.086,.004},
        {-.195,.089,.101,.005},{-.108,.097,.110,.006},{-.035,.091,.102,.004},{.034,.073,.088,.002}}
}

function Human.limb(look,part,side)
    local isLeg=legRings[part]~=nil
    local upper=part=="upperArm"
    local short=look.outfit=="polo" or look.outfit=="apron"
    local skin,cloth=dye(look.skin),dye(look.outfit=="varsity" and look.trim or look.shirt)
    return meshModel(function(mesh)
        if isLeg then
            local ending=side<0 and "Left" or "Right"
            local sample=look.inks and look.inks[part..ending]
            classicLoft(mesh,legRings[part],dye(look.pants),sample)
            if part=="shin" and look.outfit=="hoodie" and not sample then
                classicBevel(mesh,0,-.322,-.002,.137,.042,.156,tone(look.pants,.82))
            end
        elseif short then
            if upper then
                classicBevel(mesh,0,-.138,0,.157,.276,.158,skin)
                classicBevel(mesh,0,-.035,0,.209,.197,.236,cloth)
                classicBevel(mesh,0,-.108,-.005,.201,.037,.200,
                    look.outfit=="polo" and dye(look.trim) or tone(look.shirt,.82))
            else
                classicBevel(mesh,0,-.108,0,.143,.252,.158,skin)
            end
        else
            addMatchMesh(mesh,PolyLax.Character.campusApparel(part),cloth)
            if part=="forearm" and look.outfit=="varsity" then
                classicBevel(mesh,0,-.190,0,.153,.036,.172,dye(look.shirt))
            end
        end
    end)
end

function Human.hand(look,side)
    local skin=dye(look.skin)
    return meshModel(function(mesh)
        classicBevel(mesh,0,-.072,-.010,.107,.168,.091,skin)
        classicBevel(mesh,side*.043,-.061,-.033,.047,.091,.049,skin)
        if side==-1 and (look.accessory=="watch" or look.accessory=="wristband") then
            classicBevel(mesh,0,-.015,-.008,.114,.035,.102,dye(look.trim))
            if look.accessory=="watch" then
                classicBevel(mesh,0,-.013,-.064,.037,.036,.014,charcoal)
            end
        elseif side==-1 and look.accessory=="notebook" then
            classicBevel(mesh,-.014,-.095,-.073,.113,.147,.025,dye(look.trim))
            classicBevel(mesh,-.010,-.095,-.081,.090,.133,.013,chalk)
        end
    end)
end

function Human.shoe(look,side)
    local upper=dye(look.shoe)
    local sole=tone(look.shoe,.30,{14,13,12})
    local line=tone(look.shoe,.79)
    local boot=look.shoeStyle=="boot"
    local runner=look.shoeStyle=="runner"
    local ground=-PolyLax.Character.rigDimensions.ankle*PolyLax.Character.campusScale
    return meshModel(function(mesh)
        classicLoft(mesh,{{ground,.103,.164,-.069},{-.089,.113,.177,-.070},
            {-.072,.110,.174,-.069},{runner and -.053 or -.062,.106,.169,-.068}},sole)
        classicLoft(mesh,{{-.075,.108,.170,-.068},{-.028,.111,.164,-.062},
            {.035,.091,.116,-.033},{boot and .095 or .063,.073,.087,.007}},upper)
        for i=0,2 do
            local y,z=.026+i*.013,-.156+i*.033
            strand(mesh,{V(-.048,y,z),V(.048,y,z)},.005,.005,boot and line or chalk,5)
        end
        classicBevel(mesh,side*.069,.013,.041,.035,.038,.038,line)
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
        local width=travel and .160 or .152
        classicLoft(mesh,{{-.250,.091,.044,.098},{-.223,.143,.078,.111},
            {-.152,width,.102,.126},{.146,width,.093,.107},
            {.216,.136,.071,.094},{.265+tall*.025,.064,.036,.069}},
            base,look.inks and look.inks.backpack)
        classicLoft(mesh,{{-.208,.056,.020,.187},{-.189,.104,.037,.197},
            {-.124,.114,.052,.207},{-.079,.103,.045,.199},{-.057,.077,.033,.193}},trim)
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
            strand(mesh,{V(side*.103,.224,.045),V(side*.161,.289,-.070),
                V(side*.202,.255,-.208),V(side*.205,.176,-.310),V(side*.187,.065,-.330),
                V(side*.186,-.079,-.311),V(side*.199,-.166,-.227),
                V(side*.186,-.205,-.078),V(side*.123,-.217,.058)},.020,.011,trim,6)
            strand(mesh,{V(side*.201,.16,-.318),V(side*.195,.119,-.330),
                V(side*.190,.102,-.333)},.023,.013,zipper)
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
