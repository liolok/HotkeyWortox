TUNING.HOTKEY_WORTOX = {}
local T = TUNING.HOTKEY_WORTOX
T.DEBUG = GetModConfigData('debug_mode')
T.GREED = GetModConfigData('greed_mode')
T.SPIN_MARKER = not GetModConfigData('static_blink_marker')
T.handler = {} -- config name to key event handlers

modimport('keybind')

local Input = GLOBAL.TheInput
local FN = require('liolok_hotkey/wortox')

PrefabFiles = { 'blink_marker' } -- Soul Hop target position display | 灵魂跳跃目标位置显示
AddComponentPostInit('playercontroller', FN.RefreshBlinkMarkers)

function KeyBind(name, key)
  -- disable old binding
  if T.handler[name] then T.handler[name]:Remove() end

  -- new binding
  local function f(_key, down) return (_key == key and down and FN.IsPlaying('wortox')) and FN[name]() end
  T.handler[name] = key and (key >= 1000 and Input:AddMouseButtonHandler(f) or Input:AddKeyHandler(f))
end
