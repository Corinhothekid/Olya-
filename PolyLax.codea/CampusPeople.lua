-- Stable appearance recipes for named people and authored background spawn slots.
PolyLax = PolyLax or {}
local People = {}
PolyLax.CampusPeople = People

local named = {
    ethan={name="Ethan Cole",role="athlete",height=1.02,width=.97,frame="athletic",
        faceWidth=.97,faceHeight=1.01,headShape="oval",skin={195,134,102},hair={86,47,33},haircut="sweep",
        shirt={40,102,91},trim={126,178,157},pants={48,67,86},shoe={230,232,221},outfit="hoodie",
        shoeStyle="court",accessory="watch",motion="easy"},
    jace={name="Jace Holloway",role="athlete",height=1.06,width=1.04,frame="broad",
        faceWidth=1.04,faceHeight=.98,headShape="angular",skin={126,80,60},hair={26,23,24},haircut="crop",
        shirt={171,63,37},trim={237,218,172},pants={39,48,69},shoe={218,225,230},outfit="varsity",
        shoeStyle="runner",accessory="wristband",motion="athletic"},
    coach={name="Coach Daniel Mercer",role="coach",height=1.03,width=1.02,frame="broad",
        faceWidth=1.03,faceHeight=1.07,headShape="long",skin={200,148,111},hair={98,94,89},
        haircut="neat",beard=true,glasses=true,shirt={43,59,85},trim={150,166,179},pants={88,92,77},
        shoe={111,80,62},outfit="jacket",shoeStyle="boot",accessory="lanyard",motion="measured"},
    maya={name="Maya Brooks",role="journalist",height=.97,width=.94,frame="slim",
        faceWidth=.97,faceHeight=1.02,headShape="round",skin={165,109,83},hair={34,24,29},
        haircut="braids",earrings=true,shirt={80,62,118},trim={235,178,101},pants={52,65,82},
        shoe={228,221,197},outfit="cardigan",shoeStyle="court",accessory="notebook",motion="animated"},
    drip={name="Nina Reyes",role="staff",height=.96,width=.95,frame="slim",
        faceWidth=.96,faceHeight=.99,headShape="oval",skin={150,94,72},hair={41,29,35},
        haircut="bun",earrings=true,shirt={101,78,156},trim={241,160,100},pants={50,47,71},
        shoe={177,147,223},outfit="apron",shoeStyle="runner",accessory="watch",motion="animated"},
    training={name="Trainer Avery",role="coach",height=1.01,width=1.04,frame="athletic",
        faceWidth=1.01,faceHeight=.99,headShape="angular",skin={105,65,50},hair={30,28,36},
        haircut="curls",shirt={30,101,119},trim={224,189,106},pants={52,61,68},
        shoe={208,228,222},outfit="polo",shoeStyle="runner",accessory="lanyard",motion="athletic"}
}

local function copy(source)
    local result={}
    for key,value in pairs(source) do
        result[key]=type(value)=="table" and copy(value) or value
    end
    return result
end

function People.named(id)
    if not named[id] then return end
    local result=copy(named[id])
    result.id=id
    return result
end

-- Used for appearance and animation offsets without consuming gameplay randomness.
function People.seed(key)
    local value=14369
    for i=1,#key do value=(value*131+key:byte(i))%2147483647 end
    return value
end

local skin={{105,66,52},{134,85,64},{165,109,79},{193,133,98},{216,158,119},{235,184,147}}
local hair={{33,29,28},{56,35,32},{101,58,36},{163,105,70},{200,153,94},{101,95,87}}
local shades={
    {{158,67,65},{238,172,117}},{{64,111,126},{164,211,205}},{{137,91,50},{230,187,99}},
    {{66,94,73},{185,201,132}},{{112,78,126},{203,163,196}},{{61,82,123},{160,186,221}},
    {{160,96,53},{242,205,146}},{{83,91,105},{176,192,211}}
}
local pants={{48,59,78},{64,70,69},{69,58,54},{49,61,78}}
local shoes={{216,222,219},{139,107,86},{205,219,191},{128,149,168}}
local headShapes={"oval","angular","round","long"}
local frames={"slim","athletic","broad"}
local haircuts={"sweep","crop","neat","bun","bob","curls","braids"}

