PrefabFiles = { 'blink_marker' }

modimport('keybind')

local callback = require('liolok_hotkey/wortox')

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
    handler[name] = GLOBAL.TheInput:AddMouseButtonHandler(function(button, down, x, y)
      if button == key and down then callback[name]() end
    end)
  else -- it's a keyboard key
    handler[name] = GLOBAL.TheInput:AddKeyDownHandler(key, callback[name])
  end
end

AddComponentPostInit('playercontroller', function(self) -- injection
  local OldOnUpdate = self.OnUpdate
  self.OnUpdate = function(self, ...)
    if not (GLOBAL.ThePlayer and GLOBAL.ThePlayer.prefab == 'wortox') then return OldOnUpdate(self, ...) end

    if TUNING.HOTKEY_WORTOX_CURSOR then -- key binding enabled
      self.blink_marker_cursor = self.blink_marker_cursor or GLOBAL.SpawnPrefab('blink_marker')
      local x, z = callback.GetCursorPosition()
      self.blink_marker_cursor:Refresh(x, z)
    elseif self.blink_marker_cursor then -- key binding disabled in game
      self.blink_marker_cursor:Remove()
      self.blink_marker_cursor = nil
    end

    if TUNING.HOTKEY_WORTOX_MOST_FAR then -- key binding enabled
      self.blink_marker_most_far = self.blink_marker_most_far or GLOBAL.SpawnPrefab('blink_marker')
      local x, z = callback.GetMostFarPosition()
      self.blink_marker_most_far:Refresh(x, z)
    elseif self.blink_marker_most_far then -- key binding disabled in game
      self.blink_marker_most_far:Remove()
      self.blink_marker_most_far = nil
    end

    return OldOnUpdate(self, ...)
  end
end)
