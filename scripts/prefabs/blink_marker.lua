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

  inst.AnimState:SetBank('pocketwatch_warp_marker')
  inst.AnimState:SetBuild('pocketwatch_warp_marker')
  inst.AnimState:PlayAnimation('idle_pre')
  inst.AnimState:PushAnimation('idle_loop', true)
  inst.AnimState:SetLightOverride(1)
  inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
  inst.AnimState:SetLayer(LAYER_BACKGROUND)
  inst.AnimState:SetSortOrder(3.1)

  inst.Transform:SetScale(1.5, 1.5, 1.5)

  inst.Refresh = function(inst, x, z)
    if x and z then
      inst.Transform:SetPosition(x, 0, z)
      if inst.shown then return end
      inst.AnimState:PlayAnimation('mark4_pre')
      inst.AnimState:PushAnimation('mark4_loop', true)
      inst.shown = true
    else
      if not inst.shown then return end
      inst.AnimState:PlayAnimation('mark4_pst')
      inst.AnimState:PushAnimation('off', false)
      inst.shown = false
    end
  end

  return inst
end)
