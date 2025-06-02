local SPIN = TUNING.HOTKEY_WORTOX and TUNING.HOTKEY_WORTOX.SPIN_MARKER

return Prefab('blink_marker', function()
  local inst = CreateEntity()

  inst.entity:SetCanSleep(false)
  inst.persists = false

  inst.entity:AddTransform()
  inst.entity:AddAnimState()

  inst:AddTag('NOBLOCK')
  inst:AddTag('FX')
  inst:AddTag('CLASSIFIED')
  inst:AddTag('NOCLICK')

  inst.AnimState:SetBank('spawnprotectionbuff')
  inst.AnimState:SetBuild('spawnprotectionbuff')
  inst.AnimState:SetLightOverride(1)
  inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
  inst.AnimState:SetLayer(LAYER_BACKGROUND)
  inst.AnimState:SetSortOrder(3.1)
  inst.AnimState:SetMultColour(1, 0, 0, 1)
  inst.AnimState:SetAddColour(1, 0, 0, 0)

  inst.Refresh = function(inst, x, z)
    if x and z then
      inst.Transform:SetPosition(x, 0, z)
      if inst.shown then return end
      inst.AnimState:PlayAnimation('buff_pre')
      if SPIN then inst.AnimState:PushAnimation('buff_idle', true) end
      inst.shown = true
    elseif inst.shown then
      inst.AnimState:PlayAnimation('buff_pst')
      inst.shown = false
    end
  end

  return inst
end)
