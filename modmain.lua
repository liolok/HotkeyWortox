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
  if name == 'BlinkToEntity' then TUNING.HOTKEY_WORTOX_ENTITY = key ~= nil end
  if name == 'BlinkToMostFar' then TUNING.HOTKEY_WORTOX_FURTHEST = key ~= nil end

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
AddComponentPostInit('playercontroller', fn.RefreshBlinkMarkers)
