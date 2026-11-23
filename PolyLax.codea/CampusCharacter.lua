-- One articulated rig for the Road to Glory player and campus residents.
PolyLax = PolyLax or {}
local P = PolyLax
local Character = {}
P.CampusCharacter = Character

local V = vec3
local sides = {-1,1}
local partCache, surface = {}, nil

local function rgbKey(rgb)
    return rgb and table.concat(rgb,",") or ""
end

local function cache(part, make, key, ...)
    local group = partCache[part]
    if not group then
        group = {keys={},models={}}
        partCache[part] = group
    end
    local model = group.models[key]
    if model then return model end
    model = make(...)
    if #group.keys >= 16 then group.models[table.remove(group.keys,1)] = nil end
    group.keys[#group.keys+1], group.models[key] = key, model
    return model
end

local function node(scene,parent,x,y,z)
    local e = scene:entity()
    if parent then e.parent = parent end
    e.position = V(x or 0,y or 0,z or 0)
    return e
end

local function renderable(scene,parent,x,y,z)
    local e = node(scene,parent,x,y,z)
    if not surface then
        local standard = asset and asset.builtin and asset.builtin.Materials
        surface = craft.material(standard and standard.Standard or "Materials:Standard")
        surface.diffuse, surface.roughness = color(255,255,255), .89
    end
    e.material = surface
    return e
end

function Character.apply(rig,look)
    local geometry = P.CampusHumanMeshes
    local skin,hair,shirt,trim,pants = rgbKey(look.skin),rgbKey(look.hair),rgbKey(look.shirt),
        rgbKey(look.trim),rgbKey(look.pants)
    local patterns = look.patternKeys or {}
    local frame = ({slim=.94,athletic=1,broad=1.065})[look.frame] or 1
    local head = table.concat({look.headShape or "oval",skin,hair,trim,look.haircut or "none",
        tostring(look.beardStyle or look.beard),tostring(look.glasses),tostring(look.earrings)},"/")
    local torso = table.concat({look.outfit,shirt,trim,look.accessory or "",skin,patterns.hoodie or ""},"/")
    rig.root.scale = V((look.width or 1)*frame,look.height or 1,(look.width or 1)*frame)
    rig.face.scale = V(look.faceWidth or 1,look.faceHeight or 1,1)
    rig.face.model = cache("head",geometry.head,head,look)
    rig.neck.model = cache("neck",geometry.neck,skin,look)
    rig.outfit.model = cache("body",geometry.body,torso,look)
    rig.waist.model = cache("pelvis",geometry.pelvis,pants,look)

    for i,side in ipairs(sides) do
        local ending = side < 0 and "Left" or "Right"
        local sleeve = table.concat({look.outfit,shirt,trim,skin,look.frame or "",side},"/")
        local top,bottom = "thigh"..ending,"shin"..ending
        rig.sleeves[i].model = cache("upperArm",geometry.limb,sleeve,look,"upperArm",side)
        rig.forearms[i].model = cache("forearm",geometry.limb,sleeve,look,"forearm",side)
        local leg = table.concat({pants,look.frame or "",look.outfit,side},"/")
        rig.thighs[i].model = cache("thigh",geometry.limb,leg.."/"..(patterns[top] or ""),look,"thigh",side)
        rig.shins[i].model = cache("shin",geometry.limb,leg.."/"..(patterns[bottom] or ""),look,"shin",side)
        rig.thighs[i].material,rig.shins[i].material = surface,surface
        local accessory = side < 0 and look.accessory or ""
        local hand = table.concat({skin,side,accessory or "",trim},"/")
        rig.hands[i].model = cache("hand",geometry.hand,hand,look,side)
        local shoe = table.concat({look.shoeStyle or "court",rgbKey(look.shoe),side},"/")
        rig.feet[i].model = cache("shoe",geometry.shoe,shoe,look,side)
    end

    local hasPack = look.pack or look.accessory == "pack"
    if hasPack then
        if not rig.backpack then
            rig.backpack = renderable(rig.scene,rig.body,0,.300,.094)
        end
        local key = table.concat({rgbKey(look.pack or look.trim),rgbKey(look.packTrim or look.shirt),
            look.backpackStyle or "campus",patterns.backpack or "",tostring(look.carriesStick)},"/")
        rig.backpack.model = cache("pack",geometry.backpack,key,look)
    end
    if rig.backpack then rig.backpack.active = hasPack ~= nil and hasPack ~= false end
    rig.definition = look
end

function Character.new(scene,look)
    local root = node(scene)
    local rig = {scene=scene,root=root,arms={},elbows={},wrists={},legs={},knees={},ankles={},
        sleeves={},forearms={},thighs={},shins={},hands={},feet={}}
    rig.pelvis = node(scene,root,0,1.01,0)
    rig.torso = node(scene,rig.pelvis,0,.060,0)
    rig.body = rig.torso
    rig.waist = renderable(scene,rig.pelvis)
    rig.outfit = renderable(scene,rig.torso)
    rig.neck = renderable(scene,rig.torso,0,.598,0)
    rig.head = node(scene,rig.torso,0,.636,0)
    rig.face = renderable(scene,rig.head,0,.115,0)
    for i,side in ipairs(sides) do
        local shoulder = node(scene,rig.torso,side*.185,.535,0)
        local elbow = node(scene,shoulder,0,-.285,0)
        local wrist = node(scene,elbow,0,-.247,0)
        local hip = node(scene,rig.pelvis,side*.087,0,0)
        local knee = node(scene,hip,0,-.455,0)
        local ankle = renderable(scene,knee,0,-.456,0)
        rig.sleeves[i] = renderable(scene,shoulder)
        rig.forearms[i] = renderable(scene,elbow)
        rig.thighs[i] = renderable(scene,hip)
        rig.shins[i] = renderable(scene,knee)
        rig.hands[i],rig.feet[i] = renderable(scene,wrist),ankle
        rig.arms[i],rig.elbows[i],rig.wrists[i] = shoulder,elbow,wrist
        rig.legs[i],rig.knees[i],rig.ankles[i] = hip,knee,ankle
    end
    Character.apply(rig,look)
    return rig
end
