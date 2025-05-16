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

fn.IsPlaying = IsPlaying

local function FindInvItem(prefab)
  local inventory = Inv()
  for slot = 1, inventory:GetNumSlots() do
    local item = inventory:GetItemInSlot(slot)
    if item and item.prefab == prefab then return item end
  end
end

local function IsJumping()
  local as = Get(ThePlayer, 'AnimState')
  return as and (as:IsCurrentAnimation('wortox_portal_jumpin') or as:IsCurrentAnimation('wortox_portal_jumpout'))
end

local function GetFirstEmptySlot()
  local inventory = Inv()
  if not inventory then return end
  for slot = 1, inventory:GetNumSlots() do
    if not inventory:GetItemInSlot(slot) then return slot end
  end
end

--------------------------------------------------------------------------------
-- wortox_soul | Soul | 灵魂

fn.UseSoul = function()
  local soul = FindInvItem('wortox_soul')
  return soul and Ctl():RemoteUseItemFromInvTile(BufferedAction(ThePlayer, nil, ACTIONS.EAT, soul), soul)
end

fn.DropSoul = function()
  local soul = FindInvItem('wortox_soul')
  return soul and Ctl():RemoteDropItemFromInvTile(soul)
end

--------------------------------------------------------------------------------
-- wortox_souljar | Soul Jar | 灵魂罐
-- credit: workshop-3379520334 of liang

local function StoreSoul(jar_item, soul_slot, soul_num)
  if not (jar_item and soul_slot and soul_num) then return end

  SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, soul_slot, nil, soul_num) -- take souls from slot
  SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.STORE.code, jar_item) -- store as many souls into jar
  return ThePlayer:DoTaskInTime(0.4, function() -- put soul back into inventory bar slot
    SendRPCToServer(RPC.AddAllOfActiveItemToSlot, soul_slot)
  end)
end

local function TakeSoul(jar_item, soul_slot, soul_num, is_slot_empty)
  if not jar_item then return end

  if not Get(jar_item, 'replica', 'container', '_isopen') then -- open jar if not already open
    SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar_item)
  end
  return ThePlayer:DoTaskInTime(0.4, function() -- wait to ensure jar is ready
    if soul_slot and soul_num > 0 then
      SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, 1, jar_item, soul_num) -- take souls from jar
      local rpc = is_slot_empty and RPC.PutAllOfActiveItemInSlot or RPC.AddAllOfActiveItemToSlot
      SendRPCToServer(rpc, soul_slot) -- put soul into inventory bar slot
    end
    return SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar_item) -- close jar
  end)
end

local is_jar_in_cd -- cooldown for Soul Jar usage
local task_delay

fn.UseSoulJar = function()
  if is_jar_in_cd then return end

  if IsJumping() then
    task_delay = task_delay or ThePlayer:DoPeriodicTask(3 * FRAMES, fn.UseSoulJar)
    return
  elseif task_delay then
    task_delay:Cancel()
    task_delay = nil
  end

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
  local target_count = math.min(max_count - 10, 40)
  if soul.item and soul.item:HasTag('nosouljar') then soul.total = soul.total - 1 end
  local num = math.abs(soul.total - target_count) -- number of soul to move

  if soul.total > target_count then -- inventory bar soul too many
    return jar.min.percent < 100 and StoreSoul(jar.min.item, soul.slot, num) -- emptiest jar not full, store into it.
  else -- inventory soul too few, try to take some out of fullest jar
    return TakeSoul(jar.max.item, soul.slot or GetFirstEmptySlot(), num, soul.total == 0)
  end
end

--------------------------------------------------------------------------------
-- blink | Soul Hop | 灵魂跳跃
-- credits: workshop-3129154416 of 萌萌的新

fn.BlinkInPlace = function()
  local pos = ThePlayer:GetPosition()
  return pos and SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, pos.x, pos.z)
end

fn.GetCursorPosition = function()
  if IsJumping() or not (TheInput and ThePlayer) then return end

  local target = TheInput:GetWorldEntityUnderMouse()
  local cursor = target and target:GetPosition() or TheInput:GetWorldPosition()
  local player = ThePlayer:GetPosition()
  local dx, dz = cursor.x - player.x, cursor.z - player.z
  local distance = math.sqrt(dx ^ 2 + dz ^ 2)
  local dist_max = ACTIONS.BLINK.distance or 36
  if distance < dist_max then return cursor.x, cursor.z end
end

fn.BlinkToCursor = function()
  local x, z = fn.GetCursorPosition()
  return (x and z) and SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, x, z)
end

fn.GetMostFarPosition = function()
  if IsJumping() or not (TheInput and ThePlayer) then return end

  local cursor, player = TheInput:GetWorldPosition(), ThePlayer:GetPosition()
  local dx, dz = cursor.x - player.x, cursor.z - player.z
  local distance = math.sqrt(dx ^ 2 + dz ^ 2)
  local dist_max = ACTIONS.BLINK.distance or 36
  if distance < dist_max / 9 then return end -- dead zone

  local x = player.x + dist_max * dx / distance
  local z = player.z + dist_max * dz / distance
  return x, z
end

fn.BlinkToMostFar = function()
  local x, z = fn.GetMostFarPosition()
  return (x and z) and SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, x, z)
end

--------------------------------------------------------------------------------

return fn
