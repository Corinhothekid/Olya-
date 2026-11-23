-- Drip Lab previews are local to the shop. Only a confirmed save changes the career.
PolyLax = PolyLax or {}
local P = PolyLax
local Shop = {}
P.RoadEquipmentUI = Shop

local colors = {
    ink=color(19,27,34), shadow=color(8,13,17), panel=color(23,34,43),
    line=color(50,68,81), highlight=color(23,84,64), mint=color(129,240,187),
    paper=color(238,247,247), subdued=color(163,182,191), gold=color(239,190,110)
}

local function field(view)
    local section=P.RoadEquipment.sections[view.section]
    return section.fields and section.fields[view.field]
end

local function cycle(value,offset,count)
    return (value-1+offset)%count+1
end

local function refresh(view)
    local equipment=P.RoadEquipment
    local selected=field(view)
    local preview=selected and equipment.preview(view.kit,selected[1],view.choice) or view.kit
    if view.section==3 and selected then
        -- Preview different threads even before the player buys the sleeve itself.
        local side=selected[1]:match("^left") and "left" or "right"
        local style=side.."Sleeve"
        if selected[1]~=style and preview.equipped[style]==1 then preview.equipped[style]=3 end
    end
    if view.section>=4 then
        if not view.casualRig then
            view.casualRig=equipment.newCasual(view.scene,view.profile,preview,view.stickType)
            view.casualMotion=P.CampusMotion.new(view.casualRig,"player",0)
        else
            equipment.applyCasual(view.casualRig,view.profile,preview,view.stickType)
        end
        view.matchRig.root.active,view.casualRig.root.active=false,true
        view.rig=view.casualRig
    else
        local rig=view.matchRig
        if view.casualRig then view.casualRig.root.active=false end
        rig.root.active=true
        view.rig=rig
        P.Character.apply(rig,view.profile)
        P.Character.setStickType(rig,view.stickType)
        equipment.applyMatch(rig,preview)
    end
end

function Shop.new(scene,profile,kit,stickType,onSave)
    local view={
        scene=scene,profile=profile,kit=P.RoadEquipment.restore(kit),stickType=stickType or "short",
        onSave=onSave,section=1,field=1,preset=1,elapsed=0,heading=-14,goalHeading=-14
    }
    view.choice=view.kit.equipped.shaftPattern
    view.matchRig=P.Character.new(scene)
    view.camera=P.CameraController.new(scene,38)
    view.camera.lens.farPlane=45
    local stage=scene:entity()
    local standard=asset and asset.builtin and asset.builtin.Materials
    stage.model=craft.model.cube()
    stage.material=craft.material(standard and standard.Standard or "Materials:Standard")
    stage.material.diffuse=color(50,76,79)
    stage.position,stage.scale=vec3(0,-.086,0),vec3(3.4,.16,3.3)
    refresh(view)
    view.animation=P.AnimationController.new(view.matchRig)
    return view
end

