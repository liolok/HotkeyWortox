local fn = {}

-- shortcut for code like `ThePlayer and ThePlayer.replica and ThePlayer.replica.inventory`
local function Get(head_node, ...)
  local current_node = head_node
  for _, key in ipairs({ ... }) do
    if not current_node then return end
    current_node = current_node[key]
  end
  return current_node
end

local function Ctl() return Get(ThePlayer, 'components', 'playercontroller') end

local function Inv() return Get(ThePlayer, 'replica', 'inventory') end

local function IsPlaying(character)
  if not (TheWorld and ThePlayer and ThePlayer.HUD) then return end -- in game, yeah
  if character and ThePlayer.prefab ~= character then return end -- optionally check for right character
  if ThePlayer.HUD:HasInputFocus() then return end -- typing or in some menu
  if not (Ctl() and Inv()) then return end -- for safe call later
  return true -- it's all good, man
end

local function FindInvItem(prefab)
  local inventory = Inv()
  for slot = 1, inventory:GetNumSlots() do
    local item = inventory:GetItemInSlot(slot)
    if item and item.prefab == prefab then return item end
  end
end

fn.UseSoul = function()
  if not IsPlaying('wortox') then return end
  local soul = FindInvItem('wortox_soul')
  return soul and Ctl():RemoteUseItemFromInvTile(BufferedAction(ThePlayer, nil, ACTIONS.EAT, soul), soul)
end

fn.DropSoul = function()
  if not IsPlaying('wortox') then return end
  local soul = FindInvItem('wortox_soul')
  return soul and Ctl():RemoteDropItemFromInvTile(soul)
end

--------------------------------------------------------------------------------

local function StoreSoul(jar_item, soul_slot, soul_num) -- credit: workshop-3379520334 of liang
  if not (jar_item and soul_slot and soul_num) then return end
  SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, soul_slot, nil, soul_num) -- take souls from slot
  SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.STORE.code, jar_item) -- store as many souls into jar
  return ThePlayer:DoTaskInTime(0.4, function() -- put soul back into inventory bar slot
    SendRPCToServer(RPC.AddAllOfActiveItemToSlot, soul_slot)
  end)
end

local function TakeSoul(jar_item, soul_slot, soul_num, is_slot_empty) -- credit: workshop-3379520334 of liang
  if not (jar_item and soul_slot and soul_num) then return end
  SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar_item) -- open jar
  return ThePlayer:DoTaskInTime(0.4, function() -- wait to ensure jar is ready
    SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, 1, jar_item, soul_num) -- take souls from jar
    local rpc = is_slot_empty and RPC.PutAllOfActiveItemInSlot or RPC.AddAllOfActiveItemToSlot
    SendRPCToServer(rpc, soul_slot) -- put soul into inventory bar slot
    SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar_item) -- close jar
  end)
end

local is_jar_in_cd -- cooldown for Soul Jar usage

fn.UseSoulJar = function()
  if is_jar_in_cd or not IsPlaying('wortox') then return end

  is_jar_in_cd = ThePlayer:DoTaskInTime(1, function() is_jar_in_cd = nil end)

  local skill = Get(ThePlayer, 'components', 'skilltreeupdater')
  if not (skill and skill:IsActivated('wortox_souljar_1')) then return end -- can not use jar at all

  local inventory = Inv()
  if inventory:GetActiveItem() then return end -- something is on mouse cursor, that'd be too much of trouble.

  local jar = { min = { percent = 101 }, max = { percent = -1 }, total = 0 } -- to find emptiest and fullest jar
  local soul = { min = 41, total = 0 } -- to find slot and item with least soul

  for i = 1, inventory:GetNumSlots() do -- look through all slots of inventory bar, left to right.
    local item = inventory:GetItemInSlot(i)
    if item and item.prefab == 'wortox_souljar' then
      local percent_used = Get(item, 'replica', 'inventoryitem', 'classified', 'percentused')
      local percent = percent_used and percent_used:value()
      if percent then
        jar.total = jar.total + 1
        if percent < jar.min.percent then jar.min = { percent = percent, item = item } end
        if percent > jar.max.percent then jar.max = { percent = percent, item = item } end
      end
    end
    if item and item.prefab == 'wortox_soul' then
      local stackable = Get(item, 'replica', 'stackable')
      local num = stackable and stackable:StackSize()
      if num then
        soul.total = soul.total + num
        if num < soul.min then
          soul.slot, soul.item, soul.min = i, item, num
        end
      end
    end
  end
  if jar.total == 0 then return end -- no jar found

  local max_count = Get(TUNING, 'WORTOX_MAX_SOULS') or 20 -- overload limit
  local per_count = Get(TUNING, 'SKILLS', 'WORTOX', 'FILLED_SOULJAR_SOULCAP_INCREASE_PER') or 5
  if skill:IsActivated('wortox_souljar_2') then max_count = max_count + per_count * jar.total end
  local target_count = max_count - 10
  local num = math.abs(target_count - soul.total) -- number of souls to move
  if num == 0 then return end -- no need to move

  if target_count < soul.total then -- inventory soul too many, store some into emptiest jar
    return jar.min.percent < 100 and StoreSoul(jar.min.item, soul.slot, num)
  end -- only store if have non-full jar

  -- inventory soul too few, take some out of fullest jar
  if jar.max.percent == 0 then return end -- all jars are empty, no soul to take

  if soul.slot then return TakeSoul(jar.max.item, soul.slot, num) end -- put into slot with least soul

  -- no inventory bar soul at all
  if inventory:IsFull() then return end -- no empty slot for soul

  for i = 1, inventory:GetNumSlots() do
    if not inventory:GetItemInSlot(i) then
      soul.slot = i -- first empty slot
      break
    end
  end
  return TakeSoul(jar.max.item, soul.slot, num, true)
end

--------------------------------------------------------------------------------

return fn
