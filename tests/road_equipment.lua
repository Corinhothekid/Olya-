-- Standalone Drip Lab, wallet and equipment appearance checks using the Craft test double.
local helpers = arg and arg[0] and arg[0]:match("^(.*[/])")
    or os.getenv("POLYLAX_TEST_CHECKS") or "tests/"
local project = arg and arg[1] or os.getenv("POLYLAX_TEST_PROJECT") or "PolyLax.codea"
local loaded=io.open(helpers.."craft_mock.lua")
if not loaded then helpers="PolyLax-3.3-Checks/" else loaded:close() end
dofile(helpers.."craft_mock.lua")
for _,tab in ipairs({"TeamUniform","Profile","Character","AnimationController","CameraController","UI",
    "Style","CampusPeople","CraftPalette","CampusHumanMeshes","CampusCharacter","CampusMotion","RoadEquipment","RoadEquipmentUI"}) do
    dofile(project.."/"..tab..".lua")
end

local E,Shop = PolyLax.RoadEquipment,PolyLax.RoadEquipmentUI
local appearance=PolyLax.Profile.load()
local kit=E.restore({equipped={shaftPattern=14},credits=-2,owned={bogus=true}})
assert(kit.credits==0 and kit.equipped.shaftPattern==1 and next(kit.owned)==nil)
kit=E.restore()
assert(#E.patterns==14 and kit.credits==240, "Base wallet or Pattern Vault changed")
local started=kit
local candidate=assert(E.change(kit,"buy","shaftPattern",2))
assert(kit==started and kit.credits==240 and candidate.credits==205)
assert(candidate.equipped.shaftPattern==1 and E.owns(candidate,"shaftPattern",2))
assert(not E.change(candidate,"buy","shaftPattern",2))
assert(not E.change(candidate,"equip","shaftPattern",3))
assert(not E.change(candidate,"buy","shaftPattern",100))
assert(not E.change(candidate,"buy","missing",1))
kit=assert(E.change(candidate,"equip","shaftPattern",2))
assert(kit.equipped.shaftPattern==2)
kit=assert(E.change(kit,"buy","leftSleeve",3))
kit=assert(E.change(kit,"equip","leftSleeve",3))
kit=assert(E.change(kit,"buy","leftSleevePattern",3))
kit=assert(E.change(kit,"equip","leftSleevePattern",3))
kit=assert(E.change(kit,"buy","gloveFinish",2))
kit=assert(E.change(kit,"equip","gloveFinish",2))
kit=assert(E.change(kit,"savePreset",nil,1))
local previous=assert(E.change(kit,"equip","shaftPattern",1))
kit=assert(E.change(previous,"loadPreset",nil,1))
assert(kit.equipped.shaftPattern==2 and kit.equipped.leftSleeve==3
    and kit.equipped.leftSleevePattern==3 and kit.equipped.rightSleeve==1)
assert(not E.change(kit,"loadPreset",nil,2))
assert(not E.change(kit,"savePreset",nil,0))

local resume=E.restore(kit)
local rig=E.newCasual(craft.scene(),appearance,resume,"long")
local animation=PolyLax.CampusMotion.new(rig,"player",0)
local stick,anchor=rig.stickRoot,rig.backpackStick
assert(stick.parent==anchor and anchor.parent==rig.backpack and rig.backpack.parent==rig.body)
assert(rig.roadStick.upper.active and rig.stickType=="long")
assert(rig.definition.patternKeys.thighLeft and rig.definition.patternKeys.shinLeft)
assert(not rig.definition.patternKeys.shinRight and not rig.definition.patternKeys.thighRight)
local left=rig.shins[1].model
local plain=E.preview(resume,"leftSleeve",1)
local pieces=#rig.scene.entities
E.applyCasual(rig,appearance,plain,"long")
assert(rig.shins[1].model~=left and not rig.definition.patternKeys.shinLeft)
E.applyCasual(rig,appearance,resume,"long")
assert(rig.shins[1].model==left and #rig.scene.entities==pieces,"Sleeve edits rebuilt the avatar")
for _,entry in ipairs({{"hoodiePattern",2,"hoodie",rig.outfit},
    {"joggerPattern",3,"shinRight",rig.shins[2]},{"backpackPattern",4,"backpack",rig.backpack}}) do
    E.applyCasual(rig,appearance,resume,"long")
    local field,option,key,part=table.unpack(entry)
    local plainModel=part.model
    E.applyCasual(rig,appearance,E.preview(resume,field,option),"long")
    assert(part.model~=plainModel and rig.definition.patternKeys[key],
        "Pattern does not follow the clothing mesh for "..field)
    local shades={}
    for _,uv in ipairs(part.model.uvs) do shades[uv.x..":"..uv.y]=true end
    local colorCount=0
    for _ in pairs(shades) do colorCount=colorCount+1 end
    assert(part.material.map and colorCount>=3,"Pattern material is missing colors for "..field)
end
local before=stick.worldPosition
rig.root.position=vec3(2,0,-2)
rig.root.eulerAngles=vec3(0,57,0)
for _=1,20 do
    PolyLax.CampusMotion.update(animation,.016,"walk",3.5,.2)
    rig.root.position=vec3(2,animation.bob,-2)
end
assert((stick.worldPosition-anchor.worldPosition):len()<.00001
    and (stick.worldPosition-before):len()>1, "The stowed stick came off the backpack")
assert(rig.roadStick.upper.model.colors and #rig.roadStick.upper.model.colors>35)

local gameRig=PolyLax.Character.new(craft.scene())
PolyLax.Character.setStickType(gameRig,"goalie")
local originalPocket=gameRig.pocket.position
E.applyMatch(gameRig,resume)
assert(gameRig.stickRoot.parent==gameRig.body and gameRig.roadStick.goalieStrings.active)
assert(gameRig.materials.gloves.metalness>.7 and gameRig.materials.gloves.roughness<.2)
assert(gameRig.sleeveParts.left[1].active and gameRig.roadMatch.sleeves.left.thigh.active)
assert(not gameRig.sleeveParts.right[1].active and not gameRig.roadMatch.sleeves.right.shin.active)
assert((gameRig.pocket.position-originalPocket):len()<.0001)
local count=#gameRig.scene.entities
for i=2,#E.patterns do
    E.applyMatch(gameRig,E.preview(resume,"shaftPattern",i))
    assert(gameRig.roadStick.upper.active and gameRig.roadStick.upper.model.colors[1])
end
assert(#gameRig.scene.entities==count,"Pattern changes allocated more entities")

local saved,deny=nil,true
local view=Shop.new(craft.scene(),appearance,E.restore(),"short",function(nextKit)
    if deny then return false,"Write failed" end
    saved=nextKit
    return true
end)
local function tap(name)
    local item=assert(Shop.layout(view).byId[name],name)
    return Shop.touch(view,{id=1,x=item.x,y=item.y,state=BEGAN})
end
tap("VALUE_NEXT")
assert(view.choice==2 and view.rig.roadStick.upper.active and not E.owns(view.kit,"shaftPattern",2))
tap("BUY")
assert(view.kit.credits==240 and not saved)
deny=false
tap("BUY")
assert(saved.credits==205 and saved.equipped.shaftPattern==1)
tap("EQUIP")
assert(saved.equipped.shaftPattern==2)
tap("PRESETS")
tap("SAVE_PRESET")
assert(saved.presets["1"].shaftPattern==2)
tap("OUTFIT")
assert(view.rig.campus and view.rig.stickRoot.parent==view.rig.backpackStick)
local casualRig, entities=view.rig,#view.scene.entities
tap("GLOVES")
assert(not view.rig.campus and view.rig.stickRoot.parent==view.rig.body)
assert(not casualRig.root.active and view.rig.root.active)
tap("OUTFIT")
assert(view.rig==casualRig and not view.matchRig.root.active and #view.scene.entities==entities)
tap("GLOVES")
for _,size in ipairs({{320,568},{390,844},{430,932}}) do
    WIDTH,HEIGHT=size[1],size[2]
    local layout=Shop.layout(view)
    assert(layout.previewTop-layout.previewBottom>=100)
    for _,item in ipairs(layout.items) do
        assert(item.x-item.w/2>=0 and item.x+item.w/2<=WIDTH)
        assert(item.y-item.h/2>=0 and item.y+item.h/2<=HEIGHT)
    end
    Shop.draw(view,.016)
end
assert(tap("BACK")=="BACK")
print("Drip Lab: purchases, save rollback, presets, 13 patterns, independent sleeves, chrome, and stowed stick transform verified.")