local function add(layout,id,label,x,y,w,h,selected,enabled)
    local item={id=id,label=label,x=x,y=y,w=w,h=h,selected=selected,enabled=enabled~=false}
    layout.items[#layout.items+1]=item
    layout.byId[id]=item
    return item
end

function Shop.layout(view)
    local safe=P.UI.safeArea()
    local width=math.min(504,WIDTH-safe.left-safe.right-22)
    local mid=(WIDTH+safe.left-safe.right)*.5
    local top,bottom=HEIGHT-safe.top-8,safe.bottom+10
    local L={items={},byId={},width=width,mid=mid,top=top,bottom=bottom}
    L.topRow,L.tabsY=top-23,top-69
    local left,right=mid-width*.5,mid+width*.5
    if view.textureTesting then
        L.previewBottom,L.previewTop=bottom+100,top-55
        L.editorTop=L.previewBottom
        add(L,"TEXTURE_BACK","Back",left+33,L.topRow,66,38)
        return L
    end
    L.editorTop=bottom+176
    L.previewBottom,L.previewTop=L.editorTop+4,L.tabsY-22
    L.fieldY,L.valueY,L.actionY=bottom+134,bottom+84,bottom+25
    add(L,"BACK","Exit",left+33,L.topRow,66,38)
    add(L,"TEXTURE_TEST","Texture Test",right-48,L.topRow,96,38)
    local sections=P.RoadEquipment.sections
    local step=width/#sections
    for number,tab in ipairs(sections) do
        add(L,tab.id,tab.label,left+(number-.5)*step,L.tabsY,step-4,36,number==view.section)
    end
    if view.section==5 then
        local p=tostring(view.preset)
        local preset=view.kit.presets[p]
        L.fieldLabel="Look "..p
        L.valueLabel=preset and "Saved equipment and outfit" or "Empty preset"
        add(L,"VALUE_PREV","‹",left+23,L.valueY,46,42)
        add(L,"VALUE_NEXT","›",right-23,L.valueY,46,42)
        local w=(width-8)*.5
        add(L,"SAVE_PRESET","Save look",mid-(w+8)*.5,L.actionY,w,44,true)
        add(L,"LOAD_PRESET","Equip look",mid+(w+8)*.5,L.actionY,w,44,false,preset~=nil)
    else
        local selected=field(view)
        local id,count=selected[1],#P.RoadEquipment.sections[view.section].fields
        L.fieldLabel=selected[2]
        L.fieldCount=view.field.." / "..count
        L.valueLabel=selected[3][view.choice]
        local textureReady=P.RoadEquipment.patternStatus(id,view.choice)
        L.valueUnavailable=textureReady==false
        add(L,"FIELD_PREV","‹",left+23,L.fieldY,46,42)
        add(L,"FIELD_NEXT","›",right-23,L.fieldY,46,42)
        add(L,"VALUE_PREV","‹",left+23,L.valueY,46,42)
        add(L,"VALUE_NEXT","›",right-23,L.valueY,46,42)
        if view.choice==view.kit.equipped[id] then
            add(L,"EQUIP","Equipped",mid,L.actionY,width,44,false,false)
        elseif P.RoadEquipment.owns(view.kit,id,view.choice) then
            add(L,"EQUIP","Equip",mid,L.actionY,width,44,true)
        elseif L.valueUnavailable then
            add(L,"TEXTURE_UNAVAILABLE","Texture unavailable",mid,L.actionY,width,44,false,false)
        else
            add(L,"BUY","Buy • "..selected[5].." credits",mid,L.actionY,width,44,true,
                view.kit.credits>=selected[5])
        end
    end
    return L
end

local function label(value,x,y,size,ink,width)
    if not value then return end
    fontSize(size)
    if textSize and width then
        local actual=textSize(value)
        if actual>width then fontSize(math.max(9,size*width/actual)) end
    end
    fill(ink)
    text(value,x,y)
end

local function panel(x,y,w,h,corner,ink)
    P.Style.rounded(x,y,w,h,corner,ink)
end

local function drawButton(item)
    local fillColor=item.selected and colors.highlight or colors.panel
    local strokeColor=item.selected and colors.mint or colors.line
    panel(item.x,item.y,item.w,item.h,10,strokeColor)
    panel(item.x,item.y,item.w-2,item.h-2,9,fillColor)
    label(item.label,item.x,item.y,(item.label=="‹" or item.label=="›") and 24 or 14,
        item.enabled and colors.paper or colors.subdued,item.w-10)
end

local function renderPreview(view,L,dt)
    local rig=view.rig
    view.heading=view.heading+(view.goalHeading-view.heading)*(1-math.exp(-dt*15))
    rig.root.eulerAngles=vec3(0,view.heading,0)
    local height
    if rig.campus then
        P.CampusMotion.update(view.casualMotion,dt,"idle",0)
        rig.root.position=vec3(0,view.casualMotion.bob,0)
        height=rig.root.scale.y
    else
        P.AnimationController.update(view.animation,dt,{speed=0})
        height=rig.proportions.scale.y
    end
    local equipmentY,objectSpan,radius=1.45*height,3.12*height,1.45
    if rig.campus then equipmentY,objectSpan,radius=1.22*height,2.62*height,.84 end
    if view.section==2 then equipmentY,objectSpan,radius=1.57*height,1.56*height,1.02 end
    if view.section==3 then equipmentY,objectSpan,radius=.58*height,1.29*height,.73 end
    local t=view.camera.tanHalf
    local visible=math.max(.27,(L.previewTop-L.previewBottom)/HEIGHT)
    local dist=math.max(radius/(t*WIDTH/HEIGHT*.87),objectSpan/(2*t*visible*.87))
    local q=(L.previewTop+L.previewBottom)/HEIGHT-1
    local eyeY=equipmentY-q*dist*t
    local eye=vec3(0,eyeY,-dist)
    view.camera.entity.position=eye
    view.camera.entity.rotation=quat.lookRotation(vec3(0,0,1),vec3(0,1,0))
    view.scene:update(dt)
    view.scene:draw()
end

local function openTextureTest(view)
    if not view.texturePreview then
        local scene=craft.scene()
        scene.ambientColor=color(170,180,198)
        scene.sun.rotation=quat.eulerAngles(39,23,0)
        local test=P.RoadEquipment.textureTest(scene)
        test.scene=scene
        test.camera=P.CameraController.new(scene,38)
        test.heading,test.goalHeading=0,0
        view.texturePreview=test
    end
    view.textureTesting=true
    view.drag=nil
end

local function renderTextureTest(test,L,dt)
    test.heading=test.heading+(test.goalHeading-test.heading)*(1-math.exp(-dt*15))
    for _,shaft in ipairs(test.shafts) do shaft.root.eulerAngles=vec3(0,test.heading,0) end
    local camera=test.camera
    local t=camera.tanHalf
    local h=L.previewTop-L.previewBottom
    local distance=.15+math.max(test.radius/(t*L.width/HEIGHT*.91),test.height/(2*t*h/HEIGHT*.9))
    local projection=HEIGHT/(2*distance*t)
    local centerY=(L.previewTop+L.previewBottom)*.5
    camera.entity.position=vec3((WIDTH*.5-L.mid)/projection,
        (test.centerY or 0)+(HEIGHT*.5-centerY)/projection,-distance)
    camera.entity.rotation=quat.lookRotation(vec3(0,0,1),vec3(0,1,0))
    test.scene:update(dt)
    test.scene:draw()
end

local textureErrors={
    ["Missing asset"]="Missing",
    ["Image load failed"]="Read failed",
    ["Craft map rejected"]="Map rejected"
}

local function drawTextureLabels(test,L)
    local labelWidth=L.width/#test.shafts-4
    label("Texture Test",L.mid,L.topRow,21,colors.paper,L.width-145)
    for _,shaft in ipairs(test.shafts) do
        local screen=P.CameraController.project(test.camera,shaft.root.worldPosition)
        if screen then
            label("asset."..shaft.key,screen.x,L.bottom+67,12,colors.paper,labelWidth)
            local status=shaft.loaded and "Loaded" or textureErrors[shaft.status] or "Unavailable"
            label(status,screen.x,L.bottom+47,11,
                shaft.loaded and colors.mint or colors.gold,labelWidth)
        end
    end
    label("Drag to rotate all four shafts",L.mid,L.bottom+16,13,colors.subdued,L.width)
end

function Shop.draw(view,dt)
    dt=math.max(0,math.min(dt or 0,.05))
    local L=Shop.layout(view)
    view.elapsed=view.elapsed+dt
    if view.messageTime and view.elapsed>=view.messageTime then view.message=nil end
    if view.textureTesting then renderTextureTest(view.texturePreview,L,dt)
    else renderPreview(view,L,dt) end
    pushStyle()
    pushMatrix()
    resetMatrix()
    ortho()
    viewMatrix(matrix())
    rectMode(CORNER)
    textMode(CENTER)
    textAlign(CENTER)
    noStroke()
    font("AvenirNext-DemiBold")
    fill(colors.shadow)
    rect(0,0,WIDTH,L.editorTop)
    rect(0,L.previewTop,WIDTH,HEIGHT-L.previewTop)
    if view.textureTesting then
        drawTextureLabels(view.texturePreview,L)
    else
        local cx=L.mid
        label("Drip Lab",cx,L.topRow+7,20,colors.paper,L.width-202)
        label(tostring(view.kit.credits).." cr",cx,L.topRow-12,13,colors.gold,82)
        label("Drag preview to rotate",cx,L.previewBottom+14,12,colors.paper,L.width)
        label(L.fieldLabel,cx,L.fieldY+6,17,colors.paper,L.width-106)
        label(L.fieldCount,cx,L.fieldY-14,11,colors.subdued,55)
        label(L.valueLabel,cx,L.valueY,16,L.valueUnavailable and colors.gold or colors.mint,L.width-108)
        if L.valueUnavailable then
            label("Texture unavailable on this device",cx,L.bottom+55,12,colors.gold,L.width-10)
        elseif view.message then
            label(view.message,cx,L.bottom+55,12,colors.gold,L.width-10)
        end
    end
    for _,item in ipairs(L.items) do drawButton(item) end
    popMatrix()
    popStyle()
end

local function selectField(view)
    local selected=field(view)
    view.choice=selected and view.kit.equipped[selected[1]] or 1
end

local function commit(view,action)
    local selected=field(view)
    local candidate,message=P.RoadEquipment.change(view.kit,action,selected and selected[1],
        selected and view.choice or view.preset)
    if candidate and view.onSave then
        local saved
        saved,message=view.onSave(candidate)
        if not saved then candidate=nil end
    end
    if candidate and view.onSave then
        view.kit=candidate
        message=action=="buy" and "Unlocked. Equip it to keep this look." or
            action=="savePreset" and "Look saved" or "Equipped"
    else
        message=message or "Could not save your changes"
    end
    view.message,view.messageTime=message,view.elapsed+2.4
    refresh(view)
end

local function handle(view,id)
    if id=="TEXTURE_TEST" then
        openTextureTest(view)
        return
    elseif id=="TEXTURE_BACK" then
        view.textureTesting=false
        view.drag=nil
        return
    end
    for number,tab in ipairs(P.RoadEquipment.sections) do
        if tab.id==id then
            view.section,view.field=number,1
            view.goalHeading=number>=4 and 156 or -14
            selectField(view)
            refresh(view)
            return
        end
    end
    if id=="BACK" then return "BACK" end
    if id=="FIELD_PREV" or id=="FIELD_NEXT" then
        local section=P.RoadEquipment.sections[view.section]
        view.field=cycle(view.field,id=="FIELD_PREV" and -1 or 1,#section.fields)
        selectField(view)
        refresh(view)
    elseif id=="VALUE_PREV" or id=="VALUE_NEXT" then
        local offset=id=="VALUE_PREV" and -1 or 1
        if view.section==5 then
            view.preset=cycle(view.preset,offset,3)
        else
            view.choice=cycle(view.choice,offset,#field(view)[3])
            refresh(view)
        end
    elseif id=="BUY" then commit(view,"buy")
    elseif id=="EQUIP" then commit(view,"equip")
    elseif id=="SAVE_PRESET" then commit(view,"savePreset")
    elseif id=="LOAD_PRESET" then commit(view,"loadPreset") end
end

function Shop.touch(view,touch)
    if touch.state==BEGAN then
        local L=Shop.layout(view)
        for _,item in ipairs(L.items) do
            if P.UI.hit(item,touch.x,touch.y) then
                if item.enabled then return handle(view,item.id) end
                return
            end
        end
        if touch.y>=L.previewBottom and touch.y<=L.previewTop and not view.drag then
            view.drag={id=touch.id,x=touch.x}
        end
    elseif view.drag and view.drag.id==touch.id then
        if touch.state==MOVING then
            local rotating=view.textureTesting and view.texturePreview or view
            rotating.goalHeading=rotating.goalHeading+(touch.x-view.drag.x)*.8
            view.drag.x=touch.x
        else
            view.drag=nil
        end
    end
end
