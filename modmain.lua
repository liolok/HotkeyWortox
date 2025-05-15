modimport('keybind')

local callback = require('liolok_hotkey/wortox')

local handler = {} -- config name to key event handlers

function KeyBind(name, key)
  -- disable old binding
  if handler[name] then
    handler[name]:Remove()
    handler[name] = nil
  end

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
