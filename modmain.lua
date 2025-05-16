PrefabFiles = { 'blink_marker' }
modimport('keybind')
local G = GLOBAL
local fn = require('liolok_hotkey/wortox')
local handler = {} -- config name to key event handlers

function KeyBind(name, key)
  -- disable old binding
  if handler[name] then
    handler[name]:Remove()
    handler[name] = nil
  end

  -- if has binding, will display its blink marker
  if name == 'BlinkToCursor' then TUNING.HOTKEY_WORTOX_CURSOR = key ~= nil end
  if name == 'BlinkToMostFar' then TUNING.HOTKEY_WORTOX_MOST_FAR = key ~= nil end

  -- no binding
  if not key then return end

  -- new binding
  if key >= 1000 then -- it's a mouse button
    handler[name] = G.TheInput:AddMouseButtonHandler(
      function(button, down) return (button == key and down and fn.IsPlaying('wortox')) and fn[name]() end
    )
  else -- it's a keyboard key
    handler[name] = G.TheInput:AddKeyDownHandler(key, function() return fn.IsPlaying('wortox') and fn[name]() end)
  end
end

-- Soul Hop Target Position Display | 灵魂跳跃目标位置显示
AddComponentPostInit('playercontroller', function(self)
  local OldOnUpdate = self.OnUpdate
  self.OnUpdate = function(self, ...)
    if not (G.ThePlayer and G.ThePlayer.prefab == 'wortox') then return OldOnUpdate(self, ...) end

    if TUNING.HOTKEY_WORTOX_CURSOR then -- key binding enabled
      self.blink_marker_cursor = self.blink_marker_cursor or G.SpawnPrefab('blink_marker')
      local x, z = fn.GetCursorPosition()
      self.blink_marker_cursor:Refresh(x, z)
    elseif self.blink_marker_cursor then -- key binding disabled in game
      self.blink_marker_cursor:Remove()
      self.blink_marker_cursor = nil
    end

    if TUNING.HOTKEY_WORTOX_MOST_FAR then -- key binding enabled
      self.blink_marker_most_far = self.blink_marker_most_far or G.SpawnPrefab('blink_marker')
      local x, z = fn.GetMostFarPosition()
      self.blink_marker_most_far:Refresh(x, z)
    elseif self.blink_marker_most_far then -- key binding disabled in game
      self.blink_marker_most_far:Remove()
      self.blink_marker_most_far = nil
    end

    return OldOnUpdate(self, ...)
  end
end)
