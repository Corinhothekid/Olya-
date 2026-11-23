-- One articulated rig for the Road to Glory player and campus residents.
PolyLax = PolyLax or {}
local P = PolyLax
local Character = {}
P.CampusCharacter = Character

local V = vec3
local sides = {-1,1}
local scale = P.Character.campusScale
local dimensions = P.Character.rigDimensions
local matchScale = V(scale,scale,scale)
local partCache = {}

local function rgbKey(rgb)
    return rgb and table.concat(rgb,",") or ""
end

local function applyMesh(entity, part, make, key, ...)
    local group = partCache[part]
    if not group then
        group = {keys={},models={}}
        partCache[part] = group
    end
    local paint = group.models[key]
    if not paint then
        local model,material = make(...)
        paint = {model=model,material=material}
        if #group.keys >= 16 then group.models[table.remove(group.keys,1)] = nil end
        group.keys[#group.keys+1],group.models[key] = key,paint
    end
    entity.model = paint.model
    entity.material = paint.material
end

local function node(scene,parent,x,y,z)
    local e = scene:entity()
    if parent then e.parent = parent end
    e.position = V(x or 0,y or 0,z or 0)
    return e
end

function Character.apply(rig,look)
    local geometry = P.CampusHumanMeshes
    local skin,shirt,trim,pants = rgbKey(look.skin),rgbKey(look.shirt),
        rgbKey(look.trim),rgbKey(look.pants)
    local patterns = look.patternKeys or {}
    local frame = ({slim=.94,athletic=1,broad=1.065})[look.frame] or 1
    local torso = table.concat({look.outfit,shirt,trim,look.accessory or "",skin,patterns.hoodie or ""},"/")
    rig.root.scale = V((look.width or 1)*frame,look.height or 1,(look.width or 1)*frame)
    rig.head.scale = V(scale*(look.faceWidth or 1),scale*(look.faceHeight or 1),scale)
    P.Character.applyCampusHead(rig,look)
    applyMesh(rig.outfit,"body",geometry.body,torso,look)
    applyMesh(rig.waist,"pelvis",geometry.pelvis,pants,look)

    for i,side in ipairs(sides) do
        local ending = side < 0 and "Left" or "Right"
        local sleeve = table.concat({look.outfit,shirt,trim,skin,look.frame or "",side},"/")
        local top,bottom = "thigh"..ending,"shin"..ending
        applyMesh(rig.sleeves[i],"upperArm",geometry.limb,sleeve,look,"upperArm",side)
        applyMesh(rig.forearms[i],"forearm",geometry.limb,sleeve,look,"forearm",side)
        local leg = table.concat({pants,look.frame or "",look.outfit,side},"/")
        applyMesh(rig.thighs[i],"thigh",geometry.limb,leg.."/"..(patterns[top] or ""),look,"thigh",side)
        applyMesh(rig.shins[i],"shin",geometry.limb,leg.."/"..(patterns[bottom] or ""),look,"shin",side)
        local accessory = side < 0 and look.accessory or ""
        local hand = table.concat({skin,side,accessory or "",trim},"/")
        applyMesh(rig.hands[i],"hand",geometry.hand,hand,look,side)
        local shoe = table.concat({look.shoeStyle or "court",rgbKey(look.shoe),side},"/")
        applyMesh(rig.feet[i],"shoe",geometry.shoe,shoe,look,side)
    end

    local hasPack = look.pack or look.accessory == "pack"
    if hasPack then
        if not rig.backpack then
            rig.backpack = node(rig.scene,rig.body,0,.31,.14)
        end
        local key = table.concat({rgbKey(look.pack or look.trim),rgbKey(look.packTrim or look.shirt),
            look.backpackStyle or "campus",patterns.backpack or "",tostring(look.carriesStick)},"/")
        applyMesh(rig.backpack,"pack",geometry.backpack,key,look)
    end
    if rig.backpack then rig.backpack.active = hasPack ~= nil and hasPack ~= false end
    rig.definition = look
end

function Character.new(scene,look)
    local root = node(scene)
    local rig = {scene=scene,root=root,arms={},elbows={},wrists={},legs={},knees={},ankles={},
        sleeves={},forearms={},thighs={},shins={},hands={},feet={}}
    rig.pelvis = node(scene,root,0,dimensions.pelvis*scale,0)
    rig.torso = node(scene,rig.pelvis)
    rig.body = rig.torso
    rig.waist = node(scene,rig.pelvis)
    rig.outfit = node(scene,rig.torso)
    rig.neck = node(scene,rig.torso)
    rig.neck.scale = matchScale
    rig.head = node(scene,rig.torso,0,dimensions.headY*scale,0)
    rig.face = node(scene,rig.head)
    for i,side in ipairs(sides) do
        local shoulder = node(scene,rig.torso,side*dimensions.shoulderX*scale,dimensions.shoulderY*scale,0)
        local elbow = node(scene,shoulder,0,-dimensions.armUpper*scale,0)
        local wrist = node(scene,elbow,0,-dimensions.armLower*scale,0)
        local hip = node(scene,rig.pelvis,side*dimensions.hipX*scale,0,0)
        local knee = node(scene,hip,0,-dimensions.legUpper*scale,0)
        local ankle = node(scene,knee,0,-dimensions.legLower*scale,0)
        rig.sleeves[i] = node(scene,shoulder)
        rig.forearms[i] = node(scene,elbow)
        rig.thighs[i] = node(scene,hip)
        rig.shins[i] = node(scene,knee)
        rig.hands[i],rig.feet[i] = node(scene,wrist),ankle
        rig.arms[i],rig.elbows[i],rig.wrists[i] = shoulder,elbow,wrist
        rig.legs[i],rig.knees[i],rig.ankles[i] = hip,knee,ankle
    end
    Character.apply(rig,look)
    return rig
end
