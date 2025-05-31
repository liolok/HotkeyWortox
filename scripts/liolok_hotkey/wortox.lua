local fn = {}

local function dbg(...) return TUNING.HOTKEY_WORTOX_DEBUG and print('Hotkey for Wortox: ' .. string.format(...)) end

-- shortcut for code like `ThePlayer and ThePlayer.replica and ThePlayer.replica.inventory`
local function Get(head_node, ...)
  local current = head_node
  for _, key in ipairs({ ... }) do
    if not current then return end

    local next = current[key]
    if type(next) == 'function' then
      current = next(current) -- this could be `false` so avoid using `and next(current) or next` assignment
    else
      current = next
    end
  end
  return current
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
  local least_stacked_soul
  local min_stack_size = 41
  for _, item in pairs(Get(ThePlayer, 'replica', 'inventory', 'GetItems') or {}) do
    local prefab = Get(item, 'prefab')
    local stack_size = Get(item, 'replica', 'stackable', 'StackSize')
    if prefab == 'wortox_soul' and type(stack_size) == 'number' and stack_size < min_stack_size then
      min_stack_size = stack_size
      least_stacked_soul = item
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

local is_jar_in_cd -- cooldown for Soul Jar

local function StoreSoul(jar_item, soul_slot, soul_num)
  if not (jar_item and soul_slot and soul_num) then return end

  dbg('Store %d Soul from slot %d', soul_num, soul_slot)
  is_jar_in_cd = ThePlayer:DoTaskInTime(0.5, function() is_jar_in_cd = nil end)
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

local function TakeSoul(jar_item, soul_slot, soul_num)
  if not jar_item then return end

  local target_slot = soul_slot or GetFirstEmptySlot()
  dbg('Take %d Soul to slot %d', soul_num, target_slot)
  is_jar_in_cd = ThePlayer:DoTaskInTime(1, function() is_jar_in_cd = nil end)
  local is_open = Get(jar_item, 'replica', 'container', '_isopen')
  if not is_open then ToggleJar(jar_item) end -- open jar if not already open
  return ThePlayer:DoTaskInTime(is_open and 0 or 0.4, function() -- wait to ensure jar is open
    if soul_num > 0 then
      SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, 1, jar_item, soul_num) -- take souls from jar
      local rpc = soul_slot and RPC.AddAllOfActiveItemToSlot or RPC.PutAllOfActiveItemInSlot
      SendRPCToServer(rpc, target_slot) -- put soul into inventory bar slot
    end
    return ToggleJar(jar_item) -- close jar
  end)
end

local task_delay

fn.UseSoulJar = function()
  if is_jar_in_cd then return end

  if not ThePlayer:HasOneOfTags('idle', 'moving') then
    task_delay = task_delay or ThePlayer:DoPeriodicTask(FRAMES, fn.UseSoulJar)
    return
  elseif task_delay then
    task_delay:Cancel()
    task_delay = nil
  end

  local skill = Get(ThePlayer, 'components', 'skilltreeupdater')
  if not (skill and skill:IsActivated('wortox_souljar_1')) then return end -- can not use jar at all

  local inventory = Inv()
  local prefab_on_cursor = Get(inventory:GetActiveItem(), 'prefab') -- return Soul or Soul Jar on cursor to inventory
  if prefab_on_cursor == 'wortox_soul' or prefab_on_cursor == 'wortox_souljar' then inventory:ReturnActiveItem() end

  local jar = { min = { percent = 101 }, max = { percent = -1 }, total = 0 } -- to find emptiest and fullest jar
  local soul = { min = { stack_size = 41 }, total = 0 } -- to find slot and item with least soul

  for i = 1, inventory:GetNumSlots() do -- look through all slots of inventory bar, left to right.
    local item = inventory:GetItemInSlot(i)
    local prefab = Get(item, 'prefab')
    local percent = Get(item, 'replica', 'inventoryitem', 'classified', 'percentused', 'value')
    local stack_size = Get(item, 'replica', 'stackable', 'StackSize')
    if prefab == 'wortox_souljar' and type(percent) == 'number' then
      jar.total = jar.total + 1
      if percent < jar.min.percent then jar.min = { percent = percent, item = item } end
      if percent > jar.max.percent then jar.max = { percent = percent, item = item } end
    end
    if prefab == 'wortox_soul' and type(stack_size) == 'number' then
      soul.total = soul.total + stack_size
      if stack_size < soul.min.stack_size then soul.min = { slot = i, item = item, stack_size = stack_size } end
    end
  end
  if jar.total == 0 then return end -- no jar found

  local max_count = TUNING.WORTOX_MAX_SOULS or 20 -- overload limit
  local per_count = Get(TUNING, 'SKILLS', 'WORTOX', 'FILLED_SOULJAR_SOULCAP_INCREASE_PER') or 5
  if skill:IsActivated('wortox_souljar_2') then max_count = max_count + per_count * jar.total end
  local is_greedy = TUNING.HOTKEY_WORTOX_GREED and (ThePlayer.wortox_inclination == 'naughty')
  local target_count = max_count - (is_greedy and 0 or 10)
  if target_count > 40 then target_count = 40 end
  if soul.min.item and soul.min.item:HasTag('nosouljar') then soul.total = soul.total - 1 end -- in Soul Echo
  local n = math.abs(soul.total - target_count) -- number of soul to move
  dbg('Inventory has %d Soul in total', soul.total)
  inventory:ReturnActiveItem() -- if something is on mouse cursor, return it to inventory or it'd block storing/taking actions.
  return (soul.total > target_count) and StoreSoul(jar.min.item, soul.min.slot, n) -- inventory bar soul too many, try to store some into emptiest jar.
    or TakeSoul(jar.max.item, soul.min.slot, n) -- inventory bar soul too few, try to take some out of fullest jar.
end

--------------------------------------------------------------------------------
-- blink | Soul Hop | 灵魂跳跃
-- credits: workshop-3129154416 of 萌萌的新

local function IsJumping()
  local as = Get(ThePlayer, 'AnimState')
  return as and (as:IsCurrentAnimation('wortox_portal_jumpin') or as:IsCurrentAnimation('wortox_portal_jumpout'))
end

local function CanBlink()
  return Get(ThePlayer, 'CanSoulhop') -- has inventory soul and not riding
    and not IsJumping() -- not already jumping
    and not Inv():GetActiveItem() -- nothing is blocking mouse cursor
    and Get(Inv():GetEquippedItem(EQUIPSLOTS.HANDS), 'prefab') ~= 'orangestaff' -- not equipping The Lazy Explorer
end

local function IsPassable(x, z) return x and z and TheWorld and TheWorld.Map and TheWorld.Map:IsPassableAtPoint(x, 0, z) end

local function GetPosition(target)
  if not (ThePlayer and TheInput and CanBlink()) then return end

  local player = ThePlayer:GetPosition()
  if target == 'player' then return player.x, player.z end

  if target == 'entity' then
    local entity = TheInput:GetWorldEntityUnderMouse()
    if not entity or entity:HasTag('CLASSIFIED') then return end

    entity = entity:GetPosition()
    if not (entity and IsPassable(entity.x, entity.z)) then return end

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
    if IsPassable(x, z) then return x, z end
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
-- Craft | 制作

local function Make(prefab) return SendRPCToServer(RPC.MakeRecipeFromMenu, Get(AllRecipes, prefab, 'rpc_id')) end

fn.MakeNabBag = function() return Make('wortox_nabbag') end -- Knabsack | 强抢袋
fn.MakeReviver = function() return Make('wortox_reviver') end -- Twintailed Heart | 双尾心

--------------------------------------------------------------------------------

return fn
