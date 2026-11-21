-- PolyLax Ultimate 3.3 | earn-only packs, wheel, starter grant, and match rewards
-- Load after Ultimate.lua. No real-money transactions.
PolyLax=PolyLax or {}
local U=assert(PolyLax.Ultimate,"Ultimate.lua required")
local E={}
U.Economy=E
E.packSize=5
E.wheelCost=1200
E.packCost=3500
E.rates={
 {tier="elite",minimum=90,maximum=96,weight=20},
 {tier="high",minimum=85,maximum=89,weight=35},
 {tier="core",minimum=75,maximum=84,weight=45}
}
-- These are FICTIONAL game ratings, not claims about player skill or official ratings.
-- A full rated pool requires position/season editorial verification.
local function rating(player)
 if player.rating then return player.rating end
 local index=1
 for i,p in ipairs(U.players) do if p.id==player.id then index=i;break end end
 return 75+((index*7)%22)
end
function E.rating(player) return rating(player) end
local function rollTier(rng)
 local n=rng(1,100)
 if n<=20 then return "elite" elseif n<=55 then return "high" end
 return "core"
end
local function pickPlayer(tier,rng)
 local pool={}
 for _,p in ipairs(U.players) do
  local r=rating(p)
  if (tier=="elite" and r>=90) or (tier=="high" and r>=85 and r<90) or (tier=="core" and r<85) then
   pool[#pool+1]=p
  end
 end
 if #pool==0 then return nil end
 return pool[rng(1,#pool)]
end
local function draw(rng)
 local tier=rollTier(rng)
 local p=pickPlayer(tier,rng)
 if not p then
  -- No substitute rarity: fail rather than misrepresent odds.
  return nil,"No verified cards in "..tier.." tier"
 end
 return {id=p.id,name=p.name,rating=rating(p),tier=tier}
end
function E.grantStarter(collection,rng)
 if collection.starterGranted then return false,"Starter already claimed" end
 rng=rng or math.random
 local results={}
 -- Five players with one guaranteed high-or-better card.
 for i=1,E.packSize do
  local p,err
  if i==E.packSize then
   local tier=rng(1,100)<=35 and "elite" or "high"
   p=pickPlayer(tier,rng)
   if not p then return false,"Missing guaranteed starter tier" end
   results[i]={id=p.id,name=p.name,rating=rating(p),tier=tier}
  else
   results[i],err=draw(rng)
   if not results[i] then return false,err end
  end
 end
 for _,p in ipairs(results) do U.addCard(collection,p.id) end
 collection.starterGranted=true
 return true,results
end
function E.openPack(collection,rng)
 if (collection.unopenedPacks or 0)<1 then return false,"No unopened packs" end
 rng=rng or math.random
 local results={}
 for i=1,E.packSize do
  local p,err=draw(rng)
  if not p then return false,err end
  results[i]=p
 end
 collection.unopenedPacks=collection.unopenedPacks-1
 for _,p in ipairs(results) do U.addCard(collection,p.id) end
 return true,results
end
function E.buyPack(collection)
 if (collection.coins or 0)<E.packCost then return false,"Not enough gold" end
 collection.coins=collection.coins-E.packCost
 collection.unopenedPacks=(collection.unopenedPacks or 0)+1
 return true
end
function E.spin(collection,rng)
 if (collection.coins or 0)<E.wheelCost then return false,"Not enough gold" end
 local result,err=draw(rng or math.random)
 if not result then return false,err end
 collection.coins=collection.coins-E.wheelCost
 U.addCard(collection,result.id)
 return true,result
end
function E.grantTestGold(collection)
 -- Explicitly gated local developer grant. Never enable for production accounts.
 if not U.devMode then return false,"Developer mode disabled" end
 if collection.testGoldGranted then return false,"Test gold already claimed" end
 collection.coins=(collection.coins or 0)+1000000
 collection.testGoldGranted=true
 return true,collection.coins
end
function E.recordMatch(collection,result)
 -- Call only after an actual completed FullMatch; do not use as a fake game simulation.
 if result~="win" and result~="draw" and result~="loss" then return false,"Invalid match result" end
 local payout= result=="win" and 450 or result=="draw" and 250 or 150
 collection.coins=(collection.coins or 0)+payout
 collection.matches=(collection.matches or 0)+1
 collection.wins=(collection.wins or 0)+(result=="win" and 1 or 0)
 return true,payout
end
return E
