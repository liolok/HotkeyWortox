local fn = {}
local T = TUNING.HOTKEY_WORTOX or {}

local function dbg(...) return T.DEBUG and print('Hotkey for Wortox: ' .. string.format(...)) end

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

local _cached_soul_slot -- remember which inventory bar slot to carry Soul

local function GetLeastStackedSoul()
  local inventory = Inv()
  if not inventory then return end

  local least_stacked_soul, least_stacked_slot
  local min_stack_size = 1 + (TUNING.STACK_SIZE_SMALLITEM or 40)
  local total_amount = 0
  for slot = 1, inventory:GetNumSlots() do -- look through all slots of inventory bar, left to right.
    local item = inventory:GetItemInSlot(slot)
    local prefab = Get(item, 'prefab')
    local stack_size = Get(item, 'replica', 'stackable', 'StackSize')
    if prefab == 'wortox_soul' and type(stack_size) == 'number' then
      if stack_size < min_stack_size then
        min_stack_size = stack_size
        least_stacked_soul = item
        least_stacked_slot = slot
      end
      total_amount = total_amount + stack_size
    end
  end
  if type(least_stacked_slot) == 'number' then _cached_soul_slot = least_stacked_slot end
  return least_stacked_soul, least_stacked_slot, total_amount
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

local function GetEmptySlot()
  local inventory = Inv()
  if not inventory then return end

  local cached = _cached_soul_slot
  if type(cached) == 'number' and not inventory:GetItemInSlot(cached) then return cached end

  for slot = 1, inventory:GetNumSlots() do
    if not inventory:GetItemInSlot(slot) then return slot end
  end
end

local function TakeSoul(jar_item, soul_slot, soul_num)
  if not jar_item then return end

  local target_slot = soul_slot or GetEmptySlot()
  local is_open = Get(jar_item, 'replica', 'container', '_isopen')
  if not is_open then ToggleJar(jar_item) end -- open jar if not already open
  return ThePlayer:DoTaskInTime(is_open and 0 or 0.4, function() -- wait to ensure jar is open
    if target_slot and soul_num > 0 then
      dbg('Take %d Soul to slot %d', soul_num, target_slot)
      SendRPCToServer(RPC.TakeActiveItemFromCountOfSlot, 1, jar_item, soul_num) -- take souls from jar
      local rpc = soul_slot and RPC.AddAllOfActiveItemToSlot or RPC.PutAllOfActiveItemInSlot
      SendRPCToServer(rpc, target_slot) -- put soul into inventory bar slot
    end
    return ToggleJar(jar_item) -- close jar
  end)
end

local function GetJar(demand) -- to find non-full Jar to store Soul, or non-empty Jar to take Soul
  local inventory = Inv()
  if not inventory then return end

  local fallback
  for i = 1, inventory:GetNumSlots() do -- look through all slots of inventory bar, left to right.
    local item = inventory:GetItemInSlot(i)
    local prefab = Get(item, 'prefab')
    local percent = Get(item, 'replica', 'inventoryitem', 'classified', 'percentused', 'value')
    if prefab == 'wortox_souljar' and type(percent) == 'number' then
      if (demand == 'non-full' and percent < 100) or (demand == 'non-empty' and percent > 0) then return item end
      if not fallback then fallback = item end
    end
  end
  return fallback -- return left-most Jar if none meets the demand
end

local _is_jar_in_cd -- cooldown for Soul Jar
local function IsJarInCD()
  if _is_jar_in_cd then return true end
  _is_jar_in_cd = ThePlayer:DoTaskInTime(0.5, function() _is_jar_in_cd = nil end)
end

