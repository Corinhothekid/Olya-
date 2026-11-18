local vector = {}
vector.__index = vector
function vec3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},vector) end
vec2 = vec3
function vector.__add(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector.__sub(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
function vector.__unm(a) return vec3(-a.x,-a.y,-a.z) end
function vector.__mul(a,b)
    if type(a) == 'number' then return vec3(a*b.x,a*b.y,a*b.z) end
    if type(b) == 'number' then return vec3(b*a.x,b*a.y,b*a.z) end
    error("Unsupported vector product")
end
function vector.__div(a,b) return a*(1/b) end
function vector:dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
function vector:cross(b) return vec3(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
function vector:len() return math.sqrt(self:dot(self)) end
function vector:normalize() return self:len()>0 and self/self:len() or vec3() end

quat={}
local function q(x,y,z,w) return {x=x,y=y,z=z,w=w} end
local function rotate(rot,v,inverse)
    local a=vec3(rot.x,rot.y,rot.z)
    if inverse then a=-a end
    local t=a:cross(v)*2
    return v+t*rot.w+a:cross(t)
end
local function qmul(a,b)
    local av,bv=vec3(a.x,a.y,a.z),vec3(b.x,b.y,b.z)
    local out=av*b.w+bv*a.w+av:cross(bv)
    return q(out.x,out.y,out.z,a.w*b.w-av:dot(bv))
end
function quat.angleAxis(deg,axis)
    local half=math.rad(deg)/2
    local w=math.cos(half)
    local a=axis:normalize()*math.sin(half)
    return q(a.x,a.y,a.z,w)
end
function quat.eulerAngles(x,y,z)
    return qmul(qmul(quat.angleAxis(y,vec3(0,1,0)),quat.angleAxis(x,vec3(1,0,0))),quat.angleAxis(z,vec3(0,0,1)))
end
function quat.fromToRotation(a,b)
    a,b=a:normalize(),b:normalize()
    local angle=math.deg(math.acos(math.max(-1,math.min(1,a:dot(b)))))
    local axis=a:cross(b)
    if axis:len()<1e-7 then
        axis=a:cross(math.abs(a.x)<.9 and vec3(1,0,0) or vec3(0,1,0))
    end
    return quat.angleAxis(angle,axis)
end
function quat.lookRotation(forward,up)
    local z=forward:normalize()
    local base=quat.fromToRotation(vec3(0,0,1),z)
    local newUp=rotate(base,vec3(0,1,0))
    local nextUp=(up-z*up:dot(z)):normalize()
    local angle=math.deg(math.atan(z:dot(newUp:cross(nextUp)),newUp:dot(nextUp)))
    return qmul(quat.angleAxis(angle,z),base)
end

local entityPrototype={}
local entityMeta={}
function entityMeta.__index(e,k)
    if k=='worldPosition' then return e:transformPoint(vec3()) end
    return entityPrototype[k]
end
function entityMeta.__newindex(e,k,v)
    if k=='eulerAngles' then
        e.rotation=quat.eulerAngles(v.x,v.y,v.z)
    else
        rawset(e,k,v)
    end
end
local function entity(parent)
    return setmetatable({parent=parent,position=vec3(),rotation=q(0,0,0,1),scale=vec3(1,1,1),active=true},entityMeta)
end
function entityPrototype:transformPoint(a)
    local v=rotate(self.rotation,vec3(a.x*self.scale.x,a.y*self.scale.y,a.z*self.scale.z))+self.position
    return self.parent and self.parent:transformPoint(v) or v
end
function entityPrototype:inverseTransformPoint(a)
    local v=self.parent and self.parent:inverseTransformPoint(a) or a
    local offset=rotate(self.rotation,v-self.position,true)
    return vec3(offset.x/self.scale.x,offset.y/self.scale.y,offset.z/self.scale.z)
end
function entityPrototype:get(component)
    assert(component==craft.camera)
    local e=self
    return {screenToRay=function()
        return e.position,rotate(e.rotation,vec3(0,0,-1))
    end}
end

local scenes={}
craft={
    camera={}, material=function()return{}end,
    model=setmetatable({cube=function()return{}end,icosphere=function()return{}end},{__call=function()return{}end}),
    cubeTexture=function(...) assert(select('#',...)==6) return {testCube=true} end
}
function craft.scene()
    local s={camera=entity(),sun=entity(),entities={}}
    s.entity=function(self)
        local e=entity()
        self.entities[#self.entities+1]=e
        return e
    end
    s.draw=function()end
    s.update=function()end
    scenes[#scenes+1]=s
    return s
end
function image() return {set=function()end} end
function color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end

WIDTH, HEIGHT, DeltaTime = 390, 844, 1/60
BEGAN, MOVING, ENDED, CANCELLED = 1, 2, 3, 4
CENTER, CORNER, FULLSCREEN, PORTRAIT = 0, 1, 2, 3
local store={}
function readLocalData(key) return store[key] end
function saveLocalData(key,value) store[key]=value end
local currentFontSize=17
function fontSize(size)
    if size==nil then return currentFontSize end
    assert(type(size)=='number', "fontSize expects a number, got "..type(size))
    currentFontSize=size
end
local noop=function()end
for _,key in ipairs({'supportedOrientations','displayMode','pushStyle','popStyle',
        'pushMatrix','popMatrix','resetMatrix','ortho','viewMatrix','noStroke',
        'font','textMode','textAlign','fill','text','rectMode','rect',
        'matrix','ellipseMode','ellipse'}) do _G[key]=noop end

return {scenes=scenes,store=store,rotate=rotate}
