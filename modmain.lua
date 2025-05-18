modimport('keybind')

local Input = GLOBAL.TheInput
local handler = {} -- config name to key event handlers
local fn = require('liolok_hotkey/wortox')

PrefabFiles = { 'blink_marker' } -- Soul Hop target position display | 灵魂跳跃目标位置显示
AddComponentPostInit('playercontroller', fn.RefreshBlinkMarkers)

function KeyBind(name, key)
  -- disable old binding
  if handler[name] then handler[name]:Remove() end

  -- to display target position only if these two hotkeys have binding
  if name == 'BlinkToEntity' then TUNING.HOTKEY_WORTOX_ENTITY = key ~= nil end
  if name == 'BlinkToMostFar' then TUNING.HOTKEY_WORTOX_FURTHEST = key ~= nil end

  -- new binding
  local function f(_key, down) return (_key == key and down and fn.IsPlaying('wortox')) and fn[name]() end
  handler[name] = key and (key >= 1000 and Input:AddMouseButtonHandler(f) or Input:AddKeyHandler(f))
end