local playerSkin={{247,208,174},{213,161,119},{168,110,77},{105,69,52}}
local playerHair={{27,24,25},{27,24,25},{94,59,35},{190,140,69},{132,66,46},{52,39,33}}
local playerHaircuts={"none","crop","sweep","neat","curls","bob"}
local builds={{.96,.97,"slim"},{1,1,"athletic"},{1.025,1,"broad"},{.98,1.10,"athletic"}}

local function choice(profile,key,default,length)
    local value=tonumber(profile[key])
    if value and value>=1 and value<=length and value%1==0 then return value end
    return default
end

function People.player(profile)
    profile=profile or {}
    local face=choice(profile,"FACE",2,#playerSkin)
    local haircut=choice(profile,"HAIR",3,#playerHaircuts)
    local width,height,frame=table.unpack(builds[choice(profile,"BODY",2,#builds)])
    local athlete=PolyLax.Athlete
    return {id="player",role="athlete",width=width,height=athlete and athlete.heightScale(profile) or height,
        frame=frame,headShape=headShapes[face],skin=copy(playerSkin[face]),hair=copy(playerHair[haircut]),
        haircut=playerHaircuts[haircut],beardStyle=choice(profile,"BEARD",1,6),outfit="hoodie",motion="player"}
end

local roles={
    student={outfits={"hoodie","cardigan","varsity"},accessories={"pack","watch","notebook"},motion={"easy","animated","athletic"}},
    coach={outfits={"jacket","polo"},accessories={"lanyard","watch"},motion={"measured","athletic"}},
    staff={outfits={"cardigan","polo","jacket"},accessories={"lanyard","notebook"},motion={"measured","animated"}}
}

local function generated(id,role,key,used)
    local state=People.seed(key)
    local function pick(values)
        state=(state*48271)%2147483647
        return values[state%#values+1]
    end
    local options=roles[role]
    -- Nearby people get different hair silhouettes and primary outfit colors.
    local combinations=#haircuts*#shades
    local combination=state%combinations
    for _=1,combinations do
        if not used[combination] then break end
        combination=(combination+1)%combinations
    end
    used[combination]=true
    local style=haircuts[combination%#haircuts+1]
    local cloth=shades[math.floor(combination/#haircuts)+1]
    local skinTone,frame=pick(skin),pick(frames)
    return {
        id=id,role=role,height=pick({.93,.97,1.01,1.05,1.09}),width=pick({.91,.96,1.01,1.06}),
        frame=frame,faceWidth=pick({.94,1,1.06}),faceHeight=pick({.95,1,1.05}),
        headShape=pick(headShapes),skin=copy(skinTone),hair=copy(pick(hair)),haircut=style,
        shirt=copy(cloth[1]),trim=copy(cloth[2]),pants=copy(pick(pants)),shoe=copy(pick(shoes)),
        outfit=pick(options.outfits),accessory=pick(options.accessories),motion=pick(options.motion),
        shoeStyle=pick({"runner","boot","court"}),glasses=pick({false,false,true})
    }
end

function People.background(zone,slots)
    local order={}
    for i,slot in ipairs(slots) do order[i]=slot end
    table.sort(order,function(a,b) return a.id<b.id end)
    local definitions,used={},{}
    for _,slot in ipairs(order) do
        assert(not definitions[slot.id],"Duplicate campus NPC slot "..slot.id)
        local role=roles[slot.role] and slot.role or "student"
        definitions[slot.id]=generated(slot.id,role,zone.."/"..slot.id.."/"..role,used)
    end
    return definitions
end
