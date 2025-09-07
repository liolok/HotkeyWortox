local fn = {}
local T = TUNING.HOTKEY_WORTOX or {}
local S = STRINGS.HOTKEY_WORTOX or {}

local function dbg(...) return T.DEBUG and print('Hotkey for Wortox: ' .. string.format(...)) end

local is_in_cd = {} -- cooldown | 冷却
local function IsInCD(key, cooldown)
  if is_in_cd[key] then return true end
  is_in_cd[key] = ThePlayer and ThePlayer:DoTaskInTime(cooldown or 1, function() is_in_cd[key] = false end)
end

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

local function ToggleJar(jar) return SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.RUMMAGE.code, jar) end

local function GetRightMostNonFullJar() -- to find right-most non-full Jar to store Soul
  local inventory = Inv()
  if not inventory then return end

  local left_most_jar
  for i = inventory:GetNumSlots(), 1, -1 do -- look through all slots of inventory bar, right to right.
    local item = inventory:GetItemInSlot(i)
    local prefab = Get(item, 'prefab')
    local percent = Get(item, 'replica', 'inventoryitem', 'classified', 'percentused', 'value')
    if prefab == 'wortox_souljar' and type(percent) == 'number' then
      if percent < 100 then return item end
      left_most_jar = item
    end
  end
  return left_most_jar -- return left-most Jar if all Jars are full
end

local function GetLeftMostNonEmptyJar() -- to find left-most non-empty Jar to take Soul
  local inventory = Inv()
  if not inventory then return end

  local right_most_jar
  for i = 1, inventory:GetNumSlots() do -- look through all slots of inventory bar, left to right.
    local item = inventory:GetItemInSlot(i)
    local prefab = Get(item, 'prefab')
    local percent = Get(item, 'replica', 'inventoryitem', 'classified', 'percentused', 'value')
    if prefab == 'wortox_souljar' and type(percent) == 'number' then
      if percent > 0 then return item end
      right_most_jar = item
    end
  end
  return right_most_jar -- return right-most Jar if all Jars are empty
end

fn.UseSoulJar = function()
  if ThePlayer:HasTag('busy') then return ThePlayer:DoTaskInTime(FRAMES, fn.UseSoulJar) end -- delay until not busy

  if IsInCD('Soul Jar', 0.5) then return end -- wait for cooldown

  local inv, skill = Inv(), Get(ThePlayer, 'components', 'skilltreeupdater')
  if not (inv and skill and skill:IsActivated('wortox_souljar_1')) then return end -- can not use Jar at all

  local cursor = Get(inv:GetActiveItem(), 'prefab') -- return Soul or Soul Jar on cursor to inventory
  if cursor == 'wortox_soul' or cursor == 'wortox_souljar' then inv:ReturnActiveItem() end

  local has_jar, jar_amount = inv:Has('wortox_souljar', 1, false) -- at least one Jar, no need to check all container.
  if not has_jar then return end -- no Soul Jar at all

  inv:ReturnActiveItem() -- if something is on mouse cursor, return it to inventory or it'd block storing/taking actions.

  -- calculate target number of inventory bar Soul
  local max_souls = TUNING.WORTOX_MAX_SOULS or 20 -- overload limit
  local increase_per = TUNING.SKILLS.WORTOX.FILLED_SOULJAR_SOULCAP_INCREASE_PER or 5
  if skill:IsActivated('wortox_souljar_2') then max_souls = max_souls + increase_per * jar_amount end
  local is_greedy = T.GREED and (ThePlayer.wortox_inclination == 'naughty')
  local target = max_souls - (is_greedy and 0 or 10)
  if target > 40 then target = 40 end

  local soul, slot, count = GetLeastStackedSoul()
  if soul and soul:HasTag('nosouljar') and count >= 1 then count = count - 1 end -- in Soul Echo so minus one
  dbg('Inventory bar has %d Soul in total', count)
  local is_storing = count > target
  local jar = is_storing and GetRightMostNonFullJar() or GetLeftMostNonEmptyJar()
  local is_jar_open = Get(jar, 'replica', 'container', '_isopen')
  if not is_jar_open then ToggleJar(jar) end -- open jar if not already open
  return ThePlayer:DoTaskInTime(is_jar_open and 0 or 0.4, function() -- wait to ensure jar is open
    local n = math.abs(count - target) -- number of Soul to move
    if n == 0 then return ToggleJar(jar) end -- no need to move Soul, skip to close Jar

    if is_storing then
      local soul_in_jar = Get(jar, 'replica', 'container'):GetItemInSlot(1)
      local soul_count_in_jar = Get(soul_in_jar, 'replica', 'stackable', 'StackSize') or 0
      local available_storage = (TUNING.STACK_SIZE_SMALLITEM or 40) - soul_count_in_jar
      local num = math.min(n, available_storage)
      dbg('Moving %d Soul from slot %d of inventory bar into Soul Jar', num, slot)
      local source_slot, destination_container = slot, jar
      SendRPCToServer(RPC.MoveInvItemFromCountOfSlot, source_slot, destination_container, num)
    else
      dbg('Moving %d Soul out of Soul Jar to inventory bar', n)
      local source_slot, source_container, destination_container = 1, jar, ThePlayer
      SendRPCToServer(RPC.MoveItemFromCountOfSlot, source_slot, source_container, destination_container, n)
    end
    return ToggleJar(jar) -- close Jar
  end)
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
    and not TheInput:GetHUDEntityUnderMouse() -- cursor not hovering HUD like clock or inventory bar
    and Get(Inv():GetEquippedItem(EQUIPSLOTS.HANDS), 'prefab') ~= 'orangestaff' -- not equipping The Lazy Explorer
    and not Get(T, 'CONTROLS', 'CPMAPanel', 'IsShow') -- 圆形摆放：https://steamcommunity.com/sharedfiles/filedetails/?id=2914336761
    and not (type(rawget(_G, 'IsBSPJPlayHelperReady')) == 'function' and _G.IsBSPJPlayHelperReady()) -- 基地投影：https://steamcommunity.com/sharedfiles/filedetails/?id=2928652892
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
-- Other | 其它

local function Tip(message)
  local talker, time, no_anim, force = Get(ThePlayer, 'components', 'talker'), nil, true, true
  return talker and talker:Say(message, time, no_anim, force)
end

local function GetLandPercentMessage()
  local percent = Get(ThePlayer, 'GetSeeableTilePercent')
  if type(percent) ~= 'number' then return end

  local world = (TheWorld and TheWorld:HasTag('cave')) and S.CAVE_WORLD or S.FOREST_WORLD
  return world .. S.MY_EXPLORED_PERCENT .. string.format('%.2f%%', percent * 100)
end

fn.TipLandPercent = function() return Tip(GetLandPercentMessage() .. '\n' .. S.HOW_TO_ANNOUNCE) end

AddUserCommand('announce_land_percent', {
  aliases = { 'alp' },
  slash = true,
  params = {},
  localfn = function() return TheNet and TheNet:Say(S.MOD_NAME .. GetLandPercentMessage()) end,
})

--------------------------------------------------------------------------------

return fn
