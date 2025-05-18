local function T(en, zh, zht) return ChooseTranslationTable({ en, zh = zh, zht = zht or zh }) end

name = T('Hotkey for Wortox', '热键：沃拓克斯')
author = T('liolok', '李皓奇')
local date = '2025-05-18'
version = date .. '-1' -- for revision in same day
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
configuration_options = {
  {
    name = 'debug_mode',
    label = T('Debug Mode', '调试模式'),
    hover = T('Print log in console.', '在控制台打印日志'),
    options = { { data = false, description = T('Off', '禁用') }, { data = true, description = T('On', '启用') } },
    default = false,
  },
}

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

local function Config(name, label, hover)
  configuration_options[#configuration_options + 1] =
    { name = name, label = label, hover = hover, options = keys, default = 'KEY_DISABLED' }
end

Config('UseSoul', T('Eat Soul', '吃灵魂'))
Config('DropSoul', T('Release Soul', '释放灵魂'))
Config(
  'UseSoulJar',
  T('Store or Take Soul', '存放或拿取灵魂'),
  T(
    [[Store into / take from Soul Jar once, make inventory bar Soul number
closer to "10 short of overload limit and not more than 40".]],
    [[存/取一次灵魂罐，使物品栏灵魂数量趋近于
「差 10 达到过载上限，且不超过 40」。]]
  )
)
Config(
  'BlinkInPlace',
  T('Soul Hop in Place', '原地灵魂跳跃'),
  T('Jump at the position of character.', '在角色所在位置跳跃')
)
Config(
  'BlinkToEntity',
  T('Soul Hop to Object', '精准灵魂跳跃'),
  T('Jump to the position of object under mouse cursor.', '跳到鼠标光标下物体所在的位置')
)
Config(
  'BlinkToMostFar',
  T('Soul Hop to Furthest', '最远灵魂跳跃'),
  T('Jump to the furthest position directed by the mouse cursor.', '跳到鼠标光标所指向的最远位置')
)