fn.UseSoulJar = function()
  if ThePlayer:HasTag('busy') then return ThePlayer:DoTaskInTime(FRAMES, fn.UseSoulJar) end -- delay until not busy

  if IsJarInCD() then return end -- wait for cooldown

  local skill = Get(ThePlayer, 'components', 'skilltreeupdater')
  if not (skill and skill:IsActivated('wortox_souljar_1')) then return end -- can not use Jar at all

  local inv = Inv()
  local cursor = Get(inv:GetActiveItem(), 'prefab') -- return Soul or Soul Jar on cursor to inventory
  if cursor == 'wortox_soul' or cursor == 'wortox_souljar' then inv:ReturnActiveItem() end

  local has_jar, jar_amount = inv:Has('wortox_souljar', 1, false) -- at least one Jar, no need to check all container.
  if not has_jar then return end -- no Soul Jar at all

  -- calculate target number of inventory bar Soul
  local max_souls = TUNING.WORTOX_MAX_SOULS or 20 -- overload limit
  local increase_per = TUNING.SKILLS.WORTOX.FILLED_SOULJAR_SOULCAP_INCREASE_PER or 5
  if skill:IsActivated('wortox_souljar_2') then max_souls = max_souls + increase_per * jar_amount end
  local is_greedy = T.GREED and (ThePlayer.wortox_inclination == 'naughty')
  local target = max_souls - (is_greedy and 0 or 10)
  if target > 40 then target = 40 end

  local soul, slot, count = GetLeastStackedSoul()
  if soul and soul:HasTag('nosouljar') and count >= 1 then count = count - 1 end -- in Soul Echo so minus one
  dbg('Inventory has %d Soul in total', count)
  local n = math.abs(count - target) -- number of soul to move
  inv:ReturnActiveItem() -- if something is on mouse cursor, return it to inventory or it'd block storing/taking actions.
  return (count > target) and StoreSoul(GetJar('non-full'), slot, n) or TakeSoul(GetJar('non-empty'), slot, n)
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
    and (Inv() and not Inv():GetActiveItem()) -- nothing is blocking mouse cursor
    and Get(Inv():GetEquippedItem(EQUIPSLOTS.HANDS), 'prefab') ~= 'orangestaff' -- not equipping The Lazy Explorer
end

local function IsPassable(x, z) return x and z and TheWorld and TheWorld.Map and TheWorld.Map:IsPassableAtPoint(x, 0, z) end

local function GetPosition(target)
  if not CanBlink() then return end

  local player_x, player_z = Get(ThePlayer, 'GetPosition', 'x'), Get(ThePlayer, 'GetPosition', 'z')
  if target == 'player' then
    return player_x, player_z
  elseif target == 'entity' then
    local entity = Get(TheInput, 'GetWorldEntityUnderMouse')
    local is_classified = entity and entity:HasTag('CLASSIFIED')
    local x, z = Get(entity, 'GetPosition', 'x'), Get(entity, 'GetPosition', 'z')
    if is_classified == false and IsPassable(x, z) then return x, z end
  elseif target == 'furthest' then
    local cursor_x, cursor_z = Get(TheInput, 'GetWorldPosition', 'x'), Get(TheInput, 'GetWorldPosition', 'z')
    if not (player_x and player_z and cursor_x and cursor_z) then return end
    local dx, dz = cursor_x - player_x, cursor_z - player_z
    local distance = math.sqrt(dx ^ 2 + dz ^ 2) -- distance between player and cursor
    local dist_max = ACTIONS.BLINK.distance or 36
    if distance > dist_max / 9 then -- dead zone
      for dist = dist_max, dist_max / 3, -0.1 do
        local ratio = dist / distance
        local x, z = player_x + dx * ratio, player_z + dz * ratio
        if IsPassable(x, z) then return x, z end
      end
    end
  end
end

local function BlinkTo(target)
  local x, z = GetPosition(target)
  return x and z and SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, x, z)
end

fn.BlinkInPlace = function() return BlinkTo('player') end
fn.BlinkToEntity = function() return BlinkTo('entity') end
fn.BlinkToMostFar = function() return BlinkTo('furthest') end

fn.RefreshBlinkMarkers = function(self) -- inject playercontroller component
  local OldOnUpdate = self.OnUpdate
  self.OnUpdate = function(self, ...)
    if Get(ThePlayer, 'prefab') ~= 'wortox' then return OldOnUpdate(self, ...) end

    for target, fn_name in pairs({ entity = 'BlinkToEntity', furthest = 'BlinkToMostFar' }) do
      local marker = 'wortox_blink_marker_to_' .. target
      if Get(T, 'handler', fn_name) then -- key binding enabled
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
