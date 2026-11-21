-- PolyLax Ultimate | console-football-inspired SBC screen, original lacrosse layout
-- Requires Ultimate.lua and UltimateSBC.lua. Standalone draw/touch module.
PolyLax = PolyLax or {}
local U=PolyLax.Ultimate
assert(U and U.SBC,"Load Ultimate and UltimateSBC before UltimateSBCUI")
local UI={}
U.SBCUI=UI
local ink=color(235,242,244)
local muted=color(169,189,193)
local gold=color(230,195,108)
local cyan=color(80,216,211)
local green=color(50,173,108)
local navy=color(10,23,33)
local panel=color(22,39,50)
local function rectBox(x,y,w,h,tint)
 fill(tint) rectMode(CENTER) rect(x,y,w,h)
end
local function txt(s,x,y,size,tint)
 fill(tint or ink) fontSize(size) text(tostring(s),x,y)
end
local function hit(b,t)
 return b and math.abs(t.x-b.x)<b.w*.5 and math.abs(t.y-b.y)<b.h*.5
end
function UI.new(collection)
 return {collection=collection or U.defaultCollection(),challenge=1,selected=1,entries={},mode="squad",message=nil}
end
local function challenge(state) return U.SBC.challenges[state.challenge] end
local function cardById(id) return U.find(id) end
local function ownedOptions(state)
 local options={}
 for _,p in ipairs(U.players) do
  local owned=(state.collection.owned or {})[p.id] or 0
  if owned>0 then options[#options+1]={player=p,owned=owned} end
 end
 table.sort(options,function(a,b) return a.player.name<b.player.name end)
 return options
end
function UI.layout(state)
 local safe=PolyLax.UI and PolyLax.UI.safeArea and PolyLax.UI.safeArea() or {top=0,bottom=0,left=0,right=0}
 local left,right=16+(safe.left or 0),WIDTH-16-(safe.right or 0)
 local top=HEIGHT-18-(safe.top or 0)
 local bottom=18+(safe.bottom or 0)
 local width=right-left
 local ch=challenge(state)
 local fieldTop=top-127
 local fieldBottom=bottom+170
 local fieldHeight=math.max(155,fieldTop-fieldBottom)
 local fieldCenter=(fieldTop+fieldBottom)*.5
 local cardW=math.min(59,(width-30)/5.3)
 local cardH=math.min(73,fieldHeight*.24)
 local coords={
  {.20,.84},{.50,.89},{.80,.84},
  {.18,.61},{.50,.66},{.82,.61},
  {.20,.37},{.50,.42},{.80,.37},
  {.50,.14}
 }
 local slots={}
 for i=1,ch.slots do
  local point=coords[i]
  slots[i]={x=left+width*point[1],y=fieldBottom+fieldHeight*point[2],w=cardW,h=cardH}
 end
 return {left=left,right=right,top=top,bottom=bottom,width=width,
  field={x=(left+right)*.5,y=fieldCenter,w=width,h=fieldHeight},
  slots=slots,previous={x=left+24,y=top-69,w=46,h=38},
  next={x=right-24,y=top-69,w=46,h=38},
  submit={x=(left+right)*.5,y=bottom+39,w=width*.78,h=49},
  inventory={x=(left+right)*.5,y=bottom+112,w=width-8,h=65},
  titleY=top-20,challengeY=top-69}
end
local function drawCard(b,player,selected,index)
 local x,y=b.x,b.y
 local edge=selected and cyan or color(105,126,131)
 rectBox(x,y,b.w+4,b.h+4,selected and cyan or color(45,72,80))
 rectBox(x,y,b.w,b.h,player and color(169,137,72) or color(27,55,64))
 if player then
  txt(player.position or "?",x,y+b.h*.30,10,navy)
  txt(player.name:match("([^ ]+)$") or player.name,x,y-3,math.min(11,b.w*.19),navy)
  txt(player.league,x,y-b.h*.31,9,navy)
 else
  txt("+",x,y+4,24,muted)
  txt(tostring(index),x,y-b.h*.30,9,muted)
 end
end
function UI.draw(state)
 local l=UI.layout(state)
 local ch=challenge(state)
 pushStyle() pushMatrix() resetMatrix() ortho() viewMatrix(matrix())
 background(9,20,30) noStroke() font("AvenirNext-DemiBold") textAlign(CENTER) textMode(CENTER)
 txt("POLYLAX ULTIMATE  /  SBC",l.field.x,l.titleY,18,ink)
 rectBox(l.field.x,l.challengeY,l.width,52,panel)
 txt("<",l.previous.x,l.previous.y,26,cyan)
 txt(">",l.next.x,l.next.y,26,cyan)
 txt(ch.name,l.field.x,l.challengeY+8,17,gold)
 txt(tostring(state.challenge).." / "..#U.SBC.challenges,l.field.x,l.challengeY-14,10,muted)
 local f=l.field
 rectBox(f.x,f.y,f.w,f.h,color(19,73,68))
 stroke(61,133,123,180) strokeWidth(1.5) noFill()
 rect(f.x,f.y,f.w-24,f.h-18)
 ellipse(f.x,f.y,math.min(85,f.w*.28))
 line(f.x-f.w*.5+12,f.y,f.x+f.w*.5-12,f.y)
 noStroke()
 for i,b in ipairs(l.slots) do
  local id=state.entries[i]
  drawCard(b,id and cardById(id),state.selected==i,i)
 end
 rectBox(l.inventory.x,l.inventory.y,l.inventory.w,l.inventory.h,panel)
 local options=ownedOptions(state)
 local id=state.entries[state.selected]
 txt("SLOT "..state.selected.."  |  "..(id and (cardById(id) and cardById(id).name or "Empty") or "EMPTY"),l.inventory.x,l.inventory.y+17,13,ink)
 txt(#options.." owned card types  |  Tap slot to select, then tap here to cycle cards",l.inventory.x,l.inventory.y-9,10,muted)
 local ok,why=U.SBC.validate(state.collection,ch.id,state.entries)
 rectBox(l.submit.x,l.submit.y,l.submit.w,l.submit.h,ok and green or color(59,75,78))
 txt(ok and "SUBMIT SQUAD" or "SQUAD INCOMPLETE",l.submit.x,l.submit.y+5,15,ink)
 txt(ch.reward.coins.." COINS  +  "..ch.reward.pack.." PACKS",l.submit.x,l.submit.y-13,10,ok and ink or muted)
 if state.message then txt(state.message,l.field.x,l.bottom+76,10,gold)
 elseif not ok then txt(why,l.field.x,l.bottom+76,10,muted) end
 popMatrix() popStyle()
 return l
end
function UI.touch(state,t)
 if t.state~=BEGAN then return nil end
 local l=UI.layout(state)
 if hit(l.previous,t) then state.challenge=(state.challenge-2)%#U.SBC.challenges+1;state.entries={};state.selected=1;state.message=nil;return "previous" end
 if hit(l.next,t) then state.challenge=state.challenge%#U.SBC.challenges+1;state.entries={};state.selected=1;state.message=nil;return "next" end
 for i,b in ipairs(l.slots) do
  if hit(b,t) then state.selected=i;state.message=nil;return "slot" end
 end
 if hit(l.inventory,t) then
  local options=ownedOptions(state)
  local selected=state.entries[state.selected]
  local index=0
  for i,v in ipairs(options) do if v.player.id==selected then index=i;break end end
  if #options>0 then
   state.entries[state.selected]=options[index%#options+1].player.id
   state.message=nil
  else state.message="No owned cards. Earn cards before building an SBC." end
  return "inventory"
 end
 if hit(l.submit,t) then
  local ok,result=U.SBC.submit(state.collection,challenge(state).id,state.entries)
  if ok then state.entries={};state.selected=1;state.message="COMPLETE! +"..result.coins.." COINS / +"..result.packs.." PACKS"
  else state.message=result end
  return ok and "completed" or "invalid"
 end
 return nil
end
return UI
