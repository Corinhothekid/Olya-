-- PolyLax Ultimate | Squad Building Challenges (SBC)
-- Offline, earn-only challenges. Atomic inventory consumption; no paid currency.
PolyLax = PolyLax or {}
local U=PolyLax.Ultimate
assert(U,"Load Ultimate.lua before UltimateSBC.lua")
local SBC={}
U.SBC=SBC
SBC.challenges={
 {id="starter_exchange",name="First Trade",slots=2,repeatable=false,reward={coins=250,pack=1},rules={minLeagues=1}},
 {id="field_specialists",name="Field Specialists",slots=3,repeatable=false,reward={coins=600,pack=1},rules={league="PLL"}},
 {id="box_experts",name="Box Experts",slots=3,repeatable=false,reward={coins=600,pack=1},rules={league="NLL"}},
 {id="heritage",name="Heritage Exchange",slots=3,repeatable=false,reward={coins=650,pack=1},rules={league="MLL"}},
 {id="cross_league",name="Cross-League Chemistry",slots=4,repeatable=false,reward={coins=1200,pack=2},rules={minLeagues=2}},
 {id="ultimate_mix",name="Ultimate Trio",slots=6,repeatable=false,reward={coins=2000,pack=3},rules={minLeagues=3}}
}
local function findChallenge(id)
 for _,c in ipairs(SBC.challenges) do if c.id==id then return c end end
end
local function findCard(id)
 local p=U.find(id)
 if p then return p end
 for _,c in ipairs(U.researchCandidates or {}) do if c.id==id then return c end end
end
function SBC.validate(collection,challengeId,cardIds)
 local challenge=findChallenge(challengeId)
 if not challenge then return false,"Unknown challenge" end
 if type(cardIds)~="table" or #cardIds~=challenge.slots then return false,"Incorrect number of cards" end
 if not challenge.repeatable and collection.completedSBC and collection.completedSBC[challengeId] then return false,"Challenge already completed" end
 local used,leagues={},{}
 for _,id in ipairs(cardIds) do
  if type(id)~="string" then return false,"Invalid card ID" end
  local card=findCard(id)
  if not card then return false,"Unknown card" end
  -- Research-only candidates are not eligible until a verified card is minted.
  if card.verification=="pending" then return false,"Unverified card cannot be submitted" end
  if challenge.rules.league and card.league~=challenge.rules.league then return false,"Wrong league" end
  used[id]=(used[id] or 0)+1
  leagues[card.league]=true
  if (collection.owned or {})[id]==nil or collection.owned[id]<used[id] then return false,"Not enough copies" end
 end
 local count=0
 for _ in pairs(leagues) do count=count+1 end
 if count<(challenge.rules.minLeagues or 1) then return false,"Not enough different leagues" end
 return true,challenge
end
function SBC.submit(collection,challengeId,cardIds)
 local ok,challenge=SBC.validate(collection,challengeId,cardIds)
 if not ok then return false,challenge end
 -- All checks above complete before any inventory mutation.
 local used={}
 for _,id in ipairs(cardIds) do used[id]=(used[id] or 0)+1 end
 for id,n in pairs(used) do collection.owned[id]=collection.owned[id]-n end
 -- Remove equipped cards if their last copy was submitted.
 for slot,id in pairs(collection.squad or {}) do
  if (collection.owned[id] or 0)==0 then collection.squad[slot]=nil end
 end
 collection.coins=(collection.coins or 0)+(challenge.reward.coins or 0)
 collection.unopenedPacks=(collection.unopenedPacks or 0)+(challenge.reward.pack or 0)
 collection.completedSBC=collection.completedSBC or {}
 collection.completedSBC[challengeId]=true
 return true,{coins=challenge.reward.coins,packs=challenge.reward.pack}
end
return SBC
