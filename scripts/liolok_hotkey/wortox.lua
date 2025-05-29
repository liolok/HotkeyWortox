local fn = {}

local function dbg(...) return TUNING.HOTKEY_WORTOX_DEBUG and print('Hotkey for Wortox: ' .. string.format(...)) end

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

fn.IsPlaying = function(character) -- to guard hotkeys
  if not (TheWorld and ThePlayer and ThePlayer.HUD) then return end -- in game, yeah
  if character and ThePlayer.prefab ~= character then return end -- optionally check for right character
  if ThePlayer.HUD:HasInputFocus() then return end -- typing or in some menu
  if not (Ctl() and Inv()) then return end -- for safe call later
  return true -- it's all good, man
end

--------------------------------------------------------------------------------
-- wortox_soul | Soul | 灵魂

local function GetLeastStackedSoul()
  local inventory = Inv()
  if not inventory then return end

  local least_stacked_soul
  local min_stack_size = 41
  for _, item in pairs(inventory:GetItems()) do
    if item and item.prefab == 'wortox_soul' then
      local stack = Get(item, 'replica', 'stackable')
      local size = stack and stack:StackSize()
      if type(size) == 'number' and size < min_stack_size then
        min_stack_size = size
        least_stacked_soul = item
      end
    end
  end
  return least_stacked_soul
end

fn.UseSoul = function()
  dbg('Eating Soul')
  local soul = GetLeastStackedSoul()
  return soul and Ctl():RemoteUseItemFromInvTile(BufferedAction(ThePlayer, nil, ACTIONS.EAT, soul), soul)
end

fn.DropSoul = function()
  dbg('Dropping Soul')
  local soul = GetLeastStackedSoul()
  return soul and Ctl():RemoteDropItemFromInvTile(soul)
end

--------------------------------------------------------------------------------
-- wortox_souljar | Soul Jar | 灵魂罐
-- credit: workshop-3379520334 of liang

local function StoreSoul(jar_item, soul_slot, soul_num)
  if not (jar_item and soul_slot and soul_num) then return end

  dbg('Store %d Soul from slot %d', soul_num, soul_slot)
  SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, soul_slot, nil, soul_num) -- take souls from slot
  SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.STORE.code, jar_item) -- store as many souls into jar
  return ThePlayer:DoTaskInTime(0.4, function() -- put soul back into inventory bar slot
    return SendRPCToServer(RPC.AddAllOfActiveItemToSlot, soul_slot)
  end)
end

local function ToggleJar(jar) return SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar) end

local function GetFirstEmptySlot()
  local inventory = Inv()
  if not inventory then return end
  for slot = 1, inventory:GetNumSlots() do
    if not inventory:GetItemInSlot(slot) then return slot end
  end
end

local is_jar_in_cd -- cooldown for Soul Jar Open/Close

local function TakeSoul(jar_item, soul_slot, soul_num)
  if not jar_item then return end

  dbg('Take %d Soul to slot %d', soul_num, soul_slot or GetFirstEmptySlot())
  is_jar_in_cd = ThePlayer:DoTaskInTime(1, function() is_jar_in_cd = nil end)
  local is_open = Get(jar_item, 'replica', 'container', '_isopen')
  if not is_open then ToggleJar(jar_item) end -- open jar if not already open
  return ThePlayer:DoTaskInTime(is_open and 0 or 0.4, function() -- wait to ensure jar is open
    if soul_num > 0 then
      SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, 1, jar_item, soul_num) -- take souls from jar
      local rpc = soul_slot and RPC.AddAllOfActiveItemToSlot or RPC.PutAllOfActiveItemInSlot
      SendRPCToServer(rpc, soul_slot or GetFirstEmptySlot()) -- put soul into inventory bar slot
    end
    return ToggleJar(jar_item) -- close jar
  end)
end

local function IsJumping()
  local as = Get(ThePlayer, 'AnimState')
  return as and (as:IsCurrentAnimation('wortox_portal_jumpin') or as:IsCurrentAnimation('wortox_portal_jumpout'))
end

local task_delay

