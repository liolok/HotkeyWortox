local function T(en, zh, zht) return ChooseTranslationTable({ en, zh = zh, zht = zht or zh }) end

name = T('Hotkey for Wortox', '热键：沃拓克斯')
author = T('liolok', '李皓奇')
local date = '2025-06-22'
version = date .. '' -- for revision in same day
description = T(
  [[󰀏 Tip:
Enable this mod and click "Apply", its key bindings will be way more easy,
and also adjustable in bottom of Settings > Controls page.]],
  [[󰀏 提示：
启用本模组并点击「应用」，它的按键绑定会变得非常方便，
并且也可以在设置 > 控制页面下方实时调整。]]
) .. '\n󰀰 ' .. T('Last updated at: ', '最后更新于：') .. date
api_version = 10
dst_compatible = true
client_only_mod = true
icon = 'wortox.tex'
icon_atlas = 'wortox.xml'

local keyboard = { -- from STRINGS.UI.CONTROLSSCREEN.INPUTS[1] of strings.lua, need to match constants.lua too.
  { 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12', 'Print', 'ScrolLock', 'Pause' },
  { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
  { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M' },
  { 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' },
  { 'Escape', 'Tab', 'CapsLock', 'LShift', 'LCtrl', 'LSuper', 'LAlt' },
  { 'Space', 'RAlt', 'RSuper', 'RCtrl', 'RShift', 'Enter', 'Backspace' },
  { 'BackQuote', 'Minus', 'Equals', 'LeftBracket', 'RightBracket' },
  { 'Backslash', 'Semicolon', 'Quote', 'Period', 'Slash' }, -- punctuation
  { 'Up', 'Down', 'Left', 'Right', 'Insert', 'Delete', 'Home', 'End', 'PageUp', 'PageDown' }, -- navigation
}
local numpad = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Period', 'Divide', 'Multiply', 'Minus', 'Plus' }
local mouse = { '\238\132\130', '\238\132\131', '\238\132\132' } -- Middle Mouse Button, Mouse Button 4 and 5
local key_disabled = { description = 'Disabled', data = 'KEY_DISABLED' }
keys = { key_disabled }
for i = 1, #mouse do
  keys[#keys + 1] = { description = mouse[i], data = mouse[i] }
end
for i = 1, #keyboard do
  for j = 1, #keyboard[i] do
    local key = keyboard[i][j]
    keys[#keys + 1] = { description = key, data = 'KEY_' .. key:upper() }
  end
  keys[#keys + 1] = key_disabled
end
for i = 1, #numpad do
  local key = numpad[i]
  keys[#keys + 1] = { description = 'Numpad ' .. key, data = 'KEY_KP_' .. key:upper() }
end

configuration_options = {}

local function Config(conf_type, name, label, hover)
  local options, default = { { description = '', data = 0 } }, 0 -- header
  if conf_type == 'hotkey' then
    options, default = keys, 'KEY_DISABLED'
  elseif conf_type == 'boolean' then
    options = { { data = false, description = T('Off', '关闭') }, { data = true, description = T('On', '开启') } }
    default = false
  end
  configuration_options[#configuration_options + 1] =
    { name = name, label = label, hover = hover, options = options, default = default }
end

local function Switch(...) return Config('boolean', ...) end
local function Header(...) return Config('header', T(...)) end
local function Hotkey(...) return Config('hotkey', ...) end

Switch('debug_mode', T('Debug Mode', '调试模式'), T('Print log in console.', '在控制台打印日志'))

Header('Soul', '灵魂')
Hotkey('UseSoul', T('Eat Soul', '吃灵魂'), T("Hold key till you're full.", '按住吃到饱'))
Hotkey('DropSoul', T('Release Soul', '释放灵魂'), T('Hold key to drop fast.', '按住快速丢'))

Header('Soul Jar', '灵魂罐')
Hotkey(
  'UseSoulJar',
  T('Balance Soul', '存取灵魂'),
  T(
    'Access Soul Jar, make inventory bar Soul number closer to "10 short of overload limit and not more than 40".',
    '操作灵魂罐，使物品栏灵魂数量趋近于「差 10 达到过载上限，且不超过 40」'
  )
)
Switch(
  'greed_mode',
  T('Greed Mode', '贪婪模式'),
  T(
    'When Naughty inclined, pull up the target number of "Balance Soul" to overload limit, no more reducing by ten.',
    '淘气包倾向时，将「存取灵魂」的目标数量拉满至过载上限，不再减十。'
  )
)

Header('Soul Hop', '灵魂跳跃')
Hotkey(
  'BlinkInPlace',
  T('Soul Hop in Place', '原地灵魂跳跃'),
  T('Jump at the position of character.', '在角色所在位置跳跃')
)
Hotkey(
  'BlinkToEntity',
  T('Soul Hop to Object', '精准灵魂跳跃'),
  T(
    'Jump to passible position of object under mouse cursor, where will play portal animation.',
    '跳到鼠标光标下方物体所在且可以落脚的位置，可以看到传送动画提示。'
  )
)
Hotkey(
  'BlinkToMostFar',
  T('Soul Hop to Furthest', '最远灵魂跳跃'),
  T(
    'Jump to furthest passible position directed by the mouse cursor, where will play portal animation.',
    '跳到鼠标光标所指方向最远且可以落脚的位置，可以看到传送动画提示。'
  )
)
Switch(
  'static_blink_marker',
  T('Static Position Prompt', '静态位置提示'),
  T(
    'Almost zero animation of target position prompt for "Soul Hop to Object" and "Soul Hop to Furthest".',
    '精准和最远灵魂跳跃的传送位置的提示接近零动画。'
  )
)

Header('Quick Craft', '快速制作')
Hotkey('MakeNabBag', T('Craft Knabsack', '制作强抢袋'))
Hotkey('MakeReviver', T('Craft Twintailed Heart', '制作双尾心'))

Header('Other', '其它')
Hotkey(
  'TipLandPercent',
  T('Check Land Explored Percent', '查看陆地探索百分比'),
  T('Could also input /alp to announce to the team', '也可以输入 /alp 宣告给队友')
)