fn.UseSoulJar = function()
  if is_jar_in_cd then return end

  if IsJumping() then
    task_delay = task_delay or ThePlayer:DoPeriodicTask(FRAMES, fn.UseSoulJar)
    return
  elseif task_delay then
    task_delay:Cancel()
    task_delay = nil
  end

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

  local max_count = TUNING.WORTOX_MAX_SOULS or 20 -- overload limit
  local per_count = Get(TUNING, 'SKILLS', 'WORTOX', 'FILLED_SOULJAR_SOULCAP_INCREASE_PER') or 5
  if skill:IsActivated('wortox_souljar_2') then max_count = max_count + per_count * jar.total end
  local is_greedy = TUNING.HOTKEY_WORTOX_GREED and (ThePlayer.wortox_inclination == 'naughty')
  local target_count = max_count - (is_greedy and 0 or 10)
  if target_count > 40 then target_count = 40 end
  if soul.item and soul.item:HasTag('nosouljar') then soul.total = soul.total - 1 end -- in Soul Echo
  local n = math.abs(soul.total - target_count) -- number of soul to move
  dbg('Inventory has %d Soul in total', soul.total)
  return (soul.total > target_count) and StoreSoul(jar.min.item, soul.slot, n) -- inventory bar soul too many, try to store some into emptiest jar.
    or TakeSoul(jar.max.item, soul.slot, n) -- inventory bar soul too few, try to take some out of fullest jar.
end

--------------------------------------------------------------------------------
-- blink | Soul Hop | 灵魂跳跃
-- credits: workshop-3129154416 of 萌萌的新

local function CanBlink()
  if Get(ThePlayer, 'CanSoulhop') and not ThePlayer:CanSoulhop() then return end -- no inventory soul or riding

  if IsJumping() then return end

  local inventory = Inv()
  if not inventory or inventory:GetActiveItem() then return end -- something is on mouse cursor

  local hand_item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
  if hand_item and hand_item.prefab == 'orangestaff' then return end -- The Lazy Explorer is equipped

  return true
end

local function CanBlinkTo(x, z) return x and z and TheWorld and TheWorld.Map and TheWorld.Map:IsPassableAtPoint(x, 0, z) end

local function GetPosition(target)
  if not (ThePlayer and TheInput and CanBlink()) then return end

  local player = ThePlayer:GetPosition()
  if target == 'player' then return player.x, player.z end

  if target == 'entity' then
    local entity = TheInput:GetWorldEntityUnderMouse()
    if not entity or entity:HasTag('CLASSIFIED') then return end

    entity = entity:GetPosition()
    if not (entity and CanBlinkTo(entity.x, entity.z)) then return end

    return entity.x, entity.z
  end

  local cursor = TheInput:GetWorldPosition()
  local dx, dz = cursor.x - player.x, cursor.z - player.z
  local distance = math.sqrt(dx ^ 2 + dz ^ 2) -- distance between player and cursor
  local dist_max = ACTIONS.BLINK.distance or 36
  if distance < dist_max / 9 then return end -- dead zone

  for dist = dist_max, dist_max / 3, -0.1 do
    local ratio = dist / distance
    local x, z = player.x + dx * ratio, player.z + dz * ratio
    if CanBlinkTo(x, z) then return x, z end
  end
end

fn.BlinkInPlace = function() return SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, GetPosition('player')) end
fn.BlinkToEntity = function() return SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, GetPosition('entity')) end
fn.BlinkToMostFar = function() return SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, GetPosition('furthest')) end

fn.RefreshBlinkMarkers = function(self) -- inject playercontroller component
  local OldOnUpdate = self.OnUpdate
  self.OnUpdate = function(self, ...)
    if Get(ThePlayer, 'prefab') ~= 'wortox' then return OldOnUpdate(self, ...) end

    for _, target in ipairs({ 'entity', 'furthest' }) do
      local marker = 'blink_marker_wortox_' .. target
      if TUNING['HOTKEY_WORTOX_' .. target:upper()] then -- key binding enabled
        self[marker] = self[marker] or SpawnPrefab('blink_marker')
        self[marker]:Refresh(GetPosition(target))
      elseif self[marker] then -- key binding disabled in game
        self[marker]:Remove()
        self[marker] = nil
      end
    end

    return OldOnUpdate(self, ...)
  end
end

--------------------------------------------------------------------------------

return fn
